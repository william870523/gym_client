import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../window_manager.dart';
import '../../localization/locale_provider.dart';
import '../../theme/pulso/appearance_provider.dart';

class DesktopWindowFrame extends ConsumerWidget {
  final Widget child;

  const DesktopWindowFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final isDark =
        appearance.resolveBrightness(
          MediaQuery.platformBrightnessOf(context),
        ) ==
        Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);

    // 1. If Web/Mobile, return Custom Web Frame (Overlay Header)
    // NOTE: On web there are no native window controls, so the theme/language
    // toggles are rendered inside the in-content headers (DashboardHeader /
    // LoginScreen) instead of here. This overlay stays decorative (non-interactive)
    // to avoid overlapping real content.
    if (!isDesktopPlatform) {
      return Stack(
        children: [
          child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: true,
              child: _buildWebTitleBar(context, ref, isDark, textColor),
            ),
          ),
        ],
      );
    }

    // 2. If Desktop, return Custom Frame with Window Controls
    return WindowBorder(
      color: Colors.transparent,
      width: 0,
      child: Stack(
        children: [
          child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTitleBar(context, ref, isDark, textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildWebTitleBar(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    Color textColor,
  ) {
    return Container(
      height: 46,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ), // Add padding for Web
      child: const Material(
        type: MaterialType.transparency,
        child: Row(
          children: [
            // Left Spacer (pushes controls to the right)
            Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    Color textColor,
  ) {
    return Container(
      height: 46, // Expanded height for better visibility
      color: Colors.transparent, // Seamless integration
      child: WindowTitleBarBox(
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              // 1. Draggable Background (captures drags everywhere except where buttons are)
              // We leave the left 260px open so the DashboardSidebar toggle button can receive clicks
              Positioned.fill(left: 260, child: MoveWindow()),

              // 2. Perfectly Centered Branding
              // Wrapped in MoveWindow to allow dragging when clicking/holding the logo/text
              Center(
                child: MoveWindow(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Diamond ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 6.0,
                        ),
                        child: Image.asset(
                          'assets/images/diamond_logo.png',
                          height: 22,
                        ),
                      ),
                      Text(
                        ' Gym',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Right-aligned Controls (Theme + Language Toggles + Window Buttons)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Theme & Language Toggles
                    _TitleBarToggleButtons(isDark: isDark),
                    const SizedBox(width: 8),
                    // Window Buttons
                    WindowButtons(isDark: isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WindowButtons extends StatelessWidget {
  final bool isDark;

  const WindowButtons({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final iconColor = isDark ? Colors.white : const Color(0xFF111827);
    final hoverColor = isDark ? Colors.white24 : const Color(0xFFE5E7EB);

    final colors = WindowButtonColors(
      iconNormal: iconColor,
      mouseOver: hoverColor,
      mouseDown: isDark ? Colors.white38 : const Color(0xFFD1D5DB),
      iconMouseOver: iconColor,
      iconMouseDown: iconColor,
    );

    final closeColors = WindowButtonColors(
      mouseOver: const Color(0xFFD32F2F),
      mouseDown: const Color(0xFFB71C1C),
      iconNormal: iconColor,
      iconMouseOver: Colors.white,
    );

    return Row(
      children: [
        MinimizeWindowButton(colors: colors),
        MaximizeWindowButton(colors: colors),
        CloseWindowButton(colors: closeColors),
      ],
    );
  }
}

/// Theme (light/dark) and language (es/en) toggles rendered inside the
/// custom title bar so they no longer overlap the window controls.
///
/// The native title bar only hosts controls that do not require Navigator's
/// Overlay. Appearance lives inside Login/Dashboard, where popup menus are safe.
class _TitleBarToggleButtons extends ConsumerWidget {
  final bool isDark;

  const _TitleBarToggleButtons({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final iconColor = isDark ? Colors.white : const Color(0xFF111827);
    // Translucent background so the buttons stay visible over any content.
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Language Toggle (stadium)
        _TitleBarButton(
          isDark: isDark,
          backgroundColor: bgColor,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          onTap: () => ref.read(localeProvider.notifier).toggleLocale(),
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
      ],
    );
  }
}

/// A compact hover-aware button used by [_TitleBarToggleButtons].
class _TitleBarButton extends StatefulWidget {
  final bool isDark;
  final Color backgroundColor;
  final OutlinedBorder shape;
  final EdgeInsetsGeometry padding;
  final VoidCallback onTap;
  final Widget child;

  const _TitleBarButton({
    required this.isDark,
    required this.backgroundColor,
    required this.shape,
    required this.padding,
    required this.onTap,
    required this.child,
  });

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: ShapeDecoration(
            color: _hover
                ? widget.backgroundColor.withValues(alpha: 1)
                : widget.backgroundColor,
            shape: widget.shape,
          ),
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );
  }
}
