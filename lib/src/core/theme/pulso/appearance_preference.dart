import 'package:flutter/material.dart';

import 'pulso_palette_id.dart';

@immutable
class AppearancePreference {
  const AppearancePreference({required this.palette, required this.themeMode});

  static const defaults = AppearancePreference(
    palette: PulsoPaletteId.clay,
    themeMode: ThemeMode.light,
  );

  final PulsoPaletteId palette;
  final ThemeMode themeMode;

  Brightness resolveBrightness(Brightness platformBrightness) {
    return switch (themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => platformBrightness,
    };
  }

  AppearancePreference copyWith({
    PulsoPaletteId? palette,
    ThemeMode? themeMode,
  }) {
    return AppearancePreference(
      palette: palette ?? this.palette,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppearancePreference &&
        other.palette == palette &&
        other.themeMode == themeMode;
  }

  @override
  int get hashCode => Object.hash(palette, themeMode);
}

ThemeMode themeModeFromStorage(String? value) {
  return switch (value) {
    'dark' => ThemeMode.dark,
    'system' => ThemeMode.system,
    _ => ThemeMode.light,
  };
}
