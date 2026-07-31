import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_charts.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../dashboard/presentation/state/dashboard_nav_provider.dart';
import '../../../financials/data/models/currency_model.dart';
import '../../../financials/presentation/state/currency_notifier.dart';
import '../../../products/data/models/payment_plan_model.dart';
import '../../../products/presentation/state/payment_plan_notifier.dart';
import '../../data/models/plan_statistics.dart';
import '../state/statistics_providers.dart';
import 'statistics_shared.dart';

/// Perfil estadístico de un plan (docs/PLAN_ESTADISTICAS.md §4.2).
///
/// El panel que manda es el de **movilidad**, y va primero y a ancho completo a
/// propósito: es el único sitio del sistema donde se ve si un plan capta socios
/// de otros o si alimenta a los demás. Lo demás —cuántos lo tienen, si renuevan,
/// cuánto deja, si se usa— ya se intuía por otras vías; esto no.
class PlanStatisticsPulsoView extends ConsumerWidget {
  const PlanStatisticsPulsoView({super.key, this.showSelector = false});

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
                          label: 'Volver a Planes',
                          icon: Icons.arrow_back,
                          onPressed: () => ref
                              .read(dashboardNavProvider.notifier)
                              .setIndex(14),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const StatsHeader(
                      etiqueta: 'Estadística · plan',
                      titulo: 'PERFIL DEL\nPLAN',
                      descripcion:
                          'Si el producto funciona: quién lo contrata, si lo '
                          'renuevan, cuánto deja, si se usa de verdad y —lo que '
                          'más dice— a qué plan se van los que lo dejan.',
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
    final planes =
        ref.watch(paymentPlanProvider).value ?? const <PaymentPlanModel>[];
    final elegido = ref.watch(selectedPlanProvider);
    return StatsChipSelector(
      vacio: 'No hay planes configurados todavía.',
      opciones: [
        for (final plan in planes)
          if (plan.id != null)
            StatsChipOption(
              id: plan.id!,
              texto: plan.nombre,
              nota: plan.codigo ?? '${plan.duracion} días',
              atenuado: !plan.activo,
            ),
      ],
      seleccionado: elegido,
      onSelect: (id) => ref.read(selectedPlanProvider.notifier).select(id),
    );
  }
}

class _Cuerpo extends ConsumerWidget {
  const _Cuerpo({required this.compacto, required this.showSelector});

  final bool compacto;
  final bool showSelector;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(selectedPlanProvider);
    if (id == null) {
      return PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.empty,
          message: showSelector
              ? 'Elige un plan arriba para ver su perfil: contratación, '
                    'composición, movilidad entre planes, dinero y uso real.'
              : 'Vuelve a Planes, busca el producto por nombre o código y '
                    'abre su estadística desde la ficha.',
        ),
      );
    }

    return ref
        .watch(planStatisticsProvider(id))
        .when(
          loading: () => const PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.loading,
              message: 'Calculando el perfil del plan…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message:
                  'No se pudo calcular la estadística.\n'
                  '${statisticsErrorMessage(error)}',
              onRetry: () => ref.invalidate(planStatisticsProvider(id)),
            ),
          ),
          data: (datos) => _Perfil(datos: datos, compacto: compacto),
        );
  }
}

class _Perfil extends ConsumerWidget {
  const _Perfil({required this.datos, required this.compacto});

  final PlanStatistics datos;
  final bool compacto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    final monedas =
        ref.watch(currencyProvider).value ?? const <CurrencyModel>[];
    final c = datos.contratacion;

    final paneles = <Widget>[
      _PanelContratacion(datos: datos),
      _PanelComposicion(datos: datos),
      _PanelDinero(datos: datos, monedas: monedas),
      _PanelUso(datos: datos),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PulsoMetricStrip(
          metrics: [
            PulsoMetricData(
              value: '${c.vigentes}',
              label: 'Contratos vigentes',
              note: 'de ${c.socios} socios que han pasado por el plan',
              emphasis: true,
            ),
            PulsoMetricData(
              value: c.tasaRenovacion.etiqueta,
              label: 'Renovación',
              note: c.tasaRenovacion.detalle,
              warning: (c.tasaRenovacion.porcentaje ?? 100) < 40,
            ),
            PulsoMetricData(
              value: datos.movilidad.saldo == 0
                  ? '±0'
                  : '${datos.movilidad.saldo > 0 ? '+' : ''}${datos.movilidad.saldo}',
              label: 'Saldo de cambios',
              note: datos.movilidad.saldo > 0
                  ? 'capta socios de otros planes'
                  : datos.movilidad.saldo < 0
                  ? 'los socios suben a otros planes'
                  : 'entran tantos como salen',
            ),
            PulsoMetricData(
              value: datos.uso.visitasPorSocio == null
                  ? '—'
                  : '${datos.uso.visitasPorSocio}',
              label: 'Visitas por socio',
              note: datos.uso.sociosConCobertura == 0
                  ? 'sin socios con los que comparar'
                  : 'de ${datos.uso.sociosConCobertura} socios con cobertura',
            ),
          ],
        ),
        const SizedBox(height: 12),
        // La movilidad va sola y a ancho completo: es la razón de esta vista.
        _PanelMovilidad(datos: datos),
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

class _PanelMovilidad extends StatelessWidget {
  const _PanelMovilidad({required this.datos});

  final PlanStatistics datos;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final m = datos.movilidad;

    // Una fila por plan, con lo que entra y lo que sale de cada uno.
    final porPlan = <String, PulsoFlujoDato>{};
    for (final e in m.vienenDe) {
      porPlan[e.etiqueta] = PulsoFlujoDato(
        etiqueta: e.etiqueta,
        entran: e.total,
        salen: porPlan[e.etiqueta]?.salen ?? 0,
      );
    }
    for (final s in m.seVanA) {
      porPlan[s.etiqueta] = PulsoFlujoDato(
        etiqueta: s.etiqueta,
        entran: porPlan[s.etiqueta]?.entran ?? 0,
        salen: s.total,
      );
    }

    return PulsoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StatsPanelTitle('¿Capta socios, o alimenta a otros planes?'),
          const SizedBox(height: 6),
          Text(
            'Cada fila es otro plan. A la derecha, los socios que llegaron '
            'desde él; a la izquierda, los que se fueron hacia él. Las dos '
            'mitades comparten escala, así que el desequilibrio se ve sin leer '
            'las cifras.',
            style: TextStyle(fontSize: 11, height: 1.5, color: tokens.muted),
          ),
          const SizedBox(height: 14),
          PulsoFlujo(
            datos: porPlan.values.toList(),
            mensajeVacio:
                'Ningún socio ha cambiado de plan hacia o desde éste todavía.',
          ),
          if (!m.vacia) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(border: Border.all(color: tokens.line)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _lectura(m, datos.plan.nombre),
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: tokens.chalk,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        m.saldo == 0
                            ? '±0'
                            : '${m.saldo > 0 ? '+' : ''}${m.saldo}',
                        style: TextStyle(
                          fontFamily: PulsoFonts.display,
                          fontSize: 26,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: tokens.chalk,
                        ),
                      ),
                      Text(
                        '${m.entran} entran · ${m.salen} salen',
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 9,
                          color: tokens.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// La frase se calcula del dato, no se escribe a mano: si el dato cambia de
  /// signo, la lectura cambia con él.
  String _lectura(PlanMobility m, String plan) {
    if (m.saldo > 0) {
      final origen = m.vienenDe.isEmpty ? null : m.vienenDe.first;
      return '$plan capta socios de otros planes. '
          '${origen == null ? '' : 'La mayoría llega desde ${origen.etiqueta} '
                    '(${origen.total}). '}'
          'Un saldo positivo sostenido señala el plan al que la gente sube.';
    }
    if (m.saldo < 0) {
      final destino = m.seVanA.isEmpty ? null : m.seVanA.first;
      return '$plan es puerta de entrada: pierde más socios de los que capta. '
          '${destino == null ? '' : 'La mayoría se va a ${destino.etiqueta} '
                    '(${destino.total}). '}'
          'No es necesariamente malo: un plan barato que empuja hacia arriba '
          'está haciendo su trabajo.';
    }
    return 'Entran tantos socios como salen. $plan ni capta ni alimenta: '
        'se sostiene con los suyos.';
  }
}

class _PanelContratacion extends StatelessWidget {
  const _PanelContratacion({required this.datos});

  final PlanStatistics datos;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final c = datos.contratacion;
    return PulsoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StatsPanelTitle('¿Lo contratan, y lo renuevan?'),
          const SizedBox(height: 12),
          PulsoLinea(
            puntos: [
              for (final mes in c.porMes)
                PulsoChartDato(
                  etiqueta: mesCorto(mes.etiqueta),
                  valor: mes.total.toDouble(),
                ),
            ],
            mensajeVacio: 'Todavía no se ha contratado ninguna vez.',
          ),
          const SizedBox(height: 16),
          const StatsSubLabel('Estado de los contratos'),
          const SizedBox(height: 8),
          PulsoBarras(
            anchoEtiqueta: 92,
            datos: [
              PulsoChartDato(
                etiqueta: 'Vigentes',
                valor: c.vigentes.toDouble(),
              ),
              PulsoChartDato(
                etiqueta: 'Pend. de pago',
                valor: c.pendientes.toDouble(),
              ),
              PulsoChartDato(
                etiqueta: 'Pausadas',
                valor: c.pausadas.toDouble(),
              ),
              PulsoChartDato(
                etiqueta: 'Terminadas',
                valor: c.terminadas.toDouble(),
              ),
            ],
            mensajeVacio: 'Sin contratos registrados.',
          ),
          const SizedBox(height: 14),
          StatsRate(
            tasa: c.tasaRenovacion,
            titulo: 'renovación',
            tokens: tokens,
          ),
          const SizedBox(height: 8),
          Text(
            'El estado guardado nunca dice «vencida»: registra el acto, no la '
            'cobertura. Lo vigente se deriva comparando la fecha de fin con el '
            'día de negocio de la sede.',
            style: TextStyle(fontSize: 10, height: 1.4, color: tokens.muted),
          ),
        ],
      ),
    );
  }
}

class _PanelComposicion extends StatelessWidget {
  const _PanelComposicion({required this.datos});

  final PlanStatistics datos;

  @override
  Widget build(BuildContext context) {
    final c = datos.composicion;
    return PulsoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StatsPanelTitle('¿Quién lo contrata?'),
          const SizedBox(height: 12),
          const StatsSubLabel('Sexo'),
          const SizedBox(height: 8),
          PulsoDona(
            datos: datosDona(c.porSexo),
            diametro: 108,
            grosor: 15,
            centroValor: '${datos.contratacion.vigentes}',
            centroTitulo: 'vigentes',
            mensajeVacio: 'Sin contratos vigentes.',
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
          const SizedBox(height: 14),
          const StatsSubLabel('Entrenador'),
          const SizedBox(height: 8),
          PulsoBarras(
            anchoEtiqueta: 112,
            datos: datosBarra(c.porEntrenador),
            mensajeVacio: 'Sin entrenador asignado.',
          ),
        ],
      ),
    );
  }
}

class _PanelDinero extends StatelessWidget {
  const _PanelDinero({required this.datos, required this.monedas});

  final PlanStatistics datos;
  final List<CurrencyModel> monedas;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StatsPanelTitle('¿Cuánto deja, y en qué moneda?'),
          const SizedBox(height: 12),
          if (datos.dinero.isEmpty)
            const PulsoChartVacio(
              mensaje: 'Este plan todavía no ha generado ningún cobro.',
              alto: 70,
            )
          else
            // Una tarjeta por divisa. Jamás un total combinado: sumar CUP con
            // EUR daría una cifra que no significa nada.
            Column(
              children: [
                for (final moneda in datos.dinero)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _TarjetaMoneda(
                      dinero: moneda,
                      nombre: nombreMoneda(monedas, moneda.monedaId),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          const StatsSubLabel('Reparto del pago'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              StatsFact(
                'Membresías fraccionadas',
                '${datos.membresiasFraccionadas}',
              ),
              StatsFact('Cuotas emitidas', '${datos.cuotasEmitidas}'),
              StatsFact('Acepta cuotas', datos.plan.aceptaCuotas ? 'sí' : 'no'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Los importes no se suman entre divisas: cada moneda lleva su '
            'propio total, su ticket y sus descuentos.',
            style: TextStyle(fontSize: 10, height: 1.4, color: tokens.muted),
          ),
        ],
      ),
    );
  }
}

class _TarjetaMoneda extends StatelessWidget {
  const _TarjetaMoneda({required this.dinero, required this.nombre});

  final PlanMoney dinero;
  final String nombre;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(border: Border.all(color: tokens.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dinero.total.toStringAsFixed(2),
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
                    '${dinero.cobros} cobro(s)',
                    style: TextStyle(fontSize: 11, color: tokens.chalk),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'ticket ${dinero.ticketMedio.toStringAsFixed(2)}',
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
          if (dinero.descuentoTotal > 0 || dinero.recargoTotal > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                if (dinero.descuentoTotal > 0)
                  StatsFact(
                    'Descuento concedido',
                    dinero.descuentoTotal.toStringAsFixed(2),
                  ),
                if (dinero.recargoTotal > 0)
                  StatsFact(
                    'Recargo de mora',
                    dinero.recargoTotal.toStringAsFixed(2),
                    alerta: true,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PanelUso extends StatelessWidget {
  const _PanelUso({required this.datos});

  final PlanStatistics datos;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final d = datos.duracion;
    return PulsoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StatsPanelTitle('¿Se usa, o solo se paga?'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      datos.uso.visitasPorSocio == null
                          ? '—'
                          : '${datos.uso.visitasPorSocio}',
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
                      datos.uso.sociosConCobertura == 0
                          ? 'visitas por socio · sin socios con cobertura'
                          : 'visitas por socio · ${datos.uso.visitas} visitas '
                                'entre ${datos.uso.sociosConCobertura}',
                      style: TextStyle(fontSize: 11, color: tokens.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const StatsSubLabel('Cobertura real frente a la contratada'),
          const SizedBox(height: 8),
          PulsoBarras(
            anchoEtiqueta: 96,
            resaltarPrimero: false,
            datos: [
              PulsoChartDato(
                etiqueta: 'Contratada',
                valor: d.contratadaDias.toDouble(),
              ),
              if (d.realMediaDias != null)
                PulsoChartDato(etiqueta: 'Real media', valor: d.realMediaDias!),
            ],
            mensajeVacio: 'Sin contratos de los que medir la duración.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              StatsFact('Duración del plan', '${d.contratadaDias} días'),
              StatsFact(
                'Duración real media',
                d.realMediaDias == null ? '—' : '${d.realMediaDias} días',
              ),
              StatsFact(
                'Desviación',
                d.desviacionDias == null
                    ? '—'
                    : '${d.desviacionDias! > 0 ? '+' : ''}${d.desviacionDias} días',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'La cobertura real se estira con las pausas: por eso puede superar '
            'los días contratados sin que nadie haya regalado nada.',
            style: TextStyle(fontSize: 10, height: 1.4, color: tokens.muted),
          ),
        ],
      ),
    );
  }
}
