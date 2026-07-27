import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/state/sede_session_provider.dart';
import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../domain/models/gym.dart';
import '../gyms_provider.dart';
import '../widgets/gym_pulso_form.dart';

enum _GymFilter { all, active, inactive }

enum _GymSort { code, name, city }

String _location(Gym gym) {
  final parts = [gym.city, gym.state, gym.country]
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
  return parts.isEmpty ? 'Ubicación sin registrar' : parts.join(' · ');
}

String _timezone(Gym gym) {
  final value = gym.timezone?.trim();
  return value == null || value.isEmpty ? 'Etc/UTC' : value;
}

class GymsPulsoView extends ConsumerStatefulWidget {
  const GymsPulsoView({super.key});

  @override
  ConsumerState<GymsPulsoView> createState() => _GymsPulsoViewState();
}

class _GymsPulsoViewState extends ConsumerState<GymsPulsoView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  String? _selectedId;
  _GymFilter _filter = _GymFilter.all;
  _GymSort _sort = _GymSort.code;
  bool _ascending = true;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<Gym> _visible(List<Gym> all) {
    final query = _query.trim().toLowerCase();
    final result = all.where((gym) {
      final haystack =
          '${gym.code} ${gym.name} ${gym.address ?? ''} ${_location(gym)} ${_timezone(gym)}'
              .toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      final matchesFilter = switch (_filter) {
        _GymFilter.all => true,
        _GymFilter.active => gym.active,
        _GymFilter.inactive => !gym.active,
      };
      return matchesQuery && matchesFilter;
    }).toList();
    int compare(Gym a, Gym b) {
      final value = switch (_sort) {
        _GymSort.code => a.code.toLowerCase().compareTo(b.code.toLowerCase()),
        _GymSort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        _GymSort.city => _location(
          a,
        ).toLowerCase().compareTo(_location(b).toLowerCase()),
      };
      return _ascending ? value : -value;
    }

    result.sort(compare);
    return result;
  }

  void _setSort(_GymSort sort) {
    setState(() {
      if (_sort == sort) {
        _ascending = !_ascending;
      } else {
        _sort = sort;
        _ascending = true;
      }
    });
  }

  Future<void> _saveGym(Gym gym, {required bool create}) async {
    final controller = ref.read(gymsControllerProvider.notifier);
    if (create) {
      await controller.createGym(gym);
    } else {
      await controller.updateGym(gym);
    }
    final action = ref.read(gymsControllerProvider);
    if (action.hasError) throw action.error!;
  }

  Future<void> _openForm([Gym? gym]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => GymPulsoForm(
        gym: gym,
        onSubmit: (updated) => _saveGym(updated, create: gym == null),
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          gym == null ? 'Nueva sede creada.' : '“${gym.name}” fue actualizada.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Gym gym) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PulsoThemeScope(
        child: AlertDialog(
          title: const Text('Eliminar gimnasio'),
          content: Text(
            'Se eliminará “${gym.name}” (${gym.code}) y su configuración asociada.',
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
      await ref.read(gymsControllerProvider.notifier).deleteGym(gym.id);
      final action = ref.read(gymsControllerProvider);
      if (action.hasError) throw action.error!;
      if (!mounted) return;
      if (_selectedId == gym.id) setState(() => _selectedId = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('“${gym.name}” fue eliminada.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $error')));
    }
  }

  void _showDetail(Gym gym) {
    final puedeDarDeBaja = ref.read(esDuenoDeCadenaProvider);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => PulsoThemeScope(
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 40,
          ),
          child: SizedBox(
            width: 360,
            height: 520,
            child: _GymDetail(
              gym: gym,
              onEdit: () {
                Navigator.of(dialogContext).pop();
                _openForm(gym);
              },
              onDelete: !puedeDarDeBaja
                  ? null
                  : () {
                      Navigator.of(dialogContext).pop();
                      _confirmDelete(gym);
                    },
              puedeDarDeBaja: puedeDarDeBaja,
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
    final state = ref.watch(gymsListProvider);
    // Alta y baja de sede son del Dueño de la cadena, en escritorio y en web
    // (docs/MULTI_SEDE.md §3). Esconderlos es cortesía: quien manda es el
    // servidor, que responde 403 si la petición llega igualmente.
    final puedeGestionarSedes = ref.watch(esDuenoDeCadenaProvider);
    final all = state.value ?? const <Gym>[];
    final visible = _visible(all);
    final active = all.where((gym) => gym.active).length;
    final configuredZones = all
        .where((gym) => _timezone(gym) != 'Etc/UTC')
        .length;
    final countries = all
        .map((gym) => gym.country?.trim() ?? '')
        .where((country) => country.isNotEmpty)
        .toSet()
        .length;
    Gym? selected;
    for (final gym in all) {
      if (gym.id == _selectedId) selected = gym;
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
              message: 'Cargando la red de gimnasios…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message: 'No se pudo cargar la red de sedes.\n$error',
              onRetry: () => ref.invalidate(gymsListProvider),
            ),
          ),
          data: (_) => visible.isEmpty
              ? PulsoPanel(
                  child: PulsoStateView(
                    kind: PulsoStateKind.empty,
                    message: all.isEmpty
                        ? 'Todavía no hay gimnasios registrados.'
                        : 'Ninguna sede coincide con la búsqueda.',
                  ),
                )
              : _GymWorkspace(
                  items: visible,
                  selected: workspaceWide ? selected : null,
                  sort: _sort,
                  ascending: _ascending,
                  onSort: _setSort,
                  onSelect: (gym) {
                    if (workspaceWide) {
                      setState(() => _selectedId = gym.id);
                    } else {
                      _showDetail(gym);
                    }
                  },
                  onEdit: _openForm,
                  onDelete: _confirmDelete,
                  puedeDarDeBaja: puedeGestionarSedes,
                ),
        );
        final page = Column(
          mainAxisSize: scrollPage ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GymHeader(
              onCreate: puedeGestionarSedes ? () => _openForm() : null,
            ),
            const SizedBox(height: 14),
            PulsoMetricStrip(
              metrics: [
                PulsoMetricData(
                  value: '${all.length}',
                  label: 'Sedes',
                  note: 'en la red',
                  emphasis: true,
                ),
                PulsoMetricData(
                  value: '$active',
                  label: 'Operativas',
                  note: '${all.length - active} inactivas',
                  warning: all.length - active > 0,
                ),
                PulsoMetricData(
                  value: '$configuredZones',
                  label: 'Zonas configuradas',
                  note: configuredZones == all.length
                      ? 'todas localizadas'
                      : '${all.length - configuredZones} en UTC neutral',
                  warning: all.isNotEmpty && configuredZones != all.length,
                ),
                PulsoMetricData(
                  value: '$countries',
                  label: 'Países',
                  note: 'cobertura registrada',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _GymCommand(
              controller: _searchController,
              focusNode: _searchFocus,
              filter: _filter,
              onSearch: (value) => setState(() => _query = value),
              onFilter: (value) => setState(() => _filter = value),
              onRefresh: () => ref.invalidate(gymsListProvider),
            ),
            const SizedBox(height: 12),
            if (scrollPage)
              SizedBox(height: 390, child: catalog)
            else
              Expanded(child: catalog),
            const SizedBox(height: 8),
            const _GymFooter(),
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

class _GymHeader extends StatelessWidget {
  const _GymHeader({required this.onCreate});

  /// Nulo cuando esta cuenta no es Dueño de la cadena: dar de alta una sede es
  /// suyo, y el servidor lo vuelve a comprobar (docs/MULTI_SEDE.md §3).
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PulsoLabel('PULSO · OPERACIÓN'),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                text: 'GIMNASIOS',
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
              'Administra sedes, ubicación y hora comercial de cada gimnasio.',
              style: TextStyle(color: tokens.muted, fontSize: 14),
            ),
          ],
        );
        final onCreate = this.onCreate;
        if (onCreate == null) return copy;
        final action = PulsoPrimaryButton(
          label: 'Nueva sede',
          icon: Icons.add_business_outlined,
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

class _GymCommand extends StatelessWidget {
  const _GymCommand({
    required this.controller,
    required this.focusNode,
    required this.filter,
    required this.onSearch,
    required this.onFilter,
    required this.onRefresh,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final _GymFilter filter;
  final ValueChanged<String> onSearch;
  final ValueChanged<_GymFilter> onFilter;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return PulsoPanel(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            key: const ValueKey('pulso-gym-search'),
            controller: controller,
            focusNode: focusNode,
            onChanged: onSearch,
            decoration: const InputDecoration(
              hintText: 'Buscar sede, código, ciudad o zona horaria…',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          );
          final controls = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _FilterButton(
                label: 'Todas',
                selected: filter == _GymFilter.all,
                onTap: () => onFilter(_GymFilter.all),
              ),
              _FilterButton(
                label: 'Activas',
                selected: filter == _GymFilter.active,
                onTap: () => onFilter(_GymFilter.active),
              ),
              _FilterButton(
                label: 'Inactivas',
                selected: filter == _GymFilter.inactive,
                onTap: () => onFilter(_GymFilter.inactive),
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

class _GymWorkspace extends StatelessWidget {
  const _GymWorkspace({
    required this.items,
    required this.selected,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.puedeDarDeBaja,
  });

  final List<Gym> items;
  final Gym? selected;
  final _GymSort sort;
  final bool ascending;
  final ValueChanged<_GymSort> onSort;
  final ValueChanged<Gym> onSelect;
  final ValueChanged<Gym> onEdit;
  final ValueChanged<Gym> onDelete;
  final bool puedeDarDeBaja;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final list = _GymList(
          items: items,
          selectedId: selected?.id,
          sort: sort,
          ascending: ascending,
          onSort: onSort,
          onSelect: onSelect,
          onEdit: onEdit,
          onDelete: onDelete,
          puedeDarDeBaja: puedeDarDeBaja,
        );
        if (constraints.maxWidth < 1040) return list;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: list),
            const SizedBox(width: 12),
            SizedBox(
              width: 340,
              child: _GymDetail(
                gym: selected,
                onEdit: selected == null ? null : () => onEdit(selected!),
                onDelete: selected == null || !puedeDarDeBaja
                    ? null
                    : () => onDelete(selected!),
                puedeDarDeBaja: puedeDarDeBaja,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GymList extends StatelessWidget {
  const _GymList({
    required this.items,
    required this.selectedId,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.puedeDarDeBaja,
  });

  final List<Gym> items;
  final String? selectedId;
  final _GymSort sort;
  final bool ascending;
  final ValueChanged<_GymSort> onSort;
  final ValueChanged<Gym> onSelect;
  final ValueChanged<Gym> onEdit;
  final ValueChanged<Gym> onDelete;
  final bool puedeDarDeBaja;

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
                      flex: 3,
                      child: _SortButton(
                        label: compact ? 'Sede' : 'Código',
                        active: sort == _GymSort.code,
                        ascending: ascending,
                        onTap: () => onSort(_GymSort.code),
                      ),
                    ),
                    if (!compact) ...[
                      Expanded(
                        flex: 4,
                        child: _SortButton(
                          label: 'Gimnasio',
                          active: sort == _GymSort.name,
                          ascending: ascending,
                          onTap: () => onSort(_GymSort.name),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: _SortButton(
                          label: 'Ubicación',
                          active: sort == _GymSort.city,
                          ascending: ascending,
                          onTap: () => onSort(_GymSort.city),
                        ),
                      ),
                      const Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PulsoLabel('Estado'),
                        ),
                      ),
                      const SizedBox(width: 112),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  key: const PageStorageKey('pulso-gyms-list'),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: tokens.line),
                  itemBuilder: (context, index) {
                    final gym = items[index];
                    return _GymRow(
                      key: ValueKey(gym.id),
                      gym: gym,
                      compact: compact,
                      selected: selectedId == gym.id,
                      onSelect: () => onSelect(gym),
                      onEdit: () => onEdit(gym),
                      onDelete: puedeDarDeBaja ? () => onDelete(gym) : null,
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
                  '${items.length} resultados · sedes y zonas comerciales',
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
    return InkWell(
      onTap: onTap,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulsoLabel(label, color: active ? tokens.accent : null),
            if (active) ...[
              const SizedBox(width: 4),
              Icon(
                ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 13,
                color: tokens.accent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GymRow extends StatelessWidget {
  const _GymRow({
    super.key,
    required this.gym,
    required this.compact,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final Gym gym;
  final bool compact;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  /// Nulo cuando esta cuenta no es Dueño de la cadena: el mando no se enseña.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final code = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      color: selected ? tokens.accentSoftStrong : tokens.raised,
      child: Text(
        gym.code.toUpperCase(),
        style: TextStyle(
          fontFamily: PulsoFonts.mono,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: selected ? tokens.accent : tokens.chalkDim,
        ),
      ),
    );
    return Material(
      color: selected ? tokens.accentSoft : tokens.surface,
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: compact
              ? Row(
                  children: [
                    code,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gym.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.chalk,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _location(gym),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: tokens.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _Status(active: gym.active),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: code,
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        gym.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.chalk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        _location(gym),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: tokens.muted, fontSize: 12),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _Status(active: gym.active),
                      ),
                    ),
                    SizedBox(
                      width: 112,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          PulsoIconButton(
                            icon: Icons.edit_outlined,
                            tooltip: 'Editar ${gym.name}',
                            onPressed: onEdit,
                          ),
                          if (onDelete != null) ...[
                            const SizedBox(width: 6),
                            PulsoIconButton(
                              icon: Icons.delete_outline,
                              tooltip: 'Eliminar ${gym.name}',
                              danger: true,
                              onPressed: onDelete,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = active ? tokens.success : tokens.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: active ? tokens.successSoft : tokens.warningSoft,
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        active ? 'Activa' : 'Inactiva',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _GymDetail extends StatelessWidget {
  const _GymDetail({
    this.gym,
    this.onEdit,
    this.onDelete,
    this.puedeDarDeBaja = true,
  });

  final Gym? gym;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool puedeDarDeBaja;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final gym = this.gym;
    if (gym == null) {
      return const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.empty,
          message: 'Selecciona una sede para consultar su configuración.',
        ),
      );
    }
    final neutralTimezone = _timezone(gym) == 'Etc/UTC';
    return PulsoPanel(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PulsoLabel('DETALLE SELECCIONADO'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              color: tokens.raised,
              child: Column(
                children: [
                  Text(
                    gym.code.toUpperCase(),
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: tokens.accent,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const PulsoLabel('CÓDIGO DE SEDE'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(gym.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            _Status(active: gym.active),
            const SizedBox(height: 18),
            _DetailLine(
              label: 'Dirección',
              value: gym.address ?? 'Sin registrar',
            ),
            _DetailLine(label: 'Ubicación', value: _location(gym)),
            _DetailLine(
              label: 'Código postal',
              value: gym.zipCode ?? 'Sin registrar',
            ),
            _DetailLine(
              label: 'Zona horaria',
              value: _timezone(gym),
              warning: neutralTimezone,
            ),
            if (neutralTimezone) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                color: tokens.warningSoft,
                child: Text(
                  'Etc/UTC es un valor neutral de arranque; configure la zona real de la sede.',
                  style: TextStyle(color: tokens.warning, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 20),
            PulsoPrimaryButton(
              label: 'Editar sede',
              icon: Icons.edit_outlined,
              onPressed: onEdit,
            ),
            if (puedeDarDeBaja) ...[
              const SizedBox(height: 8),
              PulsoSecondaryButton(
                label: 'Eliminar sede',
                danger: true,
                icon: Icons.delete_outline,
                onPressed: onDelete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.warning = false,
  });

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PulsoLabel(label),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: warning ? tokens.warning : tokens.chalkDim,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GymFooter extends StatelessWidget {
  const _GymFooter();

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 12,
      runSpacing: 4,
      children: [
        Text(
          'Ctrl/⌘ + K · buscar',
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: 9,
            color: tokens.muted2,
          ),
        ),
        const PulsoSyncStatus(compact: true),
      ],
    );
  }
}
