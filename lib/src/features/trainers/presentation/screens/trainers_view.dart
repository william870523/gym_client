import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/registro_palette.dart';
import '../../../../core/widgets/base64_image.dart';
import '../../../../core/widgets/registro_widgets.dart';
import '../../data/models/trainer_model.dart';
import '../providers/trainer_notifier.dart';
import '../widgets/trainer_form.dart';

/// Entrenadores — "REGISTRO DE ENTRENADORES" (F-11, sistema REGISTRO).
///
/// Ver docs/DESIGN_SYSTEM.md. Reutiliza [trainerProvider] y [TrainerForm].
class TrainersView extends ConsumerStatefulWidget {
  const TrainersView({super.key});

  @override
  ConsumerState<TrainersView> createState() => _TrainersViewState();
}

enum _TrainerStatusFilter { all, active, inactive }

enum _TrainerSortKey { name, ci, contact, startDate, status }

class _TrainersViewState extends ConsumerState<TrainersView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _fName = TextEditingController();
  final TextEditingController _fCi = TextEditingController();
  final TextEditingController _fContact = TextEditingController();
  final TextEditingController _fStatus = TextEditingController();

  String _searchQuery = '';
  _TrainerStatusFilter _filter = _TrainerStatusFilter.all;
  bool _filtersVisible = false;
  _TrainerSortKey _sortKey = _TrainerSortKey.name;
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
    _fCi.dispose();
    _fContact.dispose();
    _fStatus.dispose();
    super.dispose();
  }

  String _fullName(TrainerModel trainer) {
    final first = (trainer.nombres ?? '').trim();
    final last = (trainer.apellidos ?? '').trim();
    final value = '$first $last'.trim();
    return value.isEmpty ? 'Entrenador sin nombre' : value;
  }

  String _contactLine(TrainerModel trainer) {
    final phone = trainer.telefono?.toString() ?? '';
    final email = (trainer.correo ?? '').trim();
    if (phone.isNotEmpty && email.isNotEmpty) {
      return '$phone • $email';
    }
    if (phone.isNotEmpty) return phone;
    if (email.isNotEmpty) return email;
    return 'Sin contacto';
  }

  void _openForm([TrainerModel? trainer]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 800,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: RegistroPalette.fromContext(context).paper,
            border: Border(top: BorderSide(color: RegistroPalette.fromContext(context).verm, width: 3)),
          ),
          child: TrainerForm(
            trainer: trainer,
            onCancel: () => Navigator.pop(context),
            onSuccess: () {
              Navigator.pop(context);
              ref.invalidate(trainerProvider);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(TrainerModel trainer) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await RegistroDeleteDialog.show(
      context,
      title: 'ELIMINAR ENTRENADOR',
      message:
          '¿Eliminar al entrenador "${_fullName(trainer)}" (CI: ${trainer.ci})? '
          'Esta acción no se puede deshacer.',
    );

    if (confirmed != true) return;
    try {
      await ref.read(trainerProvider.notifier).deleteTrainer(trainer.id);
      if (mounted && _selectedId == trainer.id) {
        setState(() => _selectedId = null);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Entrenador "${_fullName(trainer)}" eliminado.'),
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

  bool _matchesSearch(TrainerModel trainer) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery;
    return _fullName(trainer).toLowerCase().contains(q) ||
        trainer.ci.toLowerCase().contains(q) ||
        (trainer.correo ?? '').toLowerCase().contains(q) ||
        (trainer.telefono?.toString() ?? '').contains(q) ||
        trainer.id.toLowerCase().contains(q);
  }

  bool _matchesFilter(TrainerModel trainer) {
    switch (_filter) {
      case _TrainerStatusFilter.active:
        return trainer.activo;
      case _TrainerStatusFilter.inactive:
        return !trainer.activo;
      case _TrainerStatusFilter.all:
        return true;
    }
  }

  bool _matchesColumnFilters(TrainerModel trainer) {
    bool has(TextEditingController t, String value) {
      final f = t.text.trim().toLowerCase();
      return f.isEmpty || value.toLowerCase().contains(f);
    }

    return has(_fName, _fullName(trainer)) &&
        has(_fCi, trainer.ci) &&
        has(_fContact, _contactLine(trainer)) &&
        has(_fStatus, trainer.activo ? 'ACTIVO' : 'INACTIVO');
  }

  void _toggleSort(_TrainerSortKey key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sortKey = key;
        _sortAsc = true;
      }
    });
  }

  List<TrainerModel> _sortList(List<TrainerModel> list) {
    final copy = List<TrainerModel>.from(list);
    copy.sort((a, b) {
      int cmp;
      switch (_sortKey) {
        case _TrainerSortKey.name:
          cmp = _fullName(a).toLowerCase().compareTo(_fullName(b).toLowerCase());
        case _TrainerSortKey.ci:
          cmp = a.ci.compareTo(b.ci);
        case _TrainerSortKey.contact:
          cmp = _contactLine(a).compareTo(_contactLine(b));
        case _TrainerSortKey.startDate:
          cmp = a.fechaInicio.compareTo(b.fechaInicio);
        case _TrainerSortKey.status:
          cmp = (a.activo ? 1 : 0).compareTo(b.activo ? 1 : 0);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return copy;
  }

  Widget _buildSummarySentence(
    RegistroPalette p,
    List<TrainerModel> all,
    List<TrainerModel> filtered,
  ) {
    final activeCount = all.where((t) => t.activo).length;

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
              text: all.length == 1 ? ' entrenador, con ' : ' entrenadores, con ',
            ),
            TextSpan(
              text: '$activeCount',
              style: GoogleFonts.archivo(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: p.verm,
              ),
            ),
            const TextSpan(text: ' activos en la nómina del gimnasio.'),
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

  Widget _buildMarginalia(RegistroPalette p, TrainerModel? selected) {
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
              'Seleccione un entrenador de la lista para inspeccionar su ficha, CI, datos de contacto y fecha de ingreso.',
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

    final hasPhoto = selected.foto != null && selected.foto!.isNotEmpty;

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
                  'ASIENTO Y FICHA',
                  style: GoogleFonts.archivo(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: p.ink3,
                  ),
                ),
                Text(
                  'trn_${registroShortId(selected.id)}',
                  style: GoogleFonts.fragmentMono(
                    fontSize: 11,
                    color: p.ink3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Foto carnet / figure
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: p.paper,
                  border: Border.all(color: p.ruleStrong, width: 2),
                ),
                child: hasPhoto
                    ? Base64Image(
                        base64String: selected.foto!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      )
                    : Center(
                        child: Text(
                          _fullName(selected).substring(0, 1).toUpperCase(),
                          style: GoogleFonts.archivoBlack(
                            fontSize: 24,
                            color: p.verm,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _fullName(selected),
                textAlign: TextAlign.center,
                style: GoogleFonts.archivo(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: p.ink,
                ),
              ),
            ),
            Center(
              child: Text(
                'CI: ${selected.ci}',
                textAlign: TextAlign.center,
                style: GoogleFonts.fragmentMono(
                  fontSize: 11,
                  color: p.ink3,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Dot leaders
            RegistroDotLeader(
              p: p,
              label: 'TELÉFONO',
              value: selected.telefono?.toString() ?? 'NO REGISTRADO',
            ),
            const SizedBox(height: 8),
            RegistroDotLeader(
              p: p,
              label: 'CORREO',
              value: selected.correo?.isNotEmpty == true
                  ? selected.correo!
                  : 'NO REGISTRADO',
            ),
            const SizedBox(height: 8),
            RegistroDotLeader(
              p: p,
              label: 'DIRECCIÓN',
              value: selected.direccion?.isNotEmpty == true
                  ? selected.direccion!
                  : 'NO REGISTRADA',
            ),
            const SizedBox(height: 8),
            RegistroDotLeader(
              p: p,
              label: 'INGRESO',
              value: DateFormat('dd/MM/yyyy').format(selected.fechaInicio),
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
              label: 'EDITAR ENTRENADOR →',
              prime: true,
              onTap: () => _openForm(selected),
            ),
            const SizedBox(height: 12),
            RegistroTextAction(
              p: p,
              label: 'ELIMINAR ENTRENADOR',
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
    final trainersAsync = ref.watch(trainerProvider);

    return Scaffold(
      backgroundColor: p.paper,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
              _searchFocus.requestFocus(),
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
              _searchFocus.requestFocus(),
        },
        child: trainersAsync.when(
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
                  'componiendo la nómina de entrenadores…',
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
              message: 'Error al cargar entrenadores: $err',
            ),
          ),
          data: (trainers) {
            final filtered = trainers
                .where(_matchesSearch)
                .where(_matchesFilter)
                .where(_matchesColumnFilters)
                .toList();

            final sorted = _sortList(filtered);
            final activeCount = trainers.where((t) => t.activo).length;
            final inactiveCount = trainers.length - activeCount;

            TrainerModel? selectedTrainer;
            if (_selectedId != null) {
              for (final t in trainers) {
                if (t.id == _selectedId) {
                  selectedTrainer = t;
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
                    department: 'PERSONAL Y ENTRENADORES',
                    code: 'F-11 / ENTRENADORES · REV. 2026',
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
                              const TextSpan(text: 'REGISTRO DE\nENTRENADORES'),
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
                            onTap: () => ref.invalidate(trainerProvider),
                          ),
                          RegistroTextAction(
                            p: p,
                            label: '＋ NUEVO ENTRENADOR',
                            prime: true,
                            onTap: () => _openForm(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Summary sentence KPI
                  _buildSummarySentence(p, trainers, sorted),
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
                                      'nombre, CI, correo o teléfono… (Ctrl+K)',
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
                                      count: trainers.length,
                                      active: _filter == _TrainerStatusFilter.all,
                                      onTap: () => setState(
                                        () => _filter = _TrainerStatusFilter.all,
                                      ),
                                    ),
                                    RegistroTab(
                                      p: p,
                                      label: 'ACTIVOS',
                                      count: activeCount,
                                      active: _filter == _TrainerStatusFilter.active,
                                      onTap: () => setState(
                                        () => _filter = _TrainerStatusFilter.active,
                                      ),
                                    ),
                                    RegistroTab(
                                      p: p,
                                      label: 'INACTIVOS',
                                      count: inactiveCount,
                                      active: _filter == _TrainerStatusFilter.inactive,
                                      onTap: () => setState(
                                        () => _filter = _TrainerStatusFilter.inactive,
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
                                    count: trainers.length,
                                    active: _filter == _TrainerStatusFilter.all,
                                    onTap: () => setState(
                                      () => _filter = _TrainerStatusFilter.all,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  RegistroTab(
                                    p: p,
                                    label: 'ACTIVOS',
                                    count: activeCount,
                                    active: _filter == _TrainerStatusFilter.active,
                                    onTap: () => setState(
                                      () => _filter = _TrainerStatusFilter.active,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  RegistroTab(
                                    p: p,
                                    label: 'INACTIVOS',
                                    count: inactiveCount,
                                    active: _filter == _TrainerStatusFilter.inactive,
                                    onTap: () => setState(
                                      () => _filter = _TrainerStatusFilter.inactive,
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
                              controller: _fCi,
                              onChanged: (_) => setState(() {}),
                              cursorColor: p.verm,
                              style: GoogleFonts.fragmentMono(
                                fontSize: 12,
                                color: p.ink,
                              ),
                              decoration: InputDecoration(
                                hintText: 'filtro CI…',
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
                              controller: _fContact,
                              onChanged: (_) => setState(() {}),
                              cursorColor: p.verm,
                              style: GoogleFonts.fragmentMono(
                                fontSize: 12,
                                color: p.ink,
                              ),
                              decoration: InputDecoration(
                                hintText: 'filtro contacto…',
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
                                    label: 'ENTRENADOR',
                                    active: _sortKey == _TrainerSortKey.name,
                                    asc: _sortAsc,
                                    onTap: () =>
                                        _toggleSort(_TrainerSortKey.name),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: RegistroSortHead(
                                    p: p,
                                    label: 'CI / DNI',
                                    active: _sortKey == _TrainerSortKey.ci,
                                    asc: _sortAsc,
                                    onTap: () =>
                                        _toggleSort(_TrainerSortKey.ci),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: RegistroSortHead(
                                    p: p,
                                    label: 'CONTACTO',
                                    active: _sortKey == _TrainerSortKey.contact,
                                    asc: _sortAsc,
                                    onTap: () =>
                                        _toggleSort(_TrainerSortKey.contact),
                                  ),
                                ),
                                SizedBox(
                                  width: 90,
                                  child: RegistroSortHead(
                                    p: p,
                                    label: 'ESTADO',
                                    active: _sortKey == _TrainerSortKey.status,
                                    asc: _sortAsc,
                                    onTap: () =>
                                        _toggleSort(_TrainerSortKey.status),
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
                                  'No se encontraron entrenadores que coincidan con la búsqueda.',
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
                                                  _fullName(item),
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
                                                  'trn_${registroShortId(item.id)}',
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
                                              item.ci,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.fragmentMono(
                                                fontSize: 11.5,
                                                color: p.ink2,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              _contactLine(item),
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
                                    '${sorted.length} de ${trainers.length} asientos · orden: ${_sortKey.name} ${_sortAsc ? "↑" : "↓"}',
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
                                  child: _buildMarginalia(p, selectedTrainer),
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
                            _buildMarginalia(p, selectedTrainer),
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
