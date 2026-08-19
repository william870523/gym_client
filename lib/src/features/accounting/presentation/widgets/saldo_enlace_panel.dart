import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/saldo_enlace_models.dart';
import '../../data/repositories/saldo_enlace_repository.dart';
import '../state/saldo_enlace_providers.dart';

/// Mínimos que manda `PulsoStateView`: 28 de padding arriba y abajo, 30 de
/// icono, 12 de hueco y el mensaje —más 44 del botón cuando lo lleva—.
const double _altoEstado = 132;
const double _altoEstadoConReintento = 214;

/// M8 — lo que una sede debe, y registrar que lo pagó (§5.4).
///
/// Va en la pantalla de la cadena porque es el último paso del mismo trabajo:
/// veo quién cerró, cuánto suma, lo congelo, abro la sede que chirría… y aquí
/// veo qué le debe a las demás y anoto la transferencia cuando se hace.
///
/// **El saldo no es del período.** Es lo que se debe *hoy*, acumulado desde el
/// primer cobro cruzado, y por eso este panel no obedece al selector de arriba.
/// Se dice en la propia cabecera: filtrarlo por el período daría una cifra que
/// nadie puede transferir, y quien la viera creería que ya no debe el resto.
class SaldoEnlacePanel extends ConsumerWidget {
  const SaldoEnlacePanel({
    super.key,
    required this.gymId,
    required this.nombreSede,
    this.compact = false,
    this.sedePropia = false,
  });

  /// La sede que se está mirando. `null` cuando aún no se ha elegido ninguna.
  final String? gymId;
  final String? nombreSede;
  final bool compact;

  /// Esta instalación **es** una sede: se carga su saldo sin elegir nada, y la
  /// consulta viaja sin `gym_id` porque el servidor local ya sabe cuál es.
  final bool sedePropia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);

    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Cabecera(
            titulo: 'SALDO ENTRE SEDES',
            nota: 'Acumulado · no depende del período',
            notaColor: tokens.muted2,
          ),
          if (gymId == null && sedePropia)
            // Sin sede elegida pero en su propia instalación: se pide sin
            // `gym_id` y el servidor local contesta lo suyo.
            const _SaldoDeLaSede(gymId: null, nombreSede: null, compact: false)
          else if (gymId == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Text(
                'Elija una sede arriba para ver qué le debe a las demás y a la '
                'cadena. Estas cifras son lo que se debe hoy, no lo del período: '
                'nacen de los cobros en que el efectivo entró en una caja y el '
                'ingreso era de otro.',
                style: TextStyle(fontSize: 12, color: tokens.chalkDim),
              ),
            )
          else
            _SaldoDeLaSede(
              gymId: gymId!,
              nombreSede: nombreSede,
              compact: compact,
            ),
        ],
      ),
    );
  }
}

class _SaldoDeLaSede extends ConsumerWidget {
  const _SaldoDeLaSede({
    required this.gymId,
    required this.nombreSede,
    required this.compact,
  });

  /// `null` cuando la instalación pregunta por sí misma: la consulta viaja sin
  /// `gym_id` y el servidor local contesta lo suyo.
  final String? gymId;
  final String? nombreSede;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saldo = ref.watch(saldoDeSedeProvider(gymId));

    return saldo.when(
      loading: () => const SizedBox(
        height: _altoEstado,
        child: PulsoStateView(
          kind: PulsoStateKind.loading,
          message: 'Sumando el libro de asientos…',
        ),
      ),
      error: (error, _) => SizedBox(
        height: _altoEstadoConReintento,
        child: PulsoStateView(
          kind: PulsoStateKind.error,
          message: error.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(saldoDeSedeProvider(gymId)),
        ),
      ),
      data: (datos) => _Cuerpo(
        datos: datos,
        // El servidor dice de qué sede es lo que acaba de contestar; en una
        // instalación eso es lo único que la identifica aquí.
        gymId: gymId ?? datos.gymId,
        clave: gymId,
        nombreSede: nombreSede ?? datos.nombre,
        compact: compact,
      ),
    );
  }
}

class _Cuerpo extends ConsumerWidget {
  const _Cuerpo({
    required this.datos,
    required this.gymId,
    required this.clave,
    required this.nombreSede,
    required this.compact,
  });

  final SaldoSedeModel datos;
  final String gymId;

  /// La clave con la que se pidió: `null` si fue la instalación por sí misma.
  /// Invalidar con otra dejaría la vista sin refrescarse tras liquidar.
  final String? clave;
  final String nombreSede;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    if (datos.lineas.isEmpty) {
      return const SizedBox(
        height: _altoEstado,
        child: PulsoStateView(
          kind: PulsoStateKind.empty,
          message: 'Esta sede no ha cobrado nada por cuenta ajena: no debe nada.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (datos.sinDeuda)
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.line)),
              color: tokens.successSoft,
            ),
            child: Row(
              children: [
                Container(width: 19, height: 2, color: tokens.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sin deudas vivas. Las líneas de abajo se conservan para poder '
                    'cuadrar: liquidar no borra nada, añade el contraasiento.',
                    style: TextStyle(fontSize: 12, color: tokens.chalkDim),
                  ),
                ),
              ],
            ),
          ),
        _CabeceraColumnas(compact: compact),
        for (final linea in datos.lineas)
          _FilaSaldo(
            linea: linea,
            compact: compact,
            onLiquidar: linea.aFavor || linea.saldado
                ? null
                : () => _abrirLiquidacion(context, ref, linea),
          ),
        _Liquidaciones(gymId: gymId, clave: clave, compact: compact),
      ],
    );
  }

  Future<void> _abrirLiquidacion(
    BuildContext context,
    WidgetRef ref,
    LineaSaldoModel linea,
  ) async {
    final hecha = await showDialog<LiquidacionHechaModel>(
      context: context,
      builder: (_) => LiquidarSaldoDialog(
        gymId: gymId,
        nombreSede: nombreSede,
        linea: linea,
      ),
    );
    if (hecha == null || !context.mounted) return;
    ref.invalidate(saldoDeSedeProvider(clave));
    ref.invalidate(liquidacionesDeSedeProvider(clave));
    final mensaje = hecha.yaEstaba
        ? 'Esa liquidación ya estaba registrada; no se ha pagado dos veces.'
        : hecha.liquidaDelTodo
        ? 'Liquidado. La deuda queda saldada.'
        : hecha.dejaSaldoAFavor
        ? 'Registrado. Queda ${hecha.saldoDespues} a favor de la sede.'
        : 'Registrado. Quedan ${hecha.saldoDespues} por liquidar.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }
}

class _CabeceraColumnas extends StatelessWidget {
  const _CabeceraColumnas({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    TextStyle estilo() => TextStyle(
      fontFamily: PulsoFonts.mono,
      fontSize: 8,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w500,
      color: tokens.muted2,
    );
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('SE LE DEBE A', style: estilo())),
          if (!compact)
            Expanded(flex: 2, child: Text('NACIDO DE COBROS', style: estilo())),
          if (!compact)
            Expanded(flex: 2, child: Text('YA LIQUIDADO', style: estilo())),
          Expanded(flex: 2, child: Text('SALDO', style: estilo())),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _FilaSaldo extends StatelessWidget {
  const _FilaSaldo({
    required this.linea,
    required this.compact,
    required this.onLiquidar,
  });

  final LineaSaldoModel linea;
  final bool compact;
  final VoidCallback? onLiquidar;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = linea.aFavor
        ? tokens.warning
        : linea.saldado
        ? tokens.muted
        : tokens.chalk;

    return Container(
      constraints: const BoxConstraints(minHeight: 61),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: linea.aFavor
                            ? tokens.warning
                            : linea.saldado
                            ? tokens.success
                            : tokens.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        linea.acreedor.nombre,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tokens.chalk,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  linea.aFavor
                      ? 'PAGADO DE MÁS · ${linea.asientos} ASIENTOS'
                      : linea.saldado
                      ? 'SALDADO · ${linea.asientos} ASIENTOS'
                      : '${linea.asientos} ASIENTOS',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 8,
                    letterSpacing: 0.6,
                    color: tokens.muted2,
                  ),
                ),
              ],
            ),
          ),
          if (!compact)
            Expanded(flex: 2, child: _Dinero(linea.generado, color: tokens.muted)),
          if (!compact)
            Expanded(flex: 2, child: _Dinero(linea.deshecho, color: tokens.muted)),
          Expanded(
            flex: 2,
            child: _Dinero(linea.saldo, color: color, fuerte: true),
          ),
          SizedBox(
            width: 40,
            child: onLiquidar == null
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.centerRight,
                    child: PulsoIconButton(
                      icon: Icons.call_made,
                      tooltip: 'Registrar la transferencia',
                      onPressed: onLiquidar,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Dinero: mono, cifras tabulares, alineado a la derecha.
class _Dinero extends StatelessWidget {
  const _Dinero(this.valor, {required this.color, this.fuerte = false});

  final String valor;
  final Color color;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    return Text(
      valor,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontFamily: PulsoFonts.mono,
        fontSize: 13,
        fontWeight: fuerte ? FontWeight.w600 : FontWeight.w500,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// El historial: qué se transfirió, con qué referencia y quién lo anotó.
class _Liquidaciones extends ConsumerWidget {
  const _Liquidaciones({
    required this.gymId,
    required this.clave,
    required this.compact,
  });

  final String gymId;
  final String? clave;
  final bool compact;

  static final _fecha = DateFormat('yyyy-MM-dd HH:mm');

  /// Anular es contraasentar: la fila se queda, marcada, y la deuda vuelve.
  Future<void> _anular(
    BuildContext context,
    WidgetRef ref,
    String? clave,
    LiquidacionModel fila,
  ) async {
    final hecho = await showDialog<bool>(
      context: context,
      builder: (_) => AnularLiquidacionDialog(fila: fila),
    );
    if (hecho != true || !context.mounted) return;
    ref.invalidate(saldoDeSedeProvider(clave));
    ref.invalidate(liquidacionesDeSedeProvider(clave));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Anulada. Los ${fila.monto} vuelven a la deuda; la transferencia '
          'queda registrada.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    final lista = ref.watch(liquidacionesDeSedeProvider(clave));
    final filas = lista.asData?.value ?? const <LiquidacionModel>[];
    if (filas.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: tokens.raised,
            border: Border(bottom: BorderSide(color: tokens.line)),
          ),
          child: PulsoLabel('Transferencias registradas · ${filas.length}'),
        ),
        for (final fila in filas)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  fila.acreedor.nombre,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: fila.anulada
                                        ? tokens.muted
                                        : tokens.chalk,
                                    // Tachada: la transferencia existió, pero ya
                                    // no cuenta. Quitarla de la lista borraría
                                    // algo que ocurrió de verdad.
                                    decoration: fila.anulada
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                              if (fila.anulada) ...[
                                const SizedBox(width: 8),
                                _Marca(texto: 'ANULADA', color: tokens.danger),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            [
                              if (fila.ocurridoAt != null)
                                _fecha.format(fila.ocurridoAt!),
                              if (fila.referencia != null) fila.referencia!,
                              fila.registradaPor,
                            ].join(' · ').toUpperCase(),
                            style: TextStyle(
                              fontFamily: PulsoFonts.mono,
                              fontSize: 8,
                              letterSpacing: 0.6,
                              color: tokens.muted2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!compact)
                      Expanded(
                        flex: 3,
                        child: Text(
                          '${fila.saldoAntes} → ${fila.saldoDespues}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: PulsoFonts.mono,
                            fontSize: 11,
                            color: fila.dejoSaldoAFavor
                                ? tokens.warning
                                : tokens.muted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    Expanded(
                      flex: 2,
                      child: _Dinero(
                        fila.monto,
                        color: fila.anulada ? tokens.muted : tokens.chalk,
                        fuerte: true,
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: fila.anulada
                          ? const SizedBox.shrink()
                          : Align(
                              alignment: Alignment.centerRight,
                              child: PulsoIconButton(
                                icon: Icons.undo,
                                tooltip: 'Anular esta liquidación',
                                onPressed: () =>
                                    _anular(context, ref, clave, fila),
                              ),
                            ),
                    ),
                  ],
                ),
                // El motivo va **en la fila**, no escondido tras un clic: quien
                // revisa el historial busca justamente por qué se corrigió.
                if (fila.anulada && fila.anuladaMotivo != null) ...[
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: tokens.line),
                      color: tokens.raised,
                    ),
                    child: Text(
                      '${fila.anuladaMotivo!}'
                      '${fila.anuladaPor != null ? ' · ${fila.anuladaPor}' : ''}',
                      style: TextStyle(fontSize: 11, color: tokens.chalkDim),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Registrar la transferencia.
///
/// El importe se teclea a mano y no se rellena con la deuda entera a propósito:
/// lo que se anota es **lo que se transfirió de verdad**, y un campo ya relleno
/// invita a confirmar sin mirar. La deuda se enseña al lado para poder
/// compararla.
class LiquidarSaldoDialog extends ConsumerStatefulWidget {
  const LiquidarSaldoDialog({
    super.key,
    required this.gymId,
    required this.nombreSede,
    required this.linea,
  });

  final String gymId;
  final String nombreSede;
  final LineaSaldoModel linea;

  @override
  ConsumerState<LiquidarSaldoDialog> createState() => _LiquidarSaldoDialogState();
}

class _LiquidarSaldoDialogState extends ConsumerState<LiquidarSaldoDialog> {
  final _monto = TextEditingController();
  final _referencia = TextEditingController();
  final _nota = TextEditingController();

  /// Se genera una vez y **no cambia al reintentar**: es lo que convierte un
  /// segundo clic en la misma liquidación en vez de en un segundo pago.
  late final String _liquidacionId =
      'liq-${DateTime.now().microsecondsSinceEpoch}-${widget.gymId.hashCode.abs()}';

  bool _aceptaAFavor = false;
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _monto.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _monto.dispose();
    _referencia.dispose();
    _nota.dispose();
    super.dispose();
  }

  /// Compara en unidades mínimas, sin coma flotante: es la misma cuenta que
  /// hace el servidor, y con `double` los dos podrían discrepar en un céntimo
  /// justo en el caso límite —pagar exactamente la deuda—.
  static BigInt? _minimas(String texto) {
    final limpio = texto.trim();
    if (!RegExp(r'^-?\d+([.,]\d{0,2})?$').hasMatch(limpio)) return null;
    final normal = limpio.replaceAll(',', '.');
    final negativo = normal.startsWith('-');
    final partes = normal.replaceFirst('-', '').split('.');
    final centavos = '${partes.length > 1 ? partes[1] : ''}00'.substring(0, 2);
    final total = BigInt.parse(partes[0]) * BigInt.from(100) + BigInt.parse(centavos);
    return negativo ? -total : total;
  }

  bool get _pagaDeMas {
    final monto = _minimas(_monto.text);
    final debe = _minimas(widget.linea.saldo);
    return monto != null && debe != null && monto > debe;
  }

  Future<void> _registrar() async {
    final monto = _minimas(_monto.text);
    if (monto == null || monto <= BigInt.zero) {
      setState(() => _error = 'El importe tiene que ser una cifra positiva.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final hecha = await ref.read(saldoEnlaceRepositoryProvider).liquidar(
        liquidacionId: _liquidacionId,
        gymId: widget.gymId,
        acreedor: widget.linea.acreedor,
        monedaId: widget.linea.monedaId,
        monto: _monto.text.trim().replaceAll(',', '.'),
        aceptaDejarSaldoAFavor: _aceptaAFavor,
        referencia: _referencia.text,
        nota: _nota.text,
      );
      if (mounted) Navigator.of(context).pop(hecha);
    } on LiquidacionSoloEnElConcentrador catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final puede = !_enviando && (!_pagaDeMas || _aceptaAFavor);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: PulsoPanel(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Cabecera(
                  titulo: 'REGISTRAR TRANSFERENCIA',
                  nota: 'No mueve dinero · lo anota',
                  notaColor: tokens.muted2,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.nombreSede} → ${widget.linea.acreedor.nombre}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tokens.chalk,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: tokens.line),
                          color: tokens.raised,
                        ),
                        child: Row(
                          children: [
                            Expanded(child: PulsoLabel('Se debe hoy')),
                            _Dinero(
                              widget.linea.saldo,
                              color: tokens.chalk,
                              fuerte: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _Campo(
                        etiqueta: 'Importe transferido',
                        controller: _monto,
                        hint: '0.00',
                        teclado: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        formatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Campo(
                        etiqueta: 'Referencia de la transferencia',
                        controller: _referencia,
                        hint: 'Número de operación, comprobante…',
                      ),
                      const SizedBox(height: 12),
                      _Campo(
                        etiqueta: 'Nota',
                        controller: _nota,
                        hint: 'Opcional',
                      ),
                      if (_pagaDeMas) ...[
                        const SizedBox(height: 14),
                        _AvisoPagoDeMas(
                          marcado: _aceptaAFavor,
                          onCambio: (v) => setState(() => _aceptaAFavor = v),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            border: Border.all(color: tokens.danger),
                            color: tokens.dangerSoft,
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(fontSize: 12, color: tokens.danger),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: PulsoSecondaryButton(
                              label: 'Cancelar',
                              onPressed: _enviando
                                  ? null
                                  : () => Navigator.of(context).pop(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PulsoPrimaryButton(
                              label: _enviando ? 'REGISTRANDO…' : 'REGISTRAR',
                              onPressed: puede ? _registrar : null,
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
  }
}

/// Pagar de más es real y hay que poder registrarlo. Pero también es lo que
/// pasa al teclear un cero de más, y el saldo queda negativo con aspecto de
/// abono a favor. Por eso se declara aquí antes de que el servidor lo acepte.
class _AvisoPagoDeMas extends StatelessWidget {
  const _AvisoPagoDeMas({required this.marcado, required this.onCambio});

  final bool marcado;
  final ValueChanged<bool> onCambio;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.warning),
        color: tokens.warningSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Se transfiere más de lo que se debe.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tokens.warning,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'La diferencia queda a favor de la sede. Si ha sido un cero de más, '
            'corrija el importe: después el saldo se lee como un abono.',
            style: TextStyle(fontSize: 11, color: tokens.chalkDim),
          ),
          const SizedBox(height: 8),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onCambio(!marcado),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: marcado ? tokens.warning : tokens.lineStrong,
                      ),
                      color: marcado ? tokens.warning : Colors.transparent,
                    ),
                    child: marcado
                        ? Icon(Icons.check, size: 12, color: tokens.surface)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Es intencionado: dejar saldo a favor',
                      style: TextStyle(fontSize: 12, color: tokens.chalk),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({
    required this.etiqueta,
    required this.controller,
    required this.hint,
    this.teclado,
    this.formatters,
  });

  final String etiqueta;
  final TextEditingController controller;
  final String hint;
  final TextInputType? teclado;
  final List<TextInputFormatter>? formatters;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // La etiqueta va siempre visible: el placeholder no la sustituye.
        PulsoLabel(etiqueta),
        const SizedBox(height: 6),
        SizedBox(
          height: 42,
          child: TextField(
            controller: controller,
            keyboardType: teclado,
            inputFormatters: formatters,
            style: TextStyle(
              fontFamily: teclado == null ? PulsoFonts.body : PulsoFonts.mono,
              fontSize: 13,
              color: tokens.chalk,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: TextStyle(fontSize: 12, color: tokens.muted2),
              contentPadding: const EdgeInsets.symmetric(horizontal: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: tokens.muted2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: tokens.muted2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: tokens.accent),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Cabecera de panel: 60 px, título en display y nota mono a la derecha.
class _Cabecera extends StatelessWidget {
  const _Cabecera({
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

/// Marca corta encuadrada, para estados de fila.
class _Marca extends StatelessWidget {
  const _Marca({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(border: Border.all(color: color)),
      child: Text(
        texto,
        style: TextStyle(
          fontFamily: PulsoFonts.mono,
          fontSize: 8,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Anular una liquidación.
///
/// Se exige **motivo** y el botón no se habilita sin él, igual que en el
/// servidor. Una corrección de dinero entre dos negocios sin explicar es
/// indistinguible de un error, y quien la audite dentro de seis meses no tendrá
/// a nadie a quien preguntarle.
class AnularLiquidacionDialog extends ConsumerStatefulWidget {
  const AnularLiquidacionDialog({super.key, required this.fila});

  final LiquidacionModel fila;

  @override
  ConsumerState<AnularLiquidacionDialog> createState() =>
      _AnularLiquidacionDialogState();
}

class _AnularLiquidacionDialogState
    extends ConsumerState<AnularLiquidacionDialog> {
  final _motivo = TextEditingController();
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _motivo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _anular() async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ref.read(saldoEnlaceRepositoryProvider).anular(
        liquidacionId: widget.fila.liquidacionId,
        motivo: _motivo.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on LiquidacionSoloEnElConcentrador catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final puede = !_enviando && _motivo.text.trim().isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: PulsoPanel(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Cabecera(
                  titulo: 'ANULAR LIQUIDACIÓN',
                  nota: 'Se contraasienta · no se borra',
                  notaColor: tokens.muted2,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: tokens.line),
                          color: tokens.raised,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${widget.fila.monto} a ${widget.fila.acreedor.nombre}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: tokens.chalk,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Esa cantidad vuelve a la deuda. La transferencia '
                              'se queda registrada y marcada como anulada: '
                              'ocurrió de verdad, y borrarla dejaría el saldo '
                              'cuadrando por casualidad.',
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.chalkDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _Campo(
                        etiqueta: 'Motivo de la anulación',
                        controller: _motivo,
                        hint: 'Por qué se corrige',
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            border: Border.all(color: tokens.danger),
                            color: tokens.dangerSoft,
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(fontSize: 12, color: tokens.danger),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: PulsoSecondaryButton(
                              label: 'Cancelar',
                              onPressed: _enviando
                                  ? null
                                  : () => Navigator.of(context).pop(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PulsoPrimaryButton(
                              label: _enviando ? 'ANULANDO…' : 'ANULAR',
                              onPressed: puede ? _anular : null,
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
  }
}
