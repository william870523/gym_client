import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/financials/presentation/widgets/currency_pulso_form.dart';

void main() {
  testWidgets('el formulario PULSO actualiza el código y normaliza el envío', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? submittedName;
    String? submittedCode;
    String? submittedSymbol;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => CurrencyPulsoForm(
                      onSubmit: (name, code, symbol, flagBytes) async {
                        submittedName = name;
                        submittedCode = code;
                        submittedSymbol = symbol;
                      },
                    ),
                  ),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pulso-currency-name')),
      '  Dólar estadounidense  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('pulso-currency-code')),
      'usd',
    );
    await tester.enterText(
      find.byKey(const ValueKey('pulso-currency-symbol')),
      r'US$',
    );
    await tester.pump();

    expect(find.text('USD'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('CREAR MONEDA').last);
    await tester.pumpAndSettle();

    expect(submittedName, 'Dólar estadounidense');
    expect(submittedCode, 'USD');
    expect(submittedSymbol, r'US$');
    expect(tester.takeException(), isNull);
  });
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
