import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/payment_model.dart';
import '../../data/models/recargo_mora_quote.dart';
import '../../data/models/client_discount_quote.dart';
import '../../data/repositories/payment_repository.dart';

import '../../../financials/data/models/account_model.dart';
import '../../../configuration/data/models/payment_type_model.dart';
import '../../../clients/data/models/client_model.dart';
import '../../../products/data/repositories/payment_plan_repository.dart';
import '../../../products/presentation/state/payment_plan_notifier.dart';
import '../../../products/data/models/payment_plan_model.dart';

import '../../../financials/presentation/state/currency_notifier.dart';
import '../../../financials/data/models/currency_model.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/widgets/app_flag.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../state/payment_refresh_coordinator.dart';

import 'payment_row_item.dart';

class ProcessPaymentDialog extends ConsumerStatefulWidget {
  final ClientModel client;
  final String planId;

  /// R5.2 — pago de una cuota concreta de la membresía del cliente: fija el
  /// importe y envía `modo_cuotas` + `numero_cuota` al servidor.
  final int? cuotaNumero;
  final double? cuotaImporte;

  const ProcessPaymentDialog({
    super.key,
    required this.client,
    required this.planId,
    this.cuotaNumero,
    this.cuotaImporte,
  });

  @override
  ConsumerState<ProcessPaymentDialog> createState() =>
      _ProcessPaymentDialogState();
}

class _ProcessPaymentDialogState extends ConsumerState<ProcessPaymentDialog> {
  // Static mock state
  final List<Map<String, dynamic>> _paymentRows = [];
  bool _isLoading = false;

  /// R5.2 — contratación por cuotas: elección de recepción y esquema del plan.
  bool _porCuotas = false;
  // Recargo por mora (docs/RECARGO_MORA.md): cotización del servidor y casilla.
  RecargoMoraQuote? _recargoQuote;
  bool _recargoQuoteLoading = false;
  String? _recargoQuoteError;
  ClientDiscountQuote? _discountQuote;
  bool _discountQuoteLoading = false;
  String? _discountQuoteError;
  // Condonación del recargo (docs/RECARGO_MORA.md §6-bis): el recargo se cobra
  // por política; perdonarlo es la excepción y exige motivo.
  bool _condonarRecargoMora = false;
  final TextEditingController _motivoCondonacionController =
      TextEditingController();
  List<Map<String, dynamic>> _scheme = const [];

  /// Siguiente cuota pendiente detectada en la membresía del cliente: el
  /// diálogo la propone solo, con importe fijo.
  int? _autoCuotaNumero;
  double? _autoCuotaImporte;

  /// Por qué no se pudo preparar el cobro por cuotas. Se muestra: si esto se
  /// calla, el operador cobra el plan completo creyendo que no hay cuotas.
  String? _cuotaContextError;

  int? get _numeroCuotaEnCurso => widget.cuotaNumero ?? _autoCuotaNumero;

  double? get _importeCuotaEnCurso => widget.cuotaImporte ?? _autoCuotaImporte;

  bool get _cuotaFija => _numeroCuotaEnCurso != null;

  /// ¿Este cobro va contra la membresía que ya tiene el cliente?
  ///
  /// El servidor solo admite cobrar contra una membresía que **siga esperando
  /// pago**; si se le señala una ya activada responde «la membresía seleccionada
  /// ya fue activada o no admite cobros», y hace bien: cobrarla otra vez
  /// duplicaría el ingreso de un plan ya saldado.
  ///
  /// Antes se mandaba **siempre** la membresía del cliente, así que un socio con
  /// su plan al día —o vencido pero pagado— no se podía cobrar de ninguna
  /// manera. Cuando no queda nada por cobrar de la membresía actual, lo que
  /// corresponde es una **renovación**, y el servidor la abre solo con que no le
  /// mandemos ninguna membresía.
  ///
  /// El cobro por cuotas es la excepción: ahí sí se cobra sobre una membresía
  /// activa, y su ruta no pasa por la activación.
  bool get _debeSenalarMembresia =>
      _cuotaFija ||
      (widget.client.membershipStatus ?? '').trim().toUpperCase() ==
          'PENDIENTE_PAGO';

  double? get _cuota1Importe =>
      _scheme.isEmpty ? null : double.tryParse('${_scheme.first['importe']}');

  int get _cuota1Dias => _scheme.isEmpty
      ? 0
      : int.tryParse(
              '${_scheme.first['dias_cobertura'] ?? _scheme.first['diasCobertura']}',
            ) ??
            0;

  @override
  void dispose() {
    _motivoCondonacionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.cuotaNumero == null) {
      _loadInstallmentContext();
    }
    // El recargo se cotiza al abrir: si hay atraso, la casilla llega marcada.
    _loadRecargoMoraQuote();
    _loadClientDiscountQuote();
  }

  Future<void> _loadInstallmentContext() async {
    final repo = ref.read(paymentPlanRepositoryProvider);
    // 1) Membresía vigente con cuotas: proponer la siguiente pendiente.
    final membershipId = widget.client.membershipId;
    if (membershipId != null && membershipId.isNotEmpty) {
      try {
        final cuotas = await repo.getMembresiaCuotas(membershipId);
        final next = cuotas.where((c) => !c.isPaid && c.estado != 'ANULADA');
        if (next.isNotEmpty && mounted) {
          setState(() {
            _autoCuotaNumero = next.first.numeroCuota;
            _autoCuotaImporte = next.first.importe;
          });
          return;
        }
      } catch (error) {
        // Antes se ignoraba: el cobro seguía como plan completo sin avisar de
        // que quizá había una cuota pendiente que no se pudo leer.
        if (mounted) {
          setState(() {
            _cuotaContextError =
                'No se pudieron leer las cuotas de la membresía. '
                '${_shortError(error)}';
          });
        }
      }
    }
    // 2) Contratación nueva: cargar el esquema para ofrecer la elección.
    if (widget.planId.isNotEmpty) {
      try {
        final scheme = await repo.getPlanCuotasScheme(widget.planId);
        if (mounted && scheme.isNotEmpty) {
          setState(() => _scheme = scheme);
        }
      } catch (error) {
        // Un esquema ilegible no es lo mismo que un plan sin cuotas: sin este
        // aviso, la opción «primera cuota» desaparecía en silencio.
        if (mounted) {
          setState(() {
            _cuotaContextError =
                'No se pudo leer el esquema de cuotas del plan. '
                '${_shortError(error)}';
          });
        }
      }
    }
  }

  /// Mensaje del servidor si lo hay; si no, algo corto y legible.
  String _shortError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      final message = data is Map ? data['error'] : null;
      if (message != null && '$message'.trim().isNotEmpty) return '$message';
      final code = error.response?.statusCode;
      return code == null
          ? 'No hubo respuesta del servidor.'
          : 'El servidor respondió $code.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _processPayment() async {
    // Se capturan antes de cerrar el diálogo para colorear los snackbars.
    final tokens = PulsoTokens.of(context);
    setState(() => _isLoading = true);

    try {
      final plans = ref.read(paymentPlanProvider).asData?.value ?? [];
      final plan = plans.firstWhere(
        (p) => p.id == widget.planId,
        orElse: () => PaymentPlanModel(
          id: '',
          nombre: '',
          importe: 0,
          duracion: 0,
          monedaId: '',
        ),
      );

      // Validation: rows in the same currency use an implicit 1:1 rate and do not need a TipoCambio row.
      for (final row in _paymentRows) {
        if (row['isValid'] != true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Error: complete tipo de pago, cuenta, monto y tasa si la moneda es diferente.',
                ),
                backgroundColor: tokens.danger,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      final paymentId = const Uuid().v4();

      // Truncate to milliseconds and ensure UTC for Prisma compatibility (requires 'Z' or offset)
      final now = appClock.nowUtc();
      final cleanDate = DateTime.utc(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
        now.second,
        now.millisecond,
      );

      final payment = PaymentModel(
        id: paymentId,
        ci: widget.client.id, // Assuming CI matches ID
        fecha: cleanDate,
        // El encabezado representa el precio aplicado al plan (o la cuota
        // cobrada en modo cuotas). El excedente en efectivo es cambio de
        // caja, no ingreso.
        amount: _amountDueFor(plan),
        trainerId: widget.client.trainerId,
        planId: widget.planId,
        currencyId: plan.monedaId,
        membershipId: _debeSenalarMembresia ? widget.client.membershipId : null,
        isDeleted: false,
      );

      final details = _paymentRows.map((row) {
        final account = row['account'] as AccountModel;
        final type = row['type'] as PaymentTypeModel;

        return PaymentDetailModel(
          id: const Uuid().v4(),
          paymentId: paymentId,
          paymentTypeId: type.id,
          currencyId: account.currencyId,
          accountId: account.id,
          amount: (row['amount'] as num).toDouble(),
          exchangeRateId: row['exchangeRateId'] as String?,
          methodSurchargeBase: (row['baseAmount'] as num).toStringAsFixed(2),
          methodSurchargeRateVersion: row['exchangeRateVersion'] as int?,
        );
      }).toList();

      await ref
          .read(paymentRepositoryProvider)
          .createPayment(
            payment,
            details,
            extra: {
              if (_cuotaFija) ...{
                'modo_cuotas': true,
                'numero_cuota': _numeroCuotaEnCurso,
              } else if (_porCuotas)
                'modo_cuotas': true,
              // El servidor recalcula el importe; aquí solo viaja la decisión de
              // condonar y su motivo (docs/RECARGO_MORA.md §6-bis).
              if (_condonarRecargoMora) ...{
                'condonar_recargo_mora': true,
                'motivo_condonacion_recargo': _motivoCondonacionController.text
                    .trim(),
              },
            },
          );
      await ref
          .read(paymentRefreshCoordinatorProvider)
          .afterSuccessfulPayment(widget.client.id);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Pago guardado exitosamente'),
            backgroundColor: tokens.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar pago: $e'),
            backgroundColor: tokens.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _totalPaid {
    double total = 0;
    for (final row in _paymentRows) {
      final equivalent = row['equivalent'];
      if (equivalent != null && equivalent is num) {
        total += equivalent.toDouble();
      }
    }
    return total;
  }

  double get _totalCollected {
    double total = 0;
    for (final row in _paymentRows) {
      final collected = row['collectedEquivalent'] ?? row['equivalent'];
      if (collected is num) total += collected.toDouble();
    }
    return total;
  }

  double get _totalSurcharge {
    double total = 0;
    for (final row in _paymentRows) {
      final surcharge = row['surchargeAmount'];
      if (surcharge != null && surcharge is num) {
        total += surcharge.toDouble();
      }
    }
    return total;
  }

  /// Casilla «aplicar recargo por mora» (docs/RECARGO_MORA.md).
  ///
  /// Solo aparece cuando el plan tiene el recargo configurado y activo. El
  /// importe lo calcula el servidor; recepción únicamente confirma o desmarca.
  Widget _buildRecargoMoraBanner(PulsoTokens t, String planSymbol) {
    if (_recargoQuoteLoading) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.line),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: t.muted),
            ),
            const SizedBox(width: 10),
            Text(
              'Comprobando recargo por mora…',
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontSize: 11,
                color: t.muted,
              ),
            ),
          ],
        ),
      );
    }

    if (_recargoQuoteError != null) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: t.danger.withValues(alpha: 0.08),
          border: Border.all(color: t.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined, size: 16, color: t.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No se pudo calcular el recargo por mora: $_recargoQuoteError',
                style: TextStyle(fontSize: 11.5, color: t.chalk),
              ),
            ),
          ],
        ),
      );
    }

    final quote = _recargoQuote;
    // Sin recargo configurado o inactivo: no se muestra nada a recepción.
    if (quote == null || !quote.planTieneRecargo || !quote.planRecargoActivo) {
      return const SizedBox.shrink();
    }
    // Configurado y activo pero sin atraso: aviso discreto, sin casilla.
    if (!quote.aplicado && quote.motivo == 'SIN_ATRASO') {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.line),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, size: 16, color: t.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Pago al día: no corresponde recargo por mora.',
                style: TextStyle(fontSize: 11.5, color: t.muted),
              ),
            ),
          ],
        ),
      );
    }

    final modoLabel = switch (quote.modo) {
      'PORCENTAJE' => 'porcentaje',
      'MONTO_FIJO' => 'monto fijo',
      'POR_DIA' => 'por día de atraso',
      _ => 'recargo',
    };
    final unidad = quote.diasAtraso == 1 ? 'día' : 'días';

    return Container(
      key: const ValueKey('pulso-cobro-recargo-mora'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _condonarRecargoMora
            ? t.danger.withValues(alpha: 0.06)
            : t.accent.withValues(alpha: 0.08),
        border: Border.all(
          color: _condonarRecargoMora
              ? t.danger.withValues(alpha: 0.3)
              : t.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _condonarRecargoMora
                    ? Icons.money_off_outlined
                    : Icons.gavel_outlined,
                size: 16,
                color: _condonarRecargoMora ? t.danger : t.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _condonarRecargoMora
                          ? 'Recargo por mora CONDONADO  ·  se deja de cobrar $planSymbol${quote.recargo}'
                          : 'Recargo por mora  ·  +$planSymbol${quote.recargo}',
                      style: TextStyle(
                        fontFamily: PulsoFonts.body,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: t.chalk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${quote.diasAtraso} $unidad de atraso · $modoLabel · '
                      'base $planSymbol${quote.base}',
                      style: TextStyle(
                        fontFamily: PulsoFonts.mono,
                        fontSize: 10.5,
                        color: t.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Condonar es la excepción: exige motivo y queda registrada en el
          // cierre con quién la hizo (docs/RECARGO_MORA.md §6-bis).
          Row(
            children: [
              Checkbox(
                key: const ValueKey('pulso-cobro-condonar-recargo'),
                value: _condonarRecargoMora,
                activeColor: t.danger,
                onChanged: _isLoading
                    ? null
                    : (value) =>
                          setState(() => _condonarRecargoMora = value ?? false),
              ),
              Expanded(
                child: Text(
                  'No cobrar este recargo (queda registrado)',
                  style: TextStyle(fontSize: 11.5, color: t.chalk),
                ),
              ),
            ],
          ),
          if (_condonarRecargoMora) ...[
            const SizedBox(height: 4),
            TextFormField(
              key: const ValueKey('pulso-cobro-condonar-motivo'),
              controller: _motivoCondonacionController,
              enabled: !_isLoading,
              maxLength: 500,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'Motivo de la condonación (obligatorio)',
                hintText: 'Ej. socio hospitalizado, autorizado por dirección',
                counterText: '',
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (!_motivoCondonacionValido)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Indique al menos 5 caracteres para poder condonar.',
                  style: TextStyle(fontSize: 10.5, color: t.danger),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// El servidor exige el mismo mínimo; aquí solo se evita el viaje en balde.
  bool get _motivoCondonacionValido =>
      _motivoCondonacionController.text.trim().length >= 5;

  Widget _buildSurchargeBanner(PulsoTokens t, String planSymbol) {
    final surcharge = _totalSurcharge;
    if (surcharge <= 0) return const SizedBox.shrink();

    final details = <String>[];
    for (final row in _paymentRows) {
      final sur = row['surchargeAmount'];
      final surPlan = row['surchargePlanCurrency'];
      final pct = row['surchargePct'];
      final type = row['type'] as PaymentTypeModel?;
      final account = row['account'] as AccountModel?;
      if (sur != null && sur is num && sur > 0) {
        final pctLabel = pct != null ? ' ($pct%)' : '';
        final typeName = type?.name ?? 'Método con recargo';
        // Un importe de recargo sin moneda al lado es exactamente lo que la
        // regla «nunca sumar monedas distintas» quiere evitar. La condición
        // anterior era `currencyId.length <= 5`, que con un UUID no se cumple
        // nunca: el recargo se enseñaba desnudo.
        final currCode = account?.currencyLabel ?? '';
        final currSuffix = currCode.isNotEmpty ? ' $currCode' : '';
        final planSuffix = surPlan != null && surPlan is num && surPlan > 0
            ? ' (+$planSymbol${surPlan.toDouble().toStringAsFixed(2)})'
            : '';
        details.add(
          '$typeName$pctLabel: +${sur.toDouble().toStringAsFixed(2)}$currSuffix$planSuffix',
        );
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.08),
        border: Border.all(color: t.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: t.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recargo por método de pago (ganancia gimnasio - entero):',
                  style: TextStyle(
                    fontFamily: PulsoFonts.body,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: t.chalk,
                  ),
                ),
                Text(
                  details.join(' | '),
                  style: TextStyle(
                    fontFamily: PulsoFonts.body,
                    fontSize: 12,
                    color: t.chalkDim,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _remainingLabel(double remaining, String planSymbol) {
    if (remaining <= 0) return 'Saldo restante: ${planSymbol}0.00';

    final text = 'Saldo restante: $planSymbol${remaining.toStringAsFixed(2)}';

    for (final row in _paymentRows) {
      final account = row['account'] as AccountModel?;
      final rate = row['rate'];
      final rateOp = row['rateOperation'];
      if (account != null &&
          rate != null &&
          rate is num &&
          rate > 0 &&
          rate != 1.0) {
        final r = rate.toDouble();
        // El código de la moneda, no un trozo de su identificador. Antes esto
        // recortaba `currencyId` a cinco caracteres y el operador leía
        // «Saldo restante: ₽34.00 (~0.08 1DBC5)» —los cinco primeros dígitos
        // del UUID de la cuenta EUR—, justo en la línea que dice cuánto falta.
        final currencyCode = account.currencyLabel;
        final equiv = rateOp == 'divide' ? remaining * r : remaining / r;
        return '$text (~${equiv.toStringAsFixed(2)} $currencyCode)';
      }
    }
    return text;
  }

  /// Aviso corto sobre el cobro por cuotas. Ocupa el sitio de la elección
  /// cuando esta no se puede ofrecer, para que nunca desaparezca sin motivo.
  Widget _cuotaAviso(PulsoTokens t, String mensaje, {bool warning = false}) {
    final color = warning ? t.warning : t.muted;
    return Container(
      key: const ValueKey('cuota-aviso'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: warning ? t.warningSoft : t.raised,
        border: Border.all(color: warning ? t.warning : t.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.warning_amber_outlined : Icons.info_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(mensaje, style: TextStyle(fontSize: 11, color: color)),
          ),
        ],
      ),
    );
  }

  /// R5.2 — elección de recepción cuando el plan admite cuotas: cobrar el
  /// plan completo o solo la primera cuota (el resto queda programado).
  Widget _buildCuotaChoice(
    PulsoTokens t,
    PaymentPlanModel plan,
    String planSymbol,
  ) {
    if (_cuotaFija) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: t.accentSoft,
          border: Border.all(color: t.accent),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined, size: 16, color: t.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'CUOTA #$_numeroCuotaEnCurso · '
                '$planSymbol${(_importeCuotaEnCurso ?? 0).toStringAsFixed(2)} · importe fijo',
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: t.accent,
                ),
              ),
            ),
          ],
        ),
      );
    }
    // Solo en contrataciones nuevas de un plan con esquema de cuotas.
    final balance = widget.client.membershipBalanceDue;
    if (_cuotaContextError != null) {
      return _cuotaAviso(t, _cuotaContextError!, warning: true);
    }
    if (balance != null && balance > 0) {
      // Se explica en vez de desaparecer: el operador debe saber por qué no
      // puede elegir cuotas en este cobro.
      return _cuotaAviso(
        t,
        'La membresía actual tiene saldo pendiente; primero se salda y '
        'después se puede contratar por cuotas.',
      );
    }
    if (_scheme.isEmpty) {
      return const SizedBox.shrink();
    }
    Widget option({
      required Key key,
      required bool selected,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: key,
            onTap: _isLoading ? null : onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: selected ? t.accentSoft : t.raised,
                border: Border.all(color: selected ? t.accent : t.line),
              ),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: selected ? t.accent : t.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: PulsoFonts.mono,
                            fontSize: 10,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                            color: selected ? t.accent : t.muted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: selected ? t.chalk : t.chalkDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          option(
            key: const ValueKey('pay-mode-full'),
            selected: !_porCuotas,
            title: 'PLAN COMPLETO',
            subtitle:
                '$planSymbol${plan.importe.toStringAsFixed(2)} · ${plan.duracion} días',
            onTap: () => setState(() => _porCuotas = false),
          ),
          const SizedBox(width: 8),
          option(
            key: const ValueKey('pay-mode-installments'),
            selected: _porCuotas,
            title: 'PRIMERA CUOTA',
            subtitle:
                '$planSymbol${(_cuota1Importe ?? 0).toStringAsFixed(2)} · '
                '$_cuota1Dias días · quedan ${_scheme.length - 1} cuota(s)',
            onTap: () => setState(() => _porCuotas = true),
          ),
        ],
      ),
    );
  }

  double _amountDueFor(PaymentPlanModel plan) {
    // El recargo por mora se suma al final: es ingreso aparte, no parte del
    // precio del plan (docs/RECARGO_MORA.md). El importe viene del servidor.
    return _baseAmountDueFor(plan) + _recargoMoraAplicado;
  }

  /// Importe del plan/cuota sin recargo por mora.
  double _baseAmountDueFor(PaymentPlanModel plan) {
    // Cuota concreta (panel de cuotas o detección automática): importe fijo.
    if (_cuotaFija) return _importeCuotaEnCurso ?? plan.importe;
    // Contratación por cuotas: se cobra la cuota 1; el resto queda programado.
    if (_porCuotas && _cuota1Importe != null) return _cuota1Importe!;
    // R5.3: Flutter no calcula. Solo presenta el precio final firmado por la
    // API; sin cotización el botón de confirmación permanece deshabilitado.
    // Mientras carga se conserva el precio de lista que ya vino del catálogo
    // del servidor; confirmar sigue bloqueado hasta recibir la cotización.
    return _discountQuote?.finalPrice ?? plan.importe;
  }

  Future<void> _loadClientDiscountQuote() async {
    if (widget.planId.isEmpty) return;
    setState(() => _discountQuoteLoading = true);
    try {
      final quote = await ref
          .read(paymentRepositoryProvider)
          .getClientDiscountQuote(ci: widget.client.id, planId: widget.planId);
      if (!mounted) return;
      setState(() {
        _discountQuote = quote;
        _discountQuoteError = null;
        _discountQuoteLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _discountQuote = null;
        _discountQuoteError = _shortError(error);
        _discountQuoteLoading = false;
      });
    }
  }

  /// Recargo que se está cobrando ahora mismo. Se cobra siempre que
  /// corresponda; solo baja a 0 si el recepcionista lo condona.
  double get _recargoMoraAplicado =>
      !_condonarRecargoMora && (_recargoQuote?.aplicado ?? false)
      ? _recargoQuote!.recargoValor
      : 0.0;

  /// Pide al servidor la cotización del recargo por mora. Si falla, se guarda
  /// el aviso y el cobro sigue disponible sin recargo.
  Future<void> _loadRecargoMoraQuote() async {
    if (widget.planId.isEmpty) return;
    setState(() => _recargoQuoteLoading = true);
    try {
      final quote = await ref
          .read(paymentRepositoryProvider)
          .getRecargoMoraQuote(
            ci: widget.client.id,
            planId: widget.planId,
            membresiaId: _cuotaFija ? widget.client.membershipId : null,
            numeroCuota: _cuotaFija ? _numeroCuotaEnCurso : null,
          );
      if (!mounted) return;
      setState(() {
        _recargoQuote = quote;
        _recargoQuoteError = null;
        _recargoQuoteLoading = false;
        // El recargo entra por política; recepción no tiene que activarlo.
        _condonarRecargoMora = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recargoQuote = null;
        _recargoQuoteError = e.toString().replaceFirst('Exception: ', '');
        _recargoQuoteLoading = false;
        _condonarRecargoMora = false;
      });
    }
  }

  String get _planLabel {
    final quoted = _discountQuote?.planCode.trim();
    if (quoted != null && quoted.isNotEmpty) return quoted;
    if (widget.planId.isEmpty) return 'sin asignar';
    final shortId = widget.planId.length > 8
        ? widget.planId.substring(0, 8)
        : widget.planId;
    return '#$shortId';
  }

  @override
  Widget build(BuildContext context) {
    return PulsoThemeScope(
      child: Builder(
        builder: (context) => LayoutBuilder(
          builder: (context, constraints) {
            final dialogWidth = constraints.maxWidth.isFinite
                ? math.min(1100.0, math.max(320.0, constraints.maxWidth - 40))
                : 1100.0;
            final maxHeight = constraints.maxHeight.isFinite
                ? math.min(760.0, math.max(420.0, constraints.maxHeight - 80))
                : 760.0;
            final compact = dialogWidth < 700;
            return Center(
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: dialogWidth,
                  height: maxHeight,
                  child: PulsoPanel(
                    key: const ValueKey('pulso-process-payment'),
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _buildHeader(),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(compact ? 16 : 28),
                            child: Column(
                              children: [
                                _buildClientInfoCard(),
                                const SizedBox(height: 24),
                                _buildPaymentDetailsSection(),
                              ],
                            ),
                          ),
                        ),
                        _buildStickyFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final t = PulsoTokens.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      decoration: BoxDecoration(
        color: t.raised,
        border: Border(bottom: BorderSide(color: t.lineStrong)),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 32, color: t.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PulsoLabel('NUEVO COBRO · PASO 2'),
                Text(
                  'REGISTRAR PAGO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: PulsoFonts.display,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: t.chalk,
                  ),
                ),
                Text(
                  'Plan $_planLabel',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 10.5,
                    color: t.muted,
                  ),
                ),
              ],
            ),
          ),
          PulsoIconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
            icon: Icons.close,
          ),
        ],
      ),
    );
  }

  Widget _buildClientInfoCard() {
    final t = PulsoTokens.of(context);
    final plansAsync = ref.watch(paymentPlanProvider);
    final currenciesAsync = ref.watch(currencyProvider);
    final loadedPlans = plansAsync.value ?? const <PaymentPlanModel>[];
    final loadedCurrencies = currenciesAsync.value ?? const <CurrencyModel>[];
    final currentPlan = loadedPlans
        .where((plan) => plan.id == widget.planId)
        .firstOrNull;
    final planCurrency = loadedCurrencies
        .where((currency) => currency.id == currentPlan?.monedaId)
        .firstOrNull;
    final planSymbol = planCurrency?.symbol?.trim().isNotEmpty == true
        ? planCurrency!.symbol!.trim()
        : '${planCurrency?.code ?? ''} ';

    final clientBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PulsoLabel('Cliente'),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _showClientPhoto,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              width: 56,
              height: 56,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: t.raised,
                border: Border.all(color: t.line),
              ),
              child: widget.client.fotoCliente != null
                  ? Image.memory(widget.client.fotoCliente!, fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        (widget.client.nombres ?? '?')[0],
                        style: TextStyle(
                          fontFamily: PulsoFonts.display,
                          fontWeight: FontWeight.w800,
                          color: t.chalk,
                          fontSize: 22,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${widget.client.nombres} ${widget.client.apellidos}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: t.chalk,
          ),
        ),
      ],
    );

    final planBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PulsoLabel('Plan suscrito'),
        const SizedBox(height: 12),
        plansAsync.when(
          data: (plans) {
            final plan = plans.firstWhere(
              (p) => p.id == widget.planId,
              orElse: () => PaymentPlanModel(
                nombre: 'Plan no encontrado',
                importe: 0,
                duracion: 0,
                monedaId: '',
              ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: t.chalk,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  color: t.accentSoft,
                  child: Text(
                    plan.formattedDuration,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: t.accent,
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (error, stackTrace) => Text(
            'Error cargando plan',
            style: TextStyle(color: t.danger, fontSize: 12),
          ),
        ),
      ],
    );

    final progressBlock = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.raised,
        border: Border.all(color: t.line),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compactSummary = constraints.maxWidth < 360;
              return Flex(
                direction: compactSummary ? Axis.vertical : Axis.horizontal,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: compactSummary
                    ? CrossAxisAlignment.stretch
                    : CrossAxisAlignment.start,
                children: [
                  Flexible(
                    fit: compactSummary ? FlexFit.loose : FlexFit.tight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PulsoLabel('Total por cobrar'),
                        plansAsync.when(
                          data: (plans) {
                            final plan = plans.firstWhere(
                              (p) => p.id == widget.planId,
                              orElse: () => PaymentPlanModel(
                                nombre: 'Unknown',
                                importe: 0,
                                duracion: 0,
                                monedaId: '',
                              ),
                            );
                            return currenciesAsync.when(
                              data: (currencies) {
                                final currency = currencies.firstWhere(
                                  (c) => c.id == plan.monedaId,
                                  orElse: () => const CurrencyModel(
                                    id: '',
                                    name: '',
                                    code: 'USD',
                                    symbol: r'$',
                                  ),
                                );
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (currency.flagImage != null) ...[
                                          AppFlag(
                                            base64String: currency.flagImage!,
                                            fallbackCode: currency.code,
                                            width: 16,
                                            height: 12,
                                            borderRadius: 0,
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          currency.code,
                                          style: TextStyle(
                                            fontFamily: PulsoFonts.mono,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: t.chalkDim,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${currency.symbol} ${_amountDueFor(plan).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontFamily: PulsoFonts.display,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: t.chalk,
                                        height: 1.0,
                                      ),
                                    ),
                                    if (!_cuotaFija && !_porCuotas) ...[
                                      const SizedBox(height: 6),
                                      if (_discountQuoteLoading)
                                        Text(
                                          'Cotizando descuento en el servidor…',
                                          style: TextStyle(
                                            fontFamily: PulsoFonts.mono,
                                            fontSize: 9,
                                            color: t.muted,
                                          ),
                                        )
                                      else if (_discountQuoteError != null)
                                        Text(
                                          'No disponible: $_discountQuoteError',
                                          style: TextStyle(
                                            fontFamily: PulsoFonts.mono,
                                            fontSize: 9,
                                            color: t.danger,
                                          ),
                                        )
                                      else if (_discountQuote != null)
                                        Text(
                                          'LISTA ${currency.symbol}${_discountQuote!.listPrice.toStringAsFixed(2)}'
                                          '  −  DESCUENTO ${currency.symbol}${_discountQuote!.discount.toStringAsFixed(2)}'
                                          '  ·  ${_discountQuote!.clientCategory}',
                                          key: const ValueKey(
                                            'server-discount-breakdown',
                                          ),
                                          style: TextStyle(
                                            fontFamily: PulsoFonts.mono,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: _discountQuote!.discount > 0
                                                ? t.success
                                                : t.muted,
                                          ),
                                        ),
                                    ],
                                  ],
                                );
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (error, stackTrace) =>
                                  const SizedBox.shrink(),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (error, stackTrace) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: compactSummary ? 0 : 12,
                    height: compactSummary ? 12 : 0,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const PulsoLabel('Aplicado al plan'),
                        const SizedBox(height: 4),
                        Text(
                          '$planSymbol${_totalPaid.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontFamily: PulsoFonts.display,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: t.success,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          plansAsync.when(
            data: (plans) {
              final plan = plans.firstWhere(
                (p) => p.id == widget.planId,
                orElse: () => PaymentPlanModel(
                  nombre: '',
                  importe: 1, // Avoid div by zero
                  duracion: 0,
                  monedaId: '',
                ),
              );
              final total = _amountDueFor(plan);
              final progress = (total > 0)
                  ? (_totalPaid / total).clamp(0.0, 1.0)
                  : 0.0;
              final remaining = (total - _totalPaid).clamp(
                0.0,
                double.infinity,
              );

              return Column(
                children: [
                  _buildCuotaChoice(t, plan, planSymbol),
                  Stack(
                    children: [
                      Container(height: 8, color: t.raised2),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Container(
                            height: 8,
                            width: constraints.maxWidth * progress,
                            color: t.success,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final progressLabel = Text(
                        'Progreso: ${(progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 11,
                          color: t.muted,
                        ),
                      );
                      final remainingBadge = Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: remaining > 0 ? t.dangerSoft : t.successSoft,
                          border: Border.all(
                            color: (remaining > 0 ? t.danger : t.success)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          _remainingLabel(remaining, planSymbol),
                          style: TextStyle(
                            fontFamily: PulsoFonts.mono,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: remaining > 0 ? t.danger : t.success,
                          ),
                        ),
                      );

                      // En ventanas angostas ambos textos no caben en una fila.
                      // Apilarlos mantiene visible el saldo sin RenderFlex.
                      if (constraints.maxWidth < 360) {
                        return Column(
                          key: const ValueKey('payment-progress-summary'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            progressLabel,
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: remainingBadge,
                            ),
                          ],
                        );
                      }

                      return Row(
                        key: const ValueKey('payment-progress-summary'),
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [progressLabel, remainingBadge],
                      );
                    },
                  ),
                  _buildRecargoMoraBanner(t, planSymbol),
                  _buildSurchargeBanner(t, planSymbol),
                ],
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => const SizedBox(),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.line),
        boxShadow: t.panelShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 640) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                clientBlock,
                const SizedBox(height: 16),
                Divider(height: 1, color: t.line),
                const SizedBox(height: 16),
                planBlock,
                const SizedBox(height: 16),
                progressBlock,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: clientBlock),
              Container(width: 1, height: 130, color: t.line),
              const SizedBox(width: 24),
              Expanded(flex: 3, child: planBlock),
              Container(width: 1, height: 130, color: t.line),
              const SizedBox(width: 24),
              Expanded(flex: 6, child: progressBlock),
            ],
          );
        },
      ),
    );
  }

  void _showClientPhoto() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => PulsoThemeScope(
        child: Builder(
          builder: (context) {
            final t = PulsoTokens.of(context);
            return Dialog(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: t.surface,
                  border: Border(top: BorderSide(color: t.accent, width: 4)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const PulsoLabel('Foto del cliente'),
                        PulsoIconButton(
                          icon: Icons.close,
                          tooltip: 'Cerrar',
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 280,
                      height: 280,
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        color: t.raised,
                        border: Border.all(color: t.line),
                      ),
                      child: widget.client.fotoCliente != null
                          ? Image.memory(
                              widget.client.fotoCliente!,
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: Text(
                                (widget.client.nombres ?? '?')[0],
                                style: TextStyle(
                                  fontFamily: PulsoFonts.display,
                                  fontSize: 80,
                                  fontWeight: FontWeight.w800,
                                  color: t.chalk,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${widget.client.nombres} ${widget.client.apellidos}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: t.chalk,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPaymentDetailsSection() {
    final t = PulsoTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, color: t.accent),
            const SizedBox(width: 8),
            const PulsoLabel('FORMAS DE PAGO'),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.line),
            boxShadow: t.panelShadow,
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: t.raised,
                  border: Border(bottom: BorderSide(color: t.line)),
                ),
                child: Row(
                  children: [
                    _colHeader('TIPO', 2),
                    const SizedBox(width: 8),
                    _colHeader('CUENTA', 3),
                    const SizedBox(width: 8),
                    _colHeader('TOTAL RECIBIDO', 2),
                    const SizedBox(width: 8),
                    _colHeader('INFO / TASA', 3),
                    const SizedBox(width: 8),
                    _colHeader('COBRADO / AL PLAN', 2, align: TextAlign.right),
                    const SizedBox(width: 48), // Action space
                  ],
                ),
              ),
              // Rows
              ..._paymentRows.asMap().entries.map(
                (e) => _buildPaymentRow(e.key, e.value),
              ),
              // Add Row Button
              Builder(
                builder: (context) {
                  final plansState = ref.watch(paymentPlanProvider);
                  final plans = plansState.asData?.value ?? [];
                  final plan = plans.firstWhere(
                    (p) => p.id == widget.planId,
                    orElse: () => PaymentPlanModel(
                      id: '',
                      nombre: '',
                      importe: 0,
                      duracion: 0,
                      monedaId: '',
                    ),
                  );
                  final remaining = _amountDueFor(plan) - _totalPaid;
                  final isPaid = remaining <= 0.001;

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: t.raised,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: isPaid ? null : _addPaymentRow,
                        icon: Icon(
                          Icons.add_circle_outline,
                          size: 20,
                          color: isPaid ? t.muted : t.accent,
                        ),
                        label: Text(
                          'Añadir otro método de pago',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isPaid ? t.muted : t.accent,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Divider(height: 1, color: t.line),
              // Footer Totals
              Container(
                padding: const EdgeInsets.all(16),
                color: t.raised,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Builder(
                      builder: (context) {
                        final plansState = ref.watch(paymentPlanProvider);
                        final plans = plansState.asData?.value ?? [];
                        final plan = plans.firstWhere(
                          (p) => p.id == widget.planId,
                          orElse: () => PaymentPlanModel(
                            id: '',
                            nombre: '',
                            importe: 0,
                            duracion: 0,
                            monedaId: '',
                          ),
                        );
                        final currencies =
                            ref.watch(currencyProvider).value ??
                            const <CurrencyModel>[];
                        final planCurrency = currencies
                            .where((c) => c.id == plan.monedaId)
                            .firstOrNull;
                        // La moneda real del plan; nunca un «$» fijo.
                        final symbol =
                            planCurrency?.symbol?.trim().isNotEmpty == true
                            ? planCurrency!.symbol!.trim()
                            : '${planCurrency?.code ?? ''} ';
                        final remaining = _amountDueFor(plan) - _totalPaid;
                        final isComplete = remaining <= 0.001;
                        final isOverpaid = remaining < -0.001;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const PulsoLabel('Total cobrado'),
                            Text(
                              '$symbol${_totalCollected.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontFamily: PulsoFonts.display,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: t.chalk,
                              ),
                            ),
                            Text(
                              'Al plan: $symbol${_totalPaid.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontFamily: PulsoFonts.mono,
                                fontSize: 10,
                                color: t.muted,
                              ),
                            ),
                            if (isOverpaid)
                              Text(
                                'Cambio: $symbol${remaining.abs().toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontFamily: PulsoFonts.mono,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: t.warning,
                                ),
                              )
                            else if (isComplete)
                              Text(
                                '¡Completado!',
                                style: TextStyle(
                                  fontFamily: PulsoFonts.mono,
                                  fontSize: 11,
                                  color: t.success,
                                ),
                              )
                            else
                              Text(
                                'Faltan $symbol${remaining.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontFamily: PulsoFonts.mono,
                                  fontSize: 11,
                                  color: t.danger,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(width: 48 + 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _colHeader(
    String text,
    int flex, {
    String? subtext,
    TextAlign align = TextAlign.left,
  }) {
    final t = PulsoTokens.of(context);
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: align == TextAlign.right
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          PulsoLabel(text),
          if (subtext != null)
            Text(
              subtext,
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontSize: 9,
                color: t.muted2,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(int index, Map<String, dynamic> row) {
    final plansState = ref.read(paymentPlanProvider);
    // Safe access to plan
    final plans = plansState.asData?.value ?? [];
    final plan = plans.firstWhere(
      (p) => p.id == widget.planId,
      orElse: () => PaymentPlanModel(
        id: '',
        nombre: '',
        importe: 0,
        duracion: 0,
        monedaId: '',
      ),
    );

    // If plan not loaded yet, show loader? Or default to empty currency which avoids crash but limits functionality
    if (plan.id == null || plan.id!.isEmpty) return const SizedBox();

    return PaymentRowItem(
      key: ValueKey('row_$index'),
      planCurrencyId: plan.monedaId,
      initialData: row,
      onChanged: (data) {
        setState(() {
          _paymentRows[index] = data;
        });
      },
      onDelete: () {
        setState(() {
          _paymentRows.removeAt(index);
        });
      },
    );
  }

  Widget _buildStickyFooter() {
    final t = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      decoration: BoxDecoration(
        color: t.raised,
        border: Border(top: BorderSide(color: t.lineStrong)),
      ),
      child: Builder(
        builder: (context) {
          final plans = ref.watch(paymentPlanProvider).value ?? [];
          final plan = plans.firstWhere(
            (p) => p.id == widget.planId,
            orElse: () => PaymentPlanModel(
              id: '',
              nombre: '',
              importe: 0,
              duracion: 0,
              monedaId: '',
            ),
          );
          final rawRemaining = _amountDueFor(plan) - _totalPaid;
          final remaining = math.max(0.0, rawRemaining);
          // Condonar sin motivo no puede confirmarse (docs/RECARGO_MORA.md §6-bis).
          final condonacionValida =
              !_condonarRecargoMora || _motivoCondonacionValido;
          final isComplete =
              rawRemaining <= 0.001 &&
              _paymentRows.isNotEmpty &&
              condonacionValida &&
              (_cuotaFija || _porCuotas || _discountQuote != null);
          final status = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              PulsoLabel(
                isComplete ? 'COBRO COMPLETO' : 'PENDIENTE DE COMPLETAR',
                color: isComplete ? t.success : t.warning,
              ),
              const SizedBox(height: 2),
              Text(
                isComplete
                    ? '${_paymentRows.length} ${_paymentRows.length == 1 ? 'forma de pago lista' : 'formas de pago listas'}'
                    : 'Faltan ${remaining.toStringAsFixed(2)} en la moneda del plan',
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 10.5,
                  color: t.muted,
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PulsoSecondaryButton(
                label: 'Cancelar',
                onPressed: () => Navigator.pop(context),
              ),
              PulsoPrimaryButton(
                label: 'Confirmar pago',
                icon: Icons.check,
                busy: _isLoading,
                onPressed: isComplete ? _processPayment : null,
              ),
            ],
          );
          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    status,
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: status),
                  const SizedBox(width: 16),
                  actions,
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _addPaymentRow() {
    setState(() {
      _paymentRows.add({});
    });
  }
}
