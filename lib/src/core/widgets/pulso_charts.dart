import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/pulso/pulso_theme.dart';
import '../theme/pulso/pulso_tokens.dart';

/// Primitivas de gráfico del sistema PULSO.
///
/// Se pintan a mano en vez de traer una librería a propósito: las de terceros
/// llegan con su propia estética —esquinas redondeadas, animaciones, paleta
/// Material— que pelea con un sistema de borde de 1 px y esquina recta, y
/// obligarían a mantener dos lenguajes visuales. Lo que hace falta aquí es
/// simple: barras, dona, línea, mapa de calor y una chispa de fila.
///
/// Reglas que estas primitivas imponen por construcción
/// (docs/PLAN_ESTADISTICAS.md §8):
///
///  - **la cifra siempre está**, no solo la forma: una barra sin su número
///    obliga a estimar a ojo, y estimar a ojo es exactamente lo que la
///    estadística viene a evitar;
///  - **el acento no lo colorea todo**: se reserva para la serie principal, y
///    el resto usa una escala neutra derivada de los tokens, para que éxito,
///    advertencia y peligro conserven su significado;
///  - **sin datos se dice que no hay datos**, en vez de dibujar un lienzo vacío
///    que parece un fallo de carga.

/// Escala categórica derivada de los tokens activos.
///
/// La primera es el acento —la serie que manda— y las demás se alejan hacia el
/// tono apagado. Así funciona igual en Arcilla, Medianoche y Hierro/oro, y en
/// claro y en oscuro, sin colores inventados fuera del sistema.
List<Color> pulsoSerieColores(PulsoTokens tokens, int cantidad) {
  if (cantidad <= 0) return const [];
  final extremo = tokens.isDark ? tokens.muted : tokens.chalkDim;
  return List<Color>.generate(cantidad, (indice) {
    if (cantidad == 1) return tokens.accent;
    final t = indice / (cantidad - 1);
    // Se detiene antes del extremo para que la última serie siga siendo
    // legible sobre el fondo en lugar de fundirse con él.
    return Color.lerp(tokens.accent, extremo, t * 0.78) ?? tokens.accent;
  });
}

/// Un dato con nombre para barras, dona y mapa de calor.
@immutable
class PulsoChartDato {
  const PulsoChartDato({
    required this.etiqueta,
    required this.valor,
    this.color,
    this.nota,
  });

  final String etiqueta;
  final double valor;

  /// Color forzado. Sin él se usa la escala categórica.
  final Color? color;

  /// Texto secundario a la derecha de la cifra (p. ej. «38 %»).
  final String? nota;
}

/// Aviso homogéneo de «aquí no hay nada que enseñar».
class PulsoChartVacio extends StatelessWidget {
  const PulsoChartVacio({super.key, required this.mensaje, this.alto = 120});

  final String mensaje;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return SizedBox(
      height: alto,
      child: Center(
        child: Text(
          mensaje,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, height: 1.4, color: tokens.muted),
        ),
      ),
    );
  }
}

// --- Barras horizontales -----------------------------------------------------

/// Ranking. Barra horizontal con la etiqueta a la izquierda y la cifra a la
/// derecha, siempre visible.
class PulsoBarras extends StatelessWidget {
  const PulsoBarras({
    super.key,
    required this.datos,
    this.maximoVisible,
    this.mensajeVacio = 'Sin datos todavía.',
    this.anchoEtiqueta = 96,
    this.resaltarPrimero = true,
  });

  final List<PulsoChartDato> datos;

  /// Tope de la escala. Sin él, el mayor valor ocupa el ancho completo.
  final double? maximoVisible;
  final String mensajeVacio;
  final double anchoEtiqueta;

  /// El primero en acento; el resto en la escala neutra.
  final bool resaltarPrimero;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    if (datos.isEmpty) return PulsoChartVacio(mensaje: mensajeVacio, alto: 80);

    final maximo = maximoVisible ??
        datos.fold<double>(0, (mayor, d) => math.max(mayor, d.valor));
    final colores = pulsoSerieColores(tokens, datos.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < datos.length; i += 1)
          Padding(
            padding: EdgeInsets.only(bottom: i == datos.length - 1 ? 0 : 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: anchoEtiqueta,
                  child: Text(
                    datos[i].etiqueta,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: tokens.chalk),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _BarraSimple(
                    fraccion: maximo <= 0 ? 0 : datos[i].valor / maximo,
                    color: datos[i].color ??
                        (resaltarPrimero && i == 0 ? tokens.accent : colores[i]),
                    fondo: tokens.line,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _cifra(datos[i].valor),
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tokens.chalk,
                  ),
                ),
                if (datos[i].nota != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    datos[i].nota!,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 10,
                      color: tokens.muted,
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

class _BarraSimple extends StatelessWidget {
  const _BarraSimple({
    required this.fraccion,
    required this.color,
    required this.fondo,
  });

  final double fraccion;
  final Color color;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: LayoutBuilder(
        builder: (context, restricciones) {
          final ancho = restricciones.maxWidth * fraccion.clamp(0.0, 1.0);
          return Stack(
            children: [
              Container(color: fondo, height: 12),
              // Un valor mayor que cero siempre deja marca: una barra de medio
              // píxel que desaparece se lee como un cero que no es.
              Container(
                width: fraccion > 0 ? math.max(ancho, 2) : 0,
                height: 12,
                color: color,
              ),
            ],
          );
        },
      ),
    );
  }
}

// --- Dona --------------------------------------------------------------------

/// Composición. Solo para pocas categorías: por encima de seis, barras.
class PulsoDona extends StatelessWidget {
  const PulsoDona({
    super.key,
    required this.datos,
    this.diametro = 132,
    this.grosor = 18,
    this.mensajeVacio = 'Sin datos todavía.',
    this.centroTitulo,
    this.centroValor,
  });

  final List<PulsoChartDato> datos;
  final double diametro;
  final double grosor;
  final String mensajeVacio;
  final String? centroTitulo;
  final String? centroValor;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final utiles = datos.where((d) => d.valor > 0).toList();
    if (utiles.isEmpty) {
      return PulsoChartVacio(mensaje: mensajeVacio, alto: diametro);
    }

    final total = utiles.fold<double>(0, (suma, d) => suma + d.valor);
    final colores = pulsoSerieColores(tokens, utiles.length);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: diametro,
          height: diametro,
          child: CustomPaint(
            painter: _DonaPainter(
              valores: [for (final d in utiles) d.valor],
              colores: [
                for (var i = 0; i < utiles.length; i += 1)
                  utiles[i].color ?? colores[i],
              ],
              grosor: grosor,
              separacion: tokens.surface,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (centroValor != null)
                    Text(
                      centroValor!,
                      style: TextStyle(
                        fontFamily: PulsoFonts.display,
                        fontSize: 22,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: tokens.chalk,
                      ),
                    ),
                  if (centroTitulo != null)
                    Text(
                      centroTitulo!.toUpperCase(),
                      style: TextStyle(
                        fontFamily: PulsoFonts.display,
                        fontSize: 10,
                        letterSpacing: 0.6,
                        color: tokens.muted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < utiles.length; i += 1)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == utiles.length - 1 ? 0 : 7,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        color: utiles[i].color ?? colores[i],
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          utiles[i].etiqueta,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: tokens.chalk),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // La cifra Y el porcentaje: el porcentaje solo esconde el
                      // tamaño de la muestra.
                      Text(
                        '${_cifra(utiles[i].valor)}  '
                        '${(utiles[i].valor * 100 / total).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 10,
                          color: tokens.muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonaPainter extends CustomPainter {
  _DonaPainter({
    required this.valores,
    required this.colores,
    required this.grosor,
    required this.separacion,
  });

  final List<double> valores;
  final List<Color> colores;
  final double grosor;
  final Color separacion;

  @override
  void paint(Canvas canvas, Size size) {
    final total = valores.fold<double>(0, (suma, v) => suma + v);
    if (total <= 0) return;
    final rect = Rect.fromLTWH(
      grosor / 2,
      grosor / 2,
      size.width - grosor,
      size.height - grosor,
    );
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor;

    // Se empieza arriba y se avanza en el sentido del reloj: es como se lee.
    var inicio = -math.pi / 2;
    for (var i = 0; i < valores.length; i += 1) {
      final barrido = (valores[i] / total) * math.pi * 2;
      pincel.color = colores[i];
      canvas.drawArc(rect, inicio, barrido, false, pincel);
      inicio += barrido;
    }

    // Filete de separación entre porciones, solo si hay más de una.
    if (valores.length > 1) {
      final corte = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = separacion;
      var angulo = -math.pi / 2;
      final centro = Offset(size.width / 2, size.height / 2);
      final radioExterno = size.width / 2;
      final radioInterno = radioExterno - grosor;
      for (final valor in valores) {
        canvas.drawLine(
          centro + Offset(math.cos(angulo), math.sin(angulo)) * radioInterno,
          centro + Offset(math.cos(angulo), math.sin(angulo)) * radioExterno,
          corte,
        );
        angulo += (valor / total) * math.pi * 2;
      }
    }
  }

  @override
  bool shouldRepaint(_DonaPainter anterior) =>
      anterior.valores != valores || anterior.colores != colores;
}

// --- Línea / área ------------------------------------------------------------

/// Tendencia temporal. Punto por período, con el eje de etiquetas debajo.
class PulsoLinea extends StatelessWidget {
  const PulsoLinea({
    super.key,
    required this.puntos,
    this.alto = 140,
    this.mensajeVacio = 'Sin serie todavía.',
    this.color,
    this.mostrarPuntos = true,
  });

  /// Pares etiqueta/valor en orden cronológico.
  final List<PulsoChartDato> puntos;
  final double alto;
  final String mensajeVacio;
  final Color? color;
  final bool mostrarPuntos;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    if (puntos.isEmpty) return PulsoChartVacio(mensaje: mensajeVacio, alto: alto);
    // Un solo punto no es una tendencia: se dice, en vez de dibujar una recta
    // que sugiere una evolución inexistente.
    if (puntos.length == 1) {
      return SizedBox(
        height: alto,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _cifra(puntos.first.valor),
                style: TextStyle(
                  fontFamily: PulsoFonts.display,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: tokens.chalk,
                ),
              ),
              Text(
                '${puntos.first.etiqueta} · un solo período, todavía no hay '
                'tendencia',
                style: TextStyle(fontSize: 10, color: tokens.muted),
              ),
            ],
          ),
        ),
      );
    }

    final maximo = puntos.fold<double>(0, (m, p) => math.max(m, p.valor));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: alto,
          child: CustomPaint(
            painter: _LineaPainter(
              valores: [for (final p in puntos) p.valor],
              maximo: maximo,
              color: color ?? tokens.accent,
              rejilla: tokens.line,
              relleno: (color ?? tokens.accent).withValues(alpha: 0.14),
              mostrarPuntos: mostrarPuntos,
              fondoPunto: tokens.surface,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < puntos.length; i += 1)
              Expanded(
                child: Text(
                  puntos[i].etiqueta,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 9,
                    color: tokens.muted,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LineaPainter extends CustomPainter {
  _LineaPainter({
    required this.valores,
    required this.maximo,
    required this.color,
    required this.rejilla,
    required this.relleno,
    required this.mostrarPuntos,
    required this.fondoPunto,
  });

  final List<double> valores;
  final double maximo;
  final Color color;
  final Color rejilla;
  final Color relleno;
  final bool mostrarPuntos;
  final Color fondoPunto;

  @override
  void paint(Canvas canvas, Size size) {
    if (valores.length < 2) return;
    const margen = 6.0;
    final alto = size.height - margen * 2;
    final paso = size.width / (valores.length - 1);
    // Con todos los valores iguales (incluido todo a cero) la escala se fija a
    // uno: así la línea sale plana a media altura en vez de dividir por cero.
    final tope = maximo <= 0 ? 1.0 : maximo;

    // Rejilla horizontal: tres líneas bastan para dar referencia sin ruido.
    final lapizRejilla = Paint()
      ..color = rejilla
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i += 1) {
      final y = margen + (alto / 2) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), lapizRejilla);
    }

    final camino = Path();
    final area = Path();
    for (var i = 0; i < valores.length; i += 1) {
      final x = paso * i;
      final y = margen + alto - (valores[i] / tope) * alto;
      if (i == 0) {
        camino.moveTo(x, y);
        area.moveTo(x, size.height);
        area.lineTo(x, y);
      } else {
        camino.lineTo(x, y);
        area.lineTo(x, y);
      }
    }
    area.lineTo(size.width, size.height);
    area.close();

    canvas.drawPath(area, Paint()..color = relleno);
    canvas.drawPath(
      camino,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    if (mostrarPuntos) {
      final centro = Paint()..color = fondoPunto;
      final borde = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (var i = 0; i < valores.length; i += 1) {
        final x = paso * i;
        final y = margen + alto - (valores[i] / tope) * alto;
        canvas.drawCircle(Offset(x, y), 3, centro);
        canvas.drawCircle(Offset(x, y), 3, borde);
      }
    }
  }

  @override
  bool shouldRepaint(_LineaPainter anterior) =>
      anterior.valores != valores || anterior.maximo != maximo;
}

// --- Chispa de fila ----------------------------------------------------------

/// Tendencia mínima para meter en una fila de tabla o junto a una métrica.
class PulsoChispa extends StatelessWidget {
  const PulsoChispa({
    super.key,
    required this.valores,
    this.ancho = 64,
    this.alto = 18,
    this.color,
  });

  final List<double> valores;
  final double ancho;
  final double alto;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    if (valores.length < 2) return SizedBox(width: ancho, height: alto);
    return SizedBox(
      width: ancho,
      height: alto,
      child: CustomPaint(
        painter: _LineaPainter(
          valores: valores,
          maximo: valores.reduce(math.max),
          color: color ?? tokens.accent,
          rejilla: Colors.transparent,
          relleno: (color ?? tokens.accent).withValues(alpha: 0.12),
          mostrarPuntos: false,
          fondoPunto: tokens.surface,
        ),
      ),
    );
  }
}

// --- Flujo bidireccional -----------------------------------------------------

/// Una fila del flujo: cuántos llegan de un sitio y cuántos se van a él.
@immutable
class PulsoFlujoDato {
  const PulsoFlujoDato({
    required this.etiqueta,
    this.entran = 0,
    this.salen = 0,
  });

  final String etiqueta;

  /// Los que **vienen de** aquí. Se dibujan hacia la derecha.
  final int entran;

  /// Los que **se van a** aquí. Se dibujan hacia la izquierda.
  final int salen;

  int get neto => entran - salen;
  int get movimiento => entran + salen;
}

/// Movilidad entre categorías: entradas y salidas sobre un eje central.
///
/// Existe porque ninguna otra primitiva sabe dibujar **un dato con signo**. Con
/// dos gráficos de barras separados —uno de entradas y otro de salidas— hay que
/// comparar de memoria entre dos escalas distintas, y la pregunta que importa
/// («¿este plan capta o alimenta a los demás?») se responde precisamente
/// restando. Aquí las dos mitades comparten escala, así que el desequilibrio se
/// ve sin leer una sola cifra.
///
/// Las dos direcciones no compiten por el color: entrar y salir no son «bueno»
/// y «malo» —quien sube de plan es una buena noticia para el gimnasio aunque el
/// plan de origen la registre como salida—, así que se distinguen por posición
/// y por tono, no por semáforo.
class PulsoFlujo extends StatelessWidget {
  const PulsoFlujo({
    super.key,
    required this.datos,
    this.etiquetaEntran = 'vienen de',
    this.etiquetaSalen = 'se van a',
    this.mensajeVacio = 'Sin cambios de plan todavía.',
    this.anchoEtiqueta = 116,
  });

  final List<PulsoFlujoDato> datos;
  final String etiquetaEntran;
  final String etiquetaSalen;
  final String mensajeVacio;
  final double anchoEtiqueta;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final utiles = datos.where((d) => d.movimiento > 0).toList()
      ..sort((a, b) => b.movimiento.compareTo(a.movimiento));
    if (utiles.isEmpty) return PulsoChartVacio(mensaje: mensajeVacio, alto: 110);

    // Escala común a las dos mitades: si cada lado se normalizara por su cuenta,
    // tres salidas parecerían tanto como treinta entradas.
    final maximo = utiles.fold<int>(
      0,
      (mayor, d) => math.max(mayor, math.max(d.entran, d.salen)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(width: anchoEtiqueta),
            Expanded(
              child: Text(
                etiquetaSalen.toUpperCase(),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: PulsoFonts.display,
                  fontSize: 9,
                  letterSpacing: 0.7,
                  color: tokens.muted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                etiquetaEntran.toUpperCase(),
                style: TextStyle(
                  fontFamily: PulsoFonts.display,
                  fontSize: 9,
                  letterSpacing: 0.7,
                  color: tokens.muted,
                ),
              ),
            ),
            const SizedBox(width: 42),
          ],
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < utiles.length; i += 1)
          Padding(
            padding: EdgeInsets.only(bottom: i == utiles.length - 1 ? 0 : 7),
            child: _FilaFlujo(
              dato: utiles[i],
              maximo: maximo,
              anchoEtiqueta: anchoEtiqueta,
              tokens: tokens,
            ),
          ),
      ],
    );
  }
}

class _FilaFlujo extends StatelessWidget {
  const _FilaFlujo({
    required this.dato,
    required this.maximo,
    required this.anchoEtiqueta,
    required this.tokens,
  });

  final PulsoFlujoDato dato;
  final int maximo;
  final double anchoEtiqueta;
  final PulsoTokens tokens;

  @override
  Widget build(BuildContext context) {
    final colorEntran = tokens.accent;
    // La salida en tono apagado: es información, no una alarma.
    final colorSalen = tokens.isDark ? tokens.muted : tokens.chalkDim;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: anchoEtiqueta,
          child: Text(
            dato.etiqueta,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: tokens.chalk),
          ),
        ),
        Expanded(
          child: _MediaBarra(
            valor: dato.salen,
            maximo: maximo,
            color: colorSalen,
            fondo: tokens.line,
            haciaLaIzquierda: true,
            tokens: tokens,
          ),
        ),
        // El eje: la referencia contra la que se lee el desequilibrio.
        Container(width: 1, height: 18, color: tokens.chalk),
        Expanded(
          child: _MediaBarra(
            valor: dato.entran,
            maximo: maximo,
            color: colorEntran,
            fondo: tokens.line,
            haciaLaIzquierda: false,
            tokens: tokens,
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            dato.neto == 0
                ? '±0'
                : '${dato.neto > 0 ? '+' : ''}${dato.neto}',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: dato.neto == 0 ? tokens.muted : tokens.chalk,
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaBarra extends StatelessWidget {
  const _MediaBarra({
    required this.valor,
    required this.maximo,
    required this.color,
    required this.fondo,
    required this.haciaLaIzquierda,
    required this.tokens,
  });

  final int valor;
  final int maximo;
  final Color color;
  final Color fondo;
  final bool haciaLaIzquierda;
  final PulsoTokens tokens;

  @override
  Widget build(BuildContext context) {
    final fraccion = maximo <= 0 ? 0.0 : valor / maximo;
    return LayoutBuilder(
      builder: (context, restricciones) {
        // Se deja hueco para la cifra fuera de la barra; sin él, un valor de
        // una cifra sobre barra corta queda ilegible.
        final disponible = math.max(0.0, restricciones.maxWidth - 22);
        final ancho = valor > 0
            ? math.max(disponible * fraccion.clamp(0.0, 1.0), 2.0)
            : 0.0;
        final barra = Container(width: ancho, height: 14, color: color);
        final cifra = SizedBox(
          width: 22,
          child: Text(
            valor == 0 ? '' : '$valor',
            textAlign: haciaLaIzquierda ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 10,
              color: tokens.muted,
            ),
          ),
        );
        return Row(
          mainAxisAlignment: haciaLaIzquierda
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: haciaLaIzquierda ? [cifra, barra] : [barra, cifra],
        );
      },
    );
  }
}

// --- Mapa de calor -----------------------------------------------------------

/// Rejilla de intensidad, pensada para franja × día de la semana.
class PulsoMapaCalor extends StatelessWidget {
  const PulsoMapaCalor({
    super.key,
    required this.filas,
    required this.columnas,
    required this.valores,
    this.mensajeVacio = 'Sin datos todavía.',
    this.altoCelda = 22,
  });

  final List<String> filas;
  final List<String> columnas;

  /// `valores[fila][columna]`.
  final List<List<double>> valores;
  final String mensajeVacio;
  final double altoCelda;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final maximo = valores.fold<double>(
      0,
      (mayor, fila) => math.max(mayor, fila.fold<double>(0, math.max)),
    );
    if (maximo <= 0) return PulsoChartVacio(mensaje: mensajeVacio, alto: 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(width: 64),
            for (final columna in columnas)
              Expanded(
                child: Text(
                  columna,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: PulsoFonts.display,
                    fontSize: 10,
                    letterSpacing: 0.4,
                    color: tokens.muted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var f = 0; f < filas.length; f += 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    filas[f],
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: tokens.chalk),
                  ),
                ),
                for (var c = 0; c < columnas.length; c += 1)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: _Celda(
                        valor: valores[f][c],
                        maximo: maximo,
                        alto: altoCelda,
                        tokens: tokens,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Celda extends StatelessWidget {
  const _Celda({
    required this.valor,
    required this.maximo,
    required this.alto,
    required this.tokens,
  });

  final double valor;
  final double maximo;
  final double alto;
  final PulsoTokens tokens;

  @override
  Widget build(BuildContext context) {
    final intensidad = maximo <= 0 ? 0.0 : (valor / maximo).clamp(0.0, 1.0);
    // El cero se dibuja como hueco con borde, no como color pálido: así se
    // distingue de «poco» de un vistazo.
    return Container(
      height: alto,
      decoration: BoxDecoration(
        color: valor <= 0
            ? Colors.transparent
            : tokens.accent.withValues(alpha: 0.15 + intensidad * 0.75),
        border: Border.all(color: tokens.line),
      ),
      alignment: Alignment.center,
      child: Text(
        valor <= 0 ? '' : _cifra(valor),
        style: TextStyle(
          fontFamily: PulsoFonts.mono,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: intensidad > 0.55 ? tokens.accentInk : tokens.chalk,
        ),
      ),
    );
  }
}

// --- Utilidades --------------------------------------------------------------

/// Cifra compacta: sin decimales cuando es entera, con uno cuando no.
String _cifra(double valor) {
  if (valor == valor.roundToDouble()) return valor.toStringAsFixed(0);
  return valor.toStringAsFixed(1);
}
