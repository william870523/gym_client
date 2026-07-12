import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/registro_palette.dart';
import '../../../../core/widgets/registro_widgets.dart';
import '../../../auth/domain/models/user.dart';
import '../providers/users_provider.dart';
import 'create_user_screen.dart';

/// Usuarios — "REGISTRO DE USUARIOS" (F-07, sistema REGISTRO).
///
/// Ver docs/DESIGN_SYSTEM.md. Reutiliza [usersProvider] y [CreateUserScreen].
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

enum _UserStatusFilter { all, active, inactive }

enum _UserSortKey { name, role, coverage, status }

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _fName = TextEditingController();
  final TextEditingController _fRole = TextEditingController();
  final TextEditingController _fCoverage = TextEditingController();
  final TextEditingController _fStatus = TextEditingController();

  String _searchQuery = '';
  _UserStatusFilter _filter = _UserStatusFilter.all;
  bool _filtersVisible = false;
  _UserSortKey _sortKey = _UserSortKey.name;
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
    _fRole.dispose();
    _fCoverage.dispose();
    _fStatus.dispose();
    super.dispose();
  }

  String _roleLabel(User u) {
    return switch (u.role.toLowerCase()) {
      'admin' || 'administrador' => 'Administrador',
      'trainer' || 'entrenador' => 'Entrenador',
      'reception' || 'recepcion' || 'recepción' => 'Recepción',
      'maintenance' || 'mantenimiento' => 'Mantenimiento',
      _ => u.role.isEmpty ? 'Sin rol' : u.role,
    };
  }

  String _coverageTitle(User u) {
    final gymId = u.gymId?.trim();
    if (gymId != null && gymId.isNotEmpty) {
      final shortId = gymId.length > 8 ? gymId.substring(0, 8) : gymId;
      return 'Gym $shortId';
    }
    return 'Acceso global';
  }

  String _initials(User u) {
    final source = u.name.trim().isNotEmpty ? u.name.trim() : u.email.trim();
    if (source.isEmpty) return '?';
    return source
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
  }

  Future<void> _openForm([User? user]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateUserScreen(userToEdit: user),
      ),
    );
    if (mounted) {
      ref.invalidate(usersProvider);
    }
  }

  Future<void> _confirmDelete(User item) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await RegistroDeleteDialog.show(
      context,
      title: 'ELIMINAR USUARIO',
      message:
          '¿Eliminar el usuario "${item.name.isEmpty ? item.email : item.name}" (${_roleLabel(item)})? '
          'Se eliminarán sus accesos asociados. Esta acción no se puede deshacer.',
    );
    if (confirmed != true) return;
    try {
      await ref.read(usersProvider.notifier).deleteUser(item.id);
      if (mounted && _selectedId == item.id) {
        setState(() => _selectedId = null);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Usuario "${item.name}" eliminado correctamente.'),
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

  bool _matchesSearch(User u) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery;
    return u.name.toLowerCase().contains(q) ||
        u.email.toLowerCase().contains(q) ||
        u.role.toLowerCase().contains(q) ||
        u.id.toLowerCase().contains(q) ||
        (u.gymId ?? '').toLowerCase().contains(q);
  }

  bool _matchesFilter(User u) {
    switch (_filter) {
      case _UserStatusFilter.active:
        return u.active;
      case _UserStatusFilter.inactive:
        return !u.active;
      case _UserStatusFilter.all:
        return true;
    }
  }

  bool _matchesColumnFilters(User u) {
    bool has(TextEditingController t, String value) {
      final f = t.text.trim().toLowerCase();
      return f.isEmpty || value.toLowerCase().contains(f);
    }

    return has(_fName, '${u.name} ${u.email}') &&
        has(_fRole, _roleLabel(u)) &&
        has(_fCoverage, _coverageTitle(u)) &&
        has(_fStatus, u.active ? 'ACTIVO' : 'INACTIVO');
  }

  void _toggleSort(_UserSortKey key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sortKey = key;
        _sortAsc = true;
      }
    });
  }

  List<User> _sortList(List<User> list) {
    final copy = List<User>.from(list);
    copy.sort((a, b) {
      int cmp;
      switch (_sortKey) {
        case _UserSortKey.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _UserSortKey.role:
          cmp = _roleLabel(a).compareTo(_roleLabel(b));
        case _UserSortKey.coverage:
          cmp = _coverageTitle(a).compareTo(_coverageTitle(b));
        case _UserSortKey.status:
          cmp = (a.active ? 1 : 0).compareTo(b.active ? 1 : 0);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return copy;
  }

  Widget _buildSummarySentence(
    RegistroPalette p,
    List<User> all,
    List<User> filtered,
  ) {
    final activeCount = all.where((u) => u.active).length;
    final adminCount =
        all.where((u) => u.role.toLowerCase().contains('admin')).length;

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
              text: all.length == 1 ? ' usuario, con ' : ' usuarios, con ',
            ),
            TextSpan(
              text: '$activeCount',
              style: GoogleFonts.archivo(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: p.verm,
              ),
            ),
            const TextSpan(text: ' activos y '),
            TextSpan(
              text: '$adminCount',
              style: GoogleFonts.archivo(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
            TextSpan(
              text: adminCount == 1
                  ? ' con perfil administrador.'
                  : ' con perfil administrador.',
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

  Widget _buildMarginalia(RegistroPalette p, User? selected) {
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
              'Seleccione un usuario de la lista para inspeccionar sus permisos, rol y credenciales de acceso.',
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

    final hasImage = selected.imageUrl != null && selected.imageUrl!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.paper2,
        border: Border(left: BorderSide(color: p.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ASIENTO Y PERFIL',
                style: GoogleFonts.archivo(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: p.ink3,
                ),
              ),
              Text(
                'usr_${registroShortId(selected.id)}',
                style: GoogleFonts.fragmentMono(
                  fontSize: 11,
                  color: p.ink3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Visual avatar / figure
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: p.paper,
                border: Border.all(color: p.ruleStrong, width: 2),
              ),
              child: hasImage
                  ? Image.network(
                      selected.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Text(
                          _initials(selected),
                          style: GoogleFonts.archivoBlack(
                            fontSize: 24,
                            color: p.verm,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        _initials(selected),
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
              selected.name.isEmpty ? 'Usuario sin nombre' : selected.name,
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
              selected.email,
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
            label: 'ROL EN SISTEMA',
            value: _roleLabel(selected).toUpperCase(),
          ),
          const SizedBox(height: 8),
          RegistroDotLeader(
            p: p,
            label: 'COBERTURA',
            value: _coverageTitle(selected).toUpperCase(),
          ),
          const SizedBox(height: 8),
          RegistroDotLeader(
            p: p,
            label: 'PERMISOS',
            value: selected.permissions.isEmpty
                ? 'POR ROL'
                : '${selected.permissions.length} ASIGNADOS',
          ),
          const SizedBox(height: 8),
          RegistroDotLeader(
            p: p,
            label: 'ESTADO',
            value: selected.active ? 'ACTIVO' : 'INACTIVO',
            valueColor: selected.active ? p.ink : p.verm,
          ),
          const SizedBox(height: 20),

          // Permisos list if any
          if (selected.permissions.isNotEmpty) ...[
            Text(
              'PERMISOS ESPECÍFICOS:',
              style: GoogleFonts.archivo(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: p.ink3,
              ),
            ),
            const SizedBox(height: 6),
            ...selected.permissions.map(
              (perm) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text('• ', style: TextStyle(color: p.verm)),
                    Expanded(
                      child: Text(
                        perm,
                        style: GoogleFonts.fragmentMono(
                          fontSize: 11,
                          color: p.ink2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          Divider(height: 1, color: p.rule),
          const SizedBox(height: 16),

          // Actions
          RegistroTextAction(
            p: p,
            label: 'EDITAR PERFIL →',
            prime: true,
            onTap: () => _openForm(selected),
          ),
          const SizedBox(height: 12),
          RegistroTextAction(
            p: p,
            label: 'ELIMINAR USUARIO',
            onTap: () => _confirmDelete(selected),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = RegistroPalette.fromContext(context);
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      backgroundColor: p.paper,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
              _searchFocus.requestFocus(),
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
              _searchFocus.requestFocus(),
        },
        child: usersAsync.when(
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
                  'componiendo el registro de usuarios…',
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
              message: 'Error al cargar usuarios: $err',
            ),
          ),
          data: (users) {
            final filtered = users
                .where(_matchesSearch)
                .where(_matchesFilter)
                .where(_matchesColumnFilters)
                .toList();

            final sorted = _sortList(filtered);
            final activeUserCount = users.where((u) => u.active).length;
            final inactiveUserCount = users.length - activeUserCount;

            User? selectedUser;
            if (_selectedId != null) {
              for (final u in users) {
                if (u.id == _selectedId) {
                  selectedUser = u;
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
                    department: 'ADMINISTRACIÓN',
                    code: 'F-07 / USUARIOS · REV. 2026',
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
                              const TextSpan(text: 'REGISTRO\nDE USUARIOS'),
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
                            onTap: () => ref.invalidate(usersProvider),
                          ),
                          RegistroTextAction(
                            p: p,
                            label: '＋ NUEVO USUARIO',
                            prime: true,
                            onTap: () => _openForm(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Summary sentence KPI
                  _buildSummarySentence(p, users, sorted),
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
                                      'nombre, correo, rol, gym o ID… (Ctrl+K)',
                                  onChanged: (v) =>
                                      setState(() => _searchQuery = v.trim().toLowerCase()),
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
                                      count: users.length,
                                      active: _filter == _UserStatusFilter.all,
                                      onTap: () => setState(
                                        () => _filter = _UserStatusFilter.all,
                                      ),
                                    ),
                                    RegistroTab(
                                      p: p,
                                      label: 'ACTIVOS',
                                      count: activeUserCount,
                                      active: _filter == _UserStatusFilter.active,
                                      onTap: () => setState(
                                        () => _filter = _UserStatusFilter.active,
                                      ),
                                    ),
                                    RegistroTab(
                                      p: p,
                                      label: 'INACTIVOS',
                                      count: inactiveUserCount,
                                      active: _filter == _UserStatusFilter.inactive,
                                      onTap: () => setState(
                                        () => _filter = _UserStatusFilter.inactive,
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
                                    count: users.length,
                                    active: _filter == _UserStatusFilter.all,
                                    onTap: () => setState(
                                      () => _filter = _UserStatusFilter.all,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  RegistroTab(
                                    p: p,
                                    label: 'ACTIVOS',
                                    count: activeUserCount,
                                    active: _filter == _UserStatusFilter.active,
                                    onTap: () => setState(
                                      () => _filter = _UserStatusFilter.active,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  RegistroTab(
                                    p: p,
                                    label: 'INACTIVOS',
                                    count: inactiveUserCount,
                                    active: _filter == _UserStatusFilter.inactive,
                                    onTap: () => setState(
                                      () => _filter = _UserStatusFilter.inactive,
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
                                hintText: 'filtro usuario…',
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
                              controller: _fRole,
                              onChanged: (_) => setState(() {}),
                              cursorColor: p.verm,
                              style: GoogleFonts.fragmentMono(
                                fontSize: 12,
                                color: p.ink,
                              ),
                              decoration: InputDecoration(
                                hintText: 'filtro rol…',
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
                              controller: _fCoverage,
                              onChanged: (_) => setState(() {}),
                              cursorColor: p.verm,
                              style: GoogleFonts.fragmentMono(
                                fontSize: 12,
                                color: p.ink,
                              ),
                              decoration: InputDecoration(
                                hintText: 'filtro cobertura…',
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
                                    label: 'USUARIO Y CORREO',
                                    active: _sortKey == _UserSortKey.name,
                                    asc: _sortAsc,
                                    onTap: () => _toggleSort(_UserSortKey.name),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: RegistroSortHead(
                                    p: p,
                                    label: 'ROL',
                                    active: _sortKey == _UserSortKey.role,
                                    asc: _sortAsc,
                                    onTap: () => _toggleSort(_UserSortKey.role),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: RegistroSortHead(
                                    p: p,
                                    label: 'COBERTURA',
                                    active: _sortKey == _UserSortKey.coverage,
                                    asc: _sortAsc,
                                    onTap: () => _toggleSort(_UserSortKey.coverage),
                                  ),
                                ),
                                SizedBox(
                                  width: 90,
                                  child: RegistroSortHead(
                                    p: p,
                                    label: 'ESTADO',
                                    active: _sortKey == _UserSortKey.status,
                                    asc: _sortAsc,
                                    onTap: () => _toggleSort(_UserSortKey.status),
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
                                  'No se encontraron usuarios que coincidan con la búsqueda.',
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
                                    onTap: () =>
                                        setState(() => _selectedId = item.id),
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
                                                  item.name.isEmpty
                                                      ? 'Usuario sin nombre'
                                                      : item.name,
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
                                                  item.email,
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
                                              _roleLabel(item).toUpperCase(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.archivo(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1.1,
                                                color: p.ink2,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              _coverageTitle(item),
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
                                              item.active
                                                  ? 'ACTIVO'
                                                  : 'INACTIVO',
                                              style: GoogleFonts.fragmentMono(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: item.active
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
                                    '${sorted.length} de ${users.length} asientos · orden: ${_sortKey.name} ${_sortAsc ? "↑" : "↓"}',
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
                                  child: _buildMarginalia(p, selectedUser),
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
                            _buildMarginalia(p, selectedUser),
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
