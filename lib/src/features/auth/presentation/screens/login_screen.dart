import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/sync_status_chip.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/window/window_manager.dart';
import '../../../../core/localization/locale_provider.dart';
import '../state/auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  static const _devEmail = 'william870523@gmail.com';
  static const _devPassword = 'Root2014*';

  @override
  void initState() {
    super.initState();
    assert(() {
      _emailController.text = _devEmail;
      _passwordController.text = _devPassword;
      return true;
    }());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen for Auth Errors
    ref.listen<AsyncValue>(authProvider, (_, state) {
      if (state.hasError && !state.isLoading) {
        final l10n = AppLocalizations.of(context)!;
        final msg =
            _mapAuthError(l10n, state.error.toString()) ??
            state.error.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg.replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final l10n = AppLocalizations.of(context)!;
    final rawErrorText = authState.hasError
        ? authState.error.toString().replaceFirst('Exception: ', '')
        : null;
    final errorText = _mapAuthError(l10n, rawErrorText);
    final isDark = NeumorphicTheme.isUsingDark(context);
    // Use the theme's base color directly
    final kNeuBackground = NeumorphicTheme.baseColor(context);

    Future<void> submitLogin() async {
      if (authState.isLoading) return;
      if (!_formKey.currentState!.validate()) {
        return;
      }
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      await ref.read(authProvider.notifier).login(email, password);
      final user = ref.read(authProvider).asData?.value;
      if (user == null || !context.mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }

    return Scaffold(
      backgroundColor: kNeuBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;

          return Stack(
            fit: StackFit.expand,
            children: [
              // --- 1. Global Background Image ---
              if (isDesktop)
                Image.asset(
                  'assets/images/gym_bg_2.jpg',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(color: Color(0xFF0F172A)),
                ),

              // --- 2. Smooth Transition Gradient (Blue -> NeuBackground) ---
              if (isDesktop)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: const [0.0, 0.3, 0.8, 1.0],
                      colors: isDark
                          ? [
                              Colors.black.withValues(alpha: 0.9), // Deep Dark
                              const Color(0xFF1E1E1E).withValues(alpha: 0.95),
                              kNeuBackground.withValues(alpha: 0.9),
                              kNeuBackground,
                            ]
                          : [
                              const Color(
                                0xFF1E3A8A,
                              ).withValues(alpha: 0.95), // Deep Blue
                              const Color(
                                0xFF0F172A,
                              ).withValues(alpha: 0.9), // Dark Slate
                              kNeuBackground.withValues(
                                alpha: 0.8,
                              ), // Fading to NeuBase
                              kNeuBackground, // Solid NeuBase
                            ],
                    ),
                  ),
                )
              else
                ColoredBox(color: kNeuBackground),

              // --- 3. Content Layer ---
              Row(
                children: [
                  // Left Panel Content
                  if (isDesktop)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(64.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            const Text(
                              'Diamond Gym',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Tagline
                            Text(
                              l10n.loginTagline,
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                                color: Colors.white,
                                letterSpacing: -1.0,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Description
                            Text(
                              l10n.loginDescription,
                              style: TextStyle(
                                fontSize: 18,
                                color: Color(0xFFCBD5E1), // slate-300
                                height: 1.6,
                              ),
                            ),

                            const SizedBox(height: 48),

                            // Features
                            // Features
                            Row(
                              children: [
                                _buildFeatureBadge(
                                  Icons.analytics_outlined,
                                  l10n.loginFeatureReports,
                                ),
                                const SizedBox(width: 24),
                                _buildFeatureBadge(
                                  Icons.security_outlined,
                                  l10n.loginFeatureAccess,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Right Panel (Login Form)
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 32),
                              const SizedBox(height: 8),
                              // Logo
                              Align(
                                alignment: Alignment.center,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 24.0),
                                  child: Image.asset(
                                    'assets/images/diamond_logo.png',
                                    height: 80,
                                    filterQuality: FilterQuality.high,
                                    errorBuilder:
                                        (context, error, stackTrace) => Icon(
                                          Icons.diamond_outlined,
                                          size: 72,
                                          color:
                                              NeumorphicTheme.defaultTextColor(
                                                context,
                                              ),
                                        ),
                                    // Make logo adapt or keep original colors if it's an image that works on both
                                    // Removing color override if it's a colored logo
                                  ),
                                ),
                              ),

                              // Header
                              Text(
                                l10n.loginTitle,
                                textAlign: isDesktop
                                    ? TextAlign.left
                                    : TextAlign.center,
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: NeumorphicTheme.defaultTextColor(
                                    context,
                                  ),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.loginSubtitle,
                                textAlign: isDesktop
                                    ? TextAlign.left
                                    : TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: NeumorphicTheme.defaultTextColor(
                                    context,
                                  ).withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 32),

                              const SizedBox(height: 32),

                              // Form
                              CallbackShortcuts(
                                bindings: {
                                  const SingleActivator(
                                    LogicalKeyboardKey.enter,
                                  ): submitLogin,
                                  const SingleActivator(
                                    LogicalKeyboardKey.numpadEnter,
                                  ): submitLogin,
                                },
                                child: Focus(
                                  autofocus: true,
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Email
                                        _buildLabel(
                                          context,
                                          l10n.loginUsernameLabel,
                                        ),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: _emailController,
                                          textInputAction: TextInputAction.next,
                                          onFieldSubmitted: (_) {
                                            FocusScope.of(context).nextFocus();
                                          },
                                          validator: (v) =>
                                              (v == null || v.trim().isEmpty)
                                              ? l10n.loginUsernameRequired
                                              : null,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color:
                                                NeumorphicTheme.defaultTextColor(
                                                  context,
                                                ),
                                          ),
                                          decoration: _inputDecoration(
                                            context: context,
                                            hint: l10n.loginUsernameHint,
                                            icon: Icons.person_outline,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 4,
                                            top: 4,
                                          ),
                                          child: Text(
                                            l10n.loginUsernameHelper,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  NeumorphicTheme.defaultTextColor(
                                                    context,
                                                  ).withValues(alpha: 0.5),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 24),

                                        // Password
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: _buildLabel(
                                                context,
                                                l10n.loginPasswordLabel,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Flexible(
                                              child: TextButton(
                                                onPressed: () {},
                                                style: TextButton.styleFrom(
                                                  padding: EdgeInsets.zero,
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                                child: Text(
                                                  l10n.loginForgotPassword,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(
                                                      0xFF135BEC,
                                                    ), // primary
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),

                                        TextFormField(
                                          controller: _passwordController,
                                          textInputAction: TextInputAction.done,
                                          onFieldSubmitted: (_) =>
                                              submitLogin(),
                                          validator: (v) =>
                                              (v == null || v.isEmpty)
                                              ? l10n.loginPasswordRequired
                                              : null,
                                          obscureText: true,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color:
                                                NeumorphicTheme.defaultTextColor(
                                                  context,
                                                ),
                                          ),
                                          decoration: _inputDecoration(
                                            context: context,
                                            hint: '********',
                                            icon: Icons.lock_outline,
                                            suffixIcon:
                                                Icons.visibility_off_outlined,
                                          ),
                                        ),

                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 4,
                                            top: 4,
                                          ),
                                          child: Text(
                                            l10n.loginPasswordHelper,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  NeumorphicTheme.defaultTextColor(
                                                    context,
                                                  ).withValues(alpha: 0.5),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 24),

                                        // Error Message
                                        if (authState.hasError)
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            margin: const EdgeInsets.only(
                                              bottom: 20,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEE2E2),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: const Color(0xFFFECACA),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.error_outline,
                                                  color: Color(0xFFDC2626),
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    errorText ??
                                                        l10n.loginErrorUnexpected,
                                                    style: const TextStyle(
                                                      color: Color(0xFFDC2626),
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        // Submit Button (Neumorphic)
                                        SizedBox(
                                          height: 50,
                                          child: NeumorphicButton(
                                            onPressed: authState.isLoading
                                                ? null
                                                : submitLogin,
                                            style: NeumorphicStyle(
                                              color: const Color(
                                                0xFF135BEC,
                                              ), // Primary Blue
                                              // High Contrast Shadows for "Pop"
                                              shadowLightColor: isDark
                                                  ? const Color(
                                                      0xFF60A5FA,
                                                    ) // Bright Blue Highlight (Dark Mode)
                                                  : Colors
                                                        .white, // Pure White Highlight (Light Mode)

                                              shadowDarkColor: isDark
                                                  ? Colors.black
                                                  : const Color(
                                                      0xFF002171,
                                                    ), // Deep Navy Shadow (Light Mode)

                                              depth: 8, // Very noticeable depth
                                              intensity: 1, // Max intensity
                                              surfaceIntensity:
                                                  0.5, // Glossy curve
                                              shape: NeumorphicShape.concave,
                                              boxShape:
                                                  NeumorphicBoxShape.roundRect(
                                                    BorderRadius.circular(12),
                                                  ),
                                              lightSource: LightSource.topLeft,
                                            ),
                                            padding: EdgeInsets.zero,
                                            child: Center(
                                              child: authState.isLoading
                                                  ? const SizedBox(
                                                      height: 20,
                                                      width: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Colors.white,
                                                          ),
                                                    )
                                                  : Text(
                                                      l10n.loginButton,
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 32),
                              Divider(
                                height: 32,
                                color: NeumorphicTheme.defaultTextColor(
                                  context,
                                ).withValues(alpha: 0.2),
                              ),

                              // System Status Footer - CLEAN VERSION
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        l10n.systemStatusLabel.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              NeumorphicTheme.defaultTextColor(
                                                context,
                                              ).withValues(alpha: 0.5),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const Flexible(
                                        child: SyncStatusChip(compact: true),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'v2.4.0-stable build.892',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: NeumorphicTheme.defaultTextColor(
                                        context,
                                      ).withValues(alpha: 0.4),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Appearance must remain below Navigator's Overlay. On desktop
              // language stays in the native title bar; web/mobile show both.
              Positioned(
                top: 12,
                right: 16,
                child: isDesktopPlatform
                    ? const PulsoThemeScope(child: PulsoAppearanceMenuButton())
                    : _LoginToggles(isDark: isDark),
              ),
            ],
          );
        },
      ),
    );
  }

  String? _mapAuthError(AppLocalizations l10n, String? rawMessage) {
    if (rawMessage == null || rawMessage.trim().isEmpty) {
      return null;
    }

    int? retryAfterSeconds;
    String? errorCode;

    if (rawMessage.startsWith('error_code:')) {
      final parts = rawMessage.split(':');
      if (parts.length >= 2) {
        errorCode = parts[1].trim();
      }
      if (parts.length >= 3) {
        retryAfterSeconds = int.tryParse(parts[2].trim());
      }
    }

    if (errorCode != null && errorCode.isNotEmpty) {
      switch (errorCode) {
        case 'INVALID_CREDENTIALS':
          return l10n.invalidCredentialsError;
        case 'USER_INACTIVE':
          return l10n.userInactiveError;
        case 'TOO_MANY_ATTEMPTS':
          if (retryAfterSeconds != null) {
            return l10n.tooManyAttemptsError(retryAfterSeconds);
          }
          return l10n.tooManyAttemptsErrorGeneric;
        case 'MISSING_IDENTIFIER':
          return l10n.loginUsernameRequired;
        case 'INVALID_PAYLOAD':
        case 'INTERNAL_ERROR':
          return l10n.loginErrorUnexpected;
      }
    }

    final normalized = rawMessage.toLowerCase();

    if (normalized.contains('too many failed attempts')) {
      final match = RegExp(r'(\d+)').firstMatch(rawMessage);
      if (match != null) {
        return l10n.tooManyAttemptsError(int.parse(match.group(1)!));
      }
      return l10n.tooManyAttemptsErrorGeneric;
    }

    if (normalized.contains('invalid credentials') ||
        normalized.contains('credenciales')) {
      return l10n.invalidCredentialsError;
    }

    if (normalized.contains('inactive user') ||
        normalized.contains('account is inactive') ||
        normalized.contains('inactivo')) {
      return l10n.userInactiveError;
    }

    if (normalized.contains('network') || normalized.contains('red')) {
      return l10n.networkError;
    }

    return rawMessage;
  }

  // --- Helper Methods RESTORED ---

  Widget _buildFeatureBadge(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 24), // Always white on gradient
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white, // Always white on gradient
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: NeumorphicTheme.defaultTextColor(context),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String hint,
    required IconData icon,
    IconData? suffixIcon,
  }) {
    final textColor = NeumorphicTheme.defaultTextColor(context);
    final isDark = NeumorphicTheme.isUsingDark(context);

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4)),
      prefixIcon: Icon(icon, color: textColor.withValues(alpha: 0.5)),
      suffixIcon: suffixIcon != null
          ? Icon(suffixIcon, color: textColor.withValues(alpha: 0.5))
          : null,
      filled: true,
      fillColor: isDark ? Colors.grey[900] : Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: textColor.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF135BEC), width: 2),
      ),
    );
  }
}

/// Theme & language toggles shown on the login screen ONLY on web (where there
/// is no desktop title bar to host them). Translucent blurred background so it
/// stays visible over the login's background image.
class _LoginToggles extends ConsumerWidget {
  final bool isDark;

  const _LoginToggles({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final iconColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final bgColor = (isDark ? Colors.black : Colors.white).withValues(
      alpha: 0.35,
    );

    Widget button({
      required Widget child,
      required VoidCallback onTap,
      required BorderRadius radius,
    }) {
      return ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Material(
            color: bgColor,
            child: InkWell(onTap: onTap, borderRadius: radius, child: child),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const PulsoThemeScope(child: PulsoAppearanceMenuButton()),
        const SizedBox(width: 8),
        button(
          onTap: () => ref.read(localeProvider.notifier).toggleLocale(),
          radius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.language_outlined, size: 16, color: iconColor),
                const SizedBox(width: 4),
                Text(
                  locale.languageCode.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
