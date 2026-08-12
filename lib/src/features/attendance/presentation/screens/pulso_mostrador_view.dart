import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_palette_id.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/base64_image.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../clients/data/models/client_model.dart';
import '../../../clients/domain/membership_vigencia.dart';
import '../../../clients/presentation/state/client_notifier.dart';
import '../../../clients/presentation/widgets/client_form.dart';
import '../../../payments/presentation/state/payment_notifier.dart';
import '../../../payments/presentation/widgets/process_payment_dialog.dart';
import '../../../schedules/data/models/horario_model.dart';
import '../../../schedules/presentation/state/horario_notifier.dart';
import '../../data/models/attendance_model.dart';
import '../state/attendance_notifier.dart';

/// Asistencia / Recepción — MOSTRADOR PULSO.
///
/// Optimizado para velocidad de recepción (ver docs/DESIGN_SYSTEM.md §
/// Mostrador). Cola de llegada por horario (los que se acercan a su turno suben),
/// entrada de un clic sin escribir, aforo con pausa/salida, y **alerta cuando
/// alguien dentro se acerca o pasa su tiempo** (para avisar al entrenador).
/// Mockup de referencia: docs/registro_mostrador.html.
///
/// Datos reales: [attendanceNotifierProvider] (asistencias de hoy),
/// [clientNotifierProvider] (socios), [horarioNotifierProvider] (horarios).
class PulsoMostradorView extends ConsumerStatefulWidget {
  const PulsoMostradorView({super.key});

  @override
  ConsumerState<PulsoMostradorView> createState() => _PulsoMostradorViewState();
}

enum _AforoTab { dentro, historial }

class _PulsoMostradorViewState extends ConsumerState<PulsoMostradorView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  _AforoTab _tab = _AforoTab.dentro;

  Timer? _tick;
  final Set<String> _notifiedOverLimit = {};
  final Set<String> _checkingInCis = {};
  // Cada panel (cola / aforo) scrollea dentro de su propia región.
  final ScrollController _queueScroll = ScrollController();
  final ScrollController _aforoScroll = ScrollController();

  /// Minutos de tolerancia dentro por defecto cuando el socio no tiene horario.
  static const int _defaultStayMinutes = 60;

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
    _searchFocus.addListener(() => setState(() {}));
    // Refresca cronómetros, cuentas regresivas y evalúa alertas cada segundo.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _queueScroll.dispose();
    _aforoScroll.dispose();
    super.dispose();
  }

  // ===== helpers de tiempo (zona del gym) =====
  DateTime _gymNow() => toGymWallClock(appClock.nowUtc(), appClock.gymTimezone);
  int _gymNowMinutes() {
    final n = _gymNow();
    return n.hour * 60 + n.minute;
  }

  String _dateLine() {
    final n = _gymNow();
    return 'control de acceso · ${_weekdays[n.weekday - 1]}, ${n.day} de '
        '${_months[n.month - 1]} de ${n.year}';
  }

  String _clock() {
    final n = _gymNow();
    return '${n.hour.toString().padLeft(2, '0')}:'
        '${n.minute.toString().padLeft(2, '0')}';
  }

  String _fullName(ClientModel c) {
    final n = '${c.nombres ?? ''} ${c.apellidos ?? ''}'.trim();
    return n.isEmpty ? c.id : n;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((w) => w[0]).join().toUpperCase();
  }

  // ===== estado de membresía =====
  bool _membershipActive(ClientModel c) {
    if (c.planId == null || c.planId!.trim().isEmpty) return false;
    if (!c.activo) return false;
    final end = c.endDate;
    if (end == null) return true;
    final now = _gymNow();
    final today = DateTime(now.year, now.month, now.day);
    final normEnd = DateTime(end.year, end.month, end.day);
    return !normEnd.isBefore(today);
  }

  /// 'entrar' | 'cobrar' | 'plan'
  String _memberAction(ClientModel c) {
    if (c.planId == null || c.planId!.trim().isEmpty) return 'plan';
    if (!_membershipActive(c)) return 'cobrar';
    return 'entrar';
  }

  /// El motivo que da el servidor, o `null` si de verdad no dijo nada.
  ///
  /// El mostrador enseñaba «No se pudo registrar la entrada» pasara lo que
  /// pasara. El servidor sí explica —la membresía está pausada, hay un cobro
  /// pendiente, la cuota está vencida— y ese texto se perdía en el `catch`: el
  /// recepcionista veía un fallo genérico y no sabía qué hacer a continuación.
  /// Un rechazo que no se explica obliga a llamar a administración por algo que
  /// la pantalla ya sabe.
  String? _motivoDelServidor(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] != null) {
        final texto = data['error'].toString().trim();
        if (texto.isNotEmpty) return texto;
      }
    }
    return null;
  }

  // ===== acciones =====
  Future<void> _checkIn(ClientModel c) async {
    final current = ref.read(attendanceNotifierProvider).value;
    final alreadyInside =
        current?.any(
          (attendance) =>
              attendance.clientId == c.id && attendance.checkOut == null,
        ) ??
        false;
    if (alreadyInside) {
      _toast('${_fullName(c)} ya está dentro', _ToastKind.info);
      return;
    }
    if (!_checkingInCis.add(c.id)) {
      _toast('La entrada ya se está registrando', _ToastKind.info);
      return;
    }
    try {
      await ref.read(attendanceNotifierProvider.notifier).checkIn(c);
      _toast('Entrada · ${_fullName(c)}', _ToastKind.ok);
    } catch (e) {
      _toast(
        _motivoDelServidor(e) ?? 'No se pudo registrar la entrada',
        _ToastKind.bad,
      );
    } finally {
      _checkingInCis.remove(c.id);
    }
  }

  Future<void> _checkOut(AttendanceModel a, ClientModel? c) async {
    try {
      await ref
          .read(attendanceNotifierProvider.notifier)
          .checkOutClient(a.clientId, fallbackAttendanceId: a.id);
      _notifiedOverLimit.remove(a.id);
      _toast(
        'Salida · ${c != null ? _fullName(c) : a.clientId}',
        _ToastKind.ok,
      );
    } catch (e) {
      _toast(
        _motivoDelServidor(e) ?? 'No se pudo registrar la salida',
        _ToastKind.bad,
      );
    }
  }

  /// Pausa/reanuda la permanencia — persistida en el backend (sobrevive
  /// reinicios de la terminal y se sincroniza con la remota).
  Future<void> _togglePause(AttendanceModel a) async {
    try {
      if (a.isPaused) {
        await ref.read(attendanceNotifierProvider.notifier).resume(a.id);
        _toast('Reanudado', _ToastKind.ok);
      } else {
        await ref.read(attendanceNotifierProvider.notifier).pause(a.id);
        _toast('En pausa · salió un momento', _ToastKind.info);
      }
    } catch (e) {
      // La pausa sin días disponibles es un rechazo de negocio con motivo
      // (409), no una avería: decirlo es la diferencia entre corregirlo y
      // llamar a soporte.
      _toast(
        _motivoDelServidor(e) ?? 'No se pudo cambiar la pausa',
        _ToastKind.bad,
      );
    }
  }

  Future<void> _cobrar(ClientModel c) async {
    final planId = c.planId;
    if (planId == null || planId.isEmpty) {
      await _editClient(c);
      return;
    }
    final paid = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PulsoThemeScope(
        child: ProcessPaymentDialog(client: c, planId: planId),
      ),
    );
    if (paid == true && mounted) {
      await ref.read(clientNotifierProvider.notifier).refresh();
      await ref.read(attendanceNotifierProvider.notifier).refresh();
    }
  }

  Future<void> _editClient(ClientModel c) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PulsoThemeScope(child: ClientForm(client: c)),
    );
    if (mounted) {
      await ref.read(clientNotifierProvider.notifier).refresh();
      await ref.read(attendanceNotifierProvider.notifier).refresh();
    }
  }

  void _quickAct(ClientModel c) {
    switch (_memberAction(c)) {
      case 'entrar':
        _checkIn(c);
      case 'cobrar':
        _cobrar(c);
      case 'plan':
        _editClient(c);
    }
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  // ===== toast =====
  void _toast(String msg, _ToastKind kind) {
    if (!mounted) return;
    final p = _MostradorPalette.fromContext(context);
    final inks = _MostradorInks.fromContext(context);
    final bar = switch (kind) {
      _ToastKind.ok => inks.verde,
      _ToastKind.bad => p.danger,
      _ToastKind.info => inks.ocre,
    };
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: p.ink,
          shape: const RoundedRectangleBorder(),
          content: Row(
            children: [
              Container(width: 5, height: 26, color: bar),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  msg.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: p.paper,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return PulsoThemeScope(
      child: Builder(builder: (context) => _buildThemed(context)),
    );
  }

  Widget _buildThemed(BuildContext context) {
    final p = _MostradorPalette.fromContext(context);
    final inks = _MostradorInks.fromContext(context);

    final clients = ref.watch(clientNotifierProvider).value ?? const [];
    final attendance = ref.watch(attendanceNotifierProvider).value ?? const [];
    final horarios = ref.watch(horarioNotifierProvider).value ?? const [];
    final payments = ref.watch(paymentNotifierProvider).value ?? const [];

    // Cobros de hoy en la zona del gimnasio (los instantes viven en UTC).
    final todayWall = _gymNow();
    bool sameGymDay(DateTime instant) {
      final wall = toGymWallClock(instant.toUtc(), appClock.gymTimezone);
      return wall.year == todayWall.year &&
          wall.month == todayWall.month &&
          wall.day == todayWall.day;
    }

    final paymentsToday = payments
        .where((pay) => !pay.isDeleted && sameGymDay(pay.fecha))
        .toList();
    final monedasHoy = paymentsToday
        .map((pay) => pay.currencyId)
        .toSet()
        .length;

    final byCi = {for (final c in clients) c.id: c};
    final horariosById = {for (final h in horarios) h.id: h};

    final facts = _MostradorFacts.compute(
      nowMinutes: _gymNowMinutes(),
      nowUtc: appClock.nowUtc(),
      clients: clients,
      attendance: attendance,
      byCi: byCi,
      horariosById: horariosById,
      defaultStayMinutes: _defaultStayMinutes,
      membershipActive: _membershipActive,
      memberAction: _memberAction,
    );

    // Alerta al recepcionista cuando alguien nuevo pasa su tiempo dentro.
    _evaluateOverLimitAlerts(facts, byCi);

    return Scaffold(
      backgroundColor: p.paper,
      body: SafeArea(
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
                _searchFocus.requestFocus(),
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
                _searchFocus.requestFocus(),
          },
          child: Focus(
            autofocus: true,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 600;
                final scrollPage = compact || constraints.maxHeight < 720;
                final horizontal = compact
                    ? 14.0
                    : constraints.maxWidth < 840
                    ? 24.0
                    : 40.0;
                final insets = EdgeInsets.fromLTRB(
                  horizontal,
                  compact ? 16 : 24,
                  horizontal,
                  compact ? 18 : 20,
                );
                final fixed = <Widget>[
                  _PulsoMasthead(clock: _clock()),
                  const SizedBox(height: 18),
                  _buildTitle(p),
                  const SizedBox(height: 14),
                  _buildMetrics(
                    p,
                    inks,
                    facts,
                    paymentsToday.length,
                    monedasHoy,
                  ),
                  const SizedBox(height: 14),
                  _buildSearch(p, inks, clients, facts),
                  const SizedBox(height: 18),
                ];
                if (scrollPage) {
                  return SingleChildScrollView(
                    padding: insets,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...fixed,
                        SizedBox(
                          height: compact ? 760 : 680,
                          child: _buildFloor(p, inks, facts, byCi),
                        ),
                        const SizedBox(height: 14),
                        _buildTerminalBar(p, inks),
                      ],
                    ),
                  );
                }
                return Padding(
                  padding: insets,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...fixed,
                      Expanded(child: _buildFloor(p, inks, facts, byCi)),
                      const SizedBox(height: 14),
                      _buildTerminalBar(p, inks),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(_MostradorPalette p) {
    // Cabecera de página del mockup v3: eyebrow (guion en acento + mono en
    // mayúsculas) sobre el H1 display con una palabra en acento.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 26, height: 2, color: p.verm),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                _dateLine().toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.3,
                  color: p.ink3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            text: 'CONTROL DE ',
            children: [
              TextSpan(
                text: 'PISO',
                style: TextStyle(color: p.verm),
              ),
            ],
          ),
          style: TextStyle(
            fontFamily: PulsoFonts.display,
            fontSize: 52,
            height: 0.86,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.8,
            color: p.ink,
          ),
        ),
      ],
    );
  }

  Widget _buildMetrics(
    _MostradorPalette p,
    _MostradorInks inks,
    _MostradorFacts f,
    int cobrosHoy,
    int monedasHoy,
  ) {
    // Banda de métricas del turno: un solo marco con divisores internos
    // (PULSO_RECETARIO_VISUAL.md §3.2).
    final accesosHoy = f.inside.length + f.history.length;
    final atencion = f.dueList.length;
    final paused = f.inside.where((s) => s.attendance.isPaused).length;
    final cells = [
      (
        '${f.inside.length}',
        'EN SALA',
        paused > 0 ? '$paused en pausa' : 'ahora mismo',
        p.verm,
      ),
      ('$accesosHoy', 'ACCESOS HOY', '${f.history.length} salidas', p.ink),
      (
        '$cobrosHoy',
        'COBROS HOY',
        monedasHoy > 0
            ? '$monedasHoy moneda${monedasHoy == 1 ? '' : 's'}'
            : 'sin cobros aún',
        p.ink,
      ),
      (
        '$atencion',
        'REQUIEREN ATENCIÓN',
        'vencen en ≤7 días',
        atencion > 0 ? p.danger : p.ink,
      ),
    ];
    Widget cell((String, String, String, Color) it) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      child: Row(
        children: [
          Text(
            it.$1,
            style: TextStyle(
              fontFamily: PulsoFonts.display,
              fontSize: 27,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              color: it.$4,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  it.$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: p.ink2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  it.$3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 9,
                    color: p.ink4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 600;
        final row = IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cells.length; i++) ...[
                if (i > 0) Container(width: 1, color: p.rule),
                if (narrow)
                  SizedBox(width: 152, child: cell(cells[i]))
                else
                  Expanded(child: cell(cells[i])),
              ],
            ],
          ),
        );
        return Container(
          decoration: BoxDecoration(
            color: p.paper2.withValues(alpha: 0.45),
            border: Border.all(color: p.rule),
          ),
          child: narrow
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: row,
                )
              : row,
        );
      },
    );
  }

  /// Escáner de código: los lectores de barras/QR teclean el código en el
  /// campo enfocado y pulsan Enter, así que basta con enfocar la búsqueda.
  void _activateScanner() {
    _searchFocus.requestFocus();
    _toast('Escáner activo · pasa el código del socio', _ToastKind.info);
  }

  // ===== búsqueda protagonista + sugerencias inline =====
  Widget _buildSearch(
    _MostradorPalette p,
    _MostradorInks inks,
    List<ClientModel> clients,
    _MostradorFacts facts,
  ) {
    final q = _searchQuery.trim().toLowerCase();
    final results = q.isEmpty
        ? const <ClientModel>[]
        : (clients
              .where(
                (c) =>
                    _fullName(c).toLowerCase().contains(q) ||
                    c.id.toLowerCase().contains(q),
              )
              .take(6)
              .toList());

    // Asistencias activas por cédula → para auto-detectar salida al buscar a
    // alguien que ya está dentro (evita entradas duplicadas).
    final insideByCi = <String, AttendanceModel>{
      for (final s in facts.inside) s.attendance.clientId: s.attendance,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: p.ruleStrong, width: 2),
              bottom: BorderSide(color: p.ruleStrong, width: 2),
            ),
          ),
          child: Row(
            children: [
              Text(
                'IDENTIFICAR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                  color: _searchFocus.hasFocus ? p.verm : p.ink3,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  key: const ValueKey('pulso-mostrador-search'),
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  cursorColor: p.verm,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'nombre o cédula…',
                    hintStyle: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: p.ink4,
                    ),
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                _MiniTap(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Text(
                    '✕',
                    style: TextStyle(fontSize: 16, color: p.ink3),
                  ),
                )
              else
                Text(
                  'CTRL K',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 11,
                    color: p.ink4,
                  ),
                ),
              const SizedBox(width: 14),
              // Escáner de código / QR (para lector físico).
              _ScannerButton(p: p, onTap: _activateScanner),
            ],
          ),
        ),
        if (results.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: p.ruleStrong, width: 2),
                right: BorderSide(color: p.ruleStrong, width: 2),
                bottom: BorderSide(color: p.ruleStrong, width: 2),
              ),
            ),
            child: Column(
              children: [
                for (final c in results)
                  // Si ya está dentro, la acción es SALIDA; si no, entrada/
                  // cobrar/plan según su membresía.
                  if (insideByCi[c.id] case final att?)
                    _SuggestRow(
                      p: p,
                      inks: inks,
                      name: _fullName(c),
                      ci: c.id,
                      photo: c.photoUrl,
                      initials: _initials(_fullName(c)),
                      action: 'salida',
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _checkOut(att, c);
                      },
                    )
                  else
                    _SuggestRow(
                      p: p,
                      inks: inks,
                      name: _fullName(c),
                      ci: c.id,
                      photo: c.photoUrl,
                      initials: _initials(_fullName(c)),
                      action: _memberAction(c),
                      onTap: () => _quickAct(c),
                    ),
              ],
            ),
          ),
      ],
    );
  }

  // ===== cuerpo: cola + aforo =====
  Widget _buildFloor(
    _MostradorPalette p,
    _MostradorInks inks,
    _MostradorFacts f,
    Map<String, ClientModel> byCi,
  ) {
    final queue = _buildQueuePanel(p, inks, f);
    final aforo = _buildAforoPanel(p, inks, f, byCi);
    final memberships = _buildMembershipPanel(p, f);

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 1040) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 27, child: queue),
              const SizedBox(width: 14),
              Expanded(
                flex: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 12, child: aforo),
                    const SizedBox(height: 14),
                    Expanded(flex: 7, child: memberships),
                  ],
                ),
              ),
            ],
          );
        }
        // En estrecho: las tres unidades conservan su propio panel y scroll.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: queue),
            const SizedBox(height: 14),
            Expanded(child: aforo),
            const SizedBox(height: 14),
            Expanded(child: memberships),
          ],
        );
      },
    );
  }

  Widget _buildQueuePanel(
    _MostradorPalette p,
    _MostradorInks inks,
    _MostradorFacts f,
  ) {
    return PulsoPanel(
      key: const ValueKey('pulso-arrivals-panel'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: p.paper2,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: _plateHead(
              p,
              tickColor: p.verm,
              title: 'PRÓXIMOS A LLEGAR · ${f.queue.length}',
              note: f.freeAccessCount == 0
                  ? 'por horario · los más cercanos arriba'
                  : '${f.scheduledCount} con horario · '
                        '${f.freeAccessCount} de acceso libre',
            ),
          ),
          Expanded(
            child: f.queue.isEmpty
                ? _emptyBlock(p, 'no hay socios pendientes de entrada')
                : Scrollbar(
                    controller: _queueScroll,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _queueScroll,
                      primary: false,
                      padding: EdgeInsets.zero,
                      itemCount: f.queue.length,
                      itemBuilder: (_, i) =>
                          _buildQueueRow(p, inks, f.queue[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueRow(
    _MostradorPalette p,
    _MostradorInks inks,
    _QueueEntry q,
  ) {
    final eta = q.eta;
    final Color etaColor = switch (eta.level) {
      _EtaLevel.far => p.ink3,
      _EtaLevel.soon => inks.ocre,
      _EtaLevel.now => p.verm,
      _EtaLevel.late => p.danger,
    };
    final due = q.action != 'entrar';
    final urgent = eta.level == _EtaLevel.now || eta.level == _EtaLevel.late;
    final leftColor = due
        ? p.danger
        : urgent
        ? p.verm
        : Colors.transparent;
    final bg = due ? p.dangerSoft : Colors.transparent;

    final (String actLabel, Color actColor) = switch (q.action) {
      'cobrar' => ('COBRAR', p.danger),
      'plan' => ('PLAN', p.ink2),
      _ => ('ENTRADA', inks.verde),
    };

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(color: p.rule),
          left: BorderSide(color: leftColor, width: 3),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 12, 10, 12),
      child: Row(
        children: [
          _Avatar(p: p, initials: q.initials, photo: q.photo, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      if (q.window != 'acceso libre')
                        const TextSpan(text: 'horario '),
                      TextSpan(
                        text: q.window,
                        style: TextStyle(color: p.ink2),
                      ),
                      TextSpan(text: ' · ${q.planLabel}'),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 12,
                    color: p.ink3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 84,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  eta.num,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: etaColor,
                  ),
                ),
                Text(
                  eta.label,
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 9.5,
                    letterSpacing: 0.4,
                    color: eta.level == _EtaLevel.late ? p.danger : p.ink3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _OutlineAction(
            label: actLabel,
            color: actColor,
            onTap: () => _quickAct(q.client),
          ),
        ],
      ),
    );
  }

  TextStyle _columnHeadStyle(_MostradorPalette p) => TextStyle(
    fontFamily: PulsoFonts.mono,
    fontSize: 8.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.1,
    color: p.ink4,
  );

  Widget _buildAforoPanel(
    _MostradorPalette p,
    _MostradorInks inks,
    _MostradorFacts f,
    Map<String, ClientModel> byCi,
  ) {
    return PulsoPanel(
      key: const ValueKey('pulso-inside-panel'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // cabecera con tabs segmentadas + contador
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
            decoration: BoxDecoration(
              color: p.paper2,
              border: Border(bottom: BorderSide(color: p.rule)),
            ),
            child: Wrap(
              spacing: 20,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // grupo segmentado enmarcado (recetario §3.8)
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: p.paper,
                    border: Border.all(color: p.rule),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _AforoTabButton(
                        p: p,
                        label: 'DENTRO AHORA',
                        active: _tab == _AforoTab.dentro,
                        onTap: () => setState(() => _tab = _AforoTab.dentro),
                      ),
                      const SizedBox(width: 3),
                      _AforoTabButton(
                        p: p,
                        label: 'HISTORIAL',
                        active: _tab == _AforoTab.historial,
                        onTap: () => setState(() => _tab = _AforoTab.historial),
                      ),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${f.inside.length}'),
                      TextSpan(
                        text: ' dentro',
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 12,
                          color: p.ink3,
                        ),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: inks.verde,
                  ),
                ),
              ],
            ),
          ),

          // cabecera de columnas (recetario §3.3)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: p.paper2,
              border: Border(bottom: BorderSide(color: p.rule)),
            ),
            child: Row(
              children: [
                Expanded(child: Text('SOCIO', style: _columnHeadStyle(p))),
                Text(
                  _tab == _AforoTab.dentro ? 'TIEMPO · ACCIONES' : 'DURACIÓN',
                  style: _columnHeadStyle(p),
                ),
              ],
            ),
          ),

          // alerta de tiempo cumplido
          if (_tab == _AforoTab.dentro && f.overLimit > 0)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: p.dangerSoft,
                border: Border(left: BorderSide(color: p.danger, width: 3)),
              ),
              child: Text(
                '${f.overLimit} ${f.overLimit == 1 ? 'socio pasó' : 'socios pasaron'} '
                'de su tiempo — avisar al entrenador',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: p.danger,
                ),
              ),
            ),

          const SizedBox(height: 2),

          // Cuerpo scrolleable exclusivo de dentro/historial.
          Expanded(
            child: Scrollbar(
              controller: _aforoScroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _aforoScroll,
                primary: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_tab == _AforoTab.dentro)
                      if (f.inside.isEmpty)
                        _emptyBlock(p, 'nadie dentro en este momento')
                      else
                        for (final s in f.inside) _buildInsideRow(p, inks, s)
                    else if (f.history.isEmpty)
                      _emptyBlock(p, 'sin salidas registradas hoy')
                    else
                      for (final h in f.history) _buildHistoryRow(p, h),
                  ],
                ),
              ),
            ),
          ),

          // pie de tabla con resumen (recetario §3.3)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: p.paper2,
              border: Border(top: BorderSide(color: p.rule)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${f.inside.length} EN SALA · '
                    '${f.history.length} SALIDAS HOY',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.9,
                      color: p.ink4,
                    ),
                  ),
                ),
                if (f.overLimit > 0)
                  Text(
                    '${f.overLimit} TIEMPO CUMPLIDO',
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.9,
                      color: p.danger,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsideRow(
    _MostradorPalette p,
    _MostradorInks inks,
    _InsideEntry s,
  ) {
    final Color tmrColor = switch (s.stayLevel) {
      _StayLevel.ok => p.ink,
      _StayLevel.soon => inks.ocre,
      _StayLevel.over => p.danger,
    };
    final paused = s.attendance.isPaused;

    return Opacity(
      opacity: paused ? 0.72 : 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: p.rule),
            left: BorderSide(
              color: s.stayLevel == _StayLevel.over
                  ? p.danger
                  : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(8, 11, 8, 11),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final identity = Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
                  Text(
                    paused
                        ? '● en pausa'
                        : s.stayLevel == _StayLevel.over
                        ? 'tiempo cumplido'
                        : 'entró ${s.enteredLabel}',
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 11,
                      color: paused
                          ? inks.ocre
                          : s.stayLevel == _StayLevel.over
                          ? p.danger
                          : p.ink3,
                    ),
                  ),
                ],
              ),
            );
            final timer = Text(
              s.timerLabel,
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: paused ? inks.ocre : tmrColor,
              ),
            );
            final actions = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniButton(
                  p: p,
                  label: paused ? 'REANUDAR' : 'PAUSAR',
                  accent: paused ? inks.verde : null,
                  onTap: () => _togglePause(s.attendance),
                ),
                const SizedBox(width: 6),
                _MiniButton(
                  p: p,
                  label: 'SALIDA',
                  onTap: () => _checkOut(s.attendance, s.client),
                ),
              ],
            );
            final identityRow = Row(
              children: [
                _Avatar(p: p, initials: s.initials, photo: s.photo, size: 40),
                const SizedBox(width: 12),
                identity,
                const SizedBox(width: 10),
                timer,
              ],
            );
            if (constraints.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identityRow,
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerRight, child: actions),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: identityRow),
                const SizedBox(width: 10),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHistoryRow(_MostradorPalette p, _HistoryEntry h) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.rule)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 11, 8, 11),
      child: Row(
        children: [
          _Avatar(p: p, initials: h.initials, photo: h.photo, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                Text(
                  '${h.inLabel} → ${h.outLabel}',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 11,
                    color: p.ink3,
                  ),
                ),
              ],
            ),
          ),
          Text(
            h.durationLabel,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 14,
              color: p.ink2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipPanel(_MostradorPalette p, _MostradorFacts f) {
    return PulsoPanel(
      key: const ValueKey('pulso-memberships-panel'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: p.paper2,
              border: Border(bottom: BorderSide(color: p.rule)),
            ),
            child: Row(
              children: [
                Container(width: 8, height: 8, color: p.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'MEMBRESÍAS POR VENCER',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                      color: p.ink3,
                    ),
                  ),
                ),
                if (f.dueList.isNotEmpty)
                  Text(
                    '${f.dueList.length}',
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: p.danger,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: f.dueList.isEmpty
                ? Center(
                    child: Text(
                      'todos al día ✓',
                      style: TextStyle(
                        fontFamily: PulsoFonts.mono,
                        fontSize: 12,
                        color: p.ink3,
                      ),
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final d in f.dueList.take(12))
                        Container(
                          key: ValueKey('membership-due-${d.client.id}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: p.rule,
                                style: BorderStyle.solid,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  d.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: p.ink,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                d.whenLabel,
                                style: TextStyle(
                                  fontFamily: PulsoFonts.mono,
                                  fontSize: 12,
                                  color: p.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalBar(_MostradorPalette p, _MostradorInks inks) {
    final mono = TextStyle(
      fontFamily: PulsoFonts.mono,
      fontSize: 10.5,
      color: p.ink3,
    );
    Widget sw(Color c, String t) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, color: c),
        const SizedBox(width: 5),
        Text(t, style: mono),
      ],
    );
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.rule)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 8,
        children: [
          Wrap(
            spacing: 14,
            children: [
              sw(p.ink3, 'lejos'),
              sw(inks.ocre, '≤20 min / por salir'),
              sw(p.verm, 'su turno'),
              sw(p.danger, 'tarde / tiempo cumplido / cobrar'),
              sw(inks.verde, 'entrada'),
            ],
          ),
          Text('GYMOS · PULSO · TERMINAL 01', style: mono),
        ],
      ),
    );
  }

  // ===== piezas compartidas locales =====
  Widget _plateHead(
    _MostradorPalette p, {
    required Color tickColor,
    required String title,
    required String note,
  }) {
    return Container(
      padding: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.rule)),
      ),
      child: Row(
        children: [
          Container(width: 9, height: 9, color: tickColor),
          const SizedBox(width: 9),
          Text(
            title,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
              color: p.ink2,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontSize: 10,
                color: p.ink3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBlock(_MostradorPalette p, String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Text(
        msg.toUpperCase(),
        style: TextStyle(
          fontFamily: PulsoFonts.mono,
          fontSize: 10,
          letterSpacing: 1.2,
          color: p.ink3,
        ),
      ),
    );
  }

  // Muestra un snackbar una sola vez por socio cuando pasa su tiempo dentro.
  void _evaluateOverLimitAlerts(
    _MostradorFacts f,
    Map<String, ClientModel> byCi,
  ) {
    final currentOver = <String>{};
    for (final s in f.inside) {
      if (s.stayLevel == _StayLevel.over) currentOver.add(s.attendance.id);
    }
    // Poda de los que ya salieron.
    _notifiedOverLimit.removeWhere((id) => !currentOver.contains(id));
    final nuevos = currentOver.difference(_notifiedOverLimit);
    if (nuevos.isEmpty) return;
    _notifiedOverLimit.addAll(nuevos);
    // Aviso al recepcionista (tras el frame para no chocar con el build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final s in f.inside) {
        if (nuevos.contains(s.attendance.id)) {
          _toast(
            'Tiempo cumplido · ${s.name} — avisar al entrenador',
            _ToastKind.bad,
          );
          break; // un aviso a la vez
        }
      }
    });
  }
}

enum _ToastKind { ok, bad, info }

// =========================================================================
// Cálculo de los hechos del mostrador
// =========================================================================
enum _EtaLevel { far, soon, now, late }

enum _StayLevel { ok, soon, over }

class _Eta {
  final _EtaLevel level;
  final String num;
  final String label;
  const _Eta(this.level, this.num, this.label);
}

class _QueueEntry {
  final ClientModel client;
  final String name;
  final String initials;
  final String? photo;
  final String window;
  final String planLabel;
  final String action; // entrar | cobrar | plan
  final _Eta eta;
  const _QueueEntry({
    required this.client,
    required this.name,
    required this.initials,
    required this.photo,
    required this.window,
    required this.planLabel,
    required this.action,
    required this.eta,
  });
}

class _InsideEntry {
  final AttendanceModel attendance;
  final ClientModel? client;
  final String name;
  final String initials;
  final String? photo;
  final String enteredLabel;
  final String timerLabel;
  final _StayLevel stayLevel;
  const _InsideEntry({
    required this.attendance,
    required this.client,
    required this.name,
    required this.initials,
    required this.photo,
    required this.enteredLabel,
    required this.timerLabel,
    required this.stayLevel,
  });
}

class _HistoryEntry {
  final String name;
  final String initials;
  final String? photo;
  final String inLabel;
  final String outLabel;
  final String durationLabel;
  const _HistoryEntry({
    required this.name,
    required this.initials,
    required this.photo,
    required this.inLabel,
    required this.outLabel,
    required this.durationLabel,
  });
}

class _DueEntry {
  final ClientModel client;
  final String name;
  final String whenLabel;
  const _DueEntry({
    required this.client,
    required this.name,
    required this.whenLabel,
  });
}

class _MostradorFacts {
  final List<_QueueEntry> queue;
  final int scheduledCount;
  final int freeAccessCount;
  final List<_InsideEntry> inside;
  final List<_HistoryEntry> history;
  final List<_DueEntry> dueList;
  final int overLimit;

  const _MostradorFacts({
    required this.queue,
    required this.scheduledCount,
    required this.freeAccessCount,
    required this.inside,
    required this.history,
    required this.dueList,
    required this.overLimit,
  });

  static String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((w) => w[0]).join().toUpperCase();
  }

  static String _hm(int minutes) {
    final m = ((minutes % 1440) + 1440) % 1440;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:'
        '${(m % 60).toString().padLeft(2, '0')}';
  }

  static String _dur(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  static _MostradorFacts compute({
    required int nowMinutes,
    required DateTime nowUtc,
    required List<ClientModel> clients,
    required List<AttendanceModel> attendance,
    required Map<String, ClientModel> byCi,
    required Map<String, HorarioModel> horariosById,
    required int defaultStayMinutes,
    required bool Function(ClientModel) membershipActive,
    required String Function(ClientModel) memberAction,
  }) {
    // Solo asistencias de hoy (el provider ya filtra), activas = sin salida.
    final todays = attendance;
    final insideAtt = <AttendanceModel>[];
    final insideSeen = <String>{};
    for (final item in todays.where((a) => a.checkOut == null)) {
      if (insideSeen.add(item.clientId)) insideAtt.add(item);
    }
    final insideCis = insideAtt.map((a) => a.clientId).toSet();

    String nameOf(ClientModel c) {
      final n = '${c.nombres ?? ''} ${c.apellidos ?? ''}'.trim();
      return n.isEmpty ? c.id : n;
    }

    // ---- cola de llegada ----
    final queue = <_QueueEntry>[];
    var scheduledCount = 0;
    var freeAccessCount = 0;
    for (final c in clients) {
      if (insideCis.contains(c.id)) continue; // ya está dentro
      final sid = c.scheduleId;
      final h = sid == null || sid.isEmpty ? null : horariosById[sid];
      if (h == null) {
        freeAccessCount++;
        queue.add(
          _QueueEntry(
            client: c,
            name: nameOf(c),
            initials: _initialsOf(nameOf(c)),
            photo: c.photoUrl,
            window: 'acceso libre',
            planLabel: (c.planId == null || c.planId!.isEmpty)
                ? 'Sin plan'
                : 'Plan',
            action: memberAction(c),
            eta: const _Eta(_EtaLevel.far, 'LIBRE', 'sin horario'),
          ),
        );
        continue;
      }
      final toStart = h.horaInicio - nowMinutes; // minutos hasta el turno
      final len = (h.horaFin - h.horaInicio).clamp(1, 24 * 60);
      // Se muestran todos los turnos pendientes del día. La antigua ventana
      // de dos horas ocultaba socios válidos durante buena parte de la jornada.
      if (toStart < -len - 30) continue;
      scheduledCount++;
      queue.add(
        _QueueEntry(
          client: c,
          name: nameOf(c),
          initials: _initialsOf(nameOf(c)),
          photo: c.photoUrl,
          window: '${_hm(h.horaInicio)}–${_hm(h.horaFin)}',
          planLabel: (c.planId == null || c.planId!.isEmpty)
              ? 'Sin plan'
              : 'Plan',
          action: memberAction(c),
          eta: _etaFor(toStart, len),
        ),
      );
    }
    queue.sort((a, b) {
      int rank(_QueueEntry entry) {
        final scheduleId = entry.client.scheduleId;
        final schedule = scheduleId == null ? null : horariosById[scheduleId];
        if (schedule == null) return 100000;
        final delta = schedule.horaInicio - nowMinutes;
        // Turnos vigentes primero; después, los próximos cronológicamente.
        return delta <= 0 ? 0 : delta;
      }

      final byArrival = rank(a).compareTo(rank(b));
      if (byArrival != 0) return byArrival;
      return a.name.compareTo(b.name);
    });

    // ---- dentro ahora ----
    final inside = <_InsideEntry>[];
    var overLimit = 0;
    for (final a in insideAtt) {
      final c = byCi[a.clientId];
      final name = c != null
          ? nameOf(c)
          : (a.clientName?.trim().isNotEmpty ?? false)
          ? a.clientName!.trim()
          : a.clientId;
      final photo = (a.photoUrl?.trim().isNotEmpty ?? false)
          ? a.photoUrl
          : c?.photoUrl;

      // Tiempo activo descontando la pausa persistida (pausa_ms + vigente).
      final elapsed = a.activeElapsed(nowUtc);

      // límite = ventana del horario del socio, o el valor por defecto
      var limit = defaultStayMinutes;
      final sid = c?.scheduleId;
      if (sid != null && sid.isNotEmpty && horariosById[sid] != null) {
        final h = horariosById[sid]!;
        final len = h.horaFin - h.horaInicio;
        if (len > 0) limit = len;
      }
      final remaining = limit - elapsed.inMinutes;
      final _StayLevel level;
      if (remaining <= 0) {
        level = _StayLevel.over;
        overLimit++;
      } else if (remaining <= 10) {
        level = _StayLevel.soon;
      } else {
        level = _StayLevel.ok;
      }

      final enteredGym = toGymWallClock(
        a.checkIn.toUtc(),
        appClock.gymTimezone,
      );
      inside.add(
        _InsideEntry(
          attendance: a,
          client: c,
          name: name,
          initials: _initialsOf(name),
          photo: photo,
          enteredLabel:
              '${enteredGym.hour.toString().padLeft(2, '0')}:${enteredGym.minute.toString().padLeft(2, '0')}',
          timerLabel: _dur(elapsed),
          stayLevel: level,
        ),
      );
    }
    // los que pasaron su tiempo, arriba
    inside.sort((a, b) {
      int rank(_StayLevel l) =>
          l == _StayLevel.over ? 0 : (l == _StayLevel.soon ? 1 : 2);
      return rank(a.stayLevel).compareTo(rank(b.stayLevel));
    });

    // ---- historial del día ----
    final history = <_HistoryEntry>[];
    for (final a in todays.where((a) => a.checkOut != null)) {
      final c = byCi[a.clientId];
      final name = c != null
          ? nameOf(c)
          : (a.clientName?.trim().isNotEmpty ?? false)
          ? a.clientName!.trim()
          : a.clientId;
      final inG = toGymWallClock(a.checkIn.toUtc(), appClock.gymTimezone);
      final outG = toGymWallClock(a.checkOut!.toUtc(), appClock.gymTimezone);
      final dur = a.checkOut!.difference(a.checkIn);
      history.add(
        _HistoryEntry(
          name: name,
          initials: _initialsOf(name),
          photo: (a.photoUrl?.trim().isNotEmpty ?? false)
              ? a.photoUrl
              : c?.photoUrl,
          inLabel:
              '${inG.hour.toString().padLeft(2, '0')}:${inG.minute.toString().padLeft(2, '0')}',
          outLabel:
              '${outG.hour.toString().padLeft(2, '0')}:${outG.minute.toString().padLeft(2, '0')}',
          durationLabel:
              '${dur.inHours}:${(dur.inMinutes % 60).toString().padLeft(2, '0')}',
        ),
      );
    }

    // ---- membresías por vencer (≤7 días) ----
    final now = toGymWallClock(nowUtc, appClock.gymTimezone);
    final today = DateTime(now.year, now.month, now.day);
    final due = <_DueEntry>[];
    for (final c in clients) {
      if (!c.activo || c.endDate == null) continue;
      final end = DateTime(c.endDate!.year, c.endDate!.month, c.endDate!.day);
      final vigencia =
          membershipVigenciaFromServer(c.membershipVigencia) ??
          resolveMembershipVigencia(
            status: c.membershipStatus,
            endDate: c.endDate,
            today: today,
          );
      if (vigencia == MembershipVigencia.paused ||
          vigencia == MembershipVigencia.pendingPayment ||
          vigencia == MembershipVigencia.cancelled ||
          vigencia == MembershipVigencia.none) {
        continue;
      }
      final days = -daysSinceExpiry(end, today);
      if (vigencia == MembershipVigencia.current && days > 7) continue;
      final String when;
      if (vigencia == MembershipVigencia.recentlyExpired ||
          vigencia == MembershipVigencia.expired) {
        final expiredDays = daysSinceExpiry(end, today);
        when = expiredDays == 0 ? 'vencida hoy' : 'vencida ($expiredDays d)';
      } else if (days == 1) {
        when = 'mañana';
      } else {
        when = 'en $days d';
      }
      due.add(_DueEntry(client: c, name: nameOf(c), whenLabel: when));
    }
    due.sort((a, b) {
      final da = a.client.endDate!;
      final db = b.client.endDate!;
      return da.compareTo(db);
    });

    return _MostradorFacts(
      queue: queue,
      scheduledCount: scheduledCount,
      freeAccessCount: freeAccessCount,
      inside: inside,
      history: history,
      dueList: due,
      overLimit: overLimit,
    );
  }

  static _Eta _etaFor(int toStart, int len) {
    if (toStart <= 0 && toStart > -len) {
      return const _Eta(_EtaLevel.now, 'AHORA', 'su turno');
    }
    if (toStart <= -len) {
      return _Eta(_EtaLevel.late, '+${toStart.abs()}m', 'tarde');
    }
    if (toStart <= 20) return _Eta(_EtaLevel.soon, '${toStart}m', 'faltan');
    if (toStart < 60) return _Eta(_EtaLevel.far, '${toStart}m', 'faltan');
    return _Eta(
      _EtaLevel.far,
      '${toStart ~/ 60}h${(toStart % 60).toString().padLeft(2, '0')}',
      'faltan',
    );
  }
}

// =========================================================================
// Widgets auxiliares
// =========================================================================
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.p,
    required this.initials,
    required this.photo,
    required this.size,
  });
  final _MostradorPalette p;
  final String initials;
  final String? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.paper2,
        border: Border.all(color: p.ruleStrong),
      ),
      clipBehavior: Clip.hardEdge,
      alignment: Alignment.center,
      child: (photo != null && photo!.isNotEmpty)
          ? Base64Image(
              base64String: photo!,
              width: size,
              height: size,
              fit: BoxFit.cover,
            )
          : Text(
              initials,
              style: TextStyle(
                fontSize: size * 0.34,
                fontWeight: FontWeight.w800,
                color: p.ink2,
              ),
            ),
    );
  }
}

class _OutlineAction extends StatefulWidget {
  const _OutlineAction({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_OutlineAction> createState() => _OutlineActionState();
}

class _OutlineActionState extends State<_OutlineAction> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 116),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover ? widget.color : Colors.transparent,
            border: Border.all(color: widget.color, width: 2),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: _hover ? const Color(0xFFF7F3EC) : widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniButton extends StatefulWidget {
  const _MiniButton({
    required this.p,
    required this.label,
    required this.onTap,
    this.accent,
  });
  final _MostradorPalette p;
  final String label;
  final VoidCallback onTap;
  final Color? accent;

  @override
  State<_MiniButton> createState() => _MiniButtonState();
}

class _MiniButtonState extends State<_MiniButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final hi = widget.accent ?? p.verm;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: _hover && widget.accent == null
                ? p.accentSoft
                : Colors.transparent,
            border: Border.all(color: _hover ? hi : p.rule),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: _hover ? hi : p.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

class _AforoTabButton extends StatelessWidget {
  const _AforoTabButton({
    required this.p,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final _MostradorPalette p;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Segmento del grupo enmarcado (recetario §3.8): la activa lleva fondo
    // accentSoft y subrayado interior de 2 px en acento.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: active ? p.accentSoft : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: active ? p.verm : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: active ? p.verm : p.ink3,
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestRow extends StatefulWidget {
  const _SuggestRow({
    required this.p,
    required this.inks,
    required this.name,
    required this.ci,
    required this.photo,
    required this.initials,
    required this.action,
    required this.onTap,
  });
  final _MostradorPalette p;
  final _MostradorInks inks;
  final String name;
  final String ci;
  final String? photo;
  final String initials;
  final String action;
  final VoidCallback onTap;

  @override
  State<_SuggestRow> createState() => _SuggestRowState();
}

class _SuggestRowState extends State<_SuggestRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final (String label, Color color) = switch (widget.action) {
      'cobrar' => ('COBRAR', p.danger),
      'plan' => ('PLAN', p.ink3),
      'salida' => ('SALIDA', widget.inks.azul),
      _ => ('ENTRADA', widget.inks.verde),
    };
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: _hover ? p.paper2 : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              _Avatar(
                p: p,
                initials: widget.initials,
                photo: widget.photo,
                size: 40,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    Text(
                      widget.ci,
                      style: TextStyle(
                        fontFamily: PulsoFonts.mono,
                        fontSize: 11,
                        color: p.ink3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTap extends StatelessWidget {
  const _MiniTap({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: child),
    );
  }
}

/// Botón de escáner de código / QR: enfoca la búsqueda para el lector físico.
class _ScannerButton extends StatefulWidget {
  const _ScannerButton({required this.p, required this.onTap});
  final _MostradorPalette p;
  final VoidCallback onTap;

  @override
  State<_ScannerButton> createState() => _ScannerButtonState();
}

class _ScannerButtonState extends State<_ScannerButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: 'Escanear código (lector físico)',
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hover ? p.ink : Colors.transparent,
              border: Border.all(color: p.ruleStrong, width: 1.5),
            ),
            child: Icon(
              Icons.qr_code_scanner_rounded,
              size: 20,
              color: _hover ? p.paper : p.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsoMasthead extends StatelessWidget {
  const _PulsoMasthead({required this.clock});

  final String clock;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: tokens.floor2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PulsoLabel('Recepción · Terminal 01'),
              const SizedBox(height: 3),
              Text(
                'CONTROL DE ACCESO · $clock',
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: tokens.chalkDim,
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: 10),
                const PulsoSyncStatus(compact: true),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: identity),
              const PulsoSyncStatus(compact: true),
            ],
          );
        },
      ),
    );
  }
}

class _MostradorPalette {
  const _MostradorPalette({
    required this.paper,
    required this.paper2,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.ink4,
    required this.rule,
    required this.ruleStrong,
    required this.verm,
    required this.vermSoft,
    required this.accentSoft,
    required this.danger,
    required this.dangerSoft,
  });

  factory _MostradorPalette.fromContext(BuildContext context) {
    final theme = Theme.of(context);
    final tokens =
        theme.extension<PulsoTokens>() ??
        PulsoTokens.resolve(PulsoPaletteId.clay, theme.brightness);
    return _MostradorPalette(
      paper: tokens.floor,
      paper2: tokens.raised,
      ink: tokens.chalk,
      ink2: tokens.chalkDim,
      ink3: tokens.muted,
      ink4: tokens.muted2,
      rule: tokens.line,
      ruleStrong: tokens.lineStrong,
      // `verm` es el acento de marca: foco, selección, tab activa.
      // Vencido/bloqueado/error usan `danger`; nunca el acento.
      verm: tokens.accent,
      vermSoft: tokens.accentSoft,
      accentSoft: tokens.accentSoft,
      danger: tokens.danger,
      dangerSoft: tokens.dangerSoft,
    );
  }

  final Color paper;
  final Color paper2;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color ink4;
  final Color rule;
  final Color ruleStrong;
  final Color verm;
  final Color vermSoft;
  final Color accentSoft;
  final Color danger;
  final Color dangerSoft;
}

class _MostradorInks {
  const _MostradorInks({
    required this.verde,
    required this.ocre,
    required this.azul,
  });

  factory _MostradorInks.fromContext(BuildContext context) {
    final theme = Theme.of(context);
    final tokens =
        theme.extension<PulsoTokens>() ??
        PulsoTokens.resolve(PulsoPaletteId.clay, theme.brightness);
    return _MostradorInks(
      verde: tokens.success,
      ocre: tokens.warning,
      azul: tokens.sync,
    );
  }

  final Color verde;
  final Color ocre;
  final Color azul;
}
