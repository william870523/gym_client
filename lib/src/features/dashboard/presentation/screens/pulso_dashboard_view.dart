import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../attendance/data/models/attendance_model.dart';
import '../../../attendance/presentation/state/attendance_notifier.dart';
import '../../../clients/data/models/client_model.dart';
import '../../../clients/presentation/state/client_notifier.dart';
import '../../../financials/data/models/currency_model.dart';
import '../../../financials/presentation/state/currency_notifier.dart';
import '../../../payments/data/models/payment_model.dart';
import '../../../payments/presentation/state/payment_notifier.dart';
import '../state/dashboard_nav_provider.dart';

class PulsoAdminDashboardView extends StatelessWidget {
  const PulsoAdminDashboardView({super.key});

  @override
  Widget build(BuildContext context) => const _PulsoDashboard(reception: false);
}

class PulsoReceptionDashboardView extends StatelessWidget {
  const PulsoReceptionDashboardView({super.key});

  @override
  Widget build(BuildContext context) => const _PulsoDashboard(reception: true);
}

class _PulsoDashboard extends ConsumerStatefulWidget {
  const _PulsoDashboard({required this.reception});

  final bool reception;

  @override
  ConsumerState<_PulsoDashboard> createState() => _PulsoDashboardState();
}

class _PulsoDashboardState extends ConsumerState<_PulsoDashboard> {
  Timer? _clock;
  static final _money = NumberFormat('#,##0.##');
  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _goTo(int index) =>
      ref.read(dashboardNavProvider.notifier).setIndex(index);

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(attendanceNotifierProvider.notifier).refresh(),
      ref.read(paymentNotifierProvider.notifier).refresh(),
      ref.read(clientNotifierProvider.notifier).refresh(),
      ref.read(currencyProvider.notifier).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final attendance = ref.watch(attendanceNotifierProvider);
    final payments = ref.watch(paymentNotifierProvider);
    final clients = ref.watch(clientNotifierProvider);
    final currencies = ref.watch(currencyProvider);
    final now = toGymWallClock(appClock.nowUtc(), appClock.gymTimezone);
    final facts = _DashboardFacts.compute(
      now: now,
      attendance: attendance.value ?? const [],
      payments: payments.value ?? const [],
      clients: clients.value ?? const [],
      currencies: currencies.value ?? const [],
    );
    final loading =
        attendance.isLoading || payments.isLoading || clients.isLoading;
    final hasError =
        attendance.hasError || payments.hasError || clients.hasError;

    return PulsoThemeScope(
      child: Builder(
        builder: (context) {
          final t = PulsoTokens.of(context);
          return ColoredBox(
            color: t.floor,
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 600;
                    final expanded = constraints.maxWidth >= 1040;
                    final horizontal = compact
                        ? 16.0
                        : expanded
                        ? 32.0
                        : 22.0;
                    return SingleChildScrollView(
                      key: const ValueKey('pulso-dashboard-scroll'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        22,
                        horizontal,
                        48,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _header(t, now, compact),
                          if (loading) ...[
                            const SizedBox(height: 14),
                            LinearProgressIndicator(
                              minHeight: 2,
                              color: t.accent,
                              backgroundColor: t.raised2,
                            ),
                          ],
                          if (hasError) ...[
                            const SizedBox(height: 14),
                            _statusStrip(
                              t,
                              'ALGUNOS DATOS NO PUDIERON ACTUALIZARSE',
                              t.danger,
                            ),
                          ],
                          const SizedBox(height: 18),
                          _storyStrip(t, facts),
                          const SizedBox(height: 14),
                          _kpis(t, facts, constraints.maxWidth),
                          const SizedBox(height: 14),
                          if (expanded)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 11,
                                  child: _hourlyPanel(t, facts),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 8,
                                  child: _incomePanel(t, facts),
                                ),
                              ],
                            )
                          else ...[
                            _hourlyPanel(t, facts),
                            const SizedBox(height: 14),
                            _incomePanel(t, facts),
                          ],
                          const SizedBox(height: 14),
                          if (expanded)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 11,
                                  child: _activityPanel(t, facts),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 8,
                                  child: _attentionPanel(t, facts),
                                ),
                              ],
                            )
                          else ...[
                            _attentionPanel(t, facts),
                            const SizedBox(height: 14),
                            _activityPanel(t, facts),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _header(PulsoTokens t, DateTime now, bool compact) {
    final title = widget.reception ? 'PARTE DEL TURNO' : 'PARTE DEL DÍA';
    final date = '${now.day} de ${_months[now.month - 1]} de ${now.year}';
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PulsoLabel(
          widget.reception ? 'RECEPCIÓN · OPERACIÓN' : 'PANEL · DIRECCIÓN',
        ),
        const SizedBox(height: 5),
        Text.rich(
          TextSpan(
            text: title,
            children: [
              TextSpan(
                text: '.',
                style: TextStyle(color: t.accent),
              ),
            ],
          ),
          style: TextStyle(
            fontFamily: PulsoFonts.display,
            fontSize: compact ? 31 : 42,
            height: 0.98,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
            color: t.chalk,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '$date · ${_two(now.hour)}:${_two(now.minute)} · ${appClock.gymTimezone}',
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: 11,
            color: t.muted,
          ),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        PulsoSecondaryButton(
          label: 'Actualizar',
          icon: Icons.refresh,
          onPressed: _refresh,
        ),
        PulsoPrimaryButton(
          label: widget.reception ? 'Pasar asistencia' : 'Ver turno',
          icon: Icons.how_to_reg_outlined,
          onPressed: () => _goTo(widget.reception ? 7 : 22),
        ),
      ],
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [heading, const SizedBox(height: 14), actions],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: heading),
        const SizedBox(width: 20),
        actions,
      ],
    );
  }

  Widget _storyStrip(PulsoTokens t, _DashboardFacts f) {
    final message = f.attendanceToday == 0
        ? 'La jornada aún no registra entradas.'
        : '${f.attendanceToday} ${f.attendanceToday == 1 ? 'socio pasó' : 'socios pasaron'} hoy; '
              '${f.insideNow} ${f.insideNow == 1 ? 'permanece' : 'permanecen'} dentro.';
    final attention = f.expired > 0
        ? '${f.expired} vencida${f.expired == 1 ? '' : 's'} requieren atención.'
        : f.dueSoon.isNotEmpty
        ? '${f.dueSoon.length} membresía${f.dueSoon.length == 1 ? '' : 's'} vence${f.dueSoon.length == 1 ? '' : 'n'} esta semana.'
        : 'No hay vencimientos inmediatos.';
    return _statusStrip(
      t,
      '$message  $attention',
      f.expired > 0 ? t.danger : t.success,
    );
  }

  Widget _statusStrip(PulsoTokens t, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: t.isDark ? 0.10 : 0.07),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: t.chalkDim,
        ),
      ),
    );
  }

  Widget _kpis(PulsoTokens t, _DashboardFacts f, double width) {
    final columns = width >= 1040
        ? 4
        : width >= 600
        ? 2
        : 2;
    final gap = 10.0;
    final cardWidth =
        (width -
            (columns - 1) * gap -
            (width < 600
                ? 32
                : width >= 1040
                ? 64
                : 44)) /
        columns;
    final items = [
      (
        '01',
        'ASISTENCIAS HOY',
        '${f.attendanceToday}',
        '${f.insideNow} dentro',
        t.sync,
      ),
      (
        '02',
        'SOCIOS ACTIVOS',
        '${f.activeClients}',
        'de ${f.totalClients} registrados',
        t.success,
      ),
      (
        '03',
        'COBROS HOY',
        '${f.paymentCount}',
        '${f.income.length} moneda${f.income.length == 1 ? '' : 's'}',
        t.warning,
      ),
      (
        '04',
        'ATENCIÓN',
        '${f.dueSoon.length + f.expired}',
        '${f.expired} vencidas',
        f.expired > 0 ? t.danger : t.accent,
      ),
    ];
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final item in items)
          SizedBox(
            width: math.max(140, cardWidth),
            child: _KpiCard(
              number: item.$1,
              label: item.$2,
              value: item.$3,
              note: item.$4,
              color: item.$5,
            ),
          ),
      ],
    );
  }

  Widget _hourlyPanel(PulsoTokens t, _DashboardFacts f) {
    final peak = f.hourly.fold<int>(0, math.max);
    return PulsoPanel(
      key: const ValueKey('pulso-dashboard-hourly'),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panelTitle(
            t,
            'RITMO DE ASISTENCIA',
            f.peakHour == null
                ? 'sin pico todavía'
                : 'pico ${_two(f.peakHour!)}:00',
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var hour = 6; hour <= 22; hour++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (f.hourly[hour] > 0)
                            Text(
                              '${f.hourly[hour]}',
                              style: TextStyle(
                                fontFamily: PulsoFonts.mono,
                                fontSize: 9,
                                color: t.muted,
                              ),
                            ),
                          const SizedBox(height: 3),
                          Container(
                            key: ValueKey('attendance-hour-$hour'),
                            height: peak == 0
                                ? 2
                                : math.max(3, 105 * f.hourly[hour] / peak),
                            color: f.hourly[hour] == peak && peak > 0
                                ? t.accent
                                : t.sync.withValues(alpha: 0.72),
                          ),
                          const SizedBox(height: 6),
                          if (hour.isEven)
                            Text(
                              _two(hour),
                              style: TextStyle(
                                fontFamily: PulsoFonts.mono,
                                fontSize: 8.5,
                                color: t.muted2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _incomePanel(PulsoTokens t, _DashboardFacts f) {
    return PulsoPanel(
      key: const ValueKey('pulso-dashboard-income'),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panelTitle(t, 'INGRESOS DE HOY', '${f.paymentCount} cobros'),
          const SizedBox(height: 12),
          if (f.income.isEmpty)
            _empty(t, 'Sin cobros registrados hoy')
          else
            for (final income in f.income)
              Container(
                key: ValueKey('income-${income.currencyId}'),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: t.line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            income.code,
                            style: TextStyle(
                              fontFamily: PulsoFonts.display,
                              fontWeight: FontWeight.w800,
                              color: t.chalk,
                            ),
                          ),
                          Text(
                            '${income.count} ${income.count == 1 ? 'operación' : 'operaciones'}',
                            style: TextStyle(
                              fontFamily: PulsoFonts.mono,
                              fontSize: 10,
                              color: t.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${income.symbol}${_money.format(income.amount)}',
                      style: TextStyle(
                        fontFamily: PulsoFonts.mono,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: t.warning,
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: PulsoSecondaryButton(
              label: 'Abrir pagos',
              icon: Icons.receipt_long_outlined,
              onPressed: () => _goTo(3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attentionPanel(PulsoTokens t, _DashboardFacts f) {
    final visible = [...f.expiredClients, ...f.dueSoon].take(6).toList();
    return PulsoPanel(
      key: const ValueKey('pulso-dashboard-attention'),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panelTitle(t, 'REQUIERE ATENCIÓN', '${visible.length} visibles'),
          const SizedBox(height: 10),
          if (visible.isEmpty)
            _empty(t, 'Membresías al día')
          else
            for (final due in visible)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: t.line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        due.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: t.chalk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      due.label,
                      style: TextStyle(
                        fontFamily: PulsoFonts.mono,
                        fontSize: 10.5,
                        color: due.expired ? t.danger : t.warning,
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: PulsoSecondaryButton(
              label: 'Ver socios',
              icon: Icons.people_outline,
              onPressed: () => _goTo(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityPanel(PulsoTokens t, _DashboardFacts f) {
    return PulsoPanel(
      key: const ValueKey('pulso-dashboard-activity'),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panelTitle(t, 'ACTIVIDAD RECIENTE', 'asistencia + cobros'),
          const SizedBox(height: 10),
          if (f.activity.isEmpty)
            _empty(t, 'La jornada aún no tiene movimientos')
          else
            for (final item in f.activity.take(8))
              Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: t.line)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      color: item.payment ? t.warning : t.sync,
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 42,
                      child: Text(
                        item.time,
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 10.5,
                          color: t.muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: t.chalk,
                            ),
                          ),
                          Text(
                            item.detail,
                            style: TextStyle(
                              fontFamily: PulsoFonts.mono,
                              fontSize: 9.5,
                              color: t.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item.amount != null)
                      Text(
                        item.amount!,
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontWeight: FontWeight.w700,
                          color: t.warning,
                        ),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _panelTitle(PulsoTokens t, String title, String note) {
    return Row(
      children: [
        Container(width: 8, height: 8, color: t.accent),
        const SizedBox(width: 8),
        Expanded(child: PulsoLabel(title, color: t.chalkDim)),
        Text(
          note,
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: 9.5,
            color: t.muted,
          ),
        ),
      ],
    );
  }

  Widget _empty(PulsoTokens t, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: PulsoFonts.mono,
        fontSize: 11,
        color: t.muted,
      ),
    ),
  );

  static String _two(int n) => n.toString().padLeft(2, '0');
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.number,
    required this.label,
    required this.value,
    required this.note,
    required this.color,
  });

  final String number;
  final String label;
  final String value;
  final String note;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                number,
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 9,
                  color: color,
                ),
              ),
              const Spacer(),
              Container(width: 22, height: 3, color: color),
            ],
          ),
          const SizedBox(height: 11),
          PulsoLabel(label),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontFamily: PulsoFonts.display,
              fontSize: 30,
              height: 1,
              fontWeight: FontWeight.w900,
              color: t.chalk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9.5,
              color: t.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardFacts {
  const _DashboardFacts({
    required this.attendanceToday,
    required this.insideNow,
    required this.activeClients,
    required this.totalClients,
    required this.paymentCount,
    required this.income,
    required this.dueSoon,
    required this.expiredClients,
    required this.expired,
    required this.hourly,
    required this.peakHour,
    required this.activity,
  });

  final int attendanceToday;
  final int insideNow;
  final int activeClients;
  final int totalClients;
  final int paymentCount;
  final List<_Income> income;
  final List<_Due> dueSoon;
  final List<_Due> expiredClients;
  final int expired;
  final List<int> hourly;
  final int? peakHour;
  final List<_Activity> activity;

  static _DashboardFacts compute({
    required DateTime now,
    required List<AttendanceModel> attendance,
    required List<PaymentModel> payments,
    required List<ClientModel> clients,
    required List<CurrencyModel> currencies,
  }) {
    bool sameDay(DateTime value) {
      final wall = toGymWallClock(value.toUtc(), appClock.gymTimezone);
      return wall.year == now.year &&
          wall.month == now.month &&
          wall.day == now.day;
    }

    String clientName(String id, [String? joined]) {
      if (joined?.trim().isNotEmpty == true) return joined!.trim();
      final client = clients.where((item) => item.id == id).firstOrNull;
      if (client == null) return id;
      final name = '${client.nombres ?? ''} ${client.apellidos ?? ''}'.trim();
      return name.isEmpty ? id : name;
    }

    final todayAttendance = attendance
        .where((item) => sameDay(item.checkIn))
        .toList();
    final uniqueVisitors = todayAttendance.map((item) => item.clientId).toSet();
    final inside = todayAttendance
        .where((item) => item.checkOut == null)
        .map((item) => item.clientId)
        .toSet();
    final todayPayments = payments
        .where((item) => !item.isDeleted && sameDay(item.fecha))
        .toList();
    final currencyById = {
      for (final currency in currencies) currency.id: currency,
    };
    final incomeMap = <String, (double, int)>{};
    for (final payment in todayPayments) {
      final current = incomeMap[payment.currencyId] ?? (0.0, 0);
      incomeMap[payment.currencyId] = (
        current.$1 + payment.amount,
        current.$2 + 1,
      );
    }
    final income = incomeMap.entries.map((entry) {
      final currency = currencyById[entry.key];
      return _Income(
        currencyId: entry.key,
        code: currency?.code ?? entry.key.toUpperCase(),
        symbol: currency?.symbol?.trim().isNotEmpty == true
            ? currency!.symbol!.trim()
            : '${currency?.code ?? entry.key} ',
        amount: entry.value.$1,
        count: entry.value.$2,
      );
    }).toList()..sort((a, b) => a.code.compareTo(b.code));

    final today = DateTime(now.year, now.month, now.day);
    final dueSoon = <_Due>[];
    final expiredClients = <_Due>[];
    for (final client in clients.where(
      (item) => item.activo && item.endDate != null,
    )) {
      final end = client.endDate!;
      final days = DateTime(
        end.year,
        end.month,
        end.day,
      ).difference(today).inDays;
      final name = clientName(client.id);
      if (days < 0) {
        expiredClients.add(
          _Due(
            name: name,
            label: 'vencida hace ${days.abs()} d',
            expired: true,
          ),
        );
      } else if (days <= 7) {
        dueSoon.add(
          _Due(
            name: name,
            label: days == 0
                ? 'vence hoy'
                : days == 1
                ? 'mañana'
                : 'en $days d',
            expired: false,
          ),
        );
      }
    }
    expiredClients.sort((a, b) => a.name.compareTo(b.name));
    dueSoon.sort((a, b) => a.label.compareTo(b.label));

    final hourly = List<int>.filled(24, 0);
    for (final item in todayAttendance) {
      final wall = toGymWallClock(item.checkIn.toUtc(), appClock.gymTimezone);
      hourly[wall.hour]++;
    }
    int? peakHour;
    for (var hour = 0; hour < hourly.length; hour++) {
      if (hourly[hour] > 0 &&
          (peakHour == null || hourly[hour] > hourly[peakHour])) {
        peakHour = hour;
      }
    }

    final activity = <_Activity>[];
    for (final payment in todayPayments) {
      final wall = toGymWallClock(payment.fecha.toUtc(), appClock.gymTimezone);
      final curr = currencyById[payment.currencyId];
      final symbol = curr?.symbol?.trim().isNotEmpty == true
          ? curr!.symbol!.trim()
          : '${curr?.code ?? payment.currencyId} ';
      activity.add(
        _Activity(
          instant: payment.fecha,
          time:
              '${_PulsoDashboardState._two(wall.hour)}:${_PulsoDashboardState._two(wall.minute)}',
          name: clientName(payment.ci, payment.clientName),
          detail: 'COBRO',
          amount:
              '$symbol${_PulsoDashboardState._money.format(payment.amount)}',
          payment: true,
        ),
      );
    }
    for (final item in todayAttendance) {
      final wall = toGymWallClock(item.checkIn.toUtc(), appClock.gymTimezone);
      activity.add(
        _Activity(
          instant: item.checkIn,
          time:
              '${_PulsoDashboardState._two(wall.hour)}:${_PulsoDashboardState._two(wall.minute)}',
          name: clientName(item.clientId, item.clientName),
          detail: item.checkOut == null ? 'DENTRO AHORA' : 'VISITA FINALIZADA',
          amount: null,
          payment: false,
        ),
      );
    }
    activity.sort((a, b) => b.instant.compareTo(a.instant));

    return _DashboardFacts(
      attendanceToday: uniqueVisitors.length,
      insideNow: inside.length,
      activeClients: clients.where((item) => item.activo).length,
      totalClients: clients.length,
      paymentCount: todayPayments.length,
      income: income,
      dueSoon: dueSoon,
      expiredClients: expiredClients,
      expired: expiredClients.length,
      hourly: hourly,
      peakHour: peakHour,
      activity: activity,
    );
  }
}

class _Income {
  const _Income({
    required this.currencyId,
    required this.code,
    required this.symbol,
    required this.amount,
    required this.count,
  });
  final String currencyId;
  final String code;
  final String symbol;
  final double amount;
  final int count;
}

class _Due {
  const _Due({required this.name, required this.label, required this.expired});
  final String name;
  final String label;
  final bool expired;
}

class _Activity {
  const _Activity({
    required this.instant,
    required this.time,
    required this.name,
    required this.detail,
    required this.amount,
    required this.payment,
  });
  final DateTime instant;
  final String time;
  final String name;
  final String detail;
  final String? amount;
  final bool payment;
}
