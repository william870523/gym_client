import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/configuration/presentation/widgets/payment_type_pulso_form.dart';

void main() {
  testWidgets('normaliza y envía un tipo de pago PULSO', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? name;
    String? code;
    bool? active;
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
                    builder: (context) => PaymentTypePulsoForm(
                      onSubmit: (valueName, valueCode, valueActive) async {
                        name = valueName;
                        code = valueCode;
                        active = valueActive;
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
      find.byKey(const ValueKey('pulso-payment-type-name')),
      '  Transferencia  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('pulso-payment-type-code')),
      'wire_transfer',
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.text('CREAR').last);
    await tester.pumpAndSettle();

    expect(name, 'Transferencia');
    expect(code, 'WIRE_TRANSFER');
    expect(active, isFalse);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
