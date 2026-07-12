import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../financials/data/models/currency_model.dart';
import '../../../financials/presentation/state/currency_notifier.dart';
import '../../data/models/payment_plan_model.dart';

typedef PaymentPlanPulsoSubmit = Future<void> Function(PaymentPlanModel plan);

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

  String? _currencyId;
  String _durationUnit = 'months';
  bool _active = true;
  bool _includesTrainer = false;
  String _commissionType = 'NONE';
  bool _busy = false;
  String? _error;

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
    _currencyId = plan?.monedaId.isNotEmpty == true ? plan!.monedaId : null;
    _active = plan?.activo ?? true;
    _includesTrainer = plan?.incluyeEntrenador ?? false;
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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _durationController.dispose();
    _commissionController.dispose();
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

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    if (_currencyId == null) {
      setState(() => _error = 'Selecciona la moneda de cobro.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
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
      gymId: widget.plan?.gymId ?? '123',
    );
    try {
      await widget.onSubmit(plan);
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
                              onPressed: _submit,
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
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [amount, const SizedBox(height: 16), currency],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: amount),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: currency),
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
