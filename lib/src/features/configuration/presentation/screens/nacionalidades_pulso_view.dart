import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../widgets/global_catalog_authority.dart';
import '../../data/models/nacionalidad_model.dart';
import '../state/nacionalidad_notifier.dart';
import '../widgets/nacionalidad_pulso_form.dart';

enum _NationalityFilter { all, withFlag, withoutFlag }

enum _NationalitySort { name, iso, status }

class NacionalidadesPulsoView extends ConsumerStatefulWidget {
  const NacionalidadesPulsoView({super.key});

  @override
  ConsumerState<NacionalidadesPulsoView> createState() =>
      _NacionalidadesPulsoViewState();
}

class _NacionalidadesPulsoViewState
    extends ConsumerState<NacionalidadesPulsoView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  String _query = '';
  String? _selectedId;
  _NationalityFilter _filter = _NationalityFilter.all;
  _NationalitySort _sort = _NationalitySort.name;
  bool _ascending = true;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool _hasFlag(NacionalidadModel item) => item.flagImage?.isNotEmpty == true;

  String _statusOf(NacionalidadModel item) =>
      _hasFlag(item) ? 'Completa' : 'Sin bandera';

  List<NacionalidadModel> _visible(List<NacionalidadModel> all) {
    final query = _query.trim().toLowerCase();
    final result = all.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.isoCode.toLowerCase().contains(query);
      final matchesFilter = switch (_filter) {
        _NationalityFilter.all => true,
        _NationalityFilter.withFlag => _hasFlag(item),
        _NationalityFilter.withoutFlag => !_hasFlag(item),
      };
      return matchesQuery && matchesFilter;
    }).toList();

    int compare(NacionalidadModel a, NacionalidadModel b) {
      final value = switch (_sort) {
        _NationalitySort.name => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
        _NationalitySort.iso => a.isoCode.toLowerCase().compareTo(
          b.isoCode.toLowerCase(),
        ),
        _NationalitySort.status => _statusOf(a).compareTo(_statusOf(b)),
      };
      return _ascending ? value : -value;
    }

    result.sort(compare);
    return result;
  }

  void _setSort(_NationalitySort sort) {
    setState(() {
      if (_sort == sort) {
        _ascending = !_ascending;
      } else {
        _sort = sort;
        _ascending = true;
      }
    });
  }

  Future<void> _openForm([NacionalidadModel? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => NacionalidadPulsoForm(
        id: item?.id,
        initialName: item?.name,
        initialIsoCode: item?.isoCode,
        initialFlagImage: item?.flagImage,
        onSubmit: (name, isoCode, flagBytes) async {
          final notifier = ref.read(nacionalidadProvider.notifier);
          if (item == null) {
            await notifier.create(name, isoCode, flagBytes);
          } else {
            await notifier.updateNacionalidad(
              item.id,
              name,
              isoCode,
              flagBytes,
            );
          }
        },
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          item == null
              ? 'Nueva nacionalidad creada.'
              : '${item.isoCode.toUpperCase()} fue actualizada.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(NacionalidadModel item) async {
    final tokens = PulsoTokens.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PulsoThemeScope(
        child: AlertDialog(
          title: const Text('Eliminar nacionalidad'),
          content: Text(
            'Se eliminará “${item.name}” (${item.isoCode.toUpperCase()}) del catálogo. Esta acción puede fallar si existen expedientes relacionados.',
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
      await ref.read(nacionalidadProvider.notifier).delete(item.id);
      if (!mounted) return;
      if (_selectedId == item.id) {
        setState(() => _selectedId = null);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('“${item.name}” fue eliminada.')));
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

  void _showDetail(BuildContext context, NacionalidadModel item) {
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
            height: 470,
            child: _NationalityDetail(
              item: item,
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
        builder: (context) {
          final tokens = PulsoTokens.of(context);
          return ColoredBox(
            color: tokens.floor,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                    _searchFocus.requestFocus,
                const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                    _searchFocus.requestFocus,
              },
              child: Focus(autofocus: true, child: _buildPage(context)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPage(BuildContext context) {
    final state = ref.watch(nacionalidadProvider);
    final all = state.value ?? const <NacionalidadModel>[];
    final visible = _visible(all);
    final withFlag = all.where(_hasFlag).length;
    final coverage = all.isEmpty ? 0 : ((withFlag / all.length) * 100).round();

    NacionalidadModel? selected;
    for (final item in all) {
      if (item.id == _selectedId) {
        selected = item;
        break;
      }
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
              message: 'Cargando catálogo de nacionalidades…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message: 'No se pudo cargar el catálogo.\n$error',
              onRetry: () => ref.read(nacionalidadProvider.notifier).refresh(),
            ),
          ),
          data: (_) {
            if (visible.isEmpty) {
              return PulsoPanel(
                child: PulsoStateView(
                  kind: PulsoStateKind.empty,
                  message: all.isEmpty
                      ? 'Todavía no hay nacionalidades registradas.'
                      : 'Ninguna nacionalidad coincide con la búsqueda.',
                ),
              );
            }
            return _NationalityWorkspace(
              items: visible,
              selected: workspaceWide ? selected : null,
              sort: _sort,
              ascending: _ascending,
              onSort: _setSort,
              onSelect: (item) {
                if (workspaceWide) {
                  setState(() => _selectedId = item.id);
                } else {
                  _showDetail(context, item);
                }
              },
              onEdit: _openForm,
              onDelete: _confirmDelete,
            );
          },
        );
        final page = Column(
          mainAxisSize: scrollPage ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NationalityHeader(onCreate: () => _openForm()),
            const SizedBox(height: 14),
            PulsoMetricStrip(
              metrics: [
                PulsoMetricData(
                  value: '${all.length}',
                  label: 'Nacionalidades',
                  note: 'catálogo total',
                  emphasis: true,
                ),
                PulsoMetricData(
                  value: '$withFlag',
                  label: 'Con bandera',
                  note: 'identidad completa',
                ),
                PulsoMetricData(
                  value: '${all.length - withFlag}',
                  label: 'Pendientes',
                  note: 'sin imagen',
                  warning: all.length - withFlag > 0,
                ),
                PulsoMetricData(
                  value: '$coverage%',
                  label: 'Cobertura',
                  note: 'banderas asignadas',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _NationalityCommandBar(
              controller: _searchController,
              focusNode: _searchFocus,
              filter: _filter,
              onSearch: (value) => setState(() => _query = value),
              onFilter: (value) => setState(() => _filter = value),
              onRefresh: () =>
                  ref.read(nacionalidadProvider.notifier).refresh(),
            ),
            const SizedBox(height: 12),
            if (scrollPage)
              SizedBox(height: 360, child: catalog)
            else
              Expanded(child: catalog),
            const SizedBox(height: 8),
            const _NationalityFooter(),
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

class _NationalityHeader extends StatelessWidget {
  const _NationalityHeader({required this.onCreate});

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
                text: 'NACIONALIDADES',
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
              'Organiza nombres, códigos ISO y banderas utilizados en los expedientes.',
              style: TextStyle(color: tokens.muted, fontSize: 14),
            ),
          ],
        );
        final action = GlobalCatalogAuthority(
          child: PulsoPrimaryButton(
            label: 'Nueva nacionalidad',
            icon: Icons.add,
            onPressed: onCreate,
          ),
        );
        if (constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [copy, const SizedBox(height: 14), action],
          );
        }
        return Row(
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

class _NationalityCommandBar extends StatelessWidget {
  const _NationalityCommandBar({
    required this.controller,
    required this.focusNode,
    required this.filter,
    required this.onSearch,
    required this.onFilter,
    required this.onRefresh,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final _NationalityFilter filter;
  final ValueChanged<String> onSearch;
  final ValueChanged<_NationalityFilter> onFilter;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return PulsoPanel(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            key: const ValueKey('pulso-nationality-search'),
            controller: controller,
            focusNode: focusNode,
            onChanged: onSearch,
            decoration: const InputDecoration(
              hintText: 'Buscar nombre o código ISO…',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          );
          final controls = Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _NationalityFilterButton(
                label: 'Todas',
                selected: filter == _NationalityFilter.all,
                onTap: () => onFilter(_NationalityFilter.all),
              ),
              _NationalityFilterButton(
                label: 'Con bandera',
                selected: filter == _NationalityFilter.withFlag,
                onTap: () => onFilter(_NationalityFilter.withFlag),
              ),
              _NationalityFilterButton(
                label: 'Sin bandera',
                selected: filter == _NationalityFilter.withoutFlag,
                onTap: () => onFilter(_NationalityFilter.withoutFlag),
              ),
              PulsoIconButton(
                icon: Icons.refresh,
                tooltip: 'Actualizar',
                onPressed: onRefresh,
              ),
            ],
          );
          if (constraints.maxWidth < 820) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [search, const SizedBox(height: 8), controls],
            );
          }
          return Row(
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

class _NationalityFilterButton extends StatelessWidget {
  const _NationalityFilterButton({
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

class _NationalityWorkspace extends StatelessWidget {
  const _NationalityWorkspace({
    required this.items,
    required this.selected,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final List<NacionalidadModel> items;
  final NacionalidadModel? selected;
  final _NationalitySort sort;
  final bool ascending;
  final ValueChanged<_NationalitySort> onSort;
  final ValueChanged<NacionalidadModel> onSelect;
  final ValueChanged<NacionalidadModel> onEdit;
  final ValueChanged<NacionalidadModel> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final list = _NationalityList(
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
              child: _NationalityDetail(
                item: selected,
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

class _NationalityList extends StatelessWidget {
  const _NationalityList({
    required this.items,
    required this.selectedId,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final List<NacionalidadModel> items;
  final String? selectedId;
  final _NationalitySort sort;
  final bool ascending;
  final ValueChanged<_NationalitySort> onSort;
  final ValueChanged<NacionalidadModel> onSelect;
  final ValueChanged<NacionalidadModel> onEdit;
  final ValueChanged<NacionalidadModel> onDelete;

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
                      child: _NationalitySortButton(
                        label: 'Nacionalidad',
                        active: sort == _NationalitySort.name,
                        ascending: ascending,
                        onTap: () => onSort(_NationalitySort.name),
                      ),
                    ),
                    if (!compact) ...[
                      Expanded(
                        flex: 2,
                        child: _NationalitySortButton(
                          label: 'ISO',
                          active: sort == _NationalitySort.iso,
                          ascending: ascending,
                          onTap: () => onSort(_NationalitySort.iso),
                        ),
                      ),
                      const Expanded(flex: 2, child: PulsoLabel('Bandera')),
                      Expanded(
                        flex: 3,
                        child: _NationalitySortButton(
                          label: 'Estado',
                          active: sort == _NationalitySort.status,
                          ascending: ascending,
                          onTap: () => onSort(_NationalitySort.status),
                        ),
                      ),
                      const SizedBox(width: 100),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  key: const PageStorageKey('pulso-nationalities-list'),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: tokens.line.withValues(alpha: 0.75),
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _NationalityRow(
                      key: ValueKey(item.id),
                      item: item,
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

class _NationalitySortButton extends StatelessWidget {
  const _NationalitySortButton({
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
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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

class _NationalityRow extends StatelessWidget {
  const _NationalityRow({
    super.key,
    required this.item,
    required this.selected,
    required this.compact,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final NacionalidadModel item;
  final bool selected;
  final bool compact;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final hasFlag = item.flagImage?.isNotEmpty == true;
    return Material(
      color: selected ? tokens.accentSoftStrong : Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        child: Container(
          constraints: const BoxConstraints(minHeight: 66),
          padding: const EdgeInsets.fromLTRB(11, 9, 12, 9),
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
              PulsoFlag(code: item.isoCode, base64String: item.flagImage),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
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
                        '${item.isoCode.toUpperCase()} · ${hasFlag ? 'bandera asignada' : 'sin bandera'}',
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 9.5,
                          color: hasFlag ? tokens.success : tokens.warning,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!compact) ...[
                Expanded(
                  flex: 2,
                  child: Text(
                    item.isoCode.toUpperCase(),
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontWeight: FontWeight.w600,
                      color: tokens.chalkDim,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    hasFlag ? 'Asignada' : 'Pendiente',
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 10,
                      color: hasFlag ? tokens.success : tokens.warning,
                    ),
                  ),
                ),
                Expanded(flex: 3, child: _NationalityStatus(complete: hasFlag)),
                GlobalCatalogAuthority(
                  readOnly: const SizedBox(
                    width: 100,
                    child: Center(child: Icon(Icons.lock_outline, size: 18)),
                  ),
                  child: SizedBox(
                    width: 100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        PulsoIconButton(
                          icon: Icons.edit_outlined,
                          tooltip: 'Editar ${item.name}',
                          onPressed: onEdit,
                        ),
                        const SizedBox(width: 4),
                        PulsoIconButton(
                          icon: Icons.delete_outline,
                          tooltip: 'Eliminar ${item.name}',
                          danger: true,
                          onPressed: onDelete,
                        ),
                      ],
                    ),
                  ),
                ),
              ] else
                GlobalCatalogAuthority(
                  child: PopupMenuButton<String>(
                    tooltip: 'Acciones de ${item.name}',
                    color: tokens.surface,
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
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

class _NationalityStatus extends StatelessWidget {
  const _NationalityStatus({required this.complete});

  final bool complete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = complete ? tokens.success : tokens.warning;
    return Row(
      children: [
        Container(width: 6, height: 6, color: color),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            complete ? 'COMPLETA' : 'INCOMPLETA',
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

class _NationalityDetail extends StatelessWidget {
  const _NationalityDetail({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final NacionalidadModel? item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final nationality = item;
    if (nationality == null) {
      return const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.empty,
          message: 'Selecciona una nacionalidad para ver su detalle.',
        ),
      );
    }
    final hasFlag = nationality.flagImage?.isNotEmpty == true;
    return PulsoPanel(
      padding: const EdgeInsets.all(20),
      child: CustomScrollView(
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              const PulsoLabel('Detalle seleccionado'),
              const SizedBox(height: 18),
              PulsoFlag(
                code: nationality.isoCode,
                base64String: nationality.flagImage,
                width: 132,
                height: 88,
              ),
              const SizedBox(height: 18),
              Text(
                nationality.isoCode.toUpperCase(),
                style: TextStyle(
                  fontFamily: PulsoFonts.display,
                  fontSize: 58,
                  height: 0.9,
                  fontWeight: FontWeight.w800,
                  color: tokens.accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                nationality.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 22),
              _NationalityDetailLine(
                label: 'Código ISO',
                value: nationality.isoCode.toUpperCase(),
              ),
              _NationalityDetailLine(
                label: 'Bandera',
                value: hasFlag ? 'Asignada' : 'Pendiente',
              ),
              _NationalityDetailLine(
                label: 'Estado',
                value: hasFlag ? 'Completa' : 'Incompleta',
              ),
            ]),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 18),
                GlobalCatalogAuthority(
                  readOnly: const Text('Catálogo global · solo lectura'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PulsoPrimaryButton(
                        label: 'Editar nacionalidad',
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
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  nationality.id,
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
          ),
        ],
      ),
    );
  }
}

class _NationalityDetailLine extends StatelessWidget {
  const _NationalityDetailLine({required this.label, required this.value});

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
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tokens.chalkDim,
            ),
          ),
        ],
      ),
    );
  }
}

class _NationalityFooter extends StatelessWidget {
  const _NationalityFooter();

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Row(
      children: [
        const PulsoSyncStatus(compact: true),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'PULSO · NACIONALIDADES · DATOS REALES',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              letterSpacing: 0.5,
              color: tokens.muted2,
            ),
          ),
        ),
      ],
    );
  }
}
