import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../clients/data/models/client_model.dart';
import '../../../clients/presentation/state/client_notifier.dart';
import '../../../configuration/data/models/payment_type_model.dart';
import '../../../financials/data/models/account_model.dart';
import '../../../financials/data/models/currency_model.dart';
import '../../../financials/data/models/exchange_rate_model.dart';
import '../../../financials/presentation/state/currency_notifier.dart';
import '../../../products/data/models/payment_plan_model.dart';
import '../../../products/presentation/state/payment_plan_notifier.dart';
import '../../../trainers/data/models/trainer_model.dart';
import '../../../trainers/presentation/providers/trainer_notifier.dart';
import '../../data/models/payment_model.dart';
import '../state/payment_notifier.dart';
import '../state/payment_refresh_coordinator.dart';
import '../widgets/client_picker_dialog.dart';
import '../widgets/process_payment_dialog.dart';

// El pago es un instante UTC; el libro lo presenta en la zona del gimnasio.
DateTime _paymentTimeInGym(DateTime instant) =>
    toGymWallClock(instant, appClock.gymTimezone);

final _money = NumberFormat('#,##0.00', 'es');
final _dateFmt = DateFormat('yyyy-MM-dd');
final _timeFmt = DateFormat('HH:mm');

String _shortPaymentId(String id) {
  if (id.length <= 8) return id;
  return '${id.substring(0, 4)}…${id.substring(id.length - 4)}';
}

enum _PayFilter { all, paid, voided }

enum _PaySort { date, member, plan, method, amount, status }

class PaymentsPulsoView extends ConsumerStatefulWidget {
  const PaymentsPulsoView({super.key});

  @override
  ConsumerState<PaymentsPulsoView> createState() => _PaymentsPulsoViewState();
}

class _PaymentsPulsoViewState extends ConsumerState<PaymentsPulsoView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  _PayFilter _filter = _PayFilter.all;
  _PaySort _sort = _PaySort.date;
  bool _ascending = false; // el libro abre con lo más reciente arriba
  bool _showColumnFilters = false;
  String? _selectedId;
  String _query = '';
  final Map<_PaySort, String> _columnFilters = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshAll();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      ref.read(paymentNotifierProvider.notifier).refresh(),
      ref.read(clientNotifierProvider.notifier).refresh(),
      ref.read(paymentPlanProvider.notifier).refresh(),
      ref.read(currencyProvider.notifier).refresh(),
      ref.read(trainerProvider.notifier).refresh(),
    ]);
    ref.invalidate(paymentTypesProvider);
    ref.invalidate(accountsProvider);
    ref.invalidate(exchangeRatesProvider);
  }

  Future<void> _openNewPayment() async {
    final client = await showDialog<ClientModel>(
      context: context,
      builder: (_) => const ClientPickerDialog(),
    );
    if (!mounted || client == null) return;

    final planId = client.planId?.trim() ?? '';
    if (planId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El socio no tiene un plan asignado. Edite su ficha antes de cobrar.',
          ),
        ),
      );
      return;
    }

    final paid = await showDialog<bool>(
      context: context,
      builder: (_) => ProcessPaymentDialog(client: client, planId: planId),
    );
    if (paid == true && mounted) {
      await _refreshAll();
    }
  }

  Future<void> _voidPayment(PaymentModel payment) async {
    var reasonDraft = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => PulsoThemeScope(
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            scrollable: true,
            title: const Text('Anular pago'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'El pago ${_shortPaymentId(payment.id)} dejará de contar '
                  'como ingreso. La membresía volverá a pendiente y las '
                  'comisiones no pagadas serán anuladas.',
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('payment-reversal-reason'),
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  autofocus: true,
                  onChanged: (value) => setDialogState(() {
                    reasonDraft = value;
                  }),
                  decoration: const InputDecoration(
                    labelText: 'Motivo de la anulación',
                    hintText: 'Ej.: cobro duplicado o método incorrecto',
                    helperText:
                        'Quedará guardado en el historial de auditoría.',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Si ya se pagó una cuota al entrenador, la operación será '
                  'bloqueada para proteger la contabilidad.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              PulsoSecondaryButton(
                label: 'Cancelar',
                onPressed: () => Navigator.of(context).pop(),
              ),
              PulsoSecondaryButton(
                label: 'Anular pago',
                danger: true,
                onPressed: reasonDraft.trim().length < 5
                    ? null
                    : () => Navigator.of(context).pop(reasonDraft.trim()),
              ),
            ],
          ),
        ),
      ),
    );
    if (reason == null || !mounted) return;

    try {
      final result = await ref
          .read(paymentNotifierProvider.notifier)
          .voidPayment(payment.id, reason: reason);
      await ref
          .read(paymentRefreshCoordinatorProvider)
          .afterPaymentMutation(payment.ci, refreshPayments: false);
      if (!mounted) return;
      final impact = <String>[
        if (result.membershipsPending > 0)
          '${result.membershipsPending} membresía(s) pendiente(s)',
        if (result.commissionsVoided > 0)
          '${result.commissionsVoided} comisión(es) anulada(s)',
      ];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            impact.isEmpty
                ? 'Pago anulado y vistas actualizadas.'
                : 'Pago anulado: ${impact.join(' · ')}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('No se pudo anular el pago: $error'),
        ),
      );
    }
  }

  void _exportToClipboard(
    List<PaymentModel> payments,
    Map<String, ClientModel> clients,
    Map<String, String> plans,
    Map<String, PaymentTypeModel> types,
    Map<String, CurrencyModel> currencies,
  ) {
    String csv(String value) => '"${value.replaceAll('"', '""')}"';
    final lines = <String>[
      'fecha,hora,socio,ci,concepto,metodo,importe,moneda,estado,id',
      for (final payment in payments)
        [
          _dateFmt.format(_paymentTimeInGym(payment.fecha)),
          _timeFmt.format(_paymentTimeInGym(payment.fecha)),
          _clientName(payment, clients),
          payment.ci,
          plans[payment.planId] ?? payment.planId,
          _methodName(payment, types),
          payment.amount.toStringAsFixed(2),
          currencies[payment.currencyId]?.code ?? payment.currencyId,
          payment.isDeleted ? 'anulado' : 'pagado',
          payment.id,
        ].map(csv).join(','),
    ];
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${payments.length} asientos copiados en formato CSV.'),
      ),
    );
  }

  String _clientName(PaymentModel payment, Map<String, ClientModel> clients) {
    final client = clients[payment.ci];
    final catalogName = client == null
        ? ''
        : '${client.nombres ?? ''} ${client.apellidos ?? ''}'.trim();
    if (catalogName.isNotEmpty) return catalogName;
    if (payment.clientName?.trim().isNotEmpty == true) {
      return payment.clientName!.trim();
    }
    return payment.ci;
  }

  String _methodName(
    PaymentModel payment,
    Map<String, PaymentTypeModel> types,
  ) {
    final names = <String>{
      for (final detail in payment.details ?? const <PaymentDetailModel>[])
        types[detail.paymentTypeId]?.name.trim().isNotEmpty == true
            ? types[detail.paymentTypeId]!.name.trim()
            : 'Sin clasificar',
    };
    return names.isEmpty ? 'Sin detalle' : names.join(' + ');
  }

  List<PaymentModel> _visiblePayments({
    required List<PaymentModel> payments,
    required Map<String, ClientModel> clients,
    required Map<String, String> plans,
    required Map<String, PaymentTypeModel> types,
    required Map<String, CurrencyModel> currencies,
  }) {
    final normalizedQuery = _query.trim().toLowerCase();
    final result = payments.where((payment) {
      final statusMatches = switch (_filter) {
        _PayFilter.all => true,
        _PayFilter.paid => !payment.isDeleted,
        _PayFilter.voided => payment.isDeleted,
      };
      if (!statusMatches) return false;

      final member = _clientName(payment, clients);
      final plan = plans[payment.planId] ?? payment.planId;
      final method = _methodName(payment, types);
      final currency =
          currencies[payment.currencyId]?.code ?? payment.currencyId;
      final haystack = [
        member,
        payment.ci,
        plan,
        method,
        currency,
        payment.id,
      ].join(' ').toLowerCase();
      if (normalizedQuery.isNotEmpty && !haystack.contains(normalizedQuery)) {
        return false;
      }

      bool contains(_PaySort key, String value) {
        final filter = _columnFilters[key]?.trim().toLowerCase() ?? '';
        return filter.isEmpty || value.toLowerCase().contains(filter);
      }

      return contains(
            _PaySort.date,
            _dateFmt.format(_paymentTimeInGym(payment.fecha)),
          ) &&
          contains(_PaySort.member, member) &&
          contains(_PaySort.plan, plan) &&
          contains(_PaySort.method, method) &&
          contains(_PaySort.amount, payment.amount.toStringAsFixed(2)) &&
          contains(_PaySort.status, payment.isDeleted ? 'anulado' : 'pagado');
    }).toList();

    int comparison(PaymentModel left, PaymentModel right) {
      return switch (_sort) {
        _PaySort.date => left.fecha.compareTo(right.fecha),
        _PaySort.member => _clientName(
          left,
          clients,
        ).compareTo(_clientName(right, clients)),
        _PaySort.plan => (plans[left.planId] ?? left.planId).compareTo(
          plans[right.planId] ?? right.planId,
        ),
        _PaySort.method => _methodName(
          left,
          types,
        ).compareTo(_methodName(right, types)),
        _PaySort.amount => left.amount.compareTo(right.amount),
        _PaySort.status => left.isDeleted.toString().compareTo(
          right.isDeleted.toString(),
        ),
      };
    }

    result.sort((left, right) {
      final value = comparison(left, right);
      return _ascending ? value : -value;
    });
    return result;
  }

  void _changeSort(_PaySort value) {
    setState(() {
      if (_sort == value) {
        _ascending = !_ascending;
      } else {
        _sort = value;
        _ascending = value != _PaySort.date;
      }
    });
  }

  void _showDetailDialog(BuildContext context, _ReceiptData data) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => PulsoThemeScope(
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 40,
          ),
          child: SizedBox(
            width: 360,
            height: 560,
            child: _PaymentReceiptPanel(
              data: data,
              onReceipt: () {
                Navigator.of(dialogContext).pop();
                _showReceipt(data);
              },
              onVoid: data.payment.isDeleted
                  ? null
                  : () {
                      Navigator.of(dialogContext).pop();
                      _voidPayment(data.payment);
                    },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showReceipt(_ReceiptData data) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => PulsoThemeScope(
        child: Builder(
          builder: (context) {
            final tokens = PulsoTokens.of(context);
            final payment = data.payment;
            final when = _paymentTimeInGym(payment.fecha);
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 620,
                  maxHeight: 720,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(height: 4, color: tokens.accent),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PulsoLabel(
                              'Recibo · ${_shortPaymentId(payment.id)}',
                            ),
                            const SizedBox(height: 14),
                            Text(
                              data.clientName,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_dateFmt.format(when)} · '
                              '${_timeFmt.format(when)} · ${data.planName}',
                              style: TextStyle(
                                fontFamily: PulsoFonts.mono,
                                fontSize: 11,
                                color: tokens.muted,
                              ),
                            ),
                            if (payment.isDeleted) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                color: tokens.warningSoft,
                                child: Text(
                                  'PAGO ANULADO',
                                  style: TextStyle(
                                    fontFamily: PulsoFonts.mono,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.warning,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            _DetailLine(
                              label: 'Cobrado por',
                              value: payment.collectorName == null
                                  ? 'Sin atribuir · histórico'
                                  : '${payment.collectorName}'
                                        '${payment.collectorRole == null ? '' : ' · ${payment.collectorRole}'}',
                            ),
                            if (payment.isDeleted) ...[
                              _DetailLine(
                                label: 'Anulado por',
                                value:
                                    payment.voidedByName ??
                                    'Sin identidad disponible',
                              ),
                              _DetailLine(
                                label: 'Motivo',
                                value: payment.voidReason ?? 'Sin motivo',
                                multiline: true,
                              ),
                            ],
                            const SizedBox(height: 18),
                            if (payment.listPriceSnapshot != null) ...[
                              _PaymentDiscountSnapshot(
                                payment: payment,
                                currencySymbol: data.currency?.symbol ?? r'$',
                              ),
                              const SizedBox(height: 12),
                            ],
                            Flexible(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (final detail
                                        in payment.details ??
                                            const <PaymentDetailModel>[])
                                      _PulsoReceiptDetail(
                                        detail: detail,
                                        payment: payment,
                                        type: data.types[detail.paymentTypeId],
                                        currency:
                                            data.currencies[detail.currencyId],
                                        account: detail.accountId == null
                                            ? null
                                            : data.accounts[detail.accountId],
                                        rate: detail.exchangeRateId == null
                                            ? null
                                            : data.rates[detail.exchangeRateId],
                                        currencies: data.currencies,
                                      ),
                                    if (payment.details?.isNotEmpty != true)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 20,
                                        ),
                                        child: Text(
                                          'El pago no contiene desglose económico.',
                                          style: TextStyle(
                                            color: tokens.muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.only(top: 14),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: tokens.lineStrong),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${data.currency?.symbol ?? r'$'}'
                                      '${_money.format(payment.amount)} '
                                      '${data.currency?.code ?? ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: PulsoFonts.mono,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.chalk,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  PulsoSecondaryButton(
                                    label: 'Cerrar',
                                    onPressed: () =>
                                        Navigator.pop(dialogContext),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return PulsoThemeScope(
      child: Builder(
        builder: (context) => ColoredBox(
          color: PulsoTokens.of(context).floor,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                  _searchFocus.requestFocus,
              const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                  _searchFocus.requestFocus,
            },
            child: Focus(autofocus: true, child: _buildPage(context)),
          ),
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context) {
    final paymentsAsync = ref.watch(paymentNotifierProvider);
    final payments = paymentsAsync.value ?? const <PaymentModel>[];
    final clients = {
      for (final client
          in ref.watch(clientNotifierProvider).value ?? const <ClientModel>[])
        client.id: client,
    };
    final plans = {
      for (final plan
          in ref.watch(paymentPlanProvider).value ?? const <PaymentPlanModel>[])
        if (plan.id != null) plan.id!: plan.nombre,
    };
    final types = {
      for (final type
          in ref.watch(paymentTypesProvider).value ??
              const <PaymentTypeModel>[])
        type.id: type,
    };
    final currencies = {
      for (final currency
          in ref.watch(currencyProvider).value ?? const <CurrencyModel>[])
        currency.id: currency,
    };
    final accounts = {
      for (final account
          in ref.watch(accountsProvider).value ?? const <AccountModel>[])
        account.id: account,
    };
    final rates = {
      for (final rate
          in ref.watch(exchangeRatesProvider).value ??
              const <ExchangeRateModel>[])
        rate.id: rate,
    };
    final trainers = {
      for (final trainer
          in ref.watch(trainerProvider).value ?? const <TrainerModel>[])
        trainer.id: trainer,
    };

    final visible = _visiblePayments(
      payments: payments,
      clients: clients,
      plans: plans,
      types: types,
      currencies: currencies,
    );
    final selectedId = visible.any((payment) => payment.id == _selectedId)
        ? _selectedId
        : visible.firstOrNull?.id;
    final selected = selectedId == null
        ? null
        : visible.firstWhere((payment) => payment.id == selectedId);

    // H6: los totales los cuenta el servidor (no la página cargada). Antes,
    // `payments.length` se calcaba como «total» y, con paginación, enseñaba
    // una cifra falsa (p. ej. «500 Pagos» habiendo 631).
    final totals = ref.read(paymentNotifierProvider.notifier);
    final totalCount = totals.total;
    final voidCount = totals.totalVoided;
    final paidCount = totalCount - voidCount;
    final foreignCount = payments.where((payment) {
      return (payment.details ?? const <PaymentDetailModel>[]).any(
        (detail) => detail.currencyId != payment.currencyId,
      );
    }).length;

    _ReceiptData receiptData(PaymentModel payment) => _ReceiptData(
      payment: payment,
      receiptNumber: payments.indexOf(payment) + 1,
      clientName: _clientName(payment, clients),
      planName: plans[payment.planId] ?? payment.planId,
      methodName: _methodName(payment, types),
      currency: currencies[payment.currencyId],
      types: types,
      currencies: currencies,
      accounts: accounts,
      rates: rates,
      trainer: trainers[payment.trainerId],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final scrollPage = compact || constraints.maxHeight < 760;
        final padding = compact
            ? 16.0
            : constraints.maxWidth < 840
            ? 24.0
            : 32.0;
        final workspaceWide = constraints.maxWidth - (padding * 2) >= 1040;

        final Widget catalog;
        if (paymentsAsync.isLoading && payments.isEmpty) {
          catalog = const PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.loading,
              message: 'Cargando el libro de pagos…',
            ),
          );
        } else if (paymentsAsync.hasError && payments.isEmpty) {
          catalog = PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message: 'No se pudo cargar el libro.\n${paymentsAsync.error}',
              onRetry: _refreshAll,
            ),
          );
        } else if (visible.isEmpty) {
          catalog = PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.empty,
              message: payments.isEmpty
                  ? 'Todavía no hay pagos registrados.'
                  : 'No hay asientos que coincidan con la consulta.',
            ),
          );
        } else {
          final list = _PaymentList(
            items: visible,
            allCount: payments.length,
            clients: clients,
            plans: plans,
            types: types,
            currencies: currencies,
            selectedId: workspaceWide ? selectedId : null,
            sort: _sort,
            ascending: _ascending,
            showColumnFilters: _showColumnFilters,
            columnFilters: _columnFilters,
            clientName: _clientName,
            methodName: _methodName,
            onSort: _changeSort,
            onColumnFilter: (key, value) =>
                setState(() => _columnFilters[key] = value),
            onSelect: (payment) {
              if (workspaceWide) {
                setState(() => _selectedId = payment.id);
              } else {
                _showDetailDialog(context, receiptData(payment));
              }
            },
          );
          catalog = !workspaceWide
              ? list
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: list),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 330,
                      child: selected == null
                          ? const PulsoPanel(
                              child: PulsoStateView(
                                kind: PulsoStateKind.empty,
                                message:
                                    'Selecciona un asiento para consultar el recibo.',
                              ),
                            )
                          : _PaymentReceiptPanel(
                              data: receiptData(selected),
                              onReceipt: () =>
                                  _showReceipt(receiptData(selected)),
                              onVoid: selected.isDeleted
                                  ? null
                                  : () => _voidPayment(selected),
                            ),
                    ),
                  ],
                );
        }

        final page = Column(
          mainAxisSize: scrollPage ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PaymentHeader(
              onCreate: _openNewPayment,
              onExport: () => _exportToClipboard(
                payments,
                clients,
                plans,
                types,
                currencies,
              ),
            ),
            const SizedBox(height: 14),
            PulsoMetricStrip(
              metrics: [
                PulsoMetricData(
                  value: '$totalCount',
                  label: 'Pagos',
                  note: 'asientos del libro',
                  emphasis: true,
                ),
                PulsoMetricData(
                  value: '$paidCount',
                  label: 'Vigentes',
                  note: 'contabilizan en el parte',
                ),
                PulsoMetricData(
                  value: '$voidCount',
                  label: 'Anulados',
                  note: 'fuera del parte del día',
                  warning: voidCount > 0,
                ),
                PulsoMetricData(
                  value: '$foreignCount',
                  label: 'Con conversión',
                  note: 'incluyen cambio de divisa',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PaymentCommand(
              controller: _searchController,
              focusNode: _searchFocus,
              filter: _filter,
              filtersActive: _showColumnFilters,
              onSearch: (value) => setState(() => _query = value),
              onFilter: (value) => setState(() => _filter = value),
              onToggleFilters: () =>
                  setState(() => _showColumnFilters = !_showColumnFilters),
              onRefresh: _refreshAll,
            ),
            const SizedBox(height: 12),
            if (scrollPage)
              SizedBox(height: 420, child: catalog)
            else
              Expanded(child: catalog),
            const SizedBox(height: 8),
            const _PaymentFooter(),
          ],
        );
        final insets = EdgeInsets.fromLTRB(
          padding,
          compact ? 16 : 20,
          padding,
          compact ? 18 : 24,
        );
        return scrollPage
            ? SingleChildScrollView(padding: insets, child: page)
            : Padding(padding: insets, child: page);
      },
    );
  }
}

/// Datos resueltos del recibo de un pago (catálogos ya cruzados).
class _ReceiptData {
  const _ReceiptData({
    required this.payment,
    required this.receiptNumber,
    required this.clientName,
    required this.planName,
    required this.methodName,
    required this.currency,
    required this.types,
    required this.currencies,
    required this.accounts,
    required this.rates,
    required this.trainer,
  });

  final PaymentModel payment;
  final int receiptNumber;
  final String clientName;
  final String planName;
  final String methodName;
  final CurrencyModel? currency;
  final Map<String, PaymentTypeModel> types;
  final Map<String, CurrencyModel> currencies;
  final Map<String, AccountModel> accounts;
  final Map<String, ExchangeRateModel> rates;
  final TrainerModel? trainer;
}

class _PaymentHeader extends StatelessWidget {
  const _PaymentHeader({required this.onCreate, required this.onExport});
  final VoidCallback onCreate;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PulsoLabel('PULSO · FINANZAS'),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                text: 'LIBRO DE PAGOS',
                children: [
                  TextSpan(
                    text: '.',
                    style: TextStyle(color: tokens.accent),
                  ),
                ],
              ),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Cada cobro conserva su moneda original y su recibo detallado.',
              style: TextStyle(color: tokens.muted, fontSize: 14),
            ),
          ],
        );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PulsoSecondaryButton(
              label: 'Exportar CSV',
              icon: Icons.copy_all_outlined,
              onPressed: onExport,
            ),
            PulsoPrimaryButton(
              label: 'Procesar pago',
              icon: Icons.add,
              onPressed: onCreate,
            ),
          ],
        );
        return constraints.maxWidth < 760
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, const SizedBox(height: 14), actions],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 24),
                  actions,
                ],
              );
      },
    );
  }
}

class _PaymentCommand extends StatelessWidget {
  const _PaymentCommand({
    required this.controller,
    required this.focusNode,
    required this.filter,
    required this.filtersActive,
    required this.onSearch,
    required this.onFilter,
    required this.onToggleFilters,
    required this.onRefresh,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final _PayFilter filter;
  final bool filtersActive;
  final ValueChanged<String> onSearch;
  final ValueChanged<_PayFilter> onFilter;
  final VoidCallback onToggleFilters;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return PulsoPanel(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            key: const ValueKey('pulso-payments-search'),
            controller: controller,
            focusNode: focusNode,
            onChanged: onSearch,
            decoration: const InputDecoration(
              hintText: 'Buscar socio, CI, concepto, método o ID…',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          );
          final controls = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _FilterButton(
                label: 'Todos',
                selected: filter == _PayFilter.all,
                onTap: () => onFilter(_PayFilter.all),
              ),
              _FilterButton(
                label: 'Pagados',
                selected: filter == _PayFilter.paid,
                onTap: () => onFilter(_PayFilter.paid),
              ),
              _FilterButton(
                label: 'Anulados',
                selected: filter == _PayFilter.voided,
                onTap: () => onFilter(_PayFilter.voided),
              ),
              _FilterButton(
                label: 'Filtros ¶',
                selected: filtersActive,
                onTap: onToggleFilters,
              ),
              PulsoIconButton(
                icon: Icons.refresh,
                tooltip: 'Actualizar',
                onPressed: onRefresh,
              ),
            ],
          );
          return constraints.maxWidth < 860
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [search, const SizedBox(height: 8), controls],
                )
              : Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 10),
                    controls,
                  ],
                );
        },
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Material(
      color: selected ? tokens.accentSoft : tokens.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? tokens.accent : tokens.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? tokens.chalk : tokens.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentList extends StatelessWidget {
  const _PaymentList({
    required this.items,
    required this.allCount,
    required this.clients,
    required this.plans,
    required this.types,
    required this.currencies,
    required this.selectedId,
    required this.sort,
    required this.ascending,
    required this.showColumnFilters,
    required this.columnFilters,
    required this.clientName,
    required this.methodName,
    required this.onSort,
    required this.onColumnFilter,
    required this.onSelect,
  });

  final List<PaymentModel> items;
  final int allCount;
  final Map<String, ClientModel> clients;
  final Map<String, String> plans;
  final Map<String, PaymentTypeModel> types;
  final Map<String, CurrencyModel> currencies;
  final String? selectedId;
  final _PaySort sort;
  final bool ascending;
  final bool showColumnFilters;
  final Map<_PaySort, String> columnFilters;
  final String Function(PaymentModel, Map<String, ClientModel>) clientName;
  final String Function(PaymentModel, Map<String, PaymentTypeModel>) methodName;
  final ValueChanged<_PaySort> onSort;
  final void Function(_PaySort, String) onColumnFilter;
  final ValueChanged<PaymentModel> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 46),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: tokens.line)),
                ),
                child: Row(
                  children: [
                    if (compact)
                      Expanded(
                        child: _SortButton(
                          label: 'Pago',
                          active: sort == _PaySort.date,
                          ascending: ascending,
                          onTap: () => onSort(_PaySort.date),
                        ),
                      )
                    else ...[
                      SizedBox(
                        width: 96,
                        child: _SortButton(
                          label: 'Fecha',
                          active: sort == _PaySort.date,
                          ascending: ascending,
                          onTap: () => onSort(_PaySort.date),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _SortButton(
                          label: 'Socio',
                          active: sort == _PaySort.member,
                          ascending: ascending,
                          onTap: () => onSort(_PaySort.member),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _SortButton(
                          label: 'Concepto',
                          active: sort == _PaySort.plan,
                          ascending: ascending,
                          onTap: () => onSort(_PaySort.plan),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _SortButton(
                          label: 'Método',
                          active: sort == _PaySort.method,
                          ascending: ascending,
                          onTap: () => onSort(_PaySort.method),
                        ),
                      ),
                      SizedBox(
                        width: 108,
                        child: _SortButton(
                          label: 'Importe',
                          active: sort == _PaySort.amount,
                          ascending: ascending,
                          onTap: () => onSort(_PaySort.amount),
                        ),
                      ),
                      SizedBox(
                        width: 86,
                        child: _SortButton(
                          label: 'Estado',
                          active: sort == _PaySort.status,
                          ascending: ascending,
                          onTap: () => onSort(_PaySort.status),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showColumnFilters)
                _PaymentFilterRow(
                  compact: compact,
                  filters: columnFilters,
                  onChanged: onColumnFilter,
                ),
              Expanded(
                child: ListView.separated(
                  key: const PageStorageKey('pulso-payments-list'),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: tokens.line),
                  itemBuilder: (context, index) {
                    final payment = items[index];
                    return _PaymentRow(
                      key: ValueKey(payment.id),
                      payment: payment,
                      clientName: clientName(payment, clients),
                      planName: plans[payment.planId] ?? payment.planId,
                      methodName: methodName(payment, types),
                      currency: currencies[payment.currencyId],
                      selected: selectedId == payment.id,
                      compact: compact,
                      onTap: () => onSelect(payment),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: tokens.line)),
                ),
                child: Text(
                  '${items.length} de $allCount asientos · los importes '
                  'conservan su moneda original',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 9,
                    color: tokens.muted2,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentFilterRow extends StatelessWidget {
  const _PaymentFilterRow({
    required this.compact,
    required this.filters,
    required this.onChanged,
  });
  final bool compact;
  final Map<_PaySort, String> filters;
  final void Function(_PaySort, String) onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    Widget field(_PaySort key, String hint) {
      return TextField(
        key: ValueKey('pulso-payments-filter-${key.name}'),
        onChanged: (value) => onChanged(key, value),
        style: TextStyle(
          fontFamily: PulsoFonts.mono,
          fontSize: 11,
          color: tokens.chalk,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: 10,
            color: tokens.muted2,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
        ),
      );
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.all(10),
        color: tokens.raised,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (key, hint) in const [
              (_PaySort.date, 'aaaa-mm-dd'),
              (_PaySort.member, 'socio'),
              (_PaySort.plan, 'concepto'),
              (_PaySort.method, 'método'),
              (_PaySort.amount, 'importe'),
              (_PaySort.status, 'estado'),
            ])
              SizedBox(width: 150, child: field(key, hint)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      color: tokens.raised,
      child: Row(
        children: [
          SizedBox(width: 96, child: field(_PaySort.date, 'aaaa-mm-dd')),
          const SizedBox(width: 6),
          Expanded(flex: 3, child: field(_PaySort.member, 'socio')),
          const SizedBox(width: 6),
          Expanded(flex: 3, child: field(_PaySort.plan, 'concepto')),
          const SizedBox(width: 6),
          Expanded(flex: 2, child: field(_PaySort.method, 'método')),
          const SizedBox(width: 6),
          SizedBox(width: 102, child: field(_PaySort.amount, 'importe')),
          const SizedBox(width: 6),
          SizedBox(width: 80, child: field(_PaySort.status, 'estado')),
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
  });
  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.zero,
        foregroundColor: active ? tokens.accent : tokens.muted,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: PulsoLabel(label, color: active ? tokens.accent : null),
          ),
          if (active) ...[
            const SizedBox(width: 4),
            Icon(
              ascending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 12,
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    super.key,
    required this.payment,
    required this.clientName,
    required this.planName,
    required this.methodName,
    required this.currency,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final PaymentModel payment;
  final String clientName;
  final String planName;
  final String methodName;
  final CurrencyModel? currency;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final when = _paymentTimeInGym(payment.fecha);
    final amount =
        '${currency?.symbol ?? r'$'}${_money.format(payment.amount)}';
    final statusColor = payment.isDeleted ? tokens.warning : tokens.success;
    return Material(
      color: selected ? tokens.accentSoftStrong : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? tokens.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: compact
              ? Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clientName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: payment.isDeleted
                                  ? tokens.muted
                                  : tokens.chalk,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_dateFmt.format(when)} ${_timeFmt.format(when)}'
                            ' · $planName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: PulsoFonts.mono,
                              fontSize: 9.5,
                              color: tokens.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          amount,
                          style: TextStyle(
                            fontFamily: PulsoFonts.mono,
                            fontWeight: FontWeight.w600,
                            color: tokens.chalkDim,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          payment.isDeleted ? 'ANULADO' : 'PAGADO',
                          style: TextStyle(
                            fontFamily: PulsoFonts.mono,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text.rich(
                        TextSpan(
                          text: _dateFmt.format(when),
                          children: [
                            TextSpan(
                              text: '\n${_timeFmt.format(when)}',
                              style: TextStyle(color: tokens.muted2),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 11,
                          color: tokens.chalkDim,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        clientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: payment.isDeleted
                              ? tokens.muted
                              : tokens.chalk,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        planName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: tokens.chalkDim),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        methodName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 10,
                          color: tokens.muted,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 108,
                      child: Text(
                        amount,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontWeight: FontWeight.w600,
                          color: tokens.chalk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 74,
                      child: Row(
                        children: [
                          Container(width: 6, height: 6, color: statusColor),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              payment.isDeleted ? 'ANULADO' : 'PAGADO',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: PulsoFonts.mono,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PaymentReceiptPanel extends StatelessWidget {
  const _PaymentReceiptPanel({
    required this.data,
    required this.onReceipt,
    required this.onVoid,
  });

  final _ReceiptData data;
  final VoidCallback onReceipt;
  final VoidCallback? onVoid;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final payment = data.payment;
    final when = _paymentTimeInGym(payment.fecha);
    final details = payment.details ?? const <PaymentDetailModel>[];
    final accountNames = <String>{
      for (final detail in details)
        if (detail.accountId != null && data.accounts[detail.accountId] != null)
          data.accounts[detail.accountId]!.name,
    }.join(' + ');
    final trainerName = data.trainer == null
        ? '—'
        : '${data.trainer!.nombres ?? ''} ${data.trainer!.apellidos ?? ''}'
              .trim();

    return PulsoPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PulsoLabel(
            'Recibo Nº ${data.receiptNumber.toString().padLeft(2, '0')}',
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${data.currency?.symbol ?? r'$'}${_money.format(payment.amount)}',
              maxLines: 1,
              style: TextStyle(
                fontFamily: PulsoFonts.display,
                fontSize: 48,
                height: 0.9,
                fontWeight: FontWeight.w800,
                color: payment.isDeleted ? tokens.muted : tokens.accent,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            payment.isDeleted ? 'ANULADO' : 'PAGADO',
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: payment.isDeleted ? tokens.warning : tokens.success,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            data.clientName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '${_dateFmt.format(when)} ${_timeFmt.format(when)} · '
            '${data.methodName.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 10,
              color: tokens.muted,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DetailLine(
                    label: 'Concepto',
                    value:
                        '${payment.planCodeSnapshot ?? data.planName}'
                        '${payment.installmentSuffixSnapshot ?? ''}',
                  ),
                  if (payment.clientCategorySnapshot != null)
                    _DetailLine(
                      label: 'Categoría al cobrar',
                      value: payment.clientCategorySnapshot!,
                    ),
                  _DetailLine(
                    label: 'Moneda',
                    value: data.currency?.code ?? payment.currencyId,
                  ),
                  _DetailLine(
                    label: 'Cuenta',
                    value: accountNames.isEmpty ? '—' : accountNames,
                  ),
                  _DetailLine(
                    label: 'Entrenador',
                    value: trainerName.isEmpty ? '—' : trainerName,
                  ),
                  _DetailLine(label: 'CI', value: payment.ci),
                  // H5: quién cobró (R5.6). Los cobros anteriores al corte no
                  // tienen cobrador: se enseña «histórico».
                  _DetailLine(
                    label: 'Cobrado por',
                    value: payment.collectorName == null
                        ? 'Sin atribuir · histórico'
                        : '${payment.collectorName}'
                              '${payment.collectorRole == null ? '' : ' · ${payment.collectorRole}'}',
                  ),
                  if (payment.isDeleted) ...[
                    _DetailLine(
                      label: 'Anulado por',
                      value: payment.voidedByName ?? 'Sin identidad disponible',
                    ),
                    _DetailLine(
                      label: 'Motivo',
                      value: payment.voidReason ?? 'Sin motivo',
                      multiline: true,
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (payment.listPriceSnapshot != null) ...[
                    _PaymentDiscountSnapshot(
                      payment: payment,
                      currencySymbol: data.currency?.symbol ?? r'$',
                    ),
                    const SizedBox(height: 14),
                  ],
                  const PulsoLabel('Desglose del cobro'),
                  const SizedBox(height: 4),
                  if (details.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'sin detalle económico',
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 10,
                          color: tokens.muted,
                        ),
                      ),
                    )
                  else
                    for (final detail in details.take(3))
                      _PulsoReceiptDetail(
                        detail: detail,
                        payment: payment,
                        type: data.types[detail.paymentTypeId],
                        currency: data.currencies[detail.currencyId],
                        account: detail.accountId == null
                            ? null
                            : data.accounts[detail.accountId],
                        rate: detail.exchangeRateId == null
                            ? null
                            : data.rates[detail.exchangeRateId],
                        currencies: data.currencies,
                      ),
                  if (details.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '+${details.length - 3} formas más en el recibo completo',
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 9,
                          color: tokens.muted2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          PulsoPrimaryButton(
            label: 'Ver recibo',
            icon: Icons.receipt_long_outlined,
            onPressed: onReceipt,
          ),
          const SizedBox(height: 8),
          if (onVoid != null)
            PulsoSecondaryButton(
              label: 'Anular pago',
              icon: Icons.block_outlined,
              danger: true,
              onPressed: onVoid,
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              color: tokens.warningSoft,
              child: Text(
                'PAGO ANULADO',
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: tokens.warning,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            payment.id,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              color: tokens.muted2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.multiline = false,
  });
  final String label;
  final String value;
  final bool multiline;
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final labelWidget = PulsoLabel(label);
    final valueWidget = Text(
      value,
      maxLines: multiline ? null : 1,
      overflow: multiline ? TextOverflow.visible : TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: PulsoFonts.mono,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: tokens.chalkDim,
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: MediaQuery.sizeOf(context).width < 500
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 4), valueWidget],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: labelWidget),
                Flexible(child: valueWidget),
              ],
            ),
    );
  }
}

class _PaymentDiscountSnapshot extends StatelessWidget {
  const _PaymentDiscountSnapshot({
    required this.payment,
    required this.currencySymbol,
  });

  final PaymentModel payment;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final list = payment.listPriceSnapshot ?? payment.amount;
    final discount = payment.discountAmountSnapshot ?? 0;
    final pct = payment.discountPctSnapshot;
    return Container(
      key: const ValueKey('payment-discount-snapshot'),
      padding: const EdgeInsets.all(12),
      color: discount > 0 ? tokens.successSoft : tokens.raised2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PulsoLabel('Precio congelado al cobrar'),
          const SizedBox(height: 7),
          _DetailLine(
            label: 'Precio de lista',
            value: '$currencySymbol${_money.format(list)}',
          ),
          _DetailLine(
            label: pct == null ? 'Descuento' : 'Descuento ($pct%)',
            value: '-$currencySymbol${_money.format(discount)}',
          ),
          _DetailLine(
            label: 'Precio del plan',
            value: '$currencySymbol${_money.format(list - discount)}',
          ),
        ],
      ),
    );
  }
}

class _PulsoReceiptDetail extends StatelessWidget {
  const _PulsoReceiptDetail({
    required this.detail,
    required this.payment,
    required this.type,
    required this.currency,
    required this.account,
    required this.rate,
    required this.currencies,
  });

  final PaymentDetailModel detail;
  final PaymentModel payment;
  final PaymentTypeModel? type;
  final CurrencyModel? currency;
  final AccountModel? account;
  final ExchangeRateModel? rate;
  final Map<String, CurrencyModel> currencies;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final sameCurrency = detail.currencyId == payment.currencyId;
    final rateText = sameCurrency
        ? 'misma moneda · tasa 1:1'
        : rate == null
        ? 'tasa no disponible'
        : '1 ${currencies[rate!.monedaIdBase]?.code ?? 'BASE'} = '
              '${rate!.exchangeRate.toStringAsFixed(4)} '
              '${currencies[rate!.monedaIdTarget]?.code ?? 'DESTINO'}';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  type?.name ?? 'Sin clasificar',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.chalk,
                  ),
                ),
              ),
              Text(
                '${currency?.symbol ?? r'$'}${_money.format(detail.amount)}',
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.chalk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${account?.name ?? 'sin cuenta'} · $rateText',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9.5,
              color: tokens.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentFooter extends StatelessWidget {
  const _PaymentFooter();
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Row(
      children: [
        const PulsoSyncStatus(compact: true),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'PULSO · LIBRO DE PAGOS · DATOS REALES',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              color: tokens.muted2,
            ),
          ),
        ),
      ],
    );
  }
}
