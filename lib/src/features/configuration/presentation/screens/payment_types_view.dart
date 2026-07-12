import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/registro_palette.dart';
import '../../../../core/widgets/registro_widgets.dart';
import '../../data/models/payment_type_model.dart';
import '../state/payment_type_notifier.dart';
import '../widgets/payment_type_form.dart';

/// Tipos de pago — "MEDIOS DE PAGO" (F-13, sistema REGISTRO).
///
/// Ver docs/DESIGN_SYSTEM.md. Reutiliza [paymentTypeNotifierProvider] y
/// [PaymentTypeForm].
class PaymentTypesView extends ConsumerStatefulWidget {
  const PaymentTypesView({super.key});

  @override
  ConsumerState<PaymentTypesView> createState() => _PaymentTypesViewState();
}

enum _PtFilter { all, active, inactive }

enum _PtSortKey { name, code, status }

class _PaymentTypesViewState extends ConsumerState<PaymentTypesView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _fName = TextEditingController();
  final TextEditingController _fCode = TextEditingController();
  final TextEditingController _fStatus = TextEditingController();

  String _searchQuery = '';
  _PtFilter _filter = _PtFilter.all;
  bool _filtersVisible = false;
  _PtSortKey _sortKey = _PtSortKey.name;
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
    _fCode.dispose();
    _fStatus.dispose();
    super.dispose();
  }

  void _openForm([PaymentTypeModel? item]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentTypeForm(
        id: item?.id,
        initialName: item?.name,
        initialCode: item?.code,
        initialActive: item?.active ?? true,
        onSubmit: (name, code, active) async {
          if (item == null) {
            await ref
                .read(paymentTypeNotifierProvider.notifier)
                .create(name, code, active);
          } else {
            await ref
                .read(paymentTypeNotifierProvider.notifier)
                .updatePaymentType(item.id, name, code, active);
          }
          _searchController.clear();
          if (mounted) {
            setState(() => _searchQuery = '');
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(PaymentTypeModel item) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await RegistroDeleteDialog.show(
      context,
      message: '¿Eliminar el medio de pago "${item.name}"? '
          'Esta acción no se puede deshacer.',
    );
    if (confirmed != true) return;
    try {
      await ref.read(paymentTypeNotifierProvider.notifier).delete(item.id);
      if (mounted && _selectedId == item.id) {
        setState(() => _selectedId = null);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Medio de pago "${item.name}" eliminado.'),
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

  String _statusOf(PaymentTypeModel t) => t.active ? 'Activo' : 'Inactivo';

  bool _matchesSearch(PaymentTypeModel t) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery;
    return t.name.toLowerCase().contains(q) ||
        (t.code ?? '').toLowerCase().contains(q);
  }

  bool _matchesFilter(PaymentTypeModel t) {
    switch (_filter) {
      case _PtFilter.active:
        return t.active;
      case _PtFilter.inactive:
        return !t.active;
      case _PtFilter.all:
        return true;
    }
  }

  bool _matchesColumnFilters(PaymentTypeModel t) {
    bool has(TextEditingController c, String value) {
      final f = c.text.trim().toLowerCase();
      return f.isEmpty || value.toLowerCase().contains(f);
    }

    return has(_fName, t.name) &&
        has(_fCode, t.code ?? '—') &&
        has(_fStatus, _statusOf(t));
  }

  int _compare(PaymentTypeModel a, PaymentTypeModel b) {
    int r;
    switch (_sortKey) {
      case _PtSortKey.name:
        r = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case _PtSortKey.code:
        r = (a.code ?? '')
            .toLowerCase()
            .compareTo((b.code ?? '').toLowerCase());
      case _PtSortKey.status:
        r = _statusOf(a).compareTo(_statusOf(b));
    }
    return _sortAsc ? r : -r;
  }

  void _onSort(_PtSortKey key) {
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
    final state = ref.watch(paymentTypeNotifierProvider);

    final list = state.value ?? const <PaymentTypeModel>[];
    final total = list.length;
    final activeCount = list.where((t) => t.active).length;
    final inactiveCount = total - activeCount;

    final indexById = <String, int>{
      for (var i = 0; i < list.length; i++) list[i].id: i + 1,
    };

    PaymentTypeModel? selected;
    if (list.isNotEmpty) {
      selected = list.firstWhere(
        (t) => t.id == _selectedId,
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
                    code: 'F-13 / TIPOS DE PAGO · REV. 2026',
                  ),
                  const SizedBox(height: 26),
                  _buildTitleRow(p),
                  const SizedBox(height: 18),
                  _buildLedgerLine(
                      p, state, total, activeCount, inactiveCount),
                  const SizedBox(height: 26),
                  _buildCommand(p, total, activeCount, inactiveCount),
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
              text: 'MEDIOS\nDE PAGO',
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
              onTap: () => ref.invalidate(paymentTypeNotifierProvider),
            ),
            RegistroTextAction(
              p: p,
              label: '＋ NUEVO MEDIO',
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
    AsyncValue<List<PaymentTypeModel>> state,
    int total,
    int active,
    int inactive,
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
      sentence = Text('Componiendo el registro…',
          style: base.copyWith(fontStyle: FontStyle.italic));
    } else if (state.hasError && total == 0) {
      sentence = Text('No fue posible leer el registro.',
          style: base.copyWith(color: p.verm));
    } else if (total == 0) {
      sentence = Text('Aún no se acepta ningún medio de pago.', style: base);
    } else {
      sentence = Text.rich(
        TextSpan(style: base, children: [
          const TextSpan(text: 'El gimnasio acepta '),
          TextSpan(text: '$active', style: big(p.verm)),
          TextSpan(
              text: active == 1
                  ? ' medio de pago activo de '
                  : ' medios de pago activos de '),
          TextSpan(text: '$total', style: big(p.ink)),
          TextSpan(text: total == 1 ? ' registrado' : ' registrados'),
          if (inactive > 0) ...[
            const TextSpan(text: '; '),
            TextSpan(text: '$inactive', style: big(p.ink)),
            TextSpan(
                text: inactive == 1
                    ? ' permanece inactivo.'
                    : ' permanecen inactivos.'),
          ] else
            const TextSpan(text: '.'),
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

  Widget _buildCommand(RegistroPalette p, int all, int active, int inactive) {
    final search = _buildSearch(p);
    final tabs = <Widget>[
      RegistroTab(
        p: p,
        label: 'TODOS',
        count: all,
        active: _filter == _PtFilter.all,
        onTap: () => setState(() => _filter = _PtFilter.all),
      ),
      RegistroTab(
        p: p,
        label: 'ACTIVOS',
        count: active,
        active: _filter == _PtFilter.active,
        onTap: () => setState(() => _filter = _PtFilter.active),
      ),
      RegistroTab(
        p: p,
        label: 'INACTIVOS',
        count: inactive,
        active: _filter == _PtFilter.inactive,
        onTap: () => setState(() => _filter = _PtFilter.inactive),
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
                hintText: 'nombre o código…',
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
    AsyncValue<List<PaymentTypeModel>> state,
    List<PaymentTypeModel> list,
    Map<String, int> indexById,
    PaymentTypeModel? selected,
  ) {
    final table = _buildTable(p, state, list, indexById, selected?.id);
    final marginalia = _PtMarginalia(
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
    AsyncValue<List<PaymentTypeModel>> state,
    List<PaymentTypeModel> list,
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
        .where((t) =>
            _matchesSearch(t) &&
            _matchesFilter(t) &&
            _matchesColumnFilters(t))
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
                ? 'Aún no se registra ningún medio de pago.'
                : 'Ningún medio de pago coincide. Ajusta la búsqueda o los filtros.',
          )
        else
          RegistroScrollableRows(
            p: p,
            itemCount: visible.length,
            itemBuilder: (context, i) => _PtRow(
              p: p,
              item: visible[i],
              index: indexById[visible[i].id] ?? (i + 1),
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
              label: 'MEDIO DE PAGO',
              active: _sortKey == _PtSortKey.name,
              asc: _sortAsc,
              onTap: () => _onSort(_PtSortKey.name),
            ),
          ),
          Expanded(
            flex: 2,
            child: RegistroSortHead(
              p: p,
              label: 'CÓDIGO',
              active: _sortKey == _PtSortKey.code,
              asc: _sortAsc,
              onTap: () => _onSort(_PtSortKey.code),
            ),
          ),
          Expanded(
            flex: 3,
            child: RegistroSortHead(
              p: p,
              label: 'ESTADO',
              active: _sortKey == _PtSortKey.status,
              asc: _sortAsc,
              onTap: () => _onSort(_PtSortKey.status),
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
                child: input(_fCode, 'código…'),
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
      _PtSortKey.name: 'medio',
      _PtSortKey.code: 'código',
      _PtSortKey.status: 'estado',
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
              '† medio inactivo',
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
class _PtRow extends StatefulWidget {
  const _PtRow({
    required this.p,
    required this.item,
    required this.index,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final RegistroPalette p;
  final PaymentTypeModel item;
  final int index;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_PtRow> createState() => _PtRowState();
}

class _PtRowState extends State<_PtRow> {
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
          padding: const EdgeInsets.symmetric(vertical: 12),
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
                    color: item.active ? p.ink : p.ink3,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  (item.code?.isNotEmpty ?? false)
                      ? item.code!.toUpperCase()
                      : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      GoogleFonts.fragmentMono(fontSize: 12, color: p.ink2),
                ),
              ),
              Expanded(
                flex: 3,
                child: item.active
                    ? Text(
                        'ACTIVO',
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
                            text: 'INACTIVO',
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
class _PtMarginalia extends StatelessWidget {
  const _PtMarginalia({
    required this.p,
    required this.item,
    required this.index,
    required this.onEdit,
  });

  final RegistroPalette p;
  final PaymentTypeModel? item;
  final int index;
  final VoidCallback? onEdit;

  String _glyphOf(PaymentTypeModel t) {
    final code = t.code;
    if (code != null && code.isNotEmpty) {
      return code.length > 4
          ? code.substring(0, 4).toUpperCase()
          : code.toUpperCase();
    }
    final words =
        t.name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final initials = words.take(2).map((w) => w[0]).join();
    return initials.isEmpty ? '¤' : initials.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = item;
    final nn = index.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.ruleStrong, width: 2)),
      ),
      child: t == null
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
                key: ValueKey(t.id),
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
                      _glyphOf(t),
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
                    t.name.toUpperCase(),
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
                    '${(t.code?.isNotEmpty ?? false) ? t.code!.toUpperCase() : 'SIN CÓDIGO'} · ${t.active ? 'ACTIVO' : 'INACTIVO'}',
                    style:
                        GoogleFonts.fragmentMono(fontSize: 11, color: p.ink3),
                  ),
                  const SizedBox(height: 20),
                  RegistroKvLeader(
                    p: p,
                    k: 'CÓDIGO',
                    v: (t.code?.isNotEmpty ?? false)
                        ? t.code!.toUpperCase()
                        : '—',
                    mono: true,
                  ),
                  RegistroKvLeader(
                    p: p,
                    k: 'ESTADO',
                    v: t.active ? 'Activo' : 'Inactivo †',
                  ),
                  RegistroKvLeader(
                      p: p, k: 'ID', v: registroShortId(t.id), mono: true),
                  const SizedBox(height: 22),
                  Divider(height: 1, thickness: 1, color: p.rule),
                  const SizedBox(height: 12),
                  RegistroMarginAction(
                    p: p,
                    label: 'EDITAR MEDIO DE PAGO',
                    onTap: onEdit ?? () {},
                  ),
                ],
              ),
            ),
    );
  }
}
