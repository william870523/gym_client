import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/registro_palette.dart';
import '../../../../core/widgets/app_flag.dart';
import '../../../../core/widgets/registro_widgets.dart';
import '../../../financials/data/models/currency_model.dart';
import '../../../financials/presentation/state/currency_notifier.dart';
import '../../data/models/payment_plan_model.dart';
import '../state/payment_plan_notifier.dart';
import '../widgets/payment_plan_form.dart';

/// Planes y Tarifas — "PLANES Y TARIFAS" (F-09, sistema REGISTRO).
///
/// Ver docs/DESIGN_SYSTEM.md. Reutiliza [paymentPlanProvider] y [PaymentPlanForm].
class PaymentPlansView extends ConsumerStatefulWidget {
  const PaymentPlansView({super.key});

  @override
  ConsumerState<PaymentPlansView> createState() => _PaymentPlansViewState();
}

enum _PlanFilter { all, active, inactive }

enum _PlanSortKey { name, price, duration, status }

class _PaymentPlansViewState extends ConsumerState<PaymentPlansView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _fName = TextEditingController();
  final TextEditingController _fPrice = TextEditingController();
  final TextEditingController _fDuration = TextEditingController();
  final TextEditingController _fStatus = TextEditingController();

  String _searchQuery = '';
  _PlanFilter _filter = _PlanFilter.all;
  bool _filtersVisible = false;
  _PlanSortKey _sortKey = _PlanSortKey.name;
  bool _sortAsc = true;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _fName.dispose();
    _fPrice.dispose();
    _fDuration.dispose();
    _fStatus.dispose();
    super.dispose();
  }

  void _openForm([PaymentPlanModel? plan]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentPlanForm(plan: plan),
    );
  }

  Future<void> _confirmDelete(PaymentPlanModel plan) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await RegistroDeleteDialog.show(
      context,
      title: 'ELIMINAR TARIFA',
      message:
          '¿Eliminar el plan de pago "${plan.nombre}" (${plan.formattedDuration})? '
          'Esta acción no se puede deshacer.',
    );

    if (confirmed != true) return;
    try {
      if (plan.id != null) {
        await ref.read(paymentPlanProvider.notifier).delete(plan.id!);
        if (mounted && _selectedId == plan.id) {
          setState(() => _selectedId = null);
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text('Plan "${plan.nombre}" eliminado.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al eliminar: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _matchesSearch(PaymentPlanModel plan, CurrencyModel? currency) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery;
    return plan.nombre.toLowerCase().contains(q) ||
        plan.formattedDuration.toLowerCase().contains(q) ||
        plan.importe.toString().contains(q) ||
        (plan.id ?? '').toLowerCase().contains(q) ||
        (currency?.code ?? '').toLowerCase().contains(q) ||
        (currency?.name ?? '').toLowerCase().contains(q);
  }

  bool _matchesFilter(PaymentPlanModel plan) {
    switch (_filter) {
      case _PlanFilter.active:
        return plan.activo;
      case _PlanFilter.inactive:
        return !plan.activo;
      case _PlanFilter.all:
        return true;
    }
  }

  bool _matchesColumnFilters(PaymentPlanModel plan, CurrencyModel? currency) {
    bool has(TextEditingController t, String value) {
      final f = t.text.trim().toLowerCase();
      return f.isEmpty || value.toLowerCase().contains(f);
    }

    final priceStr = '${currency?.symbol ?? '\$'} ${plan.importe.toStringAsFixed(2)} ${currency?.code ?? ''}';
    return has(_fName, plan.nombre) &&
        has(_fPrice, priceStr) &&
        has(_fDuration, '${plan.formattedDuration} ${plan.duracion} días') &&
        has(_fStatus, plan.activo ? 'ACTIVO' : 'INACTIVO');
  }

  void _toggleSort(_PlanSortKey key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sortKey = key;
        _sortAsc = true;
      }
    });
  }

  List<PaymentPlanModel> _sortList(
    List<PaymentPlanModel> list,
    Map<String, CurrencyModel> currencyMap,
  ) {
    final copy = List<PaymentPlanModel>.from(list);
    copy.sort((a, b) {
      int cmp;
      switch (_sortKey) {
        case _PlanSortKey.name:
          cmp = a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
        case _PlanSortKey.price:
          cmp = a.importe.compareTo(b.importe);
        case _PlanSortKey.duration:
          cmp = a.duracion.compareTo(b.duracion);
        case _PlanSortKey.status:
          cmp = (a.activo ? 1 : 0).compareTo(b.activo ? 1 : 0);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return copy;
  }

  Widget _buildSummarySentence(
    RegistroPalette p,
    List<PaymentPlanModel> all,
    List<PaymentPlanModel> filtered,
    Map<String, CurrencyModel> currencyMap,
  ) {
    final activeCount = all.where((pl) => pl.activo).length;
    final usedCurrencies = all.map((pl) => pl.monedaId).toSet().length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: p.rule),
          bottom: BorderSide(color: p.rule),
        ),
      ),
      child: Text.rich(
        TextSpan(
          style: GoogleFonts.archivo(
            fontSize: 16,
            height: 1.45,
            color: p.ink2,
          ),
          children: [
            const TextSpan(text: 'El catálogo contiene '),
            TextSpan(
              text: '${all.length}',
              style: GoogleFonts.archivo(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
            TextSpan(
              text: all.length == 1 ? ' tarifa registrada, con ' : ' tarifas registradas, con ',
            ),
            TextSpan(
              text: '$activeCount',
              style: GoogleFonts.archivo(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: p.verm,
              ),
            ),
            const TextSpan(text: ' planes activos en '),
            TextSpan(
              text: '$usedCurrencies',
              style: GoogleFonts.archivo(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
            TextSpan(
              text: usedCurrencies == 1 ? ' divisa de cobro.' : ' divisas de cobro.',
            ),
            if (filtered.length != all.length) ...[
              const TextSpan(text: ' (Filtrados '),
              TextSpan(
                text: '${filtered.length}',
                style: GoogleFonts.archivo(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
              const TextSpan(text: ' asientos de la consulta).'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMarginalia(
    RegistroPalette p,
    PaymentPlanModel? selected,
    CurrencyModel? currency,
  ) {
    if (selected == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: p.paper2,
          border: Border(left: BorderSide(color: p.rule)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SIN SELECCIÓN',
              style: GoogleFonts.archivo(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: p.ink3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Seleccione un plan de pago de la lista para inspeccionar la tarifa, moneda asignada y vigencia.',
              style: GoogleFonts.archivo(
                fontSize: 13,
                height: 1.4,
                color: p.ink2,
              ),
            ),
          ],
        ),
      );
    }

    final symbol = currency?.symbol ?? '\$';
    final code = currency?.code ?? 'MONEDA';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.paper2,
        border: Border(left: BorderSide(color: p.rule)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ASIENTO Y TARIFA',
                  style: GoogleFonts.archivo(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: p.ink3,
                  ),
                ),
                Text(
                  'pln_${registroShortId(selected.id ?? 'new')}',
                  style: GoogleFonts.fragmentMono(
                    fontSize: 11,
                    color: p.ink3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Figure: Price display
            Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: p.paper,
                  border: Border.all(color: p.ruleStrong, width: 2),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (currency != null) ...[
                          AppFlag(
                            base64String: currency.flagImage,
                            fallbackCode: currency.code,
                            width: 30,
                            height: 20,
                            borderRadius: 0,
                          ),
                          const SizedBox(width: 8),
                        ],
                        FittedBox(
                          child: Text(
                            '$symbol ${selected.importe.toStringAsFixed(2)}',
                            style: GoogleFonts.archivoBlack(
                              fontSize: 26,
                              color: p.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currency != null ? '${currency.code} — ${currency.name}' : 'Moneda no especificada',
                      style: GoogleFonts.fragmentMono(
                        fontSize: 11,
                        color: p.ink3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              selected.nombre,
              style: GoogleFonts.archivo(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 16),

            // Dot leaders
            RegistroDotLeader(
              p: p,
              label: 'VIGENCIA',
              value: selected.formattedDuration.toUpperCase(),
            ),
            const SizedBox(height: 8),
            RegistroDotLeader(
              p: p,
              label: 'DÍAS BASE',
              value: '${selected.duracion} DÍAS',
            ),
            const SizedBox(height: 8),
            RegistroDotLeader(
              p: p,
              label: 'MONEDA BASE',
              value: code,
            ),
            const SizedBox(height: 8),
            RegistroDotLeader(
              p: p,
              label: 'ESTADO',
              value: selected.activo ? 'ACTIVO' : 'INACTIVO',
              valueColor: selected.activo ? p.ink : p.verm,
            ),
            const SizedBox(height: 20),

            Divider(height: 1, color: p.rule),
            const SizedBox(height: 16),

            // Actions
            RegistroTextAction(
              p: p,
              label: 'EDITAR TARIFA →',
              prime: true,
              onTap: () => _openForm(selected),
            ),
            const SizedBox(height: 12),
            RegistroTextAction(
              p: p,
              label: 'ELIMINAR TARIFA',
              onTap: () => _confirmDelete(selected),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = RegistroPalette.fromContext(context);
    final plansAsync = ref.watch(paymentPlanProvider);
    final currenciesAsync = ref.watch(currencyProvider);

    return Scaffold(
      backgroundColor: p.paper,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
              _searchFocus.requestFocus(),
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
              _searchFocus.requestFocus(),
        },
        child: plansAsync.when(
          loading: () => Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: p.verm,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'componiendo el catálogo de tarifas…',
                  style: GoogleFonts.fragmentMono(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: p.ink3,
                  ),
                ),
              ],
            ),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: RegistroErrorBlock(
              p: p,
              message: 'Error al cargar planes: $err',
            ),
          ),
          data: (plans) {
            return currenciesAsync.when(
              loading: () => Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: p.verm,
                  ),
                ),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: RegistroErrorBlock(
                  p: p,
                  message: 'Error al cargar monedas: $err',
                ),
              ),
              data: (currencies) {
                final currencyMap = <String, CurrencyModel>{
                  for (final c in currencies) c.id: c,
                };

                final filtered = plans
                    .where((pl) => _matchesSearch(pl, currencyMap[pl.monedaId]))
                    .where(_matchesFilter)
                    .where((pl) => _matchesColumnFilters(pl, currencyMap[pl.monedaId]))
                    .toList();

                final sorted = _sortList(filtered, currencyMap);
                final activeCount = plans.where((pl) => pl.activo).length;
                final inactiveCount = plans.length - activeCount;

                PaymentPlanModel? selectedPlan;
                if (_selectedId != null) {
                  for (final pl in plans) {
                    if (pl.id == _selectedId) {
                      selectedPlan = pl;
                      break;
                    }
                  }
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Membrete
                      RegistroMasthead(
                        p: p,
                        department: 'TARIFAS Y CATÁLOGO',
                        code: 'F-09 / PLANES Y TARIFAS · REV. 2026',
                      ),
                      const SizedBox(height: 16),

                      // Title + Text Actions
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(text: 'PLANES\nY TARIFAS'),
                                  TextSpan(
                                    text: '.',
                                    style: TextStyle(color: p.verm),
                                  ),
                                ],
                              ),
                              style: GoogleFonts.archivoBlack(
                                fontSize: 38,
                                height: 0.95,
                                color: p.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            alignment: WrapAlignment.end,
                            children: [
                              RegistroTextAction(
                                p: p,
                                label: '↻ ACTUALIZAR',
                                onTap: () => ref.invalidate(paymentPlanProvider),
                              ),
                              RegistroTextAction(
                                p: p,
                                label: '＋ NUEVO PLAN',
                                prime: true,
                                onTap: () => _openForm(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Summary sentence KPI
                      _buildSummarySentence(p, plans, sorted, currencyMap),
                      const SizedBox(height: 16),

                      // Command line: search + tabs
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 700;
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: RegistroSearchBar(
                                      p: p,
                                      controller: _searchController,
                                      focusNode: _searchFocus,
                                      hintText:
                                          'nombre, duración, precio o moneda… (Ctrl+K)',
                                      onChanged: (v) => setState(
                                        () => _searchQuery = v.trim().toLowerCase(),
                                      ),
                                      onClear: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    ),
                                  ),
                                  if (!isNarrow) const SizedBox(width: 24),
                                  if (!isNarrow)
                                    Wrap(
                                      spacing: 16,
                                      children: [
                                        RegistroTab(
                                          p: p,
                                          label: 'TODOS',
                                          count: plans.length,
                                          active: _filter == _PlanFilter.all,
                                          onTap: () => setState(
                                            () => _filter = _PlanFilter.all,
                                          ),
                                        ),
                                        RegistroTab(
                                          p: p,
                                          label: 'ACTIVOS',
                                          count: activeCount,
                                          active: _filter == _PlanFilter.active,
                                          onTap: () => setState(
                                            () => _filter = _PlanFilter.active,
                                          ),
                                        ),
                                        RegistroTab(
                                          p: p,
                                          label: 'INACTIVOS',
                                          count: inactiveCount,
                                          active: _filter == _PlanFilter.inactive,
                                          onTap: () => setState(
                                            () => _filter = _PlanFilter.inactive,
                                          ),
                                        ),
                                        RegistroTab(
                                          p: p,
                                          label: 'FILTROS ¶',
                                          count: null,
                                          active: _filtersVisible,
                                          onTap: () => setState(
                                            () => _filtersVisible = !_filtersVisible,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              if (isNarrow) const SizedBox(height: 12),
                              if (isNarrow)
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      RegistroTab(
                                        p: p,
                                        label: 'TODOS',
                                        count: plans.length,
                                        active: _filter == _PlanFilter.all,
                                        onTap: () => setState(
                                          () => _filter = _PlanFilter.all,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      RegistroTab(
                                        p: p,
                                        label: 'ACTIVOS',
                                        count: activeCount,
                                        active: _filter == _PlanFilter.active,
                                        onTap: () => setState(
                                          () => _filter = _PlanFilter.active,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      RegistroTab(
                                        p: p,
                                        label: 'INACTIVOS',
                                        count: inactiveCount,
                                        active: _filter == _PlanFilter.inactive,
                                        onTap: () => setState(
                                          () => _filter = _PlanFilter.inactive,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      RegistroTab(
                                        p: p,
                                        label: 'FILTROS ¶',
                                        count: null,
                                        active: _filtersVisible,
                                        onTap: () => setState(
                                          () => _filtersVisible = !_filtersVisible,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),

                      // Column filters box
                      if (_filtersVisible) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: p.paper2,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _fName,
                                  onChanged: (_) => setState(() {}),
                                  cursorColor: p.verm,
                                  style: GoogleFonts.fragmentMono(
                                    fontSize: 12,
                                    color: p.ink,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'filtro nombre…',
                                    hintStyle: GoogleFonts.fragmentMono(
                                      fontSize: 12,
                                      color: p.ink4,
                                    ),
                                    isDense: true,
                                    border: UnderlineInputBorder(
                                      borderSide: BorderSide(color: p.rule),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _fPrice,
                                  onChanged: (_) => setState(() {}),
                                  cursorColor: p.verm,
                                  style: GoogleFonts.fragmentMono(
                                    fontSize: 12,
                                    color: p.ink,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'filtro precio…',
                                    hintStyle: GoogleFonts.fragmentMono(
                                      fontSize: 12,
                                      color: p.ink4,
                                    ),
                                    isDense: true,
                                    border: UnderlineInputBorder(
                                      borderSide: BorderSide(color: p.rule),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _fDuration,
                                  onChanged: (_) => setState(() {}),
                                  cursorColor: p.verm,
                                  style: GoogleFonts.fragmentMono(
                                    fontSize: 12,
                                    color: p.ink,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'filtro duración…',
                                    hintStyle: GoogleFonts.fragmentMono(
                                      fontSize: 12,
                                      color: p.ink4,
                                    ),
                                    isDense: true,
                                    border: UnderlineInputBorder(
                                      borderSide: BorderSide(color: p.rule),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Table + Marginalia main section
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 960;

                          final tableWidget = Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Table Header with rule 2px
                              Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: p.ruleStrong,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 10,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 38,
                                      child: Text('Nº', style: registroThStyle(p)),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: RegistroSortHead(
                                        p: p,
                                        label: 'PLAN DE PAGO',
                                        active: _sortKey == _PlanSortKey.name,
                                        asc: _sortAsc,
                                        onTap: () => _toggleSort(_PlanSortKey.name),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: RegistroSortHead(
                                        p: p,
                                        label: 'PRECIO Y MONEDA',
                                        active: _sortKey == _PlanSortKey.price,
                                        asc: _sortAsc,
                                        onTap: () => _toggleSort(_PlanSortKey.price),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: RegistroSortHead(
                                        p: p,
                                        label: 'DURACIÓN',
                                        active: _sortKey == _PlanSortKey.duration,
                                        asc: _sortAsc,
                                        onTap: () => _toggleSort(_PlanSortKey.duration),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 90,
                                      child: RegistroSortHead(
                                        p: p,
                                        label: 'ESTADO',
                                        active: _sortKey == _PlanSortKey.status,
                                        asc: _sortAsc,
                                        onTap: () => _toggleSort(_PlanSortKey.status),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Rows block
                              if (sorted.isEmpty)
                                RegistroEmptyBlock(
                                  p: p,
                                  message:
                                      'No se encontraron planes que coincidan con la consulta.',
                                )
                              else
                                RegistroScrollableRows(
                                  p: p,
                                  itemCount: sorted.length,
                                  itemBuilder: (context, index) {
                                    final item = sorted[index];
                                    final isSelected = item.id == _selectedId;
                                    final numStr = (index + 1)
                                        .toString()
                                        .padLeft(2, '0');

                                    final currency = currencyMap[item.monedaId];
                                    final symbol = currency?.symbol ?? '\$';
                                    final code = currency?.code ?? '';

                                    return MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () => setState(
                                          () => _selectedId = item.id,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? p.vermSoft
                                                : Colors.transparent,
                                            border: Border(
                                              left: BorderSide(
                                                color: isSelected
                                                    ? p.verm
                                                    : Colors.transparent,
                                                width: 3,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 35,
                                                child: Text(
                                                  numStr,
                                                  style: GoogleFonts.fragmentMono(
                                                    fontSize: 11,
                                                    color: isSelected
                                                        ? p.verm
                                                        : p.ink4,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w700
                                                        : FontWeight.w400,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.nombre,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: GoogleFonts.archivo(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w700,
                                                        color: p.ink,
                                                      ),
                                                    ),
                                                    Text(
                                                      item.id != null
                                                          ? 'pln_${registroShortId(item.id!)}'
                                                          : 'nuevo',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style:
                                                          GoogleFonts.fragmentMono(
                                                        fontSize: 10.5,
                                                        color: p.ink3,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Row(
                                                  children: [
                                                    if (currency != null) ...[
                                                      AppFlag(
                                                        base64String:
                                                            currency.flagImage,
                                                        fallbackCode:
                                                            currency.code,
                                                        width: 24,
                                                        height: 16,
                                                        borderRadius: 0,
                                                      ),
                                                      const SizedBox(width: 8),
                                                    ],
                                                    Expanded(
                                                      child: Text(
                                                        '$symbol ${item.importe.toStringAsFixed(2)} ${code.isNotEmpty ? code : ''}',
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                        style:
                                                            GoogleFonts.fragmentMono(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: p.ink,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  '${item.formattedDuration} (${item.duracion}d)',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.fragmentMono(
                                                    fontSize: 11,
                                                    color: p.ink2,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 90,
                                                child: Text(
                                                  item.activo
                                                      ? 'ACTIVO'
                                                      : 'INACTIVO',
                                                  style: GoogleFonts.fragmentMono(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: item.activo
                                                        ? p.ink
                                                        : p.verm,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),

                              // Table colophon
                              Container(
                                padding: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: p.ruleStrong, width: 2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${sorted.length} de ${plans.length} asientos · orden: ${_sortKey.name} ${_sortAsc ? "↑" : "↓"}',
                                        style: GoogleFonts.fragmentMono(
                                          fontSize: 11,
                                          color: p.ink3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );

                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: tableWidget),
                                const SizedBox(width: 24),
                                SizedBox(
                                  width: 280,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: KeyedSubtree(
                                      key: ValueKey(_selectedId),
                                      child: _buildMarginalia(
                                        p,
                                        selectedPlan,
                                        selectedPlan != null
                                            ? currencyMap[selectedPlan.monedaId]
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                tableWidget,
                                const SizedBox(height: 24),
                                _buildMarginalia(
                                  p,
                                  selectedPlan,
                                  selectedPlan != null
                                      ? currencyMap[selectedPlan.monedaId]
                                      : null,
                                ),
                              ],
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
