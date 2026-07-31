import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../clients/domain/plan_associates.dart';
import '../../../clients/presentation/state/client_notifier.dart';
import '../../../clients/presentation/state/clients_scope_filter_provider.dart';
import '../../../dashboard/presentation/state/dashboard_nav_provider.dart';
import '../../../financials/data/models/currency_model.dart';
import '../../../financials/presentation/state/currency_notifier.dart';
import '../../../statistics/presentation/state/statistics_providers.dart';
import '../../data/models/payment_plan_model.dart';
import '../state/payment_plan_notifier.dart';
import '../widgets/payment_plan_pulso_form.dart';

enum _PlanFilter { all, active, inactive }

enum _PlanSort { name, price, duration, clients }

final _moneyFmt = NumberFormat('#,##0.00');

/// Índice de la vista de Clientes en el conmutador del panel principal.
const int _clientsViewIndex = 1;

/// Socios activos por plan, derivado del catálogo de clientes.
class _PlanStats {
  const _PlanStats({required this.ready, required this.counts});

  /// `false` mientras el catálogo de clientes no ha cargado: los conteos se
  /// muestran como «—» en lugar de un cero engañoso.
  final bool ready;
  final Map<String, int> counts;

  int of(PaymentPlanModel plan) => plan.id == null ? 0 : counts[plan.id] ?? 0;

  int get assignedTotal =>
      counts.values.fold(0, (total, value) => total + value);
}

class PaymentPlansPulsoView extends ConsumerStatefulWidget {
  const PaymentPlansPulsoView({super.key});

  @override
  ConsumerState<PaymentPlansPulsoView> createState() =>
      _PaymentPlansPulsoViewState();
}

class _PaymentPlansPulsoViewState extends ConsumerState<PaymentPlansPulsoView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  String? _selectedId;
  _PlanFilter _filter = _PlanFilter.all;
  _PlanSort _sort = _PlanSort.name;
  bool _ascending = true;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<PaymentPlanModel> _visible(
    List<PaymentPlanModel> all,
    Map<String, CurrencyModel> currencyMap,
    _PlanStats stats,
  ) {
    final query = _query.trim().toLowerCase();
    final result = all.where((plan) {
      final currency = currencyMap[plan.monedaId];
      final haystack = [
        plan.nombre,
        // El código es lo que el operador teclea para encontrar un plan
        // concreto; sin él, buscar «PCU-3» no devolvía nada.
        plan.codigo,
        plan.formattedDuration,
        plan.importe.toString(),
        currency?.code,
        currency?.name,
      ].whereType<String>().join(' ').toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      final matchesFilter = switch (_filter) {
        _PlanFilter.all => true,
        _PlanFilter.active => plan.activo,
        _PlanFilter.inactive => !plan.activo,
      };
      return matchesQuery && matchesFilter;
    }).toList();
    int compare(PaymentPlanModel a, PaymentPlanModel b) {
      final value = switch (_sort) {
        _PlanSort.name => a.nombre.toLowerCase().compareTo(
          b.nombre.toLowerCase(),
        ),
        _PlanSort.price => a.importe.compareTo(b.importe),
        _PlanSort.duration => a.duracion.compareTo(b.duracion),
        _PlanSort.clients => stats.of(a).compareTo(stats.of(b)),
      };
      return _ascending ? value : -value;
    }

    result.sort(compare);
    return result;
  }

  void _setSort(_PlanSort sort) {
    setState(() {
      if (_sort == sort) {
        _ascending = !_ascending;
      } else {
        _sort = sort;
        // Por socios interesa primero el plan con más membresías.
        _ascending = sort != _PlanSort.clients;
      }
    });
  }

  Future<void> _openForm([PaymentPlanModel? plan]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentPlanPulsoForm(
        plan: plan,
        onSubmit: (updated) async {
          final notifier = ref.read(paymentPlanProvider.notifier);
          if (plan == null) {
            return notifier.create(updated);
          }
          await notifier.updatePlan(updated);
          return null;
        },
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          plan == null
              ? 'Nuevo plan creado.'
              : '“${plan.nombre}” fue actualizado.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(PaymentPlanModel plan, _PlanStats stats) async {
    final tokens = PulsoTokens.of(context);
    final count = stats.of(plan);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PulsoThemeScope(
        child: AlertDialog(
          title: const Text('Eliminar plan'),
          content: Text(
            stats.ready && count > 0
                ? 'Se eliminará “${plan.nombre}”. Hay $count socio${count == 1 ? '' : 's'} '
                      'con este plan asignado; sus expedientes no se modifican.'
                : 'Se eliminará “${plan.nombre}” (${plan.formattedDuration}) del catálogo.',
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
    if (confirmed != true || plan.id == null) return;
    try {
      await ref.read(paymentPlanProvider.notifier).delete(plan.id!);
      if (!mounted) return;
      if (_selectedId == plan.id) setState(() => _selectedId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“${plan.nombre}” fue eliminado.')),
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

  _PlanStats _buildStats(List<PaymentPlanModel> all) {
    final clients = ref.watch(clientNotifierProvider).value;
    if (clients == null) {
      return const _PlanStats(ready: false, counts: {});
    }
    // El criterio de «asociado» es el mismo que usa la lista de Clientes a la
    // que lleva el contador (docs/PLAN_ASOCIADOS.md §5). Contar aquí por otro
    // camino sería la forma segura de enseñar 15 y encontrar 12.
    return _PlanStats(
      ready: true,
      counts: countAssociatesByPlan(
        clients,
        planIds: {
          for (final plan in all)
            if (plan.id != null) plan.id!,
        },
        today: todayInZone(appClock.gymTimezone),
      ),
    );
  }

  /// Lleva a Clientes con este plan ya filtrado (opción A del diseño).
  void _showAssociates(PaymentPlanModel plan) {
    final planId = plan.id;
    if (planId == null || planId.isEmpty) return;
    ref
        .read(clientsScopeFilterProvider.notifier)
        .showPlan(planId: planId, planName: plan.nombre);
    ref.read(dashboardNavProvider.notifier).setIndex(_clientsViewIndex);
  }

  void _showPlanStatistics(PaymentPlanModel plan) {
    final planId = plan.id;
    if (planId == null || planId.isEmpty) return;
    ref.read(selectedPlanProvider.notifier).select(planId);
    ref.read(dashboardNavProvider.notifier).setIndex(30);
  }

  void _showDetail(
    BuildContext context,
    PaymentPlanModel plan,
    Map<String, CurrencyModel> currencyMap,
    _PlanStats stats,
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
            height: 620,
            child: _PlanDetail(
              plan: plan,
              currency: currencyMap[plan.monedaId],
              stats: stats,
              onEdit: () {
                Navigator.of(dialogContext).pop();
                _openForm(plan);
              },
              onDelete: () {
                Navigator.of(dialogContext).pop();
                _confirmDelete(plan, stats);
              },
              onAssociates: () {
                Navigator.of(dialogContext).pop();
                _showAssociates(plan);
              },
              onStatistics: () {
                Navigator.of(dialogContext).pop();
                _showPlanStatistics(plan);
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
    final state = ref.watch(paymentPlanProvider);
    final all = state.value ?? const <PaymentPlanModel>[];
    final currencyMap = <String, CurrencyModel>{
      for (final currency
          in ref.watch(currencyProvider).value ?? const <CurrencyModel>[])
        currency.id: currency,
    };
    final stats = _buildStats(all);
    final visible = _visible(all, currencyMap, stats);
    final active = all.where((plan) => plan.activo).length;
    PaymentPlanModel? leader;
    for (final plan in all) {
      if (stats.of(plan) == 0) continue;
      if (leader == null || stats.of(plan) > stats.of(leader)) leader = plan;
    }
    PaymentPlanModel? selected;
    for (final plan in all) {
      if (plan.id != null && plan.id == _selectedId) selected = plan;
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
              message: 'Cargando el catálogo de tarifas…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message: 'No se pudo cargar el catálogo.\n$error',
              onRetry: () => ref.invalidate(paymentPlanProvider),
            ),
          ),
          data: (_) => visible.isEmpty
              ? PulsoPanel(
                  child: PulsoStateView(
                    kind: PulsoStateKind.empty,
                    message: all.isEmpty
                        ? 'Todavía no hay planes registrados.'
                        : 'Ningún plan coincide con la búsqueda.',
                  ),
                )
              : _PlanWorkspace(
                  items: visible,
                  currencyMap: currencyMap,
                  stats: stats,
                  selected: workspaceWide ? selected : null,
                  sort: _sort,
                  ascending: _ascending,
                  onSort: _setSort,
                  onSelect: (plan) {
                    if (workspaceWide) {
                      setState(() => _selectedId = plan.id);
                    } else {
                      _showDetail(context, plan, currencyMap, stats);
                    }
                  },
                  onEdit: _openForm,
                  onDelete: (plan) => _confirmDelete(plan, stats),
                  onAssociates: _showAssociates,
                  onStatistics: _showPlanStatistics,
                ),
        );
        final page = Column(
          mainAxisSize: scrollPage ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PlanHeader(onCreate: () => _openForm()),
            const SizedBox(height: 14),
            PulsoMetricStrip(
              metrics: [
                PulsoMetricData(
                  value: '${all.length}',
                  label: 'Planes',
                  note: 'catálogo de tarifas',
                  emphasis: true,
                ),
                PulsoMetricData(
                  value: '$active',
                  label: 'Activos',
                  note: '${all.length - active} inactivos',
                  warning: all.length - active > 0,
                ),
                PulsoMetricData(
                  value: stats.ready ? '${stats.assignedTotal}' : '—',
                  label: 'Socios con plan',
                  note: 'membresías activas asignadas',
                ),
                PulsoMetricData(
                  value: leader == null ? '—' : '${stats.of(leader)}',
                  label: 'Plan líder',
                  note: leader?.nombre ?? 'sin socios todavía',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PlanCommand(
              controller: _searchController,
              focusNode: _searchFocus,
              filter: _filter,
              onSearch: (value) => setState(() => _query = value),
              onFilter: (value) => setState(() => _filter = value),
              onRefresh: () => ref.invalidate(paymentPlanProvider),
            ),
            const SizedBox(height: 12),
            if (scrollPage)
              SizedBox(height: 360, child: catalog)
            else
              Expanded(child: catalog),
            const SizedBox(height: 8),
            const _PlanFooter(),
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

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PulsoLabel('PULSO · TARIFAS'),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                text: 'PLANES Y TARIFAS',
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
              'Define las membresías, su precio y cuántos socios sostiene cada una.',
              style: TextStyle(color: tokens.muted, fontSize: 14),
            ),
          ],
        );
        final action = PulsoPrimaryButton(
          label: 'Nuevo plan',
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

class _PlanCommand extends StatelessWidget {
  const _PlanCommand({
    required this.controller,
    required this.focusNode,
    required this.filter,
    required this.onSearch,
    required this.onFilter,
    required this.onRefresh,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final _PlanFilter filter;
  final ValueChanged<String> onSearch;
  final ValueChanged<_PlanFilter> onFilter;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return PulsoPanel(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            key: const ValueKey('pulso-plan-search'),
            controller: controller,
            focusNode: focusNode,
            onChanged: onSearch,
            decoration: const InputDecoration(
              hintText: 'Buscar plan, duración, precio o moneda…',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          );
          final controls = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _FilterButton(
                label: 'Todos',
                selected: filter == _PlanFilter.all,
                onTap: () => onFilter(_PlanFilter.all),
              ),
              _FilterButton(
                label: 'Activos',
                selected: filter == _PlanFilter.active,
                onTap: () => onFilter(_PlanFilter.active),
              ),
              _FilterButton(
                label: 'Inactivos',
                selected: filter == _PlanFilter.inactive,
                onTap: () => onFilter(_PlanFilter.inactive),
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

class _PlanWorkspace extends StatelessWidget {
  const _PlanWorkspace({
    required this.items,
    required this.currencyMap,
    required this.stats,
    required this.selected,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onAssociates,
    required this.onStatistics,
  });
  final List<PaymentPlanModel> items;
  final Map<String, CurrencyModel> currencyMap;
  final _PlanStats stats;
  final PaymentPlanModel? selected;
  final _PlanSort sort;
  final bool ascending;
  final ValueChanged<_PlanSort> onSort;
  final ValueChanged<PaymentPlanModel> onSelect;
  final ValueChanged<PaymentPlanModel> onEdit;
  final ValueChanged<PaymentPlanModel> onDelete;
  final ValueChanged<PaymentPlanModel> onAssociates;
  final ValueChanged<PaymentPlanModel> onStatistics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final list = _PlanList(
          items: items,
          currencyMap: currencyMap,
          stats: stats,
          selectedId: selected?.id,
          sort: sort,
          ascending: ascending,
          onSort: onSort,
          onSelect: onSelect,
          onEdit: onEdit,
          onDelete: onDelete,
          onAssociates: onAssociates,
        );
        if (constraints.maxWidth < 1040) return list;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: list),
            const SizedBox(width: 12),
            SizedBox(
              width: 330,
              child: _PlanDetail(
                plan: selected,
                currency: selected == null
                    ? null
                    : currencyMap[selected!.monedaId],
                stats: stats,
                onEdit: selected == null ? null : () => onEdit(selected!),
                onDelete: selected == null ? null : () => onDelete(selected!),
                onAssociates: selected == null
                    ? null
                    : () => onAssociates(selected!),
                onStatistics: selected == null
                    ? null
                    : () => onStatistics(selected!),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlanList extends StatelessWidget {
  const _PlanList({
    required this.items,
    required this.currencyMap,
    required this.stats,
    required this.selectedId,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onAssociates,
  });
  final List<PaymentPlanModel> items;
  final Map<String, CurrencyModel> currencyMap;
  final _PlanStats stats;
  final String? selectedId;
  final _PlanSort sort;
  final bool ascending;
  final ValueChanged<_PlanSort> onSort;
  final ValueChanged<PaymentPlanModel> onSelect;
  final ValueChanged<PaymentPlanModel> onEdit;
  final ValueChanged<PaymentPlanModel> onDelete;
  final ValueChanged<PaymentPlanModel> onAssociates;

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
                        label: 'Plan',
                        active: sort == _PlanSort.name,
                        ascending: ascending,
                        onTap: () => onSort(_PlanSort.name),
                      ),
                    ),
                    if (!compact) ...[
                      Expanded(
                        flex: 3,
                        child: _SortButton(
                          label: 'Tarifa',
                          active: sort == _PlanSort.price,
                          ascending: ascending,
                          onTap: () => onSort(_PlanSort.price),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _SortButton(
                          label: 'Duración',
                          active: sort == _PlanSort.duration,
                          ascending: ascending,
                          onTap: () => onSort(_PlanSort.duration),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _SortButton(
                          label: 'Socios',
                          active: sort == _PlanSort.clients,
                          ascending: ascending,
                          onTap: () => onSort(_PlanSort.clients),
                        ),
                      ),
                      const SizedBox(width: 100),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  key: const PageStorageKey('pulso-plans-list'),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: tokens.line),
                  itemBuilder: (context, index) {
                    final plan = items[index];
                    return _PlanRow(
                      key: ValueKey(plan.id ?? plan.nombre),
                      plan: plan,
                      currency: currencyMap[plan.monedaId],
                      stats: stats,
                      selected: selectedId != null && selectedId == plan.id,
                      compact: compact,
                      onSelect: () => onSelect(plan),
                      onEdit: () => onEdit(plan),
                      onDelete: () => onDelete(plan),
                      onAssociates: () => onAssociates(plan),
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
                  '${items.length} resultados · asociados por plan',
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

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    super.key,
    required this.plan,
    required this.currency,
    required this.stats,
    required this.selected,
    required this.compact,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onAssociates,
  });
  final PaymentPlanModel plan;
  final CurrencyModel? currency;
  final _PlanStats stats;
  final bool selected;
  final bool compact;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAssociates;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final symbol = currency?.symbol ?? r'$';
    final code = currency?.code.toUpperCase() ?? '';
    final price =
        '$symbol ${_moneyFmt.format(plan.importe)}'
        '${code.isEmpty ? '' : ' $code'}';
    final count = stats.of(plan);
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
        ? (plan.activo ? tokens.warning : tokens.muted)
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
              PulsoFlag(
                code: currency?.code ?? '¤¤',
                base64String: currency?.flagImage,
                width: 33,
                height: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: plan.activo ? tokens.chalk : tokens.muted,
                      ),
                    ),
                    if (compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$price · ${plan.formattedDuration} · $membersLabel',
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
                  child: Text(
                    price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                    plan.formattedDuration,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 11,
                      color: tokens.muted,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _AssociatesCell(
                    label: membersLabel,
                    color: membersColor,
                    planName: plan.nombre,
                    // Sin asociados no hay a quién ir a ver: el contador se
                    // queda como texto y no promete una lista vacía.
                    onTap: stats.ready && count > 0 ? onAssociates : null,
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      PulsoIconButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Editar ${plan.nombre}',
                        onPressed: onEdit,
                      ),
                      const SizedBox(width: 4),
                      PulsoIconButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Eliminar ${plan.nombre}',
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
                    if (value == 'associates') onAssociates();
                  },
                  itemBuilder: (context) => [
                    if (stats.ready && count > 0)
                      const PopupMenuItem(
                        value: 'associates',
                        child: Text('Ver asociados'),
                      ),
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Contador de asociados de la fila. Cuando hay a quién enseñar, lleva a
/// Clientes con el plan filtrado; cuando no, es texto y ya.
class _AssociatesCell extends StatelessWidget {
  const _AssociatesCell({
    required this.label,
    required this.color,
    required this.planName,
    required this.onTap,
  });

  final String label;
  final Color color;
  final String planName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: PulsoFonts.mono,
        fontWeight: FontWeight.w600,
        color: color,
        decoration: onTap == null ? null : TextDecoration.underline,
        decorationColor: color,
      ),
    );
    if (onTap == null) return text;
    return Tooltip(
      message: 'Ver los asociados de $planName en Clientes',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: text,
        ),
      ),
    );
  }
}

class _PlanDetail extends StatelessWidget {
  const _PlanDetail({
    required this.plan,
    required this.currency,
    required this.stats,
    required this.onEdit,
    required this.onDelete,
    required this.onAssociates,
    required this.onStatistics,
  });
  final PaymentPlanModel? plan;
  final CurrencyModel? currency;
  final _PlanStats stats;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAssociates;
  final VoidCallback? onStatistics;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final selected = plan;
    if (selected == null) {
      return const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.empty,
          message: 'Selecciona un plan para ver su detalle.',
        ),
      );
    }
    final symbol = currency?.symbol ?? r'$';
    final count = stats.of(selected);
    final perDay = selected.duracion <= 0
        ? '—'
        : '$symbol ${_moneyFmt.format(selected.importe / selected.duracion)}';
    // Estimación de lectura: asociados × importe normalizado a 30 días.
    final monthly = !stats.ready || selected.duracion <= 0
        ? '—'
        : '$symbol ${_moneyFmt.format(count * selected.importe * 30 / selected.duracion)}';
    final trainer = !selected.incluyeEntrenador
        ? '—'
        : selected.comisionEntrenadorTipo == 'PERCENTAGE'
        ? '${_moneyFmt.format(selected.comisionEntrenadorValor ?? 0)} %'
        : '$symbol ${_moneyFmt.format(selected.comisionEntrenadorValor ?? 0)}';
    return PulsoPanel(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PulsoLabel('Detalle seleccionado'),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '$symbol ${_moneyFmt.format(selected.importe)}',
                maxLines: 1,
                style: TextStyle(
                  fontFamily: PulsoFonts.display,
                  fontSize: 48,
                  height: 0.9,
                  fontWeight: FontWeight.w800,
                  color: tokens.accent,
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              selected.nombre,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              selected.activo ? 'ACTIVO' : 'INACTIVO',
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: selected.activo ? tokens.success : tokens.muted,
              ),
            ),
            const SizedBox(height: 12),
            _DetailLine(
              label: 'Duración',
              value: '${selected.formattedDuration} · ${selected.duracion} d',
            ),
            _DetailLine(label: 'Por día', value: perDay),
            // El número es el enlace: lleva a Clientes con este plan filtrado.
            // Se prefiere aquí, y no un botón aparte, para no crecer el panel.
            _DetailLine(
              key: const ValueKey('plan-detail-associates'),
              label: 'Asociados',
              value: stats.ready ? '$count' : '—',
              onTap: stats.ready && count > 0 ? onAssociates : null,
              tooltip: 'Ver los asociados de ${selected.nombre} en Clientes',
            ),
            _DetailLine(label: 'Ingreso/mes est.', value: monthly),
            _DetailLine(label: 'Comisión entrenador', value: trainer),
            const SizedBox(height: 18),
            PulsoPrimaryButton(
              label: 'Ver estadística',
              icon: Icons.insights_outlined,
              onPressed: onStatistics,
            ),
            const SizedBox(height: 8),
            PulsoSecondaryButton(
              label: 'Editar plan',
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
              selected.id ?? '—',
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
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.tooltip,
  });
  final String label;
  final String value;
  final VoidCallback? onTap;
  final String? tooltip;
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final text = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: PulsoFonts.mono,
        fontWeight: FontWeight.w600,
        color: onTap == null ? tokens.chalkDim : tokens.accent,
        decoration: onTap == null ? null : TextDecoration.underline,
        decorationColor: onTap == null ? null : tokens.accent,
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: [
          Expanded(child: PulsoLabel(label)),
          Flexible(
            child: onTap == null
                ? text
                : Tooltip(
                    message: tooltip ?? '',
                    child: InkWell(onTap: onTap, child: text),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlanFooter extends StatelessWidget {
  const _PlanFooter();
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Row(
      children: [
        const PulsoSyncStatus(compact: true),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'PULSO · PLANES Y TARIFAS · DATOS REALES',
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
