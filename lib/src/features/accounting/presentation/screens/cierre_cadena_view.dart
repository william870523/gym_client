import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../auth/presentation/state/sede_session_provider.dart';
import '../../data/models/cierre_cadena_m6_models.dart';
import '../../data/repositories/cierre_cadena_repository.dart';
import '../state/cierre_cadena_m6_providers.dart';
import '../state/cierre_cadena_providers.dart';
import '../widgets/saldo_enlace_panel.dart';
import '../widgets/semaforo_cierre_panel.dart';

/// Alto mínimo de un estado de carga o vacío, y de uno con botón de reintento.
///
/// Los manda `PulsoStateView`: 28 de padding arriba y abajo, 30 de icono, 12 de
/// hueco y el mensaje —más 44 del botón cuando lo lleva—. Ponerle menos desborda
/// por unos pocos píxeles, que es lo que pasó al montar esta vista.
const double _altoEstado = 132;
const double _altoEstadoConReintento = 214;

/// M6 — contabilidad central de la cadena (docs/MULTI_SEDE.md §6.3 y §6.4).
///
/// Las tres vistas que describe §6.4 viven juntas porque son **pasos del mismo
/// trabajo**, no pantallas independientes:
///
/// 1. el **semáforo** dice quién ha cerrado y quién no;
/// 2. el **informe agregado** suma lo que hay, por moneda y con desglose;
/// 3. el **certificado** lo congela, y
/// 4. el **detalle** de una sede explica cualquier cifra que chirríe, y
/// 5. el **saldo entre sedes** (M8, §5.4) dice qué le debe esa sede a las demás
///    y deja registrar la transferencia cuando se hace.
///
/// Repartirlas por menús obligaría a recordar el período al saltar de una a
/// otra, que es justo donde uno acaba mirando agosto en una y julio en la otra.
/// Aquí el período se elige una vez y manda sobre las cuatro primeras —**el
/// saldo no**, y eso se dice en su cabecera: es lo que se debe hoy, acumulado
/// desde el primer cobro cruzado, y filtrarlo por período daría una cifra que
/// nadie puede transferir—. La sede elegida en el detalle sí manda sobre él:
/// es el mismo gesto, «abro la que chirría».
///
/// El semáforo se mudó desde la pantalla de Sedes, donde vivió durante M5: allí
/// era un panel plegado en el catálogo de sedes; aquí es el primer paso del
/// flujo al que pertenece.
class CierreCadenaView extends ConsumerStatefulWidget {
  const CierreCadenaView({super.key});

  @override
  ConsumerState<CierreCadenaView> createState() => _CierreCadenaViewState();
}

class _CierreCadenaViewState extends ConsumerState<CierreCadenaView> {
  late PeriodoSemaforo _periodo;

  @override
  void initState() {
    super.initState();
    // El mes anterior: el en curso todavía está abierto, y pedir su cierre sería
    // pedir que se firme dinero que aún está entrando.
    final hoy = DateTime.now();
    _periodo = PeriodoSemaforo.mesDe(DateTime(hoy.year, hoy.month - 1));
  }

  static const _meses = [
    'ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO',
    'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE',
  ];
  static final _dia = DateFormat('yyyy-MM-dd');

  String get _etiqueta => _periodo.esMesNatural
      ? '${_meses[_periodo.desde.month - 1]} ${_periodo.desde.year}'
      : '${_dia.format(_periodo.desde)} → ${_dia.format(_periodo.ultimoDiaIncluido)}';

  void _mover(PeriodoSemaforo destino) {
    setState(() => _periodo = destino);
    ref.read(sedeEnDetalleProvider.notifier).limpiar();
  }

  void _recargar() {
    ref.invalidate(consolidadoProvider(_periodo));
    ref.invalidate(certificadosProvider);
    ref.invalidate(semaforoCadenaProvider(_periodo));
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(sedeSessionProvider);
    // El servidor rechaza con 403 a quien no es dueño de la cadena; ofrecer la
    // pantalla solo llevaría a un error. La sesión nula es el caso de las
    // pruebas aisladas, igual criterio que `GlobalCatalogAuthority`.
    if (sesion != null && !sesion.esPlataforma) {
      return const _SoloParaLaCadena();
    }

    final sedeEnDetalle = ref.watch(sedeEnDetalleProvider);
    // El nombre sale del semáforo, que ya está cargado para el detalle: pedirlo
    // otra vez solo para rotularlo sería una llamada de más.
    final nombreDeLaSede = ref
        .watch(semaforoCadenaProvider(_periodo))
        .asData
        ?.value
        .filas
        .where((f) => f.gymId == sedeEnDetalle)
        .map((f) => f.nombre)
        .firstOrNull;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final padding = compact ? 16.0 : 32.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(padding, compact ? 16 : 20, padding, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cabecera(
                etiqueta: _etiqueta,
                compact: compact,
                onAnterior: () => _mover(_periodo.mesAnterior),
                onSiguiente: () => _mover(_periodo.mesSiguiente),
                onRecargar: _recargar,
              ),
              const SizedBox(height: 18),
              // 1. Quién ha cerrado.
              SemaforoCierrePanel(
                abierto: true,
                periodoFijado: _periodo,
                onPeriodo: _mover,
              ),
              const SizedBox(height: 18),
              // 2. Cuánto suma.
              _InformePanel(periodo: _periodo, compact: compact),
              const SizedBox(height: 18),
              // 3. Congelarlo.
              _CertificadoPanel(
                periodo: _periodo,
                etiqueta: _etiqueta,
                onFirmado: _recargar,
              ),
              const SizedBox(height: 18),
              // 4. Y si algo chirría, la sede que lo produce.
              _DetallePanel(periodo: _periodo, compact: compact),
              const SizedBox(height: 18),
              // 5. Qué le debe esa sede a las demás, y anotar que lo pagó.
              SaldoEnlacePanel(
                gymId: sedeEnDetalle,
                nombreSede: nombreDeLaSede,
                compact: compact,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.etiqueta,
    required this.compact,
    required this.onAnterior,
    required this.onSiguiente,
    required this.onRecargar,
  });

  final String etiqueta;
  final bool compact;
  final VoidCallback onAnterior;
  final VoidCallback onSiguiente;
  final VoidCallback onRecargar;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final titulo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(width: 26, height: 2, color: tokens.accent),
            const SizedBox(width: 8),
            PulsoLabel('Pulso · contabilidad de la cadena', color: tokens.muted),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'CIERRE DE LA CADENA.',
          style: TextStyle(
            fontFamily: PulsoFonts.display,
            fontSize: compact ? 40 : 54,
            fontWeight: FontWeight.w800,
            letterSpacing: -2,
            height: 0.86,
            color: tokens.chalk,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'El central pide y cada sede cierra. Aquí se mira quién cerró, cuánto '
          'suma la cadena y qué firmar.',
          style: TextStyle(fontSize: 13, color: tokens.chalkDim),
        ),
      ],
    );

    final mando = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Paso(icono: Icons.chevron_left, onTap: onAnterior),
        Container(
          constraints: const BoxConstraints(minWidth: 168),
          height: 40,
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(border: Border.all(color: tokens.line)),
          child: Text(
            etiqueta,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 11,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w500,
              color: tokens.chalk,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        _Paso(icono: Icons.chevron_right, onTap: onSiguiente),
        const SizedBox(width: 8),
        PulsoIconButton(
          icon: Icons.refresh,
          tooltip: 'Volver a leer el período',
          onPressed: onRecargar,
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [titulo, const SizedBox(height: 14), mando],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [Expanded(child: titulo), const SizedBox(width: 18), mando],
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({required this.icono, required this.onTap});

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
          width: 40,
          height: 40,
          decoration: BoxDecoration(border: Border.all(color: tokens.line)),
          child: Icon(icono, size: 17, color: tokens.muted),
        ),
      ),
    );
  }
}

/// 2. El informe agregado: por moneda, con desglose y sin total general.
class _InformePanel extends ConsumerWidget {
  const _InformePanel({required this.periodo, required this.compact});

  final PeriodoSemaforo periodo;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    final informe = ref.watch(consolidadoProvider(periodo));

    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CabeceraPanel(
            titulo: 'INFORME AGREGADO',
            nota: informe.asData?.value.esParcial == true
                ? 'Parcial · faltan sedes'
                : 'Suma de los cierres firmados',
            notaColor: informe.asData?.value.esParcial == true
                ? tokens.warning
                : tokens.muted2,
          ),
          informe.when(
            loading: () => const SizedBox(
              height: _altoEstado,
              child: PulsoStateView(
                kind: PulsoStateKind.loading,
                message: 'Sumando los cierres firmados…',
              ),
            ),
            error: (error, _) => SizedBox(
              height: _altoEstadoConReintento,
              child: error is SemaforoSoloEnElConcentrador
                  ? _NotaDelConcentrador(mensaje: error.mensaje)
                  : PulsoStateView(
                      kind: PulsoStateKind.error,
                      message: error.toString().replaceFirst('Exception: ', ''),
                      onRetry: () => ref.invalidate(consolidadoProvider(periodo)),
                    ),
            ),
            data: (datos) => _InformeCuerpo(datos: datos, compact: compact),
          ),
        ],
      ),
    );
  }
}

class _InformeCuerpo extends StatelessWidget {
  const _InformeCuerpo({required this.datos, required this.compact});

  final ConsolidadoModel datos;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    if (datos.monedas.isEmpty) {
      return SizedBox(
        height: _altoEstado,
        child: PulsoStateView(
          kind: PulsoStateKind.empty,
          message: datos.motivoParaNoFirmar ??
              'Ninguna sede ha firmado su cierre de este período.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final bloque in datos.monedas)
          _BloqueMoneda(bloque: bloque, compact: compact),
        if (datos.avisos.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            decoration: BoxDecoration(
              color: tokens.warningSoft,
              border: Border(top: BorderSide(color: tokens.warning)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(width: 19, height: 2, color: tokens.warning),
                    const SizedBox(width: 8),
                    PulsoLabel(
                      'Lo que estos cierres no pueden afirmar',
                      color: tokens.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final aviso in datos.avisos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      aviso,
                      style: TextStyle(fontSize: 12, color: tokens.chalkDim),
                    ),
                  ),
              ],
            ),
          ),
        if (datos.ausentes.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
            decoration: BoxDecoration(
              color: tokens.raised,
              border: Border(top: BorderSide(color: tokens.line)),
            ),
            // El semáforo, justo encima, ya nombra una por una a las que
            // faltan; repetir la lista aquí es ruido. Lo que este pie añade es lo
            // que el semáforo no dice: que el total de arriba está incompleto.
            child: Text(
              'Este total deja fuera ${datos.ausentes.length} sede(s): las que el '
              'semáforo marca sin consolidar.',
              style: TextStyle(fontSize: 12, color: tokens.chalkDim),
            ),
          ),
      ],
    );
  }
}

class _BloqueMoneda extends StatelessWidget {
  const _BloqueMoneda({required this.bloque, required this.compact});

  final BloqueMonedaModel bloque;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  PulsoLabel('Ingreso de la cadena', color: tokens.muted2),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        bloque.monedaCodigo,
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.muted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        bloque.ingreso,
                        style: TextStyle(
                          fontFamily: PulsoFonts.display,
                          fontSize: 31,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          letterSpacing: -1,
                          color: tokens.chalk,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              if (bloque.tieneAjeno)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PulsoLabel('Cobrado por cuenta ajena', color: tokens.muted2),
                    const SizedBox(height: 3),
                    Text(
                      bloque.cobradoCuentaAjena,
                      style: TextStyle(
                        fontFamily: PulsoFonts.mono,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: tokens.warning,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'no suma en el ingreso',
                      style: TextStyle(fontSize: 10, color: tokens.muted2),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Siempre el desglose: un total sin él no se puede auditar ni repartir.
          for (final sede in bloque.sedes)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      sede.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: tokens.chalkDim),
                    ),
                  ),
                  if (!compact) ...[
                    Text(
                      sede.origenCierre.toLowerCase(),
                      style: TextStyle(
                        fontFamily: PulsoFonts.mono,
                        fontSize: 8,
                        letterSpacing: 0.6,
                        color: tokens.muted2,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    sede.ingreso,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: tokens.chalk,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 3. El certificado: congelar el período y ver lo ya congelado.
class _CertificadoPanel extends ConsumerStatefulWidget {
  const _CertificadoPanel({
    required this.periodo,
    required this.etiqueta,
    required this.onFirmado,
  });

  final PeriodoSemaforo periodo;
  final String etiqueta;
  final VoidCallback onFirmado;

  @override
  ConsumerState<_CertificadoPanel> createState() => _CertificadoPanelState();
}

class _CertificadoPanelState extends ConsumerState<_CertificadoPanel> {
  static final _dia = DateFormat('yyyy-MM-dd');
  static final _diaHora = DateFormat('yyyy-MM-dd HH:mm');

  CertificadoModel? _vigenteDelPeriodo(List<CertificadoModel> lista) {
    for (final certificado in lista) {
      if (!certificado.vigente) continue;
      if (certificado.fechaInicio == widget.periodo.desde &&
          certificado.fechaFinExclusiva == widget.periodo.hastaExclusivo) {
        return certificado;
      }
    }
    return null;
  }

  Future<void> _firmar(bool rehacer) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => _FirmarDialog(
        periodo: widget.periodo,
        etiqueta: widget.etiqueta,
        rehacer: rehacer,
      ),
    );
    if (confirmado == true) {
      ref.invalidate(certificadosProvider);
      widget.onFirmado();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final certificados = ref.watch(certificadosProvider);
    final informe = ref.watch(consolidadoProvider(widget.periodo));

    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CabeceraPanel(
            titulo: 'CERTIFICADO',
            nota: 'La foto que ya no cambia',
            notaColor: tokens.muted2,
          ),
          certificados.when(
            loading: () => const SizedBox(
              height: _altoEstado,
              child: PulsoStateView(
                kind: PulsoStateKind.loading,
                message: 'Leyendo los certificados…',
              ),
            ),
            error: (error, _) => SizedBox(
              height: _altoEstadoConReintento,
              child: error is SemaforoSoloEnElConcentrador
                  ? _NotaDelConcentrador(mensaje: error.mensaje)
                  : PulsoStateView(
                      kind: PulsoStateKind.error,
                      message: error.toString().replaceFirst('Exception: ', ''),
                      onRetry: () => ref.invalidate(certificadosProvider),
                    ),
            ),
            data: (lista) {
              final vigente = _vigenteDelPeriodo(lista);
              final delPeriodo = lista
                  .where((c) =>
                      c.fechaInicio == widget.periodo.desde &&
                      c.fechaFinExclusiva == widget.periodo.hastaExclusivo)
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    child: vigente == null
                        ? _SinCertificado(
                            motivo: informe.asData?.value.motivoParaNoFirmar,
                            parcial: informe.asData?.value.esParcial ?? false,
                            onFirmar: informe.asData?.value.sePuedeFirmar == true
                                ? () => _firmar(false)
                                : null,
                          )
                        : _ConCertificado(
                            certificado: vigente,
                            onRehacer: () => _firmar(true),
                          ),
                  ),
                  if (delPeriodo.length > 1)
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                      decoration: BoxDecoration(
                        color: tokens.raised,
                        border: Border(top: BorderSide(color: tokens.line)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PulsoLabel('Ciclos anteriores', color: tokens.muted2),
                          const SizedBox(height: 6),
                          // Los anulados se conservan a propósito: son la prueba
                          // de lo que se cerró entonces.
                          for (final anterior in delPeriodo.where((c) => !c.vigente))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                'Ciclo ${anterior.cicloNumero} · anulado'
                                '${anterior.firmadoAt == null ? '' : ' · firmado el ${_dia.format(anterior.firmadoAt!)}'}'
                                '${anterior.anuladoMotivo == null ? '' : ' · ${anterior.anuladoMotivo}'}',
                                style: TextStyle(fontSize: 11, color: tokens.muted),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String diaHora(DateTime valor) => _diaHora.format(valor);
}

class _SinCertificado extends StatelessWidget {
  const _SinCertificado({
    required this.motivo,
    required this.parcial,
    required this.onFirmar,
  });

  final String? motivo;
  final bool parcial;
  final VoidCallback? onFirmar;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Este período no está certificado.',
                style: TextStyle(fontSize: 14, color: tokens.chalk),
              ),
              const SizedBox(height: 3),
              Text(
                motivo ??
                    (parcial
                        ? 'Se puede firmar como cierre parcial declarado: el certificado '
                              'nombrará dentro a las sedes que quedan fuera.'
                        : 'Todas las sedes están en verde: el certificado saldrá completo.'),
                style: TextStyle(
                  fontSize: 12,
                  color: motivo == null ? tokens.chalkDim : tokens.warning,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        PulsoSecondaryButton(
          label: parcial ? 'Firmar parcial' : 'Firmar certificado',
          icon: Icons.verified_outlined,
          onPressed: onFirmar,
        ),
      ],
    );
  }
}

class _ConCertificado extends StatelessWidget {
  const _ConCertificado({required this.certificado, required this.onRehacer});

  final CertificadoModel certificado;
  final VoidCallback onRehacer;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final integro = certificado.integro ?? true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: integro ? tokens.success : tokens.danger,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                integro
                    ? 'Certificado · sello verificado'
                    : 'Certificado · EL SELLO NO CUADRA',
                style: TextStyle(
                  fontSize: 13,
                  color: integro ? tokens.success : tokens.danger,
                ),
              ),
            ),
            PulsoLabel(
              certificado.esParcial ? 'PARCIAL DECLARADO' : 'COMPLETO',
              color: certificado.esParcial ? tokens.warning : tokens.muted2,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Ciclo ${certificado.cicloNumero} · ${certificado.sedesIncluidas} sede(s) dentro'
          '${certificado.firmadoPor == null ? '' : ' · firmó ${certificado.firmadoPor}'}'
          '${certificado.firmadoAt == null ? '' : ' el ${_CertificadoPanelState.diaHora(certificado.firmadoAt!)}'}',
          style: TextStyle(fontSize: 12, color: tokens.chalkDim),
        ),
        const SizedBox(height: 6),
        // El sello a la vista: es lo que permite comprobar una copia impresa
        // contra la base sin creerse la pantalla.
        Text(
          certificado.sha256,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: 10,
            letterSpacing: 0.4,
            color: tokens.muted2,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: PulsoSecondaryButton(
            label: 'Rehacer con motivo',
            icon: Icons.history_toggle_off,
            onPressed: onRehacer,
          ),
        ),
      ],
    );
  }
}

/// 4. El detalle de una sede: solo lectura, y con el origen dicho.
class _DetallePanel extends ConsumerWidget {
  const _DetallePanel({required this.periodo, required this.compact});

  final PeriodoSemaforo periodo;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    final sedeId = ref.watch(sedeEnDetalleProvider);
    final semaforo = ref.watch(semaforoCadenaProvider(periodo));
    final sedes = semaforo.asData?.value.filas ?? const [];

    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CabeceraPanel(
            titulo: 'DETALLE POR SEDE',
            nota: 'Solo lectura · el central no cobra ni anula',
            notaColor: tokens.muted2,
          ),
          if (sedes.isEmpty)
            const SizedBox(
              height: _altoEstado,
              child: PulsoStateView(
                kind: PulsoStateKind.empty,
                message: 'Elija un período con sedes para poder auditarlas.',
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: tokens.line)),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final fila in sedes)
                    _ChipSede(
                      nombre: fila.nombre,
                      activo: fila.gymId == sedeId,
                      onTap: () =>
                          ref.read(sedeEnDetalleProvider.notifier).alternar(fila.gymId),
                    ),
                ],
              ),
            ),
            if (sedeId == null)
              Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Text(
                  'Elija una sede para ver sus cobros del período. Cada cobro dice '
                  'si el ingreso es suyo, si solo tiene el dinero en caja, o las dos '
                  'cosas.',
                  style: TextStyle(fontSize: 12, color: tokens.chalkDim),
                ),
              )
            else
              _DetalleDeSede(
                pedido: DetallePedido(gymId: sedeId, periodo: periodo),
                compact: compact,
              ),
          ],
        ],
      ),
    );
  }
}

class _ChipSede extends StatelessWidget {
  const _ChipSede({required this.nombre, required this.activo, required this.onTap});

  final String nombre;
  final bool activo;
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
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: activo ? tokens.accent : tokens.line),
            color: activo ? tokens.accentSoft : tokens.surface,
          ),
          child: Text(
            nombre,
            style: TextStyle(
              fontSize: 12,
              color: activo ? tokens.accent : tokens.chalkDim,
            ),
          ),
        ),
      ),
    );
  }
}

class _DetalleDeSede extends ConsumerWidget {
  const _DetalleDeSede({required this.pedido, required this.compact});

  final DetallePedido pedido;
  final bool compact;

  static final _diaHora = DateFormat('yyyy-MM-dd HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    final detalle = ref.watch(detalleDeSedeProvider(pedido));

    return detalle.when(
      loading: () => const SizedBox(
        height: _altoEstado,
        child: PulsoStateView(
          kind: PulsoStateKind.loading,
          message: 'Buscando los cobros de esa sede…',
        ),
      ),
      error: (error, _) => SizedBox(
        height: _altoEstadoConReintento,
        child: error is SemaforoSoloEnElConcentrador
            ? _NotaDelConcentrador(mensaje: error.mensaje)
            : PulsoStateView(
                kind: PulsoStateKind.error,
                message: error.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(detalleDeSedeProvider(pedido)),
              ),
      ),
      data: (datos) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            decoration: BoxDecoration(
              color: datos.esFirmado ? tokens.successSoft : tokens.warningSoft,
              border: Border(bottom: BorderSide(color: tokens.line)),
            ),
            child: Row(
              children: [
                Container(
                  width: 19,
                  height: 2,
                  color: datos.esFirmado ? tokens.success : tokens.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    datos.nota,
                    style: TextStyle(fontSize: 12, color: tokens.chalkDim),
                  ),
                ),
              ],
            ),
          ),
          for (final total in datos.totales)
            Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: tokens.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _Cifra(
                      etiqueta: 'Ingreso suyo',
                      valor: total.ingreso,
                      color: tokens.chalk,
                    ),
                  ),
                  Expanded(
                    child: _Cifra(
                      etiqueta: 'Pasó por su caja',
                      valor: total.efectivo,
                      color: tokens.chalk,
                    ),
                  ),
                  if (total.cobradoCuentaAjena != '0.00')
                    Expanded(
                      child: _Cifra(
                        etiqueta: 'De otra sede',
                        valor: total.cobradoCuentaAjena,
                        color: tokens.warning,
                      ),
                    ),
                  if (!compact)
                    Expanded(
                      child: _Cifra(
                        etiqueta: 'Cobros',
                        valor: '${total.cobros}'
                            '${total.anulados > 0 ? ' (${total.anulados} anul.)' : ''}',
                        color: tokens.muted,
                      ),
                    ),
                ],
              ),
            ),
          _TablaCobros(cobros: datos.cobros, compact: compact),
        ],
      ),
    );
  }

  static String diaHora(DateTime valor) => _diaHora.format(valor);
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.etiqueta, required this.valor, required this.color});

  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PulsoLabel(etiqueta, color: tokens.muted2),
        const SizedBox(height: 2),
        Text(
          valor,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// La tabla de cobros: se desplaza por dentro (recetario §4-bis).
class _TablaCobros extends StatefulWidget {
  const _TablaCobros({required this.cobros, required this.compact});

  final List<CobroDetalleModel> cobros;
  final bool compact;

  @override
  State<_TablaCobros> createState() => _TablaCobrosState();
}

class _TablaCobrosState extends State<_TablaCobros> {
  final _scroll = ScrollController();
  static const double _altoFila = 56;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    if (widget.cobros.isEmpty) {
      return const SizedBox(
        height: _altoEstado,
        child: PulsoStateView(
          kind: PulsoStateKind.empty,
          message: 'Esa sede no registró cobros en este período.',
        ),
      );
    }
    final alto = (widget.cobros.length.clamp(1, 6) * _altoFila) +
        (widget.cobros.length > 6 ? 24 : 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.compact)
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: tokens.raised,
              border: Border(bottom: BorderSide(color: tokens.line)),
            ),
            child: Row(
              children: const [
                Expanded(flex: 30, child: _Columna('Socio y plan')),
                Expanded(flex: 34, child: _Columna('Qué es para esta sede')),
                Expanded(flex: 20, child: _Columna('Cobrador')),
                Expanded(flex: 16, child: _Columna('Importe')),
              ],
            ),
          ),
        SizedBox(
          height: alto,
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: ListView.separated(
              controller: _scroll,
              primary: false,
              padding: EdgeInsets.zero,
              itemCount: widget.cobros.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: tokens.line),
              itemBuilder: (context, index) =>
                  _FilaCobro(cobro: widget.cobros[index], compact: widget.compact),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilaCobro extends StatelessWidget {
  const _FilaCobro({required this.cobro, required this.compact});

  final CobroDetalleModel cobro;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = switch (cobro.clase) {
      'SOLO_EFECTIVO' => tokens.warning,
      'SOLO_INGRESO' => tokens.accent,
      _ => tokens.success,
    };
    final socio = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cobro.ci ?? '—',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: 12,
            color: cobro.anulado ? tokens.muted2 : tokens.chalk,
            decoration: cobro.anulado ? TextDecoration.lineThrough : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          [
            if (cobro.plan != null) cobro.plan!,
            if (cobro.ocurridoAt != null) _DetalleDeSede.diaHora(cobro.ocurridoAt!),
          ].join(' · ').toUpperCase(),
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

    final clase = Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            cobro.anulado ? '${cobro.rotuloClase} · anulado' : cobro.rotuloClase,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: color),
          ),
        ),
      ],
    );

    final importe = Text(
      cobro.monto,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontFamily: PulsoFonts.mono,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: cobro.anulado ? tokens.muted2 : tokens.chalk,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    return Container(
      height: _TablaCobrosState._altoFila,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: compact
          ? Row(
              children: [
                Expanded(flex: 55, child: socio),
                Expanded(flex: 45, child: importe),
              ],
            )
          : Row(
              children: [
                Expanded(flex: 30, child: socio),
                Expanded(flex: 34, child: clase),
                Expanded(
                  flex: 20,
                  child: Text(
                    cobro.cobrador ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: tokens.chalkDim),
                  ),
                ),
                Expanded(flex: 16, child: importe),
              ],
            ),
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

class _CabeceraPanel extends StatelessWidget {
  const _CabeceraPanel({
    required this.titulo,
    required this.nota,
    required this.notaColor,
  });

  final String titulo;
  final String nota;
  final Color notaColor;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(
                fontFamily: PulsoFonts.display,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: tokens.chalk,
              ),
            ),
          ),
          PulsoLabel(nota, color: notaColor),
        ],
      ),
    );
  }
}

class _NotaDelConcentrador extends StatelessWidget {
  const _NotaDelConcentrador({required this.mensaje});

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
            PulsoLabel('Contabilidad de la cadena', color: tokens.muted2),
            const SizedBox(height: 6),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: tokens.chalkDim),
            ),
            const SizedBox(height: 4),
            Text(
              'Esta instalación solo guarda lo suyo. Ábralo desde la web para ver '
              'la red entera.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: tokens.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoloParaLaCadena extends StatelessWidget {
  const _SoloParaLaCadena();

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 24, color: tokens.muted),
            const SizedBox(height: 12),
            PulsoLabel('Cierre de la cadena', color: tokens.muted2),
            const SizedBox(height: 8),
            Text(
              'Esta pantalla suma el dinero de todas las sedes, así que es del '
              'dueño de la cadena.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: tokens.chalkDim),
            ),
          ],
        ),
      ),
    );
  }
}

class _FirmarDialog extends ConsumerStatefulWidget {
  const _FirmarDialog({
    required this.periodo,
    required this.etiqueta,
    required this.rehacer,
  });

  final PeriodoSemaforo periodo;
  final String etiqueta;
  final bool rehacer;

  @override
  ConsumerState<_FirmarDialog> createState() => _FirmarDialogState();
}

class _FirmarDialogState extends ConsumerState<_FirmarDialog> {
  final _motivo = TextEditingController();
  String? _error;
  bool _enviando = false;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (widget.rehacer && _motivo.text.trim().isEmpty) {
      setState(() => _error = 'Rehacer un certificado exige decir por qué.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ref
          .read(cierreCadenaRepositoryProvider)
          .firmarCertificado(
            tipoPeriodo: widget.periodo.esMesNatural ? 'MES' : 'RANGO',
            desde: widget.periodo.desde,
            hastaExclusivo: widget.periodo.hastaExclusivo,
            motivo: widget.rehacer ? _motivo.text : null,
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
      title: Text(widget.rehacer ? 'Rehacer el certificado' : 'Firmar el certificado'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.rehacer
                  ? 'El certificado vigente no se borra: queda anulado con su motivo y '
                        'se conserva, porque «esto es lo que se cerró» tiene que seguir '
                        'siendo demostrable.'
                  : 'Congela una copia exacta de lo que hay ahora. No cambiará aunque '
                        'después entren correcciones.',
              style: TextStyle(color: tokens.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              widget.etiqueta,
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontSize: 13,
                color: tokens.chalk,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (widget.rehacer) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _motivo,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Motivo'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: tokens.danger, fontSize: 12)),
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
          label: widget.rehacer ? 'Rehacer' : 'Firmar',
          onPressed: _enviando ? null : _enviar,
        ),
      ],
    );
  }
}
