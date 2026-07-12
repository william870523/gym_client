import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../clients/presentation/state/client_notifier.dart';
import '../../data/models/horario_model.dart';
import '../state/horario_notifier.dart';
import '../widgets/horario_pulso_form.dart';

enum _ScheduleFilter { all, withClients, withoutClients }

enum _ScheduleSort { start, name, clients }

String _window(HorarioModel horario) =>
    '${horario.horaInicioFormatted} – ${horario.horaFinFormatted}';

String _duration(HorarioModel horario) {
  var minutes = horario.horaFin - horario.horaInicio;
  if (minutes < 0) minutes += 24 * 60; // franja que cruza la medianoche
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest min';
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}

/// Dos franjas del mismo día se solapan si cada una empieza antes de que la
/// otra termine. Las franjas que cruzan la medianoche se excluyen del cálculo.
bool _overlaps(HorarioModel a, HorarioModel b) {
  if (a.horaFin <= a.horaInicio || b.horaFin <= b.horaInicio) return false;
  return a.horaInicio < b.horaFin && b.horaInicio < a.horaFin;
}

/// Socios activos asignados por franja, derivado del catálogo de clientes.
class _ScheduleStats {
  const _ScheduleStats({required this.ready, required this.counts});

  /// `false` mientras el catálogo de clientes no ha cargado: los conteos se
  /// muestran como «—» en lugar de un cero engañoso.
  final bool ready;
  final Map<String, int> counts;

  int of(HorarioModel horario) => counts[horario.id] ?? 0;

  int get assignedTotal =>
      counts.values.fold(0, (total, value) => total + value);
}

class HorariosPulsoView extends ConsumerStatefulWidget {
  const HorariosPulsoView({super.key});

  @override
  ConsumerState<HorariosPulsoView> createState() => _HorariosPulsoViewState();
}

class _HorariosPulsoViewState extends ConsumerState<HorariosPulsoView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  String? _selectedId;
  _ScheduleFilter _filter = _ScheduleFilter.all;
  _ScheduleSort _sort = _ScheduleSort.start;
  bool _ascending = true;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<HorarioModel> _visible(List<HorarioModel> all, _ScheduleStats stats) {
    final query = _query.trim().toLowerCase();
    final result = all.where((horario) {
      final haystack = '${horario.nombre} ${_window(horario)}'.toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      final matchesFilter = switch (_filter) {
        _ScheduleFilter.all => true,
        _ScheduleFilter.withClients => stats.of(horario) > 0,
        _ScheduleFilter.withoutClients => stats.of(horario) == 0,
      };
      return matchesQuery && matchesFilter;
    }).toList();
    int compare(HorarioModel a, HorarioModel b) {
      final value = switch (_sort) {
        _ScheduleSort.start => a.horaInicio.compareTo(b.horaInicio),
        _ScheduleSort.name => a.nombre.toLowerCase().compareTo(
          b.nombre.toLowerCase(),
        ),
        _ScheduleSort.clients => stats.of(a).compareTo(stats.of(b)),
      };
      return _ascending ? value : -value;
    }

    result.sort(compare);
    return result;
  }

  void _setSort(_ScheduleSort sort) {
    setState(() {
      if (_sort == sort) {
        _ascending = !_ascending;
      } else {
        _sort = sort;
        // Por socios interesa primero la franja más concurrida.
        _ascending = sort != _ScheduleSort.clients;
      }
    });
  }

  Future<void> _openForm([HorarioModel? horario]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => HorarioPulsoForm(
        horario: horario,
        onSubmit: (nombre, horaInicio, horaFin) async {
          final notifier = ref.read(horarioNotifierProvider.notifier);
          if (horario == null) {
            await notifier.create(
              nombre: nombre,
              horaInicio: horaInicio,
              horaFin: horaFin,
            );
          } else {
            await notifier.updateHorario(
              horario.copyWith(
                nombre: nombre,
                horaInicio: horaInicio,
                horaFin: horaFin,
              ),
            );
          }
        },
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          horario == null
              ? 'Nuevo horario creado.'
              : '“${horario.nombre}” fue actualizado.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    HorarioModel horario,
    _ScheduleStats stats,
  ) async {
    final tokens = PulsoTokens.of(context);
    final count = stats.of(horario);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PulsoThemeScope(
        child: AlertDialog(
          title: const Text('Eliminar horario'),
          content: Text(
            stats.ready && count > 0
                ? 'Se eliminará “${horario.nombre}”. Hay $count socio${count == 1 ? '' : 's'} '
                      'asignado${count == 1 ? '' : 's'} a esta franja; sus expedientes no se modifican.'
                : 'Se eliminará “${horario.nombre}” (${_window(horario)}) del catálogo.',
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
      await ref.read(horarioNotifierProvider.notifier).delete(horario.id);
      if (!mounted) return;
      if (_selectedId == horario.id) setState(() => _selectedId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“${horario.nombre}” fue eliminado.')),
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

  _ScheduleStats _buildStats(List<HorarioModel> all) {
    final clients = ref.watch(clientNotifierProvider).value;
    if (clients == null) {
      return const _ScheduleStats(ready: false, counts: {});
    }
    final ids = {for (final horario in all) horario.id};
    final counts = <String, int>{};
    for (final client in clients) {
      final scheduleId = client.scheduleId;
      if (!client.activo || scheduleId == null || !ids.contains(scheduleId)) {
        continue;
      }
      counts[scheduleId] = (counts[scheduleId] ?? 0) + 1;
    }
    return _ScheduleStats(ready: true, counts: counts);
  }

  void _showDetail(
    BuildContext context,
    HorarioModel horario,
    List<HorarioModel> all,
    _ScheduleStats stats,
  ) {
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
            height: 560,
            child: _ScheduleDetail(
              horario: horario,
              all: all,
              stats: stats,
              onEdit: () {
                Navigator.of(dialogContext).pop();
                _openForm(horario);
              },
              onDelete: () {
                Navigator.of(dialogContext).pop();
                _confirmDelete(horario, stats);
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
    final state = ref.watch(horarioNotifierProvider);
    final all = state.value ?? const <HorarioModel>[];
    final stats = _buildStats(all);
    final visible = _visible(all, stats);
    final empty = stats.ready
        ? all.where((horario) => stats.of(horario) == 0).length
        : null;
    HorarioModel? peak;
    for (final horario in all) {
      if (stats.of(horario) == 0) continue;
      if (peak == null || stats.of(horario) > stats.of(peak)) peak = horario;
    }
    HorarioModel? selected;
    for (final horario in all) {
      if (horario.id == _selectedId) selected = horario;
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
              message: 'Cargando los horarios…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message: 'No se pudo cargar el catálogo.\n$error',
              onRetry: () => ref.invalidate(horarioNotifierProvider),
            ),
          ),
          data: (_) => visible.isEmpty
              ? PulsoPanel(
                  child: PulsoStateView(
                    kind: PulsoStateKind.empty,
                    message: all.isEmpty
                        ? 'Todavía no hay horarios registrados.'
                        : 'Ninguna franja coincide con la búsqueda.',
                  ),
                )
              : _ScheduleWorkspace(
                  items: visible,
                  all: all,
                  stats: stats,
                  selected: workspaceWide ? selected : null,
                  sort: _sort,
                  ascending: _ascending,
                  onSort: _setSort,
                  onSelect: (horario) {
                    if (workspaceWide) {
                      setState(() => _selectedId = horario.id);
                    } else {
                      _showDetail(context, horario, all, stats);
                    }
                  },
                  onEdit: _openForm,
                  onDelete: (horario) => _confirmDelete(horario, stats),
                ),
        );
        final page = Column(
          mainAxisSize: scrollPage ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ScheduleHeader(onCreate: () => _openForm()),
            const SizedBox(height: 14),
            PulsoMetricStrip(
              metrics: [
                PulsoMetricData(
                  value: '${all.length}',
                  label: 'Franjas',
                  note: 'horarios del gimnasio',
                  emphasis: true,
                ),
                PulsoMetricData(
                  value: stats.ready ? '${stats.assignedTotal}' : '—',
                  label: 'Socios asignados',
                  note: 'con franja definida',
                ),
                PulsoMetricData(
                  value: empty == null ? '—' : '$empty',
                  label: 'Franjas vacías',
                  note: 'sin socios asignados',
                  warning: (empty ?? 0) > 0,
                ),
                PulsoMetricData(
                  value: peak == null ? '—' : '${stats.of(peak)}',
                  label: 'Franja pico',
                  note: peak?.nombre ?? 'sin datos todavía',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ScheduleCommand(
              controller: _searchController,
              focusNode: _searchFocus,
              filter: _filter,
              onSearch: (value) => setState(() => _query = value),
              onFilter: (value) => setState(() => _filter = value),
              onRefresh: () => ref.invalidate(horarioNotifierProvider),
            ),
            const SizedBox(height: 12),
            if (scrollPage)
              SizedBox(height: 360, child: catalog)
            else
              Expanded(child: catalog),
            const SizedBox(height: 8),
            const _ScheduleFooter(),
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

class _ScheduleHeader extends StatelessWidget {
  const _ScheduleHeader({required this.onCreate});
  final VoidCallback onCreate;

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
                text: 'HORARIOS',
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
              'Organiza las franjas de llegada y mide cuántos socios sostiene cada una.',
              style: TextStyle(color: tokens.muted, fontSize: 14),
            ),
          ],
        );
        final action = PulsoPrimaryButton(
          label: 'Nuevo horario',
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

class _ScheduleCommand extends StatelessWidget {
  const _ScheduleCommand({
    required this.controller,
    required this.focusNode,
    required this.filter,
    required this.onSearch,
    required this.onFilter,
    required this.onRefresh,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final _ScheduleFilter filter;
  final ValueChanged<String> onSearch;
  final ValueChanged<_ScheduleFilter> onFilter;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return PulsoPanel(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            key: const ValueKey('pulso-horario-search'),
            controller: controller,
            focusNode: focusNode,
            onChanged: onSearch,
            decoration: const InputDecoration(
              hintText: 'Buscar franja u hora…',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          );
          final controls = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _FilterButton(
                label: 'Todas',
                selected: filter == _ScheduleFilter.all,
                onTap: () => onFilter(_ScheduleFilter.all),
              ),
              _FilterButton(
                label: 'Con socios',
                selected: filter == _ScheduleFilter.withClients,
                onTap: () => onFilter(_ScheduleFilter.withClients),
              ),
              _FilterButton(
                label: 'Vacías',
                selected: filter == _ScheduleFilter.withoutClients,
                onTap: () => onFilter(_ScheduleFilter.withoutClients),
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

class _ScheduleWorkspace extends StatelessWidget {
  const _ScheduleWorkspace({
    required this.items,
    required this.all,
    required this.stats,
    required this.selected,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });
  final List<HorarioModel> items;
  final List<HorarioModel> all;
  final _ScheduleStats stats;
  final HorarioModel? selected;
  final _ScheduleSort sort;
  final bool ascending;
  final ValueChanged<_ScheduleSort> onSort;
  final ValueChanged<HorarioModel> onSelect;
  final ValueChanged<HorarioModel> onEdit;
  final ValueChanged<HorarioModel> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final list = _ScheduleList(
          items: items,
          all: all,
          stats: stats,
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
              child: _ScheduleDetail(
                horario: selected,
                all: all,
                stats: stats,
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

class _ScheduleList extends StatelessWidget {
  const _ScheduleList({
    required this.items,
    required this.all,
    required this.stats,
    required this.selectedId,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });
  final List<HorarioModel> items;
  final List<HorarioModel> all;
  final _ScheduleStats stats;
  final String? selectedId;
  final _ScheduleSort sort;
  final bool ascending;
  final ValueChanged<_ScheduleSort> onSort;
  final ValueChanged<HorarioModel> onSelect;
  final ValueChanged<HorarioModel> onEdit;
  final ValueChanged<HorarioModel> onDelete;

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
                        label: 'Franja',
                        active: sort == _ScheduleSort.name,
                        ascending: ascending,
                        onTap: () => onSort(_ScheduleSort.name),
                      ),
                    ),
                    if (!compact) ...[
                      Expanded(
                        flex: 3,
                        child: _SortButton(
                          label: 'Ventana',
                          active: sort == _ScheduleSort.start,
                          ascending: ascending,
                          onTap: () => onSort(_ScheduleSort.start),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _SortButton(
                          label: 'Socios',
                          active: sort == _ScheduleSort.clients,
                          ascending: ascending,
                          onTap: () => onSort(_ScheduleSort.clients),
                        ),
                      ),
                      const SizedBox(width: 100),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  key: const PageStorageKey('pulso-horarios-list'),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: tokens.line),
                  itemBuilder: (context, index) {
                    final horario = items[index];
                    final overlapping = all.any(
                      (other) =>
                          other.id != horario.id &&
                          _overlaps(horario, other),
                    );
                    return _ScheduleRow(
                      key: ValueKey(horario.id),
                      horario: horario,
                      stats: stats,
                      overlapping: overlapping,
                      selected: selectedId == horario.id,
                      compact: compact,
                      onSelect: () => onSelect(horario),
                      onEdit: () => onEdit(horario),
                      onDelete: () => onDelete(horario),
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
                  '${items.length} resultados · socios activos por franja',
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

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    super.key,
    required this.horario,
    required this.stats,
    required this.overlapping,
    required this.selected,
    required this.compact,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });
  final HorarioModel horario;
  final _ScheduleStats stats;
  final bool overlapping;
  final bool selected;
  final bool compact;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final count = stats.of(horario);
    final hasClients = stats.ready && count > 0;
    final membersLabel = !stats.ready
        ? '—'
        : count == 0
        ? 'sin socios'
        : count == 1
        ? '1 socio'
        : '$count socios';
    final membersColor = !stats.ready
        ? tokens.muted
        : count == 0
        ? tokens.warning
        : tokens.success;
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
              Container(
                width: 36,
                height: 36,
                color: hasClients ? tokens.successSoft : tokens.raised,
                child: Icon(
                  Icons.schedule_outlined,
                  size: 18,
                  color: hasClients ? tokens.success : tokens.muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      horario.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: tokens.chalk,
                      ),
                    ),
                    if (compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${_window(horario)} · $membersLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 9.5,
                          color: membersColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!compact) ...[
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _window(horario),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: PulsoFonts.mono,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: tokens.chalkDim,
                          ),
                        ),
                      ),
                      if (overlapping) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Se solapa con otra franja',
                          child: Icon(
                            Icons.layers_outlined,
                            size: 14,
                            color: tokens.warning,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    membersLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontWeight: FontWeight.w600,
                      color: membersColor,
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      PulsoIconButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Editar ${horario.nombre}',
                        onPressed: onEdit,
                      ),
                      const SizedBox(width: 4),
                      PulsoIconButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Eliminar ${horario.nombre}',
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

class _ScheduleDetail extends StatelessWidget {
  const _ScheduleDetail({
    required this.horario,
    required this.all,
    required this.stats,
    required this.onEdit,
    required this.onDelete,
  });
  final HorarioModel? horario;
  final List<HorarioModel> all;
  final _ScheduleStats stats;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final selected = horario;
    if (selected == null) {
      return const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.empty,
          message: 'Selecciona una franja para ver su detalle.',
        ),
      );
    }
    final count = stats.of(selected);
    final total = stats.assignedTotal;
    final share = !stats.ready || total == 0
        ? '—'
        : '${(count * 100 / total).round()} %';
    final overlaps = [
      for (final other in all)
        if (other.id != selected.id && _overlaps(selected, other))
          other.nombre,
    ];
    return PulsoPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PulsoLabel('Detalle seleccionado'),
          const SizedBox(height: 12),
          Text(
            stats.ready ? '$count' : '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.display,
              fontSize: 48,
              height: 0.9,
              fontWeight: FontWeight.w800,
              color: tokens.accent,
            ),
          ),
          const SizedBox(height: 4),
          const PulsoLabel('Socios asignados'),
          const SizedBox(height: 9),
          Text(selected.nombre, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _DetailLine(label: 'Ventana', value: _window(selected)),
          _DetailLine(label: 'Duración', value: _duration(selected)),
          _DetailLine(label: 'Participación', value: share),
          _DetailLine(
            label: 'Solapa con',
            value: overlaps.isEmpty ? '—' : overlaps.join(', '),
            warning: overlaps.isNotEmpty,
          ),
          const Spacer(),
          PulsoPrimaryButton(
            label: 'Editar horario',
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
                color: warning ? tokens.warning : tokens.chalkDim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleFooter extends StatelessWidget {
  const _ScheduleFooter();
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Row(
      children: [
        const PulsoSyncStatus(compact: true),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'PULSO · HORARIOS · DATOS REALES',
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
