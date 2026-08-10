import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/window/window_manager.dart'; // IsDesktop check
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../../core/widgets/sync_status_chip.dart';
import '../../../gyms/presentation/widgets/sede_selector.dart';

class DashboardHeader extends ConsumerWidget {
  final bool isDark;
  final Color surfaceColor;
  final Color borderColor;
  final String title;
  final String role;
  final VoidCallback onToggleRole;
  final VoidCallback onLogout;
  final VoidCallback? onMenuPressed;
  final Widget? headerAction;

  const DashboardHeader({
    super.key,
    required this.isDark,
    required this.surfaceColor,
    required this.borderColor,
    required this.title,
    required this.role,
    required this.onToggleRole,
    required this.onLogout,
    this.onMenuPressed,
    this.headerAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Desktop: Add padding for Window Frame (Title Bar)
    final double topPadding = isDesktopPlatform ? 28.0 : 0.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16 + topPadding,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Title / Breadcrumb
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final hasMenu = onMenuPressed != null;
                final showTitle =
                    title.isNotEmpty &&
                    (!hasMenu || constraints.maxWidth >= 120);
                return Row(
                  children: [
                    if (hasMenu)
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 40,
                            height: 40,
                          ),
                          icon: Icon(
                            Icons.menu,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF475569),
                          ),
                          onPressed: onMenuPressed,
                        ),
                      ),
                    if (showTitle) ...[
                      if (hasMenu) const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),

          // Status Indicators (API / Sync)
          if (MediaQuery.of(context).size.width > 1024) ...[
            SyncStatusChip(isDark: isDark, showDetails: true),
            const SizedBox(width: 24),
          ],

          // Appearance opens a popup and therefore stays under Navigator's
          // Overlay instead of the native title-bar layer.
          const PulsoThemeScope(child: PulsoAppearanceMenuButton()),
          const SizedBox(width: 8),
          // Language remains in the native bar on desktop. Web/mobile expose it
          // inline because they do not have native window controls.
          if (!isDesktopPlatform) ...[
            TextButton(
              onPressed: () {
                ref.read(localeProvider.notifier).toggleLocale();
              },
              style: TextButton.styleFrom(
                minimumSize: const Size(36, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                ref.watch(localeProvider).languageCode.toUpperCase(),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          // Sede activa (docs/MULTI_SEDE.md §3.4). Se esconde solo cuando hay
          // una sola sede, así que no estorba en una instalación normal.
          const SedeSelector(compact: true),

          // Divider
          Container(height: 24, width: 1, color: borderColor),
          const SizedBox(width: 16),

          // Logout Button
          InkWell(
            onTap: onLogout,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFF3F4F6), // gray-100
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.logout,
                    size: 20,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                  if (MediaQuery.of(context).size.width > 640) ...[
                    const SizedBox(width: 8),
                    Text(
                      "Salir",
                      style: GoogleFonts.inter(
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF334155),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(width: 24),

          // Profile Picture
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade200,
                  border: Border.all(color: Colors.transparent, width: 2),
                ),
                child: Icon(
                  Icons.person,
                  color: Colors.grey.shade400,
                  size: 24,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green.shade500,
                    border: Border.all(color: Colors.white, width: 2),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
