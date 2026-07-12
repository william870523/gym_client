import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/registro_palette.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/app_flag.dart';
import '../../../../core/widgets/registro_widgets.dart';
import '../../data/models/currency_model.dart';
import '../../data/models/exchange_rate_model.dart';
import '../state/currency_notifier.dart';

/// Formulario de tipo de cambio — "F-05A" (sistema REGISTRO).
///
/// Alta y modificación de tasas. Mantiene el contrato original:
/// `onSubmit(Map<String, dynamic>)` con las mismas claves de la API.
class ExchangeRateForm extends ConsumerStatefulWidget {
  final ExchangeRateModel? initialData;
  final String? initialBaseCurrencyId;
  final String? initialTargetCurrencyId;
  final Function(Map<String, dynamic>) onSubmit;

  const ExchangeRateForm({
    super.key,
    this.initialData,
    this.initialBaseCurrencyId,
    this.initialTargetCurrencyId,
    required this.onSubmit,
  });

  @override
  ConsumerState<ExchangeRateForm> createState() => _ExchangeRateFormState();
}

class _ExchangeRateFormState extends ConsumerState<ExchangeRateForm> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _baseSearchController = TextEditingController();
  final TextEditingController _targetSearchController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _activo = true;
  bool _isLoading = false;
  String? _errorMessage;

  CurrencyModel? _selectedBase;
  CurrencyModel? _selectedTarget;
  bool _showBaseDropdown = false;
  bool _showTargetDropdown = false;
  List<CurrencyModel> _filteredBaseCurrencies = [];
  List<CurrencyModel> _filteredTargetCurrencies = [];
  bool _initialized = false;

  bool get _isEdit => widget.initialData != null;

  static final _dateFmt = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _rateController.text = widget.initialData!.exchangeRate.toString();
      _activo = widget.initialData!.activo;
      _startDate = widget.initialData!.fechaInicio;
      _endDate = widget.initialData!.fechaExpiracion;
    } else {
      _startDate = todayInZone(appClock.gymTimezone);
    }

    _startDateController.text = _startDate != null
        ? _dateFmt.format(_startDate!)
        : '';
    _endDateController.text = _endDate != null
        ? _dateFmt.format(_endDate!)
        : '';
  }

  @override
  void dispose() {
    _rateController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _baseSearchController.dispose();
    _targetSearchController.dispose();
    super.dispose();
  }

  // ===== selección de divisas =====
  void _filterBase(String query, List<CurrencyModel> all) {
    setState(() {
      _showBaseDropdown = true;
      if (query.isEmpty) {
        _filteredBaseCurrencies = all;
      } else {
        _filteredBaseCurrencies = all.where((c) {
          final q = query.toLowerCase();
          return c.name.toLowerCase().contains(q) ||
              c.code.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  void _filterTarget(String query, List<CurrencyModel> all) {
    setState(() {
      _showTargetDropdown = true;
      final candidates = _selectedBase == null
          ? all
          : all.where((c) => c.id != _selectedBase!.id).toList();

      if (query.isEmpty) {
        _filteredTargetCurrencies = candidates;
      } else {
        _filteredTargetCurrencies = candidates.where((c) {
          final q = query.toLowerCase();
          return c.name.toLowerCase().contains(q) ||
              c.code.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  void _selectBase(CurrencyModel c) {
    setState(() {
      _selectedBase = c;
      _baseSearchController.text = '${c.code} — ${c.name}';
      _showBaseDropdown = false;
      if (_selectedTarget?.id == c.id) {
        _selectedTarget = null;
        _targetSearchController.clear();
      }
    });
  }

  void _selectTarget(CurrencyModel c) {
    setState(() {
      _selectedTarget = c;
      _targetSearchController.text = '${c.code} — ${c.name}';
      _showTargetDropdown = false;
    });
  }

  void _initializeCurrencySelection(List<CurrencyModel> currencies) {
    if (widget.initialData != null) {
      try {
        _selectedBase = currencies.firstWhere(
          (c) => c.id == widget.initialData!.monedaIdBase,
        );
        _baseSearchController.text =
            '${_selectedBase!.code} — ${_selectedBase!.name}';

        _selectedTarget = currencies.firstWhere(
          (c) => c.id == widget.initialData!.monedaIdTarget,
        );
        _targetSearchController.text =
            '${_selectedTarget!.code} — ${_selectedTarget!.name}';
      } catch (_) {}
      return;
    }

    final baseId = widget.initialBaseCurrencyId;
    if (baseId != null && baseId.isNotEmpty) {
      try {
        _selectedBase = currencies.firstWhere((c) => c.id == baseId);
        _baseSearchController.text =
            '${_selectedBase!.code} — ${_selectedBase!.name}';
      } catch (_) {}
    }

    final targetId = widget.initialTargetCurrencyId;
    if (targetId != null &&
        targetId.isNotEmpty &&
        targetId != _selectedBase?.id) {
      try {
        _selectedTarget = currencies.firstWhere((c) => c.id == targetId);
        _targetSearchController.text =
            '${_selectedTarget!.code} — ${_selectedTarget!.name}';
      } catch (_) {}
    }
  }

  // ===== fechas =====
  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final p = RegistroPalette.fromContext(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          (isStart ? _startDate : (_endDate ?? _startDate)) ??
          todayInZone(appClock.gymTimezone),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        final scheme = p.isNight
            ? ColorScheme.dark(
                primary: p.verm,
                onPrimary: p.paper,
                surface: p.paper2,
                onSurface: p.ink,
              )
            : ColorScheme.light(
                primary: p.verm,
                onPrimary: p.paper,
                surface: p.paper,
                onSurface: p.ink,
              );
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: scheme,
            datePickerTheme: DatePickerThemeData(
              backgroundColor: p.paper,
              shape: Border(top: BorderSide(color: p.verm, width: 3)),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          _startDateController.text = _dateFmt.format(picked);
        } else {
          _endDate = picked;
          _endDateController.text = _dateFmt.format(picked);
        }
      });
    }
  }

  // ===== guardar =====
  Future<void> _submit() async {
    if (_isLoading || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_selectedBase == null || _selectedTarget == null) {
      setState(
        () => _errorMessage = 'Selecciona la moneda base y la de destino.',
      );
      return;
    }
    if (_selectedBase!.id == _selectedTarget!.id) {
      setState(
        () => _errorMessage =
            'La moneda base y la de destino no pueden ser la misma.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final data = <String, dynamic>{
      'moneda_id_base': _selectedBase!.id,
      'moneda_id_target': _selectedTarget!.id,
      'exchange_rate': double.parse(_rateController.text),
      'fecha_inicio': calendarDateToUtc(_startDate!).toIso8601String(),
    };
    if (_endDate != null) {
      data['fecha_expiracion'] = calendarDateToUtc(_endDate!).toIso8601String();
    }
    data['activo'] = _activo;
    if (widget.initialData != null) {
      data['tipo_cambio_id'] = widget.initialData!.id;
    }

    try {
      await widget.onSubmit(data);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo guardar el asiento: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = RegistroPalette.fromContext(context);
    final currenciesAsync = ref.watch(currencyProvider);
    final screen = MediaQuery.sizeOf(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 640,
        constraints: BoxConstraints(maxHeight: screen.height * 0.9),
        decoration: BoxDecoration(
          color: p.paper,
          border: Border(
            top: BorderSide(color: p.verm, width: 3),
            right: BorderSide(color: p.rule),
            bottom: BorderSide(color: p.rule),
            left: BorderSide(color: p.rule),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FormHeader(
              p: p,
              isEdit: _isEdit,
              isLoading: _isLoading,
              onCancel: _isLoading ? null : () => Navigator.of(context).pop(),
              onSave: _isLoading ? null : _submit,
            ),
            Divider(height: 1, thickness: 1, color: p.rule),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(26, 24, 26, 28),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: currenciesAsync.when(
                    data: (currencies) {
                      if (!_initialized) {
                        _initializeCurrencySelection(currencies);
                        _initialized = true;
                      }
                      return _buildBody(p, currencies);
                    },
                    loading: () => RegistroLoadingBlock(p: p),
                    error: (err, _) => RegistroErrorBlock(
                      p: p,
                      message: 'Error al cargar divisas: $err',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(RegistroPalette p, List<CurrencyModel> currencies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null) ...[
          RegistroErrorBlock(p: p, message: _errorMessage!),
          const SizedBox(height: 24),
        ],
        RegistroSectionRule(p: p, number: '01', label: 'PAR DE DIVISAS'),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final baseSelector = _CurrencySelector(
              p: p,
              label: 'MONEDA BASE',
              controller: _baseSearchController,
              selected: _selectedBase,
              showDropdown: _showBaseDropdown,
              items: _filteredBaseCurrencies.isEmpty
                  ? currencies
                  : _filteredBaseCurrencies,
              onChanged: (v) => _filterBase(v, currencies),
              onTap: () {
                setState(() {
                  _showBaseDropdown = true;
                  _showTargetDropdown = false;
                  if (_baseSearchController.text.isEmpty) {
                    _filteredBaseCurrencies = currencies;
                  }
                });
              },
              onToggle: () =>
                  setState(() => _showBaseDropdown = !_showBaseDropdown),
              onSelect: _selectBase,
            );
            final targetSelector = _CurrencySelector(
              p: p,
              label: 'MONEDA DESTINO',
              controller: _targetSearchController,
              selected: _selectedTarget,
              showDropdown: _showTargetDropdown,
              items:
                  _filteredTargetCurrencies.isEmpty &&
                      _targetSearchController.text.isEmpty
                  ? (_selectedBase != null
                        ? currencies
                              .where((c) => c.id != _selectedBase!.id)
                              .toList()
                        : currencies)
                  : _filteredTargetCurrencies,
              onChanged: (v) => _filterTarget(v, currencies),
              onTap: () {
                setState(() {
                  _showTargetDropdown = true;
                  _showBaseDropdown = false;
                  _filterTarget(_targetSearchController.text, currencies);
                });
              },
              onToggle: () =>
                  setState(() => _showTargetDropdown = !_showTargetDropdown),
              onSelect: _selectTarget,
            );

            if (constraints.maxWidth < 480) {
              return Column(
                children: [
                  baseSelector,
                  const SizedBox(height: 22),
                  targetSelector,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: baseSelector),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 34),
                    child: Text(
                      '→',
                      style: GoogleFonts.fragmentMono(
                        fontSize: 16,
                        color: p.verm,
                      ),
                    ),
                  ),
                ),
                Expanded(child: targetSelector),
              ],
            );
          },
        ),
        const SizedBox(height: 32),
        RegistroSectionRule(p: p, number: '02', label: 'DETALLES DE LA TASA'),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final rateField = RegistroFormField(
              p: p,
              label: 'TASA DE CAMBIO',
              hint: '0.0000',
              controller: _rateController,
              requiredField: true,
              monospace: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Campo obligatorio.';
                }
                final parsed = double.tryParse(val);
                if (parsed == null || parsed <= 0) {
                  return 'Ingrese una tasa válida.';
                }
                return null;
              },
            );
            final statusToggle = _StatusToggle(
              p: p,
              activo: _activo,
              onChanged: (v) => setState(() => _activo = v),
            );

            if (constraints.maxWidth < 480) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [rateField, const SizedBox(height: 22), statusToggle],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: rateField),
                const SizedBox(width: 28),
                Expanded(flex: 2, child: statusToggle),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final startField = RegistroFormField(
              p: p,
              label: 'VIGENTE DESDE',
              hint: 'aaaa-mm-dd',
              controller: _startDateController,
              requiredField: true,
              monospace: true,
              readOnly: true,
              onTap: () => _selectDate(context, true),
              validator: (val) =>
                  (val == null || val.isEmpty) ? 'Campo obligatorio.' : null,
            );
            final endField = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RegistroFormField(
                  p: p,
                  label: 'EXPIRA',
                  hint: 'opcional',
                  controller: _endDateController,
                  monospace: true,
                  readOnly: true,
                  onTap: () => _selectDate(context, false),
                  suffix: _endDate != null
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _endDate = null;
                                _endDateController.clear();
                              }),
                              child: Text(
                                'LIMPIAR ✕',
                                style: GoogleFonts.archivo(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: p.verm,
                                ),
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            );

            if (constraints.maxWidth < 480) {
              return Column(
                children: [startField, const SizedBox(height: 22), endField],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: startField),
                const SizedBox(width: 28),
                Expanded(child: endField),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        Divider(height: 1, thickness: 1, color: p.rule),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '†',
              style: GoogleFonts.fragmentMono(fontSize: 11, color: p.verm),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'Los campos marcados son obligatorios. La tasa se aplica '
                'a pagos y reportes desde la fecha de vigencia.',
                style: GoogleFonts.fragmentMono(
                  fontSize: 10.5,
                  height: 1.45,
                  color: p.ink3,
                ),
              ),
            ),
            if (_isEdit) ...[
              const SizedBox(width: 18),
              Text(
                registroShortId(widget.initialData!.id),
                style: GoogleFonts.fragmentMono(fontSize: 10.5, color: p.ink4),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// =========================================================================
// Encabezado del pliego
// =========================================================================
class _FormHeader extends StatelessWidget {
  const _FormHeader({
    required this.p,
    required this.isEdit,
    required this.isLoading,
    required this.onCancel,
    required this.onSave,
  });

  final RegistroPalette p;
  final bool isEdit;
  final bool isLoading;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'GYM'),
              TextSpan(
                text: '·',
                style: TextStyle(color: p.verm),
              ),
              const TextSpan(text: 'OS — FINANZAS'),
            ],
          ),
          style: GoogleFonts.archivo(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.1,
            color: p.ink,
          ),
        ),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(
            text: isEdit ? 'EDITAR TASA' : 'NUEVA TASA',
            children: [
              TextSpan(
                text: '.',
                style: TextStyle(color: p.verm),
              ),
            ],
          ),
          style: GoogleFonts.archivoBlack(
            fontSize: 30,
            height: 1,
            color: p.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isEdit
              ? 'F-05A / MODIFICACION · REV. 2026'
              : 'F-05A / ALTA · REV. 2026',
          style: GoogleFonts.fragmentMono(fontSize: 10.5, color: p.ink3),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 22,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        RegistroDialogTextAction(p: p, label: 'CANCELAR', onTap: onCancel),
        RegistroDialogTextAction(
          p: p,
          label: isLoading ? 'COMPONIENDO…' : 'GUARDAR CAMBIOS',
          prime: true,
          onTap: onSave,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, const SizedBox(height: 20), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: copy),
              const SizedBox(width: 20),
              actions,
            ],
          );
        },
      ),
    );
  }
}

// =========================================================================
// Selector de divisa con búsqueda y lista desplegable
// =========================================================================
class _CurrencySelector extends StatelessWidget {
  const _CurrencySelector({
    required this.p,
    required this.label,
    required this.controller,
    required this.selected,
    required this.showDropdown,
    required this.items,
    required this.onChanged,
    required this.onTap,
    required this.onToggle,
    required this.onSelect,
  });

  final RegistroPalette p;
  final String label;
  final TextEditingController controller;
  final CurrencyModel? selected;
  final bool showDropdown;
  final List<CurrencyModel> items;
  final ValueChanged<String> onChanged;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final ValueChanged<CurrencyModel> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              TextSpan(
                text: '  †',
                style: TextStyle(color: p.verm),
              ),
            ],
          ),
          style: GoogleFonts.archivo(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: p.ink3,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          onTap: onTap,
          cursorColor: p.verm,
          style: GoogleFonts.archivo(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: p.ink,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'buscar divisa…',
            hintStyle: GoogleFonts.archivo(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: p.ink4,
            ),
            prefixIcon: selected != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 6),
                    child: AppFlag(
                      base64String: selected!.flagImage,
                      fallbackCode: selected!.code,
                      width: 30,
                      height: 20,
                      borderRadius: 0,
                    ),
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(
              minWidth: 30,
              minHeight: 22,
            ),
            suffixIcon: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 6),
                  child: Text(
                    showDropdown ? '▴' : '▾',
                    style: TextStyle(fontSize: 12, color: p.ink3),
                  ),
                ),
              ),
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 22,
              minHeight: 20,
            ),
            contentPadding: const EdgeInsets.only(bottom: 9),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: p.ruleStrong, width: 1.2),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: p.verm, width: 2),
            ),
          ),
        ),
        if (showDropdown)
          Container(
            height: 210,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: p.paper,
              border: Border.all(color: p.ruleStrong),
            ),
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'sin coincidencias',
                      style: GoogleFonts.fragmentMono(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: p.ink3,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, thickness: 1, color: p.rule),
                    itemBuilder: (context, index) {
                      final c = items[index];
                      return _CurrencyOption(
                        p: p,
                        currency: c,
                        onTap: () => onSelect(c),
                      );
                    },
                  ),
          ),
      ],
    );
  }
}

class _CurrencyOption extends StatefulWidget {
  const _CurrencyOption({
    required this.p,
    required this.currency,
    required this.onTap,
  });

  final RegistroPalette p;
  final CurrencyModel currency;
  final VoidCallback onTap;

  @override
  State<_CurrencyOption> createState() => _CurrencyOptionState();
}

class _CurrencyOptionState extends State<_CurrencyOption> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final c = widget.currency;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: _hover ? p.paper2 : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              AppFlag(
                base64String: c.flagImage,
                fallbackCode: c.code,
                width: 30,
                height: 20,
                borderRadius: 0,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.archivo(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: p.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                c.code,
                style: GoogleFonts.fragmentMono(fontSize: 11, color: p.ink3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// Estado: ACTIVO / INACTIVO como pestañas tipográficas
// =========================================================================
class _StatusToggle extends StatelessWidget {
  const _StatusToggle({
    required this.p,
    required this.activo,
    required this.onChanged,
  });

  final RegistroPalette p;
  final bool activo;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ESTADO',
          style: GoogleFonts.archivo(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: p.ink3,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatusOption(
              p: p,
              label: 'ACTIVO',
              selected: activo,
              onTap: () => onChanged(true),
            ),
            const SizedBox(width: 20),
            _StatusOption(
              p: p,
              label: 'INACTIVO',
              selected: !activo,
              onTap: () => onChanged(false),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusOption extends StatefulWidget {
  const _StatusOption({
    required this.p,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final RegistroPalette p;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_StatusOption> createState() => _StatusOptionState();
}

class _StatusOptionState extends State<_StatusOption> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final color = widget.selected ? p.verm : (_hover ? p.ink : p.ink3);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.selected ? p.verm : Colors.transparent,
                width: 1.5,
              ),
            ),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.archivo(
              fontSize: 12,
              fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: 1.2,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
