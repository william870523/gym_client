import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../dashboard/presentation/state/dashboard_nav_provider.dart';
import '../../../clients/presentation/state/client_notifier.dart';
import '../../../clients/data/models/client_model.dart';
import '../../../payments/presentation/widgets/process_payment_dialog.dart';
import '../state/attendance_notifier.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';

DateTime _sidebarGymNow() =>
    toGymWallClock(appClock.nowUtc(), appClock.gymTimezone);

class _ActivityEvent {
  final String name;
  final String text;
  final DateTime time;
  final IconData icon;
  final Color color;

  _ActivityEvent({
    required this.name,
    required this.text,
    required this.time,
    required this.icon,
    required this.color,
  });
}

class AttendanceSidebar extends ConsumerWidget {
  const AttendanceSidebar({super.key});

  String _formatRelativeTime(DateTime time) {
    final diff = appClock.nowUtc().difference(time.toUtc());
    if (diff.isNegative || diff.inSeconds < 10) return "Hace un momento";
    if (diff.inSeconds < 60) return "Hace ${diff.inSeconds} seg";
    if (diff.inMinutes < 60) return "Hace ${diff.inMinutes} min";
    if (diff.inHours < 24) {
      return "Hace ${diff.inHours} ${diff.inHours == 1 ? 'hora' : 'horas'}";
    }
    return "Hace ${diff.inDays} ${diff.inDays == 1 ? 'día' : 'días'}";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Watch real-time providers
    final clientsAsync = ref.watch(clientNotifierProvider);
    final attendancesAsync = ref.watch(attendanceNotifierProvider);

    // Tailwind Colors
    final slate50 = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final slate100 = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final slate200 = isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0);
    final slate400 = const Color(0xFF94A3B8);
    final slate500 = const Color(0xFF64748B);
    final slate900 = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final primary = const Color(0xFF135BEC);
    final success = const Color(0xFF22C55E);
    final danger = const Color(0xFFEF4444);

    final amber50 = const Color(0xFFFFFBEB);
    final amber100 = const Color(0xFFFEF3C7);
    final amber600 = const Color(0xFFD97706);
    final red50 = const Color(0xFFFEF2F2);
    final red100 = const Color(0xFFFEE2E2);

    // 1. Filter and Process Billing Alerts from loaded clients
    final List<ClientModel> expiredOrExpiring = [];
    if (clientsAsync.hasValue) {
      final now = _sidebarGymNow();
      final today = DateTime(now.year, now.month, now.day);
      final all = clientsAsync.value ?? [];

      for (final client in all) {
        if (client.endDate != null) {
          final expiry = DateTime(
            client.endDate!.year,
            client.endDate!.month,
            client.endDate!.day,
          );
          final diff = expiry.difference(today).inDays;

          // Expired (negative diff) or inactive clients get alerts
          if (diff < 0 || !client.activo) {
            expiredOrExpiring.add(client);
          } else if (diff >= 0 && diff <= 3) {
            // Expiring in next 3 days
            expiredOrExpiring.add(client);
          }
        } else if (!client.activo) {
          expiredOrExpiring.add(client);
        }
      }
    }

    // Sort billing alerts: most expired first, then soonest expiring
    expiredOrExpiring.sort((a, b) {
      final aEnd = a.endDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bEnd = b.endDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aEnd.compareTo(bEnd);
    });

    final visibleAlerts = expiredOrExpiring.take(10).toList();

    // 2. Build Timeline Events from today's attendances
    final List<_ActivityEvent> events = [];
    if (attendancesAsync.hasValue) {
      for (final att in attendancesAsync.value ?? []) {
        final clientName = att.clientName ?? 'Socio';

        // Add Check-In (Entrada) event
        events.add(
          _ActivityEvent(
            name: clientName,
            text: '$clientName ingresó a sala.',
            time: att.checkIn,
            icon: Icons.login,
            color: success,
          ),
        );

        // Add Check-Out (Salida) event if they finished
        if (att.checkOut != null) {
          events.add(
            _ActivityEvent(
              name: clientName,
              text: '$clientName finalizó entrenamiento.',
              time: att.checkOut!,
              icon: Icons.logout,
              color: danger,
            ),
          );
        }
      }
    }

    // Sort activity events chronologically descending (newest first)
    events.sort((a, b) => b.time.compareTo(a.time));

    final visibleEvents = events.take(10).toList();

    return SizedBox(
      width: 320,
      child: Column(
        children: [
          // 1. ALERTAS DE COBRO
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: slate200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: Border(bottom: BorderSide(color: slate100)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: danger,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ALERTAS DE COBRO',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: slate900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (expiredOrExpiring.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: danger.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${expiredOrExpiring.length}',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: danger,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: visibleAlerts.isEmpty
                        ? _buildEmptyAlertsState(
                            slate50,
                            slate200,
                            slate900,
                            slate500,
                            success,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: visibleAlerts.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final client = visibleAlerts[index];
                              final now = _sidebarGymNow();
                              final today = DateTime(
                                now.year,
                                now.month,
                                now.day,
                              );

                              int daysDiff = -1;
                              if (client.endDate != null) {
                                final expiry = DateTime(
                                  client.endDate!.year,
                                  client.endDate!.month,
                                  client.endDate!.day,
                                );
                                daysDiff = expiry.difference(today).inDays;
                              }

                              final bool isVencido =
                                  daysDiff < 0 || !client.activo;

                              final cardBg = isVencido
                                  ? (isDark
                                        ? const Color(
                                            0xFF451A1A,
                                          ).withValues(alpha: 0.3)
                                        : red50)
                                  : (isDark
                                        ? const Color(
                                            0xFF452A1A,
                                          ).withValues(alpha: 0.3)
                                        : amber50);

                              final cardBorder = isVencido
                                  ? (isDark
                                        ? const Color(
                                            0xFF991B1B,
                                          ).withValues(alpha: 0.4)
                                        : red100)
                                  : (isDark
                                        ? const Color(
                                            0xFF92400E,
                                          ).withValues(alpha: 0.4)
                                        : amber100);

                              final cardAccent = isVencido ? danger : amber600;
                              final tagText = isVencido
                                  ? 'VENCIDO'
                                  : 'POR VENCER';

                              final formattedDate = client.endDate != null
                                  ? DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(client.endDate!)
                                  : 'Sin fecha fin';

                              final descText = isVencido
                                  ? (daysDiff < 0
                                        ? 'Plan venció hace ${daysDiff.abs()} días ($formattedDate).'
                                        : 'Socio marcado como inactivo.')
                                  : 'Vence en $daysDiff días ($formattedDate).';

                              return _buildAlertCard(
                                context,
                                ref,
                                client,
                                slate900,
                                slate500,
                                cardBg,
                                cardBorder,
                                cardAccent,
                                isDark ? const Color(0xFF1E293B) : Colors.white,
                                '${client.nombres ?? ''} ${client.apellidos ?? ''}'
                                    .trim(),
                                tagText,
                                cardAccent,
                                descText,
                                isVencido ? 'Cobrar Plan' : 'Notificar Cobro',
                                canCollect: isVencido,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. ACTIVIDAD RECIENTE
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: slate200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: slate100)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.history_rounded, color: slate400, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'ACTIVIDAD RECIENTE',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: slate900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: visibleEvents.isEmpty
                        ? _buildEmptyActivityState(slate400, slate500)
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: visibleEvents.length,
                            itemBuilder: (context, index) {
                              final ev = visibleEvents[index];

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Stack(
                                  children: [
                                    // Vertical line helper
                                    if (index < visibleEvents.length - 1)
                                      Positioned(
                                        left: 11,
                                        top: 24,
                                        bottom: -12,
                                        child: Container(
                                          width: 1.5,
                                          color: slate100,
                                        ),
                                      ),
                                    _buildActivityItem(
                                      slate900,
                                      slate400,
                                      ev.color,
                                      ev.icon,
                                      ev.text,
                                      _formatRelativeTime(ev.time),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Footer
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: slate100)),
                      color: isDark
                          ? const Color(0xFF0F172A).withValues(alpha: 0.2)
                          : slate50,
                    ),
                    child: Center(
                      child: TextButton(
                        onPressed: () {
                          ref
                              .read(dashboardNavProvider.notifier)
                              .setIndex(19); // 19 is Daily History Screen
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'VER HISTORIAL COMPLETO',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: primary,
                            letterSpacing: 1.0,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
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

  Widget _buildEmptyAlertsState(
    Color slate50,
    Color slate200,
    Color slate900,
    Color slate500,
    Color success,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                color: success,
                size: 36,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sin alertas pendientes',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: slate900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Todos los socios activos tienen sus planes vigentes y al día.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 10, color: slate500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyActivityState(Color slate400, Color slate500) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              color: slate400.withValues(alpha: 0.3),
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              'Sin actividad registrada',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: slate500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Los accesos de hoy aparecerán aquí en tiempo real.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 10, color: slate400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(
    BuildContext context,
    WidgetRef ref,
    ClientModel client,
    Color textMain,
    Color textSub,
    Color bg,
    Color border,
    Color accent,
    Color btnBg,
    String name,
    String tag,
    Color tagColor,
    String desc,
    String btnText, {
    required bool canCollect,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textMain,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tag,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: tagColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(desc, style: GoogleFonts.inter(fontSize: 10, color: textSub)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canCollect
                  ? () => _openPaymentDialog(context, ref, client)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: btnBg,
                foregroundColor: tagColor,
                elevation: 0,
                side: BorderSide(color: border.withValues(alpha: 0.7)),
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                minimumSize: const Size(0, 24),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                btnText,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPaymentDialog(
    BuildContext context,
    WidgetRef ref,
    ClientModel client,
  ) async {
    final planId = client.planId;
    if (planId == null || planId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este socio no tiene un plan asignado para cobrar.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final paid = await showDialog<bool>(
      context: context,
      builder: (_) => ProcessPaymentDialog(client: client, planId: planId),
    );

    if (paid == true && context.mounted) {
      await ref.read(clientNotifierProvider.notifier).refresh();
      await ref.read(attendanceNotifierProvider.notifier).refresh();
    }
  }

  Widget _buildActivityItem(
    Color textMain,
    Color textSub,
    Color color,
    IconData icon,
    String text,
    String time,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 28), // Indent for timeline
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -28,
            top: 0,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, size: 11, color: color),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: textSub,
                    height: 1.2,
                  ),
                  children: _parseActivityText(text, textMain),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: textSub,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _parseActivityText(String text, Color boldColor) {
    final parts = text.split(' ');
    if (parts.length > 2) {
      // Find the first few parts representing the name (usually until 'ingresó' or 'finalizó')
      int actionIndex = parts.indexWhere(
        (p) => p.startsWith('ingresó') || p.startsWith('finalizó'),
      );
      if (actionIndex == -1) actionIndex = 2; // fallback

      final boldName = parts.take(actionIndex).join(' ');
      final rest = parts.skip(actionIndex).join(' ');

      return [
        TextSpan(
          text: '$boldName ',
          style: TextStyle(fontWeight: FontWeight.bold, color: boldColor),
        ),
        TextSpan(text: rest),
      ];
    }
    return [TextSpan(text: text)];
  }
}
