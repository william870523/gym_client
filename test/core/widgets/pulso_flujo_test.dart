import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_theme.dart';
import 'package:gym_client/src/core/widgets/pulso_charts.dart';

/// La primitiva de movilidad existe porque ninguna otra dibuja **un dato con
/// signo**. Lo que se prueba aquí es justo eso: que el saldo se vea, que las dos
/// mitades compartan escala y que un valor pequeño no desaparezca.
Future<void> _pump(WidgetTester tester, Widget hijo, {double ancho = 700}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
      ],
      child: MaterialApp(
        home: PulsoThemeScope(
          child: Scaffold(
            body: Center(child: SizedBox(width: ancho, child: hijo)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}

void main() {
  testWidgets('enseña el saldo con su signo, que es la pregunta del gráfico', (
    tester,
  ) async {
    await _pump(
      tester,
      const PulsoFlujo(
        datos: [
          PulsoFlujoDato(etiqueta: 'Semanal', entran: 3, salen: 1),
          PulsoFlujoDato(etiqueta: 'Mensual', entran: 1, salen: 1),
          PulsoFlujoDato(etiqueta: 'Diario', entran: 0, salen: 2),
        ],
      ),
    );

    expect(find.text('+2'), findsOneWidget); // Semanal: 3 − 1
    expect(find.text('±0'), findsOneWidget); // Mensual: 1 − 1
    expect(find.text('-2'), findsOneWidget); // Diario: 0 − 2
    expect(tester.takeException(), isNull);
  });

  testWidgets('ordena por movimiento: primero la fila que más cuenta', (
    tester,
  ) async {
    await _pump(
      tester,
      const PulsoFlujo(
        datos: [
          PulsoFlujoDato(etiqueta: 'Poco', entran: 1),
          PulsoFlujoDato(etiqueta: 'Mucho', entran: 9, salen: 4),
        ],
      ),
    );

    final poco = tester.getTopLeft(find.text('Poco'));
    final mucho = tester.getTopLeft(find.text('Mucho'));
    expect(mucho.dy, lessThan(poco.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('las dos mitades comparten escala', (tester) async {
    // Con escalas independientes, 2 salidas ocuparían tanto como 20 entradas.
    await _pump(
      tester,
      const PulsoFlujo(
        datos: [PulsoFlujoDato(etiqueta: 'Otro', entran: 20, salen: 2)],
      ),
    );

    expect(find.text('20'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('+18'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin ningún movimiento dice que no hay nada, no dibuja vacío', (
    tester,
  ) async {
    await _pump(
      tester,
      const PulsoFlujo(
        datos: [PulsoFlujoDato(etiqueta: 'Semanal')],
        mensajeVacio: 'Ningún socio ha cambiado de plan.',
      ),
    );

    expect(find.text('Ningún socio ha cambiado de plan.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cabe en una ventana estrecha sin desbordar', (tester) async {
    await _pump(
      tester,
      const PulsoFlujo(
        datos: [
          PulsoFlujoDato(etiqueta: 'Mensual con entrenador', entran: 7, salen: 3),
          PulsoFlujoDato(etiqueta: 'Diario', entran: 1, salen: 6),
        ],
      ),
      ancho: 320,
    );

    expect(find.text('+4'), findsOneWidget);
    expect(find.text('-5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
