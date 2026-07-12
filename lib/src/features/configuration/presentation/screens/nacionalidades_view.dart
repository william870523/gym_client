import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/registro_palette.dart';
import '../../../../core/widgets/app_flag.dart';
import '../../../../core/widgets/registro_widgets.dart';
import '../../data/models/nacionalidad_model.dart';
import '../state/nacionalidad_notifier.dart';
import '../widgets/nacionalidad_form.dart';

/// Nacionalidades — "ATLAS DE NACIONES" (F-13, sistema REGISTRO).
///
/// Ver docs/DESIGN_SYSTEM.md. Reutiliza [nacionalidadProvider] y
/// [NacionalidadForm].
class NacionalidadesView extends ConsumerStatefulWidget {
  const NacionalidadesView({super.key});

  @override
  ConsumerState<NacionalidadesView> createState() => _NacionalidadesViewState();
}

enum _NacFilter { all, withFlag, withoutFlag }

enum _NacSortKey { name, iso, status }

class _NacionalidadesViewState extends ConsumerState<NacionalidadesView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _fName = TextEditingController();
  final TextEditingController _fIso = TextEditingController();
  final TextEditingController _fStatus = TextEditingController();

  String _searchQuery = '';
  _NacFilter _filter = _NacFilter.all;
  bool _filtersVisible = false;
  _NacSortKey _sortKey = _NacSortKey.name;
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
    _fIso.dispose();
    _fStatus.dispose();
    super.dispose();
  }

  void _openForm([NacionalidadModel? item]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => NacionalidadForm(
        id: item?.id,
        initialName: item?.name,
        initialIsoCode: item?.isoCode,
        initialFlagImage: item?.flagImage,
        onSubmit: (name, isoCode, flagBytes) async {
          if (item == null) {
            await ref
                .read(nacionalidadProvider.notifier)
                .create(name, isoCode, flagBytes);
          } else {
            await ref
                .read(nacionalidadProvider.notifier)
                .updateNacionalidad(item.id, name, isoCode, flagBytes);
          }
          _searchController.clear();
          if (mounted) {
            setState(() => _searchQuery = '');
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(NacionalidadModel item) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await RegistroDeleteDialog.show(
      context,
      message: '¿Eliminar "${item.name}" (${item.isoCode}) del atlas? '
          'Esta acción no se puede deshacer.',
    );
    if (confirmed != true) return;
    try {
      await ref.read(nacionalidadProvider.notifier).delete(item.id);
      if (mounted && _selectedId == item.id) {
        setState(() => _selectedId = null);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Nacionalidad "${item.name}" eliminada.'),
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

  bool _hasFlag(NacionalidadModel n) =>
      n.flagImage != null && n.flagImage!.isNotEmpty;

  String _statusOf(NacionalidadModel n) =>
      _hasFlag(n) ? 'Con enseña' : 'Sin enseña';

  bool _matchesSearch(NacionalidadModel n) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery;
    return n.name.toLowerCase().contains(q) ||
        n.isoCode.toLowerCase().contains(q);
  }

  bool _matchesFilter(NacionalidadModel n) {
    switch (_filter) {
      case _NacFilter.withFlag:
        return _hasFlag(n);
      case _NacFilter.withoutFlag:
        return !_hasFlag(n);
      case _NacFilter.all:
        return true;
    }
  }

  bool _matchesColumnFilters(NacionalidadModel n) {
    bool has(TextEditingController t, String value) {
      final f = t.text.trim().toLowerCase();
      return f.isEmpty || value.toLowerCase().contains(f);
    }

    return has(_fName, n.name) &&
        has(_fIso, n.isoCode) &&
        has(_fStatus, _statusOf(n));
  }

  int _compare(NacionalidadModel a, NacionalidadModel b) {
    int r;
    switch (_sortKey) {
      case _NacSortKey.name:
        r = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case _NacSortKey.iso:
        r = a.isoCode.toLowerCase().compareTo(b.isoCode.toLowerCase());
      case _NacSortKey.status:
        r = _statusOf(a).compareTo(_statusOf(b));
    }
    return _sortAsc ? r : -r;
  }

  void _onSort(_NacSortKey key) {
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
    final state = ref.watch(nacionalidadProvider);

    final list = state.value ?? const <NacionalidadModel>[];
    final total = list.length;
    final withFlag = list.where(_hasFlag).length;
    final withoutFlag = total - withFlag;

    final indexById = <String, int>{
      for (var i = 0; i < list.length; i++) list[i].id: i + 1,
    };

    NacionalidadModel? selected;
    if (list.isNotEmpty) {
      selected = list.firstWhere(
        (n) => n.id == _selectedId,
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
                    department: 'CONFIGURACIÓN',
                    code: 'F-13 / NACIONALIDADES · REV. 2026',
                  ),
                  const SizedBox(height: 26),
                  _buildTitleRow(p),
                  const SizedBox(height: 18),
                  _buildLedgerLine(p, state, total, withFlag, withoutFlag),
                  const SizedBox(height: 26),
                  _buildCommand(p, total, withFlag, withoutFlag),
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
              text: 'ATLAS\nDE NACIONES',
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
              onTap: () => ref.invalidate(nacionalidadProvider),
            ),
            RegistroTextAction(
              p: p,
              label: '＋ NUEVA NACIONALIDAD',
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
    AsyncValue<List<NacionalidadModel>> state,
    int total,
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
    if (state.isLoading && total == 0) {
      sentence = Text('Componiendo el atlas…',
          style: base.copyWith(fontStyle: FontStyle.italic));
    } else if (state.hasError && total == 0) {
      sentence = Text('No fue posible leer el atlas.',
          style: base.copyWith(color: p.verm));
    } else if (total == 0) {
      sentence =
          Text('El atlas está vacío. Asienta la primera nación.', style: base);
    } else {
      sentence = Text.rich(
        TextSpan(style: base, children: [
          const TextSpan(text: 'El atlas registra '),
          TextSpan(text: '$total', style: big(p.ink)),
          TextSpan(
              text:
                  total == 1 ? ' nacionalidad: ' : ' nacionalidades: '),
          TextSpan(text: '$withFlag', style: big(p.verm)),
          TextSpan(
              text: withFlag == 1
                  ? ' tiene enseña asignada y '
                  : ' tienen enseña asignada y '),
          TextSpan(text: '$withoutFlag', style: big(p.ink)),
          TextSpan(
              text: withoutFlag == 1
                  ? ' aguarda bandera.'
                  : ' aguardan bandera.'),
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

  Widget _buildCommand(
      RegistroPalette p, int all, int withFlag, int withoutFlag) {
    final search = _buildSearch(p);
    final tabs = <Widget>[
      RegistroTab(
        p: p,
        label: 'TODAS',
        count: all,
        active: _filter == _NacFilter.all,
        onTap: () => setState(() => _filter = _NacFilter.all),
      ),
      RegistroTab(
        p: p,
        label: 'ABANDERADAS',
        count: withFlag,
        active: _filter == _NacFilter.withFlag,
        onTap: () => setState(() => _filter = _NacFilter.withFlag),
      ),
      RegistroTab(
        p: p,
        label: 'SIN ENSEÑA',
        count: withoutFlag,
        active: _filter == _NacFilter.withoutFlag,
        onTap: () => setState(() => _filter = _NacFilter.withoutFlag),
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
                hintText: 'nombre o código iso…',
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
    AsyncValue<List<NacionalidadModel>> state,
    List<NacionalidadModel> list,
    Map<String, int> indexById,
    NacionalidadModel? selected,
  ) {
    final table = _buildTable(p, state, list, indexById, selected?.id);
    final marginalia = _NacMarginalia(
      p: p,
      item: selected,
      index: selected == null ? 0 : (indexById[selected.id] ?? 0),
      onEdit: selected == null ? null : () => _openForm(selected),
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
    AsyncValue<List<NacionalidadModel>> state,
    List<NacionalidadModel> list,
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
        .where((n) =>
            _matchesSearch(n) &&
            _matchesFilter(n) &&
            _matchesColumnFilters(n))
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
                ? 'El atlas está vacío. Asienta la primera nación.'
                : 'Ninguna nacionalidad coincide. Ajusta la búsqueda o los filtros.',
          )
        else
          RegistroScrollableRows(
            p: p,
            itemCount: visible.length,
            itemBuilder: (context, i) => _NacRow(
              p: p,
              item: visible[i],
              index: indexById[visible[i].id] ?? (i + 1),
              status: _statusOf(visible[i]),
              selected: selectedId == visible[i].id,
              onSelect: () =>
                  setState(() => _selectedId = visible[i].id),
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
              label: 'NACIONALIDAD',
              active: _sortKey == _NacSortKey.name,
              asc: _sortAsc,
              onTap: () => _onSort(_NacSortKey.name),
            ),
          ),
          Expanded(
            flex: 2,
            child: RegistroSortHead(
              p: p,
              label: 'ISO',
              active: _sortKey == _NacSortKey.iso,
              asc: _sortAsc,
              onTap: () => _onSort(_NacSortKey.iso),
            ),
          ),
          Expanded(
            flex: 3,
            child: RegistroSortHead(
              p: p,
              label: 'ESTADO',
              active: _sortKey == _NacSortKey.status,
              asc: _sortAsc,
              onTap: () => _onSort(_NacSortKey.status),
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
                child: input(_fName, 'filtrar nombre…'),
              )),
          Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: input(_fIso, 'iso…'),
              )),
          Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: input(_fStatus, 'estado…'),
              )),
          const SizedBox(width: 140),
        ],
      ),
    );
  }

  Widget _buildColophon(RegistroPalette p, int shown, int total) {
    final names = {
      _NacSortKey.name: 'nacionalidad',
      _NacSortKey.iso: 'iso',
      _NacSortKey.status: 'estado',
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
              '† pendiente de enseña',
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
class _NacRow extends StatefulWidget {
  const _NacRow({
    required this.p,
    required this.item,
    required this.index,
    required this.status,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final RegistroPalette p;
  final NacionalidadModel item;
  final int index;
  final String status;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_NacRow> createState() => _NacRowState();
}

class _NacRowState extends State<_NacRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final sel = widget.selected;
    final bg = sel ? p.vermSoft : (_hover ? p.paper2 : Colors.transparent);
    final showActions = _hover || sel;
    final hasFlag = widget.status == 'Con enseña';

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
                child: Row(
                  children: [
                    AppFlag(
                      base64String: widget.item.flagImage,
                      countryCode: widget.item.isoCode,
                      fallbackCode: widget.item.isoCode,
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
              Expanded(
                flex: 2,
                child: Text(
                  widget.item.isoCode.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      GoogleFonts.fragmentMono(fontSize: 12, color: p.ink2),
                ),
              ),
              Expanded(
                flex: 3,
                child: hasFlag
                    ? Text(
                        'CON ENSEÑA',
                        style: GoogleFonts.archivo(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: p.ink,
                        ),
                      )
                    : Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: 'SIN ENSEÑA',
                            style: GoogleFonts.archivo(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: p.ink3,
                            ),
                          ),
                          TextSpan(
                            text: ' †',
                            style: GoogleFonts.archivo(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: p.verm,
                            ),
                          ),
                        ]),
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
class _NacMarginalia extends StatelessWidget {
  const _NacMarginalia({
    required this.p,
    required this.item,
    required this.index,
    required this.onEdit,
  });

  final RegistroPalette p;
  final NacionalidadModel? item;
  final int index;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final n = item;
    final nn = index.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.ruleStrong, width: 2)),
      ),
      child: n == null
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
                key: ValueKey(n.id),
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
                      n.isoCode.toUpperCase(),
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
                    n.name.toUpperCase(),
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
                    '${n.isoCode.toUpperCase()} · ${(n.flagImage?.isNotEmpty ?? false) ? 'CON ENSEÑA' : 'SIN ENSEÑA'}',
                    style:
                        GoogleFonts.fragmentMono(fontSize: 11, color: p.ink3),
                  ),
                  const SizedBox(height: 20),
                  RegistroKvLeader(
                      p: p, k: 'CÓDIGO ISO', v: n.isoCode.toUpperCase(),
                      mono: true),
                  RegistroKvLeader(
                    p: p,
                    k: 'ENSEÑA',
                    v: (n.flagImage?.isNotEmpty ?? false)
                        ? 'Asignada'
                        : 'Pendiente †',
                  ),
                  RegistroKvLeader(
                      p: p, k: 'ID', v: registroShortId(n.id), mono: true),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      AppFlag(
                        base64String: n.flagImage,
                        countryCode: n.isoCode,
                        fallbackCode: n.isoCode,
                        width: 60,
                        height: 40,
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
                    label: 'EDITAR NACIONALIDAD',
                    onTap: onEdit ?? () {},
                  ),
                ],
              ),
            ),
    );
  }
}
