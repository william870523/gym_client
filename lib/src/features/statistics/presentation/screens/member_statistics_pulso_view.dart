import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_charts.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../clients/data/models/client_model.dart';
import '../../../clients/presentation/state/client_notifier.dart';
import '../../../dashboard/presentation/state/dashboard_nav_provider.dart';
import '../../data/models/member_statistics.dart';
import '../state/statistics_providers.dart';
import 'statistics_shared.dart';

/// Perfil estadístico del socio (docs/PLAN_ESTADISTICAS.md §3).
///
/// Cada panel responde **una** pregunta: ¿viene?, ¿cuánto deja?, ¿renueva?,
/// ¿cambia su cuerpo? Nada se dibuja porque quede bonito; si un dato no ayuda a
/// decidir, no está.
class MemberStatisticsPulsoView extends ConsumerStatefulWidget {
  const MemberStatisticsPulsoView({super.key, this.showSelector = true});

  final bool showSelector;

  @override
  ConsumerState<MemberStatisticsPulsoView> createState() =>
      _MemberStatisticsPulsoViewState();
}

class _MemberStatisticsPulsoViewState
    extends ConsumerState<MemberStatisticsPulsoView> {
  final _buscador = TextEditingController();
  String _consulta = '';

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PulsoThemeScope(
      child: Builder(
        builder: (context) => ColoredBox(
          color: PulsoTokens.of(context).floor,
          child: LayoutBuilder(
            builder: (context, restricciones) {
              final compacto = restricciones.maxWidth < 900;
              final relleno = compacto ? 16.0 : 28.0;
              return SingleChildScrollView(
                padding: EdgeInsets.all(relleno),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Encabezado(),
                    const SizedBox(height: 14),
                    if (widget.showSelector) ...[
                      _selector(context, compacto),
                      const SizedBox(height: 14),
                    ] else ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PulsoSecondaryButton(
                          label: 'Volver a Clientes',
                          icon: Icons.arrow_back,
                          onPressed: () => ref
                              .read(dashboardNavProvider.notifier)
                              .setIndex(1),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _cuerpo(context, compacto),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _selector(BuildContext context, bool compacto) {
    final tokens = PulsoTokens.of(context);
    final socios =
        ref.watch(clientNotifierProvider).value ?? const <ClientModel>[];
    final consulta = _consulta.trim().toLowerCase();
    final coincidencias = consulta.isEmpty
        ? const <ClientModel>[]
        : socios
              .where(
                (c) =>
                    '${c.nombres ?? ''} ${c.apellidos ?? ''}'
                        .toLowerCase()
                        .contains(consulta) ||
                    c.id.toLowerCase().contains(consulta),
              )
              .take(8)
              .toList();

    return PulsoPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('estadistica-buscar-socio'),
            controller: _buscador,
            onChanged: (valor) => setState(() => _consulta = valor),
            style: TextStyle(fontSize: 13, color: tokens.chalk),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Buscar socio por nombre o carné',
              hintStyle: TextStyle(fontSize: 12, color: tokens.muted),
              prefixIcon: Icon(Icons.search, size: 16, color: tokens.muted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: tokens.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: tokens.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: tokens.accent),
              ),
            ),
          ),
          if (coincidencias.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final socio in coincidencias)
                  _Ficha(
                    texto: '${socio.nombres ?? ''} ${socio.apellidos ?? ''}',
                    nota: socio.id,
                    onTap: () {
                      ref
                          .read(selectedMemberProvider.notifier)
                          .select(socio.id);
                      setState(() {
                        _consulta = '';
                        _buscador.clear();
                      });
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _cuerpo(BuildContext context, bool compacto) {
    final ci = ref.watch(selectedMemberProvider);
    if (ci == null) {
      return const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.empty,
          message:
              'Busca un socio arriba para ver su perfil: constancia, dinero, '
              'contrato y evolución del cuerpo.',
        ),
      );
    }

    final perfil = ref.watch(memberStatisticsProvider(ci));
    return perfil.when(
      loading: () => const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.loading,
          message: 'Calculando el perfil del socio…',
        ),
      ),
      error: (error, _) => PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.error,
          message:
              'No se pudo calcular la estadística.\n'
              '${statisticsErrorMessage(error)}',
          onRetry: () => ref.invalidate(memberStatisticsProvider(ci)),
        ),
      ),
      data: (datos) => _Perfil(datos: datos, compacto: compacto),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PulsoLabel('Estadística · socio'),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            text: 'PERFIL DEL\nSOCIO',
            style: TextStyle(
              fontFamily: PulsoFonts.display,
              fontSize: 36,
              height: 0.95,
              fontWeight: FontWeight.w700,
              color: tokens.chalk,
            ),
            children: [
              TextSpan(
                text: '.',
                style: TextStyle(color: tokens.accent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 520,
          child: Text(
            'Qué hace este socio de verdad: si viene y cuándo, cuánto deja y en '
            'qué moneda, si renueva y cómo cambia su cuerpo.',
            style: TextStyle(fontSize: 12, height: 1.5, color: tokens.muted),
          ),
        ),
      ],
    );
  }
}

class _Perfil extends StatelessWidget {
  const _Perfil({required this.datos, required this.compacto});

  final MemberStatistics datos;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final constancia = datos.constancia;
    final socio = datos.socio;

    final paneles = <Widget>[
      _PanelConstancia(datos: datos),
      _PanelDinero(datos: datos),
      _PanelContrato(datos: datos),
      _PanelCuerpo(datos: datos),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PulsoMetricStrip(
          metrics: [
            PulsoMetricData(
              value: '${constancia.visitas}',
              label: 'Visitas',
              note: constancia.diasDesdeUltima == null
                  ? 'todavía no ha venido'
                  : constancia.diasDesdeUltima == 0
                  ? 'vino hoy'
                  : 'hace ${constancia.diasDesdeUltima} día(s)',
              emphasis: true,
            ),
            PulsoMetricData(
              value: constancia.aprovechamiento.etiqueta,
              label: 'Aprovechamiento',
              note: 'de ${constancia.aprovechamiento.base} días cubiertos',
              warning: (constancia.aprovechamiento.porcentaje ?? 100) < 30,
            ),
            PulsoMetricData(
              value: datos.dinero.mora.puntualidad.etiqueta,
              label: 'Puntualidad',
              note:
                  'cobros sin recargo · ${datos.dinero.mora.puntualidad.detalle}',
              warning: (datos.dinero.mora.puntualidad.porcentaje ?? 100) < 70,
            ),
            PulsoMetricData(
              value: socio.antiguedadDias == null
                  ? '—'
                  : '${socio.antiguedadDias}',
              label: 'Antigüedad',
              note: socio.edad == null ? 'días' : 'días · ${socio.edad} años',
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
        Text(
          'Días y horas agrupados en ${datos.zona} · día de negocio '
          '${datos.diaNegocio}',
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: 10,
            color: tokens.muted,
          ),
        ),
      ],
    );
  }
}

class _PanelConstancia extends StatelessWidget {
  const _PanelConstancia({required this.datos});

  final MemberStatistics datos;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final c = datos.constancia;
    return PulsoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TituloPanel('¿Viene, y cuándo?'),
          const SizedBox(height: 12),
          PulsoLinea(
            puntos: [
              for (final mes in c.visitasPorMes)
                PulsoChartDato(
                  etiqueta: _mesCorto(mes.etiqueta),
                  valor: mes.total.toDouble(),
                ),
            ],
            mensajeVacio: 'Todavía no ha registrado ninguna entrada.',
          ),
          const SizedBox(height: 16),
          _Rotulo('Franja habitual'),
          const SizedBox(height: 8),
          PulsoDona(
            datos: [
              for (final f in c.porFranja)
                PulsoChartDato(etiqueta: f.etiqueta, valor: f.total.toDouble()),
            ],
            centroValor: '${c.visitas}',
            centroTitulo: 'visitas',
            mensajeVacio: 'Sin entradas registradas.',
          ),
          const SizedBox(height: 16),
          _Rotulo('Día de la semana'),
          const SizedBox(height: 8),
          PulsoBarras(
            anchoEtiqueta: 76,
            resaltarPrimero: false,
            datos: [
              for (final d in c.porDiaSemana)
                PulsoChartDato(etiqueta: d.etiqueta, valor: d.total.toDouble()),
            ],
            mensajeVacio: 'Sin entradas registradas.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Dato('Racha actual', '${c.rachaActual} día(s)'),
              _Dato('Racha máxima', '${c.rachaMaxima} día(s)'),
              _Dato(
                'Permanencia media',
                c.permanenciaMediaMin == null
                    ? '—'
                    : '${c.permanenciaMediaMin} min',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'El aprovechamiento compara los días que vino con los días que su '
            'membresía cubría, descontando las pausas.',
            style: TextStyle(fontSize: 10, height: 1.4, color: tokens.muted),
          ),
        ],
      ),
    );
  }
}

class _PanelDinero extends StatelessWidget {
  const _PanelDinero({required this.datos});

  final MemberStatistics datos;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final d = datos.dinero;
    return PulsoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TituloPanel('¿Cuánto deja, y en qué moneda?'),
          const SizedBox(height: 12),
          if (d.porMoneda.isEmpty)
            const PulsoChartVacio(
              mensaje: 'Todavía no ha hecho ningún cobro.',
              alto: 70,
            )
          else
            // Una tarjeta por divisa. Nunca un total combinado: sumar CUP con
            // EUR daría una cifra que no significa nada.
            Column(
              children: [
                for (final moneda in d.porMoneda)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _TarjetaMoneda(moneda: moneda),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          _Rotulo('Medio de pago'),
          const SizedBox(height: 8),
          PulsoBarras(
            anchoEtiqueta: 96,
            datos: [
              for (final m in d.porMedio)
                PulsoChartDato(etiqueta: m.etiqueta, valor: m.total.toDouble()),
            ],
            mensajeVacio: 'Sin medios de pago registrados.',
          ),
          const SizedBox(height: 14),
          _Rotulo('Puntualidad'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Dato(
                'Cobros con recargo',
                '${d.mora.cobrosConRecargo}',
                alerta: d.mora.cobrosConRecargo > 0,
              ),
              _Dato(
                'Atraso medio',
                d.mora.diasAtrasoPromedio == null
                    ? '—'
                    : '${d.mora.diasAtrasoPromedio!.toStringAsFixed(1)} días',
              ),
              _Dato('Recargo pagado', d.mora.recargoTotal.toStringAsFixed(2)),
              if (d.mora.condonadoTotal > 0)
                _Dato(
                  'Recargo perdonado',
                  d.mora.condonadoTotal.toStringAsFixed(2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Los importes no se suman entre divisas: cada moneda lleva su '
            'propio total y su propio ticket.',
            style: TextStyle(fontSize: 10, height: 1.4, color: tokens.muted),
          ),
        ],
      ),
    );
  }
}

class _TarjetaMoneda extends StatelessWidget {
  const _TarjetaMoneda({required this.moneda});

  final MemberMoneyByCurrency moneda;

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
                  moneda.total.toStringAsFixed(2),
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
                  // El identificador de moneda se muestra recortado: el nombre
                  // legible vive en el catálogo y aquí no se ha cargado.
                  'moneda ${moneda.monedaId.substring(0, moneda.monedaId.length.clamp(0, 8))}',
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
                '${moneda.cobros} cobro(s)',
                style: TextStyle(fontSize: 11, color: tokens.chalk),
              ),
              const SizedBox(height: 3),
              Text(
                'ticket ${moneda.ticketMedio.toStringAsFixed(2)}',
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

class _PanelContrato extends StatelessWidget {
  const _PanelContrato({required this.datos});

  final MemberStatistics datos;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final c = datos.contrato;
    return PulsoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TituloPanel('¿Renueva, o se está yendo?'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.tasaRenovacion.etiqueta,
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
                      'renovación · ${c.tasaRenovacion.detalle}',
                      style: TextStyle(fontSize: 11, color: tokens.muted),
                    ),
                    if (c.tasaRenovacion.muestraBaja) ...[
                      const SizedBox(height: 4),
                      Text(
                        'muestra baja',
                        style: TextStyle(
                          fontFamily: PulsoFonts.display,
                          fontSize: 10,
                          letterSpacing: 0.6,
                          color: tokens.warning,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    _Dato('Altas', '${c.altas}'),
                    _Dato('Renovaciones', '${c.renovaciones}'),
                    _Dato('Cambios de plan', '${c.cambiosDePlan}'),
                    if (c.reactivaciones > 0)
                      _Dato('Reactivaciones', '${c.reactivaciones}'),
                    if (c.diasPausados > 0)
                      _Dato('Días en pausa', '${c.diasPausados}'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Rotulo('Planes por los que ha pasado'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final plan in c.planesRecorridos)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: tokens.line),
                  ),
                  child: Text(
                    plan,
                    style: TextStyle(fontSize: 11, color: tokens.chalk),
                  ),
                ),
              if (c.planesRecorridos.isEmpty)
                Text(
                  'Sin contratos registrados.',
                  style: TextStyle(fontSize: 11, color: tokens.muted),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _Rotulo('Línea de contratos'),
          const SizedBox(height: 6),
          // Solo los últimos: la lista completa es el expediente, no esto.
          for (final m in c.membresias.reversed.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    color: _colorOrigen(m.origen, tokens),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      m.plan,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: tokens.chalk),
                    ),
                  ),
                  Text(
                    '${m.desde} → ${m.hasta}',
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 9,
                      color: tokens.muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _colorOrigen(String origen, PulsoTokens tokens) => switch (origen) {
    'ALTA' => tokens.accent,
    'RENOVACION' => tokens.success,
    'CAMBIO' => tokens.warning,
    _ => tokens.muted,
  };
}

class _PanelCuerpo extends StatelessWidget {
  const _PanelCuerpo({required this.datos});

  final MemberStatistics datos;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final c = datos.cuerpo;
    return PulsoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TituloPanel('¿Está cambiando su cuerpo?'),
          const SizedBox(height: 12),
          PulsoLinea(
            puntos: [
              for (final p in c.serie)
                PulsoChartDato(etiqueta: _diaCorto(p.fecha), valor: p.peso),
            ],
            mensajeVacio: 'Sin pesajes registrados todavía.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Dato(
                'Peso inicial',
                c.pesoInicial == null ? '—' : '${c.pesoInicial} kg',
              ),
              _Dato(
                'Peso actual',
                c.pesoActual == null ? '—' : '${c.pesoActual} kg',
              ),
              _Dato(
                'Variación',
                c.delta == null
                    ? '—'
                    : '${c.delta! > 0 ? '+' : ''}${c.delta} kg',
              ),
              _Dato('IMC', c.imc == null ? '—' : '${c.imc}'),
            ],
          ),
          if (datos.socio.objetivo != null) ...[
            const SizedBox(height: 10),
            Text(
              'Objetivo declarado: ${datos.socio.objetivo}',
              style: TextStyle(fontSize: 11, color: tokens.muted),
            ),
          ],
          if (c.imc == null && c.pesoActual != null) ...[
            const SizedBox(height: 8),
            Text(
              'Sin estatura registrada no se puede calcular el IMC.',
              style: TextStyle(fontSize: 10, color: tokens.muted),
            ),
          ],
        ],
      ),
    );
  }
}

// --- Piezas menudas ----------------------------------------------------------

class _TituloPanel extends StatelessWidget {
  const _TituloPanel(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Text(
      texto,
      style: TextStyle(
        fontFamily: PulsoFonts.display,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: tokens.chalk,
      ),
    );
  }
}

class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return PulsoLabel(texto);
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor, {this.alerta = false});

  final String etiqueta;
  final String valor;
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          valor,
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: alerta ? tokens.warning : tokens.chalk,
          ),
        ),
        Text(etiqueta, style: TextStyle(fontSize: 10, color: tokens.muted)),
      ],
    );
  }
}

class _Ficha extends StatelessWidget {
  const _Ficha({required this.texto, required this.nota, required this.onTap});

  final String texto;
  final String nota;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: tokens.line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              texto.trim(),
              style: TextStyle(fontSize: 12, color: tokens.chalk),
            ),
            Text(
              nota,
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontSize: 9,
                color: tokens.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `2026-07` → `jul`. El año se sobreentiende en una serie continua.
String _mesCorto(String mes) {
  const nombres = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final partes = mes.split('-');
  if (partes.length < 2) return mes;
  final indice = int.tryParse(partes[1]);
  if (indice == null || indice < 1 || indice > 12) return mes;
  return nombres[indice - 1];
}

/// `2026-07-15` → `15/07`.
String _diaCorto(String dia) {
  final partes = dia.split('-');
  if (partes.length < 3) return dia;
  return '${partes[2]}/${partes[1]}';
}
