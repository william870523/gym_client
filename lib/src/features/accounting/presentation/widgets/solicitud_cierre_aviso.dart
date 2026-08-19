import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/cierre_cadena_models.dart';
import '../state/cierre_cadena_providers.dart';

/// Alto reservado para el aviso, **separación incluida**. El panel de Tesorería
/// tiene altura fija y la calcula el padre, así que esto tiene que ser una
/// constante y no «lo que salga»: es el mismo motivo por el que la línea de
/// recargos condonados declara la suya. La separación va dentro para que, sin
/// solicitudes, el aviso no deje un hueco donde no hay nada.
// 124 = 24 de padding + 10 de separación + 32 de la cabecera (la manda el
// paso entre solicitudes, de 32) + 44 del botón, y 12 de holgura.
const double kSolicitudCierreAvisoAlto = 124;
// En compacto se apilan rango, detalle y botón: 32 + 18 + 16 + 44.
const double kSolicitudCierreAvisoAltoCompacto = 158;
const double _separacion = 10;

/// Por debajo de este ancho el aviso apila el rango y la acción.
const double _compactWidth = 620;

/// M5 — «Administración solicita cerrar el período X» (docs/MULTI_SEDE.md §6.2).
///
/// La solicitud la emite contabilidad central en el concentrador y baja a cada
/// instalación por sincronización. Hasta aquí llegaba y **no la veía nadie**:
/// vivía en la base y en la bandeja de avisos, que ninguna vista consumía.
///
/// Vive pegado al panel que **firma** el cierre, y no en un tablón aparte, por
/// una razón concreta: el aviso sin la acción al lado obliga a leer unas fechas,
/// recordarlas y volver a teclearlas en el selector, que es justo donde se
/// equivoca uno de día. «Cargar el período» las pone en el selector tal cual las
/// pidió administración.
class SolicitudCierreAviso extends ConsumerStatefulWidget {
  const SolicitudCierreAviso({super.key, required this.onCargarPeriodo});

  /// Recibe el rango tal y como lo pidió administración: primer día incluido y
  /// último día **incluido** (el servidor lo guarda con fin exclusivo).
  final void Function(DateTime desde, DateTime hastaIncluido) onCargarPeriodo;

  @override
  ConsumerState<SolicitudCierreAviso> createState() =>
      _SolicitudCierreAvisoState();
}

class _SolicitudCierreAvisoState extends ConsumerState<SolicitudCierreAviso> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    final solicitudes = ref.watch(solicitudesCierreProvider);
    final lista = solicitudes.asData?.value ?? const <SolicitudCierreModel>[];
    // Sin nada pedido, el aviso no ocupa sitio. Un panel vacío que dijera «no
    // hay solicitudes» sería ruido permanente en la vista de cierre.
    if (lista.isEmpty) return const SizedBox.shrink();

    final indice = _indice.clamp(0, lista.length - 1);
    final solicitud = lista[indice];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactWidth;
        return SizedBox(
          height: compact
              ? kSolicitudCierreAvisoAltoCompacto
              : kSolicitudCierreAvisoAlto,
          child: Padding(
            padding: const EdgeInsets.only(bottom: _separacion),
            child: _AvisoPanel(
              solicitud: solicitud,
              total: lista.length,
              indice: indice,
              compact: compact,
              onAnterior: indice == 0
                  ? null
                  : () => setState(() => _indice = indice - 1),
              onSiguiente: indice >= lista.length - 1
                  ? null
                  : () => setState(() => _indice = indice + 1),
              onCargar: () => widget.onCargarPeriodo(
                solicitud.fechaInicio,
                solicitud.ultimoDiaIncluido,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AvisoPanel extends StatelessWidget {
  const _AvisoPanel({
    required this.solicitud,
    required this.total,
    required this.indice,
    required this.compact,
    required this.onCargar,
    this.onAnterior,
    this.onSiguiente,
  });

  final SolicitudCierreModel solicitud;
  final int total;
  final int indice;
  final bool compact;
  final VoidCallback onCargar;
  final VoidCallback? onAnterior;
  final VoidCallback? onSiguiente;

  static final _dia = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final hoy = todayInZone(appClock.gymTimezone);
    final limite = solicitud.fechaLimite;
    final vencida = limite != null && limite.isBefore(hoy);
    final rango =
        '${_dia.format(solicitud.fechaInicio)} → ${_dia.format(solicitud.ultimoDiaIncluido)}';

    final cabecera = Row(
      children: [
        Container(width: 19, height: 2, color: tokens.warning),
        const SizedBox(width: 8),
        Expanded(
          child: PulsoLabel(
            'Administración solicita cerrar el período',
            color: tokens.warning,
          ),
        ),
        if (total > 1) ...[
          PulsoLabel('${indice + 1}/$total', color: tokens.muted2),
          const SizedBox(width: 6),
          _MiniPaso(icono: Icons.chevron_left, onTap: onAnterior),
          const SizedBox(width: 4),
          _MiniPaso(icono: Icons.chevron_right, onTap: onSiguiente),
        ] else
          PulsoLabel(solicitud.tipoPeriodo, color: tokens.muted2),
      ],
    );

    final fechas = Text(
      rango,
      style: TextStyle(
        fontFamily: PulsoFonts.mono,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: tokens.chalk,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    final detalle = Text(
      [
        if (solicitud.solicitadaPor != null) 'Pidió ${solicitud.solicitadaPor}',
        if (limite != null)
          vencida
              ? 'Plazo vencido el ${_dia.format(limite)}'
              : 'Plazo hasta ${_dia.format(limite)}',
        if (solicitud.nota != null) solicitud.nota!,
      ].join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        color: vencida ? tokens.danger : tokens.chalkDim,
      ),
    );

    final accion = PulsoSecondaryButton(
      label: 'Cargar el período',
      icon: Icons.event_available_outlined,
      onPressed: onCargar,
    );

    return PulsoPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      borderColor: vencida ? tokens.danger : tokens.warning,
      color: vencida ? tokens.dangerSoft : tokens.warningSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          cabecera,
          if (compact) ...[
            fechas,
            detalle,
            Row(children: [Expanded(child: accion)]),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [fechas, const SizedBox(height: 3), detalle],
                  ),
                ),
                const SizedBox(width: 12),
                accion,
              ],
            ),
        ],
      ),
    );
  }
}

/// Paso entre solicitudes. Mini-acción de fila: 32 px con su borde de 1 px.
class _MiniPaso extends StatelessWidget {
  const _MiniPaso({required this.icono, this.onTap});

  final IconData icono;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final activo = onTap != null;
    return MouseRegion(
      cursor: activo ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: activo ? tokens.lineStrong : tokens.line),
            color: tokens.surface,
          ),
          child: Icon(
            icono,
            size: 15,
            color: activo ? tokens.muted : tokens.muted2,
          ),
        ),
      ),
    );
  }
}
