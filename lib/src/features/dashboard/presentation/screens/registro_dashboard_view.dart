import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/registro_palette.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/registro_dashboard_widgets.dart';
import '../../../../core/widgets/registro_widgets.dart';
import '../../../attendance/data/models/attendance_model.dart';
import '../../../attendance/presentation/state/attendance_notifier.dart';
import '../../../clients/data/models/client_model.dart';
import '../../../clients/presentation/state/client_notifier.dart';
import '../../../configuration/data/models/payment_type_model.dart';
import '../../../financials/data/models/currency_model.dart';
import '../../../financials/presentation/state/currency_notifier.dart';
import '../../../payments/data/models/payment_model.dart';
import '../../../payments/presentation/state/payment_notifier.dart';
import '../../../products/data/models/payment_plan_model.dart';
import '../../../products/presentation/state/payment_plan_notifier.dart';
import '../state/dashboard_nav_provider.dart';

DateTime _gymWallTime(DateTime instant) =>
    toGymWallClock(instant, appClock.gymTimezone);

DateTime _gymNow() => _gymWallTime(appClock.nowUtc());

/// Dashboard admin — "PARTE DEL DÍA" (F-01, arquetipo 2 del sistema REGISTRO).
///
/// Atlas estadístico impreso con tintas de datos ([RegistroInks]): azul =
/// asistencia, ocre = ingresos, verde = socios, vermellón = alertas.
/// Mockup de referencia: docs/registro_dashboard.html.
///
/// Todos los datos son reales: [attendanceNotifierProvider] (asistencias de
/// hoy), [paymentNotifierProvider] (pagos), [clientNotifierProvider]
/// (socios y vencimientos) y [paymentTypesProvider] (métodos de pago).
class RegistroDashboardView extends ConsumerStatefulWidget {
  const RegistroDashboardView({super.key});

  @override
  ConsumerState<RegistroDashboardView> createState() =>
      _RegistroDashboardViewState();
}

class _RegistroDashboardViewState extends ConsumerState<RegistroDashboardView> {
  Timer? _clockTimer;

  static final _hm = DateFormat('HH:mm');
  static final _money = NumberFormat('#,##0.##');

  static const _weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
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
    // Reloj del membrete y colofón ("parte compuesto a las HH:MM").
    _clockTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _refreshAll() {
    unawaited(
      Future.wait([
        ref.read(attendanceNotifierProvider.notifier).refresh(),
        ref.read(paymentNotifierProvider.notifier).refresh(),
        ref.read(clientNotifierProvider.notifier).refresh(),
      ]),
    );
    ref.invalidate(paymentTypesProvider);
    ref.invalidate(paymentPlanProvider);
    ref.invalidate(currencyProvider);
  }

  void _goTo(int index) =>
      ref.read(dashboardNavProvider.notifier).setIndex(index);

  String _dateLine(DateTime now) =>
      '${_weekdays[now.weekday - 1]}, ${now.day} de ${_months[now.month - 1]} '
      'de ${now.year} · diamond gym';

  String _dueLabel(DateTime end, DateTime today) {
    final d = DateTime(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
    if (d < 0) return 'vencida †';
    if (d == 0) return 'hoy';
    if (d == 1) return 'mañana';
    return 'en $d días';
  }

  void _copyReport(_DayFacts f) {
    final now = _gymNow();
    final sb = StringBuffer()
      ..writeln('PARTE DEL DÍA — ${_dateLine(now)}')
      ..writeln('Asistencias: ${f.attToday} (${f.inside} dentro ahora)')
      ..writeln(
        'Ingresos: ${f.incomeSymbol}${_money.format(f.incomeToday)} '
        'en ${f.paymentsToday} pagos',
      )
      ..writeln('Socios activos: ${f.activeClients} de ${f.totalClients}')
      ..writeln(
        'Membresías por vencer (7 días): ${f.dueSoon.length} · vencidas: ${f.expired}',
      )
      ..writeln('Compuesto a las ${_hm.format(now)} · GYM·OS');
    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Parte del día copiado al portapapeles.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(dashboardNavProvider, (previous, next) {
      if (next == 0 && previous != 0) {
        Future.microtask(_refreshAll);
      }
    });

    final isNight = Theme.of(context).brightness == Brightness.dark;
    final p = RegistroPalette.of(isNight);
    final inks = RegistroInks.of(isNight);
    final now = _gymNow();

    final attendanceAsync = ref.watch(attendanceNotifierProvider);
    final paymentsAsync = ref.watch(paymentNotifierProvider);
    final clientsAsync = ref.watch(clientNotifierProvider);
    final typesAsync = ref.watch(paymentTypesProvider);
    final plansAsync = ref.watch(paymentPlanProvider);
    final currenciesAsync = ref.watch(currencyProvider);

    final facts = _DayFacts.compute(
      now: now,
      attendance: attendanceAsync.value ?? const [],
      payments: paymentsAsync.value ?? const [],
      clients: clientsAsync.value ?? const [],
      paymentTypes: typesAsync.value ?? const [],
      paymentPlans: plansAsync.value ?? const [],
      currencies: currenciesAsync.value ?? const [],
    );
    final loading =
        attendanceAsync.isLoading &&
        paymentsAsync.isLoading &&
        clientsAsync.isLoading;

    return Scaffold(
      backgroundColor: p.paper,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(44, 30, 44, 72),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RegistroMasthead(
                p: p,
                department: 'PANEL',
                code: 'F-01 / GENERAL · ${_hm.format(now)}',
              ),
              const SizedBox(height: 26),
              _buildTitleRow(p, now, facts),
              const SizedBox(height: 18),
              _buildLedgerLine(p, inks, facts, loading),
              const SizedBox(height: 26),
              _buildFigures(p, inks, facts),
              const SizedBox(height: 36),
              _buildChartsRow(p, inks, facts),
              const SizedBox(height: 36),
              _buildSheet(p, inks, facts, now),
              const SizedBox(height: 44),
              _buildPageColophon(p, inks, now),
            ],
          ),
        ),
      ),
    );
  }

  // ===== título =====
  Widget _buildTitleRow(RegistroPalette p, DateTime now, _DayFacts f) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: 'PARTE\nDEL DÍA',
                  children: [
                    TextSpan(
                      text: '.',
                      style: TextStyle(color: p.verm),
                    ),
                  ],
                ),
                style: GoogleFonts.archivoBlack(
                  fontSize: 46,
                  height: 0.98,
                  letterSpacing: -1.0,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _dateLine(now),
                style: GoogleFonts.fragmentMono(fontSize: 12, color: p.ink3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Wrap(
          spacing: 26,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            RegistroTextAction(p: p, label: '↻ ACTUALIZAR', onTap: _refreshAll),
            RegistroTextAction(
              p: p,
              label: '⎙ COPIAR PARTE',
              onTap: () => _copyReport(f),
            ),
            // Vista previa del panel de recepción (índice 22), para que el
            // admin pueda verlo sin iniciar sesión como recepcionista.
            RegistroTextAction(
              p: p,
              label: '◱ PANEL RECEPCIÓN',
              onTap: () => _goTo(22),
            ),
            RegistroTextAction(
              p: p,
              label: '＋ REGISTRAR PAGO',
              prime: true,
              onTap: () => _goTo(3),
            ),
          ],
        ),
      ],
    );
  }

  // ===== oración-resumen =====
  Widget _buildLedgerLine(
    RegistroPalette p,
    RegistroInks inks,
    _DayFacts f,
    bool loading,
  ) {
    final base = GoogleFonts.archivo(
      fontSize: 19,
      height: 1.6,
      color: p.ink2,
      fontWeight: FontWeight.w400,
    );
    TextStyle big(Color c) => GoogleFonts.archivo(
      fontSize: 25,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: c,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final Widget sentence;
    if (loading) {
      sentence = Text(
        'Componiendo el parte…',
        style: base.copyWith(fontStyle: FontStyle.italic),
      );
    } else {
      sentence = Text.rich(
        TextSpan(
          style: base,
          children: [
            TextSpan(
              text: f.attToday == 1 ? 'Hoy asistió ' : 'Hoy asistieron ',
            ),
            TextSpan(text: '${f.attToday}', style: big(inks.azul)),
            TextSpan(text: f.attToday == 1 ? ' socio' : ' socios'),
            TextSpan(text: f.inside == 1 ? ' y queda ' : ' y quedan '),
            TextSpan(text: '${f.inside}', style: big(p.ink)),
            const TextSpan(text: ' dentro; '),
            TextSpan(text: f.paymentsToday == 1 ? 'ingresó ' : 'ingresaron '),
            TextSpan(
              text: '${f.incomeSymbol}${_money.format(f.incomeToday)}',
              style: big(inks.ocre),
            ),
            TextSpan(text: ' en '),
            TextSpan(text: '${f.paymentsToday}', style: big(p.ink)),
            TextSpan(text: f.paymentsToday == 1 ? ' pago, y ' : ' pagos, y '),
            TextSpan(text: '${f.dueSoon.length}', style: big(p.verm)),
            TextSpan(
              text: f.dueSoon.length == 1
                  ? ' membresía vence esta semana.'
                  : ' membresías vencen esta semana.',
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: p.rule),
          bottom: BorderSide(color: p.rule),
        ),
      ),
      child: sentence,
    );
  }

  // ===== figuras 01–04 =====
  Widget _buildFigures(RegistroPalette p, RegistroInks inks, _DayFacts f) {
    final deltaNote = f.incomeYesterday > 0
        ? '${f.incomeToday >= f.incomeYesterday ? '▲' : '▼'} '
              '${((f.incomeToday - f.incomeYesterday).abs() / f.incomeYesterday * 100).round()}% vs. ayer'
        : '${f.paymentsToday} ${f.paymentsToday == 1 ? 'pago' : 'pagos'}';

    final figures = [
      RegistroFigure(
        number: '01',
        caption: 'asistencia',
        value: '${f.attToday}',
        note:
            '${f.inside} dentro ahora'
            '${f.peakHour != null ? ' · pico ${f.peakHour}:00' : ''}',
        ink: inks.azul,
        meter: f.attToday == 0 ? 0 : f.inside / f.attToday,
      ),
      RegistroFigure(
        number: '02',
        caption: 'ingresos del día',
        value: '${f.incomeSymbol}${_money.format(f.incomeToday)}',
        note:
            '$deltaNote · ${f.paymentsToday} '
            '${f.paymentsToday == 1 ? 'pago' : 'pagos'}',
        ink: inks.ocre,
        meter: (f.incomeToday + f.incomeYesterday) == 0
            ? 0
            : f.incomeToday / (f.incomeToday + f.incomeYesterday),
      ),
      RegistroFigure(
        number: '03',
        caption: 'socios activos',
        value: '${f.activeClients}',
        note:
            'de ${f.totalClients} registrados'
            '${f.totalClients > 0 ? ' · ${(f.activeClients / f.totalClients * 100).round()}%' : ''}',
        ink: inks.verde,
        meter: f.totalClients == 0 ? 0 : f.activeClients / f.totalClients,
      ),
      RegistroFigure(
        number: '04',
        caption: 'por vencer',
        value: '${f.dueSoon.length}',
        note:
            'próximos 7 días · ${f.expired} '
            '${f.expired == 1 ? 'vencida' : 'vencidas'}',
        ink: p.verm,
        meter: f.activeClients == 0
            ? 0
            : (f.dueSoon.length / f.activeClients).clamp(0.0, 1.0),
      ),
    ];

    return RegistroFiguresGrid(p: p, figures: figures);
  }

  // ===== láminas 05 + 06 =====
  Widget _buildChartsRow(RegistroPalette p, RegistroInks inks, _DayFacts f) {
    final curve = RegistroPlateFrame(
      p: p,
      tick: inks.azul,
      number: '05',
      title: 'CURVA HORARIA DE ASISTENCIA',
      note: 'socios por hora · hoy',
      child: f.attToday == 0
          ? RegistroPlateEmpty(p: p, message: 'sin asistencias registradas hoy')
          : RegistroHourlyChart(p: p, ink: inks.azul, buckets: f.hourly),
    );
    final pie = RegistroPlateFrame(
      p: p,
      tick: inks.ocre,
      number: '06',
      title: 'INGRESOS POR MÉTODO',
      note: 'hoy',
      child: f.byMethod.isEmpty
          ? RegistroPlateEmpty(p: p, message: 'sin pagos registrados hoy')
          : _MethodPie(
              p: p,
              inks: inks,
              total: f.incomeToday,
              count: f.paymentsToday,
              symbol: f.incomeSymbol,
              slices: f.byMethod,
            ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 1000) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 8, child: curve),
              const SizedBox(width: 44),
              Expanded(flex: 5, child: pie),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [curve, const SizedBox(height: 36), pie],
        );
      },
    );
  }

  // ===== pliego: movimientos + margen =====
  Widget _buildSheet(
    RegistroPalette p,
    RegistroInks inks,
    _DayFacts f,
    DateTime now,
  ) {
    final movements = RegistroPlateFrame(
      p: p,
      tick: null,
      number: '07',
      title: 'ÚLTIMOS MOVIMIENTOS',
      note: 'hoy · en tiempo real',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (f.movements.isEmpty)
            RegistroPlateEmpty(p: p, message: 'aún no hay movimientos hoy')
          else
            for (int i = 0; i < f.movements.length; i++)
              _MovementRow(p: p, inks: inks, index: i + 1, m: f.movements[i]),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: p.ruleStrong, width: 2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${f.movements.length} '
                  '${f.movements.length == 1 ? 'movimiento' : 'movimientos'} de hoy',
                  style: GoogleFonts.fragmentMono(fontSize: 10, color: p.ink3),
                ),
                RegistroMarginAction(
                  p: p,
                  label: 'VER LIBRO DE PAGOS',
                  onTap: () => _goTo(3),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final margin = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RegistroPlateFrame(
          p: p,
          tick: p.verm,
          number: '08',
          title: 'VENCIMIENTOS',
          note: null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (f.dueList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'sin vencimientos próximos ¶',
                    style: GoogleFonts.fragmentMono(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: p.ink3,
                    ),
                  ),
                )
              else ...[
                for (final c in f.dueList.take(6))
                  _DueRow(
                    p: p,
                    name: _clientName(c),
                    label: _dueLabel(c.endDate!, now),
                    hot: !c.endDate!.isAfter(
                      DateTime(now.year, now.month, now.day + 1),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '† ',
                          style: TextStyle(color: p.verm),
                        ),
                        const TextSpan(
                          text: 'membresía vencida — requiere renovación',
                        ),
                      ],
                    ),
                    style: GoogleFonts.fragmentMono(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: p.ink3,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 34),
        Container(
          padding: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: p.ruleStrong, width: 2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ACCESOS RÁPIDOS',
                style: GoogleFonts.archivo(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                  color: p.ink3,
                ),
              ),
              const SizedBox(height: 12),
              RegistroMarginAction(
                p: p,
                label: 'REGISTRAR PAGO',
                onTap: () => _goTo(3),
              ),
              const SizedBox(height: 10),
              RegistroMarginAction(
                p: p,
                label: 'PASAR ASISTENCIA',
                onTap: () => _goTo(7),
              ),
              const SizedBox(height: 10),
              RegistroMarginAction(
                p: p,
                label: 'VER CLIENTES',
                onTap: () => _goTo(1),
              ),
              const SizedBox(height: 10),
              RegistroMarginAction(
                p: p,
                label: 'VER CONTABILIDAD',
                onTap: () => _goTo(20),
              ),
            ],
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 1000) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: movements),
              const SizedBox(width: 44),
              SizedBox(width: 272, child: margin),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [movements, const SizedBox(height: 36), margin],
        );
      },
    );
  }

  Widget _buildPageColophon(
    RegistroPalette p,
    RegistroInks inks,
    DateTime now,
  ) {
    final mono = GoogleFonts.fragmentMono(fontSize: 10, color: p.ink3);
    Widget leg(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, color: c),
        const SizedBox(width: 5),
        Text(label, style: mono),
      ],
    );

    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.ruleStrong, width: 3)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 8,
        children: [
          Text(
            'parte compuesto a las ${_hm.format(now)} · datos en tiempo real',
            style: mono,
          ),
          Wrap(
            spacing: 14,
            children: [
              leg(inks.azul, 'asistencia'),
              leg(inks.ocre, 'ingresos'),
              leg(inks.verde, 'socios'),
              leg(p.verm, 'alertas'),
            ],
          ),
        ],
      ),
    );
  }

  static String _clientName(ClientModel c) {
    final n = '${c.nombres ?? ''} ${c.apellidos ?? ''}'.trim();
    return n.isEmpty ? c.id : n;
  }
}

// =========================================================================
// Cálculo de los hechos del día a partir de los providers
// =========================================================================
class _Movement {
  final DateTime time;
  final String kind; // 'PAGO · …', 'ENTRADA', 'SALIDA'
  final String name;
  final String? method;
  final double? amount;
  final String? currencySymbol;
  final _MovementInk ink;
  const _Movement({
    required this.time,
    required this.kind,
    required this.name,
    required this.method,
    required this.amount,
    required this.currencySymbol,
    required this.ink,
  });
}

enum _MovementInk { ocre, azul, verde }

class _MethodSlice {
  final String label;
  final double amount;
  const _MethodSlice(this.label, this.amount);
}

class _DayFacts {
  final int attToday;
  final int inside;
  final Map<int, int> hourly; // hora → asistencias
  final int? peakHour;
  final double incomeToday;
  final double incomeYesterday;
  final String incomeSymbol;
  final int paymentsToday;
  final List<_MethodSlice> byMethod;
  final int totalClients;
  final int activeClients;
  final List<ClientModel> dueSoon; // vencen en ≤7 días (no vencidas)
  final List<ClientModel> dueList; // vencidas + por vencer, ordenadas
  final int expired;
  final List<_Movement> movements;

  const _DayFacts({
    required this.attToday,
    required this.inside,
    required this.hourly,
    required this.peakHour,
    required this.incomeToday,
    required this.incomeYesterday,
    required this.incomeSymbol,
    required this.paymentsToday,
    required this.byMethod,
    required this.totalClients,
    required this.activeClients,
    required this.dueSoon,
    required this.dueList,
    required this.expired,
    required this.movements,
  });

  static _DayFacts compute({
    required DateTime now,
    required List<AttendanceModel> attendance,
    required List<PaymentModel> payments,
    required List<ClientModel> clients,
    required List<PaymentTypeModel> paymentTypes,
    required List<PaymentPlanModel> paymentPlans,
    required List<CurrencyModel> currencies,
  }) {
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Los timestamps llegan en UTC y se convierten a la zona IANA del gimnasio,
    // nunca a la zona del equipo que abre la aplicación.

    // --- asistencia (el provider ya trae solo las de hoy) ---
    final attToday = attendance
        .where((a) => sameDay(_gymWallTime(a.checkIn), now))
        .toList();
    final inside = attToday.where((a) => a.checkOut == null).length;
    final hourly = <int, int>{};
    for (final a in attToday) {
      final h = _gymWallTime(a.checkIn).hour;
      hourly[h] = (hourly[h] ?? 0) + 1;
    }
    int? peak;
    var peakCount = 0;
    hourly.forEach((h, c) {
      if (c > peakCount) {
        peak = h;
        peakCount = c;
      }
    });

    // --- pagos ---
    final validPayments = payments.where((x) => !x.isDeleted).toList();
    final payToday = validPayments
        .where((x) => sameDay(_gymWallTime(x.fecha), today))
        .toList();
    final payYesterday = validPayments
        .where((x) => sameDay(_gymWallTime(x.fecha), yesterday))
        .toList();
    final incomeToday = payToday.fold<double>(0, (s, x) => s + x.amount);
    final incomeYesterday = payYesterday.fold<double>(
      0,
      (s, x) => s + x.amount,
    );

    // ingresos por método (desde los detalles; sin detalle → "otros")
    final typeNames = {for (final t in paymentTypes) t.id: t.name};
    final clientsById = {for (final client in clients) client.id: client};
    final planNames = {
      for (final plan in paymentPlans)
        if (plan.id != null) plan.id!: plan.nombre,
    };
    final currencySymbols = {
      for (final currency in currencies)
        currency.id: currency.symbol?.trim().isNotEmpty == true
            ? currency.symbol!.trim()
            : currency.code,
    };
    final paymentCurrencyIds = payToday.map((pay) => pay.currencyId).toSet();
    final incomeSymbol = paymentCurrencyIds.length == 1
        ? currencySymbols[paymentCurrencyIds.single] ?? '\$'
        : paymentCurrencyIds.isEmpty
        ? '\$'
        : '¤';
    final byMethodMap = <String, double>{};
    for (final pay in payToday) {
      final details = pay.details ?? const <PaymentDetailModel>[];
      if (details.isEmpty) {
        byMethodMap['Otros'] = (byMethodMap['Otros'] ?? 0) + pay.amount;
      } else {
        for (final d in details) {
          final label = typeNames[d.paymentTypeId] ?? 'Otros';
          byMethodMap[label] = (byMethodMap[label] ?? 0) + d.amount;
        }
      }
    }
    final byMethod =
        byMethodMap.entries.map((e) => _MethodSlice(e.key, e.value)).toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

    // --- socios y vencimientos ---
    final totalClients = clients.length;
    final activeClients = clients.where((c) => c.activo).length;
    final withEnd = clients.where((c) => c.activo && c.endDate != null).toList()
      ..sort((a, b) => a.endDate!.compareTo(b.endDate!));
    final horizon = today.add(const Duration(days: 7));
    final expiredList = withEnd
        .where((c) => c.endDate!.isBefore(today))
        .toList();
    final dueSoon = withEnd
        .where(
          (c) => !c.endDate!.isBefore(today) && !c.endDate!.isAfter(horizon),
        )
        .toList();
    final dueList = [...dueSoon, ...expiredList.reversed];

    // --- movimientos: pagos + entradas + salidas de hoy ---
    final movements = <_Movement>[
      for (final pay in payToday)
        _Movement(
          time: _gymWallTime(pay.fecha),
          kind: _paymentMovementKind(pay: pay, planNames: planNames),
          name: _paymentClientName(pay, clientsById),
          method: _paymentMethod(pay, typeNames),
          amount: pay.amount,
          currencySymbol: currencySymbols[pay.currencyId] ?? '\$',
          ink: _MovementInk.ocre,
        ),
      for (final a in attToday)
        _Movement(
          time: _gymWallTime(a.checkIn),
          kind: 'ENTRADA',
          name: _attendanceClientName(a, clientsById),
          method: null,
          amount: null,
          currencySymbol: null,
          ink: _MovementInk.verde,
        ),
      for (final a in attToday.where((a) => a.checkOut != null))
        _Movement(
          time: _gymWallTime(a.checkOut!),
          kind: 'SALIDA',
          name: _attendanceClientName(a, clientsById),
          method: null,
          amount: null,
          currencySymbol: null,
          ink: _MovementInk.azul,
        ),
    ]..sort((a, b) => b.time.compareTo(a.time));

    return _DayFacts(
      attToday: attToday.length,
      inside: inside,
      hourly: hourly,
      peakHour: peak,
      incomeToday: incomeToday,
      incomeYesterday: incomeYesterday,
      incomeSymbol: incomeSymbol,
      paymentsToday: payToday.length,
      byMethod: byMethod,
      totalClients: totalClients,
      activeClients: activeClients,
      dueSoon: dueSoon,
      dueList: dueList,
      expired: expiredList.length,
      movements: movements.take(8).toList(),
    );
  }

  static String _paymentClientName(
    PaymentModel payment,
    Map<String, ClientModel> clientsById,
  ) {
    final client = clientsById[payment.ci];
    final catalogName = client == null
        ? ''
        : '${client.nombres ?? ''} ${client.apellidos ?? ''}'.trim();
    if (catalogName.isNotEmpty) {
      return catalogName;
    }
    if (payment.clientName?.trim().isNotEmpty == true) {
      return payment.clientName!.trim();
    }
    return payment.ci;
  }

  static String _attendanceClientName(
    AttendanceModel attendance,
    Map<String, ClientModel> clientsById,
  ) {
    if (attendance.clientName?.trim().isNotEmpty == true) {
      return attendance.clientName!.trim();
    }
    final client = clientsById[attendance.clientId];
    final catalogName = client == null
        ? ''
        : '${client.nombres ?? ''} ${client.apellidos ?? ''}'.trim();
    return catalogName.isNotEmpty ? catalogName : attendance.clientId;
  }

  static String _paymentMovementKind({
    required PaymentModel pay,
    required Map<String, String> planNames,
  }) {
    final parts = <String>['PAGO'];
    final planName = planNames[pay.planId]?.trim();
    if (planName?.isNotEmpty == true) {
      parts.add(planName!.toUpperCase());
    }
    return parts.join(' · ');
  }

  static String? _paymentMethod(
    PaymentModel pay,
    Map<String, String> typeNames,
  ) {
    final methods = <String>{
      for (final detail in pay.details ?? const <PaymentDetailModel>[])
        if (typeNames[detail.paymentTypeId]?.trim().isNotEmpty == true)
          typeNames[detail.paymentTypeId]!.trim().toUpperCase(),
    };
    return methods.isEmpty ? null : methods.join(' + ');
  }
}

// =========================================================================
// fig. 06 — pastel de ingresos por método
// =========================================================================
class _MethodPie extends StatelessWidget {
  const _MethodPie({
    required this.p,
    required this.inks,
    required this.total,
    required this.count,
    required this.symbol,
    required this.slices,
  });

  final RegistroPalette p;
  final RegistroInks inks;
  final double total;
  final int count;
  final String symbol;
  final List<_MethodSlice> slices;

  static final _money = NumberFormat('#,##0.##');

  @override
  Widget build(BuildContext context) {
    final colors = [inks.ocre, inks.azul, inks.verde, p.ink3, p.ink4];

    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < slices.length && i < 5; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              border: i < math.min(slices.length, 5) - 1
                  ? Border(
                      bottom: BorderSide(
                        color: p.rule,
                        style: BorderStyle.solid,
                      ),
                    )
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  color: colors[i % colors.length],
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    slices[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.archivo(fontSize: 12.5, color: p.ink),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: RegistroDottedLine(color: p.ink4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$symbol${_money.format(slices[i].amount)}',
                  style: GoogleFonts.fragmentMono(fontSize: 12, color: p.ink),
                ),
                const SizedBox(width: 6),
                Text(
                  total == 0
                      ? ''
                      : '${(slices[i].amount / total * 100).round()}%',
                  style: GoogleFonts.fragmentMono(fontSize: 10, color: p.ink3),
                ),
              ],
            ),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: LayoutBuilder(
        builder: (context, c) {
          final pie = SizedBox(
            width: 156,
            height: 156,
            child: CustomPaint(
              painter: _PiePainter(
                slices: slices,
                total: total,
                colors: colors,
                paper: p.paper,
                outline: p.ruleStrong,
                rule: p.rule,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$symbol${_money.format(total)}',
                      style: GoogleFonts.archivo(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: p.ink,
                      ),
                    ),
                    Text(
                      '$count ${count == 1 ? 'pago' : 'pagos'}',
                      style: GoogleFonts.fragmentMono(
                        fontSize: 9,
                        color: p.ink3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          if (c.maxWidth < 360) {
            return Column(children: [pie, const SizedBox(height: 18), legend]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              pie,
              const SizedBox(width: 26),
              Expanded(child: legend),
            ],
          );
        },
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({
    required this.slices,
    required this.total,
    required this.colors,
    required this.paper,
    required this.outline,
    required this.rule,
  });

  final List<_MethodSlice> slices;
  final double total;
  final List<Color> colors;
  final Color paper;
  final Color outline;
  final Color rule;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius - 4);

    if (total <= 0) return;

    var start = -math.pi / 2;
    for (int i = 0; i < slices.length; i++) {
      final sweep = (slices[i].amount / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, start, sweep, true, paint);
      start += sweep;
    }

    // contorno exterior de tinta, como una lámina impresa
    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // centro de papel (anillo)
    canvas.drawCircle(
      center,
      radius - 38,
      Paint()
        ..color = paper
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      radius - 38,
      Paint()
        ..color = rule
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) =>
      old.slices != slices || old.total != total || old.paper != paper;
}

// =========================================================================
// fig. 07 — movimientos
// =========================================================================
class _MovementRow extends StatefulWidget {
  const _MovementRow({
    required this.p,
    required this.inks,
    required this.index,
    required this.m,
  });

  final RegistroPalette p;
  final RegistroInks inks;
  final int index;
  final _Movement m;

  @override
  State<_MovementRow> createState() => _MovementRowState();
}

class _MovementRowState extends State<_MovementRow> {
  bool _hover = false;

  static final _hm = DateFormat('HH:mm');
  static final _money = NumberFormat('#,##0.##');

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final m = widget.m;
    final tick = switch (m.ink) {
      _MovementInk.ocre => widget.inks.ocre,
      _MovementInk.azul => widget.inks.azul,
      _MovementInk.verde => widget.inks.verde,
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        color: _hover ? p.paper2 : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final identity = _MovementIdentity(p: p, m: m, tick: tick);
            final method = Text(
              m.method ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.fragmentMono(fontSize: 12, color: p.ink2),
            );
            final amount = Text(
              key: ValueKey('movement-amount-${m.ink.name}'),
              m.amount == null
                  ? '—'
                  : '${m.currencySymbol ?? '\$'}${_money.format(m.amount)}',
              textAlign: TextAlign.right,
              style: GoogleFonts.fragmentMono(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: m.amount == null ? p.ink4 : p.ink,
              ),
            );
            final time = Text(
              key: ValueKey('movement-time-${m.ink.name}'),
              _hm.format(m.time),
              textAlign: TextAlign.right,
              style: GoogleFonts.fragmentMono(fontSize: 12, color: p.ink2),
            );

            if (constraints.maxWidth < 620) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MovementIndex(p: p, index: widget.index),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        identity,
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: method),
                            SizedBox(
                              width: 96,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: amount,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 58,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: time,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                _MovementIndex(p: p, index: widget.index),
                Expanded(flex: 5, child: identity),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: method),
                const SizedBox(width: 16),
                SizedBox(
                  width: 120,
                  child: Align(alignment: Alignment.centerRight, child: amount),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: 120,
                  child: Align(alignment: Alignment.centerRight, child: time),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MovementIndex extends StatelessWidget {
  const _MovementIndex({required this.p, required this.index});

  final RegistroPalette p;
  final int index;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      child: Text(
        index.toString().padLeft(2, '0'),
        style: GoogleFonts.fragmentMono(fontSize: 11, color: p.ink4),
      ),
    );
  }
}

class _MovementIdentity extends StatelessWidget {
  const _MovementIdentity({
    required this.p,
    required this.m,
    required this.tick,
  });

  final RegistroPalette p;
  final _Movement m;
  final Color tick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              key: ValueKey('movement-ink-${m.ink.name}'),
              width: 7,
              height: 7,
              color: tick,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                m.kind,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.archivo(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                  color: p.ink3,
                ),
              ),
            ),
          ],
        ),
        Text(
          m.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.archivo(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: p.ink,
          ),
        ),
      ],
    );
  }
}

// =========================================================================
// fig. 08 — vencimientos
// =========================================================================
class _DueRow extends StatelessWidget {
  const _DueRow({
    required this.p,
    required this.name,
    required this.label,
    required this.hot,
  });

  final RegistroPalette p;
  final String name;
  final String label;
  final bool hot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.rule)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.archivo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: p.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: RegistroDottedLine(color: p.ink4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.fragmentMono(
              fontSize: 11,
              color: hot ? p.verm : p.ink3,
            ),
          ),
        ],
      ),
    );
  }
}
