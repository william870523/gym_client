import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/registro_palette.dart';
import '../../../../core/widgets/registro_widgets.dart';
import '../../domain/models/gym.dart';
import '../gyms_provider.dart';
import 'gym_form_view.dart';

/// Gimnasios — "SEDES Y GIMNASIOS" (F-14, sistema REGISTRO).
///
/// Ver docs/DESIGN_SYSTEM.md. Reutiliza [gymsListProvider] y [GymFormView].
class GymsDashboardView extends ConsumerStatefulWidget {
  const GymsDashboardView({super.key});

  @override
  ConsumerState<GymsDashboardView> createState() => _GymsDashboardViewState();
}

enum _GymStatusFilter { all, active, inactive }

enum _GymSortKey { code, name, location, status }

class _GymsDashboardViewState extends ConsumerState<GymsDashboardView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _fCode = TextEditingController();
  final TextEditingController _fName = TextEditingController();
  final TextEditingController _fLocation = TextEditingController();
  final TextEditingController _fStatus = TextEditingController();

  String _searchQuery = '';
  _GymStatusFilter _filter = _GymStatusFilter.all;
  bool _filtersVisible = false;
  _GymSortKey _sortKey = _GymSortKey.code;
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
    _fCode.dispose();
    _fName.dispose();
    _fLocation.dispose();
    _fStatus.dispose();
    super.dispose();
  }

  void _openForm([Gym? gym]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => GymFormView(gym: gym),
    );
  }

  Future<void> _confirmDelete(Gym gym) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await RegistroDeleteDialog.show(
      context,
      title: 'ELIMINAR SEDE',
      message:
          '¿Eliminar la sede "${gym.name}" (Código: ${gym.code}) y su configuración asociada? '
          'Esta acción no se puede deshacer.',
    );

    if (confirmed != true) return;
    try {
      await ref.read(gymsControllerProvider.notifier).deleteGym(gym.id);
      if (mounted && _selectedId == gym.id) {
        setState(() => _selectedId = null);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Sede "${gym.name}" eliminada.'),
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

  bool _matchesSearch(Gym gym) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery;
    return gym.name.toLowerCase().contains(q) ||
        gym.code.toLowerCase().contains(q) ||
        (gym.address ?? '').toLowerCase().contains(q) ||
        (gym.city ?? '').toLowerCase().contains(q) ||
        (gym.country ?? '').toLowerCase().contains(q) ||
        gym.id.toLowerCase().contains(q);
  }

  bool _matchesFilter(Gym gym) {
    final active = gym.active == true || (gym.active as dynamic) == 1;
    switch (_filter) {
      case _GymStatusFilter.active:
        return active;
      case _GymStatusFilter.inactive:
        return !active;
      case _GymStatusFilter.all:
        return true;
    }
  }

  bool _matchesColumnFilters(Gym gym) {
    bool has(TextEditingController t, String value) {
      final f = t.text.trim().toLowerCase();
      return f.isEmpty || value.toLowerCase().contains(f);
    }

    final locationStr = '${gym.city ?? ''} ${gym.country ?? ''}';
    final active = gym.active == true || (gym.active as dynamic) == 1;

    return has(_fCode, gym.code) &&
        has(_fName, gym.name) &&
        has(_fLocation, locationStr) &&
        has(_fStatus, active ? 'ACTIVO' : 'INACTIVO');
  }

  void _toggleSort(_GymSortKey key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sortKey = key;
        _sortAsc = true;
      }
    });
  }

  List<Gym> _sortList(List<Gym> list) {
    final copy = List<Gym>.from(list);
    copy.sort((a, b) {
      int cmp;
      switch (_sortKey) {
        case _GymSortKey.code:
          cmp = a.code.toLowerCase().compareTo(b.code.toLowerCase());
        case _GymSortKey.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _GymSortKey.location:
          cmp = (a.city ?? '').compareTo(b.city ?? '');
        case _GymSortKey.status:
          final aAct = a.active == true || (a.active as dynamic) == 1;
          final bAct = b.active == true || (b.active as dynamic) == 1;
          cmp = (aAct ? 1 : 0).compareTo(bAct ? 1 : 0);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return copy;
  }

  Widget _buildSummarySentence(
    RegistroPalette p,
    List<Gym> all,
    List<Gym> filtered,
  ) {
    final activeCount = all.where((g) => g.active == true || (g.active as dynamic) == 1).length;

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
              text: all.length == 1 ? ' sede registrada, con ' : ' sedes registradas, con ',
            ),
            TextSpan(
              text: '$activeCount',
              style: GoogleFonts.archivo(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: p.verm,
              ),
            ),
            const TextSpan(text: ' operativas en la red de gimnasios.'),
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

  Widget _buildMarginalia(RegistroPalette p, Gym? selected) {
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
              'Seleccione una sede de la lista para inspeccionar su código, dirección y zona horaria.',
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

    final isActive = selected.active == true || (selected.active as dynamic) == 1;

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
                  'ASIENTO Y SEDE',
                  style: GoogleFonts.archivo(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: p.ink3,
                  ),
                ),
                Text(
                  'gym_${registroShortId(selected.id)}',
                  style: GoogleFonts.fragmentMono(
                    fontSize: 11,
                    color: p.ink3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Figure: Gym code display
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
                        selected.code.toUpperCase(),
                        style: GoogleFonts.fragmentMono(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: p.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'CÓDIGO DE SUCURSAL',
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

            Text(
              selected.name,
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
              label: 'DIRECCIÓN',
              value: selected.address?.isNotEmpty == true
                  ? selected.address!
                  : 'NO REGISTRADA',
            ),
            const SizedBox(height: 8),
            RegistroDotLeader(
              p: p,
              label: 'CIUDAD',
              value: selected.city?.isNotEmpty == true ? selected.city! : 'N/A',
            ),
            const SizedBox(height: 8),
            RegistroDotLeader(
              p: p,
              label: 'PAÍS',
              value: selected.country?.isNotEmpty == true
                  ? selected.country!
                  : 'N/A',
            ),
            const SizedBox(height: 8),
            RegistroDotLeader(
              p: p,
              label: 'TIMEZONE',
              value: selected.timezone?.isNotEmpty == true
                  ? selected.timezone!
                  : 'Etc/UTC',
            ),
            const SizedBox(height: 8),
            RegistroDotLeader(
              p: p,
              label: 'ESTADO',
              value: isActive ? 'ACTIVO' : 'INACTIVO',
              valueColor: isActive ? p.ink : p.verm,
            ),
            const SizedBox(height: 20),

            Divider(height: 1, color: p.rule),
            const SizedBox(height: 16),

            // Actions
            RegistroTextAction(
              p: p,
              label: 'EDITAR SEDE →',
              prime: true,
              onTap: () => _openForm(selected),
            ),
            const SizedBox(height: 12),
            RegistroTextAction(
              p: p,
              label: 'ELIMINAR SEDE',
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
    final gymsAsync = ref.watch(gymsListProvider);

    return Scaffold(
      backgroundColor: p.paper,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
              _searchFocus.requestFocus(),
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
              _searchFocus.requestFocus(),
        },
        child: gymsAsync.when(
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
                  'componiendo la red de gimnasios…',
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
              message: 'Error al cargar gimnasios: $err',
            ),
          ),
          data: (gyms) {
            final filtered = gyms
                .where(_matchesSearch)
                .where(_matchesFilter)
                .where(_matchesColumnFilters)
                .toList();

            final sorted = _sortList(filtered);
            final activeCount = gyms
                .where((g) => g.active == true || (g.active as dynamic) == 1)
                .length;
            final inactiveCount = gyms.length - activeCount;

            Gym? selectedGym;
            if (_selectedId != null) {
              for (final g in gyms) {
                if (g.id == _selectedId) {
                  selectedGym = g;
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
                    department: 'SEDES Y REGISTRO',
                    code: 'F-14 / SEDES Y GIMNASIOS · REV. 2026',
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
                              const TextSpan(text: 'REGISTRO DE\nSEDES'),
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
                            onTap: () => ref.invalidate(gymsListProvider),
                          ),
                          RegistroTextAction(
                            p: p,
                            label: '＋ NUEVA SEDE',
                            prime: true,
                            onTap: () => _openForm(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Summary sentence KPI
                  _buildSummarySentence(p, gyms, sorted),
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
                                      'nombre, código, ciudad o país… (Ctrl+K)',
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
                                      label: 'TODAS',
                                      count: gyms.length,
                                      active: _filter == _GymStatusFilter.all,
                                      onTap: () => setState(
                                        () => _filter = _GymStatusFilter.all,
                                      ),
                                    ),
                                    RegistroTab(
                                      p: p,
                                      label: 'ACTIVAS',
                                      count: activeCount,
                                      active: _filter == _GymStatusFilter.active,
                                      onTap: () => setState(
                                        () => _filter = _GymStatusFilter.active,
                                      ),
                                    ),
                                    RegistroTab(
                                      p: p,
                                      label: 'INACTIVAS',
                                      count: inactiveCount,
                                      active: _filter == _GymStatusFilter.inactive,
                                      onTap: () => setState(
                                        () => _filter = _GymStatusFilter.inactive,
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
                                    label: 'TODAS',
                                    count: gyms.length,
                                    active: _filter == _GymStatusFilter.all,
                                    onTap: () => setState(
                                      () => _filter = _GymStatusFilter.all,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  RegistroTab(
                                    p: p,
                                    label: 'ACTIVAS',
                                    count: activeCount,
                                    active: _filter == _GymStatusFilter.active,
                                    onTap: () => setState(
                                      () => _filter = _GymStatusFilter.active,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  RegistroTab(
                                    p: p,
                                    label: 'INACTIVAS',
                                    count: inactiveCount,
                                    active: _filter == _GymStatusFilter.inactive,
                                    onTap: () => setState(
                                      () => _filter = _GymStatusFilter.inactive,
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
                              controller: _fCode,
                              onChanged: (_) => setState(() {}),
                              cursorColor: p.verm,
                              style: GoogleFonts.fragmentMono(
                                fontSize: 12,
                                color: p.ink,
                              ),
                              decoration: InputDecoration(
                                hintText: 'filtro código…',
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
                              controller: _fLocation,
                              onChanged: (_) => setState(() {}),
                              cursorColor: p.verm,
                              style: GoogleFonts.fragmentMono(
                                fontSize: 12,
                                color: p.ink,
                              ),
                              decoration: InputDecoration(
                                hintText: 'filtro ubicación…',
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
                                  flex: 2,
                                  child: RegistroSortHead(
                                    p: p,
                                    label: 'CÓDIGO',
                                    active: _sortKey == _GymSortKey.code,
                                    asc: _sortAsc,
                                    onTap: () => _toggleSort(_GymSortKey.code),
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: RegistroSortHead(
                                    p: p,
                                    label: 'NOMBRE DE SEDE',
                                    active: _sortKey == _GymSortKey.name,
                                    asc: _sortAsc,
                                    onTap: () => _toggleSort(_GymSortKey.name),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: RegistroSortHead(
                                    p: p,
                                    label: 'UBICACIÓN',
                                    active: _sortKey == _GymSortKey.location,
                                    asc: _sortAsc,
                                    onTap: () =>
                                        _toggleSort(_GymSortKey.location),
                                  ),
                                ),
                                SizedBox(
                                  width: 90,
                                  child: RegistroSortHead(
                                    p: p,
                                    label: 'ESTADO',
                                    active: _sortKey == _GymSortKey.status,
                                    asc: _sortAsc,
                                    onTap: () =>
                                        _toggleSort(_GymSortKey.status),
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
                                  'No se encontraron sedes que coincidan con la búsqueda.',
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
                                final isActive = item.active == true ||
                                    (item.active as dynamic) == 1;

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
                                            flex: 2,
                                            child: Text(
                                              item.code,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.fragmentMono(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: p.ink,
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
                                                  item.name,
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
                                                  item.address?.isNotEmpty == true
                                                      ? item.address!
                                                      : 'Sin dirección',
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
                                            flex: 3,
                                            child: Text(
                                              '${item.city ?? ''}${item.city != null && item.country != null ? ', ' : ''}${item.country ?? ''}',
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
                                              isActive ? 'ACTIVO' : 'INACTIVO',
                                              style: GoogleFonts.fragmentMono(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: isActive
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
                                    '${sorted.length} de ${gyms.length} asientos · orden: ${_sortKey.name} ${_sortAsc ? "↑" : "↓"}',
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
                                  child: _buildMarginalia(p, selectedGym),
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
                            _buildMarginalia(p, selectedGym),
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
