import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_theme.dart';
import 'package:gym_client/src/core/widgets/pulso_widgets.dart';
import 'package:gym_client/src/features/accounting/data/models/saldo_enlace_models.dart';
import 'package:gym_client/src/features/accounting/presentation/state/saldo_enlace_providers.dart';
import 'package:gym_client/src/features/accounting/presentation/widgets/saldo_enlace_panel.dart';

/// M8 — el saldo entre sedes en pantalla (docs/MULTI_SEDE.md §5.4).
///
/// Lo que se fija aquí es lo que hace falta para **decidir una transferencia**:
/// cuánto se debe hoy, a quién, y que la pantalla no confunda una deuda saldada
/// con una pagada de más. Las dos aparecen sin nada pendiente y piden cosas
/// opuestas: una está en paz y la otra tiene dinero a favor que alguien va a
/// reclamar.
void main() {
  const sedeId = 'gym-oeste';

  AcreedorModel sede(String nombre) =>
      AcreedorModel(tipo: 'SEDE', nombre: nombre, gymId: nombre);
  const cadena = AcreedorModel(tipo: 'CADENA', nombre: 'La cadena');

  LineaSaldoModel linea({
    required AcreedorModel acreedor,
    required String saldo,
    String generado = '300.00',
    String deshecho = '0.00',
    int asientos = 2,
  }) => LineaSaldoModel(
    acreedor: acreedor,
    monedaId: 'cup',
    saldo: saldo,
    generado: generado,
    deshecho: deshecho,
    asientos: asientos,
  );

  SaldoSedeModel saldo(List<LineaSaldoModel> lineas) => SaldoSedeModel(
    gymId: sedeId,
    nombre: 'Sede Oeste',
    pendientes: [for (final l in lineas) if (!l.aFavor && !l.saldado) l],
    lineas: lineas,
  );

  Widget app({
    String? gymId = sedeId,
    SaldoSedeModel? datos,
    List<LiquidacionModel> liquidaciones = const [],
    Object? error,
    double width = 1100,
  }) => ProviderScope(
    overrides: [
      saldoDeSedeProvider(gymId).overrideWith((_) async {
        if (error != null) throw error;
        return datos ?? saldo(const []);
      }),
      liquidacionesDeSedeProvider(gymId).overrideWith((_) async => liquidaciones),
    ],
    child: MaterialApp(
      home: PulsoThemeScope(
        child: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: width,
              child: SaldoEnlacePanel(
                gymId: gymId,
                nombreSede: 'Sede Oeste',
                compact: width < 760,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('sin sede elegida explica de dónde salen estas cifras', (
    tester,
  ) async {
    await tester.pumpWidget(app(gymId: null));
    await tester.pumpAndSettle();
    expect(find.textContaining('Elija una sede arriba'), findsOneWidget);
    // El dato que evita el malentendido: no es del período de arriba.
    expect(find.textContaining('lo que se debe hoy'), findsOneWidget);
  });

  testWidgets('la cabecera declara que el saldo no sigue al período', (
    tester,
  ) async {
    // Es el malentendido caro de esta pantalla: las cuatro secciones de arriba
    // obedecen al selector de período y esta no. Si no lo dijera, alguien
    // transferiría «lo de julio» creyendo que salda la deuda entera.
    await tester.pumpWidget(app(gymId: null));
    await tester.pumpAndSettle();
    expect(find.text('ACUMULADO · NO DEPENDE DEL PERÍODO'), findsOneWidget);
  });

  testWidgets('una deuda viva se puede liquidar y enseña su cifra', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(datos: saldo([linea(acreedor: sede('Centro'), saldo: '300.00')])),
    );
    await tester.pumpAndSettle();
    expect(find.text('Centro'), findsOneWidget);
    expect(find.text('300.00'), findsWidgets);
    expect(find.byTooltip('Registrar la transferencia'), findsOneWidget);
  });

  testWidgets('una deuda saldada no ofrece liquidar, y sigue a la vista', (
    tester,
  ) async {
    // Desaparecerla dejaría a quien busca una deuda que recuerda haber visto
    // pensando que se perdió. Y ofrecerle liquidar 0.00 es ofrecer un error.
    await tester.pumpWidget(
      app(
        datos: saldo([
          linea(
            acreedor: sede('Centro'),
            saldo: '0.00',
            generado: '300.00',
            deshecho: '300.00',
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Centro'), findsOneWidget);
    expect(find.byTooltip('Registrar la transferencia'), findsNothing);
    expect(find.textContaining('SALDADO'), findsOneWidget);
  });

  testWidgets('pagado de más se distingue de saldado, y tampoco se liquida', (
    tester,
  ) async {
    // Las dos salen sin nada pendiente y piden cosas opuestas: una está en paz,
    // la otra tiene dinero a favor que alguien va a reclamar.
    await tester.pumpWidget(
      app(
        datos: saldo([
          linea(
            acreedor: cadena,
            saldo: '-100.00',
            generado: '900.00',
            deshecho: '1000.00',
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('PAGADO DE MÁS'), findsOneWidget);
    expect(find.text('-100.00'), findsOneWidget);
    expect(find.byTooltip('Registrar la transferencia'), findsNothing);
  });

  testWidgets('sin deudas vivas lo dice, y explica que nada se borró', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        datos: saldo([
          linea(
            acreedor: sede('Centro'),
            saldo: '0.00',
            generado: '300.00',
            deshecho: '300.00',
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Sin deudas vivas'), findsOneWidget);
    expect(find.textContaining('añade el contraasiento'), findsOneWidget);
  });

  testWidgets('el historial conserva la referencia y quién lo anotó', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        datos: saldo([linea(acreedor: sede('Centro'), saldo: '180.00')]),
        liquidaciones: [
          LiquidacionModel(
            liquidacionId: 'liq-1',
            acreedor: sede('Centro'),
            monedaId: 'cup',
            monto: '120.00',
            saldoAntes: '300.00',
            saldoDespues: '180.00',
            dejoSaldoAFavor: false,
            registradaPor: 'Dora Dueña',
            referencia: 'TRF-0041',
            ocurridoAt: DateTime(2026, 8, 19, 10, 30),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('TRF-0041'), findsOneWidget);
    expect(find.textContaining('DORA DUEÑA'), findsOneWidget);
    // De cuánto a cuánto: sin eso, «120.00» no dice si quedó algo.
    expect(find.text('300.00 → 180.00'), findsOneWidget);
  });

  testWidgets('un fallo se puede reintentar sin recargar la pantalla', (
    tester,
  ) async {
    await tester.pumpWidget(app(error: Exception('El concentrador no responde')));
    await tester.pumpAndSettle();
    expect(find.textContaining('El concentrador no responde'), findsOneWidget);
    expect(find.text('REINTENTAR'), findsOneWidget);
  });

  testWidgets('en compacto se ocultan las columnas auxiliares, no el saldo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        width: 700,
        datos: saldo([linea(acreedor: sede('Centro'), saldo: '300.00')]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('NACIDO DE COBROS'), findsNothing);
    expect(find.text('SALDO'), findsOneWidget);
    expect(find.text('300.00'), findsOneWidget);
  });

  // ------------------------------------------------------------ el diálogo

  Widget dialogo(LineaSaldoModel linea) => ProviderScope(
    child: MaterialApp(
      home: PulsoThemeScope(
        child: Scaffold(
          body: LiquidarSaldoDialog(
            gymId: sedeId,
            nombreSede: 'Sede Oeste',
            linea: linea,
          ),
        ),
      ),
    ),
  );

  testWidgets('el importe no viene relleno con la deuda entera', (tester) async {
    // Un campo ya relleno invita a confirmar sin mirar, y lo que se anota es lo
    // que se transfirió DE VERDAD, no lo que se debía. La deuda se enseña al
    // lado para poder compararla.
    await tester.pumpWidget(
      dialogo(linea(acreedor: sede('Centro'), saldo: '300.00')),
    );
    await tester.pumpAndSettle();
    expect(find.text('SE DEBE HOY'), findsOneWidget);
    expect(find.text('300.00'), findsOneWidget);
    final campo = tester.widget<TextField>(find.byType(TextField).first);
    expect(campo.controller!.text, isEmpty);
  });

  testWidgets('pagar de más avisa y no deja registrar sin declararlo', (
    tester,
  ) async {
    // Es el error de tecleo más fácil y el más difícil de ver después: el saldo
    // queda negativo y parece un abono a favor.
    await tester.pumpWidget(
      dialogo(linea(acreedor: sede('Centro'), saldo: '300.00')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '500.00');
    await tester.pumpAndSettle();

    expect(find.textContaining('más de lo que se debe'), findsOneWidget);
    final boton = tester.widget<PulsoPrimaryButton>(
      find.byType(PulsoPrimaryButton),
    );
    expect(boton.onPressed, isNull, reason: 'sin declararlo no se puede enviar');

    await tester.tap(find.textContaining('Es intencionado'));
    await tester.pumpAndSettle();
    final tras = tester.widget<PulsoPrimaryButton>(
      find.byType(PulsoPrimaryButton),
    );
    expect(tras.onPressed, isNotNull, reason: 'declarado, ya se puede registrar');
  });

  testWidgets('pagar justo la deuda no se confunde con pagar de más', (
    tester,
  ) async {
    // El caso límite: 300.00 sobre 300.00. Se compara en unidades mínimas, no en
    // coma flotante, que es donde los dos lados podrían discrepar en un céntimo.
    await tester.pumpWidget(
      dialogo(linea(acreedor: sede('Centro'), saldo: '300.00')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '300.00');
    await tester.pumpAndSettle();
    expect(find.textContaining('más de lo que se debe'), findsNothing);
    final boton = tester.widget<PulsoPrimaryButton>(
      find.byType(PulsoPrimaryButton),
    );
    expect(boton.onPressed, isNotNull);
  });

  testWidgets('la coma decimal se acepta igual que el punto', (tester) async {
    // Aquí se teclea en español y el teclado numérico da coma. Rechazarla
    // dejaría el aviso de pago de más sin aparecer cuando debía.
    await tester.pumpWidget(
      dialogo(linea(acreedor: sede('Centro'), saldo: '300.00')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '350,50');
    await tester.pumpAndSettle();
    expect(find.textContaining('más de lo que se debe'), findsOneWidget);
  });
}
