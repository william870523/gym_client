import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/payment_model.dart';
import '../../data/repositories/payment_repository.dart';

import '../../../financials/data/models/account_model.dart';
import '../../../configuration/data/models/payment_type_model.dart';
import '../../../clients/data/models/client_model.dart';
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

  const ProcessPaymentDialog({
    super.key,
    required this.client,
    required this.planId,
  });

  @override
  ConsumerState<ProcessPaymentDialog> createState() =>
      _ProcessPaymentDialogState();
}

class _ProcessPaymentDialogState extends ConsumerState<ProcessPaymentDialog> {
  // Static mock state
  final List<Map<String, dynamic>> _paymentRows = [];
  bool _isLoading = false;

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
        // El encabezado representa el precio aplicado al plan. Si recepción
        // recibe efectivo de más, el excedente es cambio de caja, no ingreso.
        amount:
            widget.client.membershipBalanceDue != null &&
                widget.client.membershipBalanceDue! > 0
            ? widget.client.membershipBalanceDue!
            : plan.importe,
        trainerId: widget.client.trainerId,
        planId: widget.planId,
        currencyId: plan.monedaId,
        membershipId: widget.client.membershipId,
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
        );
      }).toList();

      await ref.read(paymentRepositoryProvider).createPayment(payment, details);
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
        final currCode = account != null && account.currencyId.length <= 5
            ? account.currencyId.toUpperCase()
            : '';
        final currSuffix = currCode.isNotEmpty ? ' $currCode' : '';
        final planSuffix = surPlan != null && surPlan is num && surPlan > 0
            ? ' (+$planSymbol${surPlan.toDouble().toStringAsFixed(2)})'
            : '';
        details.add('$typeName$pctLabel: +${sur.toDouble().toStringAsFixed(2)}$currSuffix$planSuffix');
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
      if (account != null && rate != null && rate is num && rate > 0 && rate != 1.0) {
        final r = rate.toDouble();
        final currencyCode = account.currencyId.length > 5
            ? account.currencyId.substring(0, 5).toUpperCase()
            : account.currencyId.toUpperCase();
        final equiv = rateOp == 'divide' ? remaining * r : remaining / r;
        return '$text (~${equiv.toStringAsFixed(2)} $currencyCode)';
      }
    }
    return text;
  }

  double _amountDueFor(PaymentPlanModel plan) {
    final balance = widget.client.membershipBalanceDue;
    if (widget.client.membershipId != null && balance != null && balance > 0) {
      return balance;
    }
    return plan.importe;
  }

  String get _planLabel {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
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
                            ],
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (error, stackTrace) => const SizedBox.shrink(),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const PulsoLabel('Pagado'),
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
            ],
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progreso: ${(progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 11,
                          color: t.muted,
                        ),
                      ),
                      Container(
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
                      ),
                    ],
                  ),
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
                    _colHeader('CANTIDAD', 2),
                    const SizedBox(width: 8),
                    _colHeader('INFO / TASA', 3),
                    const SizedBox(width: 8),
                    _colHeader('EQUIVALENTE', 2, align: TextAlign.right),
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
                            const PulsoLabel('Total acumulado'),
                            Text(
                              '$symbol${_totalPaid.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontFamily: PulsoFonts.display,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: t.chalk,
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
          final isComplete = rawRemaining <= 0.001 && _paymentRows.isNotEmpty;
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
