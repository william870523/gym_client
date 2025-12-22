import 'package:flutter/material.dart';

class ReceptionDashboardView extends StatelessWidget {
  const ReceptionDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF136DEC);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final textColor = isDark ? Colors.white : Colors.black;
    final textMuted = isDark ? Colors.grey[400] : Colors.grey;
    final cardColor = isDark ? const Color(0xFF334155) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.shade200;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 1. Quick Check-In Content (Hero)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, const Color(0xFF0E4AC4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Control de Acceso',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Escanea o ingresa el ID del cliente para registrar su entrada.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.qr_code_scanner,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  hintText: 'Ingresar ID / Escanear...',
                                  hintStyle: TextStyle(color: textMuted),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            Container(
                              height: 56,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(8),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'CHECK IN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
                // Live Occupancy
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Ocupación Actual',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '84 / 120',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 150,
                        child: LinearProgressIndicator(
                          value: 0.7,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation(
                            Colors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '70% Capacidad',
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. Timeline & Quick Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline (Left)
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Clases de Hoy',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildClassItem(
                        '07:00 AM',
                        'Yoga Flow',
                        'Ana Lopez',
                        'Sala B',
                        0.9,
                        textColor,
                        textMuted,
                      ),
                      _buildClassItem(
                        '09:00 AM',
                        'CrossFit Max',
                        'Carlos R.',
                        'Sala Principal',
                        0.5,
                        textColor,
                        textMuted,
                      ),
                      _buildClassItem(
                        '05:00 PM',
                        'Spinning',
                        'Maria G.',
                        'Sala Spin',
                        0.2,
                        textColor,
                        textMuted,
                      ),
                      _buildClassItem(
                        '07:00 PM',
                        'Zumba Night',
                        'Luis P.',
                        'Sala B',
                        0.0,
                        textColor,
                        textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Actions (Right)
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildActionCard(
                      Icons.person_add,
                      'Nuevo Miembro',
                      'Registrar nuevo usuario',
                      Colors.blue,
                      cardColor,
                      borderColor,
                      textColor,
                      textMuted,
                    ),
                    const SizedBox(height: 16),
                    _buildActionCard(
                      Icons.shopping_cart,
                      'Punto de Venta',
                      'Vender productos/agua',
                      Colors.green,
                      cardColor,
                      borderColor,
                      textColor,
                      textMuted,
                    ),
                    const SizedBox(height: 16),
                    _buildActionCard(
                      Icons.report_problem,
                      'Reportar Incidencia',
                      'Mantenimiento o limpieza',
                      Colors.orange,
                      cardColor,
                      borderColor,
                      textColor,
                      textMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClassItem(
    String time,
    String title,
    String instructor,
    String room,
    double fill,
    Color textColor,
    Color? mutedColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 80,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              time,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
                Text(
                  '$instructor • $room',
                  style: TextStyle(color: mutedColor, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(fill * 100).toInt()}%',
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
              ),
              SizedBox(
                width: 60,
                child: LinearProgressIndicator(
                  value: fill,
                  color: fill > 0.8 ? Colors.red : Colors.green,
                  backgroundColor: mutedColor?.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color? mutedColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: textColor,
                ),
              ),
              Text(subtitle, style: TextStyle(color: mutedColor, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
