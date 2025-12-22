import 'package:flutter/material.dart';
import '../../../../features/dashboard/presentation/widgets/kpi_card.dart';
import '../widgets/system_health_card.dart';

class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

          // Warning Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: Colors.orange, width: 4)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Synchronization Warning',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey.shade800,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Member database sync experienced latency (145ms). Background retry scheduled.',
                        style: TextStyle(
                          color: Colors.blueGrey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: () {}, child: const Text('Dismiss')),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text('View Logs'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

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
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Text(
                      'Last 30 Days',
                      style: TextStyle(
                        color: Colors.blueGrey.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.keyboard_arrow_down, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const KpiGrid(),

          const SizedBox(height: 32),

          // 3. Charts & Alerts Row
          // For simplicity in this step, I'll use placeholders for the Charts as they require `fl_chart` or CustomPainter
          // which fits better in a separate widget file.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
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
                                ),
                              ),
                              Text(
                                'Real-time check-in data',
                                style: TextStyle(
                                  color: Colors.grey,
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
                      const Expanded(
                        child: Center(
                          child: Text(
                            '[Chart Placeholder]',
                            style: TextStyle(color: Colors.grey),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
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
                                ),
                              ),
                              Text(
                                'Last 6 Months',
                                style: TextStyle(
                                  color: Colors.grey,
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
                      const Expanded(
                        child: Center(
                          child: Text(
                            '[Bar Chart Placeholder]',
                            style: TextStyle(color: Colors.grey),
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

class SystemHealthRow extends StatelessWidget {
  const SystemHealthRow({super.key});

  @override
  Widget build(BuildContext context) {
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
              icon: Icons.wifi,
              color: Colors.green,
              label: 'Status',
              value: 'Online',
              isPulse: true,
            ),
            SystemHealthCard(
              icon: Icons.sync,
              color: Colors.blue,
              label: 'Data Sync',
              value: 'Synced',
            ),
            SystemHealthCard(
              icon: Icons.update,
              color: Colors.grey,
              label: 'Last Sync',
              value: 'Just now',
            ),
            SystemHealthCard(
              icon: Icons.error_outline,
              color: Colors.red,
              label: 'Alerts',
              value: '1 Warning',
              isError: true,
            ),
          ],
        );
      },
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
