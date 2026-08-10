import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_charts.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/statistics_forecast.dart';
import '../state/statistics_providers.dart';
import 'statistics_shared.dart';

/// E5: referencia transparente de demanda futura; nunca ocupación ni promesa.
class StatisticsForecastPulsoView extends ConsumerWidget {
  const StatisticsForecastPulsoView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(statisticsForecastQueryProvider);
    final state = ref.watch(statisticsForecastProvider(query));
    return PulsoThemeScope(
      child: Builder(
        builder: (context) => ColoredBox(
          color: PulsoTokens.of(context).floor,
          child: state.when(
            loading: () => const PulsoStateView(
              kind: PulsoStateKind.loading,
              message: 'Leyendo la historia y calculando la banda observable…',
            ),
            error: (error, _) => PulsoStateView(
              kind: PulsoStateKind.error,
              message:
                  'No se pudo calcular el pronóstico.\n'
                  '${statisticsErrorMessage(error)}',
              onRetry: () => ref.invalidate(statisticsForecastProvider(query)),
            ),
            data: (data) => _ForecastBody(data: data, query: query),
          ),
        ),
      ),
    );
  }
}

class _ForecastBody extends ConsumerWidget {
  const _ForecastBody({required this.data, required this.query});

  final StatisticsForecast data;
  final StatisticsForecastQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final medium =
            constraints.maxWidth >= 600 && constraints.maxWidth < 840;
        final padding = compact
            ? 16.0
            : medium
            ? 20.0
            : 28.0;
        return SingleChildScrollView(
          key: const PageStorageKey('pronostico-scroll'),
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StatsHeader(
                etiqueta: 'Estadística · E5',
                titulo: 'PRONÓSTICO EXPLICABLE',
                descripcion:
                    'Una referencia de visitas próximas construida con días '
                    'comparables. La estimación, su banda y la muestra quedan '
                    'a la vista: no hay IA opaca ni promesas.',
              ),
              const SizedBox(height: 14),
              _controls(ref),
              const SizedBox(height: 14),
              if (!data.available)
                PulsoStateView(
                  kind: PulsoStateKind.empty,
                  message: data.unavailableReason ?? 'Historia insuficiente.',
                )
              else ...[
                _summary(),
                const SizedBox(height: 14),
                _responsivePair(
                  stacked: compact || medium,
                  first: _historyPanel(),
                  second: _weeklyPanel(),
                ),
                const SizedBox(height: 14),
                _responsivePair(
                  stacked: compact,
                  first: _weekdayPanel(),
                  second: _methodPanel(),
                ),
                const SizedBox(height: 14),
                _tablePanel(context),
              ],
              const SizedBox(height: 12),
              Text(
                'Zona ${data.zone} · día de negocio ${data.businessDate}. '
                '${data.warnings.join(' ')}',
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 9,
                  height: 1.5,
                  color: PulsoTokens.of(context).muted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _controls(WidgetRef ref) => PulsoPanel(
    padding: const EdgeInsets.all(14),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const PulsoLabel('HISTORIA'),
        for (final days in const [90, 180, 365])
          days == query.historyDays
              ? PulsoPrimaryButton(
                  key: ValueKey('pronostico-historia-$days'),
                  label: '$days días',
                  onPressed: () => ref
                      .read(statisticsForecastQueryProvider.notifier)
                      .setHistoryDays(days),
                )
              : PulsoSecondaryButton(
                  key: ValueKey('pronostico-historia-$days'),
                  label: '$days días',
                  onPressed: () => ref
                      .read(statisticsForecastQueryProvider.notifier)
                      .setHistoryDays(days),
                ),
        const SizedBox(width: 8),
        const PulsoLabel('HORIZONTE'),
        for (final days in const [7, 28])
          days == query.horizonDays
              ? PulsoPrimaryButton(
                  key: ValueKey('pronostico-horizonte-$days'),
                  label: '$days días',
                  onPressed: () => ref
                      .read(statisticsForecastQueryProvider.notifier)
                      .setHorizonDays(days),
                )
              : PulsoSecondaryButton(
                  key: ValueKey('pronostico-horizonte-$days'),
                  label: '$days días',
                  onPressed: () => ref
                      .read(statisticsForecastQueryProvider.notifier)
                      .setHorizonDays(days),
                ),
      ],
    ),
  );

  Widget _summary() {
    final total = data.total!;
    final variation = data.trendPercentage;
    return PulsoPanel(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 30,
        runSpacing: 14,
        children: [
          StatsFact(
            'Estimación · próximos ${data.horizonDays} días',
            _number(total.central),
          ),
          StatsFact(
            'Banda empírica central 80 %',
            '${_number(total.lower)} — ${_number(total.upper)}',
          ),
          StatsFact(
            'Tendencia últimos 28 días',
            variation == null
                ? data.trendState
                : '${data.trendState} · ${variation >= 0 ? '+' : ''}${_number(variation)} %',
            alerta: data.trendState == 'BAJA',
          ),
          StatsFact('Historia útil', '${data.usefulDays} días'),
          StatsFact('Muestra mínima por día', '${data.minimumSamples} semanas'),
        ],
      ),
    );
  }

  Widget _historyPanel() => _panel(
    title: 'Lo observado recientemente',
    detail:
        'Últimos 28 días completos · ${_number(data.previousVisits)} antes → '
        '${_number(data.recentVisits)} ahora.',
    chart: PulsoLinea(
      puntos: [
        for (var index = 0; index < data.history.length; index += 1)
          PulsoChartDato(
            etiqueta: index % 7 == 0
                ? data.history[index].date.substring(5)
                : '',
            valor: data.history[index].visits,
          ),
      ],
      alto: 150,
      mostrarPuntos: false,
    ),
  );

  Widget _weeklyPanel() => _panel(
    title: 'Próximas semanas',
    detail: 'Punto = mediana · barra = percentil 10–90. Valores debajo.',
    chart: _ForecastBands(weeks: data.weeks),
  );

  Widget _weekdayPanel() => _panel(
    title: 'Patrón por día de semana',
    detail: 'Mediana histórica; la tabla conserva banda y tamaño de muestra.',
    chart: Column(
      children: [
        PulsoBarras(
          datos: [
            for (final day in data.weekdays)
              PulsoChartDato(etiqueta: day.label, valor: day.central),
          ],
        ),
        const SizedBox(height: 12),
        for (final day in data.weekdays)
          _dataRow(
            day.label,
            '${_number(day.central)} · ${_number(day.lower)}–${_number(day.upper)} · n=${day.samples}',
          ),
      ],
    ),
  );

  Widget _methodPanel() => _panel(
    title: 'Cómo se calcula',
    detail: 'La regla viaja desde el servidor y se muestra completa.',
    chart: Builder(
      builder: (context) {
        final tokens = PulsoTokens.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _methodLine(context, 'MÉTODO', data.methodName),
            _methodLine(context, 'ESTIMACIÓN', data.methodEstimate),
            _methodLine(context, 'INTERVALO', data.methodInterval),
            _methodLine(context, 'MÍNIMO', data.methodMinimum),
            const SizedBox(height: 8),
            Text(
              data.methodGuarantee,
              style: TextStyle(
                color: tokens.warning,
                fontSize: 11,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data.trendRule,
              style: TextStyle(color: tokens.muted, fontSize: 10),
            ),
          ],
        );
      },
    ),
  );

  Widget _tablePanel(BuildContext context) => _panel(
    title: 'Calendario verificable',
    detail:
        '${data.horizonFrom} → ${data.horizonTo}. Puedes copiarlo y contrastarlo.',
    action: PulsoSecondaryButton(
      key: const ValueKey('pronostico-copiar'),
      label: 'Copiar tabla',
      icon: Icons.copy_outlined,
      onPressed: () async {
        final csv = StringBuffer('fecha,dia,inferior,central,superior\n');
        for (final day in data.days) {
          csv.writeln(
            '${day.date},${day.label},${day.lower},${day.central},${day.upper}',
          );
        }
        await Clipboard.setData(ClipboardData(text: csv.toString()));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pronóstico copiado como CSV.')),
        );
      },
    ),
    chart: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Fecha')),
          DataColumn(label: Text('Día')),
          DataColumn(label: Text('P10'), numeric: true),
          DataColumn(label: Text('Mediana'), numeric: true),
          DataColumn(label: Text('P90'), numeric: true),
        ],
        rows: [
          for (final day in data.days)
            DataRow(
              key: ValueKey('pronostico-dia-${day.date}'),
              cells: [
                DataCell(Text(day.date)),
                DataCell(Text(day.label)),
                DataCell(Text(_number(day.lower))),
                DataCell(Text(_number(day.central))),
                DataCell(Text(_number(day.upper))),
              ],
            ),
        ],
      ),
    ),
  );

  Widget _responsivePair({
    required bool stacked,
    required Widget first,
    required Widget second,
  }) => stacked
      ? Column(children: [first, const SizedBox(height: 14), second])
      : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 14),
            Expanded(child: second),
          ],
        );

  Widget _panel({
    required String title,
    required String detail,
    required Widget chart,
    Widget? action,
  }) => PulsoPanel(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [StatsPanelTitle(title), if (action != null) action],
        ),
        const SizedBox(height: 3),
        Builder(
          builder: (context) => Text(
            detail,
            style: TextStyle(
              fontSize: 10,
              color: PulsoTokens.of(context).muted,
            ),
          ),
        ),
        const SizedBox(height: 16),
        chart,
      ],
    ),
  );

  Widget _methodLine(BuildContext context, String label, String value) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PulsoLabel(label),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: PulsoTokens.of(context).chalk,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      );

  Widget _dataRow(String label, String value) => Builder(
    builder: (context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: PulsoTokens.of(context).chalk,
                fontSize: 10,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              color: PulsoTokens.of(context).muted,
              fontSize: 9,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ForecastBands extends StatelessWidget {
  const _ForecastBands({required this.weeks});
  final List<ForecastWeek> weeks;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    if (weeks.isEmpty) {
      return const PulsoChartVacio(mensaje: 'Sin semanas proyectadas.');
    }
    final maximum = weeks.fold<double>(
      1,
      (value, week) => week.upper > value ? week.upper : value,
    );
    return Semantics(
      label: 'Bandas semanales de visitas previstas',
      child: SizedBox(
        height: 210,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final week in weeks)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final lowerY =
                                constraints.maxHeight *
                                (1 - week.lower / maximum);
                            final upperY =
                                constraints.maxHeight *
                                (1 - week.upper / maximum);
                            final centralY =
                                constraints.maxHeight *
                                (1 - week.central / maximum);
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        left: BorderSide(color: tokens.line),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 10,
                                  right: 10,
                                  top: upperY,
                                  height: (lowerY - upperY).clamp(
                                    2,
                                    constraints.maxHeight,
                                  ),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: tokens.accent.withValues(
                                        alpha: 0.18,
                                      ),
                                      border: Border.all(
                                        color: tokens.accent.withValues(
                                          alpha: 0.55,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 5,
                                  right: 5,
                                  top: centralY.clamp(
                                    0,
                                    constraints.maxHeight - 2,
                                  ),
                                  child: Container(
                                    height: 3,
                                    color: tokens.accent,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'S${week.week}',
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          color: tokens.chalk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _number(week.central),
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          color: tokens.chalk,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '${_number(week.lower)}–${_number(week.upper)}',
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          color: tokens.muted,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _number(num value) => NumberFormat('#,##0.##', 'es').format(value);
