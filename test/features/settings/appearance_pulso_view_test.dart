import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_palette_id.dart';
import 'package:gym_client/src/features/settings/presentation/screens/appearance_pulso_view.dart';

void main() {
  const sizes = <String, Size>{
    'compacto': Size(390, 844),
    'mediano': Size(760, 900),
    'escritorio': Size(1280, 900),
    'ventana baja': Size(1024, 650),
  };

  for (final entry in sizes.entries) {
    testWidgets('Apariencia PULSO se adapta al ancho ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('APARIENCIA.', findRichText: true), findsOneWidget);
      expect(find.text('Arcilla'), findsOneWidget);
      expect(find.text('Medianoche'), findsOneWidget);
      expect(find.text('Hierro y oro'), findsOneWidget);
      expect(find.text('Claro'), findsOneWidget);
      expect(find.text('Oscuro'), findsOneWidget);
      expect(find.text('Sistema'), findsOneWidget);
      expect(find.text('MODO LOCAL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('elegir paleta y luminosidad aplica y persiste', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _MemoryAppearanceStore();
    await tester.pumpWidget(_harness(store: store));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppearancePulsoView)),
    );

    await tester.tap(find.byKey(const ValueKey('pulso-palette-medianoche')));
    await tester.pumpAndSettle();
    expect(
      container.read(appearanceProvider).palette,
      PulsoPaletteId.midnight,
    );

    await tester.tap(find.byKey(const ValueKey('pulso-mode-Sistema')));
    await tester.pumpAndSettle();
    expect(container.read(appearanceProvider).themeMode, ThemeMode.system);

    // La preferencia quedó persistida en el almacén.
    expect(store.saved, isNotNull);
    expect(store.saved!.palette, PulsoPaletteId.midnight);
    expect(store.saved!.themeMode, ThemeMode.system);
    expect(tester.takeException(), isNull);
  });
}

Widget _harness({_MemoryAppearanceStore? store}) {
  return ProviderScope(
    overrides: [
      appearanceStoreProvider.overrideWithValue(
        store ?? _MemoryAppearanceStore(),
      ),
      syncStatusProvider.overrideWith(
        (ref) => Stream.value(
          SyncStatusSnapshot.offline(
            detail: 'API remota no disponible',
            source: 'sync-local',
          ),
        ),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: AppearancePulsoView())),
  );
}

class _MemoryAppearanceStore implements AppearanceStore {
  AppearancePreference? saved;

  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {
    saved = preference;
  }
}
