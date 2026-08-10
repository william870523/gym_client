import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_charts.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../clients/presentation/state/clients_scope_filter_provider.dart';
import '../../../dashboard/presentation/state/dashboard_nav_provider.dart';
import '../../data/models/statistics_cohorts.dart';
import '../state/statistics_providers.dart';
import 'statistics_shared.dart';

/// Cohortes, demanda y calidad (docs/PLAN_ESTADISTICAS.md, fase E3-b).
///
/// Tres paneles porque son tres preguntas distintas, y una sola vista porque se
/// responden juntas: **cuántos se quedaron** (cohorte de alta), **cuándo
/// vienen** (mapa de demanda) y **qué parte de esas dos conclusiones es
/// confiable** (calidad de datos).
///
/// Lo que esta vista nunca hace:
///
///  - **no recalcula la supervivencia.** Quién se fue y qué día lo hizo lo
///    decide el motor canónico de retención; si no está disponible, la cohorte
///    se declara no disponible en vez de dibujarse con otra fórmula (regla 11);
///  - **no habla de ocupación.** El mapa enseña demanda observada. Un
///    porcentaje de ocupación necesita aforo por sede, que todavía no existe
///    (§5.2), y ponerlo sería inventar el denominador;
///  - **no esconde un hueco.** Un horizonte que aún no pudo cerrarse se dibuja
///    como abierto, no como cero.
class StatisticsCohortsPulsoView extends ConsumerWidget {
  const StatisticsCohortsPulsoView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consulta = ref.watch(cohortsQueryProvider);

    return PulsoThemeScope(
      child: Builder(
        builder: (context) => ColoredBox(
          color: PulsoTokens.of(context).floor,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compacto = constraints.maxWidth < 900;
              return SingleChildScrollView(
                padding: EdgeInsets.all(compacto ? 16 : 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const StatsHeader(
                      etiqueta: 'Estadística · cohortes y calidad',
                      titulo: 'PERMANENCIA',
                      descripcion:
                          'De los que entraron en cada mes, cuántos seguían a '
                          'los 30, 60 y 90 días; a qué horas viene la gente de '
                          'verdad; y qué huecos de datos impiden creerse el '
                          'resto. Ninguna cifra se calcula dos veces: la '
                          'supervivencia la decide el motor de retención.',
                    ),
                    const SizedBox(height: 14),
                    _Selectores(consulta: consulta),
                    const SizedBox(height: 14),
                    _PanelCohortes(consulta: consulta, compacto: compacto),
                    const SizedBox(height: 14),
                    _PanelDemanda(dias: consulta.days, compacto: compacto),
                    const SizedBox(height: 14),
                    _PanelCalidad(dias: consulta.days),
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

class _Selectores extends ConsumerWidget {
  const _Selectores({required this.consulta});

  final CohortsQuery consulta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cohortsQueryProvider.notifier);
    return PulsoPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const PulsoLabel('PERÍODO'),
              for (final entrada in const [
                (30, '30 días'),
                (90, '90 días'),
                (365, '12 meses'),
              ])
                if (consulta.days == entrada.$1)
                  PulsoPrimaryButton(
                    key: ValueKey('permanencia-periodo-${entrada.$1}'),
                    label: entrada.$2,
                    onPressed: () => notifier.setDays(entrada.$1),
                  )
                else
                  PulsoSecondaryButton(
                    key: ValueKey('permanencia-periodo-${entrada.$1}'),
                    label: entrada.$2,
                    onPressed: () => notifier.setDays(entrada.$1),
                  ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const PulsoLabel('COHORTE POR'),
              for (final entrada in const [
                ('mes', 'Mes'),
                ('semana', 'Semana'),
              ])
                if (consulta.granularity == entrada.$1)
                  PulsoPrimaryButton(
                    key: ValueKey('permanencia-cohorte-${entrada.$1}'),
                    label: entrada.$2,
                    onPressed: () => notifier.setGranularity(entrada.$1),
                  )
                else
                  PulsoSecondaryButton(
                    key: ValueKey('permanencia-cohorte-${entrada.$1}'),
                    label: entrada.$2,
                    onPressed: () => notifier.setGranularity(entrada.$1),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Cohortes ----------------------------------------------------------------

class _PanelCohortes extends ConsumerWidget {
  const _PanelCohortes({required this.consulta, required this.compacto});

  final CohortsQuery consulta;
  final bool compacto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(cohortsProvider(consulta));
    return estado.when(
      loading: () => const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.loading,
          message: 'Midiendo la supervivencia de cada cohorte…',
        ),
      ),
      error: (error, _) => PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.error,
          message:
              'No se pudieron calcular las cohortes.\n'
              '${statisticsErrorMessage(error)}',
          onRetry: () => ref.invalidate(cohortsProvider(consulta)),
        ),
      ),
      data: (data) => _CohortesCuerpo(data: data, compacto: compacto),
    );
  }
}

class _CohortesCuerpo extends StatelessWidget {
  const _CohortesCuerpo({required this.data, required this.compacto});

  final CohortsReport data;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);

    if (!data.available) {
      return PulsoPanel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StatsPanelTitle('Cohortes de alta'),
            const SizedBox(height: 8),
            PulsoStateView(
              kind: PulsoStateKind.empty,
              message: data.reason ?? 'Las cohortes no están disponibles.',
            ),
          ],
        ),
      );
    }

    return PulsoPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: StatsPanelTitle('Cohortes de alta')),
              Text(
                '${data.totalEntries} altas · ${data.cohorts.length} cohortes',
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 10,
                  color: tokens.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            data.definition,
            style: TextStyle(fontSize: 10, height: 1.4, color: tokens.muted),
          ),
          const SizedBox(height: 14),
          // Totales del período: la lectura de un vistazo, antes de la tabla.
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [
              for (final dias in data.horizons)
                _RetencionTotal(
                  dias: dias,
                  horizonte: data.totalHorizonOf(dias),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _TablaCohortes(data: data, compacto: compacto),
          const SizedBox(height: 12),
          if (data.maturityCutoff != null)
            Text(
              'Corte de madurez ${data.maturityCutoff} · gracia '
              '${data.graceDays} día(s). Más allá de ese corte hay contratos '
              'todavía dentro de su gracia: pueden renovar, así que no se '
              'cuentan ni a favor ni en contra.',
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontSize: 9,
                height: 1.5,
                color: tokens.muted,
              ),
            ),
          if (data.membersWithoutEntry > 0) ...[
            const SizedBox(height: 6),
            Text(
              '${data.membersWithoutEntry} socio(s) sin alta identificable no '
              'pertenecen a ninguna cohorte. No se reparten.',
              style: TextStyle(fontSize: 9, color: tokens.warning),
            ),
          ],
        ],
      ),
    );
  }
}

/// Una tasa de retención con su denominador, como manda la regla 7.
class _RetencionTotal extends StatelessWidget {
  const _RetencionTotal({required this.dias, required this.horizonte});

  final int dias;
  final CohortHorizon? horizonte;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final h = horizonte;
    final abierto = h == null || h.mature == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          abierto ? '—' : '${h.ratePct?.toStringAsFixed(1)} %',
          style: TextStyle(
            fontFamily: PulsoFonts.display,
            fontSize: 30,
            height: 1,
            fontWeight: FontWeight.w700,
            color: tokens.chalk,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          abierto
              ? 'Retención a $dias días · sin cohortes maduras'
              : 'Retención a $dias días · ${h.retained} de ${h.mature}',
          style: TextStyle(fontSize: 11, color: tokens.muted),
        ),
        if (h != null && h.open > 0)
          Text(
            '${h.open} todavía en curso',
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

class _TablaCohortes extends StatelessWidget {
  const _TablaCohortes({required this.data, required this.compacto});

  final CohortsReport data;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    if (data.cohorts.isEmpty) {
      return const PulsoStateView(
        kind: PulsoStateKind.empty,
        message:
            'No hubo ninguna alta en el período elegido, así que no hay '
            'cohorte que seguir.',
      );
    }

    final anchoMinimo = 240.0 + data.horizons.length * 120.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabla = ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: compacto ? anchoMinimo : constraints.maxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const SizedBox(width: 120, child: PulsoLabel('COHORTE')),
                    const SizedBox(width: 64, child: PulsoLabel('ALTAS')),
                    for (final dias in data.horizons)
                      SizedBox(width: 120, child: PulsoLabel('$dias DÍAS')),
                    const Expanded(child: PulsoLabel('MEDIANAS')),
                  ],
                ),
              ),
              for (final cohorte in data.cohorts)
                _FilaCohorte(
                  cohorte: cohorte,
                  horizontes: data.horizons,
                  tokens: tokens,
                ),
            ],
          ),
        );
        // La tabla scrollea por dentro en compacto; la vista no se ensancha.
        return compacto
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: tabla,
              )
            : tabla;
      },
    );
  }
}

class _FilaCohorte extends StatelessWidget {
  const _FilaCohorte({
    required this.cohorte,
    required this.horizontes,
    required this.tokens,
  });

  final Cohort cohorte;
  final List<int> horizontes;
  final PulsoTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('cohorte-${cohorte.key}'),
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cohorte.label,
                  style: TextStyle(fontSize: 12, color: tokens.chalk),
                ),
                Text(
                  '${cohorte.start} → ${cohorte.end}',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 8,
                    color: tokens.muted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              '${cohorte.entries}',
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.chalk,
              ),
            ),
          ),
          for (final dias in horizontes)
            SizedBox(
              width: 120,
              child: _CeldaHorizonte(
                horizonte: cohorte.horizonOf(dias),
                tokens: tokens,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Mediana(
                  etiqueta: '1.ª renovación',
                  mediana: cohorte.firstRenewal,
                  tokens: tokens,
                ),
                _Mediana(
                  etiqueta: 'hasta la baja',
                  mediana: cohorte.timeToLeave,
                  tokens: tokens,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CeldaHorizonte extends StatelessWidget {
  const _CeldaHorizonte({required this.horizonte, required this.tokens});

  final CohortHorizon? horizonte;
  final PulsoTokens tokens;

  @override
  Widget build(BuildContext context) {
    final h = horizonte;
    // Sin ventana cerrada no hay cifra: se dice «en curso», nunca cero (regla 5).
    if (h == null || h.mature == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '—',
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 12,
              color: tokens.muted,
            ),
          ),
          Text(
            h == null ? 'sin datos' : 'en curso (${h.open})',
            style: TextStyle(fontSize: 9, color: tokens.muted),
          ),
        ],
      );
    }

    // El color no juzga: una barra llena es «se quedaron», y el acento se usa
    // para la parte retenida porque es lo que la cohorte viene a medir.
    final proporcion = (h.retained / h.mature).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${h.ratePct?.toStringAsFixed(1)} %',
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.chalk,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  border: Border.all(color: tokens.line),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: proporcion,
                  child: ColoredBox(color: tokens.accent),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        Text(
          '${h.retained}/${h.mature}'
          '${h.open > 0 ? " · ${h.open} en curso" : ""}',
          style: TextStyle(fontSize: 9, color: tokens.muted),
        ),
        if (h.lowSample)
          Text(
            'muestra baja',
            style: TextStyle(
              fontFamily: PulsoFonts.display,
              fontSize: 9,
              letterSpacing: 0.6,
              color: tokens.warning,
            ),
          ),
      ],
    );
  }
}

class _Mediana extends StatelessWidget {
  const _Mediana({
    required this.etiqueta,
    required this.mediana,
    required this.tokens,
  });

  final String etiqueta;
  final CohortMedian mediana;
  final PulsoTokens tokens;

  @override
  Widget build(BuildContext context) {
    final dias = mediana.medianDays;
    return Text(
      dias == null
          ? '$etiqueta: — (0 de ${mediana.base})'
          : '$etiqueta: ${_sinCeroSobrante(dias)} d '
                '(${mediana.members} de ${mediana.base})',
      style: TextStyle(
        fontFamily: PulsoFonts.mono,
        fontSize: 9,
        color: tokens.muted,
      ),
    );
  }
}

String _sinCeroSobrante(double valor) =>
    valor == valor.roundToDouble() ? valor.toStringAsFixed(0) : '$valor';

// --- Demanda -----------------------------------------------------------------

class _PanelDemanda extends ConsumerWidget {
  const _PanelDemanda({required this.dias, required this.compacto});

  final int dias;
  final bool compacto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(demandProvider(dias));
    return estado.when(
      loading: () => const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.loading,
          message: 'Proyectando cada entrada a la hora local de la sede…',
        ),
      ),
      error: (error, _) => PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.error,
          message:
              'No se pudo calcular el mapa de demanda.\n'
              '${statisticsErrorMessage(error)}',
          onRetry: () => ref.invalidate(demandProvider(dias)),
        ),
      ),
      data: (data) => _DemandaCuerpo(data: data, compacto: compacto),
    );
  }
}

class _DemandaCuerpo extends StatelessWidget {
  const _DemandaCuerpo({required this.data, required this.compacto});

  final DemandReport data;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: StatsPanelTitle('Demanda observada · día × hora'),
              ),
              Text(
                data.measure.toUpperCase(),
                key: const ValueKey('demanda-medida'),
                style: TextStyle(
                  fontFamily: PulsoFonts.display,
                  fontSize: 10,
                  letterSpacing: 0.6,
                  color: tokens.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            data.definition,
            style: TextStyle(fontSize: 10, height: 1.4, color: tokens.muted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 22,
            runSpacing: 10,
            children: [
              StatsFact('Visitas del período', '${data.visits}'),
              StatsFact('Socios distintos', '${data.members}'),
              StatsFact(
                'Visitas por socio',
                data.visitsPerMember == null
                    ? '—'
                    : data.visitsPerMember!.toStringAsFixed(2),
              ),
              StatsFact(
                'Media diaria',
                data.dailyAverage == null
                    ? '—'
                    : data.dailyAverage!.toStringAsFixed(2),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (data.isEmpty)
            const PulsoStateView(
              kind: PulsoStateKind.empty,
              message:
                  'No hubo ninguna entrada registrada en el período, así que '
                  'no hay demanda que dibujar.',
            )
          else
            PulsoMapaCalor(
              key: const ValueKey('demanda-mapa'),
              filas: [for (final fila in data.rows) fila.label],
              columnas: data.dayLabels,
              valores: [
                for (final fila in data.rows)
                  [for (final celda in fila.cells) celda.visits.toDouble()],
              ],
            ),
          if (data.peaks.isNotEmpty) ...[
            const SizedBox(height: 14),
            const StatsSubLabel('CUÁNDO SE LLENA'),
            const SizedBox(height: 6),
            for (final pico in data.peaks)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '${pico.day} ${pico.hourLabel} · ${pico.visits} visitas de '
                  '${pico.members} socios'
                  '${pico.sharePct == null ? "" : " · ${pico.sharePct!.toStringAsFixed(1)} % del período"}',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 10,
                    color: tokens.chalk,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 14),
          _DeclaradaVsObservada(data: data, compacto: compacto),
          const SizedBox(height: 12),
          for (final aviso in data.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '· $aviso',
                style: TextStyle(
                  fontSize: 9,
                  height: 1.5,
                  color: tokens.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lo que el socio dijo frente a lo que hizo (regla 9).
///
/// Las dos mitades se enseñan por separado y con su unidad escrita: una cuenta
/// socios que declararon una franja y la otra cuenta visitas. Sumarlas o
/// dibujarlas en la misma dona sería comparar personas con entradas.
class _DeclaradaVsObservada extends ConsumerWidget {
  const _DeclaradaVsObservada({required this.data, required this.compacto});

  final DemandReport data;
  final bool compacto;

  void _abrirSocio(WidgetRef ref, FranjaMismatch fila) {
    ref.read(selectedMemberProvider.notifier).select(fila.ci);
    ref.read(dashboardNavProvider.notifier).setIndex(31);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StatsSubLabel('FRANJA DECLARADA CONTRA FRANJA OBSERVADA'),
        const SizedBox(height: 6),
        Text(
          data.matchPct == null
              ? 'Todavía no hay a quién comparar: hacen falta socios que hayan '
                    'declarado franja y además hayan venido.'
              : '${data.matching} de ${data.comparable} socios vienen en la '
                    'franja que declararon (${data.matchPct!.toStringAsFixed(1)} %). '
                    '${data.withoutDeclared} no declararon ninguna y '
                    '${data.withoutVisits} no vinieron en el período.',
          style: TextStyle(fontSize: 11, height: 1.4, color: tokens.chalk),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 18,
          runSpacing: 12,
          children: [
            SizedBox(
              width: compacto ? double.infinity : 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // La unidad va en el rótulo, no se deduce: una cuenta
                  // personas y la otra entradas.
                  const StatsSubLabel('DECLARADA · SOCIOS'),
                  const SizedBox(height: 6),
                  PulsoBarras(
                    datos: [
                      for (final fila in data.declaredFranjas)
                        PulsoChartDato(
                          etiqueta: fila.franja,
                          valor: fila.value.toDouble(),
                        ),
                    ],
                    mensajeVacio: 'Nadie declaró franja.',
                  ),
                ],
              ),
            ),
            SizedBox(
              width: compacto ? double.infinity : 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const StatsSubLabel('OBSERVADA · VISITAS'),
                  const SizedBox(height: 6),
                  PulsoBarras(
                    datos: [
                      for (final fila in data.observedFranjas)
                        PulsoChartDato(
                          etiqueta: fila.franja,
                          valor: fila.value.toDouble(),
                        ),
                    ],
                    mensajeVacio: 'Sin visitas en el período.',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (data.mismatchTotal == 0)
          Text(
            'Ningún socio viene sistemáticamente en una franja distinta de la '
            'que declaró.',
            key: const ValueKey('demanda-sin-discrepancias'),
            style: TextStyle(fontSize: 10, color: tokens.muted),
          )
        else ...[
          Text(
            'Dicen una franja y vienen en otra (${data.mismatchTotal}):',
            style: TextStyle(fontSize: 10, color: tokens.chalk),
          ),
          const SizedBox(height: 6),
          for (final fila in data.mismatches)
            InkWell(
              key: ValueKey('discrepancia-${fila.ci}'),
              onTap: () => _abrirSocio(ref, fila),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: tokens.line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        fila.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: tokens.chalk),
                      ),
                    ),
                    Text(
                      'dice ${fila.declared} · viene ${fila.observed} · '
                      '${fila.visits} visitas',
                      style: TextStyle(
                        fontFamily: PulsoFonts.mono,
                        fontSize: 9,
                        color: tokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// --- Calidad -----------------------------------------------------------------

class _PanelCalidad extends ConsumerWidget {
  const _PanelCalidad({required this.dias});

  final int dias;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(dataQualityProvider(dias));
    return estado.when(
      loading: () => const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.loading,
          message: 'Revisando la confiabilidad de los datos…',
        ),
      ),
      error: (error, _) => PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.error,
          message:
              'No se pudo revisar la calidad de los datos.\n'
              '${statisticsErrorMessage(error)}',
          onRetry: () => ref.invalidate(dataQualityProvider(dias)),
        ),
      ),
      data: (data) => _CalidadCuerpo(data: data),
    );
  }
}

class _CalidadCuerpo extends ConsumerWidget {
  const _CalidadCuerpo({required this.data});

  final QualityReport data;

  /// Lleva al sitio donde el hueco se puede cerrar. La calidad no corrige nada
  /// por su cuenta: conduce al flujo que sí puede hacerlo.
  void _abrir(WidgetRef ref, QualityTarget destino) {
    if (destino.kind == 'retencion') {
      ref.read(dashboardNavProvider.notifier).setIndex(23);
      return;
    }
    final atributo = ClientsAttribute.fromDimension(destino.attribute ?? '');
    if (atributo == null) return;
    ref
        .read(clientsScopeFilterProvider.notifier)
        .showAttribute(
          attribute: atributo,
          value: destino.value ?? kSinDatoKey,
          label: destino.value ?? kSinDatoKey,
        );
    ref.read(dashboardNavProvider.notifier).setIndex(1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: StatsPanelTitle('Calidad de datos')),
              Text(
                '${data.danger} peligro · ${data.warning} aviso · '
                '${data.ok} en orden',
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 10,
                  color: tokens.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Qué conclusiones no son confiables y por qué. Cada control publica '
            'su denominador y la regla con la que se juzgó; ninguno corrige '
            'nada a escondidas.',
            style: TextStyle(fontSize: 10, height: 1.4, color: tokens.muted),
          ),
          const SizedBox(height: 14),
          if (!data.dropoutsEvaluated && data.dropoutsReason != null)
            Padding(
              key: const ValueKey('calidad-bajas-sin-evaluar'),
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                data.dropoutsReason!,
                style: TextStyle(fontSize: 10, color: tokens.warning),
              ),
            ),
          for (final control in data.controls)
            _FilaControl(
              control: control,
              tokens: tokens,
              onAbrir: control.target == null
                  ? null
                  : () => _abrir(ref, control.target!),
            ),
          const SizedBox(height: 10),
          for (final aviso in data.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '· $aviso',
                style: TextStyle(
                  fontSize: 9,
                  height: 1.5,
                  color: tokens.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilaControl extends StatelessWidget {
  const _FilaControl({
    required this.control,
    required this.tokens,
    required this.onAbrir,
  });

  final QualityControl control;
  final PulsoTokens tokens;
  final VoidCallback? onAbrir;

  @override
  Widget build(BuildContext context) {
    final color = switch (control.severity) {
      QualitySeverity.danger => tokens.danger,
      QualitySeverity.warning => tokens.warning,
      QualitySeverity.ok => tokens.muted,
    };
    final fila = Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 3, height: 34, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  control.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.chalk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  control.detail,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.45,
                    color: tokens.muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  control.rule,
                  style: TextStyle(fontSize: 8, height: 1.5, color: tokens.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 108,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${control.affected} / ${control.base}',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  // La cobertura no vale para todos los controles: cuando el
                  // servidor no la manda se dice, en vez de calcular una que no
                  // significaría nada.
                  control.coveragePct == null
                      ? 'sin cobertura aplicable'
                      : 'cobertura ${control.coveragePct!.toStringAsFixed(1)} %',
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 9, color: tokens.muted),
                ),
                if (onAbrir != null)
                  Text(
                    'ver registros →',
                    style: TextStyle(
                      fontFamily: PulsoFonts.display,
                      fontSize: 9,
                      letterSpacing: 0.4,
                      color: tokens.accent,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return onAbrir == null
        ? fila
        : InkWell(
            key: ValueKey('calidad-${control.id}'),
            onTap: onAbrir,
            child: fila,
          );
  }
}
