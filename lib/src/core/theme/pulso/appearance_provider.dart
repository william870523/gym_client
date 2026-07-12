import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'appearance_preference.dart';
import 'appearance_store.dart';
import 'pulso_palette_id.dart';

final appearanceStoreProvider = Provider<AppearanceStore>((ref) {
  return SharedPreferencesAppearanceStore();
});

/// Identidad activa para el scope de apariencia: el id del usuario con sesión
/// iniciada, o `null` antes del login (se usa el fallback del dispositivo).
/// La fija el flujo de autenticación; la apariencia no conoce a auth.
class AppearanceUserNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? userId) {
    final normalized = userId?.trim();
    state = normalized == null || normalized.isEmpty ? null : normalized;
  }
}

final appearanceUserProvider = NotifierProvider<AppearanceUserNotifier, String?>(
  AppearanceUserNotifier.new,
);

class AppearanceNotifier extends Notifier<AppearancePreference> {
  bool _restoreStarted = false;
  bool _hasLocalCommit = false;
  String? _userId;

  @override
  AppearancePreference build() {
    ref.listen<String?>(appearanceUserProvider, (previous, next) {
      if (previous == next) return;
      _userId = next;
      if (next != null) {
        // Cada inicio de sesión reinicia la protección: la preferencia
        // guardada del usuario manda sobre el fallback del dispositivo.
        _hasLocalCommit = false;
        unawaited(_restoreForUser(next));
      }
      // Al cerrar sesión se conserva la apariencia visible; el fallback del
      // dispositivo ya refleja la última elección.
    });
    if (!_restoreStarted) {
      _restoreStarted = true;
      unawaited(_restore());
    }
    return AppearancePreference.defaults;
  }

  Future<void> _restore() async {
    try {
      final stored = await ref.read(appearanceStoreProvider).load();
      if (stored != null && !_hasLocalCommit && _userId == null) {
        state = stored;
      }
    } catch (_) {
      // Appearance is non-critical. Keep the documented defaults if storage
      // is unavailable or contains data from an incompatible older build.
    }
  }

  Future<void> _restoreForUser(String userId) async {
    try {
      final store = ref.read(appearanceStoreProvider);
      if (store is! UserScopedAppearanceStore) return;
      final stored = await store.loadFor(userId);
      // Protección: una preferencia restaurada tarde no reemplaza una
      // elección que el usuario acaba de hacer en esta sesión.
      if (stored != null && !_hasLocalCommit && _userId == userId) {
        state = stored;
      }
    } catch (_) {
      // El usuario conserva el fallback del dispositivo si el scope falla.
    }
  }

  Future<void> setPalette(PulsoPaletteId palette) {
    return _commit(state.copyWith(palette: palette));
  }

  Future<void> setThemeMode(ThemeMode themeMode) {
    return _commit(state.copyWith(themeMode: themeMode));
  }

  Future<void> toggleBrightness(Brightness effectiveBrightness) {
    return setThemeMode(
      effectiveBrightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  Future<void> _commit(AppearancePreference next) async {
    _hasLocalCommit = true;
    state = next;
    try {
      final store = ref.read(appearanceStoreProvider);
      final userId = _userId;
      // El fallback del dispositivo siempre se actualiza (se usa antes del
      // login); con sesión iniciada se guarda además el scope del usuario.
      await Future.wait<void>([
        store.save(next),
        if (userId != null && store is UserScopedAppearanceStore)
          store.saveFor(userId, next),
      ]);
    } catch (_) {
      // The live preference remains useful even if persistence fails.
    }
  }
}

final appearanceProvider =
    NotifierProvider<AppearanceNotifier, AppearancePreference>(
      AppearanceNotifier.new,
    );
