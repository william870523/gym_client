import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReceptionDashboardView extends StatelessWidget {
  const ReceptionDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Theme Awareness
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final textMuted = isDark
            ? const Color(0xFF94A3B8)
            : const Color(0xFF64748B);
        final borderColor = isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFFE2E8F0);

        // Responsive Logic based on available width (subtracted sidebar)
        // 1024 global width - 256 sidebar ~= 768.
        // So we want to switch stack mode if we have less than ~800px available.
        final isWide = constraints.maxWidth > 900;

        Widget leftPanel = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Heading & Quick Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Registro de Asistencia",
                        style: GoogleFonts.inter(
                          fontSize: 30, // text-3xl
                          fontWeight: FontWeight.w900, // font-black
                          color: textColor,
                          letterSpacing: -0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Gestión manual de entradas y salidas.",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Aforo Stats
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.group,
                          color: Color(0xFF16A34A),
                          size: 24,
                        ), // green-600
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Aforo",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: textMuted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "124",
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Main Input Card
            _buildMainInputCard(
              context,
              isWide,
              isDark,
              surfaceColor,
              borderColor,
              textColor,
              textMuted,
            ),
          ],
        );

        Widget rightPanel = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    "Actividad Reciente",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    "Ver todo",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF135BEC), // Primary
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Log List Container
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 700),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: _buildActivityLogList(
                context,
                isDark,
                textColor,
                textMuted,
              ),
            ),
          ],
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Layout Container
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1600),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: leftPanel),
                            const SizedBox(width: 24),
                            Expanded(flex: 1, child: rightPanel),
                          ],
                        )
                      : Column(
                          children: [
                            leftPanel,
                            const SizedBox(height: 24),
                            rightPanel,
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Detailed Input Card
  Widget _buildMainInputCard(
    BuildContext context,
    bool isWide,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color textMuted,
  ) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Client Search
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Identificar Cliente",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC), // slate-50/slate-900
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFCBD5E1),
                        ), // slate-300
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: textMuted, size: 28),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              autofocus: true,
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                              decoration: InputDecoration(
                                hintText: "Buscar por CI o Nombre...",
                                hintStyle: GoogleFonts.inter(
                                  color: textMuted.withValues(alpha: 0.5),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 64,
                    width: 64,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0), // slate-200
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.qr_code_scanner),
                      color: textMuted,
                      iconSize: 28,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 32),

          // 2. Client Info Preview (Mocked)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF135BEC).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF135BEC).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                    image: const DecorationImage(
                      image: NetworkImage(
                        "https://lh3.googleusercontent.com/aida-public/AB6AXuBnsdEvmy6aI5fjB19rOcjiFINng0tp8XhuE9LRXTs9_M3ODOIfA7QzG-mnEqYlgnmQRqLUEtJZeWNniy8ndQgibEzIi_Wcak_eNoqypQYZEWJtyKNoLczQC8PXvGlICn8DBkgG8cVJH8XUS0Fh4s6lu2rGIJ1sGzMv9uFI8Fx8kqoY3wXhY48ZAnJZrBlmEHxn-JfY-r3xVTBjFuPxN-WCTCbgkBXyC4hl8OWDXqhuaGK-l_PQkyB7XBoRWLVAM5Im3mFngtKmauA",
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              "Ana María González",
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Badge
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7), // green-100
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF16A34A),
                                      shape: BoxShape.circle,
                                    ),
                                  ), // green-600
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      "Membresía Activa",
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(
                                          0xFF166534,
                                        ), // green-800
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "Plan Mensual Gold • Expira: 15 Nov 2023",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isWide)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        "CI: 172345678-9",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 3. Action Type Selector
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF1F5F9), // slate-100/800
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: surfaceColor, // Active bg (white/dark)
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.login,
                          color: const Color(0xFF135BEC),
                          size: 20,
                        ), // primary
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            "Entrada",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF135BEC),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, color: textMuted, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            "Salida",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 4. Time & Device Grid
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Fecha y Hora",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "24 Oct 2023, 08:42", // Mocked
                        style: GoogleFonts.inter(color: textColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Dispositivo de Registro",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Recepción Principal (Manual)",
                              style: GoogleFonts.inter(color: textColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.expand_more, color: textMuted),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // 5. Submit Button
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF135BEC), // Primary
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                shadowColor: const Color(0xFF135BEC).withValues(alpha: 0.3),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, size: 28, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    "Registrar Acceso",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Activity Log List
  Widget _buildActivityLogList(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color textMuted,
  ) {
    // Mock Data List
    final logs = [
      _ActivityLogItem(
        name: "Carlos Rodriguez",
        subtext: "Torniquete #1 • Membresía Activa",
        time: "08:40 AM",
        type: _LogType.entry,
      ),
      _ActivityLogItem(
        name: "Sofia Martinez",
        subtext: "Recepción (Manual) • Invitado",
        time: "08:35 AM",
        type: _LogType.exit,
      ),
      _ActivityLogItem(
        name: "Pedro Alvarez",
        subtext: "Intento Fallido • Membresía Vencida",
        time: "08:32 AM",
        type: _LogType.warning,
      ),
      _ActivityLogItem(
        name: "Lucia Mendez",
        subtext: "Biométrico • Plan Anual",
        time: "08:28 AM",
        type: _LogType.entry,
      ),
      _ActivityLogItem(
        name: "Jorge Soto",
        subtext: "Torniquete #2 • Plan Mensual",
        time: "08:25 AM",
        type: _LogType.entry,
      ),
      _ActivityLogItem(
        name: "Valentina Ruiz",
        subtext: "Torniquete Salida #1",
        time: "08:21 AM",
        type: _LogType.exit,
      ),
    ];

    return ListView.builder(
      shrinkWrap: true, // As it is inside a constrained container
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final item = logs[index];
        return _buildLogItem(context, item, isDark, textColor, textMuted);
      },
    );
  }

  Widget _buildLogItem(
    BuildContext context,
    _ActivityLogItem item,
    bool isDark,
    Color textColor,
    Color textMuted,
  ) {
    Color iconBg;
    Color iconColor;
    IconData iconData;
    Color? subtextColor = textMuted;

    switch (item.type) {
      case _LogType.entry:
        iconBg = const Color(0xFFDCFCE7); // green-100
        iconColor = const Color(0xFF16A34A); // green-600
        iconData = Icons.login;
        if (isDark) {
          iconBg = const Color(0xFF16A34A).withValues(alpha: 0.2);
          iconColor = const Color(0xFF4ADE80); // green-400
        }
        break;
      case _LogType.exit:
        iconBg = const Color(0xFFFEE2E2); // red-100
        iconColor = const Color(0xFFDC2626); // red-600
        iconData = Icons.logout;
        if (isDark) {
          iconBg = const Color(0xFFDC2626).withValues(alpha: 0.2);
          iconColor = const Color(0xFFF87171); // red-400
        }
        break;
      case _LogType.warning:
        iconBg = const Color(0xFFFEF3C7); // amber-100
        iconColor = const Color(0xFFD97706); // amber-600
        iconData = Icons.warning;
        subtextColor = const Color(0xFFD97706);
        if (isDark) {
          iconBg = const Color(0xFFD97706).withValues(alpha: 0.2);
          iconColor = const Color(0xFFFBBF24); // amber-400
          subtextColor = const Color(0xFFFBBF24);
        }
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.type == _LogType.warning
            ? (isDark
                  ? const Color(0xFFD97706).withValues(alpha: 0.1)
                  : const Color(0xFFFFFBEB)) // amber-50
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(iconData, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.subtext,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: subtextColor,
                    fontWeight: item.type == _LogType.warning
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.time,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _LogType { entry, exit, warning }

class _ActivityLogItem {
  final String name;
  final String subtext;
  final String time;
  final _LogType type;

  _ActivityLogItem({
    required this.name,
    required this.subtext,
    required this.time,
    required this.type,
  });
}
