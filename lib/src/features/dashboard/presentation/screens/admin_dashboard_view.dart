import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/sync/sync_status_provider.dart';
import '../../../../features/dashboard/presentation/widgets/kpi_card.dart';
import '../widgets/system_health_card.dart';

class AdminDashboardView extends ConsumerWidget {
  const AdminDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final syncStatus =
        ref.watch(syncStatusProvider).value ?? SyncStatusSnapshot.checking();
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. System Health Section
          Text(
            'SYSTEM HEALTH & STATUS',
            style: TextStyle(
              color: textMain,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          const SystemHealthRow(),
          const SizedBox(height: 16),

          if (!syncStatus.isHealthy) ...[
            _SyncWarningBanner(status: syncStatus, isDark: isDark),
            const SizedBox(height: 32),
          ] else
            const SizedBox(height: 16),

          // 2. KPIs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Key Performance Indicators',
                    style: TextStyle(
                      color: textMain,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Real-time business health overview',
                    style: TextStyle(color: textMuted, fontSize: 14),
                  ),
                ],
              ),
              // Dropdown Mock
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                ),
                child: Row(
                  children: [
                    Text(
                      'Last 30 Days',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white70
                            : Colors.blueGrey.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: isDark ? Colors.white70 : Colors.black,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const KpiGrid(),

          const SizedBox(height: 32),

          // 3. Charts & Alerts Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : Colors.grey.shade200,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Weekly Class Attendance',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: textMain,
                                ),
                              ),
                              Text(
                                'Real-time check-in data',
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '1,250',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                  color: textMain,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    '+8% ',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Icon(
                                    Icons.trending_up,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '[Chart Placeholder]',
                            style: TextStyle(color: textMuted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : Colors.grey.shade200,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Revenue vs Expenses',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: textMain,
                                ),
                              ),
                              Text(
                                'Last 6 Months',
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$240k',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                  color: textMain,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    '+15% Net ',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Icon(
                                    Icons.trending_up,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '[Bar Chart Placeholder]',
                            style: TextStyle(color: textMuted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SystemHealthRow extends ConsumerWidget {
  const SystemHealthRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus =
        ref.watch(syncStatusProvider).value ?? SyncStatusSnapshot.checking();
    final isOffline = syncStatus.level == SyncStatusLevel.offline;
    final isPending = syncStatus.level == SyncStatusLevel.pending;

    return LayoutBuilder(
      builder: (context, constraints) {
        int cols = constraints.maxWidth > 800 ? 4 : 2;

        return GridView.count(
          crossAxisCount: cols,
          childAspectRatio: 2.5, // Wide cards
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            SystemHealthCard(
              icon: isOffline ? Icons.wifi_off : Icons.wifi,
              color: isOffline ? Colors.red : Colors.green,
              label: 'API',
              value: isOffline ? 'Offline' : 'Online',
              isPulse: !isOffline,
              isError: isOffline,
            ),
            SystemHealthCard(
              icon: isPending ? Icons.cloud_sync : Icons.sync,
              color: isOffline
                  ? Colors.red
                  : (isPending ? Colors.orange : Colors.blue),
              label: 'Data Sync',
              value: syncStatus.label,
              isError: isOffline,
            ),
            SystemHealthCard(
              icon: Icons.update,
              color: Colors.grey,
              label: 'Last Sync',
              value: syncStatus.lastSyncLabel,
            ),
            SystemHealthCard(
              icon: Icons.error_outline,
              color: syncStatus.pendingEvents > 0
                  ? Colors.orange
                  : Colors.green,
              label: 'Pendientes',
              value: '${syncStatus.pendingEvents}',
              isError: syncStatus.pendingEvents > 0 || isOffline,
            ),
          ],
        );
      },
    );
  }
}

class _SyncWarningBanner extends StatelessWidget {
  const _SyncWarningBanner({required this.status, required this.isDark});

  final SyncStatusSnapshot status;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isOffline = status.level == SyncStatusLevel.offline;
    final color = isOffline ? Colors.red : Colors.orange;

    return IntrinsicHeight(
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.transparent : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isDark ? 0.18 : 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isOffline
                            ? Icons.cloud_off_outlined
                            : Icons.cloud_sync_outlined,
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status.label,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.blueGrey.shade800,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${status.detail}. La sincronización se reintentará automáticamente.',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white54
                                  : Colors.blueGrey.shade500,
                              fontSize: 12,
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
      ),
    );
  }
}

class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int cols = constraints.maxWidth > 1000
            ? 4
            : (constraints.maxWidth > 600 ? 2 : 1);

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children:
              [
                    const KpiCard(
                      title: 'Total Revenue',
                      value: '\$45,200',
                      trend: '+12% vs last month',
                      trendColor: Colors.green,
                      icon: Icons.trending_up,
                      iconColor: Colors.green,
                      iconBg: Color(0xFFE8F5E9), // green-50
                    ),
                    const KpiCard(
                      title: 'Customer LTV',
                      value: '\$850',
                      trend: '+5% year over year',
                      trendColor: Colors.green,
                      icon: Icons.attach_money,
                      iconColor: Color(0xFF136DEC),
                      iconBg: Color(0xFFEFF6FF), // blue-50
                    ),
                    const KpiCard(
                      title: 'Active Members',
                      value: '1,240',
                      trend: '+35 new this week',
                      trendColor: Colors.green,
                      icon: Icons.group,
                      iconColor: Color(0xFF136DEC),
                      iconBg: Color(0xFFEFF6FF),
                    ),
                    const KpiCard(
                      title: 'Churn Rate',
                      value: '4.2%',
                      trend: '0.5% warning threshold',
                      trendColor: Colors.orange,
                      icon: Icons.warning,
                      iconColor: Colors.orange,
                      iconBg: Color(0xFFFFF7ED), // orange-50
                    ),
                  ]
                  // We can convert this to Grid if Wrap is tricky with layout, but Wrap is safer for responsiveness
                  .map(
                    (e) => SizedBox(
                      width: (constraints.maxWidth - (16 * (cols - 1))) / cols,
                      child: e,
                    ),
                  )
                  .toList(),
        );
      },
    );
  }
}
