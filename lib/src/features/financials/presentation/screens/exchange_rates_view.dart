import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/registro_palette.dart';
import '../../../../core/widgets/app_flag.dart';
import '../../../../core/widgets/registro_widgets.dart';
import '../../../dashboard/presentation/state/dashboard_nav_provider.dart';
import '../../data/models/currency_model.dart';
import '../../data/models/exchange_rate_model.dart';
import '../providers/exchange_rate_notifier.dart';
import '../state/currency_notifier.dart';
import '../widgets/exchange_rate_form.dart';

/// Tipos de cambio — "PIZARRA CAMBIARIA" (F-05, sistema REGISTRO).
///
/// Ver docs/DESIGN_SYSTEM.md y docs/registro_shell.html. Reutiliza
/// [exchangeRateProvider], [currencyProvider] y [ExchangeRateForm].
class ExchangeRatesView extends ConsumerStatefulWidget {
  final bool activeOnly;
  final String? initialBaseCurrencyId;
  final String? initialTargetCurrencyId;

  const ExchangeRatesView({
    super.key,
    this.activeOnly = false,
    this.initialBaseCurrencyId,
    this.initialTargetCurrencyId,
  });

  @override
  ConsumerState<ExchangeRatesView> createState() => _ExchangeRatesViewState();
}

enum _RateFilter { all, active, expired }

enum _RateSortKey { pair, rate, since, expires, status }

class _ExchangeRatesViewState extends ConsumerState<ExchangeRatesView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _fPair = TextEditingController();
  final TextEditingController _fRate = TextEditingController();
  final TextEditingController _fSince = TextEditingController();
  final TextEditingController _fExpires = TextEditingController();
  final TextEditingController _fStatus = TextEditingController();

  String _searchQuery = '';
  _RateFilter _filter = _RateFilter.all;
  bool _filtersVisible = false;
  _RateSortKey _sortKey = _RateSortKey.pair;
  bool _sortAsc = true;
  String? _selectedId;

  static final _rateFmt = NumberFormat('#,##0.####');
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _fPair.dispose();
    _fRate.dispose();
    _fSince.dispose();
    _fExpires.dispose();
    _fStatus.dispose();
    super.dispose();
  }

  void _openForm([ExchangeRateModel? item]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ExchangeRateForm(
        initialData: item,
        initialBaseCurrencyId: item == null
            ? widget.initialBaseCurrencyId
            : null,
        initialTargetCurrencyId: item == null
            ? widget.initialTargetCurrencyId
            : null,
        onSubmit: (data) async {
          if (item == null) {
            await ref.read(exchangeRateProvider.notifier).create(data);
          } else {
            await ref
                .read(exchangeRateProvider.notifier)
                .updateExchangeRate(item.id, data);
          }
          _searchController.clear();
          setState(() => _searchQuery = '');
        },
      ),
    );
  }

  Future<void> _deleteItem(
    ExchangeRateModel item,
    Map<String, CurrencyModel> currencyMap,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteRateDialog(pair: _pairLabel(item, currencyMap)),
    );
    if (confirmed != true) return;
    try {
      await ref.read(exchangeRateProvider.notifier).delete(item.id);
      if (mounted && _selectedId == item.id) {
        setState(() => _selectedId = null);
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Tipo de cambio eliminado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  // ===== helpers de datos =====
  CurrencyModel? _base(ExchangeRateModel r, Map<String, CurrencyModel> map) =>
      r.monedaBase ?? map[r.monedaIdBase];
  CurrencyModel? _target(ExchangeRateModel r, Map<String, CurrencyModel> map) =>
      r.monedaTarget ?? map[r.monedaIdTarget];

  String _pairLabel(ExchangeRateModel r, Map<String, CurrencyModel> map) {
    final b = _base(r, map)?.code ?? registroShortId(r.monedaIdBase);
    final t = _target(r, map)?.code ?? registroShortId(r.monedaIdTarget);
    return '$b → $t';
  }

  bool _isExpired(ExchangeRateModel r) =>
      r.fechaExpiracion != null && r.fechaExpiracion!.isBefore(DateTime.now());

  String _statusOf(ExchangeRateModel r) {
    if (!r.activo) return 'Inactivo';
    if (_isExpired(r)) return 'Vencido';
    return 'Activo';
  }

  bool _matchesSearch(ExchangeRateModel r, Map<String, CurrencyModel> map) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery;
    final b = _base(r, map);
    final t = _target(r, map);
    final haystack = [
      b?.name,
      b?.code,
      t?.name,
      t?.code,
      r.exchangeRate.toString(),
      _statusOf(r),
    ].whereType<String>().join(' ').toLowerCase();
    return haystack.contains(q);
  }

  bool _matchesFilter(ExchangeRateModel r) {
    switch (_filter) {
      case _RateFilter.active:
        return _statusOf(r) == 'Activo';
      case _RateFilter.expired:
        return _statusOf(r) == 'Vencido';
      case _RateFilter.all:
        return true;
    }
  }

  bool _matchesColumnFilters(
    ExchangeRateModel r,
    Map<String, CurrencyModel> map,
  ) {
    bool has(TextEditingController t, String value) {
      final f = t.text.trim().toLowerCase();
      return f.isEmpty || value.toLowerCase().contains(f);
    }

    return has(_fPair, _pairLabel(r, map)) &&
        has(_fRate, _rateFmt.format(r.exchangeRate)) &&
        has(_fSince, _dateFmt.format(r.fechaInicio)) &&
        has(
          _fExpires,
          r.fechaExpiracion == null ? '—' : _dateFmt.format(r.fechaExpiracion!),
        ) &&
        has(_fStatus, _statusOf(r));
  }

  int _compare(
    ExchangeRateModel a,
    ExchangeRateModel b,
    Map<String, CurrencyModel> m,
  ) {
    int r;
    switch (_sortKey) {
      case _RateSortKey.pair:
        r = _pairLabel(a, m).compareTo(_pairLabel(b, m));
      case _RateSortKey.rate:
        r = a.exchangeRate.compareTo(b.exchangeRate);
      case _RateSortKey.since:
        r = a.fechaInicio.compareTo(b.fechaInicio);
      case _RateSortKey.expires:
        if (a.fechaExpiracion == null && b.fechaExpiracion == null) {
          r = 0;
        } else if (a.fechaExpiracion == null) {
          r = 1;
        } else if (b.fechaExpiracion == null) {
          r = -1;
        } else {
          r = a.fechaExpiracion!.compareTo(b.fechaExpiracion!);
        }
      case _RateSortKey.status:
        r = _statusOf(a).compareTo(_statusOf(b));
    }
    return _sortAsc ? r : -r;
  }

  void _onSort(_RateSortKey key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sortKey = key;
        _sortAsc = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNight = Theme.of(context).brightness == Brightness.dark;
    final p = RegistroPalette.of(isNight);
    final ratesAsync = ref.watch(exchangeRateProvider);
    final currenciesAsync = ref.watch(currencyProvider);

    final currencyMap = <String, CurrencyModel>{
      for (final c in currenciesAsync.value ?? const <CurrencyModel>[]) c.id: c,
    };

    // Catálogo base (respeta activeOnly, como la vista anterior).
    final allRates = ratesAsync.value ?? const <ExchangeRateModel>[];
    final baseItems = allRates
        .where((r) => !widget.activeOnly || r.activo)
        .toList();

    // Datos de la oración-resumen.
    final activeItems = baseItems
        .where((r) => _statusOf(r) == 'Activo')
        .toList();
    final expiredCount = baseItems
        .where((r) => _statusOf(r) == 'Vencido')
        .length;
    final currencyIds = <String>{};
    for (final r in activeItems) {
      currencyIds.add(r.monedaIdBase);
      currencyIds.add(r.monedaIdTarget);
    }
    DateTime? latest;
    for (final r in activeItems) {
      if (latest == null || r.fechaInicio.isAfter(latest)) {
        latest = r.fechaInicio;
      }
    }

    // Nº de asiento fijo según el catálogo.
    final indexById = <String, int>{
      for (var i = 0; i < baseItems.length; i++) baseItems[i].id: i + 1,
    };

    // Selección efectiva (fallback: primer asiento).
    ExchangeRateModel? selected;
    if (baseItems.isNotEmpty) {
      selected = baseItems.firstWhere(
        (r) => r.id == _selectedId,
        orElse: () => baseItems.first,
      );
    }

    return Scaffold(
      backgroundColor: p.paper,
      body: SafeArea(
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
                _searchFocus.requestFocus(),
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
                _searchFocus.requestFocus(),
          },
          child: Focus(
            autofocus: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(44, 30, 44, 72),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RegistroMasthead(
                    p: p,
                    department: 'FINANZAS',
                    code: 'F-05 / TIPOS DE CAMBIO · REV. 2026',
                  ),
                  const SizedBox(height: 26),
                  _buildTitleRow(p),
                  const SizedBox(height: 18),
                  _buildLedgerLine(
                    p,
                    ratesAsync,
                    activeItems.length,
                    currencyIds.length,
                    expiredCount,
                    latest,
                  ),
                  const SizedBox(height: 26),
                  _buildCommand(p, baseItems),
                  const SizedBox(height: 30),
                  _buildSheet(
                    p,
                    ratesAsync,
                    baseItems,
                    currencyMap,
                    indexById,
                    selected,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleRow(RegistroPalette p) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: 'PIZARRA\nCAMBIARIA',
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
              letterSpacing: -1.0,
              color: p.ink,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Wrap(
          spacing: 26,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            RegistroTextAction(
              p: p,
              label: '↻ ACTUALIZAR',
              onTap: () {
                ref.read(exchangeRateProvider.notifier).refresh();
                ref.read(currencyProvider.notifier).refresh();
              },
            ),
            RegistroTextAction(
              p: p,
              label: '＋ NUEVO CAMBIO',
              prime: true,
              onTap: () => _openForm(),
            ),
            if (Navigator.of(context).canPop())
              RegistroTextAction(
                p: p,
                label: '✕ CERRAR',
                onTap: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLedgerLine(
    RegistroPalette p,
    AsyncValue<List<ExchangeRateModel>> rates,
    int active,
    int currencies,
    int expired,
    DateTime? latest,
  ) {
    final base = GoogleFonts.archivo(
      fontSize: 19,
      height: 1.55,
      color: p.ink2,
      fontWeight: FontWeight.w400,
    );
    TextStyle big(Color c) => GoogleFonts.archivo(
      fontSize: 25,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: c,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final Widget sentence;
    if (rates.isLoading && active == 0 && expired == 0) {
      sentence = Text(
        'Componiendo la pizarra…',
        style: base.copyWith(fontStyle: FontStyle.italic),
      );
    } else if (rates.hasError) {
      sentence = Text(
        'No fue posible leer la pizarra.',
        style: base.copyWith(color: p.verm),
      );
    } else if (active == 0 && expired == 0) {
      sentence = Text('Aún no rige ningún tipo de cambio.', style: base);
    } else {
      sentence = Text.rich(
        TextSpan(
          style: base,
          children: [
            TextSpan(text: active == 1 ? 'Rige ' : 'Rigen '),
            TextSpan(text: '$active', style: big(p.verm)),
            TextSpan(
              text: active == 1
                  ? ' tipo de cambio activo sobre '
                  : ' tipos de cambio activos sobre ',
            ),
            TextSpan(text: '$currencies', style: big(p.ink)),
            TextSpan(text: currencies == 1 ? ' divisa' : ' divisas'),
            if (latest != null) ...[
              const TextSpan(text: '; el más reciente rige desde el '),
              TextSpan(text: _dateFmt.format(latest), style: big(p.ink)),
            ],
            if (expired > 0) ...[
              const TextSpan(text: '. Han vencido '),
              TextSpan(text: '$expired', style: big(p.ink)),
              TextSpan(text: expired == 1 ? ' tasa.' : ' tasas.'),
            ] else
              const TextSpan(text: '.'),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: p.rule),
          bottom: BorderSide(color: p.rule),
        ),
      ),
      child: sentence,
    );
  }

  Widget _buildCommand(RegistroPalette p, List<ExchangeRateModel> items) {
    final allCount = items.length;
    final activeCount = items.where((r) => _statusOf(r) == 'Activo').length;
    final expiredCount = items.where((r) => _statusOf(r) == 'Vencido').length;

    final search = _buildSearch(p);
    final tabs = <Widget>[
      if (!widget.activeOnly) ...[
        RegistroTab(
          p: p,
          label: 'TODOS',
          count: allCount,
          active: _filter == _RateFilter.all,
          onTap: () => setState(() => _filter = _RateFilter.all),
        ),
        RegistroTab(
          p: p,
          label: 'ACTIVOS',
          count: activeCount,
          active: _filter == _RateFilter.active,
          onTap: () => setState(() => _filter = _RateFilter.active),
        ),
        RegistroTab(
          p: p,
          label: 'VENCIDOS',
          count: expiredCount,
          active: _filter == _RateFilter.expired,
          onTap: () => setState(() => _filter = _RateFilter.expired),
        ),
      ],
      RegistroTab(
        p: p,
        label: 'FILTROS ¶',
        count: null,
        active: _filtersVisible,
        onTap: () => setState(() => _filtersVisible = !_filtersVisible),
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 860) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: search),
              const SizedBox(width: 34),
              for (int i = 0; i < tabs.length; i++) ...[
                tabs[i],
                if (i < tabs.length - 1) const SizedBox(width: 22),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            search,
            const SizedBox(height: 16),
            Wrap(spacing: 22, runSpacing: 10, children: tabs),
          ],
        );
      },
    );
  }

  Widget _buildSearch(RegistroPalette p) {
    final focused = _searchFocus.hasFocus;
    return Container(
      padding: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: focused ? p.verm : p.ruleStrong,
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'BUSCAR',
            style: GoogleFonts.archivo(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: focused ? p.verm : p.ink3,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: (v) =>
                  setState(() => _searchQuery = v.trim().toLowerCase()),
              style: GoogleFonts.archivo(fontSize: 16, color: p.ink),
              cursorColor: p.verm,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'par, código, tasa o estado…',
                hintStyle: GoogleFonts.archivo(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: p.ink4,
                ),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: Text('✕', style: TextStyle(fontSize: 12, color: p.ink3)),
              ),
            )
          else
            Text(
              'CTRL K',
              style: GoogleFonts.fragmentMono(fontSize: 10, color: p.ink4),
            ),
        ],
      ),
    );
  }

  Widget _buildSheet(
    RegistroPalette p,
    AsyncValue<List<ExchangeRateModel>> ratesAsync,
    List<ExchangeRateModel> baseItems,
    Map<String, CurrencyModel> currencyMap,
    Map<String, int> indexById,
    ExchangeRateModel? selected,
  ) {
    final table = _buildTable(
      p,
      ratesAsync,
      baseItems,
      currencyMap,
      selected?.id,
    );
    final marginalia = _RateMarginalia(
      p: p,
      rate: selected,
      currencyMap: currencyMap,
      index: selected == null ? 0 : (indexById[selected.id] ?? 0),
      statusLabel: selected == null ? '' : _statusOf(selected),
      onEdit: selected == null ? null : () => _openForm(selected),
      onDelete: selected == null
          ? null
          : () => _deleteItem(selected, currencyMap),
      onCurrencies: () => ref.read(dashboardNavProvider.notifier).setIndex(21),
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 1000) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: table),
              const SizedBox(width: 44),
              SizedBox(width: 272, child: marginalia),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [table, const SizedBox(height: 30), marginalia],
        );
      },
    );
  }

  Widget _buildTable(
    RegistroPalette p,
    AsyncValue<List<ExchangeRateModel>> ratesAsync,
    List<ExchangeRateModel> baseItems,
    Map<String, CurrencyModel> currencyMap,
    String? selectedId,
  ) {
    if (ratesAsync.isLoading && baseItems.isEmpty) {
      return RegistroLoadingBlock(p: p);
    }
    if (ratesAsync.hasError && baseItems.isEmpty) {
      return RegistroErrorBlock(p: p, message: '${ratesAsync.error}');
    }

    final visible =
        baseItems
            .where(
              (r) =>
                  _matchesSearch(r, currencyMap) &&
                  _matchesFilter(r) &&
                  _matchesColumnFilters(r, currencyMap),
            )
            .toList()
          ..sort((a, b) => _compare(a, b, currencyMap));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderRow(p),
        if (_filtersVisible) _buildFilterRow(p),
        if (visible.isEmpty)
          RegistroEmptyBlock(
            p: p,
            message: baseItems.isEmpty
                ? 'La pizarra está vacía. Asienta el primer tipo de cambio.'
                : 'Ningún tipo de cambio coincide. Ajusta la búsqueda o los filtros.',
          )
        else
          _ScrollableRateRows(
            p: p,
            items: visible,
            currencyMap: currencyMap,
            indexById: {
              for (var i = 0; i < baseItems.length; i++) baseItems[i].id: i + 1,
            },
            selectedId: selectedId,
            statusOf: _statusOf,
            pairLabel: (r) => _pairLabel(r, currencyMap),
            rateFmt: _rateFmt,
            dateFmt: _dateFmt,
            onSelect: (id) => setState(() => _selectedId = id),
            onEdit: _openForm,
            onDelete: (r) => _deleteItem(r, currencyMap),
          ),
        _buildColophon(p, visible.length, baseItems.length),
      ],
    );
  }

  Widget _buildHeaderRow(RegistroPalette p) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.ruleStrong, width: 2)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 3),
          SizedBox(
            width: 34,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text('Nº', style: registroThStyle(p)),
            ),
          ),
          Expanded(
            flex: 4,
            child: RegistroSortHead(
              p: p,
              label: 'PAR',
              active: _sortKey == _RateSortKey.pair,
              asc: _sortAsc,
              onTap: () => _onSort(_RateSortKey.pair),
            ),
          ),
          Expanded(
            flex: 2,
            child: RegistroSortHead(
              p: p,
              label: 'TASA',
              active: _sortKey == _RateSortKey.rate,
              asc: _sortAsc,
              alignRight: true,
              onTap: () => _onSort(_RateSortKey.rate),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: RegistroSortHead(
                p: p,
                label: 'DESDE',
                active: _sortKey == _RateSortKey.since,
                asc: _sortAsc,
                onTap: () => _onSort(_RateSortKey.since),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: RegistroSortHead(
              p: p,
              label: 'EXPIRA',
              active: _sortKey == _RateSortKey.expires,
              asc: _sortAsc,
              onTap: () => _onSort(_RateSortKey.expires),
            ),
          ),
          Expanded(
            flex: 2,
            child: RegistroSortHead(
              p: p,
              label: 'ESTADO',
              active: _sortKey == _RateSortKey.status,
              asc: _sortAsc,
              onTap: () => _onSort(_RateSortKey.status),
            ),
          ),
          const SizedBox(width: 150),
        ],
      ),
    );
  }

  Widget _buildFilterRow(RegistroPalette p) {
    Widget input(
      TextEditingController t,
      String hint, {
      bool alignRight = false,
    }) {
      return TextField(
        controller: t,
        onChanged: (_) => setState(() {}),
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: GoogleFonts.fragmentMono(fontSize: 11, color: p.ink),
        cursorColor: p.verm,
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: GoogleFonts.fragmentMono(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: p.ink4,
          ),
          contentPadding: const EdgeInsets.only(bottom: 3),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: p.ink4, width: 1),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: p.verm, width: 1),
          ),
        ),
      );
    }

    Widget cell(int flex, Widget child, {double left = 0, double right = 12}) {
      return Expanded(
        flex: flex,
        child: Padding(
          padding: EdgeInsets.only(left: left, right: right),
          child: child,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.rule)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 3),
          const SizedBox(width: 34),
          cell(4, input(_fPair, 'filtrar par…')),
          cell(2, input(_fRate, 'tasa…', alignRight: true)),
          cell(2, input(_fSince, 'aaaa-mm-dd…'), left: 16),
          cell(2, input(_fExpires, 'aaaa-mm-dd…')),
          cell(2, input(_fStatus, 'estado…')),
          const SizedBox(width: 150),
        ],
      ),
    );
  }

  Widget _buildColophon(RegistroPalette p, int shown, int total) {
    final names = {
      _RateSortKey.pair: 'par',
      _RateSortKey.rate: 'tasa',
      _RateSortKey.since: 'desde',
      _RateSortKey.expires: 'expira',
      _RateSortKey.status: 'estado',
    };
    final mono = GoogleFonts.fragmentMono(fontSize: 10.5, color: p.ink3);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.ruleStrong, width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$shown de $total asientos', style: mono),
          Text(
            '† vencido por fecha',
            style: mono.copyWith(fontStyle: FontStyle.italic),
          ),
          Text(
            'orden: ${names[_sortKey]} ${_sortAsc ? '↑' : '↓'}',
            style: mono,
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// Filas con scroll acotado
// =========================================================================
class _ScrollableRateRows extends StatefulWidget {
  const _ScrollableRateRows({
    required this.p,
    required this.items,
    required this.currencyMap,
    required this.indexById,
    required this.selectedId,
    required this.statusOf,
    required this.pairLabel,
    required this.rateFmt,
    required this.dateFmt,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final RegistroPalette p;
  final List<ExchangeRateModel> items;
  final Map<String, CurrencyModel> currencyMap;
  final Map<String, int> indexById;
  final String? selectedId;
  final String Function(ExchangeRateModel) statusOf;
  final String Function(ExchangeRateModel) pairLabel;
  final NumberFormat rateFmt;
  final DateFormat dateFmt;
  final ValueChanged<String> onSelect;
  final void Function(ExchangeRateModel) onEdit;
  final void Function(ExchangeRateModel) onDelete;

  @override
  State<_ScrollableRateRows> createState() => _ScrollableRateRowsState();
}

class _ScrollableRateRowsState extends State<_ScrollableRateRows> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    // Se auto-ajusta al alto de pantalla (norma de tablas, ver DESIGN_SYSTEM).
    final maxHeight =
        (MediaQuery.sizeOf(context).height * 0.56).clamp(280.0, 680.0);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: ListView.separated(
          controller: _controller,
          primary: false,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: items.length,
          separatorBuilder: (_, _) =>
              Divider(height: 1, thickness: 1, color: widget.p.rule),
          itemBuilder: (context, i) => _RateRow(
            p: widget.p,
            item: items[i],
            currencyMap: widget.currencyMap,
            index: widget.indexById[items[i].id] ?? (i + 1),
            pair: widget.pairLabel(items[i]),
            status: widget.statusOf(items[i]),
            rateFmt: widget.rateFmt,
            dateFmt: widget.dateFmt,
            selected: widget.selectedId == items[i].id,
            onSelect: () => widget.onSelect(items[i].id),
            onEdit: () => widget.onEdit(items[i]),
            onDelete: () => widget.onDelete(items[i]),
          ),
        ),
      ),
    );
  }
}

class _RateRow extends StatefulWidget {
  const _RateRow({
    required this.p,
    required this.item,
    required this.currencyMap,
    required this.index,
    required this.pair,
    required this.status,
    required this.rateFmt,
    required this.dateFmt,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final RegistroPalette p;
  final ExchangeRateModel item;
  final Map<String, CurrencyModel> currencyMap;
  final int index;
  final String pair;
  final String status;
  final NumberFormat rateFmt;
  final DateFormat dateFmt;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_RateRow> createState() => _RateRowState();
}

class _RateRowState extends State<_RateRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final sel = widget.selected;
    final bg = sel ? p.vermSoft : (_hover ? p.paper2 : Colors.transparent);
    final showActions = _hover || sel;
    final item = widget.item;
    final base = item.monedaBase ?? widget.currencyMap[item.monedaIdBase];
    final target = item.monedaTarget ?? widget.currencyMap[item.monedaIdTarget];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              left: BorderSide(
                color: sel ? p.verm : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  widget.index.toString().padLeft(2, '0'),
                  style: GoogleFonts.fragmentMono(
                    fontSize: 11,
                    color: sel ? p.verm : p.ink4,
                  ),
                ),
              ),
              // Par: banderas + códigos
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    AppFlag(
                      base64String: base?.flagImage,
                      fallbackCode: base?.code ?? '?',
                      width: 30,
                      height: 20,
                      borderRadius: 0,
                    ),
                    const SizedBox(width: 5),
                    AppFlag(
                      base64String: target?.flagImage,
                      fallbackCode: target?.code ?? '?',
                      width: 30,
                      height: 20,
                      borderRadius: 0,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: base?.code ?? '—'),
                            TextSpan(
                              text: ' → ',
                              style: TextStyle(color: p.verm),
                            ),
                            TextSpan(text: target?.code ?? '—'),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.fragmentMono(
                          fontSize: 13,
                          color: p.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Tasa
              Expanded(
                flex: 2,
                child: Text(
                  widget.rateFmt.format(item.exchangeRate),
                  textAlign: TextAlign.right,
                  style: GoogleFonts.fragmentMono(fontSize: 13, color: p.ink),
                ),
              ),
              // Desde
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    widget.dateFmt.format(item.fechaInicio),
                    style: GoogleFonts.fragmentMono(
                      fontSize: 12,
                      color: p.ink2,
                    ),
                  ),
                ),
              ),
              // Expira
              Expanded(
                flex: 2,
                child: Text(
                  item.fechaExpiracion == null
                      ? '—'
                      : widget.dateFmt.format(item.fechaExpiracion!),
                  style: GoogleFonts.fragmentMono(fontSize: 12, color: p.ink2),
                ),
              ),
              // Estado
              Expanded(
                flex: 2,
                child: _RateStatusText(p: p, status: widget.status),
              ),
              // Acciones — FittedBox: si el ancho reservado no alcanza,
              // el par EDITAR/ELIMINAR se encoge en vez de desbordar.
              SizedBox(
                width: 150,
                child: showActions
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RegistroRowTextAction(
                              p: p,
                              label: 'EDITAR',
                              onTap: widget.onEdit,
                            ),
                            const SizedBox(width: 16),
                            RegistroRowTextAction(
                              p: p,
                              label: 'ELIMINAR',
                              danger: true,
                              onTap: widget.onDelete,
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RateStatusText extends StatelessWidget {
  const _RateStatusText({required this.p, required this.status});
  final RegistroPalette p;
  final String status;

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.archivo(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    );
    if (status == 'Vencido') {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'VENCIDO',
              style: base.copyWith(color: p.ink3),
            ),
            TextSpan(
              text: ' †',
              style: base.copyWith(color: p.verm),
            ),
          ],
        ),
      );
    }
    final color = status == 'Activo' ? p.ink : p.ink3;
    return Text(status.toUpperCase(), style: base.copyWith(color: color));
  }
}

// =========================================================================
// Marginalia — detalle del tipo de cambio seleccionado
// =========================================================================
class _RateMarginalia extends StatelessWidget {
  const _RateMarginalia({
    required this.p,
    required this.rate,
    required this.currencyMap,
    required this.index,
    required this.statusLabel,
    required this.onEdit,
    required this.onDelete,
    required this.onCurrencies,
  });

  final RegistroPalette p;
  final ExchangeRateModel? rate;
  final Map<String, CurrencyModel> currencyMap;
  final int index;
  final String statusLabel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback onCurrencies;

  static final _rateFmt = NumberFormat('#,##0.####');
  static final _invFmt = NumberFormat('#,##0.######');
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context) {
    final r = rate;
    final nn = index.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.ruleStrong, width: 2)),
      ),
      child: r == null
          ? Text(
              'SIN SELECCIÓN',
              style: GoogleFonts.archivo(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.2,
                color: p.ink3,
              ),
            )
          : _buildDetail(context, r, nn),
    );
  }

  Widget _buildDetail(BuildContext context, ExchangeRateModel r, String nn) {
    final base = r.monedaBase ?? currencyMap[r.monedaIdBase];
    final target = r.monedaTarget ?? currencyMap[r.monedaIdTarget];
    final baseCode = base?.code ?? '—';
    final targetCode = target?.code ?? '—';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Column(
        key: ValueKey(r.id),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ASIENTO Nº $nn',
            style: GoogleFonts.archivo(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
              color: p.ink3,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _rateFmt.format(r.exchangeRate),
              maxLines: 1,
              style: GoogleFonts.archivoBlack(
                fontSize: 84,
                height: 0.95,
                letterSpacing: -2.5,
                color: p.verm,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$baseCode → $targetCode',
            style: GoogleFonts.archivo(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.05,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${statusLabel.toUpperCase()} · DESDE ${_dateFmt.format(r.fechaInicio)}',
            style: GoogleFonts.fragmentMono(fontSize: 11, color: p.ink3),
          ),
          const SizedBox(height: 20),
          RegistroKvLeader(
            p: p,
            k: 'BASE',
            v: '$baseCode · ${base?.symbol ?? '—'}',
            mono: true,
          ),
          RegistroKvLeader(
            p: p,
            k: 'DESTINO',
            v: '$targetCode · ${target?.symbol ?? '—'}',
            mono: true,
          ),
          RegistroKvLeader(
            p: p,
            k: 'TASA',
            v: _rateFmt.format(r.exchangeRate),
            mono: true,
          ),
          RegistroKvLeader(
            p: p,
            k: 'INVERSA',
            v: r.exchangeRate == 0 ? '—' : _invFmt.format(1 / r.exchangeRate),
            mono: true,
          ),
          RegistroKvLeader(
            p: p,
            k: 'EXPIRA',
            v: r.fechaExpiracion == null
                ? '—'
                : _dateFmt.format(r.fechaExpiracion!),
            mono: true,
          ),
          RegistroKvLeader(p: p, k: 'ID', v: registroShortId(r.id), mono: true),
          const SizedBox(height: 18),
          Row(
            children: [
              AppFlag(
                base64String: base?.flagImage,
                fallbackCode: baseCode,
                width: 54,
                height: 36,
                borderRadius: 0,
              ),
              const SizedBox(width: 6),
              AppFlag(
                base64String: target?.flagImage,
                fallbackCode: targetCode,
                width: 54,
                height: 36,
                borderRadius: 0,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'fig. $nn — par de divisas',
                  style: GoogleFonts.fragmentMono(
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                    color: p.ink3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Divider(height: 1, thickness: 1, color: p.rule),
          const SizedBox(height: 12),
          RegistroMarginAction(
            p: p,
            label: 'EDITAR TASA',
            onTap: onEdit ?? () {},
          ),
          const SizedBox(height: 9),
          RegistroMarginAction(
            p: p,
            label: 'ELIMINAR TASA',
            onTap: onDelete ?? () {},
          ),
          const SizedBox(height: 9),
          RegistroMarginAction(p: p, label: 'VER MONEDAS', onTap: onCurrencies),
        ],
      ),
    );
  }
}

// =========================================================================
// Diálogo de eliminación — estilo impreso
// =========================================================================
class _DeleteRateDialog extends StatelessWidget {
  const _DeleteRateDialog({required this.pair});
  final String pair;

  @override
  Widget build(BuildContext context) {
    final isNight = Theme.of(context).brightness == Brightness.dark;
    final p = RegistroPalette.of(isNight);
    return AlertDialog(
      backgroundColor: p.paper,
      shape: Border(top: BorderSide(color: p.verm, width: 3)),
      title: Text(
        'ELIMINAR ASIENTO',
        style: GoogleFonts.archivo(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
          color: p.ink,
        ),
      ),
      content: Text(
        '¿Eliminar el tipo de cambio $pair de la pizarra? '
        'Esta acción no se puede deshacer.',
        style: GoogleFonts.archivo(fontSize: 14, color: p.ink2),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'CANCELAR',
            style: GoogleFonts.archivo(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
              color: p.ink2,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: p.verm,
            shape: const RoundedRectangleBorder(),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'ELIMINAR',
            style: GoogleFonts.archivo(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
