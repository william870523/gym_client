import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_palette_id.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_theme.dart';
import 'package:gym_client/src/core/widgets/pulso_widgets.dart';

void main() {
  testWidgets('el cambio de tema respeta reducir movimiento', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: PulsoThemeScope(child: SizedBox()),
          ),
        ),
      ),
    );

    final themes = tester.widgetList<AnimatedTheme>(find.byType(AnimatedTheme));
    expect(themes.any((theme) => theme.duration == Duration.zero), isTrue);
  });

  testWidgets('el menú global permite escoger paleta y luminosidad', (
    tester,
  ) async {
    final store = _MemoryAppearanceStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appearanceStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(
          home: PulsoThemeScope(
            child: Scaffold(
              body: Center(
                child: PulsoAppearanceMenuButton(
                  key: ValueKey('appearance-menu'),
                  compact: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('appearance-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medianoche'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appearance-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();

    expect(store.saved?.palette, PulsoPaletteId.midnight);
    expect(store.saved?.themeMode, ThemeMode.dark);
    expect(tester.takeException(), isNull);
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
