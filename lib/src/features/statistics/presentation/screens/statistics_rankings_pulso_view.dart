import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_charts.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../dashboard/presentation/state/dashboard_nav_provider.dart';
import '../../../financials/data/models/currency_model.dart';
import '../../../financials/presentation/state/currency_notifier.dart';
import '../../data/models/statistics_rankings.dart';
import '../../data/models/statistics_ranking_page.dart';
import '../../data/models/statistics_comparison.dart';
import '../state/statistics_providers.dart';
import 'statistics_shared.dart';

/// Portada comparativa de R6.
///
/// No intenta ser la versión visual definitiva. Su responsabilidad es cerrar
/// primero las preguntas operativas y llevar cada ranking a su registro fuente.
class StatisticsRankingsPulsoView extends ConsumerStatefulWidget {
  const StatisticsRankingsPulsoView({super.key});

  @override
  ConsumerState<StatisticsRankingsPulsoView> createState() =>
      _StatisticsRankingsPulsoViewState();
}

class _StatisticsRankingsPulsoViewState
    extends ConsumerState<StatisticsRankingsPulsoView> {
  int _days = 90;

  void _openPlan(String id) {
    ref.read(selectedPlanProvider.notifier).select(id);
    ref.read(dashboardNavProvider.notifier).setIndex(30);
  }

  void _openTrainer(String id) {
    ref.read(selectedTrainerProvider.notifier).select(id);
    ref.read(dashboardNavProvider.notifier).setIndex(29);
  }

  void _openMember(String ci) {
    ref.read(selectedMemberProvider.notifier).select(ci);
    ref.read(dashboardNavProvider.notifier).setIndex(31);
  }

  void _openRanking(StatisticsRankingType type, {String? currencyId}) {
    ref
        .read(statisticsRankingQueryProvider.notifier)
        .open(type: type, days: _days, currencyId: currencyId);
    ref.read(dashboardNavProvider.notifier).setIndex(32);
  }

  /// Un aviso sin destino no navega: se queda enseñando su regla. Es
  /// preferible a llevar a una pantalla que no explica la cifra.
  void _openAlert(StatisticsAlertTarget target) {
    switch (target.kind) {
      case 'plan':
        if (target.id != null) _openPlan(target.id!);
      case 'entrenador':
        if (target.id != null) _openTrainer(target.id!);
      case 'ranking':
        if (target.ranking != null) _openRanking(target.ranking!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statisticsRankingsProvider(_days));
    final currencies =
        ref.watch(currencyProvider).value ?? const <CurrencyModel>[];
    return PulsoThemeScope(
      child: Builder(
        builder: (context) => ColoredBox(
          color: PulsoTokens.of(context).floor,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 900;
              return SingleChildScrollView(
                padding: EdgeInsets.all(compact ? 16 : 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const StatsHeader(
                      etiqueta: 'Estadística · comparativas',
                      titulo: 'PULSO DEL\nGIMNASIO',
                      descripcion:
                          'Los cinco líderes de cada medida, sin convertir la '
                          'portada en una lista interminable. Cada fila abre '
                          'su perfil; cada bloque abre además su ranking '
                          'completo, buscable y paginado.',
                    ),
                    const SizedBox(height: 14),
                    _PeriodSelector(
                      selected: _days,
                      onSelect: (days) => setState(() => _days = days),
                    ),
                    const SizedBox(height: 14),
                    state.when(
                      loading: () => const PulsoPanel(
                        child: PulsoStateView(
                          kind: PulsoStateKind.loading,
                          message: 'Calculando comparativas…',
                        ),
                      ),
                      error: (error, _) => PulsoPanel(
                        child: PulsoStateView(
                          kind: PulsoStateKind.error,
                          message:
                              'No se pudieron calcular los rankings.\n'
                              '${statisticsErrorMessage(error)}',
                          onRetry: () =>
                              ref.invalidate(statisticsRankingsProvider(_days)),
                        ),
                      ),
                      data: (data) => _RankingsBody(
                        data: data,
                        compact: compact,
                        currencies: currencies,
                        onPlan: _openPlan,
                        onTrainer: _openTrainer,
                        onMember: _openMember,
                        onBrowsePlan: () =>
                            _openRanking(StatisticsRankingType.plans),
                        onBrowseTrainer: () =>
                            _openRanking(StatisticsRankingType.trainers),
                        onBrowseVisits: () =>
                            _openRanking(StatisticsRankingType.memberVisits),
                        onBrowseInactivity: () => _openRanking(
                          StatisticsRankingType.memberInactivity,
                        ),
                        onBrowseChanges: () => _openRanking(
                          StatisticsRankingType.memberTrainerChanges,
                        ),
                        onBrowseValue: (currencyId) => _openRanking(
                          StatisticsRankingType.memberValue,
                          currencyId: currencyId,
                        ),
                        onAlert: _openAlert,
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
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return PulsoPanel(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const PulsoLabel('PERÍODO'),
          for (final entry in const [
            (30, '30 días'),
            (90, '90 días'),
            (365, '12 meses'),
          ])
            if (selected == entry.$1)
              PulsoPrimaryButton(
                label: entry.$2,
                onPressed: () => onSelect(entry.$1),
              )
            else
              PulsoSecondaryButton(
                label: entry.$2,
                onPressed: () => onSelect(entry.$1),
              ),
        ],
      ),
    );
  }
}

class _RankingsBody extends StatelessWidget {
  const _RankingsBody({
    required this.data,
    required this.compact,
    required this.currencies,
    required this.onPlan,
    required this.onTrainer,
    required this.onMember,
    required this.onBrowsePlan,
    required this.onBrowseTrainer,
    required this.onBrowseVisits,
    required this.onBrowseInactivity,
    required this.onBrowseChanges,
    required this.onBrowseValue,
    required this.onAlert,
  });
  final StatisticsRankings data;
  final bool compact;
  final List<CurrencyModel> currencies;
  final ValueChanged<String> onPlan;
  final ValueChanged<String> onTrainer;
  final ValueChanged<String> onMember;
  final VoidCallback onBrowsePlan;
  final VoidCallback onBrowseTrainer;
  final VoidCallback onBrowseVisits;
  final VoidCallback onBrowseInactivity;
  final VoidCallback onBrowseChanges;
  final ValueChanged<String> onBrowseValue;
  final ValueChanged<StatisticsAlertTarget> onAlert;

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;
    final width = compact ? double.infinity : 440.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PulsoMetricStrip(
          metrics: [
            PulsoMetricData(
              value: '${summary.active}',
              label: 'Socios activos',
              note: '${summary.registered} registrados',
              emphasis: true,
            ),
            PulsoMetricData(
              value: '${summary.covered}',
              label: 'Con cobertura',
              note: 'vigentes hoy',
            ),
            PulsoMetricData(
              value: '${summary.under18}',
              label: 'Menores de 18',
              note: '${summary.missingBirthDate} sin fecha',
            ),
          ],
        ),
        const SizedBox(height: 14),
        _AlertsPanel(
          alerts: data.alerts,
          omitted: data.omittedAlerts,
          rules: data.alertRules,
          currencies: currencies,
          onAlert: onAlert,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: width,
              child: _ChartPanel(
                title: 'Top 5 · planes más contratados',
                note: 'Contratos iniciados en el período',
                chart: PulsoBarras(
                  datos: [
                    for (final row in data.plans)
                      PulsoChartDato(
                        etiqueta: row.name,
                        valor: row.sold.toDouble(),
                        nota: '${row.covered} cubiertos',
                      ),
                  ],
                  mensajeVacio: 'No hay contrataciones en este período.',
                  anchoEtiqueta: 130,
                ),
                rows: [
                  for (final row in data.plans)
                    _RankingRowData(
                      id: row.id,
                      label: row.name,
                      value: '${row.sold} ventas',
                      note:
                          '${row.renewals} renovaciones · '
                          '${_comparisonText(row.comparison)}',
                    ),
                ],
                onOpen: onPlan,
                browseLabel: 'Ver ranking completo',
                onBrowse: onBrowsePlan,
              ),
            ),
            SizedBox(
              width: width,
              child: _ChartPanel(
                title: 'Top 5 · cartera por entrenador',
                note: 'Socios con asignación abierta ahora',
                chart: PulsoBarras(
                  datos: [
                    for (final row in data.trainers)
                      PulsoChartDato(
                        etiqueta: row.name,
                        valor: row.activePortfolio.toDouble(),
                        nota: '+${row.gained} · −${row.lost}',
                      ),
                  ],
                  mensajeVacio: 'No hay carteras de entrenador.',
                  anchoEtiqueta: 130,
                ),
                rows: [
                  for (final row in data.trainers)
                    _RankingRowData(
                      id: row.id,
                      label: row.name,
                      value: '${row.activePortfolio} activos',
                      note:
                          '${row.gained} ganados · ${row.lost} perdidos · '
                          '${_comparisonText(row.comparison)}',
                    ),
                ],
                onOpen: onTrainer,
                browseLabel: 'Ver ranking completo',
                onBrowse: onBrowseTrainer,
              ),
            ),
            SizedBox(
              width: width,
              child: _ChartPanel(
                title: 'Top 5 · socios más constantes',
                note: 'Visitas registradas en el período',
                chart: PulsoBarras(
                  datos: [
                    for (final row in data.byVisits)
                      PulsoChartDato(
                        etiqueta: row.name,
                        valor: row.visits.toDouble(),
                        nota: '${row.daysWithoutVisit} d sin venir',
                      ),
                  ],
                  mensajeVacio: 'No hay asistencias en este período.',
                  anchoEtiqueta: 130,
                ),
                rows: [
                  for (final row in data.byVisits)
                    _RankingRowData(
                      id: row.ci,
                      label: row.name,
                      value: '${row.visits} visitas',
                      note:
                          'última hace ${row.daysWithoutVisit} días · '
                          '${_comparisonText(row.comparison)}',
                    ),
                ],
                onOpen: onMember,
                browseLabel: 'Ver ranking completo',
                onBrowse: onBrowseVisits,
              ),
            ),
            SizedBox(
              width: width,
              child: _ChartPanel(
                title: 'Top 5 · inactividad observada',
                note: 'Días sin visitar; no supone una frecuencia obligatoria',
                chart: PulsoBarras(
                  datos: [
                    for (final row in data.byInactivity)
                      PulsoChartDato(
                        etiqueta: row.name,
                        valor: row.daysWithoutVisit.toDouble(),
                        nota: '${row.visits} visitas',
                      ),
                  ],
                  mensajeVacio: 'No hay socios activos para comparar.',
                  anchoEtiqueta: 130,
                ),
                rows: [
                  for (final row in data.byInactivity)
                    _RankingRowData(
                      id: row.ci,
                      label: row.name,
                      value: '${row.daysWithoutVisit} días',
                      note: row.lastVisit == null
                          ? 'sin visita · ${_comparisonText(row.comparison)}'
                          : '${row.visits} visitas · '
                                '${_comparisonText(row.comparison)}',
                    ),
                ],
                onOpen: onMember,
                browseLabel: 'Ver ranking completo',
                onBrowse: onBrowseInactivity,
              ),
            ),
            SizedBox(
              width: width,
              child: _ChartPanel(
                title: 'Top 5 · cambios reales de entrenador',
                note: 'Cambios de persona, no renovaciones con el mismo',
                chart: PulsoBarras(
                  datos: [
                    for (final row in data.byTrainerChanges)
                      PulsoChartDato(
                        etiqueta: row.name,
                        valor: row.changes.toDouble(),
                      ),
                  ],
                  mensajeVacio: 'No hubo cambios de entrenador.',
                  anchoEtiqueta: 130,
                ),
                rows: [
                  for (final row in data.byTrainerChanges)
                    _RankingRowData(
                      id: row.ci,
                      label: row.name,
                      value: '${row.changes} cambios',
                      note: '${row.ci} · ${_comparisonText(row.comparison)}',
                    ),
                ],
                onOpen: onMember,
                browseLabel: 'Ver ranking completo',
                onBrowse: onBrowseChanges,
              ),
            ),
            for (final group in data.byValue)
              SizedBox(
                width: width,
                child: _ChartPanel(
                  title:
                      'Valor aportado · ${nombreMoneda(currencies, group.currencyId)}',
                  note: 'Cobrado neto no anulado en el período',
                  chart: PulsoBarras(
                    datos: [
                      for (final row in group.ranking)
                        PulsoChartDato(etiqueta: row.name, valor: row.total),
                    ],
                    mensajeVacio: 'No hay cobros en esta moneda.',
                    anchoEtiqueta: 130,
                  ),
                  rows: [
                    for (final row in group.ranking)
                      _RankingRowData(
                        id: row.ci,
                        label: row.name,
                        value: NumberFormat('#,##0.00').format(row.total),
                        note:
                            '${nombreMoneda(currencies, row.currencyId)} · '
                            '${_comparisonText(row.comparison, decimals: true)}',
                      ),
                  ],
                  onOpen: onMember,
                  browseLabel: 'Ver ranking completo',
                  onBrowse: () => onBrowseValue(group.currencyId),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Período ${data.period.from} → ${data.period.to} · '
          'anterior ${data.previousPeriod.from} → '
          '${data.previousPeriod.to} · '
          'día de negocio ${data.businessDay} · zona ${data.zone}',
          style: TextStyle(fontSize: 10, color: PulsoTokens.of(context).muted),
        ),
      ],
    );
  }
}

/// Avisos explicables (docs/PLAN_ESTADISTICAS.md §5.1).
///
/// Ninguna tarjeta recomienda: enseña el umbral que la disparó, su
/// denominador y —cuando existe— el sitio donde comprobarla. Cuando no salta
/// ninguna, el panel dice qué reglas se llegaron a mirar; «no pasa nada» sin
/// decir qué se miró no es información.
class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel({
    required this.alerts,
    required this.omitted,
    required this.rules,
    required this.currencies,
    required this.onAlert,
  });

  final List<StatisticsAlert> alerts;
  final int omitted;
  final List<StatisticsAlertRule> rules;
  final List<CurrencyModel> currencies;
  final ValueChanged<StatisticsAlertTarget> onAlert;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final danger = alerts
        .where((alert) => alert.severity == StatisticsAlertSeverity.danger)
        .length;
    final sinEvaluar = rules.where((rule) => !rule.evaluated).toList();
    return PulsoPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: StatsPanelTitle('Requiere atención')),
              Text(
                alerts.isEmpty
                    ? 'sin avisos'
                    : '$danger peligro · ${alerts.length - danger} aviso',
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 10,
                  color: alerts.isEmpty ? tokens.muted : tokens.chalk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Cada aviso publica el umbral que lo disparó y su denominador. '
            'Ninguno recomienda nada.',
            style: TextStyle(fontSize: 10, color: tokens.muted),
          ),
          const SizedBox(height: 14),
          if (alerts.isEmpty)
            Container(
              key: const ValueKey('alertas-vacio'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: tokens.line),
                color: tokens.raised,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ningún indicador cruzó su umbral en este período.',
                    style: TextStyle(fontSize: 11, color: tokens.chalk),
                  ),
                  const SizedBox(height: 8),
                  for (final rule in rules)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        rule.evaluated
                            ? rule.text
                            : 'NO EVALUADA · ${rule.text}',
                        style: TextStyle(
                          fontSize: 9,
                          color: rule.evaluated ? tokens.muted : tokens.warning,
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            for (final alert in alerts)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AlertCard(
                  alert: alert,
                  currencies: currencies,
                  onAlert: onAlert,
                ),
              ),
          if (omitted > 0)
            Text(
              'Y $omitted aviso(s) más del mismo tipo, fuera del panel para que '
              'siga leyéndose.',
              style: TextStyle(fontSize: 9, color: tokens.muted),
            ),
          // Una regla que no llegó a mirarse tiene que decirse aunque haya
          // avisos: si no, dos tarjetas visibles se leen como «lo demás está en
          // orden» cuando en realidad hay algo sin comprobar.
          if (sinEvaluar.isNotEmpty)
            Padding(
              key: const ValueKey('alertas-sin-evaluar'),
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                sinEvaluar.length == 1
                    ? 'Una regla no se pudo evaluar en esta lectura '
                          '(${sinEvaluar.first.family}): su fuente no respondió. '
                          'No es lo mismo que estar en orden.'
                    : '${sinEvaluar.length} reglas no se pudieron evaluar en '
                          'esta lectura: su fuente no respondió. No es lo mismo '
                          'que estar en orden.',
                style: TextStyle(fontSize: 9, color: tokens.warning),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.currencies,
    required this.onAlert,
  });

  final StatisticsAlert alert;
  final List<CurrencyModel> currencies;
  final ValueChanged<StatisticsAlertTarget> onAlert;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final danger = alert.severity == StatisticsAlertSeverity.danger;
    final color = danger ? tokens.danger : tokens.warning;
    final target = alert.target;
    final sample = alert.sample;
    final comparison = alert.comparison;
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: tokens.line),
          right: BorderSide(color: tokens.line),
          bottom: BorderSide(color: tokens.line),
          left: BorderSide(color: color, width: 3),
        ),
        color: tokens.raised,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: color,
                child: Text(
                  danger ? 'PELIGRO' : 'AVISO',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: tokens.accentInk,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alert.currencyId == null
                      ? alert.title
                      : '${alert.title} · '
                            '${nombreMoneda(currencies, alert.currencyId!)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tokens.chalk,
                  ),
                ),
              ),
              if (target != null)
                Icon(Icons.arrow_forward, size: 13, color: tokens.accent),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            alert.detail,
            style: TextStyle(fontSize: 11, color: tokens.chalkDim),
          ),
          if (comparison != null || sample != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (comparison != null) _comparisonText(comparison),
                if (sample != null)
                  '${sample.value} de ${sample.base} · ${sample.label}',
              ].join(' · '),
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontSize: 9,
                color: tokens.muted,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Regla · ${alert.rule}',
            style: TextStyle(fontSize: 9, color: tokens.muted2),
          ),
          if (target == null) ...[
            const SizedBox(height: 4),
            Text(
              'Sin destino todavía: no existe una lista que explique esta '
              'cifra sin reinterpretarla.',
              style: TextStyle(fontSize: 9, color: tokens.muted2),
            ),
          ],
        ],
      ),
    );
    if (target == null) return KeyedSubtree(key: ValueKey(alert.id), child: card);
    return InkWell(
      key: ValueKey(alert.id),
      onTap: () => onAlert(target),
      child: card,
    );
  }
}

String _comparisonText(
  StatisticsMetricComparison comparison, {
  bool decimals = false,
}) {
  final previous = NumberFormat(
    decimals ? '#,##0.00' : '#,##0',
  ).format(comparison.previous);
  final percentage = comparison.percentageChange;
  if (percentage == null) return 'antes $previous · sin base %';
  final sign = percentage > 0
      ? '+'
      : percentage < 0
      ? '−'
      : '';
  final formatted = NumberFormat('#,##0.##').format(percentage.abs());
  return 'antes $previous · $sign$formatted%';
}

class _RankingRowData {
  const _RankingRowData({
    required this.id,
    required this.label,
    required this.value,
    required this.note,
  });
  final String id;
  final String label;
  final String value;
  final String note;
}

class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.title,
    required this.note,
    required this.chart,
    required this.rows,
    required this.onOpen,
    required this.browseLabel,
    required this.onBrowse,
  });
  final String title;
  final String note;
  final Widget chart;
  final List<_RankingRowData> rows;
  final ValueChanged<String> onOpen;
  final String browseLabel;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatsPanelTitle(title),
          const SizedBox(height: 3),
          Text(note, style: TextStyle(fontSize: 10, color: tokens.muted)),
          const SizedBox(height: 16),
          chart,
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: tokens.line),
            for (final row in rows)
              InkWell(
                key: ValueKey('ranking-${row.id}'),
                onTap: () => onOpen(row.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.label,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: tokens.chalk,
                              ),
                            ),
                            Text(
                              row.note,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                color: tokens.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        row.value,
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 10,
                          color: tokens.chalk,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 13, color: tokens.accent),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 10),
          PulsoSecondaryButton(
            label: browseLabel,
            icon: Icons.search,
            onPressed: onBrowse,
          ),
        ],
      ),
    );
  }
}
