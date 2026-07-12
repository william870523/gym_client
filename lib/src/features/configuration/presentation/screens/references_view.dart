import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/registro_palette.dart';
import '../../../../core/widgets/registro_widgets.dart';
import '../../data/models/reference_model.dart';
import '../providers/reference_notifier.dart';
import '../widgets/reference_form.dart';

/// Referencias — "CANALES Y REFERENCIAS" (F-15, sistema REGISTRO).
///
/// Ver docs/DESIGN_SYSTEM.md. Reutiliza [referenceProvider] y [ReferenceForm].
class ReferencesView extends ConsumerStatefulWidget {
  const ReferencesView({super.key});

  @override
  ConsumerState<ReferencesView> createState() => _ReferencesViewState();
}

enum _ReferenceSortKey { name, id }

class _ReferencesViewState extends ConsumerState<ReferencesView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _fName = TextEditingController();

  String _searchQuery = '';
  bool _filtersVisible = false;
  _ReferenceSortKey _sortKey = _ReferenceSortKey.name;
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
    super.dispose();
  }

  void _openForm([ReferenceModel? reference]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReferenceForm(
        id: reference?.id,
        initialName: reference?.nombre,
        onSubmit: (name) async {
          if (reference == null) {
            await ref.read(referenceProvider.notifier).create(name);
          } else {
            await ref
                .read(referenceProvider.notifier)
                .updateReference(reference.id, name);
          }
          _searchController.clear();
          if (mounted) {
            setState(() => _searchQuery = '');
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(ReferenceModel reference) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await RegistroDeleteDialog.show(
      context,
      title: 'ELIMINAR REFERENCIA',
      message:
          '¿Eliminar la referencia "${reference.nombre}" del catálogo? '
          'Esta acción no se puede deshacer.',
    );

    if (confirmed != true) return;
    try {
      await ref.read(referenceProvider.notifier).deleteReference(reference.id);
      if (mounted && _selectedId == reference.id) {
        setState(() => _selectedId = null);
      }
      _searchController.clear();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Referencia "${reference.nombre}" eliminada.'),
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

  bool _matchesSearch(ReferenceModel item) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery;
    return item.nombre.toLowerCase().contains(q) ||
        item.id.toLowerCase().contains(q);
  }

  bool _matchesColumnFilters(ReferenceModel item) {
    final f = _fName.text.trim().toLowerCase();
    return f.isEmpty || item.nombre.toLowerCase().contains(f);
  }

  void _toggleSort(_ReferenceSortKey key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sortKey = key;
        _sortAsc = true;
      }
    });
  }

  List<ReferenceModel> _sortList(List<ReferenceModel> list) {
    final copy = List<ReferenceModel>.from(list);
    copy.sort((a, b) {
      int cmp;
      switch (_sortKey) {
        case _ReferenceSortKey.name:
          cmp = a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
        case _ReferenceSortKey.id:
          cmp = a.id.compareTo(b.id);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return copy;
  }

  Widget _buildSummarySentence(
    RegistroPalette p,
    List<ReferenceModel> all,
    List<ReferenceModel> filtered,
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
              text: all.length == 1
                  ? ' fuente de atracción registrada.'
                  : ' fuentes de atracción registradas.',
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

  Widget _buildMarginalia(RegistroPalette p, ReferenceModel? selected) {
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
              'Seleccione un canal de referencia de la lista para inspeccionar su identificador y opciones.',
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
                  'ASIENTO Y CANAL',
                  style: GoogleFonts.archivo(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: p.ink3,
                  ),
                ),
                Text(
                  'ref_${registroShortId(selected.id)}',
                  style: GoogleFonts.fragmentMono(
                    fontSize: 11,
                    color: p.ink3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Visual figure
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
                        selected.nombre.toUpperCase(),
                        style: GoogleFonts.archivoBlack(
                          fontSize: 20,
                          color: p.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'CANAL DE CAPTACIÓN',
                      style: GoogleFonts.archivo(
                        fontSize: 10,
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

            // Dot leaders
            RegistroDotLeader(
              p: p,
              label: 'REFERENCIA',
              value: selected.nombre.toUpperCase(),
            ),
            const SizedBox(height: 8),
            RegistroDotLeader(
              p: p,
              label: 'IDENTIFICADOR',
              value: 'ref_${registroShortId(selected.id)}',
            ),
            const SizedBox(height: 20),

            Divider(height: 1, color: p.rule),
            const SizedBox(height: 16),

            // Actions
            RegistroTextAction(
              p: p,
              label: 'EDITAR REFERENCIA →',
              prime: true,
              onTap: () => _openForm(selected),
            ),
            const SizedBox(height: 12),
            RegistroTextAction(
              p: p,
              label: 'ELIMINAR REFERENCIA',
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
    final state = ref.watch(referenceProvider);

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
                  'componiendo el catálogo de referencias…',
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
              message: 'Error al cargar referencias: $err',
            ),
          ),
          data: (items) {
            final filtered = items
                .where(_matchesSearch)
                .where(_matchesColumnFilters)
                .toList();

            final sorted = _sortList(filtered);

            ReferenceModel? selectedReference;
            if (_selectedId != null) {
              for (final r in items) {
                if (r.id == _selectedId) {
                  selectedReference = r;
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
                    department: 'CONFIGURACIÓN Y ATRACCIÓN',
                    code: 'F-15 / CANALES Y REFERENCIAS · REV. 2026',
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
                              const TextSpan(text: 'CANALES Y\nREFERENCIAS'),
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
                            onTap: () => ref.invalidate(referenceProvider),
                          ),
                          RegistroTextAction(
                            p: p,
                            label: '＋ NUEVA REFERENCIA',
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
                                  hintText: 'nombre de la referencia… (Ctrl+K)',
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
                                hintText: 'filtro referencia…',
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
                                  flex: 5,
                                  child: RegistroSortHead(
                                    p: p,
                                    label: 'NOMBRE DE LA REFERENCIA',
                                    active: _sortKey == _ReferenceSortKey.name,
                                    asc: _sortAsc,
                                    onTap: () =>
                                        _toggleSort(_ReferenceSortKey.name),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: RegistroSortHead(
                                    p: p,
                                    label: 'IDENTIFICADOR',
                                    active: _sortKey == _ReferenceSortKey.id,
                                    asc: _sortAsc,
                                    onTap: () =>
                                        _toggleSort(_ReferenceSortKey.id),
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
                                  'No se encontraron referencias que coincidan.',
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
                                            flex: 5,
                                            child: Text(
                                              item.nombre,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.archivo(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: p.ink,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              'ref_${registroShortId(item.id)}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.fragmentMono(
                                                fontSize: 11,
                                                color: p.ink3,
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
                                  child: _buildMarginalia(p, selectedReference),
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
                            _buildMarginalia(p, selectedReference),
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
