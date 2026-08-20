import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/time/app_clock.dart';
import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../auth/presentation/state/sede_session_provider.dart';
import '../../data/models/cierre_cadena_models.dart';
import '../../data/repositories/cierre_cadena_repository.dart';
import '../state/cierre_cadena_providers.dart';

/// Cuánto hace que se supo de una sede.
///
/// La tabla ya daba **la fecha**; lo que no daba es esto, y es lo que decide qué
/// hacer: una sede callada veinticinco horas es un incidente de esta mañana; una
/// callada tres semanas es una sede que nadie ha ido a mirar. Restarlo a ojo
/// contra el reloj de cada uno es justo el trabajo que la pantalla puede
/// ahorrar. Ocupa el sitio de la etiqueta «última sync», que repetía el
/// encabezado de la columna.
///
/// `null` es **no consta**, y se dice con esas palabras: una sede recién dada de
/// alta, o cuyo escritorio nunca arrancó, no ha callado —es que nunca habló—, y
/// pintarlo como un silencio largo mandaría a alguien a revisar una conexión que
/// no existe.
String haceCuanto(DateTime? ultimaNoticia, DateTime ahora) {
  if (ultimaNoticia == null) return 'sin noticia registrada';
  final transcurrido = ahora.difference(ultimaNoticia.toUtc());
  // Un reloj que va por detrás daría «hace -2 h». Se corta en cero: lo que se
  // sabe es que se supo de ella, no cuánto hace exactamente.
  final cuanto = transcurrido.isNegative ? Duration.zero : transcurrido;
  if (cuanto.inDays >= 1) return 'hace ${cuanto.inDays} d';
  if (cuanto.inHours >= 1) return 'hace ${cuanto.inHours} h';
  return 'hace ${cuanto.inMinutes} min';
}

/// El silencio más largo de la cadena, para poner cifra a «sin noticias».
///
/// Se busca entre las que están **calladas**, no entre todas: la más antigua de
/// las que hablan hoy no es un problema de nadie.
Duration? silencioMasLargo(SemaforoCadenaModel datos, DateTime ahora) {
  Duration? peor;
  for (final fila in datos.filas) {
    if (fila.estado != EstadoSemaforo.sinNoticias) continue;
    // Una sede de la que no consta nada es el peor caso y no tiene duración;
    // se representa aparte, con `null`, y por eso aquí se salta.
    final noticia = fila.ultimaNoticia;
    if (noticia == null) continue;
    final d = ahora.difference(noticia.toUtc());
    if (peor == null || d > peor) peor = d;
  }
  return peor;
}

/// Alto de los estados de carga, error y «solo en el concentrador». Lo manda
/// `PulsoStateView` con su botón de reintento: 28 de padding arriba y abajo, 30
/// de icono, el mensaje —que puede ir a dos líneas— y 44 de botón.
const double _altoEstado = 214;

/// M5 — el semáforo de cierre de la cadena (docs/MULTI_SEDE.md §6.2).
///
/// Contabilidad central **pide** y cada sede **cierra**, porque el dinero
/// físico está en la sede. Esto es lo que el Dueño mira para saber si puede
/// consolidar, y vive en la pantalla de Sedes por el mismo motivo que la tarifa
/// del plus: es la pantalla donde se mira la red entera.
///
/// ## Cuatro estados, y dos de ellos parecen el mismo
///
/// `SIN_CERRAR` y `SIN_NOTICIAS` no son matices del mismo problema: a una sede
/// se le reclama el cierre y a la otra se le mira la conexión, porque puede
/// haber cerrado sin que aquí conste. Tratarlas igual hace que se firme el
/// consolidado creyendo que una sede no cerró cuando lo que pasa es que nadie
/// ha hablado con ella. Por eso cada fila lleva, además del estado, **qué hacer
/// con ella**.
///
/// ## Desde el escritorio no se puede, y se dice
///
/// La instalación de una sede solo tiene sus propios cierres, así que contesta
/// 409 explicándolo. Aquí eso se enseña como una nota, no como un error: un
/// «sin datos» en esta tabla se leería como «ninguna sede ha cerrado», que es
/// justo la conclusión equivocada.
class SemaforoCierrePanel extends ConsumerStatefulWidget {
  const SemaforoCierrePanel({
    super.key,
    this.abierto = true,
    this.onAbrir,
    this.periodoFijado,
    this.onPeriodo,
  });

  /// Período impuesto desde fuera.
  ///
  /// En la vista de cierre de la cadena el período se elige **una vez** y manda
  /// sobre el semáforo, el informe, el certificado y el detalle: cada panel con
  /// su propio selector es como se acaba mirando agosto en uno y julio en otro.
  /// Sin esto, el panel conserva el suyo.
  final PeriodoSemaforo? periodoFijado;

  /// Avisa al contenedor de que el período cambió desde aquí —«Ver lo pedido»—
  /// para que los demás paneles lo sigan.
  final void Function(PeriodoSemaforo)? onPeriodo;

  /// Plegado, ocupa solo su cabecera.
  ///
  /// Lo pide la pantalla que lo aloja: la de Sedes reparte su alto entre el
  /// catálogo y lo demás, y un panel de 400 px siempre desplegado le quitaría a
  /// la lista de sedes el sitio que necesita. Quien lo abre es quien viene a
  /// mirar el cierre, y entonces la página pasa a desplazarse.
  final bool abierto;
  final VoidCallback? onAbrir;

  @override
  ConsumerState<SemaforoCierrePanel> createState() =>
      _SemaforoCierrePanelState();
}

class _SemaforoCierrePanelState extends ConsumerState<SemaforoCierrePanel> {
  late PeriodoSemaforo _periodo;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Arranca en el mes anterior: es el que se cierra. El mes en curso todavía
    // está abierto y pedir su cierre sería pedir que se firme dinero que aún
    // está entrando.
    _periodo = widget.periodoFijado ??
        PeriodoSemaforo.mesDe(DateTime(DateTime.now().year, DateTime.now().month - 1));
  }

  @override
  void didUpdateWidget(SemaforoCierrePanel anterior) {
    super.didUpdateWidget(anterior);
    final fijado = widget.periodoFijado;
    if (fijado != null && fijado != _periodo) setState(() => _periodo = fijado);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Los meses van escritos y no con `DateFormat(..., 'es')`: ese constructor
  /// exige `initializeDateFormatting('es')`, que esta aplicación **no llama en
  /// ninguna parte**. Con el locale sin cargar lanza `LocaleDataException` al
  /// construir, así que el panel no habría llegado a pintarse tampoco en la
  /// aplicación real.
  static const _meses = [
    'ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO',
    'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE',
  ];
  static String _etiquetaMes(DateTime fecha) =>
      '${_meses[fecha.month - 1]} ${fecha.year}';

  /// Un período pedido no tiene por qué ser un mes: la solicitud puede pedir
  /// una semana o un rango suelto, y enseñar «AGOSTO 2026» sobre un rango del
  /// 1 al 4 sería decir que se está mirando otra cosa.
  String _etiquetaPeriodo() => _periodo.esMesNatural
      ? _etiquetaMes(_periodo.desde)
      : '${_dia.format(_periodo.desde)} → ${_dia.format(_periodo.ultimoDiaIncluido)}';
  static final _dia = DateFormat('yyyy-MM-dd');

  SolicitudCierreModel? _solicitudDelPeriodo() {
    final lista = ref.watch(solicitudesCierreProvider).asData?.value;
    if (lista == null) return null;
    for (final solicitud in lista) {
      if (solicitud.fechaInicio.year == _periodo.desde.year &&
          solicitud.fechaInicio.month == _periodo.desde.month &&
          solicitud.fechaInicio.day == _periodo.desde.day &&
          solicitud.fechaFinExclusiva.year == _periodo.hastaExclusivo.year &&
          solicitud.fechaFinExclusiva.month == _periodo.hastaExclusivo.month &&
          solicitud.fechaFinExclusiva.day == _periodo.hastaExclusivo.day) {
        return solicitud;
      }
    }
    return null;
  }

  void _mover(PeriodoSemaforo destino) {
    setState(() => _periodo = destino);
    widget.onPeriodo?.call(destino);
  }

  /// La primera solicitud viva cuyo período no es el que se está mirando.
  ///
  /// Es el caso de uso central del semáforo —«pedí esto, ¿cómo va?»— y sin esto
  /// no había manera de llegar a él: las flechas solo caminan meses naturales y
  /// una solicitud puede pedir una semana o un rango suelto.
  SolicitudCierreModel? _pedidoFueraDeVista() {
    if (_solicitudDelPeriodo() != null) return null;
    final lista = ref.watch(solicitudesCierreProvider).asData?.value;
    return (lista == null || lista.isEmpty) ? null : lista.first;
  }

  void _recargar() {
    ref.invalidate(semaforoCadenaProvider(_periodo));
    ref.invalidate(solicitudesCierreProvider);
  }

  Future<void> _pedirCierre() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => _PedirCierreDialog(periodo: _periodo),
    );
    if (confirmado == true) _recargar();
  }

  Future<void> _retirar(SolicitudCierreModel solicitud) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => _RetirarSolicitudDialog(solicitud: solicitud),
    );
    if (confirmado == true) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final sesion = ref.watch(sedeSessionProvider);
    // El semáforo enseña **todas** las sedes: es autoridad de cadena, y el
    // servidor lo rechaza con 403 a una sesión de sede. Enseñarlo igual sería
    // ofrecer una pantalla que solo puede terminar en un error.
    //
    // La sesión nula es el caso de los tests aislados, que no la montan; en la
    // aplicación siempre está. Mismo criterio que `GlobalCatalogAuthority`.
    if (sesion != null && !sesion.esPlataforma) return const SizedBox.shrink();
    final semaforo = widget.abierto
        ? ref.watch(semaforoCadenaProvider(_periodo))
        : const AsyncValue<SemaforoCadenaModel>.loading();
    final solicitud = _solicitudDelPeriodo();
    final esDueno = sesion?.esPlataforma ?? true;

    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Cabecera(
            periodo: _periodo,
            etiquetaMes: _etiquetaPeriodo(),
            conMando: widget.periodoFijado == null,
            solicitado: solicitud != null,
            pedidoFuera: _pedidoFueraDeVista(),
            onVerPedido: (pedida) => _mover(
              PeriodoSemaforo(
                desde: pedida.fechaInicio,
                hastaExclusivo: pedida.fechaFinExclusiva,
              ),
            ),
            abierto: widget.abierto,
            onAlternar: widget.onAbrir,
            onAnterior: () => _mover(_periodo.mesAnterior),
            onSiguiente: () => _mover(_periodo.mesSiguiente),
            onRecargar: _recargar,
          ),
          if (!widget.abierto)
            const SizedBox.shrink()
          else
            semaforo.when(
            loading: () => const SizedBox(
              height: _altoEstado,
              child: PulsoStateView(
                kind: PulsoStateKind.loading,
                message: 'Leyendo los cierres de cada sede…',
              ),
            ),
            error: (error, _) => SizedBox(
              height: _altoEstado,
              child: error is SemaforoSoloEnElConcentrador
                  ? _SoloEnLaWeb(mensaje: error.mensaje)
                  : PulsoStateView(
                      kind: PulsoStateKind.error,
                      message: error
                          .toString()
                          .replaceFirst('Exception: ', ''),
                      onRetry: _recargar,
                    ),
            ),
            data: (datos) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Contadores(datos: datos),
                _TablaSedes(datos: datos, scroll: _scroll),
                _Pie(
                  datos: datos,
                  solicitud: solicitud,
                  esDueno: esDueno,
                  onPedir: _pedirCierre,
                  onRetirar: _retirar,
                ),
              ],
            ),
          ),
          if (widget.abierto && semaforo.hasValue)
            Container(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: tokens.line)),
                color: tokens.raised,
              ),
              child: Text(
                'El período ${_dia.format(_periodo.desde)} → '
                '${_dia.format(_periodo.ultimoDiaIncluido)} se firma en cada sede'
                '${_periodo.esMesNatural ? ' con su cierre mensual formal' : ''}. '
                'El central no cierra: pide.',
                style: TextStyle(fontSize: 11, color: tokens.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.periodo,
    required this.etiquetaMes,
    required this.conMando,
    required this.solicitado,
    required this.pedidoFuera,
    required this.onVerPedido,
    required this.abierto,
    required this.onAnterior,
    required this.onSiguiente,
    required this.onRecargar,
    this.onAlternar,
  });

  final PeriodoSemaforo periodo;
  final String etiquetaMes;

  /// Si este panel lleva su propio selector de período o lo manda su contenedor.
  final bool conMando;
  final bool solicitado;
  final SolicitudCierreModel? pedidoFuera;
  final void Function(SolicitudCierreModel) onVerPedido;
  final bool abierto;
  final VoidCallback? onAlternar;
  final VoidCallback onAnterior;
  final VoidCallback onSiguiente;
  final VoidCallback onRecargar;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CIERRE DE LA CADENA',
                  style: TextStyle(
                    fontFamily: PulsoFonts.display,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.05,
                    color: tokens.chalk,
                  ),
                ),
                PulsoLabel(
                  solicitado ? 'Pedido · semáforo por sede' : 'Semáforo por sede',
                  color: solicitado ? tokens.warning : tokens.muted2,
                ),
              ],
            ),
          ),
          if (pedidoFuera != null) ...[
            _VerPedido(onTap: () => onVerPedido(pedidoFuera!)),
            const SizedBox(width: 6),
          ],
          // Con el período impuesto desde fuera, este panel **no** repite el
          // selector: dos mandos para lo mismo en la misma pantalla es el tipo
          // de duplicado que hace dudar de cuál manda.
          if (conMando) ...[
            if (onAlternar != null) ...[
              _PasoMes(
                icono: abierto ? Icons.unfold_less : Icons.unfold_more,
                onTap: onAlternar!,
              ),
              const SizedBox(width: 6),
            ],
            _PasoMes(icono: Icons.chevron_left, onTap: onAnterior),
            Container(
              constraints: const BoxConstraints(minWidth: 132),
              height: 32,
              alignment: Alignment.center,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(border: Border.all(color: tokens.line)),
              child: Text(
                etiquetaMes,
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 10,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w500,
                  color: tokens.chalkDim,
                ),
              ),
            ),
            _PasoMes(icono: Icons.chevron_right, onTap: onSiguiente),
            const SizedBox(width: 6),
            PulsoIconButton(
              icon: Icons.refresh,
              tooltip: 'Volver a leer el semáforo',
              onPressed: onRecargar,
            ),
          ],
        ],
      ),
    );
  }
}

/// Text-link a lo pedido: mono en mayúsculas y terminado en flecha, como manda
/// el recetario para los enlaces.
class _VerPedido extends StatelessWidget {
  const _VerPedido({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          'VER LO PEDIDO →',
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.3,
            color: tokens.warning,
          ),
        ),
      ),
    );
  }
}

class _PasoMes extends StatelessWidget {
  const _PasoMes({required this.icono, required this.onTap});

  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 32,
          height: 32,
          decoration: BoxDecoration(border: Border.all(color: tokens.line)),
          child: Icon(icono, size: 15, color: tokens.muted),
        ),
      ),
    );
  }
}

/// Los cuatro estados, en un solo marco con divisores internos.
class _Contadores extends StatelessWidget {
  const _Contadores({required this.datos});

  final SemaforoCadenaModel datos;

  /// La peor de las calladas. Si ninguna tiene fecha, lo que hay que decir no es
  /// un tiempo sino que **no consta**: son sedes de las que no se ha sabido
  /// nunca, no sedes que se hayan callado.
  static String _peorSilencio(SemaforoCadenaModel datos) {
    final peor = silencioMasLargo(datos, appClock.nowUtc());
    if (peor == null) return 'sin noticia registrada';
    return peor.inDays >= 1
        ? 'la más callada: ${peor.inDays} d'
        : 'la más callada: ${peor.inHours} h';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final celdas = <(String, int, Color)>[
      ('Listas', datos.verdes, tokens.success),
      ('Con incidencias', datos.conIncidencias, tokens.warning),
      ('Sin cerrar', datos.sinCerrar, tokens.danger),
      ('Sin noticias', datos.sinNoticias, tokens.muted),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < celdas.length; i++)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
                  decoration: BoxDecoration(
                    border: i == celdas.length - 1
                        ? null
                        : Border(right: BorderSide(color: tokens.line)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${celdas[i].$2}',
                        style: TextStyle(
                          fontFamily: PulsoFonts.display,
                          fontSize: 31,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          letterSpacing: -1,
                          color: celdas[i].$2 == 0 ? tokens.muted2 : celdas[i].$3,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      PulsoLabel(celdas[i].$1, color: tokens.muted2),
                      // «4 sin noticias» no dice si es de esta mañana o de hace
                      // tres semanas, y eso cambia a quién se llama.
                      if (celdas[i].$1 == 'Sin noticias' && celdas[i].$2 > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            _peorSilencio(datos),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: PulsoFonts.mono,
                              fontSize: 8,
                              letterSpacing: 0.6,
                              color: tokens.muted2,
                            ),
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

class _TablaSedes extends StatelessWidget {
  const _TablaSedes({required this.datos, required this.scroll});

  final SemaforoCadenaModel datos;
  final ScrollController scroll;

  static const double _altoFila = 61;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 780;
        // La tabla se desplaza por dentro: la cabecera y el mando de la vista
        // se quedan quietos (recetario §4-bis). Cuatro filas y media dejan claro
        // que hay más abajo sin comerse la pantalla.
        final alto = datos.filas.isEmpty
            ? 132.0
            : (datos.filas.length.clamp(1, 5) * _altoFila) +
                  (datos.filas.length > 5 ? 30 : 0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact)
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: tokens.raised,
                  border: Border(bottom: BorderSide(color: tokens.line)),
                ),
                child: Row(
                  children: const [
                    Expanded(flex: 32, child: _Columna('Sede')),
                    Expanded(flex: 24, child: _Columna('Estado')),
                    Expanded(flex: 20, child: _Columna('Cierre firmado')),
                    Expanded(flex: 24, child: _Columna('Incidencias')),
                    Expanded(flex: 20, child: _Columna('Última noticia')),
                  ],
                ),
              ),
            SizedBox(
              height: alto,
              child: datos.filas.isEmpty
                  ? const PulsoStateView(
                      kind: PulsoStateKind.empty,
                      message: 'No hay sedes activas en la red.',
                    )
                  : Scrollbar(
                      controller: scroll,
                      thumbVisibility: true,
                      child: ListView.separated(
                        controller: scroll,
                        primary: false,
                        padding: EdgeInsets.zero,
                        itemCount: datos.filas.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: tokens.line),
                        itemBuilder: (context, index) => _FilaSede(
                          fila: datos.filas[index],
                          compact: compact,
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _Columna extends StatelessWidget {
  const _Columna(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        texto.toUpperCase(),
        style: TextStyle(
          fontFamily: PulsoFonts.mono,
          fontSize: 8,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w500,
          color: tokens.muted2,
        ),
      ),
    );
  }
}

class _FilaSede extends StatelessWidget {
  const _FilaSede({required this.fila, required this.compact});

  final SemaforoFilaModel fila;
  final bool compact;

  static final _dia = DateFormat('yyyy-MM-dd');
  static final _diaHora = DateFormat('yyyy-MM-dd HH:mm');

  Color _color(PulsoTokens tokens) => switch (fila.estado) {
    EstadoSemaforo.cerradaYSincronizada => tokens.success,
    EstadoSemaforo.conIncidencias => tokens.warning,
    EstadoSemaforo.sinCerrar => tokens.danger,
    EstadoSemaforo.sinNoticias => tokens.muted,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = _color(tokens);

    final sede = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fila.nombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: tokens.chalk),
        ),
        const SizedBox(height: 2),
        Text(
          fila.gymId.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: 8,
            letterSpacing: 0.6,
            color: tokens.muted2,
          ),
        ),
      ],
    );

    final estado = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                fila.estado.rotulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        // El estado sin la acción obliga a recordar qué significa cada uno, y
        // los dos que se parecen —sin cerrar y sin noticias— piden cosas
        // opuestas: reclamar o mirar la conexión.
        Text(
          fila.estado.accion,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: 8,
            letterSpacing: 0.6,
            color: tokens.muted2,
          ),
        ),
        // En compacto desaparecen las tres últimas columnas, y con ellas la de
        // «Última noticia». Sin esto, la ventana estrecha se queda sin lo único
        // que distingue una sede callada esta mañana de una callada hace tres
        // semanas. Aquí no duplica nada: la columna no está.
        if (compact) ...[
          const SizedBox(height: 2),
          Text(
            fila.ultimaNoticia == null
                ? 'sin noticia registrada'
                : '${_diaHora.format(fila.ultimaNoticia!)} · '
                      '${haceCuanto(fila.ultimaNoticia, appClock.nowUtc())}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 8,
              letterSpacing: 0.6,
              color: fila.estado == EstadoSemaforo.sinNoticias
                  ? color
                  : tokens.muted2,
            ),
          ),
        ],
      ],
    );

    final cierre = _Dato(
      valor: fila.cierre?.cerradoAt == null
          ? '—'
          : _dia.format(fila.cierre!.cerradoAt!),
      nota: fila.cierre == null
          ? 'no consta'
          : '${fila.cierre!.origen.toLowerCase()} · ${fila.cierre!.estado.toLowerCase()}',
    );

    final incidencias = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fila.descuadres.isEmpty && fila.movimientosPendientes == 0)
          Text('—', style: TextStyle(fontFamily: PulsoFonts.mono, fontSize: 13, color: tokens.muted2))
        else ...[
          if (fila.descuadres.isNotEmpty)
            Text(
              fila.descuadres
                  .map((d) => '${d.monedaId} ${d.importe}')
                  .join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: tokens.warning,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          if (fila.movimientosPendientes > 0)
            Text(
              '${fila.movimientosPendientes} MOV. SIN CONCILIAR',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontSize: 8,
                letterSpacing: 0.6,
                color: tokens.muted2,
              ),
            ),
        ],
      ],
    );

    // La columna daba la fecha y, debajo, la etiqueta «última sync», que no
    // añade nada: ya lo dice el encabezado. Lo que faltaba es **cuánto hace**,
    // que es lo que decide qué hacer —una sede callada veinticinco horas es un
    // incidente de esta mañana; una callada tres semanas es una sede que nadie
    // ha ido a mirar— y obligaba a restar mentalmente contra el reloj de cada
    // uno.
    final noticia = _Dato(
      valor: fila.ultimaNoticia == null
          ? 'nunca'
          : _diaHora.format(fila.ultimaNoticia!),
      nota: haceCuanto(fila.ultimaNoticia, appClock.nowUtc()),
    );

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        height: _TablaSedes._altoFila,
        child: Row(
          children: [
            Expanded(flex: 52, child: sede),
            Expanded(flex: 48, child: estado),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      height: _TablaSedes._altoFila,
      child: Row(
        children: [
          Expanded(flex: 32, child: sede),
          Expanded(flex: 24, child: estado),
          Expanded(flex: 20, child: cierre),
          Expanded(flex: 24, child: incidencias),
          Expanded(flex: 20, child: noticia),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.valor, required this.nota});

  final String valor;
  final String nota;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          valor,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: valor == '—' || valor == 'nunca'
                ? tokens.muted2
                : tokens.chalk,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          nota.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: 8,
            letterSpacing: 0.6,
            color: tokens.muted2,
          ),
        ),
      ],
    );
  }
}

/// El consolidado: se puede firmar o se nombran las que faltan.
class _Pie extends StatelessWidget {
  const _Pie({
    required this.datos,
    required this.solicitud,
    required this.esDueno,
    required this.onPedir,
    required this.onRetirar,
  });

  final SemaforoCadenaModel datos;
  final SolicitudCierreModel? solicitud;
  final bool esDueno;
  final VoidCallback onPedir;
  final void Function(SolicitudCierreModel) onRetirar;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final puede = datos.puedeFirmarse;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          final texto = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 19,
                    height: 2,
                    color: puede ? tokens.success : tokens.warning,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: PulsoLabel(
                      puede
                          ? 'Todas en verde: el consolidado se puede firmar'
                          : 'Consolidado incompleto',
                      color: puede ? tokens.success : tokens.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              // §6.2: nunca un total silencioso e incompleto. Para declarar un
              // cierre parcial hay que poder nombrar a quién falta, así que las
              // ausentes salen con su nombre y no como una cuenta.
              Text(
                puede
                    ? 'Ninguna sede queda fuera del período.'
                    : 'Quedarían fuera: '
                          '${datos.ausentes.map((a) => a.nombre).join(', ')}.',
                style: TextStyle(fontSize: 12, color: tokens.chalkDim),
              ),
            ],
          );

          final acciones = esDueno
              ? (solicitud == null
                    ? PulsoSecondaryButton(
                        label: 'Pedir el cierre',
                        icon: Icons.campaign_outlined,
                        onPressed: onPedir,
                      )
                    : PulsoSecondaryButton(
                        label: 'Retirar la petición',
                        icon: Icons.undo_outlined,
                        danger: true,
                        onPressed: () => onRetirar(solicitud!),
                      ))
              : PulsoLabel(
                  'Lo pide el dueño de la cadena',
                  color: tokens.muted2,
                );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [texto, const SizedBox(height: 10), acciones],
            );
          }
          return Row(
            children: [
              Expanded(child: texto),
              const SizedBox(width: 14),
              acciones,
            ],
          );
        },
      ),
    );
  }
}

class _SoloEnLaWeb extends StatelessWidget {
  const _SoloEnLaWeb({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hub_outlined, size: 22, color: tokens.muted),
            const SizedBox(height: 10),
            PulsoLabel('Semáforo de la cadena', color: tokens.muted2),
            const SizedBox(height: 6),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: tokens.chalkDim),
            ),
            const SizedBox(height: 4),
            Text(
              'Esta instalación solo guarda los cierres de su sede. '
              'Ábralo desde la web para ver la red entera.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: tokens.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _PedirCierreDialog extends ConsumerStatefulWidget {
  const _PedirCierreDialog({required this.periodo});

  final PeriodoSemaforo periodo;

  @override
  ConsumerState<_PedirCierreDialog> createState() => _PedirCierreDialogState();
}

class _PedirCierreDialogState extends ConsumerState<_PedirCierreDialog> {
  final _nota = TextEditingController();
  String? _error;
  bool _enviando = false;

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ref
          .read(cierreCadenaRepositoryProvider)
          .pedirCierre(
            tipoPeriodo: widget.periodo.esMesNatural ? 'MES' : 'RANGO',
            desde: widget.periodo.desde,
            hastaExclusivo: widget.periodo.hastaExclusivo,
            nota: _nota.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final dia = DateFormat('yyyy-MM-dd');
    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      backgroundColor: tokens.surface,
      title: const Text('Pedir el cierre del período'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cada sede recibirá el aviso y firmará su propio cierre con su '
              'arqueo. El central no cierra por ellas: el dinero está allí.',
              style: TextStyle(color: tokens.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              '${dia.format(widget.periodo.desde)} → '
              '${dia.format(widget.periodo.ultimoDiaIncluido)}',
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontSize: 13,
                color: tokens.chalk,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nota,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Nota para las sedes (opcional)',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: tokens.danger, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        PulsoSecondaryButton(
          label: 'Cancelar',
          onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
        ),
        PulsoPrimaryButton(
          label: 'Pedir el cierre',
          onPressed: _enviando ? null : _enviar,
        ),
      ],
    );
  }
}

class _RetirarSolicitudDialog extends ConsumerStatefulWidget {
  const _RetirarSolicitudDialog({required this.solicitud});

  final SolicitudCierreModel solicitud;

  @override
  ConsumerState<_RetirarSolicitudDialog> createState() =>
      _RetirarSolicitudDialogState();
}

class _RetirarSolicitudDialogState
    extends ConsumerState<_RetirarSolicitudDialog> {
  final _motivo = TextEditingController();
  String? _error;
  bool _enviando = false;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_motivo.text.trim().isEmpty) {
      setState(() => _error = 'Retirar una petición exige decir por qué.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ref
          .read(cierreCadenaRepositoryProvider)
          .retirarSolicitud(
            solicitudId: widget.solicitud.solicitudId,
            motivo: _motivo.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      backgroundColor: tokens.surface,
      title: const Text('Retirar la petición de cierre'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'El aviso desaparece de la bandeja de cada sede. Los cierres que '
              'ya se firmaron por él no se tocan.',
              style: TextStyle(color: tokens.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _motivo,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Motivo'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: tokens.danger, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        PulsoSecondaryButton(
          label: 'Cancelar',
          onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
        ),
        PulsoPrimaryButton(
          label: 'Retirar',
          onPressed: _enviando ? null : _enviar,
        ),
      ],
    );
  }
}
