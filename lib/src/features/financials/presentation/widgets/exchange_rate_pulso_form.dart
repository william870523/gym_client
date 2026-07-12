import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/currency_model.dart';
import '../../data/models/exchange_rate_model.dart';
import '../state/currency_notifier.dart';

/// Alta y modificación de tasas en PULSO. Mantiene el contrato original:
/// `onSubmit(Map<String, dynamic>)` con las mismas claves de la API y fechas
/// de calendario normalizadas a medianoche UTC (`calendarDateToUtc`).
class ExchangeRatePulsoForm extends ConsumerStatefulWidget {
  const ExchangeRatePulsoForm({
    super.key,
    this.initialData,
    this.initialBaseCurrencyId,
    this.initialTargetCurrencyId,
    this.initialRate,
    required this.onSubmit,
  });

  final ExchangeRateModel? initialData;
  final String? initialBaseCurrencyId;
  final String? initialTargetCurrencyId;

  /// Tasa de partida para altas precargadas (renovar una tasa vencida).
  final double? initialRate;
  final Future<void> Function(Map<String, dynamic> data) onSubmit;

  @override
  ConsumerState<ExchangeRatePulsoForm> createState() =>
      _ExchangeRatePulsoFormState();
}

class _ExchangeRatePulsoFormState extends ConsumerState<ExchangeRatePulsoForm> {
  final _formKey = GlobalKey<FormState>();
  final _rateController = TextEditingController();

  String? _baseId;
  String? _targetId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _activo = true;
  bool _busy = false;
  String? _error;

  static final _dateFmt = DateFormat('yyyy-MM-dd');

  bool get _isEdit => widget.initialData != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialData;
    if (initial != null) {
      _rateController.text = initial.exchangeRate.toString();
      _baseId = initial.monedaIdBase;
      _targetId = initial.monedaIdTarget;
      _activo = initial.activo;
      _startDate = initial.fechaInicio;
      _endDate = initial.fechaExpiracion;
    } else {
      _baseId = widget.initialBaseCurrencyId;
      _targetId = widget.initialTargetCurrencyId == widget.initialBaseCurrencyId
          ? null
          : widget.initialTargetCurrencyId;
      if (widget.initialRate != null) {
        _rateController.text = widget.initialRate.toString();
      }
      _startDate = todayInZone(appClock.gymTimezone);
    }
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  // Las fechas de vigencia son fechas de calendario (medianoche UTC); se
  // muestran por componentes, sin conversión de zona.
  String _fmtDate(DateTime? date) =>
      date == null ? '' : _dateFmt.format(date.toUtc());

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          (isStart ? _startDate : (_endDate ?? _startDate)) ??
          todayInZone(appClock.gymTimezone),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    if (_baseId == null || _targetId == null) {
      setState(() => _error = 'Selecciona la moneda base y la de destino.');
      return;
    }
    if (_baseId == _targetId) {
      setState(
        () => _error = 'La moneda base y la de destino no pueden ser la misma.',
      );
      return;
    }
    if (_startDate == null) {
      setState(() => _error = 'Indica desde cuándo rige la tasa.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final data = <String, dynamic>{
      'moneda_id_base': _baseId,
      'moneda_id_target': _targetId,
      'exchange_rate': double.parse(_rateController.text),
      'fecha_inicio': calendarDateToUtc(_startDate!).toIso8601String(),
      // Se envía siempre: null persiste "sin vencimiento" al editar.
      'fecha_expiracion': _endDate == null
          ? null
          : calendarDateToUtc(_endDate!).toIso8601String(),
      'activo': _activo,
    };
    if (widget.initialData != null) {
      data['tipo_cambio_id'] = widget.initialData!.id;
    }
    try {
      await widget.onSubmit(data);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo guardar el tipo de cambio: $error';
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
                            const PulsoLabel('PULSO · FINANZAS'),
                            const SizedBox(height: 9),
                            Text(
                              _isEdit
                                  ? 'EDITAR TIPO DE CAMBIO'
                                  : 'NUEVO TIPO DE CAMBIO',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'La tasa se aplica a pagos y reportes desde su fecha de vigencia.',
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
                            const PulsoLabel('Par de divisas'),
                            const SizedBox(height: 12),
                            _buildPairFields(context),
                            const SizedBox(height: 24),
                            const PulsoLabel('Tasa y vigencia'),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey('pulso-rate-value'),
                              controller: _rateController,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'),
                                ),
                              ],
                              style: const TextStyle(
                                fontFamily: PulsoFonts.mono,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Tasa de cambio',
                                hintText: '0.0000',
                                helperText:
                                    'Cuántas unidades de destino vale 1 unidad base.',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Campo obligatorio.';
                                }
                                final parsed = double.tryParse(value);
                                if (parsed == null || parsed <= 0) {
                                  return 'Ingresa una tasa válida.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildDateFields(context),
                            const SizedBox(height: 24),
                            const PulsoLabel('Disponibilidad operativa'),
                            const SizedBox(height: 12),
                            _buildStatusField(tokens),
                            if (_isEdit) ...[
                              const SizedBox(height: 18),
                              Text(
                                'ID · ${widget.initialData!.id}',
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

  // Recibe el contexto del Builder interno: los tokens viven bajo el
  // PulsoThemeScope del propio formulario, no sobre el State del diálogo.
  Widget _buildPairFields(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final currenciesState = ref.watch(currencyProvider);
    return currenciesState.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (error, _) => Text(
        'No se pudo cargar el catálogo de monedas: $error',
        style: TextStyle(color: tokens.danger, fontSize: 12),
      ),
      data: (currencies) {
        final base = _buildCurrencyDropdown(
          key: const ValueKey('pulso-rate-base'),
          label: 'Moneda base',
          value: _baseId,
          currencies: currencies,
          onChanged: (value) => setState(() {
            _baseId = value;
            if (_targetId == value) _targetId = null;
          }),
        );
        final target = _buildCurrencyDropdown(
          // La clave incluye la base: al cambiarla, el selector de destino se
          // reconstruye con la lista filtrada y la selección vigente.
          key: ValueKey('pulso-rate-target-$_baseId'),
          label: 'Moneda destino',
          value: _targetId,
          currencies: [
            for (final currency in currencies)
              if (currency.id != _baseId) currency,
          ],
          onChanged: (value) => setState(() => _targetId = value),
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 480) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [base, const SizedBox(height: 16), target],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: base),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '→',
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 16,
                      color: tokens.accent,
                    ),
                  ),
                ),
                Expanded(child: target),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCurrencyDropdown({
    required Key key,
    required String label,
    required String? value,
    required List<CurrencyModel> currencies,
    required ValueChanged<String?> onChanged,
  }) {
    final known = currencies.any((currency) => currency.id == value);
    return DropdownButtonFormField<String>(
      key: key,
      initialValue: known ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final currency in currencies)
          DropdownMenuItem(
            value: currency.id,
            child: _CurrencyOption(currency: currency),
          ),
      ],
      validator: (selection) =>
          selection == null ? 'Selecciona una divisa.' : null,
      onChanged: _busy ? null : onChanged,
    );
  }

  Widget _buildDateFields(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final start = TextFormField(
      key: ValueKey('pulso-rate-start-${_fmtDate(_startDate)}'),
      initialValue: _fmtDate(_startDate),
      readOnly: true,
      onTap: _busy ? null : () => _pickDate(true),
      style: const TextStyle(
        fontFamily: PulsoFonts.mono,
        fontWeight: FontWeight.w600,
      ),
      decoration: const InputDecoration(
        labelText: 'Vigente desde',
        hintText: 'aaaa-mm-dd',
        suffixIcon: Icon(Icons.event_outlined, size: 18),
      ),
      validator: (value) =>
          value == null || value.isEmpty ? 'Campo obligatorio.' : null,
    );
    final end = TextFormField(
      key: ValueKey('pulso-rate-end-${_fmtDate(_endDate)}'),
      initialValue: _endDate == null ? '' : _fmtDate(_endDate),
      readOnly: true,
      onTap: _busy ? null : () => _pickDate(false),
      style: const TextStyle(
        fontFamily: PulsoFonts.mono,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: 'Expira (opcional)',
        hintText: 'sin vencimiento',
        suffixIcon: _endDate == null
            ? const Icon(Icons.event_outlined, size: 18)
            : IconButton(
                tooltip: 'Quitar vencimiento',
                icon: Icon(Icons.close, size: 18, color: tokens.muted),
                onPressed: _busy
                    ? null
                    : () => setState(() => _endDate = null),
              ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [start, const SizedBox(height: 16), end],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: start),
            const SizedBox(width: 16),
            Expanded(child: end),
          ],
        );
      },
    );
  }

  Widget _buildStatusField(PulsoTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _activo ? tokens.successSoft : tokens.raised,
        border: Border.all(color: _activo ? tokens.success : tokens.line),
      ),
      child: Row(
        children: [
          Icon(
            _activo ? Icons.check_circle_outline : Icons.pause_circle_outline,
            color: _activo ? tokens.success : tokens.muted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activo ? 'Activo' : 'Inactivo',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tokens.chalk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _activo
                      ? 'La tasa participa en conversiones y cobros.'
                      : 'La tasa queda apagada sin borrar su historial.',
                  style: TextStyle(color: tokens.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _activo,
            activeThumbColor: tokens.success,
            onChanged: _busy
                ? null
                : (value) => setState(() => _activo = value),
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
