import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_palette_id.dart';

const _devicePref = AppearancePreference(
  palette: PulsoPaletteId.ironGold,
  themeMode: ThemeMode.dark,
);
const _mariaPref = AppearancePreference(
  palette: PulsoPaletteId.midnight,
  themeMode: ThemeMode.system,
);

class _FakeStore implements UserScopedAppearanceStore {
  AppearancePreference? device = _devicePref;
  final userPrefs = <String, AppearancePreference>{'user-maria': _mariaPref};
  final deviceSaves = <AppearancePreference>[];
  final userSaves = <(String, AppearancePreference)>[];

  /// Permite retrasar la restauración por usuario para probar la protección.
  Completer<void>? holdUserLoad;

  @override
  Future<AppearancePreference?> load() async => device;

  @override
  Future<void> save(AppearancePreference preference) async {
    device = preference;
    deviceSaves.add(preference);
  }

  @override
  Future<AppearancePreference?> loadFor(String userId) async {
    final gate = holdUserLoad;
    if (gate != null) await gate.future;
    return userPrefs[userId];
  }

  @override
  Future<void> saveFor(String userId, AppearancePreference preference) async {
    userPrefs[userId] = preference;
    userSaves.add((userId, preference));
  }
}

ProviderContainer _container(_FakeStore store) {
  final container = ProviderContainer(
    overrides: [appearanceStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('antes del login se restaura el fallback del dispositivo', () async {
    final container = _container(_FakeStore());
    expect(container.read(appearanceProvider), AppearancePreference.defaults);
    await _settle();
    expect(container.read(appearanceProvider), _devicePref);
  });

  test('al iniciar sesión manda la preferencia guardada del usuario', () async {
    final container = _container(_FakeStore());
    container.read(appearanceProvider);
    await _settle();

    container.read(appearanceUserProvider.notifier).set('user-maria');
    await _settle();
    expect(container.read(appearanceProvider), _mariaPref);
  });

  test('sin preferencia del usuario se conserva la del dispositivo', () async {
    final container = _container(_FakeStore());
    container.read(appearanceProvider);
    await _settle();

    container.read(appearanceUserProvider.notifier).set('user-nuevo');
    await _settle();
    expect(container.read(appearanceProvider), _devicePref);
  });

  test('guardar con sesión escribe el scope del usuario y el fallback',
      () async {
    final store = _FakeStore();
    final container = _container(store);
    container.read(appearanceProvider);
    await _settle();
    container.read(appearanceUserProvider.notifier).set('user-maria');
    await _settle();

    await container
        .read(appearanceProvider.notifier)
        .setPalette(PulsoPaletteId.clay);

    expect(store.userSaves, hasLength(1));
    expect(store.userSaves.single.$1, 'user-maria');
    expect(store.userSaves.single.$2.palette, PulsoPaletteId.clay);
    // El fallback del dispositivo también refleja la última elección.
    expect(store.deviceSaves.last.palette, PulsoPaletteId.clay);
  });

  test('una restauración tardía no pisa una elección recién hecha', () async {
    final store = _FakeStore()..holdUserLoad = Completer<void>();
    final container = _container(store);
    container.read(appearanceProvider);
    await _settle();

    container.read(appearanceUserProvider.notifier).set('user-maria');
    // El usuario elige antes de que llegue su preferencia guardada.
    await container
        .read(appearanceProvider.notifier)
        .setThemeMode(ThemeMode.light);

    store.holdUserLoad!.complete();
    await _settle();

    expect(container.read(appearanceProvider).themeMode, ThemeMode.light);
  });
}
