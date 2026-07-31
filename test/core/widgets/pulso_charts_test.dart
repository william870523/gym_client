import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_theme.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_tokens.dart';
import 'package:gym_client/src/core/widgets/pulso_charts.dart';

Future<void> _pump(WidgetTester tester, Widget hijo, {bool oscuro = false}) {
  final tokens = oscuro ? PulsoTokens.clayDark : PulsoTokens.clayLight;
  return tester.pumpWidget(
    MaterialApp(
      // Los tokens viajan como extensión del tema: es de donde los lee
      // `PulsoTokens.of`.
      theme: ThemeData(extensions: <ThemeExtension<dynamic>>[tokens]),
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: hijo),
      ),
    ),
  );
}

void main() {
  group('barras', () {
    testWidgets('muestra la cifra junto a cada barra, no solo la forma', (
      tester,
    ) async {
      await _pump(
        tester,
        const PulsoBarras(
          datos: [
            PulsoChartDato(etiqueta: 'Mensual', valor: 42),
            PulsoChartDato(etiqueta: 'Semanal', valor: 17),
          ],
        ),
      );

      expect(find.text('Mensual'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin datos lo dice en vez de dejar el hueco en blanco', (
      tester,
    ) async {
      await _pump(
        tester,
        const PulsoBarras(datos: [], mensajeVacio: 'Nadie ha venido todavía.'),
      );

      expect(find.text('Nadie ha venido todavía.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('dona', () {
    testWidgets('acompaña cada porción con su cifra y su porcentaje', (
      tester,
    ) async {
      await _pump(
        tester,
        const PulsoDona(
          datos: [
            PulsoChartDato(etiqueta: 'Mañana', valor: 75),
            PulsoChartDato(etiqueta: 'Noche', valor: 25),
          ],
          centroTitulo: 'visitas',
          centroValor: '100',
        ),
      );

      expect(find.text('Mañana'), findsOneWidget);
      // La cifra Y el porcentaje: el porcentaje solo escondería la muestra.
      expect(find.text('75  75%'), findsOneWidget);
      expect(find.text('25  25%'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('VISITAS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('las categorías en cero no ocupan sitio', (tester) async {
      await _pump(
        tester,
        const PulsoDona(
          datos: [
            PulsoChartDato(etiqueta: 'Tarde', valor: 10),
            PulsoChartDato(etiqueta: 'Madrugada', valor: 0),
          ],
        ),
      );

      expect(find.text('Tarde'), findsOneWidget);
      expect(find.text('Madrugada'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('todo en cero se anuncia como sin datos', (tester) async {
      await _pump(
        tester,
        const PulsoDona(
          datos: [PulsoChartDato(etiqueta: 'Tarde', valor: 0)],
          mensajeVacio: 'Sin visitas registradas.',
        ),
      );

      expect(find.text('Sin visitas registradas.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('línea', () {
    testWidgets('dibuja la serie con su eje de períodos', (tester) async {
      await _pump(
        tester,
        const PulsoLinea(
          puntos: [
            PulsoChartDato(etiqueta: 'feb', valor: 9),
            PulsoChartDato(etiqueta: 'mar', valor: 19),
            PulsoChartDato(etiqueta: 'abr', valor: 21),
          ],
        ),
      );

      expect(find.text('feb'), findsOneWidget);
      expect(find.text('abr'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un solo período no se disfraza de tendencia', (tester) async {
      await _pump(
        tester,
        const PulsoLinea(puntos: [PulsoChartDato(etiqueta: 'jul', valor: 12)]),
      );

      expect(find.text('12'), findsOneWidget);
      expect(find.textContaining('todavía no hay tendencia'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('una serie plana en cero no divide por cero', (tester) async {
      await _pump(
        tester,
        const PulsoLinea(
          puntos: [
            PulsoChartDato(etiqueta: 'a', valor: 0),
            PulsoChartDato(etiqueta: 'b', valor: 0),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('mapa de calor', () {
    testWidgets('rotula filas y columnas y marca las celdas con valor', (
      tester,
    ) async {
      await _pump(
        tester,
        const PulsoMapaCalor(
          filas: ['Mañana', 'Noche'],
          columnas: ['Lun', 'Mar'],
          valores: [
            [5, 0],
            [0, 9],
          ],
        ),
      );

      expect(find.text('Mañana'), findsOneWidget);
      expect(find.text('Lun'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('una rejilla entera en cero se anuncia', (tester) async {
      await _pump(
        tester,
        const PulsoMapaCalor(
          filas: ['Mañana'],
          columnas: ['Lun'],
          valores: [
            [0],
          ],
          mensajeVacio: 'Nadie vino esta semana.',
        ),
      );

      expect(find.text('Nadie vino esta semana.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('escala categórica', () {
    test('la primera serie es el acento y no se repite el color', () {
      const tokens = PulsoTokens.clayLight;
      final colores = pulsoSerieColores(tokens, 5);

      expect(colores, hasLength(5));
      expect(colores.first, tokens.accent);
      expect(colores.toSet().length, 5);
    });

    test('una sola serie usa el acento sin degradar', () {
      const tokens = PulsoTokens.midnightDark;
      expect(pulsoSerieColores(tokens, 1), [tokens.accent]);
    });

    test('pedir cero colores no revienta', () {
      expect(pulsoSerieColores(PulsoTokens.ironGoldLight, 0), isEmpty);
    });
  });

  testWidgets('los gráficos se pintan igual en oscuro', (tester) async {
    await _pump(
      tester,
      const PulsoBarras(
        datos: [PulsoChartDato(etiqueta: 'Noche', valor: 8)],
      ),
      oscuro: true,
    );

    expect(find.text('Noche'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
