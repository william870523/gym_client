import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'src/core/window/window_manager.dart';
import 'src/core/window/widgets/desktop_window_frame.dart';
import 'src/features/auth/presentation/screens/login_screen.dart';

import 'src/l10n/app_localizations.dart';

import 'src/core/theme/pulso/appearance_provider.dart';
import 'src/core/theme/pulso/pulso_theme.dart';
import 'src/core/theme/pulso/pulso_tokens.dart';
import 'src/core/localization/locale_provider.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'dart:async';
import 'src/core/utils/error_logger.dart';
import 'src/core/config/env.dart';
import 'src/core/time/app_clock.dart';
import 'src/core/utils/datetime_zone.dart';

void main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      if (!kIsWeb) {
        await dotenv.load(fileName: ".env", isOptional: true);
      }
      initTimeZone();
      try {
        await appClock.synchronize(Env.baseUrl);
      } catch (_) {
        // La aplicación puede operar offline con el reloj del sistema.
      }
      appClock.startPeriodicSync();
      await ErrorLogger.init();

      windowManager.init(); // Initialize bitsdojo if desktop
      runApp(const ProviderScope(child: MyApp()));
    },
    (error, stack) {
      ErrorLogger.logError(error, stack);
    },
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key, this.useDesktopWindowFrame = true});

  final bool useDesktopWindowFrame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final locale = ref.watch(localeProvider);
    final lightTokens = PulsoTokens.resolve(
      appearance.palette,
      Brightness.light,
    );
    final darkTokens = PulsoTokens.resolve(appearance.palette, Brightness.dark);

    return NeumorphicApp(
      debugShowCheckedModeBanner: false,
      title: 'Diamond Gym',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      themeMode: appearance.themeMode,
      materialTheme: PulsoThemeFactory.build(lightTokens),
      materialDarkTheme: PulsoThemeFactory.build(darkTokens),
      theme: NeumorphicThemeData(
        baseColor: lightTokens.floor,
        lightSource: LightSource.topLeft,
        depth: 2,
        intensity: 0.42,
        accentColor: lightTokens.accent,
        variantColor: lightTokens.chalkDim,
        defaultTextColor: lightTokens.chalk,
      ),
      darkTheme: NeumorphicThemeData(
        baseColor: darkTokens.floor,
        lightSource: LightSource.topLeft,
        depth: 2,
        intensity: 0.35,
        shadowLightColor: darkTokens.lineStrong,
        shadowDarkColor: darkTokens.floor2,
        defaultTextColor: darkTokens.chalk,
        accentColor: darkTokens.accent,
        variantColor: darkTokens.chalkDim,
      ),

      // Wrap the Shell
      builder: (context, child) {
        return useDesktopWindowFrame
            ? DesktopWindowFrame(child: child!)
            : child!;
      },
      home: const LoginScreen(),
    );
  }
}
