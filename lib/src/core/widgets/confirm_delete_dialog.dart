import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A premium styled confirmation dialog for delete actions.
/// Matches the Diamond Gym design system with neon accent colors.
class ConfirmDeleteDialog extends StatelessWidget {
  final String title;
  final String itemName;
  final String? description;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  const ConfirmDeleteDialog({
    super.key,
    this.title = 'Confirmar Eliminación',
    required this.itemName,
    this.description,
    required this.onConfirm,
    this.onCancel,
  });

  /// Shows the dialog and returns true if confirmed, false otherwise.
  static Future<bool> show({
    required BuildContext context,
    String title = 'Confirmar Eliminación',
    required String itemName,
    String? description,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ConfirmDeleteDialog(
        title: title,
        itemName: itemName,
        description: description,
        onConfirm: () => Navigator.pop(ctx, true),
        onCancel: () => Navigator.pop(ctx, false),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Design tokens
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final backgroundColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    // Neon accent colors
    const dangerColor = Color(0xFFEF4444); // Red
    const dangerBgLight = Color(0xFFFEE2E2); // Red-100
    const dangerBgDark = Color(0xFF7F1D1D); // Red-900

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 420,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with danger icon
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? dangerBgDark.withValues(alpha: 0.3)
                    : dangerBgLight,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? dangerColor.withValues(alpha: 0.3)
                        : dangerColor.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Animated danger icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isDark
                          ? dangerColor.withValues(alpha: 0.2)
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: dangerColor.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: dangerColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.delete_forever_rounded,
                      size: 32,
                      color: dangerColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: dangerColor,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: textMuted,
                        height: 1.5,
                      ),
                      children: [
                        const TextSpan(text: '¿Estás seguro de eliminar '),
                        TextSpan(
                          text: '"$itemName"',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: textMain,
                          ),
                        ),
                        const TextSpan(text: '?'),
                      ],
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      description!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 13, color: textMuted),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Warning message
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Esta acción no se puede deshacer.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? const Color(0xFFFCD34D)
                                  : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  // Cancel button
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          onCancel ?? () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textMain,
                        side: BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Delete button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(
                        'Eliminar',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dangerColor,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: dangerColor.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
