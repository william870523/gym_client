import 'package:shared_preferences/shared_preferences.dart';

import 'appearance_preference.dart';
import 'pulso_palette_id.dart';

abstract interface class AppearanceStore {
  Future<AppearancePreference?> load();

  Future<void> save(AppearancePreference preference);
}

/// Extensión opcional del almacén: preferencia por usuario con claves
/// `gymos.ui.<user_id>.*` (DESIGN_SYSTEM_PULSO §3). El fallback del
/// dispositivo sigue siendo `load`/`save`.
abstract interface class UserScopedAppearanceStore implements AppearanceStore {
  Future<AppearancePreference?> loadFor(String userId);

  Future<void> saveFor(String userId, AppearancePreference preference);
}

class SharedPreferencesAppearanceStore implements UserScopedAppearanceStore {
  SharedPreferencesAppearanceStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _paletteKey = 'gymos.ui.device.palette';
  static const _themeModeKey = 'gymos.ui.device.theme_mode';

  final SharedPreferencesAsync _preferences;

  // Identificador normalizado para las claves por usuario.
  static String _normalize(String userId) =>
      userId.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');

  static String _userPaletteKey(String userId) =>
      'gymos.ui.${_normalize(userId)}.palette';

  static String _userThemeModeKey(String userId) =>
      'gymos.ui.${_normalize(userId)}.theme_mode';

  @override
  Future<AppearancePreference?> load() {
    return _read(_paletteKey, _themeModeKey);
  }

  @override
  Future<void> save(AppearancePreference preference) {
    return _write(_paletteKey, _themeModeKey, preference);
  }

  @override
  Future<AppearancePreference?> loadFor(String userId) {
    return _read(_userPaletteKey(userId), _userThemeModeKey(userId));
  }

  @override
  Future<void> saveFor(String userId, AppearancePreference preference) {
    return _write(
      _userPaletteKey(userId),
      _userThemeModeKey(userId),
      preference,
    );
  }

  Future<AppearancePreference?> _read(
    String paletteKey,
    String themeModeKey,
  ) async {
    final palette = await _preferences.getString(paletteKey);
    final themeMode = await _preferences.getString(themeModeKey);
    if (palette == null && themeMode == null) {
      return null;
    }
    return AppearancePreference(
      palette: PulsoPaletteId.fromStorage(palette),
      themeMode: themeModeFromStorage(themeMode),
    );
  }

  Future<void> _write(
    String paletteKey,
    String themeModeKey,
    AppearancePreference preference,
  ) async {
    await Future.wait<void>([
      _preferences.setString(paletteKey, preference.palette.storageValue),
      _preferences.setString(themeModeKey, preference.themeMode.name),
    ]);
  }
}
