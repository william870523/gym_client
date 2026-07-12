import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/registro_palette.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/registro_widgets.dart';
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
import '../widgets/client_picker_dialog.dart';
import '../widgets/process_payment_dialog.dart';

DateTime _paymentTimeInGym(DateTime instant) =>
    toGymWallClock(instant, appClock.gymTimezone);

enum _PaymentStatusFilter { all, paid, voided }

enum _PaymentSort { date, member, plan, method, amount, status }

class PaymentsView extends ConsumerStatefulWidget {
  const PaymentsView({super.key});

  @override
  ConsumerState<PaymentsView> createState() => _PaymentsViewState();
}

class _PaymentsViewState extends ConsumerState<PaymentsView> {
  static final _money = NumberFormat('#,##0.00', 'es');
  static final _date = DateFormat('yyyy-MM-dd');
  static final _time = DateFormat('HH:mm');

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _horizontalController = ScrollController();

  _PaymentStatusFilter _status = _PaymentStatusFilter.all;
  _PaymentSort _sort = _PaymentSort.date;
  bool _sortAscending = false;
  bool _showFilters = false;
  String? _selectedId;
  String _query = '';
  final Map<_PaymentSort, String> _columnFilters = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
      _refreshAll();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _horizontalController.dispose();
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
    final confirmed = await RegistroDeleteDialog.show(
      context,
      title: 'ANULAR PAGO',
      message:
          'El pago ${registroShortId(payment.id)} quedará marcado como anulado '
          'y dejará de contabilizarse en el parte del día.',
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(paymentNotifierProvider.notifier).voidPayment(payment.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago marcado como anulado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo anular el pago: $error')),
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
          _date.format(_paymentTimeInGym(payment.fecha)),
          _time.format(_paymentTimeInGym(payment.fecha)),
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
      final statusMatches = switch (_status) {
        _PaymentStatusFilter.all => true,
        _PaymentStatusFilter.paid => !payment.isDeleted,
        _PaymentStatusFilter.voided => payment.isDeleted,
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

      bool contains(_PaymentSort key, String value) {
        final filter = _columnFilters[key]?.trim().toLowerCase() ?? '';
        return filter.isEmpty || value.toLowerCase().contains(filter);
      }

      return contains(
            _PaymentSort.date,
            _date.format(_paymentTimeInGym(payment.fecha)),
          ) &&
          contains(_PaymentSort.member, member) &&
          contains(_PaymentSort.plan, plan) &&
          contains(_PaymentSort.method, method) &&
          contains(_PaymentSort.amount, payment.amount.toStringAsFixed(2)) &&
          contains(
            _PaymentSort.status,
            payment.isDeleted ? 'anulado' : 'pagado',
          );
    }).toList();

    int comparison(PaymentModel left, PaymentModel right) {
      return switch (_sort) {
        _PaymentSort.date => left.fecha.compareTo(right.fecha),
        _PaymentSort.member => _clientName(
          left,
          clients,
        ).compareTo(_clientName(right, clients)),
        _PaymentSort.plan => (plans[left.planId] ?? left.planId).compareTo(
          plans[right.planId] ?? right.planId,
        ),
        _PaymentSort.method => _methodName(
          left,
          types,
        ).compareTo(_methodName(right, types)),
        _PaymentSort.amount => left.amount.compareTo(right.amount),
        _PaymentSort.status => left.isDeleted.toString().compareTo(
          right.isDeleted.toString(),
        ),
      };
    }

    result.sort((left, right) {
      final value = comparison(left, right);
      return _sortAscending ? value : -value;
    });
    return result;
  }

  void _changeSort(_PaymentSort value) {
    setState(() {
      if (_sort == value) {
        _sortAscending = !_sortAscending;
      } else {
        _sort = value;
        _sortAscending = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNight = Theme.of(context).brightness == Brightness.dark;
    final p = RegistroPalette.of(isNight);

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

    final paidCount = payments.where((payment) => !payment.isDeleted).length;
    final voidCount = payments.length - paidCount;
    final foreignCount = payments.where((payment) {
      return (payment.details ?? const <PaymentDetailModel>[]).any(
        (detail) => detail.currencyId != payment.currencyId,
      );
    }).length;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _searchFocus.requestFocus,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: p.paper,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(44, 30, 44, 72),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RegistroMasthead(
                    p: p,
                    department: 'FINANZAS',
                    code: 'F-04 / PAGOS · REV. 2026',
                  ),
                  const SizedBox(height: 26),
                  _buildTitle(p),
                  const SizedBox(height: 18),
                  _buildSummary(
                    p,
                    payments.length,
                    paidCount,
                    voidCount,
                    foreignCount,
                  ),
                  const SizedBox(height: 24),
                  _buildCommandBar(p, payments.length, paidCount, voidCount),
                  const SizedBox(height: 28),
                  if (paymentsAsync.isLoading && payments.isEmpty)
                    RegistroLoadingBlock(p: p)
                  else if (paymentsAsync.hasError && payments.isEmpty)
                    RegistroErrorBlock(
                      p: p,
                      message: paymentsAsync.error.toString(),
                    )
                  else
                    _buildSheet(
                      p: p,
                      payments: payments,
                      visible: visible,
                      selected: selected,
                      selectedId: selectedId,
                      clients: clients,
                      plans: plans,
                      types: types,
                      currencies: currencies,
                      accounts: accounts,
                      rates: rates,
                      trainers: trainers,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(RegistroPalette p) {
    final actions = Wrap(
      spacing: 26,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        RegistroTextAction(p: p, label: '↻ ACTUALIZAR', onTap: _refreshAll),
        RegistroTextAction(
          p: p,
          label: '↓ EXPORTAR',
          onTap: () {
            final payments = ref.read(paymentNotifierProvider).value ?? [];
            final clients = {
              for (final item
                  in ref.read(clientNotifierProvider).value ??
                      const <ClientModel>[])
                item.id: item,
            };
            final plans = {
              for (final item
                  in ref.read(paymentPlanProvider).value ??
                      const <PaymentPlanModel>[])
                if (item.id != null) item.id!: item.nombre,
            };
            final types = {
              for (final item
                  in ref.read(paymentTypesProvider).value ??
                      const <PaymentTypeModel>[])
                item.id: item,
            };
            final currencies = {
              for (final item
                  in ref.read(currencyProvider).value ??
                      const <CurrencyModel>[])
                item.id: item,
            };
            _exportToClipboard(payments, clients, plans, types, currencies);
          },
        ),
        RegistroTextAction(
          p: p,
          label: '＋ PROCESAR PAGO',
          prime: true,
          onTap: _openNewPayment,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Text.rich(
          TextSpan(
            text: 'LIBRO\nDE PAGOS',
            children: [
              TextSpan(
                text: '.',
                style: TextStyle(color: p.verm),
              ),
            ],
          ),
          style: GoogleFonts.archivoBlack(
            fontSize: 46,
            height: 0.98,
            letterSpacing: 0,
            color: p.ink,
          ),
        );
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 24), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: title),
            const SizedBox(width: 24),
            Flexible(child: actions),
          ],
        );
      },
    );
  }

  Widget _buildSummary(
    RegistroPalette p,
    int total,
    int paid,
    int voided,
    int foreign,
  ) {
    final base = GoogleFonts.archivo(fontSize: 19, height: 1.6, color: p.ink2);
    final number = GoogleFonts.archivo(
      fontSize: 25,
      fontWeight: FontWeight.w800,
      color: p.ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: p.rule),
          bottom: BorderSide(color: p.rule),
        ),
      ),
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            const TextSpan(text: 'El libro contiene '),
            TextSpan(text: '$total', style: number),
            TextSpan(text: total == 1 ? ' pago; ' : ' pagos; '),
            TextSpan(text: '$paid', style: number),
            const TextSpan(text: ' siguen vigentes, '),
            TextSpan(
              text: '$voided',
              style: number.copyWith(color: voided > 0 ? p.verm : p.ink),
            ),
            TextSpan(
              text: voided == 1 ? ' fue anulado y ' : ' fueron anulados y ',
            ),
            TextSpan(text: '$foreign', style: number),
            TextSpan(
              text: foreign == 1
                  ? ' incluye conversión de divisa.'
                  : ' incluyen conversión de divisa.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandBar(RegistroPalette p, int total, int paid, int voided) {
    final search = AnimatedBuilder(
      animation: _searchFocus,
      builder: (context, child) => Container(
        height: 42,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: _searchFocus.hasFocus ? p.verm : p.ruleStrong,
              width: _searchFocus.hasFocus ? 2 : 1.2,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              'BUSCAR',
              style: GoogleFonts.archivo(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: _searchFocus.hasFocus ? p.verm : p.ink3,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const ValueKey('payments-search'),
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: (value) => setState(() => _query = value),
                cursorColor: p.verm,
                style: GoogleFonts.archivo(fontSize: 14, color: p.ink),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: 'socio, CI, concepto, método o ID…',
                  hintStyle: GoogleFonts.archivo(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: p.ink4,
                  ),
                ),
              ),
            ),
            Text(
              'CTRL K',
              style: GoogleFonts.fragmentMono(fontSize: 9, color: p.ink4),
            ),
          ],
        ),
      ),
    );

    final tabs = Wrap(
      spacing: 22,
      runSpacing: 10,
      children: [
        RegistroTab(
          p: p,
          label: 'TODOS',
          count: total,
          active: _status == _PaymentStatusFilter.all,
          onTap: () => setState(() => _status = _PaymentStatusFilter.all),
        ),
        RegistroTab(
          p: p,
          label: 'PAGADOS',
          count: paid,
          active: _status == _PaymentStatusFilter.paid,
          onTap: () => setState(() => _status = _PaymentStatusFilter.paid),
        ),
        RegistroTab(
          p: p,
          label: 'ANULADOS',
          count: voided,
          active: _status == _PaymentStatusFilter.voided,
          onTap: () => setState(() => _status = _PaymentStatusFilter.voided),
        ),
        RegistroTab(
          p: p,
          label: 'FILTROS ¶',
          count: null,
          active: _showFilters,
          onTap: () => setState(() => _showFilters = !_showFilters),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [search, const SizedBox(height: 16), tabs],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: search),
            const SizedBox(width: 28),
            tabs,
          ],
        );
      },
    );
  }

  Widget _buildSheet({
    required RegistroPalette p,
    required List<PaymentModel> payments,
    required List<PaymentModel> visible,
    required PaymentModel? selected,
    required String? selectedId,
    required Map<String, ClientModel> clients,
    required Map<String, String> plans,
    required Map<String, PaymentTypeModel> types,
    required Map<String, CurrencyModel> currencies,
    required Map<String, AccountModel> accounts,
    required Map<String, ExchangeRateModel> rates,
    required Map<String, TrainerModel> trainers,
  }) {
    final ledger = _buildLedger(
      p: p,
      allCount: payments.length,
      visible: visible,
      selectedId: selectedId,
      clients: clients,
      plans: plans,
      types: types,
      currencies: currencies,
    );
    final marginalia = selected == null
        ? RegistroEmptyBlock(
            p: p,
            message: 'Seleccione un asiento para consultar el recibo.',
          )
        : _PaymentMarginalia(
            p: p,
            payment: selected,
            receiptNumber: payments.indexOf(selected) + 1,
            clientName: _clientName(selected, clients),
            planName: plans[selected.planId] ?? selected.planId,
            methodName: _methodName(selected, types),
            currency: currencies[selected.currencyId],
            types: types,
            currencies: currencies,
            accounts: accounts,
            rates: rates,
            trainer: trainers[selected.trainerId],
            onReceipt: () => _showReceipt(
              p: p,
              payment: selected,
              clientName: _clientName(selected, clients),
              planName: plans[selected.planId] ?? selected.planId,
              types: types,
              currencies: currencies,
              accounts: accounts,
              rates: rates,
            ),
            onVoid: selected.isDeleted ? null : () => _voidPayment(selected),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1000) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [ledger, const SizedBox(height: 38), marginalia],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: ledger),
            const SizedBox(width: 44),
            SizedBox(width: 280, child: marginalia),
          ],
        );
      },
    );
  }

  Widget _buildLedger({
    required RegistroPalette p,
    required int allCount,
    required List<PaymentModel> visible,
    required String? selectedId,
    required Map<String, ClientModel> clients,
    required Map<String, String> plans,
    required Map<String, PaymentTypeModel> types,
    required Map<String, CurrencyModel> currencies,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(880.0, constraints.maxWidth);
        return Scrollbar(
          controller: _horizontalController,
          thumbVisibility: constraints.maxWidth < 880,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTableHeader(p),
                  if (_showFilters) _buildFilterRow(p),
                  if (visible.isEmpty)
                    RegistroEmptyBlock(
                      p: p,
                      message: 'No hay asientos que coincidan con la consulta.',
                    )
                  else
                    RegistroScrollableRows(
                      p: p,
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final payment = visible[index];
                        return _PaymentLedgerRow(
                          key: ValueKey(payment.id),
                          p: p,
                          index: index + 1,
                          payment: payment,
                          clientName: _clientName(payment, clients),
                          planName: plans[payment.planId] ?? payment.planId,
                          methodName: _methodName(payment, types),
                          currency: currencies[payment.currencyId],
                          selected: payment.id == selectedId,
                          onTap: () => setState(() => _selectedId = payment.id),
                        );
                      },
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: p.ruleStrong, width: 2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${visible.length} de $allCount asientos',
                          style: GoogleFonts.fragmentMono(
                            fontSize: 10,
                            color: p.ink3,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'los importes conservan su moneda original',
                          style: GoogleFonts.fragmentMono(
                            fontSize: 9.5,
                            fontStyle: FontStyle.italic,
                            color: p.ink3,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'orden: ${_sortLabel(_sort)} '
                          '${_sortAscending ? '↑' : '↓'}',
                          style: GoogleFonts.fragmentMono(
                            fontSize: 10,
                            color: p.ink3,
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
      },
    );
  }

  Widget _buildTableHeader(RegistroPalette p) {
    Widget head(_PaymentSort sort, String label, {bool right = false}) =>
        RegistroSortHead(
          p: p,
          label: label,
          active: _sort == sort,
          asc: _sortAscending,
          alignRight: right,
          onTap: () => _changeSort(sort),
        );

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.ruleStrong, width: 2)),
      ),
      child: Row(
        children: [
          SizedBox(width: 42, child: Text('Nº', style: registroThStyle(p))),
          SizedBox(width: 116, child: head(_PaymentSort.date, 'FECHA')),
          SizedBox(width: 200, child: head(_PaymentSort.member, 'SOCIO')),
          Expanded(child: head(_PaymentSort.plan, 'CONCEPTO')),
          SizedBox(width: 145, child: head(_PaymentSort.method, 'MÉTODO')),
          SizedBox(
            width: 110,
            child: head(_PaymentSort.amount, 'IMPORTE', right: true),
          ),
          SizedBox(width: 90, child: head(_PaymentSort.status, 'ESTADO')),
        ],
      ),
    );
  }

  Widget _buildFilterRow(RegistroPalette p) {
    Widget field(_PaymentSort key, String hint, {TextAlign? align}) {
      return TextField(
        onChanged: (value) => setState(() => _columnFilters[key] = value),
        cursorColor: p.verm,
        textAlign: align ?? TextAlign.left,
        style: GoogleFonts.fragmentMono(fontSize: 10.5, color: p.ink),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: GoogleFonts.fragmentMono(
            fontSize: 10,
            fontStyle: FontStyle.italic,
            color: p.ink4,
          ),
          contentPadding: const EdgeInsets.only(bottom: 5),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: p.rule),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: p.verm, width: 1.5),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      color: p.paper2,
      child: Row(
        children: [
          const SizedBox(width: 42),
          SizedBox(width: 116, child: field(_PaymentSort.date, 'aaaa-mm-dd')),
          SizedBox(width: 200, child: field(_PaymentSort.member, 'socio')),
          Expanded(child: field(_PaymentSort.plan, 'concepto')),
          SizedBox(width: 145, child: field(_PaymentSort.method, 'método')),
          SizedBox(
            width: 110,
            child: field(
              _PaymentSort.amount,
              'importe',
              align: TextAlign.right,
            ),
          ),
          SizedBox(width: 90, child: field(_PaymentSort.status, 'estado')),
        ],
      ),
    );
  }

  String _sortLabel(_PaymentSort sort) => switch (sort) {
    _PaymentSort.date => 'fecha',
    _PaymentSort.member => 'socio',
    _PaymentSort.plan => 'concepto',
    _PaymentSort.method => 'método',
    _PaymentSort.amount => 'importe',
    _PaymentSort.status => 'estado',
  };

  Future<void> _showReceipt({
    required RegistroPalette p,
    required PaymentModel payment,
    required String clientName,
    required String planName,
    required Map<String, PaymentTypeModel> types,
    required Map<String, CurrencyModel> currencies,
    required Map<String, AccountModel> accounts,
    required Map<String, ExchangeRateModel> rates,
  }) {
    final currency = currencies[payment.currencyId];
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: p.paper,
        shape: Border(top: BorderSide(color: p.verm, width: 3)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 24, 30, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'RECIBO · ${registroShortId(payment.id)}',
                  style: GoogleFonts.archivo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: p.ink3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  clientName,
                  style: GoogleFonts.archivo(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_date.format(_paymentTimeInGym(payment.fecha))} · '
                  '${_time.format(_paymentTimeInGym(payment.fecha))} · $planName',
                  style: GoogleFonts.fragmentMono(fontSize: 11, color: p.ink3),
                ),
                const SizedBox(height: 24),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final detail
                            in payment.details ?? const <PaymentDetailModel>[])
                          _ReceiptDetail(
                            p: p,
                            detail: detail,
                            payment: payment,
                            type: types[detail.paymentTypeId],
                            currency: currencies[detail.currencyId],
                            account: detail.accountId == null
                                ? null
                                : accounts[detail.accountId],
                            rate: detail.exchangeRateId == null
                                ? null
                                : rates[detail.exchangeRateId],
                            currencies: currencies,
                          ),
                        if (payment.details?.isNotEmpty != true)
                          RegistroEmptyBlock(
                            p: p,
                            message: 'El pago no contiene desglose económico.',
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.only(top: 14),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: p.ruleStrong)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${currency?.symbol ?? '\$'}'
                        '${_money.format(payment.amount)} '
                        '${currency?.code ?? ''}',
                        style: GoogleFonts.fragmentMono(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: p.ink,
                        ),
                      ),
                      const Spacer(),
                      RegistroDialogTextAction(
                        p: p,
                        label: 'CERRAR',
                        onTap: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentLedgerRow extends StatefulWidget {
  const _PaymentLedgerRow({
    super.key,
    required this.p,
    required this.index,
    required this.payment,
    required this.clientName,
    required this.planName,
    required this.methodName,
    required this.currency,
    required this.selected,
    required this.onTap,
  });

  final RegistroPalette p;
  final int index;
  final PaymentModel payment;
  final String clientName;
  final String planName;
  final String methodName;
  final CurrencyModel? currency;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PaymentLedgerRow> createState() => _PaymentLedgerRowState();
}

class _PaymentLedgerRowState extends State<_PaymentLedgerRow> {
  static final _date = DateFormat('yyyy-MM-dd');
  static final _time = DateFormat('HH:mm');
  static final _money = NumberFormat('#,##0.00', 'es');
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final payment = widget.payment;
    final background = widget.selected
        ? p.vermSoft
        : _hover
        ? p.paper2
        : Colors.transparent;
    final mono = GoogleFonts.fragmentMono(fontSize: 11, color: p.ink2);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: 56,
          color: background,
          child: Row(
            children: [
              Container(
                width: 3,
                color: widget.selected ? p.verm : Colors.transparent,
              ),
              SizedBox(
                width: 39,
                child: Text(
                  widget.index.toString().padLeft(2, '0'),
                  style: mono.copyWith(
                    color: widget.selected ? p.verm : p.ink4,
                  ),
                ),
              ),
              SizedBox(
                width: 116,
                child: Text.rich(
                  TextSpan(
                    text: _date.format(_paymentTimeInGym(payment.fecha)),
                    children: [
                      TextSpan(
                        text:
                            '\n${_time.format(_paymentTimeInGym(payment.fecha))}',
                        style: TextStyle(color: p.ink4),
                      ),
                    ],
                  ),
                  style: mono,
                ),
              ),
              SizedBox(
                width: 200,
                child: Text(
                  widget.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.archivo(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  widget.planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.archivo(fontSize: 12.5, color: p.ink),
                ),
              ),
              SizedBox(
                width: 145,
                child: Text(
                  widget.methodName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.fragmentMono(
                    fontSize: 10.5,
                    color: p.ink2,
                  ),
                ),
              ),
              SizedBox(
                width: 110,
                child: Text(
                  '${widget.currency?.symbol ?? '\$'}'
                  '${_money.format(payment.amount)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.fragmentMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 78,
                child: Text(
                  payment.isDeleted ? 'ANULADO' : 'PAGADO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.archivo(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: payment.isDeleted ? p.verm : p.ink2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMarginalia extends StatelessWidget {
  const _PaymentMarginalia({
    required this.p,
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
    required this.onReceipt,
    required this.onVoid,
  });

  final RegistroPalette p;
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
  final VoidCallback onReceipt;
  final VoidCallback? onVoid;

  static final _money = NumberFormat('#,##0.##', 'es');
  static final _date = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context) {
    final details = payment.details ?? const <PaymentDetailModel>[];
    final accountNames = <String>{
      for (final detail in details)
        if (detail.accountId != null && accounts[detail.accountId] != null)
          accounts[detail.accountId]!.name,
    }.join(' + ');
    final trainerName = trainer == null
        ? '—'
        : '${trainer!.nombres ?? ''} ${trainer!.apellidos ?? ''}'.trim();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Container(
        key: ValueKey(payment.id),
        padding: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.ruleStrong, width: 2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'RECIBO Nº ${receiptNumber.toString().padLeft(2, '0')}',
              style: GoogleFonts.archivo(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.7,
                color: p.ink3,
              ),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${currency?.symbol ?? '\$'}${_money.format(payment.amount)}',
                style: GoogleFonts.archivoBlack(
                  fontSize: 62,
                  height: 0.9,
                  color: payment.isDeleted ? p.ink4 : p.verm,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              clientName.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.archivo(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_date.format(_paymentTimeInGym(payment.fecha))} · '
              '${methodName.toUpperCase()}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.fragmentMono(fontSize: 10, color: p.ink3),
            ),
            const SizedBox(height: 22),
            RegistroKvLeader(p: p, k: 'CONCEPTO', v: planName),
            RegistroKvLeader(
              p: p,
              k: 'MONEDA',
              v: currency?.code ?? payment.currencyId,
              mono: true,
            ),
            RegistroKvLeader(
              p: p,
              k: 'CUENTA',
              v: accountNames.isEmpty ? '—' : accountNames,
            ),
            RegistroKvLeader(
              p: p,
              k: 'ENTRENADOR',
              v: trainerName.isEmpty ? '—' : trainerName,
            ),
            RegistroKvLeader(p: p, k: 'CI', v: payment.ci, mono: true),
            RegistroKvLeader(
              p: p,
              k: 'ID',
              v: registroShortId(payment.id),
              mono: true,
            ),
            const SizedBox(height: 20),
            Text(
              'DESGLOSE DEL COBRO',
              style: GoogleFonts.archivo(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: p.ink3,
              ),
            ),
            const SizedBox(height: 8),
            if (details.isEmpty)
              Text(
                'sin detalle económico ¶',
                style: GoogleFonts.fragmentMono(
                  fontSize: 10.5,
                  fontStyle: FontStyle.italic,
                  color: p.ink3,
                ),
              )
            else
              for (final detail in details.take(3))
                _ReceiptDetail(
                  p: p,
                  detail: detail,
                  payment: payment,
                  type: types[detail.paymentTypeId],
                  currency: currencies[detail.currencyId],
                  account: detail.accountId == null
                      ? null
                      : accounts[detail.accountId],
                  rate: detail.exchangeRateId == null
                      ? null
                      : rates[detail.exchangeRateId],
                  currencies: currencies,
                ),
            const SizedBox(height: 22),
            RegistroMarginAction(p: p, label: 'VER RECIBO', onTap: onReceipt),
            if (onVoid != null) ...[
              const SizedBox(height: 12),
              RegistroMarginAction(p: p, label: 'ANULAR PAGO', onTap: onVoid!),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                '† PAGO ANULADO',
                style: GoogleFonts.archivo(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: p.verm,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReceiptDetail extends StatelessWidget {
  const _ReceiptDetail({
    required this.p,
    required this.detail,
    required this.payment,
    required this.type,
    required this.currency,
    required this.account,
    required this.rate,
    required this.currencies,
  });

  final RegistroPalette p;
  final PaymentDetailModel detail;
  final PaymentModel payment;
  final PaymentTypeModel? type;
  final CurrencyModel? currency;
  final AccountModel? account;
  final ExchangeRateModel? rate;
  final Map<String, CurrencyModel> currencies;

  static final _money = NumberFormat('#,##0.00', 'es');

  @override
  Widget build(BuildContext context) {
    final sameCurrency = detail.currencyId == payment.currencyId;
    final rateText = sameCurrency
        ? 'misma moneda · tasa 1:1'
        : rate == null
        ? 'tasa no disponible'
        : '1 ${currencies[rate!.monedaIdBase]?.code ?? 'BASE'} = '
              '${rate!.exchangeRate.toStringAsFixed(4)} '
              '${currencies[rate!.monedaIdTarget]?.code ?? 'DESTINO'}';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.rule)),
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
                  style: GoogleFonts.archivo(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
              ),
              Text(
                '${currency?.symbol ?? '\$'}${_money.format(detail.amount)}',
                style: GoogleFonts.fragmentMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: p.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${account?.name ?? 'sin cuenta'} · $rateText',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.fragmentMono(
              fontSize: 9.5,
              fontStyle: FontStyle.italic,
              color: p.ink3,
            ),
          ),
        ],
      ),
    );
  }
}
