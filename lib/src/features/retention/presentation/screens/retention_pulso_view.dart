import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../clients/presentation/widgets/client_record_dialog.dart';
import '../../data/models/retention_models.dart';
import '../../data/services/retention_report_export_service.dart';
import '../state/retention_export_provider.dart';
import '../state/retention_providers.dart';
import '../widgets/retention_cohort_strip.dart';
import '../widgets/retention_breakdown_dialog.dart';
import '../widgets/retention_management_dialog.dart';
import '../widgets/retention_scope_filters.dart';

const _actionStates = {'PROXIMO', 'VENCE_HOY', 'EN_GRACIA', 'SALIDA'};
const _stateOrder = [
  'TODOS',
  'ACCION',
  'VENCE_HOY',
  'EN_GRACIA',
  'SALIDA',
  'RECUPERADO',
  'RENOVADO_PUNTUAL',
  'RENOVADO_EN_GRACIA',
];

class RetentionPulsoView extends ConsumerStatefulWidget {
  const RetentionPulsoView({super.key});

  @override
  ConsumerState<RetentionPulsoView> createState() => _RetentionPulsoViewState();
}

class _RetentionPulsoViewState extends ConsumerState<RetentionPulsoView> {
  final _searchController = TextEditingController();
  String _selectedState = 'ACCION';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() => ref.invalidate(retentionDashboardProvider);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(retentionDashboardProvider);
    return PulsoThemeScope(
      child: Builder(
        builder: (context) => Material(
          color: PulsoTokens.of(context).floor,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 600;
              final padding = compact
                  ? 16.0
                  : constraints.maxWidth < 840
                  ? 24.0
                  : 32.0;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  padding,
                  compact ? 16 : 20,
                  padding,
                  compact ? 16 : 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RetentionHeader(onRefresh: _refresh),
                    const SizedBox(height: 14),
                    Expanded(
                      child: state.when(
                        loading: () => const PulsoPanel(
                          child: PulsoStateView(
                            kind: PulsoStateKind.loading,
                            message: 'Calculando renovaciones y salidas…',
                          ),
                        ),
                        error: (error, _) => PulsoPanel(
                          child: PulsoStateView(
                            kind: PulsoStateKind.error,
                            message:
                                'No se pudo cargar Control y Calidad.\n$error',
                            onRetry: _refresh,
                          ),
                        ),
                        data: (dashboard) => _buildDashboard(
                          context,
                          dashboard,
                          compact: compact,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    RetentionDashboardModel dashboard, {
    required bool compact,
  }) {
    final searchQuery = _searchController.text.trim().toLowerCase();
    final filtered = dashboard.items
        .where((item) {
          final stateMatches = switch (_selectedState) {
            'TODOS' => true,
            'ACCION' => _actionStates.contains(item.state),
            _ => item.state == _selectedState,
          };
          if (!stateMatches) return false;
          if (searchQuery.isEmpty) return true;
          return item.clientName.toLowerCase().contains(searchQuery) ||
              item.clientId.toLowerCase().contains(searchQuery) ||
              item.plan.name.toLowerCase().contains(searchQuery) ||
              (item.phone?.contains(searchQuery) ?? false) ||
              item.management.status.toLowerCase().contains(searchQuery) ||
              (item.management.note?.toLowerCase().contains(searchQuery) ??
                  false) ||
              (item.trainer?.name.toLowerCase().contains(searchQuery) ?? false);
        })
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PulsoMetricStrip(
          metrics: [
            PulsoMetricData(
              value: '${dashboard.metrics.count('VENCE_HOY')}',
              label: 'Vencen hoy',
              note: 'contacto prioritario',
              emphasis: dashboard.metrics.count('VENCE_HOY') > 0,
            ),
            PulsoMetricData(
              value: '${dashboard.metrics.count('EN_GRACIA')}',
              label: 'En gracia',
              note: 'aún pueden retenerse',
              warning: dashboard.metrics.count('EN_GRACIA') > 0,
            ),
            PulsoMetricData(
              value: '${dashboard.metrics.count('SALIDA')}',
              label: 'Salidas',
              note: 'gracia terminada',
              warning: dashboard.metrics.count('SALIDA') > 0,
            ),
            PulsoMetricData(
              value: '${dashboard.metrics.dueFollowups}',
              label: 'Gestiones hoy',
              note: 'seguimiento pendiente',
              emphasis: dashboard.metrics.dueFollowups > 0,
            ),
          ],
        ),
        if (dashboard.cohorts.isNotEmpty) ...[
          const SizedBox(height: 10),
          RetentionCohortStrip(cohorts: dashboard.cohorts, compact: compact),
        ],
        const SizedBox(height: 10),
        _PolicyStrip(dashboard: dashboard),
        const SizedBox(height: 10),
        RetentionScopeFilters(
          dashboard: dashboard,
          compact: compact,
          onCompare: () => showRetentionBreakdownDialog(context, dashboard),
          onExport: () => _showExport(dashboard, filtered),
        ),
        if (dashboard.quality.missingActivationEvidence > 0) ...[
          const SizedBox(height: 10),
          _QualityNotice(quality: dashboard.quality),
        ],
        const SizedBox(height: 10),
        _RetentionFilters(
          metrics: dashboard.metrics,
          selected: _selectedState,
          searchController: _searchController,
          onStateSelected: (value) => setState(() => _selectedState = value),
          onSearchChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: PulsoPanel(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _QueueHeader(
                  visible: filtered.length,
                  total: dashboard.metrics.totalVisible,
                  businessDate: dashboard.businessDate,
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const PulsoStateView(
                          kind: PulsoStateKind.empty,
                          message:
                              'No hay socios que coincidan con este filtro.',
                        )
                      : ListView.separated(
                          key: const PageStorageKey('retention-queue'),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: PulsoTokens.of(context).line,
                          ),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return _RetentionQueueItem(
                              key: ValueKey(item.membershipId),
                              item: item,
                              timezone: dashboard.timezone,
                              compact: compact,
                              onOpen: () => _showRecord(item.clientId),
                              onManage: () => _showManagement(item, dashboard),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showRecord(String clientId) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClientRecordDialog(clientId: clientId),
    );
  }

  void _showManagement(
    RetentionItemModel item,
    RetentionDashboardModel dashboard,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RetentionManagementDialog(
        item: item,
        businessDate: dashboard.businessDate,
        timezone: dashboard.timezone,
      ),
    );
  }

  void _showExport(
    RetentionDashboardModel dashboard,
    List<RetentionItemModel> visibleItems,
  ) {
    final snapshot = RetentionReportSnapshot.fromDashboard(
      dashboard: dashboard,
      visibleItems: visibleItems,
      scope: _scopeSummary(dashboard),
    );
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RetentionExportDialog(snapshot: snapshot),
    );
  }

  String _scopeSummary(RetentionDashboardModel dashboard) {
    final filter = ref.read(retentionFilterProvider);
    final plan = dashboard.dimensions.plans
        .where((item) => item.id == filter.planId)
        .map((item) => item.name)
        .firstOrNull;
    final trainer = dashboard.dimensions.trainers
        .where((item) => item.id == filter.trainerId)
        .map((item) => item.name)
        .firstOrNull;
    final parts = <String>[
      'Periodo ${dashboard.window.from} a ${dashboard.window.to}',
      'Plan ${plan ?? 'todos'}',
      'Entrenador ${trainer ?? 'todos'}',
      'Estado ${_label(_selectedState)}',
      if (_searchController.text.trim().isNotEmpty)
        'Búsqueda “${_searchController.text.trim()}”',
    ];
    return parts.join(' / ');
  }
}

class _RetentionHeader extends StatelessWidget {
  const _RetentionHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PulsoLabel('Gym·OS — clientes'),
              const SizedBox(height: 5),
              Text(
                'CONTROL Y\nCALIDAD.',
                style: TextStyle(
                  fontFamily: PulsoFonts.display,
                  fontSize: 34,
                  height: 0.9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: tokens.chalk,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Renovaciones esperadas, gracia, salidas y clientes recuperados.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tokens.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        PulsoSecondaryButton(
          label: 'Actualizar',
          icon: Icons.refresh,
          onPressed: onRefresh,
        ),
      ],
    );
  }
}

class _PolicyStrip extends StatelessWidget {
  const _PolicyStrip({required this.dashboard});

  final RetentionDashboardModel dashboard;

  String _percentage(double? value) =>
      value == null ? '—' : '${NumberFormat('0.#').format(value)}%';

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: tokens.raised,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final policy = Text(
            '${dashboard.policy.graceDays} días de gracia · salida al día ${dashboard.policy.graceDays + 1} · '
            'cohorte consolidada hasta ${_readableDate(dashboard.policy.matureCohortCutoff)}',
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 10,
              height: 1.5,
              color: tokens.muted,
            ),
          );
          final rates = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Rate(
                label: 'Retención',
                value: _percentage(dashboard.metrics.retentionRatePct),
                color: tokens.success,
              ),
              const SizedBox(width: 18),
              _Rate(
                label: 'Recuperación',
                value: _percentage(dashboard.metrics.recoveryRatePct),
                color: tokens.accent,
              ),
            ],
          );
          if (constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [policy, const SizedBox(height: 10), rates],
            );
          }
          return Row(
            children: [
              Expanded(child: policy),
              const SizedBox(width: 16),
              rates,
            ],
          );
        },
      ),
    );
  }
}

class _Rate extends StatelessWidget {
  const _Rate({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        PulsoLabel(label),
        Text(
          value,
          style: TextStyle(
            fontFamily: PulsoFonts.display,
            fontSize: 23,
            height: 1,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _QualityNotice extends StatelessWidget {
  const _QualityNotice({required this.quality});

  final RetentionQualityModel quality;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: tokens.warningSoft,
      borderColor: tokens.warning,
      child: Row(
        children: [
          Icon(Icons.fact_check_outlined, size: 18, color: tokens.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${quality.missingActivationEvidence} renovación(es) no se contaron porque carecen de evidencia de activación.',
              style: TextStyle(color: tokens.chalkDim, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _RetentionFilters extends StatelessWidget {
  const _RetentionFilters({
    required this.metrics,
    required this.selected,
    required this.searchController,
    required this.onStateSelected,
    required this.onSearchChanged,
  });

  final RetentionMetricsModel metrics;
  final String selected;
  final TextEditingController searchController;
  final ValueChanged<String> onStateSelected;
  final ValueChanged<String> onSearchChanged;

  int _count(String state) => switch (state) {
    'TODOS' => metrics.totalVisible,
    'ACCION' => _actionStates.fold(0, (sum, item) => sum + metrics.count(item)),
    _ => metrics.count(state),
  };

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final search = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 410),
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, size: 19),
              hintText: 'Socio, CI, teléfono, plan o entrenador',
              isDense: true,
            ),
          ),
        );
        final filters = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final state in _stateOrder) ...[
                ChoiceChip(
                  label: Text('${_label(state)} ${_count(state)}'),
                  selected: state == selected,
                  onSelected: (_) => onStateSelected(state),
                  selectedColor: tokens.accentSoftStrong,
                  side: BorderSide(
                    color: state == selected ? tokens.accent : tokens.line,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  labelStyle: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 9,
                    color: state == selected ? tokens.accent : tokens.muted,
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        );
        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [search, const SizedBox(height: 8), filters],
          );
        }
        return Row(
          children: [
            Expanded(child: filters),
            const SizedBox(width: 12),
            search,
          ],
        );
      },
    );
  }
}

class _QueueHeader extends StatelessWidget {
  const _QueueHeader({
    required this.visible,
    required this.total,
    required this.businessDate,
  });

  final int visible;
  final int total;
  final String businessDate;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      color: tokens.raised,
      child: Row(
        children: [
          const PulsoLabel('Cola explicada'),
          const Spacer(),
          Text(
            '$visible de $total · corte ${_readableDate(businessDate)}',
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              color: tokens.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _RetentionQueueItem extends StatelessWidget {
  const _RetentionQueueItem({
    super.key,
    required this.item,
    required this.timezone,
    required this.compact,
    required this.onOpen,
    required this.onManage,
  });

  final RetentionItemModel item;
  final String timezone;
  final bool compact;
  final VoidCallback onOpen;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final medium = constraints.maxWidth < 950;
            final identity = _Identity(item: item);
            final status = _StatusBadge(state: item.state);
            final due = _LabeledValue(
              label: 'Renovación esperada',
              value:
                  '${_readableDate(item.expectedRenewalDate)} · ${_delta(item.daysFromDue)}',
            );
            final service = _LabeledValue(
              label: item.trainer == null ? 'Plan' : 'Plan · entrenador',
              value: item.trainer == null
                  ? item.plan.name
                  : '${item.plan.name} · ${item.trainer!.name}',
            );
            final movement = _LabeledValue(
              label: 'Último movimiento',
              value: _lastMovement(item, timezone),
            );
            final management = _ManagementStatus(management: item.management);
            if (medium) {
              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [identity, const SizedBox(height: 10), service],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [status, const SizedBox(height: 10), due],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: management),
                  const SizedBox(width: 8),
                  PulsoIconButton(
                    icon: Icons.add_call,
                    tooltip: 'Registrar gestión',
                    onPressed: onManage,
                  ),
                ],
              );
            }
            return Row(
              children: [
                SizedBox(width: 225, child: identity),
                SizedBox(width: 145, child: status),
                SizedBox(width: 190, child: due),
                Expanded(flex: 2, child: service),
                const SizedBox(width: 14),
                Expanded(child: movement),
                const SizedBox(width: 10),
                SizedBox(width: 145, child: management),
                const SizedBox(width: 8),
                PulsoIconButton(
                  icon: Icons.add_call,
                  tooltip: 'Registrar gestión',
                  onPressed: onManage,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _Identity(item: item)),
                const SizedBox(width: 8),
                _StatusBadge(state: item.state),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.reason,
              style: TextStyle(fontSize: 11, color: tokens.chalkDim),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: [
                _LabeledValue(
                  label: 'Renovación',
                  value:
                      '${_readableDate(item.expectedRenewalDate)} · ${_delta(item.daysFromDue)}',
                ),
                _LabeledValue(label: 'Plan', value: item.plan.name),
                if (item.trainer != null)
                  _LabeledValue(label: 'Entrenador', value: item.trainer!.name),
                _LabeledValue(
                  label: 'Último movimiento',
                  value: _lastMovement(item, timezone),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _ManagementStatus(management: item.management)),
                const SizedBox(width: 10),
                PulsoSecondaryButton(
                  label: 'Gestionar',
                  icon: Icons.add_call,
                  onPressed: onManage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagementStatus extends StatelessWidget {
  const _ManagementStatus({required this.management});

  final RetentionManagementSummary management;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = switch (management.status) {
      'PROMESA_PAGO' => tokens.warning,
      'CONTACTADO' => tokens.success,
      'NO_DESEA_RENOVAR' => tokens.danger,
      'NO_LOCALIZADO' => tokens.sync,
      _ => tokens.muted,
    };
    final next = management.nextManagementDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const PulsoLabel('Gestión'),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: tokens.isDark ? 0.14 : 0.09),
            border: Border(left: BorderSide(color: color, width: 3)),
          ),
          child: Text(
            _managementLabel(management.status).toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        if (next != null) ...[
          const SizedBox(height: 3),
          Text(
            '${management.overdue ? 'Vencida' : 'Próxima'} · ${_readableDate(next)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 8.5,
              color: management.overdue ? tokens.danger : tokens.muted,
            ),
          ),
        ],
      ],
    );
  }
}

class _RetentionExportDialog extends ConsumerWidget {
  const _RetentionExportDialog({required this.snapshot});

  final RetentionReportSnapshot snapshot;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    RetentionExportOperation operation,
  ) async {
    final notifier = ref.read(retentionExportProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      bool completed = false;
      switch (operation) {
        case RetentionExportOperation.pdf:
          completed = await notifier.savePdf(snapshot) != null;
          break;
        case RetentionExportOperation.csv:
          completed = await notifier.saveCsv(snapshot) != null;
          break;
        case RetentionExportOperation.print:
          completed = await notifier.printPdf(snapshot);
          break;
        case RetentionExportOperation.idle:
          return;
      }
      if (!context.mounted || !completed) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            operation == RetentionExportOperation.print
                ? 'Informe enviado a impresión.'
                : 'Informe exportado correctamente.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo generar el informe: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operation = ref.watch(retentionExportProvider);
    final busy = operation != RetentionExportOperation.idle;
    return PulsoThemeScope(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tokens = PulsoTokens.of(context);
          return Center(
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                key: const ValueKey('retention-export-dialog'),
                width: (constraints.maxWidth - 32).clamp(320.0, 620.0),
                child: PulsoPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 15, 10, 14),
                        color: tokens.raised,
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 40,
                              color: tokens.accent,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  PulsoLabel('CONTROL Y CALIDAD'),
                                  Text(
                                    'EMITIR INFORME',
                                    style: TextStyle(
                                      fontFamily: PulsoFonts.display,
                                      fontSize: 23,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PulsoIconButton(
                              tooltip: 'Cerrar',
                              icon: Icons.close,
                              onPressed: busy
                                  ? null
                                  : () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              snapshot.scope,
                              style: TextStyle(
                                fontFamily: PulsoFonts.mono,
                                fontSize: 9,
                                height: 1.5,
                                color: tokens.muted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${snapshot.visibleTotal} filas visibles · ${snapshot.cohorts.length} cohortes mensuales',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: tokens.chalk,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                PulsoPrimaryButton(
                                  label: 'Guardar PDF',
                                  icon: Icons.picture_as_pdf_outlined,
                                  busy:
                                      operation == RetentionExportOperation.pdf,
                                  onPressed: busy
                                      ? null
                                      : () => _run(
                                          context,
                                          ref,
                                          RetentionExportOperation.pdf,
                                        ),
                                ),
                                PulsoSecondaryButton(
                                  label: 'Guardar CSV',
                                  icon: Icons.table_view_outlined,
                                  onPressed: busy
                                      ? null
                                      : () => _run(
                                          context,
                                          ref,
                                          RetentionExportOperation.csv,
                                        ),
                                ),
                                PulsoSecondaryButton(
                                  label: 'Imprimir',
                                  icon: Icons.print_outlined,
                                  onPressed: busy
                                      ? null
                                      : () => _run(
                                          context,
                                          ref,
                                          RetentionExportOperation.print,
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.item});

  final RetentionItemModel item;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.clientName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w700, color: tokens.chalk),
        ),
        const SizedBox(height: 3),
        Text(
          'CI ${item.clientId}${item.phone == null ? '' : ' · ${item.phone}'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: 9,
            color: tokens.muted,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = switch (state) {
      'SALIDA' => tokens.danger,
      'EN_GRACIA' => tokens.warning,
      'VENCE_HOY' => tokens.accent,
      'RECUPERADO' ||
      'RENOVADO_PUNTUAL' ||
      'RENOVADO_EN_GRACIA' => tokens.success,
      _ => tokens.sync,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: tokens.isDark ? 0.14 : 0.10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Text(
        _label(state).toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: PulsoFonts.mono,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PulsoLabel(label),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: tokens.chalkDim),
        ),
      ],
    );
  }
}

String _label(String state) => switch (state) {
  'TODOS' => 'Todos',
  'ACCION' => 'Requieren acción',
  'PROXIMO' => 'Próximo',
  'VENCE_HOY' => 'Vence hoy',
  'EN_GRACIA' => 'En gracia',
  'SALIDA' => 'Salida',
  'RECUPERADO' => 'Recuperado',
  'RENOVADO_PUNTUAL' => 'Puntual',
  'RENOVADO_EN_GRACIA' => 'Renovó en gracia',
  _ => state,
};

String _managementLabel(String state) => switch (state) {
  'PENDIENTE' => 'Sin gestionar',
  'CONTACTADO' => 'Contactado',
  'PROMESA_PAGO' => 'Promesa de pago',
  'NO_LOCALIZADO' => 'No localizado',
  'NO_DESEA_RENOVAR' => 'No desea renovar',
  _ => state,
};

String _delta(int days) => days < 0
    ? 'en ${days.abs()} d'
    : days == 0
    ? 'hoy'
    : '$days d tarde';

String _readableDate(String value) {
  final date = DateTime.tryParse('${value}T00:00:00Z');
  return date == null ? value : DateFormat('dd/MM/yyyy').format(date.toUtc());
}

String _lastMovement(RetentionItemModel item, String timezone) {
  final payment = item.lastPaymentAtUtc;
  final attendance = item.lastAttendanceAtUtc;
  if (payment == null && attendance == null) return 'Sin actividad registrada';
  final usePayment =
      payment != null && (attendance == null || payment.isAfter(attendance));
  final DateTime value;
  if (usePayment) {
    value = payment;
  } else {
    value = attendance!;
  }
  final prefix = usePayment ? 'Pago' : 'Asistencia';
  return '$prefix · ${formatInZone(value, timezone, DateFormat('dd/MM · HH:mm'))}';
}
