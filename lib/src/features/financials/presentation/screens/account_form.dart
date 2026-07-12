import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/app_flag.dart';
import '../../data/models/account_model.dart';
import '../../data/models/currency_model.dart';
import '../state/currency_notifier.dart';
import '../../../configuration/data/models/payment_type_model.dart';
import '../../../configuration/presentation/state/payment_type_notifier.dart';

class AccountForm extends ConsumerStatefulWidget {
  final AccountModel? account;
  final Future<void> Function(
    String name,
    String currencyId, {
    String? paymentTypeId,
  })
  onSave;

  const AccountForm({super.key, this.account, required this.onSave});

  @override
  ConsumerState<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<AccountForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _currencySearchController;

  CurrencyModel? _selectedCurrency;
  PaymentTypeModel? _selectedPaymentType;
  bool _isLoading = false;
  bool _showCurrencyDropdown = false;
  bool _paymentTypeInitialized = false;
  List<CurrencyModel> _filteredCurrencies = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name ?? '');
    _currencySearchController = TextEditingController();
  }

  // ... (keep dispose and other methods)

  void _selectPaymentType(PaymentTypeModel? type) {
    setState(() {
      _selectedPaymentType = type;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currencySearchController.dispose();
    super.dispose();
  }

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCurrency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona una moneda')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.onSave(
        _nameController.text.trim(),
        _selectedCurrency!.id,
        paymentTypeId: _selectedPaymentType?.id,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currenciesState = ref.watch(currencyProvider);

    final surfaceColor = isDark ? const Color(0xFF1A2233) : Colors.white;
    final primaryColor = const Color(0xFF135BEC);
    final textDark = isDark ? Colors.white : const Color(0xFF0D121B);
    final textMedium = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final borderColor = isDark
        ? const Color(0xFF2A3447)
        : const Color(0xFFE7EBF3);
    final inputBgColor = isDark
        ? const Color(0xFF101622)
        : const Color(0xFFF6F6F8);

    final isEditing = widget.account != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 800),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.account_balance,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Actualizar Cuenta' : 'Nueva Cuenta',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEditing
                              ? 'Edita la información de la cuenta'
                              : 'Ingresa los datos para registrar una nueva cuenta',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: textMedium),
                  ),
                ],
              ),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Account Name
                      Text(
                        'Nombre de la Cuenta',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Ej. Banco Principal - Operaciones',
                          hintStyle: GoogleFonts.inter(color: textMedium),
                          filled: true,
                          fillColor: inputBgColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El nombre es requerido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Un nombre descriptivo para identificar esta cuenta en los reportes.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: textMedium,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Currency Selector
                      Text(
                        'Moneda',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      currenciesState.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Error cargando monedas: $e'),
                        data: (currencies) {
                          // Initialize selection for edit mode
                          if (isEditing && _selectedCurrency == null) {
                            final match = currencies
                                .cast<CurrencyModel?>()
                                .firstWhere(
                                  (c) => c?.id == widget.account?.currencyId,
                                  orElse: () => null,
                                );
                            if (match != null) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _selectCurrency(match);
                              });
                            }
                          }

                          if (_filteredCurrencies.isEmpty &&
                              !_showCurrencyDropdown) {
                            _filteredCurrencies = currencies;
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Search Input
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showCurrencyDropdown = true;
                                    _filteredCurrencies = currencies;
                                  });
                                },
                                child: AbsorbPointer(
                                  absorbing: false,
                                  child: TextFormField(
                                    controller: _currencySearchController,
                                    onTap: () {
                                      setState(() {
                                        _showCurrencyDropdown = true;
                                        _filteredCurrencies = currencies;
                                      });
                                    },
                                    onChanged: (value) =>
                                        _filterCurrencies(value, currencies),
                                    decoration: InputDecoration(
                                      hintText: 'Buscar moneda...',
                                      hintStyle: GoogleFonts.inter(
                                        color: textMedium,
                                      ),
                                      filled: true,
                                      fillColor: inputBgColor,
                                      prefixIcon: _selectedCurrency != null
                                          ? Padding(
                                              padding: const EdgeInsets.all(10),
                                              child: _buildCurrencyFlag(
                                                _selectedCurrency!,
                                              ),
                                            )
                                          : Icon(
                                              Icons.payments,
                                              color: textMedium,
                                            ),
                                      suffixIcon: Icon(
                                        _showCurrencyDropdown
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        color: textMedium,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: borderColor,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: borderColor,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: primaryColor,
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                    ),
                                  ),
                                ),
                              ),

                              // Dropdown List
                              if (_showCurrencyDropdown)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  constraints: const BoxConstraints(
                                    maxHeight: 200,
                                  ),
                                  decoration: BoxDecoration(
                                    color: surfaceColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: borderColor),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _filteredCurrencies.length,
                                    itemBuilder: (context, index) {
                                      final currency =
                                          _filteredCurrencies[index];
                                      final isSelected =
                                          _selectedCurrency?.id == currency.id;
                                      return ListTile(
                                        selected: isSelected,
                                        selectedTileColor: isDark
                                            ? const Color(0xFF1E293B)
                                            : Colors.blue.shade50,
                                        leading: _buildCurrencyFlag(currency),
                                        title: Text(
                                          currency.name,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w500,
                                            color: textDark,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${currency.symbol ?? ''} ${currency.code}',
                                          style: GoogleFonts.robotoMono(
                                            fontSize: 12,
                                            color: textMedium,
                                          ),
                                        ),
                                        trailing: isSelected
                                            ? Icon(
                                                Icons.check,
                                                color: primaryColor,
                                              )
                                            : null,
                                        onTap: () => _selectCurrency(currency),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'La moneda base para las transacciones de esta cuenta.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: textMedium,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Payment Type Selector
                      Text(
                        'Tipo de Pago Asociado',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Consumer(
                        builder: (context, ref, child) {
                          final paymentTypesState = ref.watch(
                            paymentTypeNotifierProvider,
                          );
                          return paymentTypesState.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => Text('Error: $e'),
                            data: (types) {
                              final activeTypes = types
                                  .where((t) => t.active && !t.isDeleted)
                                  .toList();

                              // Init selection if editing
                              // Init selection logic
                              if (isEditing &&
                                  _selectedPaymentType == null &&
                                  widget.account?.paymentTypeId != null &&
                                  !_paymentTypeInitialized) {
                                try {
                                  // Find match from all types (even inactive ones if needed, though list filters them)
                                  // Ideally we should see all types here to show the current one even if inactive
                                  final match = types.firstWhere(
                                    (t) =>
                                        t.id == widget.account!.paymentTypeId,
                                    orElse: () => types.first, // Fallback safe
                                  );

                                  // Only set if we actually found the specific one
                                  if (match.id ==
                                      widget.account!.paymentTypeId) {
                                    // Defer state update to avoid build collisions
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (mounted) {
                                            setState(() {
                                              _selectedPaymentType = match;
                                              _paymentTypeInitialized = true;
                                            });
                                          }
                                        });
                                  } else {
                                    // Mark as initialized so we don't keep trying
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (mounted) {
                                            setState(() {
                                              _paymentTypeInitialized = true;
                                            });
                                          }
                                        });
                                  }
                                } catch (_) {}
                              }

                              return DropdownButtonFormField<PaymentTypeModel>(
                                initialValue: _selectedPaymentType,
                                decoration: InputDecoration(
                                  hintText: 'Seleccione un tipo (Opcional)',
                                  hintStyle: GoogleFonts.inter(
                                    color: textMedium,
                                  ),
                                  filled: true,
                                  fillColor: inputBgColor,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                items: activeTypes.map((type) {
                                  return DropdownMenuItem(
                                    value: type,
                                    child: Text(
                                      type.name,
                                      style: GoogleFonts.inter(color: textDark),
                                    ),
                                  );
                                }).toList(),
                                onChanged: _selectPaymentType,
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Permite filtrar cuentas según el método de pago al cobrar.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: textMedium,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Info Box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50.withValues(
                            alpha: isDark ? 0.1 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.shade100.withValues(
                              alpha: isDark ? 0.3 : 1,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Información importante',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      color: textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Las nuevas cuentas pueden tardar hasta 5 minutos en reflejarse debido a la sincronización.',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: textMedium,
                                    ),
                                  ),
                                ],
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

            // Footer
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF151D2B)
                    : const Color(0xFFFAFAFB),
                border: Border(top: BorderSide(color: borderColor)),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: textMedium,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submit,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save, size: 18),
                    label: Text(
                      isEditing ? 'Guardar Cambios' : 'Guardar Cuenta',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
}
