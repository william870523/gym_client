import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'src/core/window/window_manager.dart';
import 'src/core/window/widgets/desktop_window_frame.dart';
import 'src/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'src/l10n/app_localizations.dart';

import 'src/core/theme/theme_provider.dart';
import 'src/core/localization/locale_provider.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  windowManager.init(); // Initialize bitsdojo if desktop
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);

    return NeumorphicApp(
      debugShowCheckedModeBanner: false,
      title: 'Diamond Gym',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      themeMode: themeMode,
      theme: const NeumorphicThemeData(
        baseColor: Color(0xFFEFEEEE),
        lightSource: LightSource.topLeft,
        depth: 6,
        intensity: 0.8,
        // Material Theme Fallback for standard widgets
        accentColor: Color(0xFF135BEC),
        variantColor: Colors.black38,
      ),
      darkTheme: const NeumorphicThemeData(
        baseColor: Color(0xFF1E1E1E), // Dark Grey Base
        lightSource: LightSource.topLeft,
        depth: 4,
        intensity: 0.6,
        shadowLightColor: Colors.white24, // Subtle light in dark mode
        shadowDarkColor: Colors.black87,

        // Dark Mode Text/Icon Colors
        defaultTextColor: Colors.white,
        accentColor: Color(0xFF3B82F6), // Brighter Blue for Dark Mode
      ),

      // Wrap the Shell
      builder: (context, child) {
        return DesktopWindowFrame(child: child!);
      },
      home: const LoginScreen(),
    );
  }
}
