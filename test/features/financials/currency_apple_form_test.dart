import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/financials/presentation/widgets/currency_apple_form.dart';

void main() {
  Future<void> pumpForm(
    WidgetTester tester, {
    required Size size,
    required Brightness brightness,
    CurrencyFormSubmit? onSubmit,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: CurrencyAppleForm(
            id: 'currency-cup',
            initialName: 'Peso Cubano',
            initialCode: 'CUP',
            initialSymbol: '₱',
            onSubmit: onSubmit ?? (_, _, _, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the Registro edit form on desktop', (tester) async {
    await pumpForm(
      tester,
      size: const Size(1024, 768),
      brightness: Brightness.light,
    );

    expect(find.text('EDITAR DIVISA.'), findsOneWidget);
    expect(find.text('F-03A / MODIFICACION · REV. 2026'), findsOneWidget);
    expect(find.text('GUARDAR CAMBIOS'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without overflow in compact dark mode', (tester) async {
    await pumpForm(
      tester,
      size: const Size(390, 700),
      brightness: Brightness.dark,
    );

    expect(find.text('EDITAR DIVISA.'), findsOneWidget);
    expect(find.text('CAMBIAR BANDERA'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('submits the edited currency values', (tester) async {
    String? submittedName;
    String? submittedCode;
    String? submittedSymbol;

    await pumpForm(
      tester,
      size: const Size(1024, 768),
      brightness: Brightness.light,
      onSubmit: (name, code, symbol, _) async {
        submittedName = name;
        submittedCode = code;
        submittedSymbol = symbol;
      },
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Peso Cubano'),
      'Peso Cubano Actualizado',
    );
    await tester.tap(find.text('GUARDAR CAMBIOS'));
    await tester.pump();

    expect(submittedName, 'Peso Cubano Actualizado');
    expect(submittedCode, 'CUP');
    expect(submittedSymbol, '₱');
  });
}
