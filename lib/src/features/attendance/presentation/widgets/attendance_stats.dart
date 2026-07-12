import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AttendanceStats extends StatelessWidget {
  const AttendanceStats({super.key});

  @override
  Widget build(BuildContext context) {
    // Responsive grid: 1 column on small, 2 on med, 4 on large
    // We can use Wrap or LayoutBuilder. For simplicity and closest match to grid-cols-4:
    var width = MediaQuery.of(context).size.width;
    int crossAxisCount = 1;
    if (width > 640) crossAxisCount = 2; // sm
    if (width > 1024) crossAxisCount = 4; // lg

    // Colors
    final primary = const Color(0xFF135bec);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Simple Grid implementation using Wrap for fluidity or proper GridView
        // Given existing structure, let's use a Wrap or Flex logic to simulate properties
        // But standard GridView is easier.
        // Issue: GridView requires height.
        // Solution: Wrap with width calc.

        double gap = 16.0;
        double itemWidth =
            (constraints.maxWidth - (gap * (crossAxisCount - 1))) /
            crossAxisCount;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: itemWidth,
              child: _StatCard(
                title: "Total Ingresos",
                icon: Icons.trending_up,
                iconColor: Colors.green,
                content: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "142",
                      style: GoogleFonts.inter(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A), // slate-900
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade100),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "+12%",
                        style: GoogleFonts.inter(
                          color: Colors.green.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _StatCard(
                title: "Ocupación Actual",
                icon: Icons.groups, // closest to groups
                iconColor: primary,
                borderColor: primary.withValues(alpha: 0.2),
                backgroundColor: const Color(
                  0xFFEFF6FF,
                ).withValues(alpha: 0.3), // blue-50/30
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "45",
                          style: GoogleFonts.inter(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: primary,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            "/ 120 Capacidad",
                            style: GoogleFonts.inter(
                              color: const Color(0xFF94A3B8), // slate-400
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 6,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.37,
                        child: Container(
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _StatCard(
                title: "Hora Pico (Est.)",
                icon: Icons.access_time, // schedule
                iconColor: Colors.orange.shade400,
                content: Text(
                  "19:00",
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                    height: 1.0,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _StatCard(
                title: "Nuevos",
                icon: Icons.person_add,
                iconColor: Colors.purple.shade400,
                content: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "8",
                      style: GoogleFonts.inter(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        "hoy",
                        style: GoogleFonts.inter(
                          color: const Color(0xFF64748B), // slate-500
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget content;
  final Color? borderColor;
  final Color? backgroundColor;

  const _StatCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.content,
    this.borderColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor ?? const Color(0xFFE5E7EB),
        ), // gray-200
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B), // slate-500
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(icon, color: iconColor, size: 24),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }
}
