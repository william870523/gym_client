import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gym_client/src/features/configuration/presentation/state/payment_type_notifier.dart';
import 'package:gym_client/src/features/financials/presentation/state/account_notifier.dart';
import 'package:gym_client/src/features/financials/presentation/providers/exchange_rate_notifier.dart';
import 'package:gym_client/src/features/configuration/data/models/payment_type_model.dart';
import 'package:gym_client/src/features/financials/data/models/account_model.dart';
import 'package:gym_client/src/features/financials/data/models/currency_model.dart';
import 'package:gym_client/src/features/financials/data/models/exchange_rate_model.dart';
import 'package:gym_client/src/features/financials/presentation/screens/exchange_rates_pulso_view.dart';
import 'package:gym_client/src/features/financials/presentation/state/currency_notifier.dart';
import 'package:gym_client/src/features/financials/presentation/widgets/exchange_rate_pulso_form.dart';
import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/widgets/app_flag.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/method_surcharge_quote.dart';
import '../../data/repositories/payment_repository.dart';

// Mismo formato que la vista de tasas: entero para 450, decimales solo si la
// tasa los tiene (una tasa inversa como 0.0022 no se puede redondear).
final _rateValueFmt = NumberFormat('#,##0.######');

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
  MethodSurchargeQuote? _methodQuote;
  bool _quoteLoading = false;
  String? _quoteError;
  int _quoteSequence = 0;

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

    final restoredReceived =
        data['inputReceived'] ?? data['inputBase'] ?? data['amount'];
    if (restoredReceived != null) {
      final amountVal = restoredReceived is num
          ? restoredReceived.toDouble()
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
    final received = double.tryParse(_amountController.text) ?? 0.0;
    _lastEmittedAmount = received;
    _methodQuote = null;
    _quoteError = null;
    _emitRow(received);
    if (_selectedType != null &&
        _selectedAccount != null &&
        _rateFound &&
        received > 0) {
      _loadMethodQuote(received);
    }
  }

  void _emitRow(double inputReceived) {
    final quote = _methodQuote;
    widget.onChanged({
      'type': _selectedType,
      'account': _selectedAccount,
      'inputReceived': inputReceived,
      'amount': quote?.totalValue ?? inputReceived,
      'rate': _currentRate,
      'rateOperation': _divideByRate ? 'divide' : 'multiply',
      'exchangeRateId': _currentRateId,
      'exchangeRateVersion': quote?.exchangeRateVersion,
      'surchargePct': quote?.percentageValue ?? 0.0,
      'surchargeAmount': quote?.surchargeValue ?? 0.0,
      'baseAmount': quote?.baseValue ?? inputReceived,
      'equivalent': quote?.planEquivalentValue ?? 0.0,
      'collectedEquivalent': quote?.totalPlanEquivalentValue ?? 0.0,
      'isValid':
          _selectedType != null &&
          _selectedAccount != null &&
          _rateFound &&
          inputReceived > 0 &&
          quote != null &&
          !_quoteLoading &&
          _quoteError == null,
    });
  }

  Future<void> _loadMethodQuote(double totalReceived) async {
    final sequence = ++_quoteSequence;
    setState(() {
      _quoteLoading = true;
      _quoteError = null;
    });
    _emitRow(totalReceived);
    try {
      final quote = await ref
          .read(paymentRepositoryProvider)
          .getMethodSurchargeQuote(
            totalReceived: totalReceived,
            paymentTypeId: _selectedType!.id,
            accountId: _selectedAccount!.id,
            paymentCurrencyId: _selectedAccount!.currencyId,
            planCurrencyId: widget.planCurrencyId,
            exchangeRateId: _currentRateId,
          );
      if (!mounted || sequence != _quoteSequence) return;
      setState(() {
        _methodQuote = quote;
        _quoteLoading = false;
      });
      _emitRow(totalReceived);
    } catch (error) {
      if (!mounted || sequence != _quoteSequence) return;
      setState(() {
        _methodQuote = null;
        _quoteLoading = false;
        _quoteError = error.toString().replaceFirst('Exception: ', '');
      });
      _emitRow(totalReceived);
    }
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
      _methodQuote = null;
      _quoteError = null;
      _quoteSequence++;
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
      _methodQuote = null;
      _quoteError = null;
      _quoteSequence++;
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
      // La moneda con la que paga el cliente es la base de la tasa —plan en
      // CUP cobrado en euros con «1 EUR = 450 CUP»—: se multiplica.
      final direct = _pickCurrentRate(rates, accountCurrencyId, planCurrencyId);
      if (direct != null) {
        _applyRateState(
          found: true,
          rate: direct.exchangeRate,
          rateId: direct.id,
        );
        return;
      }

      // Par al revés —plan en euros cobrado en CUP con esa misma tasa, o una
      // tasa dada como «1 CUP = 0.0022 EUR»—: entonces toca dividir.
      final inverse = _pickCurrentRate(
        rates,
        planCurrencyId,
        accountCurrencyId,
      );
      if (inverse != null) {
        _applyRateState(
          found: true,
          rate: inverse.exchangeRate,
          rateId: inverse.id,
          divideByRate: true,
        );
        return;
      }

      _applyRateState(found: false, rate: 0.0);
    });
  }

  /// Tasa vigente del par en el orden dado: activa, ya iniciada y sin vencer
  /// según el reloj calibrado. Si hay varias candidatas gana la de vigencia
  /// más reciente —antes ganaba la que llegara primero del API, que no ordena.
  ExchangeRateModel? _pickCurrentRate(
    List<ExchangeRateModel> rates,
    String baseCurrencyId,
    String targetCurrencyId,
  ) {
    final now = appClock.nowUtc();
    final candidates =
        rates
            .where(
              (r) =>
                  r.activo &&
                  _isSameCurrencyId(r.monedaIdBase, baseCurrencyId) &&
                  _isSameCurrencyId(r.monedaIdTarget, targetCurrencyId) &&
                  !r.fechaInicio.toUtc().isAfter(now) &&
                  !(r.fechaExpiracion?.toUtc().isBefore(now) ?? false),
            )
            .toList()
          ..sort((a, b) {
            final byStart = b.fechaInicio.compareTo(a.fechaInicio);
            if (byStart != 0) return byStart;
            final aTouched = a.updatedAt ?? a.createdAt;
            final bTouched = b.updatedAt ?? b.createdAt;
            if (aTouched == null || bTouched == null) return 0;
            return bTouched.compareTo(aTouched);
          });
    return candidates.isEmpty ? null : candidates.first;
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

  bool _isSameCurrencyId(String a, String b) {
    final left = a.trim().toLowerCase();
    final right = b.trim().toLowerCase();
    return left.isNotEmpty && right.isNotEmpty && left == right;
  }

  /// Orientación con la que se propone una tasa que falta. La calle cotiza
  /// «450 CUP por 1 EUR»: la moneda fuerte va de base y la débil de destino,
  /// y así el operador teclea 450 y no 0.0022. Se deduce de las tasas ya
  /// cargadas —si una de las dos monedas ya suele ser el destino, se respeta—
  /// porque el plan tanto puede estar en la débil como en la fuerte. Sin
  /// pistas se asume que el cliente paga en la fuerte, que es lo corriente.
  ({String baseId, String targetId}) _suggestedRateOrientation() {
    final accountId = _selectedAccount!.currencyId;
    final planId = widget.planCurrencyId;
    final rates =
        ref.read(exchangeRateProvider).value ?? const <ExchangeRateModel>[];

    var accountAsTarget = 0;
    var planAsTarget = 0;
    for (final rate in rates) {
      if (!rate.activo) continue;
      if (_isSameCurrencyId(rate.monedaIdTarget, accountId)) accountAsTarget++;
      if (_isSameCurrencyId(rate.monedaIdTarget, planId)) planAsTarget++;
    }

    if (accountAsTarget > planAsTarget) {
      return (baseId: planId, targetId: accountId);
    }
    return (baseId: accountId, targetId: planId);
  }

  String _currencyLabelFor(String currencyId) =>
      _isSameCurrencyId(currencyId, widget.planCurrencyId)
      ? _planCurrencyLabel(ref.read(currencyProvider).value ?? const [])
      : _accountCurrencyLabel();

  bool get _usesImplicitSameCurrencyRate {
    final account = _selectedAccount;
    return account != null &&
        _isSameCurrencyId(account.currencyId, widget.planCurrencyId) &&
        _currentRateId == null;
  }

  /// Se enuncia la tasa entera («1 EUR = 450 CUP») para que el recepcionista
  /// detecte de un vistazo una tasa cargada al revés; el `x`/`/` de la fórmula
  /// queda detrás porque por sí solo no dice nada.
  String _rateLabel(String planCurrencyLabel) {
    if (_usesImplicitSameCurrencyRate) return '1:1 sin tasa';
    final accountCurrencyLabel = _accountCurrencyLabel();
    final from = _divideByRate ? planCurrencyLabel : accountCurrencyLabel;
    final to = _divideByRate ? accountCurrencyLabel : planCurrencyLabel;
    final value = _rateValueFmt.format(_currentRate);
    return '1 $from = $value $to  ${_divideByRate ? '/' : 'x'}';
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

    // La tasa se precarga como la enuncia el operador («1 EUR = 450 CUP»).
    // Antes la base era siempre la moneda del plan, lo que obligaba a teclear
    // 0.0022 y acababa guardándose la tasa invertida.
    final orientation = _suggestedRateOrientation();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ExchangeRatePulsoForm(
        initialBaseCurrencyId: orientation.baseId,
        initialTargetCurrencyId: orientation.targetId,
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
    final orientation = _suggestedRateOrientation();
    final baseLabel = _currencyLabelFor(orientation.baseId);
    final targetLabel = _currencyLabelFor(orientation.targetId);
    final action = await showDialog<String>(
      context: context,
      builder: (context) => PulsoThemeScope(
        child: AlertDialog(
          title: const Text('Falta una tasa activa'),
          content: Text(
            'El cliente va a pagar en $accountCurrencyLabel y el plan está en $planCurrencyLabel. '
            'Crea la tasa $baseLabel → $targetLabel: 1 $baseLabel equivale a N $targetLabel, '
            'que es como se dice la tasa de la calle. '
            'También se acepta al revés ($targetLabel → $baseLabel), pero entonces el número de la tasa es una fracción. '
            'Si no puedes crearla, contacta al administrador.',
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          // La fila necesita 760 px para que sus cinco columnas se lean; por
          // debajo de eso se conserva ese ancho y se desplaza en horizontal.
          //
          // El umbral era 600 y dejaba una franja muerta: entre 600 y 760 la
          // fila se estrujaba sin activar el desplazamiento, y la columna
          // **TIPO** se quedaba en unos 85 px —icono, flecha y ni una letra del
          // método elegido—. Se vio a 768 px en el navegador, pero no es un
          // problema solo de web: el escritorio arranca en 800 px lógicos y con
          // el diálogo abierto cae de lleno en esa franja.
          const anchoComodo = 760.0;
          final rowWidth = constraints.maxWidth < anchoComodo
              ? anchoComodo
              : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: rowWidth,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Tipo de Pago (Searchable)
                  Expanded(
                    flex: 2,
                    child: typesAsync.when(
                      data: (types) {
                        final activeTypes = types
                            .where((t) => t.active)
                            .toList();
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
                              onSelected: _onTypeChanged,
                              leadingIcon: _selectedType != null
                                  ? Icon(
                                      _getTypeIcon(_selectedType!.name),
                                      size: 18,
                                      color: tokens.muted,
                                    )
                                  : Icon(
                                      Icons.payment,
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
                              if (filtered.isEmpty) {
                                return _errorCell('Sin cuentas');
                              }
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
                                    inputDecorationTheme: _dropdownInputTheme(
                                      tokens,
                                    ),
                                    menuStyle: _menuStyle(tokens),
                                    dropdownMenuEntries: filtered.map((
                                      account,
                                    ) {
                                      return DropdownMenuEntry<AccountModel>(
                                        value: account,
                                        label: account.name,
                                        leadingIcon:
                                            account.currencyImage != null
                                            ? AppFlag(
                                                bytes: account.currencyImage,
                                                fallbackCode:
                                                    account.currencyCode,
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
                                          foregroundColor:
                                              WidgetStatePropertyAll(
                                                tokens.chalk,
                                              ),
                                        ),
                                      );
                                    }).toList(),
                                    onSelected: _onAccountSelected,
                                    leadingIcon:
                                        _selectedAccount?.currencyImage != null
                                        ? Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: AppFlag(
                                              bytes: _selectedAccount!
                                                  .currencyImage,
                                              fallbackCode: _selectedAccount!
                                                  .currencyCode,
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

                  // 3. Total realmente recibido del cliente.
                  Expanded(
                    flex: 2,
                    child: Container(
                      height:
                          48, // Standardize height with DropdownMenu default (~48)
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
                          if (_rateFound) ...[
                            Text(
                              _rateLabel(planCurrencyLabel),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: PulsoFonts.mono,
                                fontSize: 10,
                                color: tokens.muted,
                              ),
                            ),
                            // R5.1: el método paga un poco más; la diferencia es
                            // ganancia del gimnasio y no cubre plan.
                            if (_quoteLoading)
                              Text(
                                'COTIZANDO…',
                                key: const ValueKey(
                                  'payment-row-quote-loading',
                                ),
                                style: TextStyle(
                                  fontFamily: PulsoFonts.mono,
                                  fontSize: 9,
                                  color: tokens.muted,
                                ),
                              )
                            else if (_quoteError != null)
                              // El motivo del rechazo se lee entero. Con
                              // `maxLines: 1` el operador veía «El total
                              // recibido no admite un desglos…» y se quedaba
                              // sin saber por qué no puede confirmar: la regla
                              // del recorrido es que nada se bloquee sin
                              // explicación, y aquí la explicación existía y la
                              // tapaba la vista. El tooltip cubre el caso
                              // extremo en que ni así quepa.
                              Tooltip(
                                message: _quoteError!,
                                child: Text(
                                  _quoteError!,
                                  key: const ValueKey(
                                    'payment-row-quote-error',
                                  ),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: PulsoFonts.mono,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.danger,
                                  ),
                                ),
                              )
                            else if ((_methodQuote?.percentageValue ?? 0) > 0)
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final compact = constraints.maxWidth < 110;
                                  return Text(
                                    key: const ValueKey(
                                      'payment-row-surcharge',
                                    ),
                                    compact
                                        ? '+${_methodQuote!.surcharge}\n'
                                              '=${_methodQuote!.total}'
                                        : 'BASE ${_methodQuote!.base} + RECARGO '
                                              '${_methodQuote!.percentage} % '
                                              '(${_methodQuote!.surcharge}) = '
                                              '${_methodQuote!.total}',
                                    maxLines: compact ? 2 : 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: PulsoFonts.mono,
                                      fontSize: compact ? 8 : 9,
                                      fontWeight: FontWeight.w700,
                                      color: tokens.warning,
                                    ),
                                  );
                                },
                              ),
                          ] else if (_selectedAccount != null)
                            _missingRateAction(tokens, planCurrencyLabel),
                        ],
                      ),
                    ),
                  ),

                  // 5. Total cobrado y parte que realmente cubre el plan.
                  Expanded(
                    flex: 2,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 60),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: tokens.raised,
                        border: Border.all(color: tokens.line),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _methodQuote?.totalPlanEquivalent ?? '0.00',
                            style: TextStyle(
                              fontFamily: PulsoFonts.mono,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: tokens.chalk,
                            ),
                          ),
                          if ((_methodQuote?.surchargeValue ?? 0) > 0)
                            Text(
                              'AL PLAN ${_methodQuote!.planEquivalent}',
                              style: TextStyle(
                                fontFamily: PulsoFonts.mono,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: tokens.muted,
                              ),
                            ),
                        ],
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
            ),
          );
        },
      ),
    );
  }

  Widget _missingRateAction(PulsoTokens tokens, String planCurrencyLabel) {
    final orientation = _suggestedRateOrientation();
    final baseLabel = _currencyLabelFor(orientation.baseId);
    final targetLabel = _currencyLabelFor(orientation.targetId);

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
                    'Falta tasa $baseLabel → $targetLabel',
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
      child: Text(text, style: TextStyle(fontSize: 12, color: tokens.muted)),
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
      child: Text(text, style: TextStyle(fontSize: 12, color: tokens.danger)),
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
