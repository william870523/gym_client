import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_client/src/features/configuration/presentation/state/payment_type_notifier.dart';
import 'package:gym_client/src/features/financials/presentation/state/account_notifier.dart';
import 'package:gym_client/src/features/financials/presentation/providers/exchange_rate_notifier.dart';
import 'package:gym_client/src/features/configuration/data/models/payment_type_model.dart';
import 'package:gym_client/src/features/financials/data/models/account_model.dart';
import 'package:gym_client/src/features/financials/data/models/currency_model.dart';
import 'package:gym_client/src/features/financials/presentation/screens/exchange_rates_pulso_view.dart';
import 'package:gym_client/src/features/financials/presentation/state/currency_notifier.dart';
import 'package:gym_client/src/features/financials/presentation/widgets/exchange_rate_pulso_form.dart';
import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/app_flag.dart';
import '../../../../core/widgets/pulso_widgets.dart';

class PaymentRowItem extends ConsumerStatefulWidget {
  final String planCurrencyId;
  final Function(Map<String, dynamic> data) onChanged;
  final VoidCallback onDelete;
  final Map<String, dynamic>? initialData;

  const PaymentRowItem({
    super.key,
    required this.planCurrencyId,
    required this.onChanged,
    required this.onDelete,
    this.initialData,
  });

  @override
  ConsumerState<PaymentRowItem> createState() => _PaymentRowItemState();
}

class _PaymentRowItemState extends ConsumerState<PaymentRowItem> {
  PaymentTypeModel? _selectedType;
  AccountModel? _selectedAccount;

  final _amountController = TextEditingController();
  // Controllers for DropdownMenu text input vs selection
  final _typeInputController = TextEditingController();
  final _accountInputController = TextEditingController();

  double _currentRate = 0.0;
  String? _currentRateId;
  bool _rateFound = false;
  bool _divideByRate = false;

  double? _lastEmittedAmount;

  @override
  void initState() {
    super.initState();
    _updateStateFromData(widget.initialData);
  }

  @override
  void didUpdateWidget(PaymentRowItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update if initialData has changed meaningfully and differs from current state
    if (widget.initialData != oldWidget.initialData) {
      _updateStateFromData(widget.initialData);
    }
    if (widget.planCurrencyId != oldWidget.planCurrencyId &&
        _selectedAccount != null) {
      _findExchangeRate(_selectedAccount!.currencyId);
    }
  }

  void _updateStateFromData(Map<String, dynamic>? data) {
    if (data == null) return;

    if (data['amount'] != null) {
      final amountVal = data['amount'] is num
          ? (data['amount'] as num).toDouble()
          : 0.0;

      // Prevent overwriting if the value matches what we last sent (Anti-Loop)
      if (_lastEmittedAmount == null ||
          (amountVal - _lastEmittedAmount!).abs() > 0.001) {
        // Only update text if parsed value differs significantly or we are initializing
        if (_amountController.text.isEmpty && amountVal == 0) {
          // Do nothing
        } else {
          final currentParsed = double.tryParse(_amountController.text) ?? 0.0;
          if ((currentParsed - amountVal).abs() > 0.001) {
            // Formatting might still be annoying (e.g. 5.0 vs 5), but this prevents loop
            // if values match.
            _amountController.text = (amountVal % 1 == 0)
                ? amountVal.toInt().toString()
                : amountVal.toString();
          }
        }
      }
    }

    if (data['type'] is PaymentTypeModel?) {
      _selectedType = data['type'] as PaymentTypeModel?;
      if (_selectedType != null) {
        _typeInputController.text = _selectedType!
            .name; // Sync dropdown text usually happens automatically but good to set
      }
    }

    if (data['account'] is AccountModel?) {
      _selectedAccount = data['account'] as AccountModel?;
      if (_selectedAccount != null) {
        // If explicit rate provided in data, use it (for restoration)
        if (data['rate'] != null && data['rate'] is num) {
          _currentRate = (data['rate'] as num).toDouble();
          _rateFound = _currentRate > 0;
          _divideByRate = data['rateOperation'] == 'divide';
        }
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _typeInputController.dispose();
    _accountInputController.dispose();
    super.dispose();
  }

  void _notifyChanged() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final equivalent = _calculateEquivalent(amount);

    _lastEmittedAmount = amount; // Track what we sent

    widget.onChanged({
      'type': _selectedType,
      'account': _selectedAccount,
      'amount': amount,
      'rate': _currentRate,
      'rateOperation': _divideByRate ? 'divide' : 'multiply',
      'exchangeRateId': _currentRateId,
      'equivalent': equivalent,
      'isValid':
          _selectedType != null &&
          _selectedAccount != null &&
          _rateFound &&
          amount > 0,
    });
  }

  void _onTypeChanged(PaymentTypeModel? type) {
    setState(() {
      _selectedType = type;
      _selectedAccount = null;
      _accountInputController.clear();
      _rateFound = false;
      _divideByRate = false;
      _currentRate = 0.0;
      _currentRateId = null;
    });
    _notifyChanged();
  }

  void _onAccountSelected(AccountModel? account) {
    setState(() {
      _selectedAccount = account;
      // Reset rate state immediately to prevent ghost data from previous selection
      _rateFound = false;
      _divideByRate = false;
      _currentRate = 0.0;
      _currentRateId = null;
    });

    if (account != null) {
      _findExchangeRate(account.currencyId);
    } else {
      _notifyChanged();
    }
  }

  void _findExchangeRate(String currencyId) {
    final accountCurrencyId = currencyId.trim();
    final planCurrencyId = widget.planCurrencyId.trim();

    if (accountCurrencyId.isEmpty || planCurrencyId.isEmpty) {
      _applyRateState(found: false, rate: 0.0);
      return;
    }

    if (_isSameCurrencyId(accountCurrencyId, planCurrencyId)) {
      _applyRateState(found: true, rate: 1.0);
      return;
    }

    final ratesAsync = ref.read(exchangeRateProvider);
    ratesAsync.whenData((rates) {
      double rate = 0.0;
      String? rateId;
      bool found = false;
      bool divideByRate = false;

      // 1. Same Currency Case (1:1)
      if (currencyId == widget.planCurrencyId) {
        rate = 1.0;
        found = true;
        rateId = null;
      }
      // 2. Different Currencies
      else {
        try {
          final rateModel = rates.firstWhere(
            (r) =>
                _isSameCurrencyId(r.monedaIdBase, planCurrencyId) &&
                _isSameCurrencyId(r.monedaIdTarget, accountCurrencyId) &&
                r.activo,
          );
          rate = rateModel.exchangeRate;
          rateId = rateModel.id;
          found = true;
          divideByRate = true;
        } catch (e) {
          try {
            final reverseRate = rates.firstWhere(
              (r) =>
                  _isSameCurrencyId(r.monedaIdBase, accountCurrencyId) &&
                  _isSameCurrencyId(r.monedaIdTarget, planCurrencyId) &&
                  r.activo,
            );
            rate = reverseRate.exchangeRate;
            rateId = reverseRate.id; // Use the reverse rate ID
            found = true;
          } catch (_) {
            found = false;
          }
        }
      }

      _applyRateState(
        found: found,
        rate: rate,
        rateId: rateId,
        divideByRate: found && divideByRate,
      );
    });
  }

  void _applyRateState({
    required bool found,
    required double rate,
    String? rateId,
    bool divideByRate = false,
  }) {
    if (!mounted) return;

    setState(() {
      _rateFound = found;
      _currentRate = rate;
      _currentRateId = rateId;
      _divideByRate = found && divideByRate;
    });
    _notifyChanged();
  }

  double _calculateEquivalent(double amount) {
    if (!_rateFound || _currentRate <= 0) return 0.0;
    return _divideByRate ? amount / _currentRate : amount * _currentRate;
  }

  bool _isSameCurrencyId(String a, String b) {
    final left = a.trim().toLowerCase();
    final right = b.trim().toLowerCase();
    return left.isNotEmpty && right.isNotEmpty && left == right;
  }

  bool get _usesImplicitSameCurrencyRate {
    final account = _selectedAccount;
    return account != null &&
        _isSameCurrencyId(account.currencyId, widget.planCurrencyId) &&
        _currentRateId == null;
  }

  String _rateLabel() {
    if (_usesImplicitSameCurrencyRate) return '1:1 sin tasa';
    return '${_divideByRate ? '/' : 'x'} ${_currentRate.toStringAsFixed(4)}';
  }

  String _accountCurrencyLabel() {
    final code = _selectedAccount?.currencyCode?.trim();
    if (code != null && code.isNotEmpty) return code;

    final name = _selectedAccount?.currencyName?.trim();
    if (name != null && name.isNotEmpty) return name;

    return _selectedAccount?.currencyId ?? 'moneda seleccionada';
  }

  String _planCurrencyLabel(List<CurrencyModel> currencies) {
    try {
      final currency = currencies.firstWhere(
        (item) => item.id == widget.planCurrencyId,
      );
      return currency.code;
    } catch (_) {
      return widget.planCurrencyId.isEmpty
          ? 'moneda del plan'
          : widget.planCurrencyId;
    }
  }

  Future<void> _refreshRateAfterConfiguration() async {
    if (_selectedAccount == null) return;

    await ref.read(exchangeRateProvider.notifier).refresh();
    if (mounted && _selectedAccount != null) {
      _findExchangeRate(_selectedAccount!.currencyId);
    }
  }

  Future<void> _openCreateExchangeRateForm() async {
    if (_selectedAccount == null) return;
    if (_isSameCurrencyId(
      _selectedAccount!.currencyId,
      widget.planCurrencyId,
    )) {
      _applyRateState(found: true, rate: 1.0);
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ExchangeRatePulsoForm(
        initialBaseCurrencyId: widget.planCurrencyId,
        initialTargetCurrencyId: _selectedAccount!.currencyId,
        onSubmit: (data) async {
          await ref.read(exchangeRateProvider.notifier).create(data);
        },
      ),
    );
    if (!mounted) return;
    await _refreshRateAfterConfiguration();
  }

  Future<void> _openExchangeRatesManager() async {
    if (_selectedAccount == null) return;
    if (_isSameCurrencyId(
      _selectedAccount!.currencyId,
      widget.planCurrencyId,
    )) {
      _applyRateState(found: true, rate: 1.0);
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PulsoThemeScope(
        child: Builder(
          builder: (context) {
            final tokens = PulsoTokens.of(context);
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: Container(
                width: 1000,
                height: MediaQuery.sizeOf(context).height * 0.85,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: tokens.floor,
                  border: Border(
                    top: BorderSide(color: tokens.accent, width: 4),
                  ),
                ),
                child: const ExchangeRatesPulsoView(),
              ),
            );
          },
        ),
      ),
    );
    if (!mounted) return;
    await _refreshRateAfterConfiguration();
  }

  Future<void> _showMissingRateDialog(String planCurrencyLabel) async {
    final accountCurrencyLabel = _accountCurrencyLabel();
    final action = await showDialog<String>(
      context: context,
      builder: (context) => PulsoThemeScope(
        child: AlertDialog(
          title: const Text('Falta una tasa activa'),
          content: Text(
            'El cliente va a pagar en $accountCurrencyLabel y el plan está en $planCurrencyLabel. '
            'La tasa recomendada es $planCurrencyLabel → $accountCurrencyLabel: 1 $planCurrencyLabel equivale a N $accountCurrencyLabel. '
            'Con esa tasa el sistema divide el monto pagado para calcular el equivalente del plan. '
            'También se acepta la tasa inversa $accountCurrencyLabel → $planCurrencyLabel. Si no puedes crearla, contacta al administrador.',
          ),
          actions: [
            PulsoSecondaryButton(
              label: 'Cancelar',
              onPressed: () => Navigator.of(context).pop(),
            ),
            PulsoSecondaryButton(
              label: 'Ver tasas',
              icon: Icons.list_alt,
              onPressed: () => Navigator.of(context).pop('manage'),
            ),
            PulsoPrimaryButton(
              label: 'Crear tasa',
              icon: Icons.add,
              onPressed: () => Navigator.of(context).pop('create'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (action == 'create') {
      await _openCreateExchangeRateForm();
    } else if (action == 'manage') {
      await _openExchangeRatesManager();
    }
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(paymentTypeNotifierProvider);
    final accountsAsync = ref.watch(accountProvider);
    final currencies =
        ref.watch(currencyProvider).value ?? const <CurrencyModel>[];
    final planCurrencyLabel = _planCurrencyLabel(currencies);
    final tokens = PulsoTokens.of(context);

    ref.listen(exchangeRateProvider, (_, next) {
      if (_selectedAccount == null ||
          _isSameCurrencyId(
            _selectedAccount!.currencyId,
            widget.planCurrencyId,
          ) ||
          !next.hasValue) {
        return;
      }
      _findExchangeRate(_selectedAccount!.currencyId);
    });

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Tipo de Pago (Searchable)
          Expanded(
            flex: 2,
            child: typesAsync.when(
              data: (types) {
                final activeTypes = types.where((t) => t.active).toList();
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return DropdownMenu<PaymentTypeModel>(
                      width: constraints.maxWidth,
                      controller: _typeInputController,
                      enableFilter: true,
                      requestFocusOnTap: true,
                      hintText: 'Tipo',
                      initialSelection: _selectedType,
                      textStyle: TextStyle(
                        fontSize: 13,
                        color: tokens.chalk,
                      ),
                      inputDecorationTheme: _dropdownInputTheme(tokens),
                      menuStyle: _menuStyle(tokens),
                      dropdownMenuEntries: activeTypes.map((type) {
                        return DropdownMenuEntry<PaymentTypeModel>(
                          value: type,
                          label: type.name,
                          leadingIcon: Icon(
                            _getTypeIcon(type.name),
                            size: 18,
                            color: tokens.muted,
                          ),
                          style: ButtonStyle(
                            textStyle: WidgetStatePropertyAll(
                              TextStyle(fontSize: 13, color: tokens.chalk),
                            ),
                            foregroundColor: WidgetStatePropertyAll(
                              tokens.chalk,
                            ),
                          ),
                        );
                      }).toList(),
                      onSelected: _onTypeChanged,
                      leadingIcon: _selectedType != null
                          ? Icon(
                              _getTypeIcon(_selectedType!.name),
                              size: 18,
                              color: tokens.muted,
                            )
                          : Icon(Icons.payment, size: 18, color: tokens.muted),
                    );
                  },
                );
              },
              loading: () => const SizedBox(),
              error: (error, stackTrace) => Icon(
                Icons.error_outline,
                size: 16,
                color: tokens.danger,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 2. Cuenta (Filtered & Searchable)
          Expanded(
            flex: 3,
            child: _selectedType == null
                ? _disabledCell('Seleccione Tipo')
                : accountsAsync.when(
                    data: (accounts) {
                      final filtered = accounts
                          .where(
                            (a) =>
                                !a.isDeleted &&
                                a.paymentTypeId == _selectedType!.id,
                          )
                          .toList();
                      if (filtered.isEmpty) return _errorCell('Sin cuentas');
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return DropdownMenu<AccountModel>(
                            width: constraints.maxWidth,
                            controller: _accountInputController,
                            enableFilter: true,
                            requestFocusOnTap: true,
                            hintText: 'Cuenta',
                            initialSelection: _selectedAccount,
                            textStyle: TextStyle(
                              fontSize: 13,
                              color: tokens.chalk,
                            ),
                            inputDecorationTheme: _dropdownInputTheme(tokens),
                            menuStyle: _menuStyle(tokens),
                            dropdownMenuEntries: filtered.map((account) {
                              return DropdownMenuEntry<AccountModel>(
                                value: account,
                                label: account.name,
                                leadingIcon: account.currencyImage != null
                                    ? AppFlag(
                                        bytes: account.currencyImage,
                                        fallbackCode: account.currencyCode,
                                        width: 20,
                                        height: 15,
                                        borderRadius: 0,
                                      )
                                    : Icon(
                                        Icons.account_balance_wallet,
                                        size: 16,
                                        color: tokens.muted,
                                      ),
                                style: ButtonStyle(
                                  textStyle: WidgetStatePropertyAll(
                                    TextStyle(
                                      fontSize: 13,
                                      color: tokens.chalk,
                                    ),
                                  ),
                                  foregroundColor: WidgetStatePropertyAll(
                                    tokens.chalk,
                                  ),
                                ),
                              );
                            }).toList(),
                            onSelected: _onAccountSelected,
                            leadingIcon: _selectedAccount?.currencyImage != null
                                ? Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: AppFlag(
                                      bytes: _selectedAccount!.currencyImage,
                                      fallbackCode:
                                          _selectedAccount!.currencyCode,
                                      width: 20,
                                      height: 15,
                                      borderRadius: 0,
                                    ),
                                  )
                                : Icon(
                                    Icons.account_balance_wallet,
                                    size: 18,
                                    color: tokens.muted,
                                  ),
                          );
                        },
                      );
                    },
                    loading: () => const SizedBox(),
                    error: (error, stackTrace) => Icon(
                      Icons.error_outline,
                      size: 16,
                      color: tokens.danger,
                    ),
                  ),
          ),
          const SizedBox(width: 8),

          // 3. Cantidad
          Expanded(
            flex: 2,
            child: Container(
              height: 48, // Standardize height with DropdownMenu default (~48)
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: tokens.raised,
                border: Border.all(color: tokens.line),
              ),
              child: TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.chalk,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  filled: false,
                  hintText: '0.00',
                  hintStyle: TextStyle(color: tokens.muted2),
                  contentPadding: const EdgeInsets.only(
                    bottom: 4,
                  ), // Align text
                  isDense: true,
                ),
                onChanged: (_) => _notifyChanged(),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 4. Info (Tasa)
          Expanded(
            flex: 3,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedAccount != null)
                    Text(
                      _selectedAccount!.currencyCode ?? '',
                      style: TextStyle(
                        fontFamily: PulsoFonts.mono,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: tokens.chalk,
                      ),
                    ),
                  if (_rateFound)
                    Text(
                      _rateLabel(),
                      style: TextStyle(
                        fontFamily: PulsoFonts.mono,
                        fontSize: 10,
                        color: tokens.muted,
                      ),
                    )
                  else if (_selectedAccount != null)
                    _missingRateAction(tokens, planCurrencyLabel),
                ],
              ),
            ),
          ),

          // 5. Equivalent
          Expanded(
            flex: 2,
            child: Container(
              height: 48,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: tokens.raised,
                border: Border.all(color: tokens.line),
              ),
              child: Text(
                (_rateFound && _amountController.text.isNotEmpty)
                    ? (double.tryParse(_amountController.text) != null
                          ? _calculateEquivalent(
                              double.parse(_amountController.text),
                            ).toStringAsFixed(2)
                          : '0.00')
                    : '0.00',
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tokens.chalk,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 6. Delete
          SizedBox(
            height: 48,
            child: Center(
              child: PulsoIconButton(
                icon: Icons.delete_outline,
                tooltip: 'Quitar forma de pago',
                danger: true,
                onPressed: widget.onDelete,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _missingRateAction(PulsoTokens tokens, String planCurrencyLabel) {
    final accountCurrencyLabel = _accountCurrencyLabel();

    return InkWell(
      onTap: () => _showMissingRateDialog(planCurrencyLabel),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: tokens.dangerSoft,
          border: Border.all(color: tokens.danger.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: tokens.danger),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Falta tasa $planCurrencyLabel → $accountCurrencyLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: tokens.danger,
                    ),
                  ),
                  Text(
                    'Crear tasa o contactar admin',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, color: tokens.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline, size: 16, color: tokens.danger),
          ],
        ),
      ),
    );
  }

  // Styles
  MenuStyle _menuStyle(PulsoTokens tokens) {
    return MenuStyle(
      backgroundColor: WidgetStatePropertyAll(tokens.surface),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(4),
      shadowColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.1)),
      shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
    );
  }

  InputDecorationTheme _dropdownInputTheme(PulsoTokens tokens) {
    return InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: tokens.raised,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 0,
      ), // Vertical 0 to center
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: tokens.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: tokens.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: tokens.accent, width: 1.5),
      ),
    );
  }

  Widget _disabledCell(String text) {
    final tokens = PulsoTokens.of(context);
    return Container(
      height: 48,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border.all(color: tokens.line),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: tokens.muted),
      ),
    );
  }

  Widget _errorCell(String text) {
    final tokens = PulsoTokens.of(context);
    return Container(
      height: 48,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: tokens.dangerSoft,
        border: Border.all(color: tokens.danger.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: tokens.danger),
      ),
    );
  }

  IconData _getTypeIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('efectivo') || lower.contains('cash')) {
      return Icons.attach_money;
    } else if (lower.contains('transfer') || lower.contains('banco')) {
      return Icons.account_balance;
    } else if (lower.contains('tarjeta') || lower.contains('card')) {
      return Icons.credit_card;
    } else if (lower.contains('zelle')) {
      return Icons.send_to_mobile;
    }
    return Icons.payment;
  }
}
