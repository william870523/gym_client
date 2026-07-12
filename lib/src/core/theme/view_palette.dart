import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pluto_grid/pluto_grid.dart';

import 'app_colors.dart';

class ViewPalette {
  const ViewPalette._({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceSoft,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  factory ViewPalette.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ViewPalette._(
      isDark: isDark,
      background: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      surface: isDark ? const Color(0xFF1A2233) : AppColors.lightSurface,
      surfaceAlt: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      surfaceSoft: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      border: isDark ? const Color(0xFF2A3447) : AppColors.lightBorder,
      textPrimary: isDark
          ? AppColors.darkTextPrimary
          : AppColors.lightTextPrimary,
      textSecondary: isDark
          ? AppColors.darkTextSecondary
          : AppColors.lightTextSecondary,
      textMuted: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
    );
  }

  final bool isDark;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceSoft;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  Color get primary => AppColors.primary;
  Color get success => AppColors.success;
  Color get error => AppColors.error;
  Color get warning => AppColors.warning;

  Color get successBg =>
      isDark ? const Color(0xFF052E1A) : const Color(0xFFECFDF5);
  Color get successBorder =>
      isDark ? const Color(0xFF14532D) : const Color(0xFFA7F3D0);
  Color get successText =>
      isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);

  Color get warningBg =>
      isDark ? const Color(0xFF3B2502) : const Color(0xFFFFFBEB);
  Color get warningBorder =>
      isDark ? const Color(0xFF92400E) : const Color(0xFFFCD34D);
  Color get warningText =>
      isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);

  Color get dangerBg =>
      isDark ? const Color(0xFF3F1518) : const Color(0xFFFEF2F2);
  Color get dangerBorder =>
      isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA);
  Color get dangerText =>
      isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);

  Color get oddRow =>
      isDark ? const Color(0xFF1F2937) : const Color(0xFFFAFAFA);

  BoxDecoration panelDecoration({double radius = 12, bool elevated = true}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.02),
                blurRadius: isDark ? 10 : 4,
                offset: const Offset(0, 2),
              ),
            ]
          : const [],
    );
  }

  InputDecoration searchDecoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.inter(
        color: textSecondary.withValues(alpha: 0.8),
        fontSize: 14,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primary, width: 1.2),
      ),
    );
  }

  ButtonStyle secondaryButtonStyle({double radius = 8}) {
    return OutlinedButton.styleFrom(
      foregroundColor: textPrimary,
      backgroundColor: surface,
      side: BorderSide(color: border),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
    );
  }

  ButtonStyle primaryButtonStyle({double radius = 8}) {
    return ElevatedButton.styleFrom(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shadowColor: primary.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
    );
  }

  ButtonStyle iconButtonStyle({double radius = 8}) {
    return IconButton.styleFrom(
      backgroundColor: surface,
      foregroundColor: textPrimary,
      side: BorderSide(color: border),
      padding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  PlutoGridConfiguration gridConfiguration({
    double rowHeight = 60,
    double columnHeight = 50,
    bool scaleColumns = false,
    Color? oddRowColor,
    Color? evenRowColor,
  }) {
    return PlutoGridConfiguration(
      style: PlutoGridStyleConfig(
        gridBackgroundColor: surface,
        rowColor: surface,
        gridBorderColor: Colors.transparent,
        borderColor: Colors.transparent,
        oddRowColor: oddRowColor ?? oddRow,
        evenRowColor: evenRowColor ?? surface,
        activatedColor: primary.withValues(alpha: 0.1),
        iconColor: textSecondary,
        columnTextStyle: GoogleFonts.inter(
          color: textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        cellTextStyle: GoogleFonts.inter(color: textPrimary, fontSize: 13),
        rowHeight: rowHeight,
        columnHeight: columnHeight,
      ),
      columnSize: PlutoGridColumnSizeConfig(
        autoSizeMode: scaleColumns
            ? PlutoAutoSizeMode.scale
            : PlutoAutoSizeMode.none,
      ),
    );
  }
}
