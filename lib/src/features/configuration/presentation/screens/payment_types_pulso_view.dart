import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../widgets/global_catalog_authority.dart';
import '../../data/models/payment_type_model.dart';
import '../state/payment_type_notifier.dart';
import '../widgets/payment_type_pulso_form.dart';

enum _PaymentFilter { all, active, inactive }

enum _PaymentSort { name, code, status }

class PaymentTypesPulsoView extends ConsumerStatefulWidget {
  const PaymentTypesPulsoView({super.key});

  @override
  ConsumerState<PaymentTypesPulsoView> createState() =>
      _PaymentTypesPulsoViewState();
}

class _PaymentTypesPulsoViewState extends ConsumerState<PaymentTypesPulsoView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  String? _selectedId;
  _PaymentFilter _filter = _PaymentFilter.all;
  _PaymentSort _sort = _PaymentSort.name;
  bool _ascending = true;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<PaymentTypeModel> _visible(List<PaymentTypeModel> all) {
    final query = _query.trim().toLowerCase();
    final result = all.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          (item.code ?? '').toLowerCase().contains(query);
      final matchesFilter = switch (_filter) {
        _PaymentFilter.all => true,
        _PaymentFilter.active => item.active,
        _PaymentFilter.inactive => !item.active,
      };
      return matchesQuery && matchesFilter;
    }).toList();
    int compare(PaymentTypeModel a, PaymentTypeModel b) {
      final value = switch (_sort) {
        _PaymentSort.name => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
        _PaymentSort.code => (a.code ?? '').toLowerCase().compareTo(
          (b.code ?? '').toLowerCase(),
        ),
        _PaymentSort.status =>
          a.active == b.active
              ? 0
              : a.active
              ? -1
              : 1,
      };
      return _ascending ? value : -value;
    }

    result.sort(compare);
    return result;
  }

  void _setSort(_PaymentSort sort) {
    setState(() {
      if (_sort == sort) {
        _ascending = !_ascending;
      } else {
        _sort = sort;
        _ascending = true;
      }
    });
  }

  Future<void> _openForm([PaymentTypeModel? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentTypePulsoForm(
        id: item?.id,
        initialName: item?.name,
        initialCode: item?.code,
        initialActive: item?.active ?? true,
        onSubmit: (name, code, active) async {
          final notifier = ref.read(paymentTypeNotifierProvider.notifier);
          if (item == null) {
            await notifier.create(name, code, active);
          } else {
            await notifier.updatePaymentType(item.id, name, code, active);
          }
        },
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          item == null
              ? 'Nuevo tipo de pago creado.'
              : '“${item.name}” fue actualizado.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(PaymentTypeModel item) async {
    final tokens = PulsoTokens.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PulsoThemeScope(
        child: AlertDialog(
          title: const Text('Eliminar tipo de pago'),
          content: Text(
            'Se eliminará “${item.name}”. La operación puede fallar si existen cobros relacionados.',
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
      await ref.read(paymentTypeNotifierProvider.notifier).delete(item.id);
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

  void _showDetail(BuildContext context, PaymentTypeModel item) {
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
            height: 440,
            child: _PaymentTypeDetail(
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
    final state = ref.watch(paymentTypeNotifierProvider);
    final all = state.value ?? const <PaymentTypeModel>[];
    final visible = _visible(all);
    final active = all.where((item) => item.active).length;
    final coded = all.where((item) => item.code?.isNotEmpty == true).length;
    PaymentTypeModel? selected;
    for (final item in all) {
      if (item.id == _selectedId) selected = item;
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
              message: 'Cargando tipos de pago…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message: 'No se pudo cargar el catálogo.\n$error',
              onRetry: () => ref.invalidate(paymentTypeNotifierProvider),
            ),
          ),
          data: (_) => visible.isEmpty
              ? PulsoPanel(
                  child: PulsoStateView(
                    kind: PulsoStateKind.empty,
                    message: all.isEmpty
                        ? 'Todavía no hay tipos de pago registrados.'
                        : 'Ningún tipo coincide con la búsqueda.',
                  ),
                )
              : _PaymentTypeWorkspace(
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
                ),
        );
        final page = Column(
          mainAxisSize: scrollPage ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PaymentTypeHeader(onCreate: () => _openForm()),
            const SizedBox(height: 14),
            PulsoMetricStrip(
              metrics: [
                PulsoMetricData(
                  value: '${all.length}',
                  label: 'Tipos de pago',
                  note: 'catálogo total',
                  emphasis: true,
                ),
                PulsoMetricData(
                  value: '$active',
                  label: 'Activos',
                  note: 'disponibles en cobros',
                ),
                PulsoMetricData(
                  value: '${all.length - active}',
                  label: 'Inactivos',
                  note: 'ocultos en cobros',
                  warning: all.length - active > 0,
                ),
                PulsoMetricData(
                  value: '$coded',
                  label: 'Con código',
                  note: 'listos para reportes',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PaymentTypeCommand(
              controller: _searchController,
              focusNode: _searchFocus,
              filter: _filter,
              onSearch: (value) => setState(() => _query = value),
              onFilter: (value) => setState(() => _filter = value),
              onRefresh: () => ref.invalidate(paymentTypeNotifierProvider),
            ),
            const SizedBox(height: 12),
            if (scrollPage)
              SizedBox(height: 360, child: catalog)
            else
              Expanded(child: catalog),
            const SizedBox(height: 8),
            const _PaymentFooter(),
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

class _PaymentTypeHeader extends StatelessWidget {
  const _PaymentTypeHeader({required this.onCreate});
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
                text: 'TIPOS DE PAGO',
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
              'Controla los medios disponibles para cobrar y reportar ingresos.',
              style: TextStyle(color: tokens.muted, fontSize: 14),
            ),
          ],
        );
        final action = GlobalCatalogAuthority(
          child: PulsoPrimaryButton(
            label: 'Nuevo tipo',
            icon: Icons.add,
            onPressed: onCreate,
          ),
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

class _PaymentTypeCommand extends StatelessWidget {
  const _PaymentTypeCommand({
    required this.controller,
    required this.focusNode,
    required this.filter,
    required this.onSearch,
    required this.onFilter,
    required this.onRefresh,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final _PaymentFilter filter;
  final ValueChanged<String> onSearch;
  final ValueChanged<_PaymentFilter> onFilter;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return PulsoPanel(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            key: const ValueKey('pulso-payment-type-search'),
            controller: controller,
            focusNode: focusNode,
            onChanged: onSearch,
            decoration: const InputDecoration(
              hintText: 'Buscar nombre o código…',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          );
          final controls = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _FilterButton(
                label: 'Todos',
                selected: filter == _PaymentFilter.all,
                onTap: () => onFilter(_PaymentFilter.all),
              ),
              _FilterButton(
                label: 'Activos',
                selected: filter == _PaymentFilter.active,
                onTap: () => onFilter(_PaymentFilter.active),
              ),
              _FilterButton(
                label: 'Inactivos',
                selected: filter == _PaymentFilter.inactive,
                onTap: () => onFilter(_PaymentFilter.inactive),
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

class _PaymentTypeWorkspace extends StatelessWidget {
  const _PaymentTypeWorkspace({
    required this.items,
    required this.selected,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });
  final List<PaymentTypeModel> items;
  final PaymentTypeModel? selected;
  final _PaymentSort sort;
  final bool ascending;
  final ValueChanged<_PaymentSort> onSort;
  final ValueChanged<PaymentTypeModel> onSelect;
  final ValueChanged<PaymentTypeModel> onEdit;
  final ValueChanged<PaymentTypeModel> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final list = _PaymentTypeList(
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
              child: _PaymentTypeDetail(
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

class _PaymentTypeList extends StatelessWidget {
  const _PaymentTypeList({
    required this.items,
    required this.selectedId,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });
  final List<PaymentTypeModel> items;
  final String? selectedId;
  final _PaymentSort sort;
  final bool ascending;
  final ValueChanged<_PaymentSort> onSort;
  final ValueChanged<PaymentTypeModel> onSelect;
  final ValueChanged<PaymentTypeModel> onEdit;
  final ValueChanged<PaymentTypeModel> onDelete;

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
                        label: 'Tipo de pago',
                        active: sort == _PaymentSort.name,
                        ascending: ascending,
                        onTap: () => onSort(_PaymentSort.name),
                      ),
                    ),
                    if (!compact) ...[
                      Expanded(
                        flex: 3,
                        child: _SortButton(
                          label: 'Código',
                          active: sort == _PaymentSort.code,
                          ascending: ascending,
                          onTap: () => onSort(_PaymentSort.code),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _SortButton(
                          label: 'Estado',
                          active: sort == _PaymentSort.status,
                          ascending: ascending,
                          onTap: () => onSort(_PaymentSort.status),
                        ),
                      ),
                      const SizedBox(width: 100),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  key: const PageStorageKey('pulso-payment-types-list'),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: tokens.line),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _PaymentTypeRow(
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

class _PaymentTypeRow extends StatelessWidget {
  const _PaymentTypeRow({
    super.key,
    required this.item,
    required this.selected,
    required this.compact,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });
  final PaymentTypeModel item;
  final bool selected;
  final bool compact;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final code = item.code?.isNotEmpty == true ? item.code!.toUpperCase() : '—';
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
                color: item.active ? tokens.successSoft : tokens.raised,
                child: Icon(
                  item.active ? Icons.payments_outlined : Icons.pause_outlined,
                  size: 18,
                  color: item.active ? tokens.success : tokens.muted,
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
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: item.active ? tokens.chalk : tokens.muted,
                      ),
                    ),
                    if (compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$code · ${item.active ? 'activo' : 'inactivo'}',
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 9.5,
                          color: item.active ? tokens.success : tokens.warning,
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
                    code,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontWeight: FontWeight.w600,
                      color: tokens.chalkDim,
                    ),
                  ),
                ),
                Expanded(flex: 3, child: _PaymentStatus(active: item.active)),
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

class _PaymentStatus extends StatelessWidget {
  const _PaymentStatus({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = active ? tokens.success : tokens.warning;
    return Row(
      children: [
        Container(width: 6, height: 6, color: color),
        const SizedBox(width: 7),
        Text(
          active ? 'ACTIVO' : 'INACTIVO',
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _PaymentTypeDetail extends StatelessWidget {
  const _PaymentTypeDetail({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });
  final PaymentTypeModel? item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final paymentType = item;
    if (paymentType == null) {
      return const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.empty,
          message: 'Selecciona un tipo de pago para ver su detalle.',
        ),
      );
    }
    final code = paymentType.code?.isNotEmpty == true
        ? paymentType.code!.toUpperCase()
        : '—';
    return PulsoPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PulsoLabel('Detalle seleccionado'),
          const SizedBox(height: 18),
          Text(
            code,
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
          const SizedBox(height: 9),
          Text(paymentType.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 22),
          _DetailLine(label: 'Código', value: code),
          _DetailLine(
            label: 'Estado',
            value: paymentType.active ? 'Activo' : 'Inactivo',
          ),
          const Spacer(),
          GlobalCatalogAuthority(
            readOnly: const Text('Catálogo global · solo lectura'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PulsoPrimaryButton(
                  label: 'Editar tipo',
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
            paymentType.id,
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

class _PaymentFooter extends StatelessWidget {
  const _PaymentFooter();
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Row(
      children: [
        const PulsoSyncStatus(compact: true),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'PULSO · TIPOS DE PAGO · DATOS REALES',
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
