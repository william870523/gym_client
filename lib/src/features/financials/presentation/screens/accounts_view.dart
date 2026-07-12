import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/registro_palette.dart';
import '../../../../core/widgets/app_flag.dart';
import '../../../../core/widgets/registro_widgets.dart';
import '../../../dashboard/presentation/state/dashboard_nav_provider.dart';
import '../../data/models/account_model.dart';
import '../state/account_notifier.dart';
import 'account_form.dart';

/// Cuentas — "PLAN DE CUENTAS" (F-06, sistema REGISTRO).
///
/// Ver docs/DESIGN_SYSTEM.md. Reutiliza [accountProvider] y [AccountForm].
class AccountsView extends ConsumerStatefulWidget {
  const AccountsView({super.key});

  @override
  ConsumerState<AccountsView> createState() => _AccountsViewState();
}

enum _AccSortKey { name, currency, symbol }

class _AccountsViewState extends ConsumerState<AccountsView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _fName = TextEditingController();
  final TextEditingController _fCurrency = TextEditingController();
  final TextEditingController _fSymbol = TextEditingController();

  String _searchQuery = '';
  bool _filtersVisible = false;
  _AccSortKey _sortKey = _AccSortKey.name;
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
    _fCurrency.dispose();
    _fSymbol.dispose();
    super.dispose();
  }

  void _openForm([AccountModel? item]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AccountForm(
        account: item,
        onSave: (name, currencyId, {paymentTypeId}) async {
          if (item == null) {
            await ref
                .read(accountProvider.notifier)
                .createAccount(name, currencyId, paymentTypeId: paymentTypeId);
          } else {
            await ref.read(accountProvider.notifier).updateAccount(
                  item.id,
                  name,
                  currencyId,
                  paymentTypeId: paymentTypeId,
                );
          }
          _searchController.clear();
          if (mounted) {
            setState(() => _searchQuery = '');
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(AccountModel item) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await RegistroDeleteDialog.show(
      context,
      message: '¿Eliminar la cuenta "${item.name}" del plan? '
          'Esta acción no se puede deshacer.',
    );
    if (confirmed != true) return;
    try {
      await ref.read(accountProvider.notifier).deleteAccount(item.id);
      if (mounted && _selectedId == item.id) {
        setState(() => _selectedId = null);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Cuenta "${item.name}" eliminada.'),
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

  String _currencyLabel(AccountModel a) =>
      a.currencyCode ?? registroShortId(a.currencyId);

  bool _matchesSearch(AccountModel a) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery;
    return a.name.toLowerCase().contains(q) ||
        (a.currencyCode ?? '').toLowerCase().contains(q) ||
        (a.currencyName ?? '').toLowerCase().contains(q) ||
        (a.currencySymbol ?? '').toLowerCase().contains(q);
  }

  bool _matchesColumnFilters(AccountModel a) {
    bool has(TextEditingController t, String value) {
      final f = t.text.trim().toLowerCase();
      return f.isEmpty || value.toLowerCase().contains(f);
    }

    return has(_fName, a.name) &&
        has(_fCurrency, '${_currencyLabel(a)} ${a.currencyName ?? ''}') &&
        has(_fSymbol, a.currencySymbol ?? '—');
  }

  int _compare(AccountModel a, AccountModel b) {
    int r;
    switch (_sortKey) {
      case _AccSortKey.name:
        r = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case _AccSortKey.currency:
        r = _currencyLabel(a)
            .toLowerCase()
            .compareTo(_currencyLabel(b).toLowerCase());
      case _AccSortKey.symbol:
        r = (a.currencySymbol ?? '').compareTo(b.currencySymbol ?? '');
    }
    return _sortAsc ? r : -r;
  }

  void _onSort(_AccSortKey key) {
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
    final p = RegistroPalette.fromContext(context);
    final state = ref.watch(accountProvider);

    final list = state.value ?? const <AccountModel>[];
    final total = list.length;
    final currencyIds = <String>{for (final a in list) a.currencyId};

    final indexById = <String, int>{
      for (var i = 0; i < list.length; i++) list[i].id: i + 1,
    };

    AccountModel? selected;
    if (list.isNotEmpty) {
      selected = list.firstWhere(
        (a) => a.id == _selectedId,
        orElse: () => list.first,
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
                    code: 'F-06 / CUENTAS · REV. 2026',
                  ),
                  const SizedBox(height: 26),
                  _buildTitleRow(p),
                  const SizedBox(height: 18),
                  _buildLedgerLine(p, state, total, currencyIds.length),
                  const SizedBox(height: 26),
                  _buildCommand(p),
                  const SizedBox(height: 30),
                  _buildSheet(p, state, list, indexById, selected),
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
              text: 'PLAN\nDE CUENTAS',
              children: [
                TextSpan(text: '.', style: TextStyle(color: p.verm)),
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
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            RegistroTextAction(
              p: p,
              label: '↻ ACTUALIZAR',
              onTap: () => ref.read(accountProvider.notifier).refresh(),
            ),
            RegistroTextAction(
              p: p,
              label: '＋ NUEVA CUENTA',
              prime: true,
              onTap: () => _openForm(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLedgerLine(
    RegistroPalette p,
    AsyncValue<List<AccountModel>> state,
    int total,
    int currencies,
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
    if (state.isLoading && total == 0) {
      sentence = Text('Componiendo el plan…',
          style: base.copyWith(fontStyle: FontStyle.italic));
    } else if (state.hasError && total == 0) {
      sentence = Text('No fue posible leer el plan de cuentas.',
          style: base.copyWith(color: p.verm));
    } else if (total == 0) {
      sentence = Text('El plan está vacío. Asienta la primera cuenta.',
          style: base);
    } else {
      sentence = Text.rich(
        TextSpan(style: base, children: [
          const TextSpan(text: 'El plan contiene '),
          TextSpan(text: '$total', style: big(p.verm)),
          TextSpan(text: total == 1 ? ' cuenta sobre ' : ' cuentas sobre '),
          TextSpan(text: '$currencies', style: big(p.ink)),
          TextSpan(
              text: currencies == 1
                  ? ' divisa del catálogo.'
                  : ' divisas del catálogo.'),
        ]),
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

  Widget _buildCommand(RegistroPalette p) {
    final search = _buildSearch(p);
    final filterTab = RegistroTab(
      p: p,
      label: 'FILTROS ¶',
      count: null,
      active: _filtersVisible,
      onTap: () => setState(() => _filtersVisible = !_filtersVisible),
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 700) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: search),
              const SizedBox(width: 34),
              filterTab,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            search,
            const SizedBox(height: 16),
            Wrap(children: [filterTab]),
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
                hintText: 'cuenta, divisa o símbolo…',
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
                child:
                    Text('✕', style: TextStyle(fontSize: 12, color: p.ink3)),
              ),
            )
          else
            Text('CTRL K',
                style: GoogleFonts.fragmentMono(fontSize: 10, color: p.ink4)),
        ],
      ),
    );
  }

  Widget _buildSheet(
    RegistroPalette p,
    AsyncValue<List<AccountModel>> state,
    List<AccountModel> list,
    Map<String, int> indexById,
    AccountModel? selected,
  ) {
    final table = _buildTable(p, state, list, indexById, selected?.id);
    final marginalia = _AccMarginalia(
      p: p,
      item: selected,
      index: selected == null ? 0 : (indexById[selected.id] ?? 0),
      onEdit: selected == null ? null : () => _openForm(selected),
      onCurrencies: () =>
          ref.read(dashboardNavProvider.notifier).setIndex(21),
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
          children: [
            table,
            const SizedBox(height: 30),
            marginalia,
          ],
        );
      },
    );
  }

  Widget _buildTable(
    RegistroPalette p,
    AsyncValue<List<AccountModel>> state,
    List<AccountModel> list,
    Map<String, int> indexById,
    String? selectedId,
  ) {
    if (state.isLoading && list.isEmpty) {
      return RegistroLoadingBlock(p: p);
    }
    if (state.hasError && list.isEmpty) {
      return RegistroErrorBlock(p: p, message: '${state.error}');
    }

    final visible = list
        .where((a) => _matchesSearch(a) && _matchesColumnFilters(a))
        .toList()
      ..sort(_compare);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderRow(p),
        if (_filtersVisible) _buildFilterRow(p),
        if (visible.isEmpty)
          RegistroEmptyBlock(
            p: p,
            message: list.isEmpty
                ? 'El plan está vacío. Asienta la primera cuenta.'
                : 'Ninguna cuenta coincide. Ajusta la búsqueda o los filtros.',
          )
        else
          RegistroScrollableRows(
            p: p,
            itemCount: visible.length,
            itemBuilder: (context, i) => _AccRow(
              p: p,
              item: visible[i],
              index: indexById[visible[i].id] ?? (i + 1),
              currencyLabel: _currencyLabel(visible[i]),
              selected: selectedId == visible[i].id,
              onSelect: () => setState(() => _selectedId = visible[i].id),
              onEdit: () => _openForm(visible[i]),
              onDelete: () => _confirmDelete(visible[i]),
            ),
          ),
        _buildColophon(p, visible.length, list.length),
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
            flex: 5,
            child: RegistroSortHead(
              p: p,
              label: 'CUENTA',
              active: _sortKey == _AccSortKey.name,
              asc: _sortAsc,
              onTap: () => _onSort(_AccSortKey.name),
            ),
          ),
          Expanded(
            flex: 3,
            child: RegistroSortHead(
              p: p,
              label: 'DIVISA',
              active: _sortKey == _AccSortKey.currency,
              asc: _sortAsc,
              onTap: () => _onSort(_AccSortKey.currency),
            ),
          ),
          Expanded(
            flex: 2,
            child: RegistroSortHead(
              p: p,
              label: 'SÍMBOLO',
              active: _sortKey == _AccSortKey.symbol,
              asc: _sortAsc,
              onTap: () => _onSort(_AccSortKey.symbol),
            ),
          ),
          const SizedBox(width: 140),
        ],
      ),
    );
  }

  Widget _buildFilterRow(RegistroPalette p) {
    Widget input(TextEditingController t, String hint) {
      return TextField(
        controller: t,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.fragmentMono(fontSize: 11, color: p.ink),
        cursorColor: p.verm,
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: GoogleFonts.fragmentMono(
              fontSize: 11, fontStyle: FontStyle.italic, color: p.ink4),
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
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: input(_fName, 'filtrar cuenta…'),
              )),
          Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: input(_fCurrency, 'divisa…'),
              )),
          Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: input(_fSymbol, 'símbolo…'),
              )),
          const SizedBox(width: 140),
        ],
      ),
    );
  }

  Widget _buildColophon(RegistroPalette p, int shown, int total) {
    final names = {
      _AccSortKey.name: 'cuenta',
      _AccSortKey.currency: 'divisa',
      _AccSortKey.symbol: 'símbolo',
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
          Flexible(
            child: Text(
              'una divisa por cuenta',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mono.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
          Text('orden: ${names[_sortKey]} ${_sortAsc ? '↑' : '↓'}',
              style: mono),
        ],
      ),
    );
  }
}

// =========================================================================
// Fila
// =========================================================================
class _AccRow extends StatefulWidget {
  const _AccRow({
    required this.p,
    required this.item,
    required this.index,
    required this.currencyLabel,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final RegistroPalette p;
  final AccountModel item;
  final int index;
  final String currencyLabel;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_AccRow> createState() => _AccRowState();
}

class _AccRowState extends State<_AccRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final sel = widget.selected;
    final bg = sel ? p.vermSoft : (_hover ? p.paper2 : Colors.transparent);
    final showActions = _hover || sel;
    final item = widget.item;

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
              Expanded(
                flex: 5,
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.archivo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    AppFlag(
                      bytes: item.currencyImage,
                      fallbackCode: item.currencyCode,
                      width: 33,
                      height: 22,
                      borderRadius: 0,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.currencyLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.fragmentMono(
                            fontSize: 12, color: p.ink2),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  item.currencySymbol ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.fragmentMono(fontSize: 14, color: p.ink),
                ),
              ),
              SizedBox(
                width: 140,
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

// =========================================================================
// Marginalia
// =========================================================================
class _AccMarginalia extends StatelessWidget {
  const _AccMarginalia({
    required this.p,
    required this.item,
    required this.index,
    required this.onEdit,
    required this.onCurrencies,
  });

  final RegistroPalette p;
  final AccountModel? item;
  final int index;
  final VoidCallback? onEdit;
  final VoidCallback onCurrencies;

  @override
  Widget build(BuildContext context) {
    final a = item;
    final nn = index.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.ruleStrong, width: 2)),
      ),
      child: a == null
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
                key: ValueKey(a.id),
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
                      (a.currencySymbol?.isNotEmpty ?? false)
                          ? a.currencySymbol!
                          : '¤',
                      maxLines: 1,
                      style: GoogleFonts.archivoBlack(
                        fontSize: 96,
                        height: 0.95,
                        letterSpacing: -3,
                        color: p.verm,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    a.name.toUpperCase(),
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
                    '${a.currencyCode ?? '—'} · ${(a.currencyName ?? 'DIVISA').toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        GoogleFonts.fragmentMono(fontSize: 11, color: p.ink3),
                  ),
                  const SizedBox(height: 20),
                  RegistroKvLeader(
                    p: p,
                    k: 'DIVISA',
                    v: a.currencyCode ?? '—',
                    mono: true,
                  ),
                  RegistroKvLeader(
                    p: p,
                    k: 'SÍMBOLO',
                    v: a.currencySymbol ?? '—',
                    mono: true,
                  ),
                  RegistroKvLeader(
                    p: p,
                    k: 'TIPO DE PAGO',
                    v: a.paymentTypeId == null
                        ? '—'
                        : registroShortId(a.paymentTypeId!),
                    mono: true,
                  ),
                  RegistroKvLeader(
                      p: p, k: 'ID', v: registroShortId(a.id), mono: true),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      AppFlag(
                        bytes: a.currencyImage,
                        fallbackCode: a.currencyCode,
                        width: 60,
                        height: 40,
                        borderRadius: 0,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'fig. $nn — divisa de la cuenta',
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
                    label: 'EDITAR CUENTA',
                    onTap: onEdit ?? () {},
                  ),
                  const SizedBox(height: 9),
                  RegistroMarginAction(
                    p: p,
                    label: 'VER MONEDAS',
                    onTap: onCurrencies,
                  ),
                ],
              ),
            ),
    );
  }
}
