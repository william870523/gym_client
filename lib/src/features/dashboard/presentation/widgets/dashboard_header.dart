import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/window/window_manager.dart'; // IsDesktop check
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../l10n/app_localizations.dart';

class DashboardHeader extends ConsumerWidget {
  final bool isDark;
  final Color surfaceColor;
  final Color borderColor;
  final String title;
  final String role;
  final VoidCallback onToggleRole;
  final VoidCallback onLogout;
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
    this.headerAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    // Desktop: Add padding for Window Frame (Title Bar)
    // Adjusted: Reduced from 40.0 to 28.0 to prevent "too wide" header look
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
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Title / Breadcrumb (Hidden on mobile if Sidebar is drawer)
          Expanded(
            child: Row(
              children: [
                if (MediaQuery.of(context).size.width < 768)
                  IconButton(
                    icon: Icon(Icons.menu, color: textMuted),
                    onPressed: () {},
                  ),

                Text(
                  title,
                  style: TextStyle(
                    color: textMain,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 32),

                // Search Bar (Flexible)
                if (MediaQuery.of(context).size.width > 600)
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Icon(Icons.search, color: textMuted, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              style: TextStyle(color: textMain, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: l10n.searchMembersHint,
                                hintStyle: TextStyle(color: textMuted),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Right Actions
          Row(
            children: [
              if (headerAction != null) ...[
                headerAction!,
                const SizedBox(width: 16),
                Container(
                  width: 1,
                  height: 24,
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                ),
                const SizedBox(width: 16),
              ],
              // Theme Toggle Notifier
              IconButton(
                onPressed: () {
                  ref.read(themeProvider.notifier).toggleTheme();
                },
                tooltip: l10n.toggleThemeTooltip,
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: isDark ? Colors.amber : Colors.blueGrey,
                ),
              ),
              const SizedBox(width: 8),

              Tooltip(
                message: l10n.toggleLanguageTooltip,
                child: TextButton(
                  onPressed: () {
                    ref.read(localeProvider.notifier).toggleLocale();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: textMuted,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.language, color: textMuted, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        locale.languageCode.toUpperCase(),
                        style: TextStyle(
                          color: textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Temporary Role Toggle for Demo
              IconButton(
                onPressed: onToggleRole,
                tooltip: l10n.switchRoleTooltip,
                icon: const Icon(Icons.swap_horiz, color: Colors.blue),
              ),
              const SizedBox(width: 8),

              _buildIconButton(
                Icons.notifications_none,
                textMuted,
                hasBadge: true,
              ),
              const SizedBox(width: 12),
              _buildIconButton(Icons.person_outline, textMuted),
              const SizedBox(width: 16),
              IconButton(
                onPressed: onLogout,
                tooltip: l10n.logoutTooltip,
                icon: const Icon(Icons.logout),
                color: Colors.redAccent,
              ),

              // Profile Circle
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade200,
                  image: const DecorationImage(
                    image: NetworkImage(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuDKxbGxTtKnzlRZvYXQIOlGOEST-PoeEarX3VzyNpxQxnsx9_NHzUKHqRkzLl9xp4pUu-5-IXXGejjC0drlQkWBeNyNpi6fMBnBBLldRlrO1_SK8-z5w2JTYlv253gdz6ZMF86lPRStpmc7AtF9rMKtYoNQnjzEaP1l_rxOB9jb05QZtvrNDCJRjcf81-n4S9f55x-MwNZ33odaKu_AYvaEOEwkYvwFXf1NWrlw-NBR9696FcXbcaYUONUR1FpWDn6cJqQsQ2_QuqU',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, Color color, {bool hasBadge = false}) {
    return Stack(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.transparent, // Hover handles in InkWell
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.transparent),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        if (hasBadge)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
