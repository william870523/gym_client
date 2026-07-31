import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/retention_models.dart';
import '../state/retention_providers.dart';
import '../widgets/dropout_reason_pulso_form.dart';

enum _ReasonFilter { all, active, inactive, unused }

enum _ReasonSort { order, name, managements }

/// Catálogo administrable de motivos de baja (docs/PLAN_ESTADISTICAS.md §7-ter).
///
/// Mismo enriquecimiento que Referencias: cuánto se usa cada motivo, cuál
/// encabeza, cuáles no ha usado nadie. Aquí el uso además decide qué se puede
/// borrar, así que no es adorno: es la información que evita un error.
class DropoutReasonsPulsoView extends ConsumerStatefulWidget {
  const DropoutReasonsPulsoView({super.key});

  @override
  ConsumerState<DropoutReasonsPulsoView> createState() =>
      _DropoutReasonsPulsoViewState();
}

class _DropoutReasonsPulsoViewState
    extends ConsumerState<DropoutReasonsPulsoView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  String? _selectedId;
  _ReasonFilter _filter = _ReasonFilter.all;
  _ReasonSort _sort = _ReasonSort.order;
  bool _ascending = true;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<DropoutReasonModel> _visible(List<DropoutReasonModel> all) {
    final query = _query.trim().toLowerCase();
    final result = all.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          (item.code ?? '').toLowerCase().contains(query);
      final matchesFilter = switch (_filter) {
        _ReasonFilter.all => true,
        _ReasonFilter.active => item.active,
        _ReasonFilter.inactive => !item.active,
        _ReasonFilter.unused => item.managements == 0,
      };
      return matchesQuery && matchesFilter;
    }).toList();

    int compare(DropoutReasonModel a, DropoutReasonModel b) {
      final value = switch (_sort) {
        _ReasonSort.order => a.order.compareTo(b.order),
        _ReasonSort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        _ReasonSort.managements => a.managements.compareTo(b.managements),
      };
      // Empate por orden: el nombre desempata para que la lista sea estable.
      if (value != 0) return _ascending ? value : -value;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }

    result.sort(compare);
    return result;
  }

  void _setSort(_ReasonSort sort) {
    setState(() {
      if (_sort == sort) {
        _ascending = !_ascending;
      } else {
        _sort = sort;
        // Por uso interesa primero el motivo que más aparece.
        _ascending = sort != _ReasonSort.managements;
      }
    });
  }

  Future<void> _openForm([DropoutReasonModel? item]) async {
    final notifier = ref.read(dropoutReasonCatalogProvider.notifier);
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DropoutReasonPulsoForm(
        reason: item,
        onSubmit: ({required name, code, required order, required active}) {
          return item == null
              ? notifier.create(
                  name: name,
                  code: code,
                  order: order,
                  active: active,
                )
              : notifier.edit(
                  id: item.id,
                  name: name,
                  code: code,
                  order: order,
                  active: active,
                );
        },
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          item == null
              ? 'Motivo creado y disponible en la gestión.'
              : '“${item.name}” fue actualizado.',
        ),
      ),
    );
  }

  Future<void> _toggleActive(DropoutReasonModel item) async {
    final tokens = PulsoTokens.of(context);
    try {
      await ref
          .read(dropoutReasonCatalogProvider.notifier)
          .setActive(item, !item.active);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item.active
                ? '“${item.name}” ya no se ofrece en gestiones nuevas.'
                : '“${item.name}” vuelve a estar disponible.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: tokens.danger,
          content: Text('No se pudo cambiar el estado: $error'),
        ),
      );
    }
  }

  Future<void> _confirmDelete(DropoutReasonModel item) async {
    final tokens = PulsoTokens.of(context);
    // Se explica el porqué antes de intentarlo: descubrir el límite con un
    // error del servidor es peor experiencia que leerlo aquí.
    if (!item.canDelete) {
      final motivo = item.isSystem
          ? 'Es un motivo base del sistema.'
          : 'Ya está registrado en ${item.managements} gestión(es), y borrarlo '
                'dejaría esas bajas sin explicación.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: tokens.warning,
          content: Text('$motivo Desactívalo en su lugar.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PulsoThemeScope(
        child: AlertDialog(
          title: const Text('Eliminar motivo'),
          content: Text(
            'Se eliminará “${item.name}” del catálogo. Nadie lo ha usado '
            'todavía, así que no hay historia que dependa de él.',
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
      await ref.read(dropoutReasonCatalogProvider.notifier).remove(item.id);
      if (!mounted) return;
      if (_selectedId == item.id) setState(() => _selectedId = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('“${item.name}” fue eliminado.')));
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
    DropoutReasonModel item,
    int totalManagements,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => PulsoThemeScope(
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: SizedBox(
            width: 340,
            height: 460,
            child: _ReasonDetail(
              item: item,
              totalManagements: totalManagements,
              onEdit: () {
                Navigator.of(dialogContext).pop();
                _openForm(item);
              },
              onToggle: () {
                Navigator.of(dialogContext).pop();
                _toggleActive(item);
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

  Widget _buildPage(BuildContext context) {
    final state = ref.watch(dropoutReasonCatalogProvider);
    final all = state.value ?? const <DropoutReasonModel>[];
    final visible = _visible(all);

    DropoutReasonModel? selected;
    for (final item in all) {
      if (item.id == _selectedId) selected = item;
    }
    DropoutReasonModel? leader;
    for (final item in all) {
      if (item.managements == 0) continue;
      if (leader == null || item.managements > leader.managements) {
        leader = item;
      }
    }
    final active = all.where((item) => item.active).length;
    final unused = all.where((item) => item.managements == 0).length;
    final totalManagements = all.fold(
      0,
      (total, item) => total + item.managements,
    );

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
              message: 'Cargando motivos de baja…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message: 'No se pudo cargar el catálogo.\n$error',
              onRetry: () => ref.invalidate(dropoutReasonCatalogProvider),
            ),
          ),
          data: (_) => visible.isEmpty
              ? PulsoPanel(
                  child: PulsoStateView(
                    kind: PulsoStateKind.empty,
                    message: all.isEmpty
                        ? 'Todavía no hay motivos de baja en el catálogo.'
                        : 'Ningún motivo coincide con la búsqueda.',
                  ),
                )
              : _ReasonWorkspace(
                  items: visible,
                  totalManagements: totalManagements,
                  selected: workspaceWide ? selected : null,
                  sort: _sort,
                  ascending: _ascending,
                  onSort: _setSort,
                  onSelect: (item) {
                    if (workspaceWide) {
                      setState(() => _selectedId = item.id);
                    } else {
                      _showDetail(context, item, totalManagements);
                    }
                  },
                  onEdit: _openForm,
                  onToggle: _toggleActive,
                  onDelete: _confirmDelete,
                ),
        );

        final page = Column(
          mainAxisSize: scrollPage ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReasonHeader(onCreate: () => _openForm()),
            const SizedBox(height: 14),
            PulsoMetricStrip(
              metrics: [
                PulsoMetricData(
                  value: '${all.length}',
                  label: 'Motivos',
                  note: 'catálogo de bajas',
                  emphasis: true,
                ),
                PulsoMetricData(
                  value: '$active',
                  label: 'Activos',
                  note: 'se ofrecen en la gestión',
                  warning: all.isNotEmpty && active == 0,
                ),
                PulsoMetricData(
                  value: '$totalManagements',
                  label: 'Gestiones',
                  note: 'con motivo registrado',
                ),
                PulsoMetricData(
                  value: leader == null ? '—' : '${leader.managements}',
                  label: 'Motivo líder',
                  note: leader?.name ?? 'sin gestiones todavía',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ReasonCommand(
              controller: _searchController,
              focusNode: _searchFocus,
              filter: _filter,
              unused: unused,
              onSearch: (value) => setState(() => _query = value),
              onFilter: (value) => setState(() => _filter = value),
              onRefresh: () => ref.invalidate(dropoutReasonCatalogProvider),
            ),
            const SizedBox(height: 12),
            if (scrollPage)
              SizedBox(height: 360, child: catalog)
            else
              Expanded(child: catalog),
            const SizedBox(height: 8),
            const _ReasonFooter(),
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

class _ReasonHeader extends StatelessWidget {
  const _ReasonHeader({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const PulsoLabel('Retención · catálogo'),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                text: 'MOTIVOS DE\nBAJA',
                style: TextStyle(
                  fontFamily: 'BarlowCondensed',
                  fontSize: compact ? 30 : 38,
                  height: 0.95,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: tokens.chalk,
                ),
                children: [
                  TextSpan(text: '.', style: TextStyle(color: tokens.accent)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: compact ? double.infinity : 420,
              child: Text(
                'Por qué se van los socios. Lo elige recepción al registrar una '
                'gestión; aquí se decide qué opciones tiene.',
                style: TextStyle(fontSize: 12, height: 1.5, color: tokens.muted),
              ),
            ),
          ],
        );
        final action = PulsoPrimaryButton(
          key: const ValueKey('dropout-reason-create'),
          label: 'Nuevo motivo',
          onPressed: onCreate,
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [title, const SizedBox(height: 14), action],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            action,
          ],
        );
      },
    );
  }
}

class _ReasonCommand extends StatelessWidget {
  const _ReasonCommand({
    required this.controller,
    required this.focusNode,
    required this.filter,
    required this.unused,
    required this.onSearch,
    required this.onFilter,
    required this.onRefresh,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final _ReasonFilter filter;
  final int unused;
  final ValueChanged<String> onSearch;
  final ValueChanged<_ReasonFilter> onFilter;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final search = TextField(
            key: const ValueKey('dropout-reason-search'),
            controller: controller,
            focusNode: focusNode,
            onChanged: onSearch,
            style: TextStyle(fontSize: 13, color: tokens.chalk),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Buscar motivo o código   ·   Ctrl K',
              hintStyle: TextStyle(fontSize: 12, color: tokens.muted),
              prefixIcon: Icon(Icons.search, size: 16, color: tokens.muted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: tokens.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: tokens.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: tokens.accent),
              ),
            ),
          );
          final filters = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterButton(
                label: 'Todos',
                selected: filter == _ReasonFilter.all,
                onPressed: () => onFilter(_ReasonFilter.all),
              ),
              _FilterButton(
                label: 'Activos',
                selected: filter == _ReasonFilter.active,
                onPressed: () => onFilter(_ReasonFilter.active),
              ),
              _FilterButton(
                label: 'Inactivos',
                selected: filter == _ReasonFilter.inactive,
                onPressed: () => onFilter(_ReasonFilter.inactive),
              ),
              _FilterButton(
                label: 'Sin uso ($unused)',
                selected: filter == _ReasonFilter.unused,
                onPressed: () => onFilter(_ReasonFilter.unused),
              ),
            ],
          );
          final refresh = PulsoIconButton(
            icon: Icons.refresh,
            tooltip: 'Actualizar',
            onPressed: onRefresh,
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: filters),
                    const SizedBox(width: 8),
                    refresh,
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              SizedBox(width: 280, child: search),
              const SizedBox(width: 12),
              Expanded(child: filters),
              const SizedBox(width: 8),
              refresh,
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
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? tokens.accentSoft : Colors.transparent,
          border: Border.all(color: selected ? tokens.accent : tokens.line),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'BarlowCondensed',
            fontSize: 12,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
            color: selected ? tokens.accent : tokens.muted,
          ),
        ),
      ),
    );
  }
}

class _ReasonWorkspace extends StatelessWidget {
  const _ReasonWorkspace({
    required this.items,
    required this.totalManagements,
    required this.selected,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final List<DropoutReasonModel> items;
  final int totalManagements;
  final DropoutReasonModel? selected;
  final _ReasonSort sort;
  final bool ascending;
  final ValueChanged<_ReasonSort> onSort;
  final ValueChanged<DropoutReasonModel> onSelect;
  final ValueChanged<DropoutReasonModel> onEdit;
  final ValueChanged<DropoutReasonModel> onToggle;
  final ValueChanged<DropoutReasonModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final list = _ReasonList(
      items: items,
      totalManagements: totalManagements,
      selectedId: selected?.id,
      sort: sort,
      ascending: ascending,
      onSort: onSort,
      onSelect: onSelect,
      onEdit: onEdit,
      onToggle: onToggle,
      onDelete: onDelete,
    );
    if (selected == null) return list;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: list),
        const SizedBox(width: 12),
        SizedBox(
          width: 320,
          child: _ReasonDetail(
            item: selected!,
            totalManagements: totalManagements,
            onEdit: () => onEdit(selected!),
            onToggle: () => onToggle(selected!),
            onDelete: () => onDelete(selected!),
          ),
        ),
      ],
    );
  }
}

class _ReasonList extends StatelessWidget {
  const _ReasonList({
    required this.items,
    required this.totalManagements,
    required this.selectedId,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final List<DropoutReasonModel> items;
  final int totalManagements;
  final String? selectedId;
  final _ReasonSort sort;
  final bool ascending;
  final ValueChanged<_ReasonSort> onSort;
  final ValueChanged<DropoutReasonModel> onSelect;
  final ValueChanged<DropoutReasonModel> onEdit;
  final ValueChanged<DropoutReasonModel> onToggle;
  final ValueChanged<DropoutReasonModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _SortButton(
                        label: 'Motivo',
                        active: sort == _ReasonSort.name,
                        ascending: ascending,
                        onPressed: () => onSort(_ReasonSort.name),
                      ),
                    ),
                    if (wide)
                      Expanded(
                        flex: 2,
                        child: _SortButton(
                          label: 'Orden',
                          active: sort == _ReasonSort.order,
                          ascending: ascending,
                          onPressed: () => onSort(_ReasonSort.order),
                        ),
                      ),
                    Expanded(
                      flex: 2,
                      child: _SortButton(
                        label: 'Gestiones',
                        active: sort == _ReasonSort.managements,
                        ascending: ascending,
                        onPressed: () => onSort(_ReasonSort.managements),
                      ),
                    ),
                    const SizedBox(width: 144),
                  ],
                ),
              ),
              Divider(height: 1, color: tokens.line),
              Expanded(
                child: ListView.separated(
                  key: const PageStorageKey('dropout-reason-list'),
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: tokens.line),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _ReasonRow(
                      item: item,
                      wide: wide,
                      selected: item.id == selectedId,
                      onTap: () => onSelect(item),
                      onEdit: () => onEdit(item),
                      onToggle: () => onToggle(item),
                      onDelete: () => onDelete(item),
                    );
                  },
                ),
              ),
              Divider(height: 1, color: tokens.line),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Text(
                  '${items.length} motivo(s) · $totalManagements gestión(es) '
                  'con motivo · selección y scroll preservados',
                  style: TextStyle(
                    fontFamily: 'IBMPlexMono',
                    fontSize: 10,
                    color: tokens.muted,
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
    required this.onPressed,
  });

  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return InkWell(
      onTap: onPressed,
      child: Row(
        children: [
          Flexible(
            child: Text(
              label.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'BarlowCondensed',
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
                color: active ? tokens.accent : tokens.muted,
              ),
            ),
          ),
          if (active) ...[
            const SizedBox(width: 3),
            Icon(
              ascending ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              size: 14,
              color: tokens.accent,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.item,
    required this.wide,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final DropoutReasonModel item;
  final bool wide;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final statusColor = !item.active
        ? tokens.muted
        : item.managements == 0
        ? tokens.warning
        : tokens.success;
    final statusLabel = !item.active
        ? 'Inactivo'
        : item.managements == 0
        ? 'Sin uso'
        : 'En uso';

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          color: selected ? tokens.accentSoftStrong : Colors.transparent,
          border: Border(
            left: BorderSide(
              width: 3,
              color: selected ? tokens.accent : Colors.transparent,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(11, 8, 14, 8),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(width: 7, height: 7, color: statusColor),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          item.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: tokens.chalk,
                          ),
                        ),
                      ),
                      if (item.isSystem) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.shield_outlined, size: 12, color: tokens.muted),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    wide
                        ? '$statusLabel${item.code == null ? '' : ' · ${item.code}'}'
                        : '$statusLabel · orden ${item.order}'
                              '${item.code == null ? '' : ' · ${item.code}'}',
                    style: TextStyle(
                      fontFamily: 'IBMPlexMono',
                      fontSize: 10,
                      color: tokens.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (wide)
              Expanded(
                flex: 2,
                child: Text(
                  '${item.order}',
                  style: TextStyle(
                    fontFamily: 'IBMPlexMono',
                    fontSize: 12,
                    color: tokens.muted,
                  ),
                ),
              ),
            Expanded(
              flex: 2,
              child: Text(
                '${item.managements}',
                style: TextStyle(
                  fontFamily: 'IBMPlexMono',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: item.managements == 0 ? tokens.muted : tokens.chalk,
                ),
              ),
            ),
            SizedBox(
              width: 144,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PulsoIconButton(
                    icon: item.active
                        ? Icons.toggle_on_outlined
                        : Icons.toggle_off_outlined,
                    tooltip: item.active ? 'Desactivar' : 'Activar',
                    onPressed: onToggle,
                  ),
                  PulsoIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Editar',
                    onPressed: onEdit,
                  ),
                  PulsoIconButton(
                    icon: Icons.delete_outline,
                    tooltip: item.canDelete
                        ? 'Eliminar'
                        : 'No se puede eliminar: desactívalo',
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonDetail extends StatelessWidget {
  const _ReasonDetail({
    required this.item,
    required this.totalManagements,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final DropoutReasonModel item;
  final int totalManagements;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final share = totalManagements == 0
        ? null
        : (item.managements * 100 / totalManagements);

    return PulsoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PulsoLabel('Detalle'),
          const SizedBox(height: 10),
          Text(
            item.name,
            style: TextStyle(
              fontFamily: 'BarlowCondensed',
              fontSize: 24,
              height: 1.05,
              fontWeight: FontWeight.w700,
              color: tokens.chalk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.active
                ? 'Se ofrece al registrar una gestión'
                : 'Oculto en gestiones nuevas',
            style: TextStyle(
              fontSize: 11,
              color: item.active ? tokens.success : tokens.muted,
            ),
          ),
          const SizedBox(height: 16),
          _DetailLine(label: 'Código', value: item.code ?? '—'),
          _DetailLine(label: 'Orden en la lista', value: '${item.order}'),
          _DetailLine(label: 'Gestiones', value: '${item.managements}'),
          _DetailLine(
            label: 'Participación',
            value: share == null ? '—' : '${share.toStringAsFixed(1)} %',
          ),
          _DetailLine(
            label: 'Origen',
            value: item.isSystem ? 'Motivo base' : 'Añadido por el gimnasio',
          ),
          const Spacer(),
          if (!item.canDelete)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                item.isSystem
                    ? 'Los motivos base no se borran. Desactívalo si no quieres '
                          'que aparezca.'
                    : 'Ya se usó en ${item.managements} gestión(es): borrarlo '
                          'dejaría esas bajas sin explicación.',
                style: TextStyle(fontSize: 11, height: 1.4, color: tokens.muted),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: PulsoSecondaryButton(
                  label: item.active ? 'Desactivar' : 'Activar',
                  onPressed: onToggle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PulsoSecondaryButton(label: 'Editar', onPressed: onEdit),
              ),
            ],
          ),
          const SizedBox(height: 8),
          PulsoSecondaryButton(
            label: 'Eliminar',
            danger: true,
            onPressed: onDelete,
          ),
          const SizedBox(height: 10),
          Text(
            item.id,
            style: TextStyle(
              fontFamily: 'IBMPlexMono',
              fontSize: 9,
              color: tokens.muted,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: tokens.muted),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'IBMPlexMono',
              fontSize: 12,
              color: tokens.chalk,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonFooter extends StatelessWidget {
  const _ReasonFooter();

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Row(
      children: [
        const PulsoSyncStatus(),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Desactivar retira el motivo de gestiones nuevas sin tocar la '
            'historia. Borrar solo se permite si nadie lo usó.',
            style: TextStyle(fontSize: 10, color: tokens.muted),
          ),
        ),
      ],
    );
  }
}
