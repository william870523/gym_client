import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../auth/domain/models/user.dart';
import '../providers/users_provider.dart';
import '../widgets/user_pulso_form.dart';

enum _UserFilter { all, active, inactive }

enum _UserSort { name, role }

String _displayName(User user) =>
    user.name.trim().isNotEmpty ? user.name.trim() : user.email.trim();

String _roleLabel(User user) {
  return switch (user.role.toLowerCase()) {
    'admin' || 'administrador' => 'Administrador',
    'trainer' || 'entrenador' => 'Entrenador',
    'reception' || 'recepcion' || 'recepción' => 'Recepción',
    'maintenance' || 'mantenimiento' => 'Mantenimiento',
    _ => user.role.isEmpty ? 'Sin rol' : user.role,
  };
}

bool _isAdmin(User user) {
  final role = user.role.toLowerCase();
  return role == 'admin' || role == 'administrador';
}

String _coverage(User user) {
  final gymId = user.gymId?.trim();
  if (gymId != null && gymId.isNotEmpty) {
    final shortId = gymId.length > 8 ? gymId.substring(0, 8) : gymId;
    return 'Gym $shortId';
  }
  return 'Acceso global';
}

String _initials(User user) {
  final source = _displayName(user);
  if (source.isEmpty) return '?';
  return source
      .split(' ')
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
}

class UsersPulsoView extends ConsumerStatefulWidget {
  const UsersPulsoView({super.key});

  @override
  ConsumerState<UsersPulsoView> createState() => _UsersPulsoViewState();
}

class _UsersPulsoViewState extends ConsumerState<UsersPulsoView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  String? _selectedId;
  _UserFilter _filter = _UserFilter.all;
  _UserSort _sort = _UserSort.name;
  bool _ascending = true;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<User> _visible(List<User> all) {
    final query = _query.trim().toLowerCase();
    final result = all.where((user) {
      final haystack =
          '${_displayName(user)} ${user.email} ${_roleLabel(user)} ${_coverage(user)}'
              .toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      final matchesFilter = switch (_filter) {
        _UserFilter.all => true,
        _UserFilter.active => user.active,
        _UserFilter.inactive => !user.active,
      };
      return matchesQuery && matchesFilter;
    }).toList();
    int compare(User a, User b) {
      final value = switch (_sort) {
        _UserSort.name => _displayName(
          a,
        ).toLowerCase().compareTo(_displayName(b).toLowerCase()),
        _UserSort.role => _roleLabel(
          a,
        ).toLowerCase().compareTo(_roleLabel(b).toLowerCase()),
      };
      return _ascending ? value : -value;
    }

    result.sort(compare);
    return result;
  }

  void _setSort(_UserSort sort) {
    setState(() {
      if (_sort == sort) {
        _ascending = !_ascending;
      } else {
        _sort = sort;
        _ascending = true;
      }
    });
  }

  /// Formulario PULSO en diálogo dentro del shell (nunca una ruta a pantalla
  /// completa que tape la navegación de la aplicación).
  Future<void> _openForm([User? user]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UserPulsoForm(
        user: user,
        onSubmit: (updated) async {
          final notifier = ref.read(usersProvider.notifier);
          if (user == null) {
            await notifier.createUser(updated);
          } else {
            await notifier.updateUser(updated);
          }
        },
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          user == null
              ? 'Nuevo usuario creado.'
              : '“${_displayName(user)}” fue actualizado.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(User user) async {
    final tokens = PulsoTokens.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PulsoThemeScope(
        child: AlertDialog(
          title: const Text('Eliminar usuario'),
          content: Text(
            'Se eliminará a “${_displayName(user)}” (${_roleLabel(user)}) '
            'y sus accesos asociados.',
          ),
          actions: [
            PulsoSecondaryButton(
              label: 'Cancelar',
              onPressed: () => Navigator.of(context).pop(false),
            ),
            PulsoSecondaryButton(
              label: 'Eliminar',
              danger: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(usersProvider.notifier).deleteUser(user.id);
      if (!mounted) return;
      if (_selectedId == user.id) setState(() => _selectedId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“${_displayName(user)}” fue eliminado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: tokens.danger,
          content: Text('No se pudo eliminar: $error'),
        ),
      );
    }
  }

  void _showDetail(BuildContext context, User user) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => PulsoThemeScope(
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 40,
          ),
          child: SizedBox(
            width: 340,
            height: 520,
            child: _UserDetail(
              user: user,
              onEdit: () {
                Navigator.of(dialogContext).pop();
                _openForm(user);
              },
              onDelete: () {
                Navigator.of(dialogContext).pop();
                _confirmDelete(user);
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PulsoThemeScope(
      child: Builder(
        builder: (context) => ColoredBox(
          color: PulsoTokens.of(context).floor,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                  _searchFocus.requestFocus,
              const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                  _searchFocus.requestFocus,
            },
            child: Focus(autofocus: true, child: _buildPage(context)),
          ),
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context) {
    final state = ref.watch(usersProvider);
    final all = state.value ?? const <User>[];
    final visible = _visible(all);
    final active = all.where((user) => user.active).length;
    final admins = all.where((user) => user.active && _isAdmin(user)).length;
    final reception = all
        .where(
          (user) =>
              user.active && _roleLabel(user).toLowerCase() == 'recepción',
        )
        .length;
    User? selected;
    for (final user in all) {
      if (user.id == _selectedId) selected = user;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final scrollPage = compact || constraints.maxHeight < 760;
        final padding = compact
            ? 16.0
            : constraints.maxWidth < 840
            ? 24.0
            : 32.0;
        final workspaceWide = constraints.maxWidth - (padding * 2) >= 1040;
        final catalog = state.when(
          loading: () => const PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.loading,
              message: 'Cargando el registro de usuarios…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message: 'No se pudo cargar el registro.\n$error',
              onRetry: () => ref.invalidate(usersProvider),
            ),
          ),
          data: (_) => visible.isEmpty
              ? PulsoPanel(
                  child: PulsoStateView(
                    kind: PulsoStateKind.empty,
                    message: all.isEmpty
                        ? 'Todavía no hay usuarios registrados.'
                        : 'Ningún usuario coincide con la búsqueda.',
                  ),
                )
              : _UserWorkspace(
                  items: visible,
                  selected: workspaceWide ? selected : null,
                  sort: _sort,
                  ascending: _ascending,
                  onSort: _setSort,
                  onSelect: (user) {
                    if (workspaceWide) {
                      setState(() => _selectedId = user.id);
                    } else {
                      _showDetail(context, user);
                    }
                  },
                  onEdit: _openForm,
                  onDelete: _confirmDelete,
                ),
        );
        final page = Column(
          mainAxisSize: scrollPage ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _UserHeader(onCreate: () => _openForm()),
            const SizedBox(height: 14),
            PulsoMetricStrip(
              metrics: [
                PulsoMetricData(
                  value: '${all.length}',
                  label: 'Usuarios',
                  note: 'cuentas del sistema',
                  emphasis: true,
                ),
                PulsoMetricData(
                  value: '$active',
                  label: 'Activos',
                  note: '${all.length - active} inactivos',
                  warning: all.length - active > 0,
                ),
                PulsoMetricData(
                  value: '$admins',
                  label: 'Administradores',
                  note: admins == 0
                      ? 'ninguno activo — atención'
                      : 'con control total',
                  // Sin administrador activo nadie puede gestionar el sistema.
                  warning: all.isNotEmpty && admins == 0,
                ),
                PulsoMetricData(
                  value: '$reception',
                  label: 'Recepción',
                  note: 'operan el mostrador',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _UserCommand(
              controller: _searchController,
              focusNode: _searchFocus,
              filter: _filter,
              onSearch: (value) => setState(() => _query = value),
              onFilter: (value) => setState(() => _filter = value),
              onRefresh: () => ref.invalidate(usersProvider),
            ),
            const SizedBox(height: 12),
            if (scrollPage)
              SizedBox(height: 360, child: catalog)
            else
              Expanded(child: catalog),
            const SizedBox(height: 8),
            const _UserFooter(),
          ],
        );
        final insets = EdgeInsets.fromLTRB(
          padding,
          compact ? 16 : 20,
          padding,
          compact ? 18 : 24,
        );
        return scrollPage
            ? SingleChildScrollView(padding: insets, child: page)
            : Padding(padding: insets, child: page);
      },
    );
  }
}

class _UserHeader extends StatelessWidget {
  const _UserHeader({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PulsoLabel('PULSO · EQUIPO'),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                text: 'USUARIOS',
                children: [
                  TextSpan(
                    text: '.',
                    style: TextStyle(color: tokens.accent),
                  ),
                ],
              ),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Controla quién entra al sistema y con qué rol opera.',
              style: TextStyle(color: tokens.muted, fontSize: 14),
            ),
          ],
        );
        final action = PulsoPrimaryButton(
          label: 'Nuevo usuario',
          icon: Icons.add,
          onPressed: onCreate,
        );
        return constraints.maxWidth < 680
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, const SizedBox(height: 14), action],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 24),
                  action,
                ],
              );
      },
    );
  }
}

class _UserCommand extends StatelessWidget {
  const _UserCommand({
    required this.controller,
    required this.focusNode,
    required this.filter,
    required this.onSearch,
    required this.onFilter,
    required this.onRefresh,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final _UserFilter filter;
  final ValueChanged<String> onSearch;
  final ValueChanged<_UserFilter> onFilter;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return PulsoPanel(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            key: const ValueKey('pulso-user-search'),
            controller: controller,
            focusNode: focusNode,
            onChanged: onSearch,
            decoration: const InputDecoration(
              hintText: 'Buscar nombre, correo o rol…',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          );
          final controls = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _FilterButton(
                label: 'Todos',
                selected: filter == _UserFilter.all,
                onTap: () => onFilter(_UserFilter.all),
              ),
              _FilterButton(
                label: 'Activos',
                selected: filter == _UserFilter.active,
                onTap: () => onFilter(_UserFilter.active),
              ),
              _FilterButton(
                label: 'Inactivos',
                selected: filter == _UserFilter.inactive,
                onTap: () => onFilter(_UserFilter.inactive),
              ),
              PulsoIconButton(
                icon: Icons.refresh,
                tooltip: 'Actualizar',
                onPressed: onRefresh,
              ),
            ],
          );
          return constraints.maxWidth < 780
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [search, const SizedBox(height: 8), controls],
                )
              : Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 10),
                    controls,
                  ],
                );
        },
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Material(
      color: selected ? tokens.accentSoft : tokens.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? tokens.accent : tokens.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? tokens.chalk : tokens.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user, this.size = 36});
  final User user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final admin = _isAdmin(user);
    return Container(
      width: size,
      height: size,
      color: admin ? tokens.accentSoft : tokens.raised,
      child: Center(
        child: Text(
          _initials(user),
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: size * 0.32,
            fontWeight: FontWeight.w600,
            color: admin ? tokens.accent : tokens.muted,
          ),
        ),
      ),
    );
  }
}

class _UserWorkspace extends StatelessWidget {
  const _UserWorkspace({
    required this.items,
    required this.selected,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });
  final List<User> items;
  final User? selected;
  final _UserSort sort;
  final bool ascending;
  final ValueChanged<_UserSort> onSort;
  final ValueChanged<User> onSelect;
  final ValueChanged<User> onEdit;
  final ValueChanged<User> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final list = _UserList(
          items: items,
          selectedId: selected?.id,
          sort: sort,
          ascending: ascending,
          onSort: onSort,
          onSelect: onSelect,
          onEdit: onEdit,
          onDelete: onDelete,
        );
        if (constraints.maxWidth < 1040) return list;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: list),
            const SizedBox(width: 12),
            SizedBox(
              width: 330,
              child: _UserDetail(
                user: selected,
                onEdit: selected == null ? null : () => onEdit(selected!),
                onDelete: selected == null ? null : () => onDelete(selected!),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UserList extends StatelessWidget {
  const _UserList({
    required this.items,
    required this.selectedId,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });
  final List<User> items;
  final String? selectedId;
  final _UserSort sort;
  final bool ascending;
  final ValueChanged<_UserSort> onSort;
  final ValueChanged<User> onSelect;
  final ValueChanged<User> onEdit;
  final ValueChanged<User> onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 46),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: tokens.line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _SortButton(
                        label: 'Usuario',
                        active: sort == _UserSort.name,
                        ascending: ascending,
                        onTap: () => onSort(_UserSort.name),
                      ),
                    ),
                    if (!compact) ...[
                      Expanded(
                        flex: 2,
                        child: _SortButton(
                          label: 'Rol',
                          active: sort == _UserSort.role,
                          ascending: ascending,
                          onTap: () => onSort(_UserSort.role),
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PulsoLabel('Cobertura'),
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PulsoLabel('Estado'),
                        ),
                      ),
                      const SizedBox(width: 100),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  key: const PageStorageKey('pulso-users-list'),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: tokens.line),
                  itemBuilder: (context, index) {
                    final user = items[index];
                    return _UserRow(
                      key: ValueKey(user.id),
                      user: user,
                      selected: selectedId == user.id,
                      compact: compact,
                      onSelect: () => onSelect(user),
                      onEdit: () => onEdit(user),
                      onDelete: () => onDelete(user),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: tokens.line)),
                ),
                child: Text(
                  '${items.length} resultados · cuentas y roles del sistema',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 9,
                    color: tokens.muted2,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
  });
  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.zero,
        foregroundColor: active ? tokens.accent : tokens.muted,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: PulsoLabel(label, color: active ? tokens.accent : null),
          ),
          if (active) ...[
            const SizedBox(width: 4),
            Icon(
              ascending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 12,
            ),
          ],
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    super.key,
    required this.user,
    required this.selected,
    required this.compact,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });
  final User user;
  final bool selected;
  final bool compact;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final name = _displayName(user);
    return Material(
      color: selected ? tokens.accentSoftStrong : Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? tokens.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              _UserAvatar(user: user),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: user.active ? tokens.chalk : tokens.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      compact
                          ? '${_roleLabel(user)} · ${user.active ? 'activo' : 'inactivo'}'
                          : user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: PulsoFonts.mono,
                        fontSize: 9.5,
                        color: tokens.muted2,
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                Expanded(
                  flex: 2,
                  child: Text(
                    _roleLabel(user),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontWeight: FontWeight.w600,
                      color: _isAdmin(user) ? tokens.accent : tokens.chalkDim,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _coverage(user),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 11,
                      color: tokens.muted,
                    ),
                  ),
                ),
                Expanded(flex: 2, child: _UserStatus(active: user.active)),
                SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      PulsoIconButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Editar $name',
                        onPressed: onEdit,
                      ),
                      const SizedBox(width: 4),
                      PulsoIconButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Eliminar $name',
                        danger: true,
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ),
              ] else
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserStatus extends StatelessWidget {
  const _UserStatus({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = active ? tokens.success : tokens.warning;
    return Row(
      children: [
        Container(width: 6, height: 6, color: color),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            active ? 'ACTIVO' : 'INACTIVO',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _UserDetail extends StatelessWidget {
  const _UserDetail({
    required this.user,
    required this.onEdit,
    required this.onDelete,
  });
  final User? user;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final selected = user;
    if (selected == null) {
      return const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.empty,
          message: 'Selecciona un usuario para ver su detalle.',
        ),
      );
    }
    return PulsoPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PulsoLabel('Detalle seleccionado'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _roleLabel(selected).toUpperCase(),
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: PulsoFonts.display,
                      fontSize: 40,
                      height: 0.9,
                      fontWeight: FontWeight.w800,
                      color: tokens.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _UserAvatar(user: selected, size: 48),
            ],
          ),
          const SizedBox(height: 4),
          const PulsoLabel('Rol en el sistema'),
          const SizedBox(height: 9),
          Text(
            _displayName(selected),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            selected.active ? 'ACTIVO' : 'INACTIVO',
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: selected.active ? tokens.success : tokens.warning,
            ),
          ),
          const SizedBox(height: 12),
          _DetailLine(label: 'Correo', value: selected.email),
          _DetailLine(label: 'Cobertura', value: _coverage(selected)),
          _DetailLine(
            label: 'Permisos',
            value: selected.permissions.isEmpty
                ? 'según rol'
                : '${selected.permissions.length}',
          ),
          const Spacer(),
          PulsoPrimaryButton(
            label: 'Editar usuario',
            icon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
          const SizedBox(height: 8),
          PulsoSecondaryButton(
            label: 'Eliminar',
            icon: Icons.delete_outline,
            danger: true,
            onPressed: onDelete,
          ),
          const SizedBox(height: 14),
          Text(
            selected.id,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              color: tokens.muted2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: [
          Expanded(child: PulsoLabel(label)),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontWeight: FontWeight.w600,
                color: tokens.chalkDim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserFooter extends StatelessWidget {
  const _UserFooter();
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Row(
      children: [
        const PulsoSyncStatus(compact: true),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'PULSO · USUARIOS · DATOS REALES',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              color: tokens.muted2,
            ),
          ),
        ),
      ],
    );
  }
}
