import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_charts.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../financials/data/models/currency_model.dart';
import '../../data/models/member_statistics.dart' show NamedCount, StatRate;

/// Piezas que comparten las vistas de estadística.
///
/// Están aquí y no copiadas en cada vista porque la disciplina del plan
/// —«toda tasa lleva su denominador», «la zona de agrupación siempre visible»,
/// «muestra baja por debajo de cinco»— solo se sostiene si hay **un** sitio
/// donde se decide cómo se dibuja eso.

String statisticsErrorMessage(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == 404) {
      return 'La estadística no está disponible en el servidor. '
          'Reintenta después de actualizar o reiniciar el servicio remoto.';
    }
    if (status == 401 || status == 403) {
      return 'La sesión ya no permite consultar esta estadística. '
          'Vuelve a iniciar sesión.';
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'No se pudo conectar con el servicio de estadísticas. '
          'Comprueba la conexión y vuelve a intentarlo.';
    }
    final data = error.response?.data;
    if (data is Map) {
      final message = data['error'] ?? data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
  }
  return 'Ocurrió un problema al calcular la estadística. Vuelve a intentarlo.';
}

/// Membrete de la vista: etiqueta, título con el punto en acento y entradilla.
class StatsHeader extends StatelessWidget {
  const StatsHeader({
    super.key,
    required this.etiqueta,
    required this.titulo,
    required this.descripcion,
  });

  final String etiqueta;
  final String titulo;
  final String descripcion;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PulsoLabel(etiqueta),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            text: titulo,
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
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            descripcion,
            style: TextStyle(fontSize: 12, height: 1.5, color: tokens.muted),
          ),
        ),
      ],
    );
  }
}

class StatsPanelTitle extends StatelessWidget {
  const StatsPanelTitle(this.texto, {super.key});

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

class StatsSubLabel extends StatelessWidget {
  const StatsSubLabel(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) => PulsoLabel(texto);
}

/// Cifra con su rótulo debajo. La cifra en monoespaciada para que columnas de
/// números se lean alineadas.
class StatsFact extends StatelessWidget {
  const StatsFact(this.etiqueta, this.valor, {super.key, this.alerta = false});

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

/// Una tasa como manda el plan: porcentaje, **denominador siempre**, y aviso
/// cuando la muestra es demasiado pequeña para leerla como tendencia.
class StatsRate extends StatelessWidget {
  const StatsRate({
    super.key,
    required this.tasa,
    required this.titulo,
    required this.tokens,
  });

  final StatRate tasa;
  final String titulo;
  final PulsoTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tasa.etiqueta,
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
          '$titulo · ${tasa.detalle}',
          style: TextStyle(fontSize: 11, color: tokens.muted),
        ),
        if (tasa.muestraBaja) ...[
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
    );
  }
}

/// Pie con la zona en que el servidor agrupó días y horas. Sin ella, «viene por
/// la mañana» no significa nada comprobable.
class StatsPie extends StatelessWidget {
  const StatsPie({
    super.key,
    required this.zona,
    required this.diaNegocio,
    required this.tokens,
  });

  final String zona;
  final String diaNegocio;
  final PulsoTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Días y horas agrupados en $zona · día de negocio $diaNegocio',
      style: TextStyle(
        fontFamily: PulsoFonts.mono,
        fontSize: 10,
        color: tokens.muted,
      ),
    );
  }
}

class StatsChipOption {
  const StatsChipOption({
    required this.id,
    required this.texto,
    this.nota,
    this.atenuado = false,
  });

  final String id;
  final String texto;
  final String? nota;

  /// Se dibuja apagado —dado de baja, inactivo— pero sigue pudiéndose mirar:
  /// la estadística de lo retirado es justamente la que explica por qué.
  final bool atenuado;
}

/// Selector de entidad. Con pocos elementos —planes, entrenadores— una lista de
/// fichas pulsables es más rápida que un buscador: se ven todas de un vistazo.
class StatsChipSelector extends StatelessWidget {
  const StatsChipSelector({
    super.key,
    required this.opciones,
    required this.seleccionado,
    required this.onSelect,
    required this.vacio,
  });

  final List<StatsChipOption> opciones;
  final String? seleccionado;
  final ValueChanged<String> onSelect;
  final String vacio;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.all(12),
      child: opciones.isEmpty
          ? Text(vacio, style: TextStyle(fontSize: 12, color: tokens.muted))
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final opcion in opciones)
                  _Ficha(
                    opcion: opcion,
                    activa: opcion.id == seleccionado,
                    onTap: () => onSelect(opcion.id),
                  ),
              ],
            ),
    );
  }
}

class _Ficha extends StatelessWidget {
  const _Ficha({
    required this.opcion,
    required this.activa,
    required this.onTap,
  });

  final StatsChipOption opcion;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: activa ? tokens.accent : tokens.line),
          color: activa ? tokens.accent.withValues(alpha: 0.12) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              opcion.texto,
              style: TextStyle(
                fontSize: 12,
                fontWeight: activa ? FontWeight.w700 : FontWeight.w400,
                color: opcion.atenuado ? tokens.muted : tokens.chalk,
              ),
            ),
            if (opcion.nota != null)
              Text(
                opcion.atenuado ? '${opcion.nota} · inactivo' : opcion.nota!,
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

// --- Conversiones menudas ----------------------------------------------------

List<PulsoChartDato> datosBarra(List<NamedCount> conteos) => [
  for (final c in conteos)
    PulsoChartDato(etiqueta: c.etiqueta, valor: c.total.toDouble()),
];

List<PulsoChartDato> datosDona(List<NamedCount> conteos) => datosBarra(conteos);

/// `2026-07` → `jul`. El año se sobreentiende en una serie continua.
String mesCorto(String mes) {
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

/// Nombre legible de la moneda. El servidor manda el identificador; enseñar el
/// UUID recortado, como se hacía en la vista del socio, no dice nada a nadie.
String nombreMoneda(List<CurrencyModel> monedas, String monedaId) {
  for (final moneda in monedas) {
    if (moneda.id == monedaId) {
      return moneda.code.isEmpty
          ? moneda.name
          : '${moneda.code} · ${moneda.name}';
    }
  }
  // Sin catálogo cargado se dice que falta, en vez de fingir un nombre.
  return 'moneda no identificada';
}
