import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/main.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_palette_id.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_tokens.dart';
import 'package:gym_client/src/core/widgets/pulso_widgets.dart';

void main() {
  testWidgets('MyApp aplica la paleta y luminosidad PULSO globalmente', (
    tester,
  ) async {
    final store = _MemoryAppearanceStore();
    final container = ProviderContainer(
      overrides: [
        appearanceStoreProvider.overrideWithValue(store),
        syncStatusProvider.overrideWith(
          (ref) => Stream.value(
            SyncStatusSnapshot(
              level: SyncStatusLevel.synced,
              label: 'Sincronizado',
              detail: 'Base local al día',
              checkedAt: DateTime.utc(2026, 7, 11),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MyApp(useDesktopWindowFrame: false),
      ),
    );
    await tester.pump();

    var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(app.theme?.extension<PulsoTokens>()?.palette, PulsoPaletteId.clay);
    expect(find.byType(PulsoAppearanceMenuButton), findsOneWidget);
    expect(tester.takeException(), isNull);

    await container
        .read(appearanceProvider.notifier)
        .setPalette(PulsoPaletteId.midnight);
    await container
        .read(appearanceProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    await tester.pump();

    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(
      app.darkTheme?.extension<PulsoTokens>()?.palette,
      PulsoPaletteId.midnight,
    );
    expect(store.saved?.palette, PulsoPaletteId.midnight);
    expect(store.saved?.themeMode, ThemeMode.dark);
  });
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
