import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/retention/data/models/retention_models.dart';
import 'package:gym_client/src/features/retention/data/repositories/retention_repository.dart';
import 'package:gym_client/src/features/retention/presentation/screens/retention_settings_pulso_view.dart';

void main() {
  testWidgets('explica la política sin desbordar en ancho compacto', (
    tester,
  ) async {
    final repository = _FakeRetentionRepository();
    await _pump(tester, const Size(500, 800), repository);

    expect(find.text('POLÍTICA DE\nRETENCIÓN.'), findsOneWidget);
    expect(find.text('VENCE HOY'), findsOneWidget);
    expect(find.text('EN GRACIA'), findsOneWidget);
    expect(find.text('CAUSA SALIDA'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('retention-grace-control')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('guarda la política e invalida la proyección', (tester) async {
    final repository = _FakeRetentionRepository();
    await _pump(tester, const Size(1280, 900), repository);

    await tester.tap(find.byTooltip('Aumentar Días de gracia'));
    await tester.pump();

    expect(find.text('CAMBIOS SIN GUARDAR'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    await tester.tap(find.text('GUARDAR POLÍTICA'));
    await tester.pumpAndSettle();

    expect(repository.savedGraceDays, 6);
    expect(repository.savedHorizonDays, 7);
    expect(
      find.text('Política guardada. Control y Calidad se recalculará.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Size size,
  RetentionRepository repository,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
        retentionRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        home: Scaffold(body: RetentionSettingsPulsoView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeRetentionRepository extends RetentionRepository {
  _FakeRetentionRepository() : super(Dio());

  int? savedGraceDays;
  int? savedHorizonDays;
  RetentionSettingsModel current = _settings();

  @override
  Future<RetentionSettingsModel> getSettings() async => current;

  @override
  Future<RetentionSettingsModel> updateSettings({
    required int graceDays,
    required int horizonDays,
  }) async {
    savedGraceDays = graceDays;
    savedHorizonDays = horizonDays;
    current = _settings(
      graceDays: graceDays,
      horizonDays: horizonDays,
      source: 'GYM',
    );
    return current;
  }
}

RetentionSettingsModel _settings({
  int graceDays = 5,
  int horizonDays = 7,
  String source = 'DEFAULT',
}) => RetentionSettingsModel(
  gymId: 'gym-1',
  graceDays: graceDays,
  horizonDays: horizonDays,
  exitBeginsDay: graceDays + 1,
  graceSource: source,
  horizonSource: source,
  graceMin: 0,
  graceMax: 60,
  horizonMin: 1,
  horizonMax: 90,
  changedKeys: const [],
  updatedAtUtc: DateTime.utc(2026, 7, 13, 8),
);

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
