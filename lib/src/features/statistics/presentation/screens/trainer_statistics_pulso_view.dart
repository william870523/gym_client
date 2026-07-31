import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_charts.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../financials/data/models/currency_model.dart';
import '../../../financials/presentation/state/currency_notifier.dart';
import '../../../dashboard/presentation/state/dashboard_nav_provider.dart';
import '../../../trainers/data/models/trainer_model.dart';
import '../../../trainers/presentation/providers/trainer_notifier.dart';
import '../../data/models/trainer_statistics.dart';
import '../state/statistics_providers.dart';
import 'statistics_shared.dart';

/// Perfil estadístico de un entrenador (docs/PLAN_ESTADISTICAS.md §4.1).
///
/// Responde la pregunta que el dueño hizo primero —cuántos socios ha ganado y
/// cuántos ha perdido— y la que de verdad lo juzga: **qué porcentaje de los
/// suyos renovó**. Tener muchos socios no dice nada si se van todos.
class TrainerStatisticsPulsoView extends ConsumerWidget {
  const TrainerStatisticsPulsoView({super.key, this.showSelector = false});

  final bool showSelector;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PulsoThemeScope(
      child: Builder(
        builder: (context) => ColoredBox(
          color: PulsoTokens.of(context).floor,
          child: LayoutBuilder(
            builder: (context, restricciones) {
              final compacto = restricciones.maxWidth < 900;
              return SingleChildScrollView(
                padding: EdgeInsets.all(compacto ? 16 : 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!showSelector) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PulsoSecondaryButton(
                          label: 'Volver a Entrenadores',
                          icon: Icons.arrow_back,
                          onPressed: () => ref
                              .read(dashboardNavProvider.notifier)
                              .setIndex(17),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const StatsHeader(
                      etiqueta: 'Estadística · entrenador',
                      titulo: 'PERFIL DEL\nENTRENADOR',
                      descripcion:
                          'Con qué cartera trabaja, cuántos socios ha ganado y '
                          'cuántos ha perdido, y qué porcentaje de los suyos '
                          'renovó, que es la cifra que de verdad lo juzga.',
                    ),
                    if (showSelector) ...[
                      const SizedBox(height: 14),
                      _Selector(),
                    ],
                    const SizedBox(height: 14),
                    _Cuerpo(compacto: compacto, showSelector: showSelector),
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

class _Selector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entrenadores =
        ref.watch(trainerProvider).value ?? const <TrainerModel>[];
    final elegido = ref.watch(selectedTrainerProvider);
    return StatsChipSelector(
      vacio: 'No hay entrenadores registrados todavía.',
      opciones: [
        for (final e in entrenadores)
          StatsChipOption(
            id: e.id,
            texto: '${e.nombres ?? ''} ${e.apellidos ?? ''}'.trim(),
            nota: e.ci,
            atenuado: !e.activo,
          ),
      ],
      seleccionado: elegido,
      onSelect: (id) => ref.read(selectedTrainerProvider.notifier).select(id),
    );
  }
}

class _Cuerpo extends ConsumerWidget {
  const _Cuerpo({required this.compacto, required this.showSelector});

  final bool compacto;
  final bool showSelector;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(selectedTrainerProvider);
    if (id == null) {
      return PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.empty,
          message: showSelector
              ? 'Elige un entrenador arriba para ver su cartera: altas y '
                    'bajas, composición, retención y los socios más constantes.'
              : 'Vuelve a Entrenadores, busca a la persona por nombre o carné '
                    'y abre su estadística desde la ficha.',
        ),
      );
    }

    return ref
        .watch(trainerStatisticsProvider(id))
        .when(
          loading: () => const PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.loading,
              message: 'Calculando el perfil del entrenador…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message:
                  'No se pudo calcular la estadística.\n'
                  '${statisticsErrorMessage(error)}',
              onRetry: () => ref.invalidate(trainerStatisticsProvider(id)),
            ),
          ),
          data: (datos) => _Perfil(datos: datos, compacto: compacto),
        );
  }
}

class _Perfil extends ConsumerWidget {
  const _Perfil({required this.datos, required this.compacto});

  final TrainerStatistics datos;
  final bool compacto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    final monedas =
        ref.watch(currencyProvider).value ?? const <CurrencyModel>[];
    final cartera = datos.cartera;

    final paneles = <Widget>[
      _PanelCartera(datos: datos),
      _PanelComposicion(datos: datos),
      _PanelConstancia(datos: datos),
      _PanelDinero(datos: datos, monedas: monedas),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PulsoMetricStrip(
          metrics: [
            PulsoMetricData(
              value: '${cartera.activos}',
              label: 'Socios activos',
              note: 'de ${cartera.historicos} que ha atendido alguna vez',
              emphasis: true,
            ),
            PulsoMetricData(
              value: datos.retencion.etiqueta,
              label: 'Retención',
              note: 'contratos renovados · ${datos.retencion.detalle}',
              warning: (datos.retencion.porcentaje ?? 100) < 40,
            ),
            PulsoMetricData(
              value: '${cartera.perdidos}',
              label: 'Asignaciones cerradas',
              note: cartera.motivosDeCierre.isEmpty
                  ? 'sin motivo registrado'
                  : 'principal: ${cartera.motivosDeCierre.first.etiqueta}',
              warning: cartera.perdidos > cartera.activos,
            ),
            PulsoMetricData(
              value: datos.composicion.planLider?.etiqueta ?? '—',
              label: 'Plan que más atiende',
              note: datos.composicion.planLider == null
                  ? 'cartera vacía'
                  : '${datos.composicion.planLider!.total} socios',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (compacto)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final panel in paneles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: panel,
                ),
            ],
          )
        else
          Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: paneles[0]),
                  const SizedBox(width: 12),
                  Expanded(child: paneles[1]),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: paneles[2]),
                  const SizedBox(width: 12),
                  Expanded(child: paneles[3]),
                ],
              ),
            ],
          ),
        const SizedBox(height: 10),
        StatsPie(
          zona: datos.zona,
          diaNegocio: datos.diaNegocio,
          tokens: tokens,
        ),
      ],
    );
  }
}

class _PanelCartera extends StatelessWidget {
  const _PanelCartera({required this.datos});

  final TrainerStatistics datos;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final c = datos.cartera;

    return PulsoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StatsPanelTitle('¿Gana socios, o los pierde?'),
          const SizedBox(height: 6),
          Text(
            'Altas y bajas de asignación, mes a mes. Las dos juntas: solo las '
            'altas dibujarían un entrenador que nunca perdió a nadie.',
            style: TextStyle(fontSize: 11, height: 1.5, color: tokens.muted),
          ),
          const SizedBox(height: 12),
          PulsoFlujo(
            etiquetaEntran: 'altas',
            etiquetaSalen: 'bajas',
            anchoEtiqueta: 52,
            datos: [
              for (final m in c.movimientos)
                PulsoFlujoDato(
                  etiqueta: mesCorto(m.mes),
                  entran: m.altas,
                  salen: m.bajas,
                ),
            ],
            mensajeVacio: 'Todavía no se le ha asignado ningún socio.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              StatsFact('Activos hoy', '${c.activos}'),
              StatsFact('Histórico atendido', '${c.historicos}'),
              StatsFact(
                'Asignaciones cerradas',
                '${c.perdidos}',
                alerta: c.perdidos > c.activos,
              ),
              StatsFact(
                'Antigüedad',
                datos.entrenador.antiguedadDias == null
                    ? '—'
                    : '${datos.entrenador.antiguedadDias} días',
              ),
            ],
          ),
          const SizedBox(height: 14),
          const StatsSubLabel('Por qué se cerraron'),
          const SizedBox(height: 8),
          PulsoBarras(
            anchoEtiqueta: 150,
            datos: datosBarra(c.motivosDeCierre),
            mensajeVacio: 'Ninguna asignación cerrada todavía.',
          ),
          const SizedBox(height: 8),
          Text(
            'La cartera se lee del historial de asignaciones, no del entrenador '
            'que figura hoy en la ficha del socio: con eso, nadie habría '
            'perdido nunca a nadie.',
            style: TextStyle(fontSize: 10, height: 1.4, color: tokens.muted),
          ),
        ],
      ),
    );
  }
}

class _PanelComposicion extends StatelessWidget {
  const _PanelComposicion({required this.datos});

  final TrainerStatistics datos;

  @override
  Widget build(BuildContext context) {
    final c = datos.composicion;
    return PulsoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StatsPanelTitle('¿Con qué cartera trabaja?'),
          const SizedBox(height: 12),
          const StatsSubLabel('Sexo'),
          const SizedBox(height: 8),
          PulsoDona(
            datos: datosDona(c.porSexo),
            diametro: 108,
            grosor: 15,
            centroValor: '${datos.cartera.activos}',
            centroTitulo: 'activos',
            mensajeVacio: 'Cartera vacía.',
          ),
          const SizedBox(height: 14),
          const StatsSubLabel('Plan'),
          const SizedBox(height: 8),
          PulsoBarras(
            anchoEtiqueta: 128,
            datos: datosBarra(c.porPlan),
            mensajeVacio: 'Sin planes en la cartera.',
          ),
          const SizedBox(height: 14),
          const StatsSubLabel('Franja horaria'),
          const SizedBox(height: 8),
          PulsoBarras(
            anchoEtiqueta: 84,
            resaltarPrimero: false,
            datos: datosBarra(c.porFranja),
            mensajeVacio: 'Sin franja declarada.',
          ),
          const SizedBox(height: 14),
          const StatsSubLabel('Categoría'),
          const SizedBox(height: 8),
          PulsoBarras(
            anchoEtiqueta: 84,
            datos: datosBarra(c.porCategoria),
            mensajeVacio: 'Sin categoría registrada.',
          ),
          if (c.porNacionalidad.length > 1) ...[
            const SizedBox(height: 14),
            const StatsSubLabel('Nacionalidad'),
            const SizedBox(height: 8),
            PulsoBarras(
              anchoEtiqueta: 112,
              datos: datosBarra(c.porNacionalidad),
              mensajeVacio: 'Sin nacionalidad registrada.',
            ),
          ],
        ],
      ),
    );
  }
}

class _PanelConstancia extends StatelessWidget {
  const _PanelConstancia({required this.datos});

  final TrainerStatistics datos;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StatsPanelTitle('¿Sus socios vienen?'),
          const SizedBox(height: 12),
          StatsRate(
            tasa: datos.retencion,
            titulo: 'retención de sus contratos',
            tokens: tokens,
          ),
          const SizedBox(height: 16),
          const StatsSubLabel('Los más constantes'),
          const SizedBox(height: 8),
          PulsoBarras(
            anchoEtiqueta: 150,
            datos: [
              for (final s in datos.masConstantes)
                PulsoChartDato(
                  etiqueta: s.nombre,
                  valor: s.visitas.toDouble(),
                  nota: 'visitas',
                ),
            ],
            mensajeVacio: 'Sin visitas registradas en su cartera.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              StatsFact(
                'Visitas medias',
                datos.visitasMediasPorSocio == null
                    ? '—'
                    : '${datos.visitasMediasPorSocio}',
              ),
              StatsFact(
                'Estado',
                datos.entrenador.activo ? 'activo' : 'dado de baja',
                alerta: !datos.entrenador.activo,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Las visitas medias se calculan sobre los socios que se muestran '
            'aquí, no sobre la cartera entera: llamarlas «media de la cartera» '
            'sería exagerar con una muestra parcial.',
            style: TextStyle(fontSize: 10, height: 1.4, color: tokens.muted),
          ),
        ],
      ),
    );
  }
}

class _PanelDinero extends StatelessWidget {
  const _PanelDinero({required this.datos, required this.monedas});

  final TrainerStatistics datos;
  final List<CurrencyModel> monedas;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StatsPanelTitle('¿Cuánto ingreso se le atribuye?'),
          const SizedBox(height: 12),
          if (datos.ingresos.isEmpty)
            const PulsoChartVacio(
              mensaje: 'Todavía no se le ha atribuido ningún cobro.',
              alto: 70,
            )
          else
            Column(
              children: [
                for (final ingreso in datos.ingresos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _TarjetaIngreso(
                      ingreso: ingreso,
                      nombre: nombreMoneda(monedas, ingreso.monedaId),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            'Ingreso atribuido, no comisión liquidada: el margen por entrenador '
            'vive en Contabilidad y se lee del informe canónico, no se '
            'recalcula aquí. Las divisas nunca se suman entre sí.',
            style: TextStyle(fontSize: 10, height: 1.4, color: tokens.muted),
          ),
        ],
      ),
    );
  }
}

class _TarjetaIngreso extends StatelessWidget {
  const _TarjetaIngreso({required this.ingreso, required this.nombre});

  final TrainerIncome ingreso;
  final String nombre;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(border: Border.all(color: tokens.line)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ingreso.total.toStringAsFixed(2),
                  style: TextStyle(
                    fontFamily: PulsoFonts.display,
                    fontSize: 24,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: tokens.chalk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  nombre,
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 9,
                    color: tokens.muted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${ingreso.cobros} cobro(s)',
                style: TextStyle(fontSize: 11, color: tokens.chalk),
              ),
              const SizedBox(height: 3),
              Text(
                'ticket ${ingreso.ticketMedio.toStringAsFixed(2)}',
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 10,
                  color: tokens.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
