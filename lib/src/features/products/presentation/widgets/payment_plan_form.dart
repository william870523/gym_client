import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/app_flag.dart';

import '../../../financials/data/models/currency_model.dart';
import '../../../financials/presentation/state/currency_notifier.dart';

import '../../data/models/payment_plan_model.dart';
import '../state/payment_plan_notifier.dart';

class PaymentPlanForm extends ConsumerStatefulWidget {
  final PaymentPlanModel? plan;

  const PaymentPlanForm({super.key, this.plan});

  @override
  ConsumerState<PaymentPlanForm> createState() => _PaymentPlanFormState();
}

class _PaymentPlanFormState extends ConsumerState<PaymentPlanForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _durationController;
  late TextEditingController _currencySearchController;
  late TextEditingController _commissionController;

  String _durationUnit = 'months'; // days, weeks, months, years
  bool _isActive = true;
  bool _includesTrainer = false;
  String _commissionType = 'NONE';
  bool _isLoading = false;

  // Currency Selector State
  CurrencyModel? _selectedCurrency;
  bool _showCurrencyDropdown = false;
  List<CurrencyModel> _filteredCurrencies = [];
  bool _currencyInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.plan?.nombre ?? '');
    _amountController = TextEditingController(
      text: widget.plan?.importe.toString() ?? '',
    );
    _commissionController = TextEditingController(
      text: widget.plan?.comisionEntrenadorValor?.toString() ?? '',
    );
    _currencySearchController = TextEditingController();

    // Calculate initial duration/unit
    int duration = widget.plan?.duracion ?? 30;
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

    _isActive = widget.plan?.activo ?? true;
    _includesTrainer = widget.plan?.incluyeEntrenador ?? false;
    _commissionType = widget.plan?.comisionEntrenadorTipo ?? 'NONE';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _durationController.dispose();
    _currencySearchController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  // Currency Helpers
  void _filterCurrencies(String query, List<CurrencyModel> allCurrencies) {
    setState(() {
      if (query.isEmpty) {
        _filteredCurrencies = allCurrencies;
      } else {
        _filteredCurrencies = allCurrencies.where((c) {
          final lowerQuery = query.toLowerCase();
          return c.name.toLowerCase().contains(lowerQuery) ||
              c.code.toLowerCase().contains(lowerQuery);
        }).toList();
      }
    });
  }

  void _selectCurrency(CurrencyModel currency) {
    setState(() {
      _selectedCurrency = currency;
      _currencySearchController.text = '${currency.code} - ${currency.name}';
      _showCurrencyDropdown = false;
    });
  }

  Widget _buildCurrencyFlag(CurrencyModel currency) {
    return AppFlag(
      base64String: currency.flagImage,
      fallbackCode: currency.code,
      width: 28,
      height: 20,
      borderRadius: 3,
      fit: BoxFit.contain,
    );
  }

  int _calculateDurationInDays() {
    final val = int.tryParse(_durationController.text) ?? 0;
    switch (_durationUnit) {
      case 'years':
        return val * 365;
      case 'months':
        return val * 30;
      case 'weeks':
        return val * 7;
      case 'days':
        return val;
      default:
        return val;
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCurrency == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor selecciona una moneda')),
        );
        return;
      }

      setState(() => _isLoading = true);

      final notifier = ref.read(paymentPlanProvider.notifier);
      try {
        final duracionDias = _calculateDurationInDays();
        final importe = double.tryParse(_amountController.text) ?? 0.0;
        final commissionValue = double.tryParse(_commissionController.text);

        final newPlan = PaymentPlanModel(
          id: widget.plan?.id,
          nombre: _nameController.text,
          importe: importe,
          duracion: duracionDias,
          monedaId: _selectedCurrency!.id,
          activo: _isActive,
          incluyeEntrenador: _includesTrainer,
          comisionEntrenadorTipo: _includesTrainer ? _commissionType : 'NONE',
          comisionEntrenadorValor: _includesTrainer ? commissionValue : null,
          gymId: widget.plan?.gymId ?? '123',
        );

        if (widget.plan == null) {
          await notifier.create(newPlan);
        } else {
          await notifier.updatePlan(newPlan);
        }
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error al guardar: $e")));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Colors
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final primary = const Color(0xFF136DEC);

    final currenciesState = ref.watch(currencyProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.plan == null ? "Nuevo Plan de Pago" : "Editar Plan",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textMain,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre
                      _buildLabel("Nombre del Plan", textMain),
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(color: textMain),
                        decoration: _inputDecoration(
                          inputBg,
                          borderColor,
                          "Ej. Membresía Mensual",
                        ),
                        validator: (v) => v!.isEmpty ? "Requerido" : null,
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel("Importe", textMain),
                                TextFormField(
                                  controller: _amountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d{0,2}'),
                                    ),
                                  ],
                                  style: TextStyle(color: textMain),
                                  decoration: _inputDecoration(
                                    inputBg,
                                    borderColor,
                                    "0.00",
                                  ),
                                  validator: (v) =>
                                      v!.isEmpty ? "Requerido" : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel("Moneda", textMain),
                                // Currency Dropdown
                                currenciesState.when(
                                  loading: () => const SizedBox(
                                    height: 48,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  error: (e, _) => Text(
                                    "Error loading currencies",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  data: (currencies) {
                                    // Init logic
                                    if (!_currencyInitialized &&
                                        widget.plan != null &&
                                        currencies.isNotEmpty) {
                                      _currencyInitialized = true;
                                      try {
                                        final match = currencies.firstWhere(
                                          (c) => c.id == widget.plan!.monedaId,
                                        );
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              if (mounted) {
                                                _selectCurrency(match);
                                              }
                                            });
                                      } catch (_) {}
                                    }

                                    if (_filteredCurrencies.isEmpty &&
                                        !_showCurrencyDropdown) {
                                      _filteredCurrencies = currencies;
                                    }

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Search Input (No GestureDetector needed if tapping field works, but keeping for safety on suffix icon usage etc)
                                        TextFormField(
                                          controller: _currencySearchController,
                                          style: TextStyle(color: textMain),
                                          decoration:
                                              _inputDecoration(
                                                inputBg,
                                                borderColor,
                                                "Seleccione moneda",
                                              ).copyWith(
                                                prefixIcon:
                                                    _selectedCurrency != null
                                                    ? Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              12,
                                                            ),
                                                        child:
                                                            _buildCurrencyFlag(
                                                              _selectedCurrency!,
                                                            ),
                                                      )
                                                    : Icon(
                                                        Icons.currency_exchange,
                                                        color: textMuted,
                                                      ),
                                                suffixIcon: IconButton(
                                                  icon: Icon(
                                                    _showCurrencyDropdown
                                                        ? Icons.arrow_drop_down
                                                        : Icons.arrow_drop_up,
                                                    color: textMuted,
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _showCurrencyDropdown =
                                                          !_showCurrencyDropdown;
                                                      if (_showCurrencyDropdown) {
                                                        _filteredCurrencies =
                                                            currencies;
                                                      }
                                                    });
                                                  },
                                                ),
                                              ),
                                          onChanged: (val) => _filterCurrencies(
                                            val,
                                            currencies,
                                          ),
                                          onTap: () {
                                            setState(() {
                                              _showCurrencyDropdown = true;
                                              _filteredCurrencies = currencies;
                                            });
                                          },
                                        ),
                                        if (_showCurrencyDropdown)
                                          Container(
                                            height: 150,
                                            margin: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: surfaceColor,
                                              border: Border.all(
                                                color: borderColor,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: ListView.builder(
                                              itemCount:
                                                  _filteredCurrencies.length,
                                              itemBuilder: (context, index) {
                                                final currency =
                                                    _filteredCurrencies[index];
                                                return ListTile(
                                                  leading: _buildCurrencyFlag(
                                                    currency,
                                                  ),
                                                  title: Text(
                                                    currency.name,
                                                    style: TextStyle(
                                                      color: textMain,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  subtitle: Text(
                                                    currency.code,
                                                    style: TextStyle(
                                                      color: textMuted,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  onTap: () =>
                                                      _selectCurrency(currency),
                                                );
                                              },
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildLabel("Duración", textMain),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _durationController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: TextStyle(color: textMain),
                              decoration: _inputDecoration(
                                inputBg,
                                borderColor,
                                "Ej. 1, 30",
                              ),
                              validator: (v) => v!.isEmpty ? "Requerido" : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              initialValue: _durationUnit,
                              dropdownColor: surfaceColor,
                              decoration: _inputDecoration(
                                inputBg,
                                borderColor,
                                "",
                              ),
                              icon: Icon(
                                Icons.keyboard_arrow_down,
                                color: textMuted,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'days',
                                  child: Text("Días"),
                                ),
                                DropdownMenuItem(
                                  value: 'weeks',
                                  child: Text("Semanas"),
                                ),
                                DropdownMenuItem(
                                  value: 'months',
                                  child: Text("Meses"),
                                ),
                                DropdownMenuItem(
                                  value: 'years',
                                  child: Text("Años"),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _durationUnit = v!),
                              style: TextStyle(color: textMain),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _includesTrainer,
                              onChanged: (v) => setState(() {
                                _includesTrainer = v ?? false;
                                if (!_includesTrainer) {
                                  _commissionType = 'NONE';
                                  _commissionController.clear();
                                } else if (_commissionType == 'NONE') {
                                  _commissionType = 'PERCENTAGE';
                                }
                              }),
                              activeColor: primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Plan con Entrenador",
                            style: GoogleFonts.inter(color: textMain),
                          ),
                        ],
                      ),

                      if (_includesTrainer) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel("Tipo de Comisión", textMain),
                                  DropdownButtonFormField<String>(
                                    initialValue: _commissionType == 'NONE'
                                        ? 'PERCENTAGE'
                                        : _commissionType,
                                    dropdownColor: surfaceColor,
                                    decoration: _inputDecoration(
                                      inputBg,
                                      borderColor,
                                      "",
                                    ),
                                    icon: Icon(
                                      Icons.keyboard_arrow_down,
                                      color: textMuted,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'PERCENTAGE',
                                        child: Text("Porcentaje"),
                                      ),
                                      DropdownMenuItem(
                                        value: 'FIXED_AMOUNT',
                                        child: Text("Monto fijo"),
                                      ),
                                    ],
                                    onChanged: (v) => setState(
                                      () => _commissionType = v ?? 'PERCENTAGE',
                                    ),
                                    style: TextStyle(color: textMain),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel("Valor Comisión", textMain),
                                  TextFormField(
                                    controller: _commissionController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d{0,2}'),
                                      ),
                                    ],
                                    style: TextStyle(color: textMain),
                                    decoration: _inputDecoration(
                                      inputBg,
                                      borderColor,
                                      _commissionType == 'PERCENTAGE'
                                          ? "Ej. 15"
                                          : "Ej. 4.00",
                                    ),
                                    validator: (v) {
                                      if (!_includesTrainer) return null;
                                      final parsed = double.tryParse(v ?? '');
                                      if (parsed == null || parsed <= 0) {
                                        return "Requerido";
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _isActive,
                              onChanged: (v) => setState(() => _isActive = v!),
                              activeColor: primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Plan Activo",
                            style: GoogleFonts.inter(color: textMain),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    child: Text("Cancelar", style: TextStyle(color: textMuted)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text("Guardar"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(Color bg, Color border, String hint) {
    return InputDecoration(
      filled: true,
      fillColor: bg,
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF136DEC), width: 1.5),
      ),
    );
  }
}
