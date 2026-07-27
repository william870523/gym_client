import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../financials/data/models/currency_model.dart';
import '../../../financials/presentation/state/currency_notifier.dart';
import '../../data/models/payment_plan_model.dart';
import '../../data/repositories/payment_plan_repository.dart';

/// Devuelve el plan persistido cuando el guardado lo produce (alta); el
/// formulario usa su id para guardar el esquema de cuotas de planes nuevos.
typedef PaymentPlanPulsoSubmit =
    Future<PaymentPlanModel?> Function(PaymentPlanModel plan);

class PaymentPlanPulsoForm extends ConsumerStatefulWidget {
  const PaymentPlanPulsoForm({super.key, this.plan, required this.onSubmit});

  final PaymentPlanModel? plan;
  final PaymentPlanPulsoSubmit onSubmit;

  @override
  ConsumerState<PaymentPlanPulsoForm> createState() =>
      _PaymentPlanPulsoFormState();
}

class _PaymentPlanPulsoFormState extends ConsumerState<PaymentPlanPulsoForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _durationController;
  late final TextEditingController _commissionController;
  // R5.3: código corto (PMV, TCN...) y excepción de precio para cliente VIEJO.
  late final TextEditingController _codigoController;
  late final TextEditingController _precioViejoController;
  // Recargo por mora (docs/RECARGO_MORA.md): valor y tope del modo elegido.
  late final TextEditingController _recargoValorController;
  late final TextEditingController _recargoTopeController;

  String? _currencyId;
  String _durationUnit = 'months';
  bool _active = true;
  bool _includesTrainer = false;
  bool _aceptaCuotas = false;
  String _commissionType = 'NONE';
  // Recargo por mora: modo elegido (null = sin recargo) y estado activo.
  String? _recargoModo;
  bool _recargoActivo = false;
  bool _busy = false;
  String? _error;
  List<_CuotaDraft> _cuotasDraft = [];

  bool get _isEdit => widget.plan != null;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _nameController = TextEditingController(text: plan?.nombre);
    _amountController = TextEditingController(
      text: plan == null ? '' : plan.importe.toString(),
    );
    _commissionController = TextEditingController(
      text: plan?.comisionEntrenadorValor?.toString() ?? '',
    );
    _codigoController = TextEditingController(text: plan?.codigo ?? '');
    _precioViejoController = TextEditingController(
      text: plan?.precioViejoExcepcion?.toString() ?? '',
    );
    _recargoValorController = TextEditingController(
      text: plan?.recargoMoraValor ?? '',
    );
    _recargoTopeController = TextEditingController(
      text: plan?.recargoMoraTope ?? '',
    );
    _recargoModo = plan?.recargoMoraModo;
    _recargoActivo = plan?.recargoMoraActivo ?? false;
    _currencyId = plan?.monedaId.isNotEmpty == true ? plan!.monedaId : null;
    _active = plan?.activo ?? true;
    _includesTrainer = plan?.incluyeEntrenador ?? false;
    _aceptaCuotas = plan?.aceptaCuotas ?? false;
    _commissionType = plan?.comisionEntrenadorTipo ?? 'NONE';

    // Misma descomposición de duración que el catálogo (año/mes/semana/día).
    final duration = plan?.duracion ?? 30;
    if (duration == 365) {
      _durationController = TextEditingController(text: '1');
      _durationUnit = 'years';
    } else if (duration > 0 && duration % 30 == 0) {
      _durationController = TextEditingController(
        text: (duration ~/ 30).toString(),
      );
      _durationUnit = 'months';
    } else if (duration > 0 && duration % 7 == 0) {
      _durationController = TextEditingController(
        text: (duration ~/ 7).toString(),
      );
      _durationUnit = 'weeks';
    } else {
      _durationController = TextEditingController(text: duration.toString());
      _durationUnit = 'days';
    }

    if (_aceptaCuotas) {
      _loadCuotasScheme();
    }
  }

  Future<void> _loadCuotasScheme() async {
    final planId = widget.plan?.id;
    if (planId != null && planId.isNotEmpty) {
      try {
        final repo = ref.read(paymentPlanRepositoryProvider);
        final scheme = await repo.getPlanCuotasScheme(planId);
        if (scheme.isNotEmpty && mounted) {
          setState(() {
            _cuotasDraft = scheme
                .map((e) => _CuotaDraft(
                      numeroCuota: ((e['numero_cuota'] ?? e['numeroCuota']) as num?)?.toInt() ?? 1,
                      importe: (e['importe'] as num?)?.toDouble() ?? 0.0,
                      dias: ((e['dias_cobertura'] ?? e['diasCobertura']) as num?)?.toInt() ?? 0,
                    ))
                .toList();
          });
          return;
        }
      } catch (_) {}
    }
    // Fallback/Default cuotas draft for new plan with cuotas
    if (_cuotasDraft.isEmpty && mounted) {
      final totalAmount = double.tryParse(_amountController.text.trim()) ?? 25.0;
      final totalDays = _durationInDays();
      final halfAmount = (totalAmount / 2 * 100).round() / 100;
      final remAmount = ((totalAmount - halfAmount) * 100).round() / 100;
      final halfDays = totalDays ~/ 3 > 0 ? totalDays ~/ 3 : 30;
      final remDays = totalDays - halfDays > 0 ? totalDays - halfDays : 60;

      setState(() {
        _cuotasDraft = [
          _CuotaDraft(numeroCuota: 1, importe: halfAmount > 0 ? halfAmount : 15.0, dias: halfDays),
          _CuotaDraft(numeroCuota: 2, importe: remAmount > 0 ? remAmount : 10.0, dias: remDays),
        ];
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _durationController.dispose();
    _commissionController.dispose();
    _codigoController.dispose();
    _precioViejoController.dispose();
    _recargoValorController.dispose();
    _recargoTopeController.dispose();
    for (final c in _cuotasDraft) {
      c.dispose();
    }
    super.dispose();
  }

  int _durationInDays() {
    final value = int.tryParse(_durationController.text) ?? 0;
    return switch (_durationUnit) {
      'years' => value * 365,
      'months' => value * 30,
      'weeks' => value * 7,
      _ => value,
    };
  }

  double get _cuotasSumAmount =>
      _cuotasDraft.fold(0.0, (sum, c) => sum + c.amount);

  int get _cuotasSumDays => _cuotasDraft.fold(0, (sum, c) => sum + c.days);

  double get _targetAmount =>
      double.tryParse(_amountController.text.trim()) ?? 0.0;

  /// El botón de guardar solo se habilita con el esquema cuadrado: cada cuota
  /// con importe y días positivos, y las sumas iguales a la tarifa del plan.
  bool get _schemeReady {
    if (!_aceptaCuotas) return true;
    if (_cuotasDraft.isEmpty) return false;
    if (_cuotasDraft.any((c) => c.amount <= 0 || c.days <= 0)) return false;
    return (_cuotasSumAmount - _targetAmount).abs() < 0.01 &&
        _cuotasSumDays == _durationInDays();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    if (_currencyId == null) {
      setState(() => _error = 'Selecciona la moneda de cobro.');
      return;
    }

    if (_aceptaCuotas && _cuotasDraft.isNotEmpty) {
      final sumAmount = _cuotasDraft.fold(0.0, (sum, c) => sum + c.amount);
      final sumDays = _cuotasDraft.fold(0, (sum, c) => sum + c.days);
      final targetAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      final targetDays = _durationInDays();

      final amountOk = (sumAmount - targetAmount).abs() < 0.01;
      final daysOk = sumDays == targetDays;

      if (!amountOk || !daysOk) {
        setState(() {
          _error = 'El esquema de cuotas (€${sumAmount.toStringAsFixed(2)} / ${sumDays}d) no coincide con la tarifa del plan (€${targetAmount.toStringAsFixed(2)} / ${targetDays}d).';
        });
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final codigo = _codigoController.text.trim();
    final precioViejoText = _precioViejoController.text.trim();
    // Recargo por mora: sin modo se limpia toda la config; el servidor la
    // revalida (importes como string decimal con punto).
    final recargoValor = _recargoValorController.text.trim().replaceAll(',', '.');
    final recargoTope = _recargoTopeController.text.trim().replaceAll(',', '.');
    final hasRecargo = _recargoModo != null;
    final plan = PaymentPlanModel(
      id: widget.plan?.id,
      nombre: _nameController.text.trim(),
      importe: double.tryParse(_amountController.text) ?? 0.0,
      duracion: _durationInDays(),
      monedaId: _currencyId!,
      activo: _active,
      incluyeEntrenador: _includesTrainer,
      comisionEntrenadorTipo: _includesTrainer ? _commissionType : 'NONE',
      comisionEntrenadorValor: _includesTrainer
          ? double.tryParse(_commissionController.text)
          : null,
      aceptaCuotas: _aceptaCuotas,
      codigo: codigo.isEmpty ? null : codigo,
      precioViejoExcepcion: precioViejoText.isEmpty
          ? null
          : double.tryParse(precioViejoText.replaceAll(',', '.')),
      recargoMoraModo: hasRecargo ? _recargoModo : null,
      recargoMoraValor: hasRecargo && recargoValor.isNotEmpty ? recargoValor : null,
      recargoMoraTope: hasRecargo && _recargoModo == 'POR_DIA' && recargoTope.isNotEmpty
          ? recargoTope
          : null,
      recargoMoraActivo: hasRecargo && _recargoActivo,
      gymId: widget.plan?.gymId ?? '123',
    );
    try {
      final saved = await widget.onSubmit(plan);
      // En un alta el id lo genera el servidor y llega en el plan devuelto.
      final targetPlanId = widget.plan?.id ?? saved?.id;
      if (_aceptaCuotas && targetPlanId != null && targetPlanId.isNotEmpty && _cuotasDraft.isNotEmpty) {
        final repo = ref.read(paymentPlanRepositoryProvider);
        final tranches = _cuotasDraft
            .asMap()
            .entries
            .map((e) => {
                  'numeroCuota': e.key + 1,
                  'numero_cuota': e.key + 1,
                  'importe': e.value.amount,
                  'diasCobertura': e.value.days,
                  'dias_cobertura': e.value.days,
                  'orden': e.key + 1,
                })
            .toList();
        await repo.savePlanCuotasScheme(targetPlanId, tranches);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo guardar el plan: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PulsoThemeScope(
      child: Builder(
        builder: (context) {
          final tokens = PulsoTokens.of(context);
          final screen = MediaQuery.sizeOf(context);
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 620,
                maxHeight: screen.height - 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(height: 4, color: tokens.accent),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 20, 18),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final copy = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const PulsoLabel('PULSO · TARIFAS'),
                            const SizedBox(height: 9),
                            Text(
                              _isEdit ? 'EDITAR PLAN' : 'NUEVO PLAN',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Define la tarifa, su vigencia en días y la moneda de cobro.',
                              style: TextStyle(
                                color: tokens.muted,
                                fontSize: 13,
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
                              onPressed: _busy
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                            ),
                            PulsoPrimaryButton(
                              label: _isEdit ? 'Guardar cambios' : 'Crear',
                              // Con cuotas descuadradas no se puede guardar.
                              onPressed: _schemeReady ? _submit : null,
                              busy: _busy,
                            ),
                          ],
                        );
                        if (constraints.maxWidth < 520) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              copy,
                              const SizedBox(height: 18),
                              actions,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: copy),
                            const SizedBox(width: 18),
                            actions,
                          ],
                        );
                      },
                    ),
                  ),
                  Divider(height: 1, color: tokens.line),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                color: tokens.dangerSoft,
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: tokens.danger,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            const PulsoLabel('Identidad del plan'),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey('pulso-plan-name'),
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Nombre del plan',
                                hintText: 'Ej. Membresía mensual',
                              ),
                              validator: _required,
                            ),
                            const SizedBox(height: 12),
                            // R5.3: código corto de recepción (PMV, TCN...).
                            TextFormField(
                              key: const ValueKey('pulso-plan-codigo'),
                              controller: _codigoController,
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Código corto (opcional)',
                                hintText: 'Ej. PMV, TCN…',
                                helperText:
                                    'Sigla que usa recepción; la cuota añade /1, /2, /3.',
                              ),
                            ),
                            const SizedBox(height: 24),
                            const PulsoLabel('Tarifa'),
                            const SizedBox(height: 12),
                            _buildPriceFields(context),
                            const SizedBox(height: 16),
                            _buildDurationFields(context),
                            const SizedBox(height: 24),
                            const PulsoLabel('Entrenador'),
                            const SizedBox(height: 12),
                            _buildTrainerField(context),
                            if (_includesTrainer) ...[
                              const SizedBox(height: 16),
                              _buildCommissionFields(context),
                            ],
                            const SizedBox(height: 24),
                            const PulsoLabel('Pago por cuotas'),
                            const SizedBox(height: 12),
                            _buildInstallmentsField(context),
                            const SizedBox(height: 24),
                            const PulsoLabel('Recargo por mora'),
                            const SizedBox(height: 12),
                            _buildRecargoMoraField(context),
                            const SizedBox(height: 24),
                            const PulsoLabel('Disponibilidad operativa'),
                            const SizedBox(height: 12),
                            _buildStatusField(context),
                            if (_isEdit && widget.plan?.id != null) ...[
                              const SizedBox(height: 18),
                              Text(
                                'ID · ${widget.plan!.id}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: PulsoFonts.mono,
                                  fontSize: 10,
                                  color: tokens.muted2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPriceFields(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final amount = TextFormField(
      key: const ValueKey('pulso-plan-amount'),
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      style: const TextStyle(
        fontFamily: PulsoFonts.mono,
        fontWeight: FontWeight.w600,
      ),
      decoration: const InputDecoration(labelText: 'Importe', hintText: '0.00'),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Campo obligatorio.';
        final parsed = double.tryParse(value);
        if (parsed == null || parsed <= 0) return 'Ingresa un importe válido.';
        return null;
      },
    );
    final currenciesState = ref.watch(currencyProvider);
    final currency = currenciesState.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (error, _) => Text(
        'No se pudo cargar el catálogo de monedas: $error',
        style: TextStyle(color: tokens.danger, fontSize: 12),
      ),
      data: (currencies) {
        final known = currencies.any((c) => c.id == _currencyId);
        return DropdownButtonFormField<String>(
          key: const ValueKey('pulso-plan-currency'),
          initialValue: known ? _currencyId : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Moneda de cobro'),
          items: [
            for (final currency in currencies)
              DropdownMenuItem(
                value: currency.id,
                child: _CurrencyOption(currency: currency),
              ),
          ],
          validator: (value) =>
              value == null ? 'Selecciona una divisa.' : null,
          onChanged: _busy
              ? null
              : (value) => setState(() => _currencyId = value),
        );
      },
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // R5.3: precio fijo opcional para cliente VIEJO. Si está vacío, se
        // aplica el % global configurado en Configuración del Sistema.
        final precioViejo = TextFormField(
          key: const ValueKey('pulso-plan-precio-viejo'),
          controller: _precioViejoController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          style: const TextStyle(
            fontFamily: PulsoFonts.mono,
            fontWeight: FontWeight.w600,
          ),
          decoration: const InputDecoration(
            labelText: 'Precio fijo VIEJO (opcional)',
            hintText: '0.00',
            helperText:
                'Anula el % global para este plan. Vacío = usar % global.',
          ),
        );
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              amount,
              const SizedBox(height: 16),
              currency,
              const SizedBox(height: 16),
              precioViejo,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: amount),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: currency),
              ],
            ),
            const SizedBox(height: 16),
            precioViejo,
          ],
        );
      },
    );
  }

  Widget _buildDurationFields(BuildContext context) {
    final amount = TextFormField(
      key: const ValueKey('pulso-plan-duration'),
      controller: _durationController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        fontFamily: PulsoFonts.mono,
        fontWeight: FontWeight.w600,
      ),
      decoration: const InputDecoration(
        labelText: 'Duración',
        hintText: 'Ej. 1, 30',
      ),
      validator: (value) {
        final parsed = int.tryParse(value ?? '');
        if (parsed == null || parsed <= 0) return 'Ingresa una duración.';
        return null;
      },
    );
    final unit = DropdownButtonFormField<String>(
      key: const ValueKey('pulso-plan-duration-unit'),
      initialValue: _durationUnit,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Unidad'),
      items: const [
        DropdownMenuItem(value: 'days', child: Text('Días')),
        DropdownMenuItem(value: 'weeks', child: Text('Semanas')),
        DropdownMenuItem(value: 'months', child: Text('Meses')),
        DropdownMenuItem(value: 'years', child: Text('Años')),
      ],
      onChanged: _busy
          ? null
          : (value) => setState(() => _durationUnit = value ?? 'months'),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: amount),
        const SizedBox(width: 16),
        Expanded(flex: 3, child: unit),
      ],
    );
  }

  Widget _buildTrainerField(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _includesTrainer ? tokens.accentSoft : tokens.raised,
        border: Border.all(
          color: _includesTrainer ? tokens.accent : tokens.line,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.fitness_center_outlined,
            color: _includesTrainer ? tokens.accent : tokens.muted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan con entrenador',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tokens.chalk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _includesTrainer
                      ? 'Incluye entrenador y comisión por cobro.'
                      : 'Sin entrenador asignado al plan.',
                  style: TextStyle(color: tokens.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _includesTrainer,
            activeThumbColor: tokens.accent,
            onChanged: _busy
                ? null
                : (value) => setState(() {
                    _includesTrainer = value;
                    if (!value) {
                      _commissionType = 'NONE';
                      _commissionController.clear();
                    } else if (_commissionType == 'NONE') {
                      _commissionType = 'PERCENTAGE';
                    }
                  }),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionFields(BuildContext context) {
    final type = DropdownButtonFormField<String>(
      key: const ValueKey('pulso-plan-commission-type'),
      initialValue: _commissionType == 'NONE' ? 'PERCENTAGE' : _commissionType,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Tipo de comisión'),
      items: const [
        DropdownMenuItem(value: 'PERCENTAGE', child: Text('Porcentaje')),
        DropdownMenuItem(value: 'FIXED_AMOUNT', child: Text('Monto fijo')),
      ],
      onChanged: _busy
          ? null
          : (value) => setState(() => _commissionType = value ?? 'PERCENTAGE'),
    );
    final value = TextFormField(
      key: const ValueKey('pulso-plan-commission-value'),
      controller: _commissionController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      style: const TextStyle(
        fontFamily: PulsoFonts.mono,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: 'Valor',
        hintText: _commissionType == 'PERCENTAGE' ? 'Ej. 15' : 'Ej. 4.00',
      ),
      validator: (value) {
        if (!_includesTrainer) return null;
        final parsed = double.tryParse(value ?? '');
        if (parsed == null || parsed <= 0) return 'Ingresa la comisión.';
        return null;
      },
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: type),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: value),
      ],
    );
  }

  // Recargo por mora (docs/RECARGO_MORA.md): el administrador elige un modo,
  // configura su valor (y tope en POR_DIA) y decide si ya se aplica. El importe
  // exacto lo calcula el servidor al cobrar; aquí solo se define la política.
  Widget _buildRecargoMoraField(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final hasRecargo = _recargoModo != null;
    final esPorDia = _recargoModo == 'POR_DIA';

    final modo = DropdownButtonFormField<String>(
      key: const ValueKey('pulso-plan-recargo-modo'),
      initialValue: _recargoModo,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Modo de recargo'),
      items: const [
        DropdownMenuItem(value: null, child: Text('Sin recargo')),
        DropdownMenuItem(value: 'PORCENTAJE', child: Text('Porcentaje (%)')),
        DropdownMenuItem(value: 'MONTO_FIJO', child: Text('Monto fijo')),
        DropdownMenuItem(value: 'POR_DIA', child: Text('Monto por día de atraso')),
      ],
      onChanged: _busy
          ? null
          : (value) => setState(() {
                _recargoModo = value;
                if (value == null) _recargoActivo = false;
              }),
    );

    if (!hasRecargo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          modo,
          const SizedBox(height: 8),
          Text(
            'Este plan no cobra recargo al pagar con atraso.',
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 10.5,
              color: tokens.muted,
            ),
          ),
        ],
      );
    }

    final valor = TextFormField(
      key: const ValueKey('pulso-plan-recargo-valor'),
      controller: _recargoValorController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      style: const TextStyle(
        fontFamily: PulsoFonts.mono,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: _recargoModo == 'PORCENTAJE' ? 'Porcentaje' : 'Monto',
        hintText: _recargoModo == 'PORCENTAJE'
            ? 'Ej. 10'
            : esPorDia
                ? 'Por día. Ej. 1.50'
                : 'Ej. 5.00',
      ),
      validator: (value) {
        final parsed = double.tryParse((value ?? '').replaceAll(',', '.'));
        if (parsed == null || parsed <= 0) return 'Ingresa el valor del recargo.';
        if (_recargoModo == 'PORCENTAJE' && parsed > 100) {
          return 'El porcentaje va de 0 a 100.';
        }
        return null;
      },
    );

    final tope = TextFormField(
      key: const ValueKey('pulso-plan-recargo-tope'),
      controller: _recargoTopeController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      style: const TextStyle(
        fontFamily: PulsoFonts.mono,
        fontWeight: FontWeight.w600,
      ),
      decoration: const InputDecoration(
        labelText: 'Tope máximo (opcional)',
        hintText: 'Sin tope si se deja vacío',
      ),
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return null;
        final parsed = double.tryParse(text.replaceAll(',', '.'));
        if (parsed == null || parsed <= 0) return 'El tope debe ser mayor que cero.';
        return null;
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        modo,
        const SizedBox(height: 12),
        if (esPorDia)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: valor),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: tope),
            ],
          )
        else
          valor,
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border.all(
              color: _recargoActivo ? tokens.success : tokens.line,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aplicar recargo a partir de ahora',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: tokens.chalk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _recargoActivo
                          ? 'Recepción podrá cobrarlo en pagos atrasados.'
                          : 'Configurado pero inactivo: recepción no lo cobra aún.',
                      style: TextStyle(
                        fontFamily: PulsoFonts.mono,
                        fontSize: 10.5,
                        color: tokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                key: const ValueKey('pulso-plan-recargo-activo'),
                value: _recargoActivo,
                activeThumbColor: tokens.accent,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _recargoActivo = value),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusField(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _active ? tokens.successSoft : tokens.raised,
        border: Border.all(color: _active ? tokens.success : tokens.line),
      ),
      child: Row(
        children: [
          Icon(
            _active ? Icons.check_circle_outline : Icons.pause_circle_outline,
            color: _active ? tokens.success : tokens.muted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _active ? 'Activo' : 'Inactivo',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tokens.chalk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _active
                      ? 'Disponible al asignar planes y cobrar.'
                      : 'Oculto para nuevas asignaciones.',
                  style: TextStyle(color: tokens.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _active,
            activeThumbColor: tokens.success,
            onChanged: _busy
                ? null
                : (value) => setState(() => _active = value),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallmentsField(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: tokens.raised,
            border: Border.all(color: tokens.line),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_month_outlined, size: 20, color: tokens.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admite pago por cuotas',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: tokens.chalk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Permite al cliente abonar el plan en cuotas asimétricas.',
                      style: TextStyle(
                        fontFamily: PulsoFonts.mono,
                        fontSize: 10.5,
                        color: tokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                key: const ValueKey('pulso-plan-cuotas-toggle'),
                value: _aceptaCuotas,
                activeThumbColor: tokens.accent,
                onChanged: _busy
                    ? null
                    : (value) {
                        setState(() => _aceptaCuotas = value);
                        if (value && _cuotasDraft.isEmpty) {
                          _loadCuotasScheme();
                        }
                      },
              ),
            ],
          ),
        ),
        if (_aceptaCuotas) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.surface,
              border: Border.all(color: tokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DESGLOSE DE CUOTAS Y TRAMOS',
                      style: TextStyle(
                        fontFamily: PulsoFonts.mono,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: tokens.accent,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() {
                                _cuotasDraft.add(_CuotaDraft(
                                  numeroCuota: _cuotasDraft.length + 1,
                                  importe: 0,
                                  dias: 0,
                                ));
                              });
                            },
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text(
                        'Añadir cuota',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._cuotasDraft.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  // Restante tras esta cuota, para guiar el desglose sin
                  // pasarse de la tarifa ni de los días del plan.
                  var usedAmount = 0.0;
                  var usedDays = 0;
                  for (var i = 0; i <= idx; i++) {
                    usedAmount += _cuotasDraft[i].amount;
                    usedDays += _cuotasDraft[i].days;
                  }
                  final leftAmount = _targetAmount - usedAmount;
                  final leftDays = _durationInDays() - usedDays;
                  final overrun = leftAmount < -0.009 || leftDays < 0;
                  final hint = idx == _cuotasDraft.length - 1
                      ? (overrun
                            ? 'Se pasa por €${(-leftAmount).clamp(0, double.infinity).toStringAsFixed(2)} · ${(-leftDays).clamp(0, 100000)}d'
                            : null)
                      : 'Quedan €${leftAmount.toStringAsFixed(2)} · ${leftDays}d para las siguientes';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCuotaRow(tokens, idx, item),
                        if (hint != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 71, top: 2),
                            child: Text(
                              hint,
                              key: ValueKey('plan-cuota-hint-$idx'),
                              style: TextStyle(
                                fontFamily: PulsoFonts.mono,
                                fontSize: 9.5,
                                color: overrun ? tokens.danger : tokens.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 10),
                _buildCuotasValidationSummary(tokens),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCuotaRow(PulsoTokens tokens, int idx, _CuotaDraft item) {
    return Row(
                      children: [
                        SizedBox(
                          width: 65,
                          child: Text(
                            'Cuota #${idx + 1}',
                            style: TextStyle(
                              fontFamily: PulsoFonts.mono,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                              color: tokens.chalk,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextFormField(
                            controller: item.amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(fontSize: 12, color: tokens.chalk),
                            decoration: const InputDecoration(
                              labelText: 'Importe (€)',
                              hintText: '15.00',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextFormField(
                            controller: item.daysController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(fontSize: 12, color: tokens.chalk),
                            decoration: const InputDecoration(
                              labelText: 'Días Cobertura',
                              hintText: '30',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (_cuotasDraft.length > 1) ...[
                          const SizedBox(width: 2),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 18),
                            color: tokens.danger,
                            onPressed: _busy
                                ? null
                                : () {
                                    setState(() {
                                      final removed = _cuotasDraft.removeAt(idx);
                                      removed.dispose();
                                    });
                                  },
                          ),
                        ],
                      ],
                    );
  }

  Widget _buildCuotasValidationSummary(PulsoTokens tokens) {
    final sumAmount = _cuotasDraft.fold(0.0, (sum, c) => sum + c.amount);
    final sumDays = _cuotasDraft.fold(0, (sum, c) => sum + c.days);
    final targetAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final targetDays = _durationInDays();

    final amountOk = (sumAmount - targetAmount).abs() < 0.01;
    final daysOk = sumDays == targetDays;

    final isOk = amountOk && daysOk;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isOk
            ? tokens.success.withValues(alpha: 0.1)
            : tokens.danger.withValues(alpha: 0.1),
        border: Border.all(
          color: isOk ? tokens.success : tokens.danger,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOk ? Icons.check_circle : Icons.warning_amber_rounded,
                size: 16,
                color: isOk ? tokens.success : tokens.danger,
              ),
              const SizedBox(width: 6),
              Text(
                isOk ? 'Esquema de cuotas válido' : 'Revisar totales del esquema',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: isOk ? tokens.success : tokens.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Importe Total: €${sumAmount.toStringAsFixed(2)} / €${targetAmount.toStringAsFixed(2)} ${amountOk ? '✓' : '⚠️ Debe coincidir con la tarifa'}',
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 10.5,
              color: amountOk ? tokens.chalk : tokens.danger,
            ),
          ),
          Text(
            'Días Cobertura: ${sumDays}d / ${targetDays}d ${daysOk ? '✓' : '⚠️ Debe coincidir con los días del plan'}',
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 10.5,
              color: daysOk ? tokens.chalk : tokens.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _CuotaDraft {
  _CuotaDraft({
    required this.numeroCuota,
    required double importe,
    required int dias,
  })  : amountController = TextEditingController(
          text: importe > 0
              ? (importe % 1 == 0 ? importe.toInt().toString() : importe.toStringAsFixed(2))
              : '',
        ),
        daysController = TextEditingController(
          text: dias > 0 ? dias.toString() : '',
        );

  final int numeroCuota;
  final TextEditingController amountController;
  final TextEditingController daysController;

  double get amount => double.tryParse(amountController.text.trim()) ?? 0.0;
  int get days => int.tryParse(daysController.text.trim()) ?? 0;

  void dispose() {
    amountController.dispose();
    daysController.dispose();
  }
}

class _CurrencyOption extends StatelessWidget {
  const _CurrencyOption({required this.currency});
  final CurrencyModel currency;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Row(
      children: [
        PulsoFlag(
          code: currency.code,
          base64String: currency.flagImage,
          width: 27,
          height: 18,
        ),
        const SizedBox(width: 10),
        Text(
          currency.code.toUpperCase(),
          style: const TextStyle(
            fontFamily: PulsoFonts.mono,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            currency.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.chalkDim),
          ),
        ),
      ],
    );
  }
}

String? _required(String? value) {
  return value?.trim().isNotEmpty == true ? null : 'Campo obligatorio.';
}
