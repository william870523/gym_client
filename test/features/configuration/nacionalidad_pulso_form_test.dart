import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/configuration/presentation/widgets/nacionalidad_pulso_form.dart';

void main() {
  testWidgets('normaliza y envía la nueva nacionalidad en ancho compacto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? name;
    String? iso;
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
                    builder: (context) => NacionalidadPulsoForm(
                      onSubmit: (valueName, valueIso, flagBytes) async {
                        name = valueName;
                        iso = valueIso;
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
      find.byKey(const ValueKey('pulso-nationality-name')),
      '  Dominicana  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('pulso-nationality-iso')),
      'do',
    );
    await tester.pump();
    expect(find.text('DO'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('CREAR').last);
    await tester.pumpAndSettle();

    expect(name, 'Dominicana');
    expect(iso, 'DO');
    expect(tester.takeException(), isNull);
  });
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
