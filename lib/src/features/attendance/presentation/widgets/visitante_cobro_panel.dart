import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../clients/data/models/multisede_access_model.dart';
import '../../../clients/data/repositories/multisede_access_repository.dart';
import '../../../financials/data/models/account_model.dart';
import '../../../payments/presentation/state/payment_notifier.dart';

/// Cobrar el plan de un visitante desde el mostrador (M4c,
/// docs/MULTI_SEDE.md §5.3).
///
/// Vive en el mostrador y no en el expediente porque el visitante **no tiene
/// expediente aquí**: su ficha está en su sede. Lo único que esta instalación
/// sabe de él es su copia de lectura y su cotización, y las dos se leen desde
/// aquí.
///
/// Enseña de dónde sale el total antes de cobrarlo —base, recargo y días de
/// atraso—, porque un socio que ve un importe distinto al de su sede pregunta
/// por qué, y quien atiende tiene que poder responder sin llamar a nadie.
class VisitanteCobroPanel extends ConsumerStatefulWidget {
  const VisitanteCobroPanel({
    super.key,
    required this.ci,
    required this.nombre,
    required this.onCerrar,
  });

  final String ci;
  final String nombre;
  final VoidCallback onCerrar;

  @override
  ConsumerState<VisitanteCobroPanel> createState() => _VisitanteCobroPanelState();
}

class _VisitanteCobroPanelState extends ConsumerState<VisitanteCobroPanel> {
  bool _trabajando = false;
  String? _motivoDelServidor;
  String? _cuentaId;
  String? _tipoPagoId;
  CobroCruzadoModel? _comprobante;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final cotizacion = ref.watch(cotizacionVisitaProvider(widget.ci));
    final cuentas = ref.watch(accountsProvider).asData?.value ?? const <AccountModel>[];
    final tipos = ref.watch(paymentTypesProvider).asData?.value ?? const [];

    return PulsoPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: PulsoLabel('Cobrar a ${widget.nombre}')),
              _MiniCerrar(onTap: widget.onCerrar, color: tokens.muted2),
            ],
          ),
          const SizedBox(height: 12),
          cotizacion.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (_, _) => Text(
              'No se pudo leer qué cobrarle.',
              style: TextStyle(color: tokens.danger, fontSize: 12),
            ),
            data: (respuesta) => respuesta.cobrable
                ? _Desglose(c: respuesta.cotizacion!, tokens: tokens)
                : Text(
                    // El servidor explica por qué —sin plus, sin cotización— y
                    // ese texto es lo único accionable en el mostrador.
                    respuesta.motivo ?? 'No se le puede cobrar aquí.',
                    style: TextStyle(color: tokens.warning, fontSize: 12),
                  ),
          ),
          if (cotizacion.asData?.value.cobrable == true && _comprobante == null) ...[
            const SizedBox(height: 14),
            const PulsoLabel('Método de pago'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String?>(
              initialValue: _tipoPagoId,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: [
                for (final tipo in tipos)
                  DropdownMenuItem<String?>(
                    value: tipo.id,
                    child: Text(tipo.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _trabajando ? null : (v) => setState(() => _tipoPagoId = v),
            ),
            const SizedBox(height: 10),
            const PulsoLabel('Caja donde entra el efectivo'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String?>(
              initialValue: _cuentaId,
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
              onChanged: _trabajando ? null : (v) => setState(() => _cuentaId = v),
            ),
            const SizedBox(height: 10),
            _AvisoIngresoAjeno(
              sede: cotizacion.asData!.value.cotizacion!.gymIdOrigen,
              tokens: tokens,
            ),
            const SizedBox(height: 12),
            PulsoPrimaryButton(
              label: 'Cobrar',
              // Sin método no se cobra: el detalle del cobro dice CÓMO se pagó
              // y el servidor lo exige. Se bloquea aquí para no mandar una
              // petición que ya se sabe que va a fallar.
              onPressed: !_trabajando && _tipoPagoId != null ? _cobrar : null,
            ),
          ],
          if (_motivoDelServidor != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tokens.danger.withValues(alpha: 0.08),
                border: Border.all(color: tokens.danger),
              ),
              child: Text(
                _motivoDelServidor!,
                style: TextStyle(color: tokens.danger, fontSize: 12),
              ),
            ),
          ],
          if (_comprobante != null) ...[
            const SizedBox(height: 12),
            _Comprobante(cobro: _comprobante!, tokens: tokens),
          ],
        ],
      ),
    );
  }

  Future<void> _cobrar() async {
    setState(() {
      _trabajando = true;
      _motivoDelServidor = null;
    });
    try {
      final cobro = await ref
          .read(multisedeAccessRepositoryProvider)
          .cobrarVisitante(widget.ci, tipoPagoId: _tipoPagoId!, cuentaId: _cuentaId);
      ref.invalidate(cotizacionVisitaProvider(widget.ci));
      if (mounted) setState(() => _comprobante = cobro);
    } catch (error) {
      if (mounted) {
        setState(
          () => _motivoDelServidor =
              error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }
}

/// De dónde sale el total. Se enseña siempre, no solo cuando hay recargo: un
/// importe sin desglose obliga a quien atiende a defenderlo de memoria.
class _Desglose extends StatelessWidget {
  const _Desglose({required this.c, required this.tokens});

  final CotizacionVisitaModel c;
  final PulsoTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              c.total.toStringAsFixed(2),
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
                child: PulsoLabel(
                  c.cuotaNumero == null
                      ? c.planNombre
                      : '${c.planNombre} · cuota ${c.cuotaNumero}',
                  color: tokens.muted2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _Linea(
          etiqueta: 'Plan',
          valor: c.base.toStringAsFixed(2),
          tokens: tokens,
        ),
        if (c.recargoMora > 0)
          _Linea(
            etiqueta: 'Recargo · ${c.diasAtraso} d de atraso',
            valor: c.recargoMora.toStringAsFixed(2),
            tokens: tokens,
            resaltado: true,
          ),
        const SizedBox(height: 6),
        // La antigüedad de la foto, dicha sin adornos. Una cotización vieja
        // puede no reflejar que el socio ya pagó en su sede, y quien cobra
        // tiene derecho a saberlo antes de cobrar.
        PulsoLabel(
          c.antiguedadDias == 0
              ? 'Precio de su sede, de hoy'
              : 'Precio de su sede, de hace ${c.antiguedadDias} d',
          color: c.antiguedadDias > 30 ? tokens.warning : tokens.muted2,
        ),
      ],
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({
    required this.etiqueta,
    required this.valor,
    required this.tokens,
    this.resaltado = false,
  });

  final String etiqueta;
  final String valor;
  final PulsoTokens tokens;
  final bool resaltado;

  @override
  Widget build(BuildContext context) {
    final color = resaltado ? tokens.warning : tokens.chalkDim;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(etiqueta, style: TextStyle(color: color, fontSize: 12)),
          ),
          Text(
            valor,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 12,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// El aviso que impide el error contable más caro (§7.10), dicho antes de
/// cobrar y no en un informe de fin de mes.
class _AvisoIngresoAjeno extends StatelessWidget {
  const _AvisoIngresoAjeno({required this.sede, required this.tokens});

  final String sede;
  final PulsoTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(border: Border.all(color: tokens.line)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.compare_arrows, size: 14, color: tokens.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'El efectivo entra en esta caja, pero el ingreso es de $sede: '
              'queda como saldo a su favor.',
              style: TextStyle(color: tokens.muted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _Comprobante extends StatelessWidget {
  const _Comprobante({required this.cobro, required this.tokens});

  final CobroCruzadoModel cobro;
  final PulsoTokens tokens;

  @override
  Widget build(BuildContext context) {
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
                  'Cobrado ${cobro.total.toStringAsFixed(2)} · ${cobro.planCodigo}',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: tokens.chalk,
                  ),
                ),
                const SizedBox(height: 3),
                PulsoLabel(
                  'ingreso de ${cobro.ingresoDe} · efectivo en ${cobro.cobradoEnGymId}',
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

class _MiniCerrar extends StatelessWidget {
  const _MiniCerrar({required this.onTap, required this.color});

  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Icon(Icons.close, size: 16, color: color),
      ),
    );
  }
}
