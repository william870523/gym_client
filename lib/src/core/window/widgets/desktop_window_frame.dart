import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../window_manager.dart';
import '../../theme/theme_provider.dart';

class DesktopWindowFrame extends ConsumerWidget {
  final Widget child;

  const DesktopWindowFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);

    // 1. If Web/Mobile, return Custom Web Frame (Overlay Header)
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
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          children: [
            // Left Spacer (pushes controls to the right)
            const Spacer(),
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
              Positioned.fill(child: MoveWindow()),

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

              // 3. Right-aligned Controls (Theme Switch + Window Buttons)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
