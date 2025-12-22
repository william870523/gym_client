import 'package:flutter/material.dart';

class DashboardSidebar extends StatelessWidget {
  final bool isDark;
  final Color surfaceColor;
  final Color borderColor;
  final int selectedIndex;
  final Function(int) onNavigate;
  final String role;
  final VoidCallback onLogout;

  const DashboardSidebar({
    super.key,
    required this.isDark,
    required this.surfaceColor,
    required this.borderColor,
    required this.selectedIndex,
    required this.onNavigate,
    required this.role,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final primary = const Color(0xFF136DEC); // Diamond Blue

    return Container(
      width: 256, // w-64
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(right: BorderSide(color: borderColor)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo Area
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade100),
                  image: const DecorationImage(
                    image: AssetImage(
                      'assets/images/diamond_logo.png',
                    ), // Ensure asset exists
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Diamond Gym',
                    style: TextStyle(
                      color: textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'MANAGEMENT',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Navigation
          _buildNavItem(
            Icons.dashboard_outlined,
            'Dashboard',
            index: 0,
            isActive: selectedIndex == 0,
            textMain: primary,
            textMuted: textMuted,
          ),
          _buildNavItem(
            Icons.people_outline,
            'Clientes',
            index: 1,
            isActive: selectedIndex == 1,
            textMain: primary,
            textMuted: textMuted,
          ),
          _buildNavItem(
            Icons.calendar_today_outlined,
            'Clases',
            index: 2,
            isActive: selectedIndex == 2,
            textMain: primary,
            textMuted: textMuted,
          ),
          _buildNavItem(
            Icons.payments_outlined,
            'Finanzas',
            index: 3,
            isActive: selectedIndex == 3,
            textMain: primary,
            textMuted: textMuted,
          ),
          if (role == 'admin')
            _buildNavItem(
              Icons.manage_accounts_outlined,
              'Usuarios',
              index:
                  5, // Using 5 to keep 4 for Config if needed, or just append
              isActive: selectedIndex == 5,
              textMain: primary,
              textMuted: textMuted,
            ),
          _buildNavItem(
            Icons.settings_outlined,
            'Configuración',
            index: 4,
            isActive: selectedIndex == 4,
            textMain: primary,
            textMuted: textMuted,
          ),

          const Spacer(),

          // Logout Button (Text Button style to fit bottom)
          InkWell(
            onTap: onLogout,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red.shade400, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Cerrar Sesión',
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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

  Widget _buildNavItem(
    IconData icon,
    String label, {
    required int index,
    bool isActive = false,
    required Color textMain,
    required Color textMuted,
  }) {
    final color = isActive ? textMain : textMuted;
    final bg = isActive ? textMain.withOpacity(0.1) : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onNavigate(index),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
