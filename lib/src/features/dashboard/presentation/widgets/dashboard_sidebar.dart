import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardSidebar extends StatefulWidget {
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
  State<DashboardSidebar> createState() => _DashboardSidebarState();
}

class _DashboardSidebarState extends State<DashboardSidebar> {
  // Tokens "Registro" (papel/tinta/vermellón) — ver docs/DESIGN_SYSTEM.md.
  Color get _ink =>
      widget.isDark ? const Color(0xFFEFEAE0) : const Color(0xFF1C1A16);
  Color get _ink3 =>
      widget.isDark ? const Color(0xFF7A7568) : const Color(0xFF8B867B);
  Color get _verm =>
      widget.isDark ? const Color(0xFFFF6A3D) : const Color(0xFFD9481C);
  Color get _vermSoft =>
      widget.isDark ? const Color(0x17FF6A3D) : const Color(0x12D9481C);

  bool _isCollapsed = false;
  bool _isDragging = false;
  double _expandedWidth = 256.0;

  bool _isFinanzasExpanded = false;

  bool _isConfigExpanded = false;
  bool _isAttendanceExpanded = false;

  void _toggleSidebar() {
    setState(() {
      _isCollapsed = !_isCollapsed;
      if (!_isCollapsed && _expandedWidth < 200.0) {
        _expandedWidth = 256.0;
      }
    });
  }

  void _toggleFinanzas() {
    setState(() {
      _isFinanzasExpanded = !_isFinanzasExpanded;
    });
  }

  void _toggleConfig() {
    setState(() {
      _isConfigExpanded = !_isConfigExpanded;
    });
  }

  void _toggleAttendance() {
    setState(() {
      _isAttendanceExpanded = !_isAttendanceExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textMain = _ink;
    final textMuted = _ink3;
    final primary = _verm;
    final role = widget.role.toLowerCase();
    final isAdmin = role == 'admin' || role == 'administrador';

    final currentWidth = _isCollapsed ? 72.0 : _expandedWidth;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: Duration(milliseconds: _isDragging ? 0 : 200),
          width: currentWidth,
          decoration: BoxDecoration(
            color: widget.surfaceColor,
            border: Border(right: BorderSide(color: widget.borderColor)),
          ),
          child: ClipRect(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: currentWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo Area & Toggle (Now fully clickable)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: InkWell(
                          onTap: _toggleSidebar,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                            child: Row(
                              mainAxisAlignment: _isCollapsed
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.spaceBetween,
                              children: [
                                if (!_isCollapsed) ...[
                                  Expanded(
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.asset(
                                            'assets/images/diamond_logo.png',
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.contain,
                                            filterQuality: FilterQuality.high,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    ColoredBox(
                                                      color:
                                                          widget.surfaceColor,
                                                      child: Icon(
                                                        Icons.diamond_outlined,
                                                        color: textMain,
                                                        size: 28,
                                                      ),
                                                    ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Diamond Gym',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.archivo(
                                                  color: textMain,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                              Text(
                                                'MANAGEMENT',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.archivo(
                                                  color: textMuted,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 2.2,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Toggle Indicator (Expanded)
                                  Icon(
                                    Icons.menu_open,
                                    color: textMuted,
                                    size: 24,
                                  ),
                                ] else
                                  // Toggle Indicator (Collapsed)
                                  Icon(Icons.menu, color: textMuted, size: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Navigation
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildNavItem(
                                Icons.dashboard_outlined,
                                'Dashboard',
                                index: 0,
                                textMain: primary,
                                textMuted: textMuted,
                              ),
                              _buildNavItem(
                                Icons.fitness_center,
                                'Gimnasios',
                                index: 12,
                                isActive: widget.selectedIndex == 12,
                                textMain: primary,
                                textMuted: textMuted,
                                accentColor: const Color(
                                  0xFF10B981,
                                ), // Emerald/Green
                              ),
                              // Asistencia Expandable
                              _buildExpandableNavItem(
                                Icons.access_time,
                                'Asistencia',
                                isExpanded: _isAttendanceExpanded,
                                onTap: _toggleAttendance,
                                textMain: primary,
                                textMuted: textMuted,
                                accentColor: const Color(0xFF06B6D4), // Cyan
                                children: [
                                  _buildSubNavItem(
                                    Icons.dashboard_customize,
                                    'Panel Principal',
                                    index: 7,
                                    isActive: widget.selectedIndex == 7,
                                    textMain: primary,
                                    textMuted: textMuted,
                                    accentColor: const Color(0xFF06B6D4),
                                  ),
                                  _buildSubNavItem(
                                    Icons.history,
                                    'Historial',
                                    index: 19,
                                    isActive: widget.selectedIndex == 19,
                                    textMain: primary,
                                    textMuted: textMuted,
                                    accentColor: const Color(0xFF06B6D4),
                                  ),
                                ],
                              ),
                              _buildNavItem(
                                Icons.sports_rounded,
                                'Entrenadores',
                                index: 17,
                                isActive: widget.selectedIndex == 17,
                                textMain: primary,
                                textMuted: textMuted,
                                accentColor: const Color(0xFFF59E0B), // Amber
                              ),
                              _buildNavItem(
                                Icons.people_outline,
                                'Clientes',
                                index: 1,
                                isActive: widget.selectedIndex == 1,
                                textMain: primary,
                                textMuted: textMuted,
                                accentColor: const Color(0xFF3B82F6), // Blue
                              ),
                              _buildNavItem(
                                Icons.monitor_heart_outlined,
                                'Control y Calidad',
                                index: 23,
                                isActive: widget.selectedIndex == 23,
                                textMain: primary,
                                textMuted: textMuted,
                                accentColor: const Color(0xFFD9481C),
                              ),
                              _buildNavItem(
                                Icons.calendar_today_outlined,
                                'Clases',
                                index: 2,
                                isActive: widget.selectedIndex == 2,
                                textMain: primary,
                                textMuted: textMuted,
                                accentColor: const Color(0xFFF59E0B), // Amber
                              ),
                              _buildNavItem(
                                Icons.credit_card, // Planes icon
                                'Planes',
                                index: 14, // New Index
                                isActive: widget.selectedIndex == 14,
                                textMain: primary,
                                textMuted: textMuted,
                                accentColor: const Color(0xFF3B82F6), // Blue
                              ),
                              _buildNavItem(
                                Icons.schedule,
                                'Horarios',
                                index: 13,
                                isActive: widget.selectedIndex == 13,
                                textMain: primary,
                                textMuted: textMuted,
                                accentColor: const Color(0xFF06B6D4), // Cyan
                              ),
                              // Finanzas Expandable Section
                              _buildExpandableNavItem(
                                Icons.payments_outlined,
                                'Finanzas',
                                isExpanded: _isFinanzasExpanded,
                                onTap: _toggleFinanzas,
                                textMain: primary,
                                textMuted: textMuted,
                                accentColor: const Color(0xFF8B5CF6), // Violet
                                children: [
                                  _buildSubNavItem(
                                    Icons.receipt_long_outlined,
                                    'Transacciones', // Was Monedas
                                    index: 3,
                                    isActive: widget.selectedIndex == 3,
                                    textMain: primary,
                                    textMuted: textMuted,
                                    accentColor: const Color(0xFF8B5CF6),
                                  ),
                                  _buildSubNavItem(
                                    Icons.account_balance_wallet_outlined,
                                    'Contabilidad',
                                    index: 20,
                                    isActive: widget.selectedIndex == 20,
                                    textMain: primary,
                                    textMuted: textMuted,
                                    accentColor: const Color(0xFF8B5CF6),
                                  ),
                                  _buildSubNavItem(
                                    Icons.attach_money,
                                    'Monedas',
                                    index: 18,
                                    isActive: widget.selectedIndex == 18,
                                    textMain: primary,
                                    textMuted: textMuted,
                                    accentColor: const Color(0xFF8B5CF6),
                                  ),
                                  _buildSubNavItem(
                                    Icons.account_balance_outlined,
                                    'Cuentas',
                                    index: 11,
                                    isActive: widget.selectedIndex == 11,
                                    textMain: primary,
                                    textMuted: textMuted,
                                    accentColor: const Color(
                                      0xFF8B5CF6,
                                    ), // Violet
                                  ),
                                  _buildSubNavItem(
                                    Icons.credit_card_outlined,
                                    'Tipos de Pago',
                                    index: 10,
                                    isActive: widget.selectedIndex == 10,
                                    textMain: primary,
                                    textMuted: textMuted,
                                    accentColor: const Color(
                                      0xFF8B5CF6,
                                    ), // Violet
                                  ),
                                  _buildSubNavItem(
                                    Icons.currency_exchange,
                                    'Tipos de Cambio',
                                    index: 16,
                                    isActive: widget.selectedIndex == 16,
                                    textMain: primary,
                                    textMuted: textMuted,
                                    accentColor: const Color(
                                      0xFF8B5CF6,
                                    ), // Violet
                                  ),
                                ],
                              ),
                              if (isAdmin)
                                _buildNavItem(
                                  Icons.manage_accounts_outlined,
                                  'Usuarios',
                                  index: 5,
                                  isActive: widget.selectedIndex == 5,
                                  textMain: primary,
                                  textMuted: textMuted,
                                  accentColor: const Color(0xFFEC4899), // Pink
                                ),
                              // Configuración Expandable Section
                              _buildExpandableNavItem(
                                Icons.settings_outlined,
                                'Configuración',
                                isExpanded: _isConfigExpanded,
                                onTap: _toggleConfig,
                                textMain: primary,
                                textMuted: textMuted,
                                accentColor: const Color(0xFFF59E0B), // Amber
                                children: [
                                  _buildSubNavItem(
                                    Icons.public_outlined,
                                    'Nacionalidades',
                                    index: 9,
                                    isActive: widget.selectedIndex == 9,
                                    textMain: primary,
                                    textMuted: textMuted,
                                    accentColor: const Color(
                                      0xFFF59E0B,
                                    ), // Amber
                                  ),
                                  _buildSubNavItem(
                                    Icons.share_outlined,
                                    'Referencias',
                                    index: 15,
                                    isActive: widget.selectedIndex == 15,
                                    textMain: primary,
                                    textMuted: textMuted,
                                    accentColor: const Color(
                                      0xFFF59E0B,
                                    ), // Amber
                                  ),
                                  _buildSubNavItem(
                                    Icons.palette_outlined,
                                    'Apariencia',
                                    index: 8,
                                    isActive: widget.selectedIndex == 8,
                                    textMain: primary,
                                    textMuted: textMuted,
                                    accentColor: const Color(0xFFF59E0B),
                                  ),
                                  if (isAdmin)
                                    _buildSubNavItem(
                                      Icons.rule_folder_outlined,
                                      'Retención',
                                      index: 24,
                                      isActive: widget.selectedIndex == 24,
                                      textMain: primary,
                                      textMuted: textMuted,
                                      accentColor: const Color(0xFFD9481C),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Logout — acción tipográfica sobre filete de pelo
                      if (_isCollapsed)
                        Tooltip(
                          message: 'Cerrar Sesión',
                          child: InkWell(
                            onTap: widget.onLogout,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: widget.borderColor),
                                ),
                              ),
                              child: Icon(Icons.logout, color: _verm, size: 18),
                            ),
                          ),
                        )
                      else
                        InkWell(
                          onTap: widget.onLogout,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: widget.borderColor),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.logout, color: _verm, size: 16),
                                const SizedBox(width: 10),
                                Text(
                                  'CERRAR SESIÓN',
                                  style: GoogleFonts.archivo(
                                    color: _verm,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10.5,
                                    letterSpacing: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ), // Ends AnimatedContainer
        // Resize Handle
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              setState(() {
                _isDragging = true;
                if (_isCollapsed) {
                  _isCollapsed = false;
                  _expandedWidth = 72.0;
                }
              });
            },
            onPanUpdate: (details) {
              setState(() {
                _expandedWidth += details.delta.dx;
                if (_expandedWidth < 72.0) _expandedWidth = 72.0;
                if (_expandedWidth > 400.0) _expandedWidth = 400.0;

                _isCollapsed = _expandedWidth <= 120.0;
              });
            },
            onPanEnd: (details) {
              setState(() {
                _isDragging = false;
                if (_expandedWidth < 150.0 && !_isCollapsed) {
                  _isCollapsed = true;
                  _expandedWidth = 256.0;
                } else if (_isCollapsed) {
                  _expandedWidth = 256.0;
                }
              });
            },
            child: Container(
              width: 6, // 6 pixels interactable handle
              color: Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label, {
    required int index,
    bool isActive = false,
    required Color textMain,
    required Color textMuted,
    Color? accentColor,
  }) {
    // Registro: un solo acento (vermellón), versalitas, esquinas rectas.
    final iconColor = isActive ? _verm : textMuted;
    final textColor = isActive ? _ink : textMuted;
    final bg = isActive ? _vermSoft : Colors.transparent;

    if (_isCollapsed) {
      return Tooltip(
        message: label,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => widget.onNavigate(index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  border: Border(
                    left: BorderSide(
                      color: isActive ? _verm : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onNavigate(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              border: Border(
                left: BorderSide(
                  color: isActive ? _verm : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 19, color: iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.archivo(
                      color: textColor,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 11.5,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Expandable nav item (parent with children)
  Widget _buildExpandableNavItem(
    IconData icon,
    String label, {
    required bool isExpanded,
    required VoidCallback onTap,
    required Color textMain,
    required Color textMuted,
    required List<Widget> children,
    Color? accentColor,
  }) {
    final iconColor = isExpanded ? _ink : textMuted;

    if (_isCollapsed) {
      // When collapsed, show a popup menu instead
      return PopupMenuButton<int>(
        tooltip: label,
        offset: const Offset(60, 0),
        itemBuilder: (context) => children
            .whereType<_SubNavItem>()
            .map(
              (item) => PopupMenuItem<int>(
                value: item.index,
                child: Row(
                  children: [
                    Icon(item.icon, size: 18, color: textMuted),
                    const SizedBox(width: 8),
                    Text(item.label),
                  ],
                ),
              ),
            )
            .toList(),
        onSelected: (index) => widget.onNavigate(index),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          color: Colors.transparent,
          child: Icon(icon, size: 22, color: iconColor),
        ),
      );
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.transparent, width: 3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 19, color: iconColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.archivo(
                          color: isExpanded ? _ink : textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Children (animated)
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(children: children),
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  // Sub-nav item (indented child)
  Widget _buildSubNavItem(
    IconData icon,
    String label, {
    required int index,
    bool isActive = false,
    required Color textMain,
    required Color textMuted,
    Color? accentColor,
  }) {
    final iconColor = isActive ? _verm : textMuted;
    final textColor = isActive ? _ink : textMuted;
    final bg = isActive ? _vermSoft : Colors.transparent;

    return _SubNavItem(
      icon: icon,
      label: label,
      index: index,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => widget.onNavigate(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bg,
                border: Border(
                  left: BorderSide(
                    color: isActive ? _verm : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.archivo(
                        color: textColor,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w600,
                        fontSize: 10.5,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Helper class to pass data to popup menu
class _SubNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final Widget child;

  const _SubNavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => child;
}
