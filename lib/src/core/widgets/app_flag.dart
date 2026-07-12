import 'dart:typed_data';

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'base64_image.dart';

class AppFlag extends StatelessWidget {
  const AppFlag({
    super.key,
    this.base64String,
    this.bytes,
    this.countryCode,
    this.fallbackCode,
    this.width = 30,
    this.height = 20,
    this.borderRadius = 2,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.high,
    this.fallback,
    this.showFrame = true,
  }) : assert(width > height, 'Las banderas deben usar un marco rectangular.');

  final String? base64String;
  final Uint8List? bytes;
  final String? countryCode;
  final String? fallbackCode;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final Widget? fallback;
  final bool showFrame;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final frameColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final child = _buildContent(context);

    if (!showFrame) {
      return child;
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: frameColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _buildContent(BuildContext context) {
    if (bytes != null) {
      return Image.memory(
        bytes!,
        width: width,
        height: height,
        fit: fit,
        filterQuality: filterQuality,
        gaplessPlayback: true,
      );
    }

    if (base64String != null && base64String!.isNotEmpty) {
      return Base64Image(
        base64String: base64String!,
        width: width,
        height: height,
        fit: fit,
        filterQuality: filterQuality,
        placeholder: fallback ?? _buildFallback(context),
      );
    }

    if (countryCode != null && countryCode!.length == 2) {
      return CountryFlag.fromCountryCode(
        countryCode!,
        theme: ImageTheme(
          width: width,
          height: height,
          shape: RoundedRectangle(borderRadius),
        ),
      );
    }

    return fallback ?? _buildFallback(context);
  }

  Widget _buildFallback(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = (fallbackCode ?? '').trim().toUpperCase();
    if (label.isNotEmpty) {
      final shortLabel = label.length > 2 ? label.substring(0, 2) : label;
      return Center(
        child: Text(
          shortLabel,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
          ),
        ),
      );
    }

    return Icon(
      Icons.flag_outlined,
      size: 16,
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
    );
  }
}
