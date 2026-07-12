import 'dart:async';

import 'package:flutter/material.dart';
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
import '../../../financials/data/models/currency_model.dart';
import '../../../financials/presentation/state/currency_notifier.dart';
import '../../../payments/data/models/payment_model.dart';
import '../../../payments/presentation/state/payment_notifier.dart';
import '../state/dashboard_nav_provider.dart';

/// Dashboard de recepción — "PARTE DEL TURNO" (F-01 · variante recepción del
/// arquetipo "Parte del día"). Reutiliza las láminas compartidas
/// ([RegistroFiguresGrid], [RegistroHourlyChart]…) y se enfoca en la operación
/// del día: asistencia, aforo, cobros del turno y vencimientos, con enlaces al
/// Mostrador. Ver docs/DESIGN_SYSTEM.md. Datos reales de los providers de
/// asistencia, pagos, clientes y monedas.
class RegistroReceptionDashboardView extends ConsumerStatefulWidget {
  const RegistroReceptionDashboardView({super.key});

  @override
  ConsumerState<RegistroReceptionDashboardView> createState() =>
      _RegistroReceptionDashboardViewState();
}

class _RegistroReceptionDashboardViewState
    extends ConsumerState<RegistroReceptionDashboardView> {
  Timer? _clockTimer;
  static final _hm = DateFormat('HH:mm');
  static final _money = NumberFormat('#,##0.##');

  static const _weekdays = [
    'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
  ];
  static const _months = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
    'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  @override
  void initState() {
    super.initState();
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

  DateTime _gymNow() => toGymWallClock(appClock.nowUtc(), appClock.gymTimezone);
  DateTime _gymWall(DateTime instant) =>
      toGymWallClock(instant.toUtc(), appClock.gymTimezone);

  void _refreshAll() {
    ref.invalidate(attendanceNotifierProvider);
    ref.invalidate(paymentNotifierProvider);
    ref.invalidate(clientNotifierProvider);
    ref.invalidate(currencyProvider);
  }

  void _goTo(int i) => ref.read(dashboardNavProvider.notifier).setIndex(i);

  String _dateLine() {
    final n = _gymNow();
    return '${_weekdays[n.weekday - 1]}, ${n.day} de ${_months[n.month - 1]} '
        'de ${n.year} · diamond gym';
  }

  @override
  Widget build(BuildContext context) {
    final isNight = Theme.of(context).brightness == Brightness.dark;
    final p = RegistroPalette.of(isNight);
    final inks = RegistroInks.of(isNight);
    final now = _gymNow();

    final attendanceAsync = ref.watch(attendanceNotifierProvider);
    final paymentsAsync = ref.watch(paymentNotifierProvider);
    final clientsAsync = ref.watch(clientNotifierProvider);
    final currenciesAsync = ref.watch(currencyProvider);

    final facts = _ReceptionFacts.compute(
      gymNow: now,
      gymWall: _gymWall,
      attendance: attendanceAsync.value ?? const [],
      payments: paymentsAsync.value ?? const [],
      clients: clientsAsync.value ?? const [],
      currencies: currenciesAsync.value ?? const [],
    );
    final loading = attendanceAsync.isLoading &&
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
                department: 'RECEPCIÓN',
                code: 'F-01 / TURNO · ${_hm.format(now)}',
              ),
              const SizedBox(height: 26),
              _buildTitle(p),
              const SizedBox(height: 18),
              _buildLedger(p, inks, facts, loading),
              const SizedBox(height: 26),
              RegistroFiguresGrid(p: p, figures: _figures(p, inks, facts)),
              const SizedBox(height: 36),
              _buildCurve(p, inks, facts),
              const SizedBox(height: 36),
              _buildSheet(p, inks, facts),
              const SizedBox(height: 44),
              _buildColophon(p, inks),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(RegistroPalette p) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: 'PARTE\nDEL TURNO',
                  children: [
                    TextSpan(text: '.', style: TextStyle(color: p.verm)),
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
                _dateLine(),
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
            RegistroTextAction(
              p: p,
              label: '↻ ACTUALIZAR',
              onTap: _refreshAll,
            ),
            RegistroTextAction(
              p: p,
              label: '＋ PASAR ASISTENCIA',
              prime: true,
              onTap: () => _goTo(7),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLedger(
      RegistroPalette p, RegistroInks inks, _ReceptionFacts f, bool loading) {
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
      sentence = Text('Componiendo el parte…',
          style: base.copyWith(fontStyle: FontStyle.italic));
    } else {
      sentence = Text.rich(
        TextSpan(style: base, children: [
          TextSpan(
              text: f.attToday == 1 ? 'Hoy ha entrado ' : 'Hoy han entrado '),
          TextSpan(text: '${f.attToday}', style: big(inks.azul)),
          TextSpan(text: f.attToday == 1 ? ' socio, ' : ' socios, '),
          TextSpan(text: '${f.inside}', style: big(inks.verde)),
          TextSpan(text: f.inside == 1 ? ' sigue dentro; ' : ' siguen dentro; '),
          TextSpan(
              text: f.paymentsToday == 1
                  ? 'se cobró '
                  : 'se cobraron '),
          TextSpan(
              text: '${f.currencySymbol}${_money.format(f.incomeToday)}',
              style: big(inks.ocre)),
          TextSpan(
              text: f.paymentsToday == 1
                  ? ' en 1 pago, y '
                  : ' en ${f.paymentsToday} pagos, y '),
          TextSpan(text: '${f.dueSoon}', style: big(p.verm)),
          TextSpan(
              text: f.dueSoon == 1
                  ? ' membresía vence esta semana.'
                  : ' membresías vencen esta semana.'),
        ]),
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

  List<RegistroFigure> _figures(
      RegistroPalette p, RegistroInks inks, _ReceptionFacts f) {
    return [
      RegistroFigure(
        number: '01',
        caption: 'asistencia de hoy',
        value: '${f.attToday}',
        note: '${f.inside} dentro ahora'
            '${f.peakHour != null ? ' · pico ${f.peakHour}:00' : ''}',
        ink: inks.azul,
        meter: f.attToday == 0 ? 0 : f.inside / f.attToday,
      ),
      RegistroFigure(
        number: '02',
        caption: 'dentro ahora',
        value: '${f.inside}',
        note: 'aforo actual',
        ink: inks.verde,
        meter: f.attToday == 0 ? 0 : f.inside / f.attToday,
      ),
      RegistroFigure(
        number: '03',
        caption: 'cobros del turno',
        value: '${f.currencySymbol}${_money.format(f.incomeToday)}',
        note: '${f.paymentsToday} '
            '${f.paymentsToday == 1 ? 'pago' : 'pagos'} hoy',
        ink: inks.ocre,
        meter: f.paymentsToday == 0 ? 0 : (f.paymentsToday / 20).clamp(0, 1),
      ),
      RegistroFigure(
        number: '04',
        caption: 'por vencer',
        value: '${f.dueSoon}',
        note: 'próximos 7 días · ${f.expired} '
            '${f.expired == 1 ? 'vencida' : 'vencidas'}',
        ink: p.verm,
        meter: f.activeClients == 0
            ? 0
            : (f.dueSoon / f.activeClients).clamp(0.0, 1.0),
      ),
    ];
  }

  Widget _buildCurve(RegistroPalette p, RegistroInks inks, _ReceptionFacts f) {
    return RegistroPlateFrame(
      p: p,
      tick: inks.azul,
      number: '05',
      title: 'CURVA HORARIA DE ASISTENCIA',
      note: 'socios por hora · hoy',
      child: f.attToday == 0
          ? RegistroPlateEmpty(p: p, message: 'sin asistencias registradas hoy')
          : RegistroHourlyChart(p: p, ink: inks.azul, buckets: f.hourly),
    );
  }

  Widget _buildSheet(RegistroPalette p, RegistroInks inks, _ReceptionFacts f) {
    final movements = RegistroPlateFrame(
      p: p,
      tick: null,
      number: '06',
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
              border:
                  Border(top: BorderSide(color: p.ruleStrong, width: 2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${f.movements.length} '
                  '${f.movements.length == 1 ? 'movimiento' : 'movimientos'} de hoy',
                  style:
                      GoogleFonts.fragmentMono(fontSize: 10, color: p.ink3),
                ),
                RegistroMarginAction(
                  p: p,
                  label: 'ABRIR MOSTRADOR',
                  onTap: () => _goTo(7),
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
          number: '07',
          title: 'VENCIMIENTOS',
          note: null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (f.dueList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text('todos al día ✓',
                      style: GoogleFonts.fragmentMono(
                          fontSize: 12, color: p.ink3)),
                )
              else
                for (final d in f.dueList.take(6))
                  _DueRow(p: p, name: d.name, label: d.whenLabel, hot: d.hot),
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
                  p: p, label: 'PASAR ASISTENCIA', onTap: () => _goTo(7)),
              const SizedBox(height: 10),
              RegistroMarginAction(
                  p: p, label: 'REGISTRAR PAGO', onTap: () => _goTo(3)),
              const SizedBox(height: 10),
              RegistroMarginAction(
                  p: p, label: 'VER CLIENTES', onTap: () => _goTo(1)),
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

  Widget _buildColophon(RegistroPalette p, RegistroInks inks) {
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
          Text('parte compuesto a las ${_hm.format(_gymNow())} · terminal 01',
              style: mono),
          Wrap(spacing: 14, children: [
            leg(inks.azul, 'asistencia'),
            leg(inks.verde, 'dentro'),
            leg(inks.ocre, 'cobros'),
            leg(p.verm, 'alertas'),
          ]),
        ],
      ),
    );
  }
}

// =========================================================================
// Cálculo de los hechos del turno
// =========================================================================
class _RecMovement {
  final DateTime time;
  final String kind; // 'PAGO', 'ENTRADA', 'SALIDA'
  final String name;
  final String? amount; // ya formateado con símbolo
  final Color tick;
  const _RecMovement({
    required this.time,
    required this.kind,
    required this.name,
    required this.amount,
    required this.tick,
  });
}

class _RecDue {
  final String name;
  final String whenLabel;
  final bool hot;
  const _RecDue(this.name, this.whenLabel, this.hot);
}

class _ReceptionFacts {
  final int attToday;
  final int inside;
  final Map<int, int> hourly;
  final int? peakHour;
  final double incomeToday;
  final int paymentsToday;
  final String currencySymbol;
  final int totalClients;
  final int activeClients;
  final int dueSoon;
  final int expired;
  final List<_RecDue> dueList;
  final List<_RecMovement> movements;

  const _ReceptionFacts({
    required this.attToday,
    required this.inside,
    required this.hourly,
    required this.peakHour,
    required this.incomeToday,
    required this.paymentsToday,
    required this.currencySymbol,
    required this.totalClients,
    required this.activeClients,
    required this.dueSoon,
    required this.expired,
    required this.dueList,
    required this.movements,
  });

  static final _money = NumberFormat('#,##0.##');

  static _ReceptionFacts compute({
    required DateTime gymNow,
    required DateTime Function(DateTime) gymWall,
    required List<AttendanceModel> attendance,
    required List<PaymentModel> payments,
    required List<ClientModel> clients,
    required List<CurrencyModel> currencies,
  }) {
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    final today = DateTime(gymNow.year, gymNow.month, gymNow.day);

    final byCi = {for (final c in clients) c.id: c};
    final symbolById = {
      for (final c in currencies)
        c.id: (c.symbol?.trim().isNotEmpty ?? false)
            ? c.symbol!.trim()
            : c.code,
    };

    String nameOf(ClientModel c) {
      final n = '${c.nombres ?? ''} ${c.apellidos ?? ''}'.trim();
      return n.isEmpty ? c.id : n;
    }

    String attName(AttendanceModel a) {
      if (a.clientName?.trim().isNotEmpty ?? false) return a.clientName!.trim();
      final c = byCi[a.clientId];
      return c != null ? nameOf(c) : a.clientId;
    }

    String payName(PaymentModel pay) {
      final c = byCi[pay.ci];
      if (c != null) return nameOf(c);
      if (pay.clientName?.trim().isNotEmpty ?? false) {
        return pay.clientName!.trim();
      }
      return pay.ci;
    }

    // asistencia
    final attToday =
        attendance.where((a) => sameDay(gymWall(a.checkIn), gymNow)).toList();
    final inside = attToday.where((a) => a.checkOut == null).length;
    final hourly = <int, int>{};
    for (final a in attToday) {
      final h = gymWall(a.checkIn).hour;
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

    // pagos de hoy
    final valid = payments.where((x) => !x.isDeleted).toList();
    final payToday =
        valid.where((x) => sameDay(gymWall(x.fecha), gymNow)).toList();
    final incomeToday = payToday.fold<double>(0, (s, x) => s + x.amount);
    // símbolo dominante de los pagos de hoy (o del primero); fallback '$'
    String symbol = r'$';
    if (payToday.isNotEmpty) {
      symbol = symbolById[payToday.first.currencyId] ?? r'$';
    }

    // socios / vencimientos
    final totalClients = clients.length;
    final activeClients = clients.where((c) => c.activo).length;
    final withEnd = clients.where((c) => c.activo && c.endDate != null).toList()
      ..sort((a, b) => a.endDate!.compareTo(b.endDate!));
    final horizon = today.add(const Duration(days: 7));
    var dueSoon = 0;
    var expired = 0;
    final dueList = <_RecDue>[];
    for (final c in withEnd) {
      final end =
          DateTime(c.endDate!.year, c.endDate!.month, c.endDate!.day);
      final days = end.difference(today).inDays;
      if (days < 0) {
        expired++;
      } else if (!end.isAfter(horizon)) {
        dueSoon++;
      }
      if (days <= 7) {
        final String when;
        if (days < 0) {
          when = 'vencida (${days.abs()} d)';
        } else if (days == 0) {
          when = 'vence hoy';
        } else if (days == 1) {
          when = 'mañana';
        } else {
          when = 'en $days d';
        }
        dueList.add(_RecDue(nameOf(c), when, days <= 1));
      }
    }
    // vencidas al final, por vencer primero
    dueList.sort((a, b) {
      int rank(_RecDue d) => d.whenLabel.startsWith('vencida') ? 1 : 0;
      return rank(a).compareTo(rank(b));
    });

    // movimientos: pagos + entradas + salidas
    final movements = <_RecMovement>[
      for (final pay in payToday)
        _RecMovement(
          time: gymWall(pay.fecha),
          kind: 'PAGO',
          name: payName(pay),
          amount:
              '${symbolById[pay.currencyId] ?? r'$'}${_money.format(pay.amount)}',
          tick: RegistroInks.day.ocre,
        ),
      for (final a in attToday)
        _RecMovement(
          time: gymWall(a.checkIn),
          kind: 'ENTRADA',
          name: attName(a),
          amount: null,
          tick: RegistroInks.day.verde,
        ),
      for (final a in attToday.where((a) => a.checkOut != null))
        _RecMovement(
          time: gymWall(a.checkOut!),
          kind: 'SALIDA',
          name: attName(a),
          amount: null,
          tick: RegistroInks.day.azul,
        ),
    ]..sort((a, b) => b.time.compareTo(a.time));

    return _ReceptionFacts(
      attToday: attToday.length,
      inside: inside,
      hourly: hourly,
      peakHour: peak,
      incomeToday: incomeToday,
      paymentsToday: payToday.length,
      currencySymbol: symbol,
      totalClients: totalClients,
      activeClients: activeClients,
      dueSoon: dueSoon,
      expired: expired,
      dueList: dueList,
      movements: movements.take(8).toList(),
    );
  }
}

// =========================================================================
// Filas locales
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
  final _RecMovement m;

  @override
  State<_MovementRow> createState() => _MovementRowState();
}

class _MovementRowState extends State<_MovementRow> {
  bool _hover = false;
  static final _hm = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final m = widget.m;
    // La tinta se guardó con la paleta "día"; se remapea a la actual.
    final tick = m.kind == 'PAGO'
        ? widget.inks.ocre
        : m.kind == 'ENTRADA'
            ? widget.inks.verde
            : widget.inks.azul;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        color: _hover ? p.paper2 : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                widget.index.toString().padLeft(2, '0'),
                style: GoogleFonts.fragmentMono(fontSize: 11, color: p.ink4),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 7, height: 7, color: tick),
                      const SizedBox(width: 6),
                      Text(
                        m.kind,
                        style: GoogleFonts.archivo(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.3,
                          color: p.ink3,
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
              ),
            ),
            const SizedBox(width: 12),
            Text(
              m.amount ?? '—',
              style: GoogleFonts.fragmentMono(
                fontSize: 13,
                color: m.amount == null ? p.ink4 : p.ink,
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                _hm.format(m.time),
                textAlign: TextAlign.right,
                style: GoogleFonts.fragmentMono(fontSize: 12, color: p.ink2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DueRow extends StatelessWidget {
  const _DueRow(
      {required this.p,
      required this.name,
      required this.label,
      required this.hot});
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
                  fontSize: 13, fontWeight: FontWeight.w600, color: p.ink),
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
