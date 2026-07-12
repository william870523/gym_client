import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../payments/presentation/state/payment_notifier.dart';
import '../../../payments/presentation/widgets/process_payment_dialog.dart';
import '../../../products/data/models/payment_plan_model.dart';
import '../../../products/presentation/state/payment_plan_notifier.dart';
import '../../../schedules/data/models/horario_model.dart';
import '../../../schedules/presentation/state/horario_notifier.dart';
import '../../../trainers/data/models/trainer_model.dart';
import '../../../trainers/presentation/providers/trainer_notifier.dart';
import '../../data/models/client_model.dart';
import '../state/client_notifier.dart';
import '../state/weight_history_notifier.dart';
import '../widgets/add_weight_pulso_dialog.dart';
import '../widgets/client_form.dart';

enum _ClientFilter { all, active, attention, inactive }

enum _ClientSort { name, plan, validity }

enum _MembershipState { active, expiring, expired, noPlan, inactive }

String _name(ClientModel client) {
  final value = '${client.nombres ?? ''} ${client.apellidos ?? ''}'.trim();
  return value.isEmpty ? client.id : value;
}

_MembershipState _membership(ClientModel client, DateTime today) {
  if (!client.activo) return _MembershipState.inactive;
  if (client.planId == null ||
      client.planId!.isEmpty ||
      client.endDate == null) {
    return _MembershipState.noPlan;
  }
  final end = DateTime.utc(
    client.endDate!.year,
    client.endDate!.month,
    client.endDate!.day,
  );
  final day = DateTime.utc(today.year, today.month, today.day);
  final remaining = end.difference(day).inDays;
  if (remaining < 0) return _MembershipState.expired;
  if (remaining <= 7) return _MembershipState.expiring;
  return _MembershipState.active;
}

String _membershipLabel(_MembershipState state) => switch (state) {
  _MembershipState.active => 'Vigente',
  _MembershipState.expiring => 'Por vencer',
  _MembershipState.expired => 'Vencida',
  _MembershipState.noPlan => 'Sin plan',
  _MembershipState.inactive => 'Inactivo',
};

String _nextAction(ClientModel client, _MembershipState state) {
  if (state == _MembershipState.inactive) return 'Revisar estado del socio';
  if (state == _MembershipState.expired) return 'Renovar membresía';
  if (state == _MembershipState.expiring) return 'Preparar renovación';
  if (state == _MembershipState.noPlan) return 'Asignar plan';
  if (client.telefono == null && (client.correo?.trim().isEmpty ?? true)) {
    return 'Completar contacto';
  }
  if (client.trainerId == null) return 'Evaluar entrenador';
  if (client.scheduleId == null) return 'Acordar horario';
  return 'Seguimiento normal';
}

class ClientsPulsoView extends ConsumerStatefulWidget {
  const ClientsPulsoView({super.key});

  @override
  ConsumerState<ClientsPulsoView> createState() => _ClientsPulsoViewState();
}

class _ClientsPulsoViewState extends ConsumerState<ClientsPulsoView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  String? _selectedId;
  _ClientFilter _filter = _ClientFilter.all;
  _ClientSort _sort = _ClientSort.name;
  bool _ascending = true;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<ClientModel> _visible(
    List<ClientModel> all,
    Map<String, String> plans,
    DateTime today,
  ) {
    final query = _query.trim().toLowerCase();
    final result = all.where((client) {
      final state = _membership(client, today);
      final plan = plans[client.planId] ?? 'Sin plan';
      final haystack =
          '${_name(client)} ${client.id} ${client.correo ?? ''} ${client.telefono ?? ''} $plan ${_membershipLabel(state)}'
              .toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      final matchesFilter = switch (_filter) {
        _ClientFilter.all => true,
        _ClientFilter.active => state == _MembershipState.active,
        _ClientFilter.attention =>
          state == _MembershipState.expiring ||
              state == _MembershipState.expired ||
              state == _MembershipState.noPlan,
        _ClientFilter.inactive => state == _MembershipState.inactive,
      };
      return matchesQuery && matchesFilter;
    }).toList();
    int compare(ClientModel a, ClientModel b) {
      final value = switch (_sort) {
        _ClientSort.name => _name(
          a,
        ).toLowerCase().compareTo(_name(b).toLowerCase()),
        _ClientSort.plan => (plans[a.planId] ?? '').compareTo(
          plans[b.planId] ?? '',
        ),
        _ClientSort.validity => (a.endDate ?? DateTime.utc(1900)).compareTo(
          b.endDate ?? DateTime.utc(1900),
        ),
      };
      return _ascending ? value : -value;
    }

    result.sort(compare);
    return result;
  }

  void _setSort(_ClientSort sort) {
    setState(() {
      if (_sort == sort) {
        _ascending = !_ascending;
      } else {
        _sort = sort;
        _ascending = true;
      }
    });
  }

  Future<void> _openForm([ClientModel? client]) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PulsoThemeScope(child: ClientForm(client: client)),
    );
  }

  Future<void> _confirmDelete(ClientModel client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PulsoThemeScope(
        child: AlertDialog(
          title: const Text('Eliminar socio'),
          content: Text(
            'Se eliminará a “${_name(client)}” y su acceso activo.',
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
      await ref.read(clientNotifierProvider.notifier).deleteClient(client.id);
      if (!mounted) return;
      if (_selectedId == client.id) setState(() => _selectedId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“${_name(client)}” fue eliminado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $error')));
    }
  }

  Future<void> _addWeight(ClientModel client) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AddWeightPulsoDialog(
        client: client,
        onSubmit: (weight) => ref
            .read(clientNotifierProvider.notifier)
            .addWeight(client.id, weight, appClock.nowUtc()),
      ),
    );
    if (saved == true) ref.invalidate(weightHistoryProvider(client.id));
  }

  void _processPayment(ClientModel client) {
    final planId = client.planId;
    if (planId == null || planId.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          ProcessPaymentDialog(client: client, planId: planId),
    ).then((_) => ref.invalidate(clientPaymentHistoryProvider(client.id)));
  }

  void _showDetail(
    ClientModel client,
    Map<String, String> plans,
    Map<String, String> trainers,
    Map<String, String> schedules,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => PulsoThemeScope(
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: SizedBox(
            width: 430,
            height: 690,
            child: _ClientInsight(
              client: client,
              plan: plans[client.planId] ?? 'Sin plan',
              trainer: trainers[client.trainerId] ?? 'Sin entrenador',
              schedule: schedules[client.scheduleId] ?? 'Sin horario',
              onEdit: () {
                Navigator.of(dialogContext).pop();
                _openForm(client);
              },
              onDelete: () {
                Navigator.of(dialogContext).pop();
                _confirmDelete(client);
              },
              onWeight: () => _addWeight(client),
              onPayment: client.planId == null
                  ? null
                  : () => _processPayment(client),
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
    final clientsState = ref.watch(clientNotifierProvider);
    final plansState = ref.watch(paymentPlanProvider);
    final trainersState = ref.watch(trainerProvider);
    final schedulesState = ref.watch(horarioNotifierProvider);
    final plans = {
      for (final plan in plansState.value ?? const <PaymentPlanModel>[])
        if (plan.id != null) plan.id!: plan.nombre,
    };
    final trainers = {
      for (final trainer in trainersState.value ?? const <TrainerModel>[])
        trainer.id: '${trainer.nombres ?? ''} ${trainer.apellidos ?? ''}'
            .trim(),
    };
    final schedules = {
      for (final schedule in schedulesState.value ?? const <HorarioModel>[])
        schedule.id: schedule.nombre,
    };
    final all = clientsState.value ?? const <ClientModel>[];
    final today = todayInZone(appClock.gymTimezone);
    final visible = _visible(all, plans, today);
    final states = [for (final client in all) _membership(client, today)];
    final active = states
        .where((state) => state == _MembershipState.active)
        .length;
    final expiring = states
        .where((state) => state == _MembershipState.expiring)
        .length;
    final attention = states.where((state) {
      return state == _MembershipState.expiring ||
          state == _MembershipState.expired ||
          state == _MembershipState.noPlan;
    }).length;
    ClientModel? selected;
    for (final client in all) {
      if (client.id == _selectedId) selected = client;
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
        final workspaceWide = constraints.maxWidth - (padding * 2) >= 1120;
        final catalog = clientsState.when(
          loading: () => const PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.loading,
              message: 'Cargando socios…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message: 'No se pudo cargar el registro.\n$error',
              onRetry: () =>
                  ref.read(clientNotifierProvider.notifier).refresh(),
            ),
          ),
          data: (_) => visible.isEmpty
              ? PulsoPanel(
                  child: PulsoStateView(
                    kind: PulsoStateKind.empty,
                    message: all.isEmpty
                        ? 'Todavía no hay socios registrados.'
                        : 'Ningún socio coincide con la consulta.',
                  ),
                )
              : _ClientWorkspace(
                  items: visible,
                  selected: workspaceWide ? selected : null,
                  plans: plans,
                  trainers: trainers,
                  schedules: schedules,
                  today: today,
                  sort: _sort,
                  ascending: _ascending,
                  onSort: _setSort,
                  onSelect: (client) {
                    if (workspaceWide) {
                      setState(() => _selectedId = client.id);
                    } else {
                      _showDetail(client, plans, trainers, schedules);
                    }
                  },
                  onEdit: _openForm,
                  onDelete: _confirmDelete,
                  onWeight: _addWeight,
                  onPayment: _processPayment,
                ),
        );
        final page = Column(
          mainAxisSize: scrollPage ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ClientHeader(onCreate: () => _openForm()),
            const SizedBox(height: 14),
            PulsoMetricStrip(
              metrics: [
                PulsoMetricData(
                  value: '${all.length}',
                  label: 'Socios',
                  note: 'registro total',
                  emphasis: true,
                ),
                PulsoMetricData(
                  value: '$active',
                  label: 'Vigentes',
                  note: 'sin alerta inmediata',
                ),
                PulsoMetricData(
                  value: '$expiring',
                  label: 'Por vencer',
                  note: 'próximos 7 días',
                  warning: expiring > 0,
                ),
                PulsoMetricData(
                  value: '$attention',
                  label: 'Atención',
                  note: 'renovar o asignar',
                  warning: attention > 0,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ClientCommand(
              controller: _searchController,
              focusNode: _searchFocus,
              filter: _filter,
              onSearch: (value) => setState(() => _query = value),
              onFilter: (value) => setState(() => _filter = value),
              onRefresh: () =>
                  ref.read(clientNotifierProvider.notifier).refresh(),
            ),
            const SizedBox(height: 12),
            if (scrollPage)
              SizedBox(height: 410, child: catalog)
            else
              Expanded(child: catalog),
            const SizedBox(height: 8),
            const _ClientFooter(),
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

class _ClientHeader extends StatelessWidget {
  const _ClientHeader({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PulsoLabel('PULSO · SOCIOS'),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                text: 'CLIENTES',
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
              'Identidad, vigencia y señales de seguimiento en una sola lectura.',
              style: TextStyle(color: tokens.muted, fontSize: 14),
            ),
          ],
        );
        final action = PulsoPrimaryButton(
          label: 'Nuevo socio',
          icon: Icons.person_add_alt_1_outlined,
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

class _ClientCommand extends StatelessWidget {
  const _ClientCommand({
    required this.controller,
    required this.focusNode,
    required this.filter,
    required this.onSearch,
    required this.onFilter,
    required this.onRefresh,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final _ClientFilter filter;
  final ValueChanged<String> onSearch;
  final ValueChanged<_ClientFilter> onFilter;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return PulsoPanel(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            key: const ValueKey('pulso-client-search'),
            controller: controller,
            focusNode: focusNode,
            onChanged: onSearch,
            decoration: const InputDecoration(
              hintText: 'Buscar nombre, documento, contacto o plan…',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          );
          final controls = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _FilterButton(
                label: 'Todos',
                selected: filter == _ClientFilter.all,
                onTap: () => onFilter(_ClientFilter.all),
              ),
              _FilterButton(
                label: 'Vigentes',
                selected: filter == _ClientFilter.active,
                onTap: () => onFilter(_ClientFilter.active),
              ),
              _FilterButton(
                label: 'Atención',
                selected: filter == _ClientFilter.attention,
                onTap: () => onFilter(_ClientFilter.attention),
              ),
              _FilterButton(
                label: 'Inactivos',
                selected: filter == _ClientFilter.inactive,
                onTap: () => onFilter(_ClientFilter.inactive),
              ),
              PulsoIconButton(
                icon: Icons.refresh,
                tooltip: 'Actualizar',
                onPressed: onRefresh,
              ),
            ],
          );
          return constraints.maxWidth < 850
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

class _ClientWorkspace extends StatelessWidget {
  const _ClientWorkspace({
    required this.items,
    required this.selected,
    required this.plans,
    required this.trainers,
    required this.schedules,
    required this.today,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onWeight,
    required this.onPayment,
  });
  final List<ClientModel> items;
  final ClientModel? selected;
  final Map<String, String> plans;
  final Map<String, String> trainers;
  final Map<String, String> schedules;
  final DateTime today;
  final _ClientSort sort;
  final bool ascending;
  final ValueChanged<_ClientSort> onSort;
  final ValueChanged<ClientModel> onSelect;
  final ValueChanged<ClientModel> onEdit;
  final ValueChanged<ClientModel> onDelete;
  final ValueChanged<ClientModel> onWeight;
  final ValueChanged<ClientModel> onPayment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final list = _ClientList(
          items: items,
          selectedId: selected?.id,
          plans: plans,
          today: today,
          sort: sort,
          ascending: ascending,
          onSort: onSort,
          onSelect: onSelect,
          onEdit: onEdit,
          onDelete: onDelete,
        );
        if (constraints.maxWidth < 1120) return list;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: list),
            const SizedBox(width: 12),
            SizedBox(
              width: 380,
              child: selected == null
                  ? const PulsoPanel(
                      child: PulsoStateView(
                        kind: PulsoStateKind.empty,
                        message:
                            'Selecciona un socio para ver su lectura operativa.',
                      ),
                    )
                  : _ClientInsight(
                      client: selected!,
                      plan: plans[selected!.planId] ?? 'Sin plan',
                      trainer:
                          trainers[selected!.trainerId] ?? 'Sin entrenador',
                      schedule:
                          schedules[selected!.scheduleId] ?? 'Sin horario',
                      onEdit: () => onEdit(selected!),
                      onDelete: () => onDelete(selected!),
                      onWeight: () => onWeight(selected!),
                      onPayment: selected!.planId == null
                          ? null
                          : () => onPayment(selected!),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ClientList extends StatelessWidget {
  const _ClientList({
    required this.items,
    required this.selectedId,
    required this.plans,
    required this.today,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });
  final List<ClientModel> items;
  final String? selectedId;
  final Map<String, String> plans;
  final DateTime today;
  final _ClientSort sort;
  final bool ascending;
  final ValueChanged<_ClientSort> onSort;
  final ValueChanged<ClientModel> onSelect;
  final ValueChanged<ClientModel> onEdit;
  final ValueChanged<ClientModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
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
                        label: 'Socio',
                        active: sort == _ClientSort.name,
                        ascending: ascending,
                        onTap: () => onSort(_ClientSort.name),
                      ),
                    ),
                    if (!compact) ...[
                      Expanded(
                        flex: 3,
                        child: _SortButton(
                          label: 'Plan',
                          active: sort == _ClientSort.plan,
                          ascending: ascending,
                          onTap: () => onSort(_ClientSort.plan),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _SortButton(
                          label: 'Vigencia',
                          active: sort == _ClientSort.validity,
                          ascending: ascending,
                          onTap: () => onSort(_ClientSort.validity),
                        ),
                      ),
                      const Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PulsoLabel('Próxima acción'),
                        ),
                      ),
                      const SizedBox(width: 112),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  key: const PageStorageKey('pulso-clients-list'),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: tokens.line),
                  itemBuilder: (context, index) {
                    final client = items[index];
                    final state = _membership(client, today);
                    return _ClientRow(
                      key: ValueKey(client.id),
                      client: client,
                      plan: plans[client.planId] ?? 'Sin plan',
                      state: state,
                      compact: compact,
                      selected: selectedId == client.id,
                      onSelect: () => onSelect(client),
                      onEdit: () => onEdit(client),
                      onDelete: () => onDelete(client),
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
                  '${items.length} resultados · vigencia calculada en ${appClock.gymTimezone}',
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

class _ClientRow extends StatelessWidget {
  const _ClientRow({
    super.key,
    required this.client,
    required this.plan,
    required this.state,
    required this.compact,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });
  final ClientModel client;
  final String plan;
  final _MembershipState state;
  final bool compact;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final identity = Row(
      children: [
        _ClientAvatar(client: client),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _name(client),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.chalk,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                client.id,
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 10,
                  color: tokens.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return Material(
      color: selected ? tokens.accentSoft : tokens.surface,
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: compact
              ? Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 8),
                    _MembershipChip(state: state),
                  ],
                )
              : Row(
                  children: [
                    Expanded(flex: 4, child: identity),
                    Expanded(
                      flex: 3,
                      child: Text(
                        plan,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: tokens.chalkDim, fontSize: 12),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _MembershipChip(state: state),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        _nextAction(client, state),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: state == _MembershipState.active
                              ? tokens.muted
                              : tokens.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 112,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          PulsoIconButton(
                            icon: Icons.edit_outlined,
                            tooltip: 'Editar ${_name(client)}',
                            onPressed: onEdit,
                          ),
                          const SizedBox(width: 6),
                          PulsoIconButton(
                            icon: Icons.delete_outline,
                            tooltip: 'Eliminar ${_name(client)}',
                            danger: true,
                            onPressed: onDelete,
                          ),
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

class _ClientAvatar extends StatelessWidget {
  const _ClientAvatar({required this.client});
  final ClientModel client;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    Uint8List? bytes;
    if (client.photoUrl != null) {
      try {
        bytes = base64Decode(client.photoUrl!);
      } catch (_) {}
    }
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border.all(color: tokens.line),
        image: bytes == null
            ? null
            : DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
      ),
      child: bytes == null
          ? Icon(Icons.person_outline, color: tokens.muted, size: 20)
          : null,
    );
  }
}

class _MembershipChip extends StatelessWidget {
  const _MembershipChip({required this.state});
  final _MembershipState state;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final (color, soft) = switch (state) {
      _MembershipState.active => (tokens.success, tokens.successSoft),
      _MembershipState.expiring => (tokens.warning, tokens.warningSoft),
      _MembershipState.expired => (tokens.danger, tokens.dangerSoft),
      _MembershipState.noPlan => (tokens.warning, tokens.warningSoft),
      _MembershipState.inactive => (tokens.muted, tokens.raised2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: soft,
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        _membershipLabel(state),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ClientInsight extends ConsumerWidget {
  const _ClientInsight({
    required this.client,
    required this.plan,
    required this.trainer,
    required this.schedule,
    required this.onEdit,
    required this.onDelete,
    required this.onWeight,
    required this.onPayment,
  });
  final ClientModel client;
  final String plan;
  final String trainer;
  final String schedule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onWeight;
  final VoidCallback? onPayment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    final today = todayInZone(appClock.gymTimezone);
    final state = _membership(client, today);
    final payments = ref.watch(clientPaymentHistoryProvider(client.id));
    final weights = ref.watch(weightHistoryProvider(client.id));
    final contactPoints = [
      client.correo?.trim(),
      client.telefono?.toString(),
      client.direccion?.trim(),
    ].where((value) => value != null && value.isNotEmpty).length;
    final end = client.endDate;
    final remaining = end == null
        ? null
        : DateTime.utc(
            end.year,
            end.month,
            end.day,
          ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    return PulsoPanel(
      padding: const EdgeInsets.all(18),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PulsoLabel('LECTURA OPERATIVA'),
            const SizedBox(height: 12),
            Row(
              children: [
                _ClientAvatar(client: client),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name(client),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        client.id,
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          color: tokens.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                _MembershipChip(state: state),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              color: state == _MembershipState.active
                  ? tokens.successSoft
                  : tokens.warningSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PulsoLabel('PRÓXIMA ACCIÓN'),
                  const SizedBox(height: 5),
                  Text(
                    _nextAction(client, state),
                    style: TextStyle(
                      color: state == _MembershipState.active
                          ? tokens.success
                          : tokens.warning,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (remaining != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      remaining >= 0
                          ? '$remaining días de vigencia'
                          : 'Venció hace ${remaining.abs()} días',
                      style: TextStyle(color: tokens.muted, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _InsightLine(label: 'Plan', value: plan),
            _InsightLine(label: 'Entrenador', value: trainer),
            _InsightLine(label: 'Horario', value: schedule),
            _InsightLine(
              label: 'Contacto',
              value: '$contactPoints de 3 datos disponibles',
              warning: contactPoints < 2,
            ),
            const SizedBox(height: 14),
            _HistorySignal(
              label: 'Pagos',
              state: payments,
              empty: 'Sin pagos registrados',
              value: (items) {
                if (items.isEmpty) return 'Sin pagos registrados';
                final sorted = [...items]
                  ..sort((a, b) => b.fecha.compareTo(a.fecha));
                final latest = toGymWallClock(
                  sorted.first.fecha,
                  appClock.gymTimezone,
                );
                return '${items.length} · último ${DateFormat('dd/MM/yyyy').format(latest)}';
              },
            ),
            const SizedBox(height: 8),
            _HistorySignal<Map<String, dynamic>>(
              label: 'Peso',
              state: weights,
              empty: client.peso == null
                  ? 'Sin seguimiento'
                  : '${client.peso!.toStringAsFixed(1)} kg inicial',
              value: (items) {
                if (items.isEmpty) {
                  return client.peso == null
                      ? 'Sin seguimiento'
                      : '${client.peso!.toStringAsFixed(1)} kg inicial';
                }
                final parsed =
                    items
                        .map(
                          (item) => (
                            date: DateTime.tryParse('${item['fecha']}'),
                            value: (item['peso'] as num?)?.toDouble(),
                          ),
                        )
                        .where(
                          (item) => item.date != null && item.value != null,
                        )
                        .toList()
                      ..sort((a, b) => b.date!.compareTo(a.date!));
                if (parsed.isEmpty) return 'Historial sin valores válidos';
                final latest = parsed.first.value!;
                if (parsed.length < 2) {
                  return '${latest.toStringAsFixed(1)} kg · primer registro';
                }
                final delta = latest - parsed[1].value!;
                final direction = delta == 0
                    ? 'sin cambio'
                    : '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg';
                return '${latest.toStringAsFixed(1)} kg · $direction';
              },
            ),
            if (client.estatura_cliente != null &&
                client.estatura_cliente! > 0) ...[
              const SizedBox(height: 8),
              _BmiSignal(client: client, weights: weights.value),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PulsoPrimaryButton(
                  label: 'Editar',
                  icon: Icons.edit_outlined,
                  onPressed: onEdit,
                ),
                PulsoSecondaryButton(
                  label: 'Peso',
                  icon: Icons.monitor_weight_outlined,
                  onPressed: onWeight,
                ),
                if (onPayment != null)
                  PulsoSecondaryButton(
                    label: 'Cobrar',
                    icon: Icons.payments_outlined,
                    onPressed: onPayment,
                  ),
                PulsoIconButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Eliminar socio',
                  danger: true,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightLine extends StatelessWidget {
  const _InsightLine({
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 92, child: PulsoLabel(label)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: warning ? tokens.warning : tokens.chalkDim,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySignal<T> extends StatelessWidget {
  const _HistorySignal({
    required this.label,
    required this.state,
    required this.empty,
    required this.value,
  });
  final String label;
  final AsyncValue<List<T>> state;
  final String empty;
  final String Function(List<T>) value;
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final text = state.when(
      data: value,
      loading: () => 'Cargando…',
      error: (_, _) => 'No disponible',
    );
    return Container(
      padding: const EdgeInsets.all(10),
      color: tokens.raised,
      child: Row(
        children: [
          PulsoLabel(label),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text.isEmpty ? empty : text,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: tokens.chalkDim,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BmiSignal extends StatelessWidget {
  const _BmiSignal({required this.client, required this.weights});
  final ClientModel client;
  final List<Map<String, dynamic>>? weights;
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    var height = client.estatura_cliente!;
    if (height > 3) height /= 100;
    double? weight;
    final values =
        (weights ?? const <Map<String, dynamic>>[])
            .map(
              (item) => (
                date: DateTime.tryParse('${item['fecha']}'),
                value: (item['peso'] as num?)?.toDouble(),
              ),
            )
            .where((item) => item.date != null && item.value != null)
            .toList()
          ..sort((a, b) => b.date!.compareTo(a.date!));
    weight = values.isEmpty ? client.peso : values.first.value;
    if (weight == null || height <= 0) return const SizedBox.shrink();
    final bmi = weight / (height * height);
    return Container(
      padding: const EdgeInsets.all(10),
      color: tokens.raised,
      child: Row(
        children: [
          const PulsoLabel('IMC ESTIMADO'),
          const Spacer(),
          Text(
            bmi.toStringAsFixed(1),
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              color: tokens.chalk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message:
                'Dato orientativo calculado con la última estatura y peso; no es diagnóstico médico.',
            child: Icon(Icons.info_outline, size: 15, color: tokens.muted),
          ),
        ],
      ),
    );
  }
}

class _ClientFooter extends StatelessWidget {
  const _ClientFooter();
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
