import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../auth/presentation/state/auth_notifier.dart';
import '../../../financials/data/models/account_model.dart';
import '../../../payments/presentation/state/payment_notifier.dart';
import '../../data/models/multisede_access_model.dart';
import '../../data/repositories/multisede_access_repository.dart';

/// Acceso multi-sede en el expediente del socio (M4a, docs/MULTI_SEDE.md §5).
///
/// Responde una pregunta completa —«¿puede este socio entrenar en otra sede, y
/// hasta cuándo?»— que es lo que el sistema pide de un panel. Y responde antes
/// de que la haga la siguiente: **qué pasa si lo renuevo hoy**. Renovar antes de
/// tiempo encadena desde el fin vigente, no desde hoy, y esa es justo la duda
/// que hace dudar en el mostrador; enseñarla evita la llamada.
class MultisedeAccessPanel extends ConsumerStatefulWidget {
  const MultisedeAccessPanel({super.key, required this.ci});

  final String ci;

  @override
  ConsumerState<MultisedeAccessPanel> createState() =>
      _MultisedeAccessPanelState();
}

class _MultisedeAccessPanelState extends ConsumerState<MultisedeAccessPanel> {
  bool _trabajando = false;
  String? _motivoDelServidor;

  /// M4b — el cobro pide confirmación porque mueve dinero. La marca gratuita
  /// no la pide: no mueve nada.
  bool _confirmando = false;
  String? _cuentaId;
  MultisedeCobroModel? _ultimoCobro;

  Future<void> _operar(Future<void> Function() accion) async {
    setState(() {
      _trabajando = true;
      _motivoDelServidor = null;
    });
    try {
      await accion();
      ref.invalidate(multisedeAccesoProvider(widget.ci));
    } catch (error) {
      // El servidor explica por qué —sin precio configurado, socio de otra
      // sede— y ese texto es lo único accionable. Se fija en el panel, no en
      // un aviso flotante que se va solo.
      if (mounted) {
        setState(
          () => _motivoDelServidor = error.toString().replaceFirst(
            'Exception: ',
            '',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final acceso = ref.watch(multisedeAccesoProvider(widget.ci));
    final precio = ref.watch(multisedePrecioProvider);
    final permisos =
        ref.watch(authProvider).value?.permissions.toSet() ?? <String>{};
    final puedeEscribir = permisos.contains('clientes.escribir');

    return PulsoPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: PulsoLabel('Acceso multi-sede')),
              acceso.when(
                data: (fila) => _Distintivo(acceso: fila),
                loading: () => const PulsoLabel('CONSULTANDO'),
                error: (_, _) => const PulsoLabel('NO DISPONIBLE'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          acceso.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (error, _) => Text(
              'No se pudo leer el acceso multi-sede.',
              style: TextStyle(color: tokens.danger, fontSize: 12),
            ),
            data: (fila) => _Cuerpo(
              acceso: fila,
              precio: precio.asData?.value,
              tokens: tokens,
            ),
          ),
          if (_motivoDelServidor != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tokens.danger.withValues(alpha: 0.08),
                border: Border.all(color: tokens.danger),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.report_outlined, size: 15, color: tokens.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _motivoDelServidor!,
                      style: TextStyle(color: tokens.danger, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          acceso.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (fila) => _confirmando
                ? _Confirmacion(
                    acceso: fila,
                    precio: precio.asData?.value,
                    cuentas: ref.watch(accountsProvider).asData?.value ??
                        const <AccountModel>[],
                    cuentaId: _cuentaId,
                    habilitado: !_trabajando,
                    onCuenta: (id) => setState(() => _cuentaId = id),
                    onCancelar: () => setState(() => _confirmando = false),
                    onCobrar: () => _operar(() async {
                      final salida = await ref
                          .read(multisedeAccessRepositoryProvider)
                          .cobrar(widget.ci, cuentaId: _cuentaId);
                      if (mounted) {
                        setState(() {
                          _confirmando = false;
                          _ultimoCobro = salida.cobro;
                        });
                      }
                    }),
                  )
                : _Acciones(
                    acceso: fila,
                    habilitado: puedeEscribir && !_trabajando,
                    onCobrar: () => setState(() {
                      _confirmando = true;
                      _motivoDelServidor = null;
                      _ultimoCobro = null;
                    }),
                    onRetirar: () => _operar(
                      () => ref
                          .read(multisedeAccessRepositoryProvider)
                          .retirar(widget.ci),
                    ),
                  ),
          ),
          if (_ultimoCobro != null) ...[
            const SizedBox(height: 12),
            _Comprobante(cobro: _ultimoCobro!, tokens: tokens),
          ],
          if (!puedeEscribir) ...[
            const SizedBox(height: 8),
            PulsoLabel('Solo recepción y administración lo venden',
                color: tokens.muted2),
          ],
        ],
      ),
    );
  }
}

/// Estado en texto **y** forma, nunca solo color (principio 5 de PULSO).
class _Distintivo extends StatelessWidget {
  const _Distintivo({required this.acceso});

  final MultisedeAccessModel? acceso;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final (texto, color, icono) = switch (acceso) {
      null => ('SIN ACCESO', tokens.muted2, Icons.remove_circle_outline),
      final a when a.vigente => ('VIGENTE', tokens.success, Icons.check_circle_outline),
      final a when a.activo => ('VENCIDO', tokens.warning, Icons.schedule),
      _ => ('RETIRADO', tokens.muted2, Icons.block),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: color)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 12, color: color),
          const SizedBox(width: 6),
          PulsoLabel(texto, color: color),
        ],
      ),
    );
  }
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo({
    required this.acceso,
    required this.precio,
    required this.tokens,
  });

  final MultisedeAccessModel? acceso;
  final MultisedePriceModel? precio;
  final PulsoTokens tokens;

  @override
  Widget build(BuildContext context) {
    if (acceso == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Este socio solo entrena en su sede.',
            style: TextStyle(color: tokens.chalkDim, fontSize: 13),
          ),
          const SizedBox(height: 6),
          _LineaPrecio(precio: precio, tokens: tokens),
        ],
      );
    }

    final fin = DateFormat('dd/MM/yyyy').format(acceso!.vigenteHasta);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              fin,
              style: TextStyle(
                fontFamily: PulsoFonts.display,
                fontSize: 31,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                height: 1,
                color: acceso!.vigente ? tokens.chalk : tokens.muted,
              ),
            ),
            const SizedBox(width: 8),
            // `Expanded` y no un `Padding` a secas: la glosa es larga y a 390 px
            // desbordaba la fila 337 px. No lo vio nadie hasta que M4b probó el
            // panel en los cuatro anchos de referencia; las pruebas de M4a solo
            // lo miraban a tamaño de escritorio.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: PulsoLabel(
                  // `vigente_hasta` es exclusiva: el día que figura ya no cubre.
                  acceso!.vigente ? 'cubre hasta ese día, sin incluirlo' : 'ya no cubre',
                  color: tokens.muted2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _LineaPrecio(precio: precio, tokens: tokens, pagado: acceso!.precioSnapshot),
        const SizedBox(height: 4),
        Text(
          'Marcado en ${acceso!.marcadoEnGymId}',
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: 8,
            letterSpacing: 0.8,
            color: tokens.muted2,
          ),
        ),
      ],
    );
  }
}

class _LineaPrecio extends StatelessWidget {
  const _LineaPrecio({required this.precio, required this.tokens, this.pagado});

  final MultisedePriceModel? precio;
  final PulsoTokens tokens;
  final double? pagado;

  @override
  Widget build(BuildContext context) {
    if (precio == null) {
      return Text(
        'Sin precio de cadena configurado: no se puede vender todavía.',
        style: TextStyle(color: tokens.warning, fontSize: 12),
      );
    }
    final tarifa = precio!.precio.toStringAsFixed(2);
    // Enseñar los dos importes cuando difieren es lo que evita la discusión en
    // el mostrador: lo que pagó está congelado y la tarifa pudo subir después.
    final cambio = pagado != null && pagado!.toStringAsFixed(2) != tarifa;
    return Text(
      cambio
          ? 'Pagó ${pagado!.toStringAsFixed(2)} · tarifa hoy $tarifa'
          : 'Tarifa de cadena: $tarifa',
      style: TextStyle(
        fontFamily: PulsoFonts.mono,
        fontSize: 13,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: tokens.chalkDim,
      ),
    );
  }
}

class _Acciones extends StatelessWidget {
  const _Acciones({
    required this.acceso,
    required this.habilitado,
    required this.onCobrar,
    required this.onRetirar,
  });

  final MultisedeAccessModel? acceso;
  final bool habilitado;
  final VoidCallback onCobrar;
  final VoidCallback onRetirar;

  @override
  Widget build(BuildContext context) {
    final vivo = acceso != null && acceso!.activo;
    return Row(
      children: [
        Expanded(
          child: PulsoPrimaryButton(
            // M4b: el verbo dice que hay dinero de por medio. «Renovar» a secas
            // sonaba a trámite y ahora abre un cobro.
            label: vivo ? 'Cobrar un mes' : 'Vender acceso',
            onPressed: habilitado ? onCobrar : null,
          ),
        ),
        if (vivo) ...[
          const SizedBox(width: 10),
          PulsoSecondaryButton(
            label: 'Retirar',
            danger: true,
            onPressed: habilitado ? onRetirar : null,
          ),
        ],
      ],
    );
  }
}

/// Paso de confirmación del cobro (M4b).
///
/// Existe porque este botón **mueve dinero**, y el resto del panel no. Enseña
/// las tres cosas que el operador necesita antes de decir que sí: cuánto, qué
/// periodo compra —encadenado desde el fin vigente, no desde hoy— y en qué caja
/// entra. La cuarta la dice el aviso: el ingreso no es de esta sede.
class _Confirmacion extends StatelessWidget {
  const _Confirmacion({
    required this.acceso,
    required this.precio,
    required this.cuentas,
    required this.cuentaId,
    required this.habilitado,
    required this.onCuenta,
    required this.onCancelar,
    required this.onCobrar,
  });

  final MultisedeAccessModel? acceso;
  final MultisedePriceModel? precio;
  final List<AccountModel> cuentas;
  final String? cuentaId;
  final bool habilitado;
  final ValueChanged<String?> onCuenta;
  final VoidCallback onCancelar;
  final VoidCallback onCobrar;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final formato = DateFormat('dd/MM/yyyy');
    // El mismo encadenado que aplica el servidor, para que la vista no prometa
    // un periodo distinto del que se va a cobrar. **La fecha de hoy la manda el
    // servidor**, no el reloj del equipo: es la fecha de negocio de la sede, y
    // deducirla aquí desplazaba el periodo un día a partir de las 17:00 en una
    // sede de la costa oeste (recorrido del 17-08-2026).
    final ahora = DateTime.now().toUtc();
    final hoy =
        acceso?.fechaNegocio ?? DateTime.utc(ahora.year, ahora.month, ahora.day);
    final cubriendo = acceso != null && acceso!.activo && acceso!.vigente
        ? acceso!.vigenteHasta
        : null;
    final desde = cubriendo != null && cubriendo.isAfter(hoy) ? cubriendo : hoy;
    final hasta = DateTime.utc(desde.year, desde.month + 1, desde.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PulsoLabel('Confirmar cobro'),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              (precio?.precio ?? 0).toStringAsFixed(2),
              style: TextStyle(
                fontFamily: PulsoFonts.display,
                fontSize: 31,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                height: 1,
                color: tokens.chalk,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'cubre ${formato.format(desde)} → ${formato.format(hasta)}',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: tokens.chalkDim,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const PulsoLabel('Caja donde entra el efectivo'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          initialValue: cuentaId,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Sin asignar · queda para revisar'),
            ),
            for (final cuenta in cuentas)
              DropdownMenuItem<String?>(
                value: cuenta.id,
                child: Text(cuenta.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: habilitado ? onCuenta : null,
        ),
        const SizedBox(height: 10),
        // El aviso que impide el error contable más caro (§7.10): quien cobra
        // no se queda el ingreso. Se dice aquí, antes de cobrar, y no en un
        // informe de fin de mes donde ya no se puede hacer nada.
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(border: Border.all(color: tokens.line)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.account_balance_outlined, size: 14, color: tokens.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'El efectivo entra en esta caja, pero el ingreso es de la '
                  'cadena: queda como saldo a su favor.',
                  style: TextStyle(color: tokens.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PulsoPrimaryButton(
                label: 'Cobrar',
                onPressed: habilitado && precio != null ? onCobrar : null,
              ),
            ),
            const SizedBox(width: 10),
            PulsoSecondaryButton(
              label: 'Cancelar',
              onPressed: habilitado ? onCancelar : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// Comprobante de lo que se acaba de cobrar.
///
/// Se queda en el panel en vez de desaparecer en un aviso flotante: es lo que
/// el operador lee en voz alta al socio, y lo que mira si el socio pregunta
/// «¿hasta cuándo me cubre?» treinta segundos después.
class _Comprobante extends StatelessWidget {
  const _Comprobante({required this.cobro, required this.tokens});

  final MultisedeCobroModel cobro;
  final PulsoTokens tokens;

  @override
  Widget build(BuildContext context) {
    final formato = DateFormat('dd/MM/yyyy');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.success.withValues(alpha: 0.07),
        border: Border.all(color: tokens.success),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.receipt_long_outlined, size: 15, color: tokens.success),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cobrado ${cobro.importe.toStringAsFixed(2)} · cubre '
                  '${formato.format(cobro.cubreDesde)} → '
                  '${formato.format(cobro.cubreHasta)}',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: tokens.chalk,
                  ),
                ),
                const SizedBox(height: 3),
                PulsoLabel(
                  'ingreso de ${cobro.ingresoDe.toLowerCase()} · '
                  'efectivo en ${cobro.cobradoEnGymId}',
                  color: tokens.muted2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
