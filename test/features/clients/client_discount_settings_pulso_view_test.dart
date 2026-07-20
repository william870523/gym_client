import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/clients/data/models/client_discount_settings_model.dart';
import 'package:gym_client/src/features/clients/data/repositories/client_discount_repository.dart';
import 'package:gym_client/src/features/clients/presentation/screens/client_discount_settings_pulso_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('muestra el % y la simulación sin desbordar en compacto', (
    tester,
  ) async {
    final repository = _FakeClientDiscountRepository();
    await _pump(tester, const Size(500, 900), repository);

    expect(find.text('DESCUENTO\nCLIENTE VIEJO.'), findsOneWidget);
    // Simulación: 30.00 al 16.67 % debe mostrar 24.00 (coincide con el backend).
    expect(find.text('24.00'), findsOneWidget);
    // 12.00 al 16.67 % sin excepción → 9.00.
    expect(find.text('9.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guarda el % editado e invalida el provider', (tester) async {
    final repository = _FakeClientDiscountRepository();
    await _pump(tester, const Size(1280, 900), repository);

    await tester.enterText(find.byType(TextField), '20');
    await tester.pump();

    expect(find.text('CAMBIOS SIN GUARDAR'), findsOneWidget);
    await tester.tap(find.text('GUARDAR DESCUENTO'));
    await tester.pumpAndSettle();

    expect(repository.savedPct, '20');
    expect(
      find.textContaining('Descuento guardado'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Size size,
  ClientDiscountRepository repository,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
        clientDiscountRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        home: Scaffold(body: ClientDiscountSettingsPulsoView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeClientDiscountRepository extends ClientDiscountRepository {
  _FakeClientDiscountRepository() : super(Dio());

  String? savedPct;
  ClientDiscountSettingsModel current = _model();

  @override
  Future<ClientDiscountSettingsModel> get() async => current;

  @override
  Future<ClientDiscountSettingsModel> update({
    required String clienteViejoPct,
  }) async {
    savedPct = clienteViejoPct;
    current = _model(pct: clienteViejoPct, source: 'GYM');
    return current;
  }
}

ClientDiscountSettingsModel _model({
  String pct = '16.67',
  String source = 'DEFAULT',
}) => ClientDiscountSettingsModel(
  gymId: 'gym-1',
  clienteViejoPct: pct,
  source: source,
  min: 0,
  max: 100,
  changedKeys: const [],
  updatedAtUtc: DateTime.utc(2026, 7, 20, 8),
);

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
