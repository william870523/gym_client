import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/registro_palette.dart';
import '../../../../core/widgets/registro_widgets.dart';
import '../../data/models/horario_model.dart';
import '../state/horario_notifier.dart';
import '../widgets/horario_form.dart';

/// Horarios — "HORARIOS Y TURNOS" (F-10, sistema REGISTRO).
///
/// Ver docs/DESIGN_SYSTEM.md. Reutiliza [horarioNotifierProvider] y [HorarioForm].
class HorariosView extends ConsumerStatefulWidget {
  const HorariosView({super.key});

  @override
  ConsumerState<HorariosView> createState() => _HorariosViewState();
}

enum _HorarioSortKey { name, start, end }

class _HorariosViewState extends ConsumerState<HorariosView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _fName = TextEditingController();
  final TextEditingController _fStart = TextEditingController();
  final TextEditingController _fEnd = TextEditingController();

  String _searchQuery = '';
  bool _filtersVisible = false;
  _HorarioSortKey _sortKey = _HorarioSortKey.name;
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
    _fStart.dispose();
    _fEnd.dispose();
    super.dispose();
  }

  void _openForm([HorarioModel? item]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => HorarioForm(horario: item),
    );
  }

  Future<void> _confirmDelete(HorarioModel item) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await RegistroDeleteDialog.show(
      context,
      title: 'ELIMINAR HORARIO',
      message:
          '¿Eliminar el bloque horario "${item.nombre}" (${item.horaInicioFormatted} - ${item.horaFinFormatted})? '
          'Esta acción no se puede deshacer.',
    );

    if (confirmed != true) return;
    try {
      await ref.read(horarioNotifierProvider.notifier).delete(item.id);
      if (mounted && _selectedId == item.id) {
        setState(() => _selectedId = null);
      }
      _searchController.clear();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Horario "${item.nombre}" eliminado.'),
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

  bool _matchesSearch(HorarioModel item) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery;
    return item.nombre.toLowerCase().contains(q) ||
        item.horaInicioFormatted.toLowerCase().contains(q) ||
        item.horaFinFormatted.toLowerCase().contains(q) ||
        item.id.toLowerCase().contains(q);
  }

  bool _matchesColumnFilters(HorarioModel item) {
    bool has(TextEditingController t, String value) {
      final f = t.text.trim().toLowerCase();
      return f.isEmpty || value.toLowerCase().contains(f);
    }

    return has(_fName, item.nombre) &&
        has(_fStart, item.horaInicioFormatted) &&
        has(_fEnd, item.horaFinFormatted);
  }

  void _toggleSort(_HorarioSortKey key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sortKey = key;
        _sortAsc = true;
      }
    });
  }

  List<HorarioModel> _sortList(List<HorarioModel> list) {
    final copy = List<HorarioModel>.from(list);
    copy.sort((a, b) {
      int cmp;
      switch (_sortKey) {
        case _HorarioSortKey.name:
          cmp = a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
        case _HorarioSortKey.start:
          cmp = a.horaInicioFormatted.compareTo(b.horaInicioFormatted);
        case _HorarioSortKey.end:
          cmp = a.horaFinFormatted.compareTo(b.horaFinFormatted);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return copy;
  }

  Widget _buildSummarySentence(
    RegistroPalette p,
    List<HorarioModel> all,
    List<HorarioModel> filtered,
  ) {
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
            const TextSpan(text: 'El registro contiene '),
            TextSpan(
              text: '${all.length}',
              style: GoogleFonts.archivo(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
            TextSpan(
              text: all.length == 1
                  ? ' bloque horario configurado para la agenda.'
                  : ' bloques horarios configurados para la agenda.',
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

  Widget _buildMarginalia(RegistroPalette p, HorarioModel? selected) {
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
              'Seleccione un bloque horario de la lista para inspeccionar las horas de apertura y cierre.',
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
                  'ASIENTO Y HORARIO',
                  style: GoogleFonts.archivo(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: p.ink3,
                  ),
                ),
                Text(
                  'hor_${registroShortId(selected.id)}',
                  style: GoogleFonts.fragmentMono(
                    fontSize: 11,
                    color: p.ink3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Time range display
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
                    FittedBox(
                      child: Text(
                        '${selected.horaInicioFormatted} — ${selected.horaFinFormatted}',
                        style: GoogleFonts.fragmentMono(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: p.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RANGO HORARIO BASE',
                      style: GoogleFonts.archivo(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
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
              label: 'BLOQUE HORARIO',
              value: selected.nombre.toUpperCase(),
            ),
            const SizedBox(height: 8),
            RegistroDotLeader(
              p: p,
              label: 'HORA APERTURA',
              value: selected.horaInicioFormatted,
            ),
            const SizedBox(height: 8),
            RegistroDotLeader(
              p: p,
              label: 'HORA CIERRE',
              value: selected.horaFinFormatted,
            ),
            const SizedBox(height: 20),

            Divider(height: 1, color: p.rule),
            const SizedBox(height: 16),

            // Actions
            RegistroTextAction(
              p: p,
              label: 'EDITAR HORARIO →',
              prime: true,
              onTap: () => _openForm(selected),
            ),
            const SizedBox(height: 12),
            RegistroTextAction(
              p: p,
              label: 'ELIMINAR HORARIO',
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
    final state = ref.watch(horarioNotifierProvider);

    return Scaffold(
      backgroundColor: p.paper,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
              _searchFocus.requestFocus(),
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
              _searchFocus.requestFocus(),
        },
        child: state.when(
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
                  'componiendo la agenda de horarios…',
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
              message: 'Error al cargar horarios: $err',
            ),
          ),
          data: (items) {
            final filtered = items
                .where(_matchesSearch)
                .where(_matchesColumnFilters)
                .toList();

            final sorted = _sortList(filtered);

            HorarioModel? selectedHorario;
            if (_selectedId != null) {
              for (final h in items) {
                if (h.id == _selectedId) {
                  selectedHorario = h;
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
                    department: 'OPERACIÓN Y AGENDA',
                    code: 'F-10 / HORARIOS Y TURNOS · REV. 2026',
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
                              const TextSpan(text: 'HORARIOS\nY TURNOS'),
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
                            onTap: () => ref
                                .read(horarioNotifierProvider.notifier)
                                .refresh(),
                          ),
                          RegistroTextAction(
                            p: p,
                            label: '＋ NUEVO HORARIO',
                            prime: true,
                            onTap: () => _openForm(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Summary sentence KPI
                  _buildSummarySentence(p, items, sorted),
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
                                  hintText: 'nombre o rango horario… (Ctrl+K)',
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
                          if (isNarrow && _filtersVisible) ...[
                            const SizedBox(height: 12),
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
                              controller: _fStart,
                              onChanged: (_) => setState(() {}),
                              cursorColor: p.verm,
                              style: GoogleFonts.fragmentMono(
                                fontSize: 12,
                                color: p.ink,
                              ),
                              decoration: InputDecoration(
                                hintText: 'filtro inicio…',
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
                              controller: _fEnd,
                              onChanged: (_) => setState(() {}),
                              cursorColor: p.verm,
                              style: GoogleFonts.fragmentMono(
                                fontSize: 12,
                                color: p.ink,
                              ),
                              decoration: InputDecoration(
                                hintText: 'filtro fin…',
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
                                  flex: 4,
                                  child: RegistroSortHead(
                                    p: p,
                                    label: 'BLOQUE HORARIO',
                                    active: _sortKey == _HorarioSortKey.name,
                                    asc: _sortAsc,
                                    onTap: () =>
                                        _toggleSort(_HorarioSortKey.name),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: RegistroSortHead(
                                    p: p,
                                    label: 'HORA INICIO',
                                    active: _sortKey == _HorarioSortKey.start,
                                    asc: _sortAsc,
                                    onTap: () =>
                                        _toggleSort(_HorarioSortKey.start),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: RegistroSortHead(
                                    p: p,
                                    label: 'HORA FIN',
                                    active: _sortKey == _HorarioSortKey.end,
                                    asc: _sortAsc,
                                    onTap: () =>
                                        _toggleSort(_HorarioSortKey.end),
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
                                  'No se encontraron horarios registrados.',
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

                                return MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => setState(
                                      () => _selectedId = item.id,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
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
                                            flex: 4,
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
                                                  'hor_${registroShortId(item.id)}',
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
                                            child: Text(
                                              item.horaInicioFormatted,
                                              style: GoogleFonts.fragmentMono(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: p.ink,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              item.horaFinFormatted,
                                              style: GoogleFonts.fragmentMono(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: p.ink,
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
                                    '${sorted.length} de ${items.length} asientos · orden: ${_sortKey.name} ${_sortAsc ? "↑" : "↓"}',
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
                                  child: _buildMarginalia(p, selectedHorario),
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
                            _buildMarginalia(p, selectedHorario),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
