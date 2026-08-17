import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../auth/presentation/state/auth_notifier.dart';
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
            data: (fila) => _Acciones(
              acceso: fila,
              habilitado: puedeEscribir && !_trabajando,
              onMarcar: () => _operar(
                () => ref
                    .read(multisedeAccessRepositoryProvider)
                    .marcar(widget.ci),
              ),
              onRetirar: () => _operar(
                () => ref
                    .read(multisedeAccessRepositoryProvider)
                    .retirar(widget.ci),
              ),
            ),
          ),
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
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: PulsoLabel(
                // `vigente_hasta` es exclusiva: el día que figura ya no cubre.
                acceso!.vigente ? 'cubre hasta ese día, sin incluirlo' : 'ya no cubre',
                color: tokens.muted2,
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
    required this.onMarcar,
    required this.onRetirar,
  });

  final MultisedeAccessModel? acceso;
  final bool habilitado;
  final VoidCallback onMarcar;
  final VoidCallback onRetirar;

  @override
  Widget build(BuildContext context) {
    final vivo = acceso != null && acceso!.activo;
    return Row(
      children: [
        Expanded(
          child: PulsoPrimaryButton(
            label: vivo ? 'Renovar un mes' : 'Activar acceso',
            onPressed: habilitado ? onMarcar : null,
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
