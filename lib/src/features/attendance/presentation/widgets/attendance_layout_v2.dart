import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'entry_register_section.dart';
import 'access_control_tabs.dart';
import 'attendance_sidebar.dart';

class AttendanceLayoutV2 extends StatelessWidget {
  const AttendanceLayoutV2({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Tailwind Colors
    final slate200 = isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0);
    final slate400 = const Color(0xFF94A3B8);

    final success = const Color(0xFF22C55E);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF101622)
          : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // BODY CONTENT (3 Columns)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Register Section (Left) - Flex 3 (in HTML was flex-[3], likely containing both left and middle)
                  // Wait, HTML structure:
                  // main -> div(flex-3) -> [Section(Register), Section(Tabs)]
                  //      -> aside
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: const [
                        // Register Section
                        Expanded(
                          flex: 4, // Adjust ratio as needed
                          child: EntryRegisterSection(),
                        ),
                        SizedBox(height: 16),
                        // Tabs Section
                        Expanded(flex: 5, child: AccessControlTabs()),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // 2. Sidebar (Right)
                  const AttendanceSidebar(),
                ],
              ),
            ),
          ),

          // FOOTER
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(top: BorderSide(color: slate200)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '© 2023 DIAMOND GYM MANAGEMENT SYSTEM | TERMINAL DE RECEPCIÓN 01',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: slate400,
                    letterSpacing: 1.0,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'HARDWARE OK',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: slate400,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'V4.2.0-V1A',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: slate400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
