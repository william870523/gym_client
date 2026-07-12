import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'appearance_provider.dart';
import 'pulso_tokens.dart';

abstract final class PulsoFonts {
  static const display = 'Barlow Condensed';
  static const body = 'Atkinson Hyperlegible';
  static const mono = 'IBM Plex Mono';
}

abstract final class PulsoThemeFactory {
  static ThemeData build(PulsoTokens tokens) {
    final colorScheme = ColorScheme(
      brightness: tokens.brightness,
      primary: tokens.accent,
      onPrimary: tokens.accentInk,
      secondary: tokens.success,
      onSecondary: tokens.isDark ? tokens.floor : Colors.white,
      error: tokens.danger,
      onError: tokens.isDark ? tokens.floor : Colors.white,
      surface: tokens.surface,
      onSurface: tokens.chalk,
      outline: tokens.line,
      outlineVariant: tokens.lineStrong,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: tokens.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.floor,
      canvasColor: tokens.floor,
      dividerColor: tokens.line,
      fontFamily: PulsoFonts.body,
      extensions: [tokens],
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: PulsoFonts.display,
          fontSize: 72,
          fontWeight: FontWeight.w800,
          height: 0.88,
          letterSpacing: -2.4,
          color: tokens.chalk,
        ),
        headlineLarge: TextStyle(
          fontFamily: PulsoFonts.display,
          fontSize: 48,
          fontWeight: FontWeight.w800,
          height: 0.92,
          letterSpacing: -1.3,
          color: tokens.chalk,
        ),
        headlineMedium: TextStyle(
          fontFamily: PulsoFonts.display,
          fontSize: 30,
          fontWeight: FontWeight.w700,
          height: 1,
          color: tokens.chalk,
        ),
        titleLarge: TextStyle(
          fontFamily: PulsoFonts.display,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: tokens.chalk,
        ),
        titleMedium: TextStyle(
          fontFamily: PulsoFonts.body,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: tokens.chalk,
        ),
        bodyLarge: TextStyle(
          fontFamily: PulsoFonts.body,
          fontSize: 16,
          height: 1.4,
          color: tokens.chalk,
        ),
        bodyMedium: TextStyle(
          fontFamily: PulsoFonts.body,
          fontSize: 14,
          height: 1.4,
          color: tokens.chalk,
        ),
        bodySmall: TextStyle(
          fontFamily: PulsoFonts.body,
          fontSize: 12,
          height: 1.35,
          color: tokens.muted,
        ),
        labelLarge: TextStyle(
          fontFamily: PulsoFonts.body,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: tokens.chalk,
        ),
        labelMedium: TextStyle(
          fontFamily: PulsoFonts.mono,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: tokens.muted,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.raised,
        labelStyle: TextStyle(color: tokens.chalkDim),
        hintStyle: TextStyle(color: tokens.muted2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: tokens.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: tokens.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: tokens.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: tokens.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: tokens.danger, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.chalk,
        contentTextStyle: TextStyle(
          color: tokens.floor,
          fontFamily: PulsoFonts.body,
          fontWeight: FontWeight.w700,
        ),
        shape: const RoundedRectangleBorder(),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: tokens.line),
        ),
      ),
    );
  }
}

class PulsoThemeScope extends ConsumerWidget {
  const PulsoThemeScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(appearanceProvider);
    final brightness = preference.resolveBrightness(
      MediaQuery.platformBrightnessOf(context),
    );
    final tokens = PulsoTokens.resolve(preference.palette, brightness);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedTheme(
      data: PulsoThemeFactory.build(tokens),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: child,
    );
  }
}
