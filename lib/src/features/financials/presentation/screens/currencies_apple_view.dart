import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/registro_palette.dart';
import '../../../../core/widgets/app_flag.dart';
import '../../../../core/widgets/registro_widgets.dart';
import '../../../dashboard/presentation/state/dashboard_nav_provider.dart';
import '../../data/models/currency_model.dart';
import '../../data/models/exchange_rate_model.dart';
import '../providers/exchange_rate_notifier.dart';
import '../state/currency_notifier.dart';
import '../widgets/currency_apple_form.dart';

/// Vista de Monedas — "REGISTRO" (índice 21 del dashboard).
///
/// Diseño tipográfico estilo impreso suizo: papel y tinta, un solo color
/// (vermellón), filetes de pelo, versalitas, numerales tabulares y puntos
/// conductores. Réplica fiel de docs/moneda_v4_registro.html.
///
/// Funcional completo: oración-resumen con datos reales, búsqueda (Ctrl+K),
/// pestañas de filtro, orden por columna, filtros por columna, selección →
/// nota marginal, editar/eliminar/crear, exportar CSV al portapapeles y
/// tema día/noche siguiendo el brightness global de la app.
class CurrenciesAppleView extends ConsumerStatefulWidget {
  const CurrenciesAppleView({super.key});

  @override
  ConsumerState<CurrenciesAppleView> createState() =>
      _CurrenciesAppleViewState();
}

enum _CurrencyFilter { all, withFlag, withoutFlag }

enum _SortKey { name, code, symbol, rates, status }

class _CurrenciesAppleViewState extends ConsumerState<CurrenciesAppleView> {
  static const double _rowActionsWidth = 124;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _fName = TextEditingController();
  final TextEditingController _fCode = TextEditingController();
  final TextEditingController _fSym = TextEditingController();
  final TextEditingController _fRates = TextEditingController();
  final TextEditingController _fStatus = TextEditingController();

  String _searchQuery = '';
  _CurrencyFilter _filter = _CurrencyFilter.all;
  bool _filtersVisible = false;
  _SortKey _sortKey = _SortKey.name;
  bool _sortAsc = true;
  bool _hasTriedSeeding = false;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    // El subrayado de la búsqueda cambia a vermellón al enfocar.
    _searchFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _fName.dispose();
    _fCode.dispose();
    _fSym.dispose();
    _fRates.dispose();
    _fStatus.dispose();
    super.dispose();
  }

  Future<void> _openForm([CurrencyModel? currency]) async {
    var saved = false;
    final isEdit = currency != null;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withValues(alpha: 0.42),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, anim1, anim2) {
        return CurrencyAppleForm(
          id: currency?.id,
          initialName: currency?.name,
          initialCode: currency?.code,
          initialSymbol: currency?.symbol,
          initialFlagImage: currency?.flagImage,
          onSubmit: (name, code, symbol, flagBytes) async {
            if (currency == null) {
              await ref
                  .read(currencyProvider.notifier)
                  .createCurrency(name, code, symbol, flagBytes);
            } else {
              await ref
                  .read(currencyProvider.notifier)
                  .updateCurrency(currency.id, name, code, symbol, flagBytes);
            }
            saved = true;
            _searchController.clear();
            if (mounted) {
              setState(() => _searchQuery = '');
            }
          },
        );
      },
    );

    if (!mounted || !saved) {
      return;
    }

    final p = RegistroPalette.fromContext(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        width: 390,
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink,
        shape: const RoundedRectangleBorder(),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Container(width: 3, height: 30, color: p.verm),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isEdit
                    ? 'ASIENTO ACTUALIZADO · ${currency.code.toUpperCase()}'
                    : 'NUEVA DIVISA ASENTADA',
                style: GoogleFonts.archivo(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: p.paper,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(CurrencyModel currency) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteCurrencyDialog(currency: currency),
    );
    if (confirmed != true) return;
    try {
      await ref.read(currencyProvider.notifier).deleteCurrency(currency.id);
      if (mounted && _selectedId == currency.id) {
        setState(() => _selectedId = null);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Moneda "${currency.name}" eliminada.'),
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

  Future<void> _seed() async {
    await ref.read(currencyProvider.notifier).seedWorldCurrencies();
  }

  void _exportCsv(List<CurrencyModel> list, Map<String, int> rateCount) {
    final sb = StringBuffer('nombre,codigo,simbolo,cambios\n');
    for (final c in list) {
      sb.writeln(
        '"${c.name}",${c.code},"${c.symbol ?? ''}",${rateCount[c.id] ?? 0}',
      );
    }
    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Catálogo copiado al portapapeles como CSV.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _matchesSearch(CurrencyModel c) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery;
    return c.name.toLowerCase().contains(q) ||
        c.code.toLowerCase().contains(q) ||
        (c.symbol ?? '').toLowerCase().contains(q);
  }

  bool _matchesFilter(CurrencyModel c) {
    switch (_filter) {
      case _CurrencyFilter.withFlag:
        return c.flagImage != null && c.flagImage!.isNotEmpty;
      case _CurrencyFilter.withoutFlag:
        return c.flagImage == null || c.flagImage!.isEmpty;
      case _CurrencyFilter.all:
        return true;
    }
  }

  bool _matchesColumnFilters(CurrencyModel c, int rateCount) {
    bool has(TextEditingController t, String value) {
      final f = t.text.trim().toLowerCase();
      return f.isEmpty || value.toLowerCase().contains(f);
    }

    return has(_fName, c.name) &&
        has(_fCode, c.code) &&
        has(_fSym, c.symbol ?? '') &&
        has(_fRates, '$rateCount') &&
        has(_fStatus, _statusOf(c, rateCount));
  }

  int _compare(CurrencyModel a, CurrencyModel b, Map<String, int> rates) {
    int r;
    switch (_sortKey) {
      case _SortKey.name:
        r = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case _SortKey.code:
        r = a.code.toLowerCase().compareTo(b.code.toLowerCase());
      case _SortKey.symbol:
        r = (a.symbol ?? '').compareTo(b.symbol ?? '');
      case _SortKey.rates:
        r = (rates[a.id] ?? 0).compareTo(rates[b.id] ?? 0);
      case _SortKey.status:
        r = _statusOf(
          a,
          rates[a.id] ?? 0,
        ).compareTo(_statusOf(b, rates[b.id] ?? 0));
    }
    return _sortAsc ? r : -r;
  }

  List<CurrencyModel> _visibleCurrencies(
    List<CurrencyModel> currencies,
    Map<String, int> rateCountByCurrency,
  ) {
    return currencies
        .where(
          (currency) =>
              _matchesSearch(currency) &&
              _matchesFilter(currency) &&
              _matchesColumnFilters(
                currency,
                rateCountByCurrency[currency.id] ?? 0,
              ),
        )
        .toList()
      ..sort((a, b) => _compare(a, b, rateCountByCurrency));
  }

  void _onSort(_SortKey key) {
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
    final currencies = ref.watch(currencyProvider);
    final rates = ref.watch(exchangeRateProvider);

    // Conteo de tipos de cambio vigentes (activo=true) por moneda.
    final rateCountByCurrency = <String, int>{};
    final allRates = rates.value ?? const <ExchangeRateModel>[];
    var activeRateCount = 0;
    for (final r in allRates) {
      if (!r.activo) continue;
      activeRateCount++;
      rateCountByCurrency[r.monedaIdBase] =
          (rateCountByCurrency[r.monedaIdBase] ?? 0) + 1;
      rateCountByCurrency[r.monedaIdTarget] =
          (rateCountByCurrency[r.monedaIdTarget] ?? 0) + 1;
    }

    final currencyList = currencies.value ?? const <CurrencyModel>[];
    final total = currencyList.length;
    final withFlagCount = currencyList
        .where((c) => c.flagImage != null && c.flagImage!.isNotEmpty)
        .length;
    final withoutFlagCount = total - withFlagCount;
    final visibleCurrencies = _visibleCurrencies(
      currencyList,
      rateCountByCurrency,
    );

    // Nº de asiento fijo según el orden del catálogo completo.
    final indexById = <String, int>{
      for (var i = 0; i < currencyList.length; i++) currencyList[i].id: i + 1,
    };

    // La selección efectiva sigue el orden y los filtros visibles.
    CurrencyModel? selectedCurrency;
    if (visibleCurrencies.isNotEmpty) {
      selectedCurrency = visibleCurrencies.firstWhere(
        (c) => c.id == _selectedId,
        orElse: () => visibleCurrencies.first,
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
                    code: 'F-03 / DIVISAS · REV. 2026',
                  ),
                  const SizedBox(height: 26),
                  _buildTitleRow(p, currencyList, rateCountByCurrency),
                  const SizedBox(height: 18),
                  _buildLedgerLine(
                    p,
                    currencies,
                    total,
                    activeRateCount,
                    withFlagCount,
                    withoutFlagCount,
                  ),
                  const SizedBox(height: 26),
                  _buildCommand(p, total, withFlagCount, withoutFlagCount),
                  const SizedBox(height: 30),
                  _buildSheet(
                    p,
                    currencies,
                    rateCountByCurrency,
                    indexById,
                    selectedCurrency,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===== título + acciones =====
  Widget _buildTitleRow(
    RegistroPalette p,
    List<CurrencyModel> list,
    Map<String, int> rateCount,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: 'REGISTRO\nDE DIVISAS',
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
                ref.invalidate(currencyProvider);
                ref.invalidate(exchangeRateProvider);
              },
            ),
            RegistroTextAction(
              p: p,
              label: '↓ EXPORTAR',
              onTap: () => _exportCsv(list, rateCount),
            ),
            RegistroTextAction(
              p: p,
              label: '＋ NUEVA MONEDA',
              prime: true,
              onTap: () => _openForm(),
            ),
          ],
        ),
      ],
    );
  }

  // ===== resumen como oración, sin tarjetas =====
  Widget _buildLedgerLine(
    RegistroPalette p,
    AsyncValue<List<CurrencyModel>> currencies,
    int total,
    int active,
    int withFlag,
    int withoutFlag,
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
    if (currencies.isLoading && total == 0) {
      sentence = Text(
        'Componiendo el registro…',
        style: base.copyWith(fontStyle: FontStyle.italic),
      );
    } else if (currencies.hasError && total == 0) {
      sentence = Text(
        'No fue posible leer el registro.',
        style: base.copyWith(color: p.verm),
      );
    } else {
      sentence = Text.rich(
        TextSpan(
          style: base,
          children: [
            const TextSpan(text: 'El registro contiene '),
            TextSpan(text: '$total', style: big(p.ink)),
            TextSpan(text: total == 1 ? ' divisa, con ' : ' divisas, con '),
            TextSpan(text: '$active', style: big(p.verm)),
            TextSpan(
              text: active == 1
                  ? ' tipo de cambio activo; '
                  : ' tipos de cambio activos; ',
            ),
            TextSpan(text: '$withFlag', style: big(p.ink)),
            TextSpan(
              text: withFlag == 1
                  ? ' tiene bandera asignada y '
                  : ' tienen bandera asignada y ',
            ),
            TextSpan(text: '$withoutFlag', style: big(p.ink)),
            TextSpan(
              text: withoutFlag == 1 ? ' aguarda imagen.' : ' aguardan imagen.',
            ),
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

  // ===== línea de mando: búsqueda + pestañas + filtros =====
  Widget _buildCommand(
    RegistroPalette p,
    int all,
    int withFlag,
    int withoutFlag,
  ) {
    final search = _buildSearch(p);
    final tabs = [
      RegistroTab(
        p: p,
        label: 'TODAS',
        count: all,
        active: _filter == _CurrencyFilter.all,
        onTap: () => setState(() => _filter = _CurrencyFilter.all),
      ),
      RegistroTab(
        p: p,
        label: 'ABANDERADAS',
        count: withFlag,
        active: _filter == _CurrencyFilter.withFlag,
        onTap: () => setState(() => _filter = _CurrencyFilter.withFlag),
      ),
      RegistroTab(
        p: p,
        label: 'SIN IMAGEN',
        count: withoutFlag,
        active: _filter == _CurrencyFilter.withoutFlag,
        onTap: () => setState(() => _filter = _CurrencyFilter.withoutFlag),
      ),
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
        crossAxisAlignment: CrossAxisAlignment.center,
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
                hintText: 'nombre, código o símbolo…',
                hintStyle: GoogleFonts.archivo(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: p.ink4,
                ),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            _InkText(
              text: '✕',
              color: p.ink3,
              hoverColor: p.verm,
              size: 12,
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
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

  // ===== pliego: tabla + marginalia =====
  Widget _buildSheet(
    RegistroPalette p,
    AsyncValue<List<CurrencyModel>> currencies,
    Map<String, int> rateCountByCurrency,
    Map<String, int> indexById,
    CurrencyModel? selectedCurrency,
  ) {
    final table = _buildTable(
      p,
      currencies,
      rateCountByCurrency,
      indexById,
      selectedCurrency?.id,
    );
    final marginalia = _Marginalia(
      p: p,
      currency: selectedCurrency,
      rateCount: selectedCurrency == null
          ? 0
          : (rateCountByCurrency[selectedCurrency.id] ?? 0),
      index: selectedCurrency == null
          ? 0
          : (indexById[selectedCurrency.id] ?? 0),
      onEdit: selectedCurrency == null
          ? null
          : () => _openForm(selectedCurrency),
      onRates: () => ref.read(dashboardNavProvider.notifier).setIndex(16),
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
    AsyncValue<List<CurrencyModel>> currencies,
    Map<String, int> rateCountByCurrency,
    Map<String, int> indexById,
    String? selectedId,
  ) {
    return currencies.when(
      data: (data) {
        if (data.isEmpty) {
          if (!_hasTriedSeeding) {
            _hasTriedSeeding = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _seed();
            });
          }
          return RegistroLoadingBlock(p: p);
        }
        final visible = _visibleCurrencies(data, rateCountByCurrency);
        final missingFlags = data
            .where((currency) => currency.flagImage?.isNotEmpty != true)
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderRow(p),
            if (_filtersVisible) _buildFilterRow(p),
            if (visible.isEmpty)
              RegistroEmptyBlock(
                p: p,
                message:
                    'Ninguna divisa coincide. Ajusta la búsqueda o los filtros.',
              )
            else
              _ScrollableRegistroRows(
                p: p,
                items: visible,
                rateCountByCurrency: rateCountByCurrency,
                indexById: indexById,
                selectedId: selectedId,
                onSelect: (id) => setState(() => _selectedId = id),
                onEdit: (currency) {
                  _openForm(currency);
                },
                onDelete: _confirmDelete,
              ),
            _buildColophon(p, visible.length, data.length, missingFlags),
          ],
        );
      },
      loading: () => RegistroLoadingBlock(p: p),
      error: (e, _) => RegistroErrorBlock(p: p, message: '$e'),
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
              label: 'DIVISA',
              active: _sortKey == _SortKey.name,
              asc: _sortAsc,
              onTap: () => _onSort(_SortKey.name),
            ),
          ),
          Expanded(
            flex: 2,
            child: RegistroSortHead(
              p: p,
              label: 'ISO',
              active: _sortKey == _SortKey.code,
              asc: _sortAsc,
              onTap: () => _onSort(_SortKey.code),
            ),
          ),
          Expanded(
            flex: 2,
            child: RegistroSortHead(
              p: p,
              label: 'SÍMBOLO',
              active: _sortKey == _SortKey.symbol,
              asc: _sortAsc,
              onTap: () => _onSort(_SortKey.symbol),
            ),
          ),
          Expanded(
            flex: 2,
            child: RegistroSortHead(
              p: p,
              label: 'CAMBIOS',
              active: _sortKey == _SortKey.rates,
              asc: _sortAsc,
              alignRight: true,
              onTap: () => _onSort(_SortKey.rates),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: RegistroSortHead(
                p: p,
                label: 'ESTADO',
                active: _sortKey == _SortKey.status,
                asc: _sortAsc,
                onTap: () => _onSort(_SortKey.status),
              ),
            ),
          ),
          const SizedBox(width: _rowActionsWidth),
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

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.rule)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 3),
          const SizedBox(width: 34),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: input(_fName, 'filtrar nombre…'),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: input(_fCode, 'iso…'),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: input(_fSym, 'símbolo…'),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: input(_fRates, 'nº…', alignRight: true),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 12),
              child: input(_fStatus, 'estado…'),
            ),
          ),
          const SizedBox(width: _rowActionsWidth),
        ],
      ),
    );
  }

  Widget _buildColophon(
    RegistroPalette p,
    int shown,
    int total,
    int missingFlags,
  ) {
    final names = {
      _SortKey.name: 'divisa',
      _SortKey.code: 'iso',
      _SortKey.symbol: 'símbolo',
      _SortKey.rates: 'cambios',
      _SortKey.status: 'estado',
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
            missingFlags == 0
                ? 'enseñas completas'
                : '† $missingFlags pendiente${missingFlags == 1 ? '' : 's'} de bandera',
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

// Paleta y componentes compartidos del sistema "Registro":
// core/theme/registro_palette.dart y core/widgets/registro_widgets.dart.

String _statusOf(CurrencyModel c, int rateCount) {
  final hasFlag = c.flagImage != null && c.flagImage!.isNotEmpty;
  if (!hasFlag) return 'Sin bandera';
  if (rateCount > 0) return 'En uso';
  return 'Disponible';
}

class _InkText extends StatefulWidget {
  const _InkText({
    required this.text,
    required this.color,
    required this.hoverColor,
    required this.size,
    required this.onTap,
  });
  final String text;
  final Color color;
  final Color hoverColor;
  final double size;
  final VoidCallback onTap;

  @override
  State<_InkText> createState() => _InkTextState();
}

class _InkTextState extends State<_InkText> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.text,
          style: TextStyle(
            fontSize: widget.size,
            color: _hover ? widget.hoverColor : widget.color,
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// Filas con altura acotada y scroll propio
// =========================================================================
class _ScrollableRegistroRows extends StatefulWidget {
  const _ScrollableRegistroRows({
    required this.p,
    required this.items,
    required this.rateCountByCurrency,
    required this.indexById,
    required this.selectedId,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final RegistroPalette p;
  final List<CurrencyModel> items;
  final Map<String, int> rateCountByCurrency;
  final Map<String, int> indexById;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final void Function(CurrencyModel) onEdit;
  final void Function(CurrencyModel) onDelete;

  @override
  State<_ScrollableRegistroRows> createState() =>
      _ScrollableRegistroRowsState();
}

class _ScrollableRegistroRowsState extends State<_ScrollableRegistroRows> {
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
          itemBuilder: (context, i) => _RegistroRow(
            p: widget.p,
            item: items[i],
            index: widget.indexById[items[i].id] ?? (i + 1),
            rateCount: widget.rateCountByCurrency[items[i].id] ?? 0,
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

class _RegistroRow extends StatefulWidget {
  const _RegistroRow({
    required this.p,
    required this.item,
    required this.index,
    required this.rateCount,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final RegistroPalette p;
  final CurrencyModel item;
  final int index;
  final int rateCount;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_RegistroRow> createState() => _RegistroRowState();
}

class _RegistroRowState extends State<_RegistroRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final sel = widget.selected;
    final bg = sel ? p.vermSoft : (_hover ? p.paper2 : Colors.transparent);
    final showActions = _hover || sel;
    final status = _statusOf(widget.item, widget.rateCount);

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
              // Divisa: bandera + nombre
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    AppFlag(
                      base64String: widget.item.flagImage,
                      fallbackCode: widget.item.code,
                      width: 33,
                      height: 22,
                      borderRadius: 0,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.archivo(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: p.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ISO
              Expanded(
                flex: 2,
                child: Text(
                  widget.item.code,
                  style: GoogleFonts.fragmentMono(fontSize: 12, color: p.ink2),
                ),
              ),
              // Símbolo
              Expanded(
                flex: 2,
                child: Text(
                  widget.item.symbol ?? '—',
                  style: GoogleFonts.fragmentMono(fontSize: 14, color: p.ink),
                ),
              ),
              // Cambios
              Expanded(
                flex: 2,
                child: Text(
                  widget.rateCount > 0 ? '${widget.rateCount}' : '—',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.fragmentMono(
                    fontSize: 12.5,
                    color: p.ink2,
                  ),
                ),
              ),
              // Estado
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _StatusText(p: p, status: status),
                ),
              ),
              // Acciones — FittedBox: si el ancho reservado no alcanza,
              // el par EDITAR/ELIMINAR se encoge en vez de desbordar.
              SizedBox(
                width: _CurrenciesAppleViewState._rowActionsWidth,
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

class _StatusText extends StatelessWidget {
  const _StatusText({required this.p, required this.status});
  final RegistroPalette p;
  final String status;

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.archivo(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    );
    if (status == 'Sin bandera') {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'SIN BANDERA',
                style: base.copyWith(color: p.ink3),
              ),
              TextSpan(
                text: ' †',
                style: base.copyWith(color: p.verm),
              ),
            ],
          ),
          maxLines: 1,
        ),
      );
    }
    final color = status == 'En uso' ? p.ink : p.ink3;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        status.toUpperCase(),
        maxLines: 1,
        softWrap: false,
        style: base.copyWith(color: color),
      ),
    );
  }
}

// =========================================================================
// Marginalia — detalle de la moneda seleccionada
// =========================================================================
class _Marginalia extends StatelessWidget {
  const _Marginalia({
    required this.p,
    required this.currency,
    required this.rateCount,
    required this.index,
    required this.onEdit,
    required this.onRates,
  });

  final RegistroPalette p;
  final CurrencyModel? currency;
  final int rateCount;
  final int index;
  final VoidCallback? onEdit;
  final VoidCallback onRates;

  @override
  Widget build(BuildContext context) {
    final c = currency;
    final nn = index.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.ruleStrong, width: 2)),
      ),
      child: c == null
          ? Text(
              'SIN SELECCIÓN',
              style: GoogleFonts.archivo(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.2,
                color: p.ink3,
              ),
            )
          : AnimatedSwitcher(
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
                key: ValueKey(c.id),
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
                      (c.symbol == null || c.symbol!.isEmpty) ? '¤' : c.symbol!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.archivoBlack(
                        fontSize: 104,
                        height: 0.95,
                        letterSpacing: -3,
                        color: p.verm,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.name.toUpperCase(),
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
                    '${c.code} · ${_statusOf(c, rateCount).toUpperCase()}',
                    style: GoogleFonts.fragmentMono(
                      fontSize: 11,
                      color: p.ink3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  RegistroKvLeader(
                    p: p,
                    k: 'SÍMBOLO',
                    v: c.symbol ?? '—',
                    mono: true,
                  ),
                  RegistroKvLeader(
                    p: p,
                    k: 'CÓDIGO ISO',
                    v: c.code,
                    mono: true,
                  ),
                  RegistroKvLeader(
                    p: p,
                    k: 'CAMBIOS',
                    v: rateCount > 0 ? '$rateCount' : '—',
                  ),
                  RegistroKvLeader(
                    p: p,
                    k: 'BANDERA',
                    v: (c.flagImage != null && c.flagImage!.isNotEmpty)
                        ? 'Asignada'
                        : 'Pendiente †',
                  ),
                  RegistroKvLeader(
                    p: p,
                    k: 'ID',
                    v: registroShortId(c.id),
                    mono: true,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      AppFlag(
                        base64String: c.flagImage,
                        fallbackCode: c.code,
                        width: 63,
                        height: 42,
                        borderRadius: 0,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'fig. $nn — enseña nacional',
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
                    label: 'EDITAR DIVISA',
                    onTap: onEdit ?? () {},
                  ),
                  const SizedBox(height: 9),
                  RegistroMarginAction(
                    p: p,
                    label: 'VER TIPOS DE CAMBIO',
                    onTap: onRates,
                  ),
                ],
              ),
            ),
    );
  }
}

// =========================================================================
// Diálogo de eliminación — estilo impreso
// =========================================================================
class _DeleteCurrencyDialog extends StatelessWidget {
  const _DeleteCurrencyDialog({required this.currency});
  final CurrencyModel currency;

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
        '¿Eliminar "${currency.name}" (${currency.code}) del registro? '
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
