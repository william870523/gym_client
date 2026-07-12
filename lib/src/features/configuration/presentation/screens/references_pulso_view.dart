import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../clients/presentation/state/client_notifier.dart';
import '../../data/models/reference_model.dart';
import '../providers/reference_notifier.dart';
import '../widgets/reference_pulso_form.dart';

enum _ReferenceFilter { all, withClients, withoutClients }

enum _ReferenceSort { name, clients }

/// Resumen de captación por canal, derivado del catálogo de clientes.
class _ReferenceStats {
  const _ReferenceStats({required this.ready, required this.counts});

  /// `false` mientras el catálogo de clientes no ha cargado: los conteos se
  /// muestran como «—» en lugar de un cero engañoso.
  final bool ready;
  final Map<String, int> counts;

  int of(ReferenceModel item) => counts[item.id] ?? 0;

  int get referredTotal =>
      counts.values.fold(0, (total, value) => total + value);
}

class ReferencesPulsoView extends ConsumerStatefulWidget {
  const ReferencesPulsoView({super.key});

  @override
  ConsumerState<ReferencesPulsoView> createState() =>
      _ReferencesPulsoViewState();
}

class _ReferencesPulsoViewState extends ConsumerState<ReferencesPulsoView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  String? _selectedId;
  _ReferenceFilter _filter = _ReferenceFilter.all;
  _ReferenceSort _sort = _ReferenceSort.name;
  bool _ascending = true;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<ReferenceModel> _visible(
    List<ReferenceModel> all,
    _ReferenceStats stats,
  ) {
    final query = _query.trim().toLowerCase();
    final result = all.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.nombre.toLowerCase().contains(query) ||
          item.id.toLowerCase().contains(query);
      final matchesFilter = switch (_filter) {
        _ReferenceFilter.all => true,
        _ReferenceFilter.withClients => stats.of(item) > 0,
        _ReferenceFilter.withoutClients => stats.of(item) == 0,
      };
      return matchesQuery && matchesFilter;
    }).toList();
    int compare(ReferenceModel a, ReferenceModel b) {
      final value = switch (_sort) {
        _ReferenceSort.name => a.nombre.toLowerCase().compareTo(
          b.nombre.toLowerCase(),
        ),
        _ReferenceSort.clients => stats.of(a).compareTo(stats.of(b)),
      };
      return _ascending ? value : -value;
    }

    result.sort(compare);
    return result;
  }

  void _setSort(_ReferenceSort sort) {
    setState(() {
      if (_sort == sort) {
        _ascending = !_ascending;
      } else {
        _sort = sort;
        // Por socios captados interesa primero el canal que más trae.
        _ascending = sort != _ReferenceSort.clients;
      }
    });
  }

  Future<void> _openForm([ReferenceModel? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReferencePulsoForm(
        id: item?.id,
        initialName: item?.nombre,
        onSubmit: (name) async {
          final notifier = ref.read(referenceProvider.notifier);
          if (item == null) {
            await notifier.create(name);
          } else {
            await notifier.updateReference(item.id, name);
          }
        },
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          item == null
              ? 'Nueva referencia creada.'
              : '“${item.nombre}” fue actualizada.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(ReferenceModel item) async {
    final tokens = PulsoTokens.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PulsoThemeScope(
        child: AlertDialog(
          title: const Text('Eliminar referencia'),
          content: Text(
            'Se eliminará “${item.nombre}” del catálogo de canales. '
            'Los socios ya captados conservan su expediente.',
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
      await ref.read(referenceProvider.notifier).deleteReference(item.id);
      if (!mounted) return;
      if (_selectedId == item.id) setState(() => _selectedId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“${item.nombre}” fue eliminada.')),
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

  void _showDetail(
    BuildContext context,
    ReferenceModel item,
    _ReferenceStats stats,
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
            height: 500,
            child: _ReferenceDetail(
              item: item,
              stats: stats,
              onEdit: () {
                Navigator.of(dialogContext).pop();
                _openForm(item);
              },
              onDelete: () {
                Navigator.of(dialogContext).pop();
                _confirmDelete(item);
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

  _ReferenceStats _buildStats(List<ReferenceModel> all) {
    final clients = ref.watch(clientNotifierProvider).value;
    if (clients == null) {
      return const _ReferenceStats(ready: false, counts: {});
    }
    final ids = {for (final item in all) item.id};
    final counts = <String, int>{};
    for (final client in clients) {
      final referralId = client.referralId;
      if (referralId == null || !ids.contains(referralId)) continue;
      counts[referralId] = (counts[referralId] ?? 0) + 1;
    }
    return _ReferenceStats(ready: true, counts: counts);
  }

  Widget _buildPage(BuildContext context) {
    final state = ref.watch(referenceProvider);
    final all = state.value ?? const <ReferenceModel>[];
    final stats = _buildStats(all);
    final visible = _visible(all, stats);
    ReferenceModel? selected;
    for (final item in all) {
      if (item.id == _selectedId) selected = item;
    }
    ReferenceModel? leader;
    for (final item in all) {
      if (stats.of(item) == 0) continue;
      if (leader == null || stats.of(item) > stats.of(leader)) leader = item;
    }
    final withoutClients = stats.ready
        ? all.where((item) => stats.of(item) == 0).length
        : null;

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
              message: 'Cargando referencias…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message: 'No se pudo cargar el catálogo.\n$error',
              onRetry: () => ref.invalidate(referenceProvider),
            ),
          ),
          data: (_) => visible.isEmpty
              ? PulsoPanel(
                  child: PulsoStateView(
                    kind: PulsoStateKind.empty,
                    message: all.isEmpty
                        ? 'Todavía no hay referencias registradas.'
                        : 'Ninguna referencia coincide con la búsqueda.',
                  ),
                )
              : _ReferenceWorkspace(
                  items: visible,
                  stats: stats,
                  selected: workspaceWide ? selected : null,
                  sort: _sort,
                  ascending: _ascending,
                  onSort: _setSort,
                  onSelect: (item) {
                    if (workspaceWide) {
                      setState(() => _selectedId = item.id);
                    } else {
                      _showDetail(context, item, stats);
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
            _ReferenceHeader(onCreate: () => _openForm()),
            const SizedBox(height: 14),
            PulsoMetricStrip(
              metrics: [
                PulsoMetricData(
                  value: '${all.length}',
                  label: 'Referencias',
                  note: 'canales de captación',
                  emphasis: true,
                ),
                PulsoMetricData(
                  value: stats.ready ? '${stats.referredTotal}' : '—',
                  label: 'Socios captados',
                  note: 'llegaron por un canal',
                ),
                PulsoMetricData(
                  value: withoutClients == null ? '—' : '$withoutClients',
                  label: 'Sin captación',
                  note: 'canales sin socios',
                  warning: (withoutClients ?? 0) > 0,
                ),
                PulsoMetricData(
                  value: leader == null ? '—' : '${stats.of(leader)}',
                  label: 'Canal líder',
                  note: leader?.nombre ?? 'sin datos todavía',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ReferenceCommand(
              controller: _searchController,
              focusNode: _searchFocus,
              filter: _filter,
              onSearch: (value) => setState(() => _query = value),
              onFilter: (value) => setState(() => _filter = value),
              onRefresh: () => ref.invalidate(referenceProvider),
            ),
            const SizedBox(height: 12),
            if (scrollPage)
              SizedBox(height: 360, child: catalog)
            else
              Expanded(child: catalog),
            const SizedBox(height: 8),
            const _ReferenceFooter(),
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

class _ReferenceHeader extends StatelessWidget {
  const _ReferenceHeader({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PulsoLabel('PULSO · CONFIGURACIÓN'),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                text: 'REFERENCIAS',
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
              'Registra los canales que traen socios nuevos y mide cuál funciona.',
              style: TextStyle(color: tokens.muted, fontSize: 14),
            ),
          ],
        );
        final action = PulsoPrimaryButton(
          label: 'Nueva referencia',
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

class _ReferenceCommand extends StatelessWidget {
  const _ReferenceCommand({
    required this.controller,
    required this.focusNode,
    required this.filter,
    required this.onSearch,
    required this.onFilter,
    required this.onRefresh,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final _ReferenceFilter filter;
  final ValueChanged<String> onSearch;
  final ValueChanged<_ReferenceFilter> onFilter;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return PulsoPanel(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            key: const ValueKey('pulso-reference-search'),
            controller: controller,
            focusNode: focusNode,
            onChanged: onSearch,
            decoration: const InputDecoration(
              hintText: 'Buscar canal de captación…',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          );
          final controls = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _FilterButton(
                label: 'Todos',
                selected: filter == _ReferenceFilter.all,
                onTap: () => onFilter(_ReferenceFilter.all),
              ),
              _FilterButton(
                label: 'Con socios',
                selected: filter == _ReferenceFilter.withClients,
                onTap: () => onFilter(_ReferenceFilter.withClients),
              ),
              _FilterButton(
                label: 'Sin socios',
                selected: filter == _ReferenceFilter.withoutClients,
                onTap: () => onFilter(_ReferenceFilter.withoutClients),
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

class _ReferenceWorkspace extends StatelessWidget {
  const _ReferenceWorkspace({
    required this.items,
    required this.stats,
    required this.selected,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });
  final List<ReferenceModel> items;
  final _ReferenceStats stats;
  final ReferenceModel? selected;
  final _ReferenceSort sort;
  final bool ascending;
  final ValueChanged<_ReferenceSort> onSort;
  final ValueChanged<ReferenceModel> onSelect;
  final ValueChanged<ReferenceModel> onEdit;
  final ValueChanged<ReferenceModel> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final list = _ReferenceList(
          items: items,
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
              child: _ReferenceDetail(
                item: selected,
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

class _ReferenceList extends StatelessWidget {
  const _ReferenceList({
    required this.items,
    required this.stats,
    required this.selectedId,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });
  final List<ReferenceModel> items;
  final _ReferenceStats stats;
  final String? selectedId;
  final _ReferenceSort sort;
  final bool ascending;
  final ValueChanged<_ReferenceSort> onSort;
  final ValueChanged<ReferenceModel> onSelect;
  final ValueChanged<ReferenceModel> onEdit;
  final ValueChanged<ReferenceModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;
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
                      flex: 5,
                      child: _SortButton(
                        label: 'Referencia',
                        active: sort == _ReferenceSort.name,
                        ascending: ascending,
                        onTap: () => onSort(_ReferenceSort.name),
                      ),
                    ),
                    if (!compact) ...[
                      Expanded(
                        flex: 3,
                        child: _SortButton(
                          label: 'Socios captados',
                          active: sort == _ReferenceSort.clients,
                          ascending: ascending,
                          onTap: () => onSort(_ReferenceSort.clients),
                        ),
                      ),
                      const Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PulsoLabel('Identificador'),
                        ),
                      ),
                      const SizedBox(width: 100),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  key: const PageStorageKey('pulso-references-list'),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: tokens.line),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _ReferenceRow(
                      key: ValueKey(item.id),
                      item: item,
                      stats: stats,
                      selected: selectedId == item.id,
                      compact: compact,
                      onSelect: () => onSelect(item),
                      onEdit: () => onEdit(item),
                      onDelete: () => onDelete(item),
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
                  '${items.length} resultados · selección y scroll preservados',
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

String _shortReferenceId(String id) {
  if (id.length <= 8) return id;
  return '${id.substring(0, 4)}…${id.substring(id.length - 4)}';
}

class _ReferenceRow extends StatelessWidget {
  const _ReferenceRow({
    super.key,
    required this.item,
    required this.stats,
    required this.selected,
    required this.compact,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });
  final ReferenceModel item;
  final _ReferenceStats stats;
  final bool selected;
  final bool compact;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final count = stats.of(item);
    final hasClients = stats.ready && count > 0;
    final countLabel = !stats.ready
        ? '—'
        : count == 1
        ? '1 socio'
        : '$count socios';
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
                  Icons.campaign_outlined,
                  size: 18,
                  color: hasClients ? tokens.success : tokens.muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nombre,
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
                        '${_shortReferenceId(item.id)} · $countLabel',
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 9.5,
                          color: hasClients ? tokens.success : tokens.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!compact) ...[
                Expanded(
                  flex: 3,
                  child: Text(
                    countLabel,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontWeight: FontWeight.w600,
                      color: hasClients ? tokens.success : tokens.muted,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    _shortReferenceId(item.id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      color: tokens.chalkDim,
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
                        tooltip: 'Editar ${item.nombre}',
                        onPressed: onEdit,
                      ),
                      const SizedBox(width: 4),
                      PulsoIconButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Eliminar ${item.nombre}',
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

class _ReferenceDetail extends StatelessWidget {
  const _ReferenceDetail({
    required this.item,
    required this.stats,
    required this.onEdit,
    required this.onDelete,
  });
  final ReferenceModel? item;
  final _ReferenceStats stats;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final reference = item;
    if (reference == null) {
      return const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.empty,
          message: 'Selecciona una referencia para ver su detalle.',
        ),
      );
    }
    final count = stats.of(reference);
    final total = stats.referredTotal;
    final share = !stats.ready || total == 0
        ? '—'
        : '${(count * 100 / total).round()} %';
    return PulsoPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PulsoLabel('Detalle seleccionado'),
          const SizedBox(height: 18),
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
          const PulsoLabel('Socios captados'),
          const SizedBox(height: 9),
          Text(reference.nombre, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 22),
          _DetailLine(
            label: 'Identificador',
            value: _shortReferenceId(reference.id),
          ),
          _DetailLine(
            label: 'Socios captados',
            value: stats.ready ? '$count' : '—',
          ),
          _DetailLine(label: 'Participación', value: share),
          const Spacer(),
          PulsoPrimaryButton(
            label: 'Editar referencia',
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
            reference.id,
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
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: [
          Expanded(child: PulsoLabel(label)),
          Text(
            value,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontWeight: FontWeight.w600,
              color: tokens.chalkDim,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceFooter extends StatelessWidget {
  const _ReferenceFooter();
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Row(
      children: [
        const PulsoSyncStatus(compact: true),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'PULSO · REFERENCIAS · DATOS REALES',
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
