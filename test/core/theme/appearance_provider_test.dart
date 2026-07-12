import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_palette_id.dart';

void main() {
  test('restaura y persiste la apariencia elegida', () async {
    final stored = const AppearancePreference(
      palette: PulsoPaletteId.midnight,
      themeMode: ThemeMode.dark,
    );
    final store = _MemoryAppearanceStore(stored);
    final container = ProviderContainer(
      overrides: [appearanceStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(container.read(appearanceProvider), AppearancePreference.defaults);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(appearanceProvider), stored);

    await container
        .read(appearanceProvider.notifier)
        .setPalette(PulsoPaletteId.ironGold);
    await container
        .read(appearanceProvider.notifier)
        .setThemeMode(ThemeMode.system);

    expect(
      store.saved,
      const AppearancePreference(
        palette: PulsoPaletteId.ironGold,
        themeMode: ThemeMode.system,
      ),
    );
  });

  test(
    'una elección inmediata no es reemplazada por una carga tardía',
    () async {
      final store = _DelayedAppearanceStore();
      final container = ProviderContainer(
        overrides: [appearanceStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      container.read(appearanceProvider);
      await container
          .read(appearanceProvider.notifier)
          .setPalette(PulsoPaletteId.ironGold);
      store.complete(
        const AppearancePreference(
          palette: PulsoPaletteId.midnight,
          themeMode: ThemeMode.dark,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(appearanceProvider).palette,
        PulsoPaletteId.ironGold,
      );
    },
  );
}

class _MemoryAppearanceStore implements AppearanceStore {
  _MemoryAppearanceStore(this.loaded);

  final AppearancePreference? loaded;
  AppearancePreference? saved;

  @override
  Future<AppearancePreference?> load() async => loaded;

  @override
  Future<void> save(AppearancePreference preference) async {
    saved = preference;
  }
}

class _DelayedAppearanceStore implements AppearanceStore {
  final _loadCompleter = Completer<AppearancePreference?>();

  void complete(AppearancePreference preference) {
    _loadCompleter.complete(preference);
  }

  @override
  Future<AppearancePreference?> load() => _loadCompleter.future;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
