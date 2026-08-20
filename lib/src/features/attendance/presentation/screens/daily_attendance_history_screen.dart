import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/base64_image.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../clients/data/models/client_model.dart';
import '../../../clients/presentation/state/client_notifier.dart';
import '../../../products/data/models/payment_plan_model.dart';
import '../../../products/presentation/state/payment_plan_notifier.dart';
import '../../data/models/attendance_model.dart';
import '../state/attendance_history_provider.dart';
import '../state/attendance_notifier.dart';

enum _AttendanceFilter { all, inside, paused, completed }

DateTime _wallTime(DateTime instant) =>
    toGymWallClock(instant, appClock.gymTimezone);

DateTime _today() {
  final now = _wallTime(appClock.nowUtc());
  return DateTime(now.year, now.month, now.day);
}

bool _sameCalendarDay(DateTime instant, DateTime day) {
  final local = _wallTime(instant);
  return local.year == day.year &&
      local.month == day.month &&
      local.day == day.day;
}

String _clientName(AttendanceModel attendance, ClientModel? client) {
  final cached = '${client?.nombres ?? ''} ${client?.apellidos ?? ''}'.trim();
  return attendance.clientName?.trim().isNotEmpty == true
      ? attendance.clientName!.trim()
      : cached.isNotEmpty
      ? cached
      : 'Socio ${attendance.clientId}';
}

String _duration(Duration value) {
  final minutes = value.inMinutes.clamp(0, 999999);
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
}

class DailyAttendanceHistoryScreen extends ConsumerStatefulWidget {
  const DailyAttendanceHistoryScreen({super.key});

  @override
  ConsumerState<DailyAttendanceHistoryScreen> createState() =>
      _DailyAttendanceHistoryScreenState();
}

class _DailyAttendanceHistoryScreenState
    extends ConsumerState<DailyAttendanceHistoryScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  DateTime _selectedDate = _today();
  String _query = '';
  _AttendanceFilter _filter = _AttendanceFilter.all;

  String _calendarDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<AttendanceModel> _visible(
    List<AttendanceModel> source,
    Map<String, ClientModel> clients,
    Map<String, String> plans,
  ) {
    final query = _query.trim().toLowerCase();
    return source.where((attendance) {
      if (!_sameCalendarDay(attendance.checkIn, _selectedDate)) return false;
      final client = clients[attendance.clientId];
      final name = _clientName(attendance, client);
      final plan = plans[client?.planId] ?? 'Sin plan';
      final matchesQuery =
          query.isEmpty ||
          '$name ${attendance.clientId} $plan'.toLowerCase().contains(query);
      final matchesFilter = switch (_filter) {
        _AttendanceFilter.all => true,
        _AttendanceFilter.inside =>
          attendance.checkOut == null && !attendance.isPaused,
        _AttendanceFilter.paused => attendance.isPaused,
        _AttendanceFilter.completed => attendance.checkOut != null,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: _today().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(
      () => _selectedDate = DateTime(picked.year, picked.month, picked.day),
    );
    await ref
        .read(attendanceHistoryProvider.notifier)
        .loadPage(1, calendarDate: _calendarDate(_selectedDate));
  }

  Future<void> _refresh(int page) async {
    await Future.wait([
      ref.read(attendanceHistoryProvider.notifier).loadPage(page),
      ref.read(attendanceNotifierProvider.notifier).refresh(),
    ]);
  }

  Future<void> _copyCsv(
    Map<String, ClientModel> clients,
    Map<String, String> plans,
  ) async {
    List<AttendanceModel> items;
    try {
      final day = await ref
          .read(attendanceHistoryProvider.notifier)
          .loadAllForSelectedDate();
      items = _visible(day, clients, plans);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo preparar el CSV: $error')),
      );
      return;
    }
    String cell(Object? value) =>
        '"${value?.toString().replaceAll('"', '""') ?? ''}"';
    final rows = <String>[
      'Socio,CI,Plan,Entrada,Salida,Estado,Permanencia activa',
      for (final attendance in items)
        [
          _clientName(attendance, clients[attendance.clientId]),
          attendance.clientId,
          plans[clients[attendance.clientId]?.planId] ?? 'Sin plan',
          DateFormat('yyyy-MM-dd HH:mm').format(_wallTime(attendance.checkIn)),
          attendance.checkOut == null
              ? ''
              : DateFormat(
                  'yyyy-MM-dd HH:mm',
                ).format(_wallTime(attendance.checkOut!)),
          attendance.isPaused
              ? 'En pausa'
              : attendance.checkOut == null
              ? 'En sala'
              : 'Finalizada',
          _duration(attendance.activeElapsed(appClock.nowUtc())),
        ].map(cell).join(','),
    ];
    await Clipboard.setData(ClipboardData(text: rows.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          items.isEmpty
              ? 'Se copiaron los encabezados del CSV.'
              : 'CSV copiado con ${items.length} registros del día filtrado.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PulsoThemeScope(
      child: Builder(
        builder: (context) => Material(
          color: PulsoTokens.of(context).floor,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                  _searchFocus.requestFocus,
              const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                  _searchFocus.requestFocus,
            },
            child: Focus(autofocus: true, child: _buildPage(context)),
          ),
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context) {
    final history = ref.watch(attendanceHistoryProvider);
    final todayState = ref.watch(attendanceNotifierProvider);
    final clientsState = ref.watch(clientNotifierProvider);
    final plansState = ref.watch(paymentPlanProvider);
    final clients = {
      for (final client in clientsState.value ?? const <ClientModel>[])
        client.id: client,
    };
    final plans = {
      for (final plan in plansState.value ?? const <PaymentPlanModel>[])
        if (plan.id != null) plan.id!: plan.nombre,
    };
    final visible = _visible(history.attendances, clients, plans);
    final today = todayState.value ?? const <AttendanceModel>[];
    final nowUtc = appClock.nowUtc();
    final inside = today.where((item) => item.checkOut == null).length;
    final completed = today.where((item) => item.checkOut != null).toList();
    final average = completed.isEmpty
        ? Duration.zero
        : Duration(
            milliseconds:
                completed
                    .map((item) => item.activeElapsed(nowUtc).inMilliseconds)
                    .fold<int>(0, (sum, value) => sum + value) ~/
                completed.length,
          );
    final peak = _peakHour(today);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final scrollPage = compact || constraints.maxHeight < 760;
        final padding = compact
            ? 16.0
            : constraints.maxWidth < 840
            ? 24.0
            : 32.0;
        final table = _AttendanceCatalog(
          items: visible,
          clients: clients,
          plans: plans,
          loading: history.isLoading && history.attendances.isEmpty,
          error: history.error,
          queryActive:
              _query.trim().isNotEmpty || _filter != _AttendanceFilter.all,
          onRetry: () => _refresh(history.page),
        );
        final page = Column(
          mainAxisSize: scrollPage ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _AttendanceHeader(),
            const SizedBox(height: 14),
            PulsoMetricStrip(
              metrics: [
                PulsoMetricData(
                  value: '${today.length}',
                  label: 'Entradas hoy',
                  note: 'zona ${appClock.gymTimezone}',
                  emphasis: true,
                ),
                PulsoMetricData(
                  value: '$inside',
                  label: 'En sala',
                  note: 'incluye pausas abiertas',
                  warning: inside > 0,
                ),
                PulsoMetricData(
                  value: _duration(average),
                  label: 'Permanencia media',
                  note: 'tiempo activo, sin pausas',
                ),
                PulsoMetricData(
                  value: peak,
                  label: 'Hora pico',
                  note: 'entradas de hoy',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _AttendanceCommand(
              controller: _searchController,
              focusNode: _searchFocus,
              date: _selectedDate,
              filter: _filter,
              resultCount: visible.length,
              onSearch: (value) => setState(() => _query = value),
              onFilter: (value) => setState(() => _filter = value),
              onDate: _pickDate,
              onCopy: () => _copyCsv(clients, plans),
              onRefresh: () => _refresh(history.page),
            ),
            const SizedBox(height: 12),
            if (scrollPage)
              SizedBox(height: 430, child: table)
            else
              Expanded(child: table),
            const SizedBox(height: 8),
            _AttendanceFooter(
              page: history.page,
              limit: history.limit,
              count: history.attendances.length,
              loading: history.isLoading,
              onPrevious: history.page > 1
                  ? () =>
                        ref.read(attendanceHistoryProvider.notifier).prevPage()
                  : null,
              onNext: history.attendances.length >= history.limit
                  ? () =>
                        ref.read(attendanceHistoryProvider.notifier).nextPage()
                  : null,
            ),
          ],
        );
        final insets = EdgeInsets.fromLTRB(
          padding,
          compact ? 16 : 20,
          padding,
          compact ? 18 : 24,
        );
        return scrollPage
            ? SingleChildScrollView(padding: insets, child: page)
            : Padding(padding: insets, child: page);
      },
    );
  }

  String _peakHour(List<AttendanceModel> items) {
    if (items.isEmpty) return '—';
    final counts = <int, int>{};
    for (final item in items) {
      final hour = _wallTime(item.checkIn).hour;
      counts[hour] = (counts[hour] ?? 0) + 1;
    }
    final hour = counts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    return '${hour.toString().padLeft(2, '0')}:00';
  }
}

class _AttendanceHeader extends StatelessWidget {
  const _AttendanceHeader();

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PulsoLabel('PULSO · CONTROL DE ACCESO'),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            text: 'ASISTENCIA',
            children: [
              TextSpan(
                text: '.',
                style: TextStyle(color: tokens.accent),
              ),
            ],
          ),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Entradas, salidas y permanencia activa leídas en la hora del gimnasio.',
          style: TextStyle(color: tokens.muted, fontSize: 14),
        ),
      ],
    );
  }
}

class _AttendanceCommand extends StatelessWidget {
  const _AttendanceCommand({
    required this.controller,
    required this.focusNode,
    required this.date,
    required this.filter,
    required this.resultCount,
    required this.onSearch,
    required this.onFilter,
    required this.onDate,
    required this.onCopy,
    required this.onRefresh,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final DateTime date;
  final _AttendanceFilter filter;
  final int resultCount;
  final ValueChanged<String> onSearch;
  final ValueChanged<_AttendanceFilter> onFilter;
  final VoidCallback onDate;
  final VoidCallback onCopy;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final search = TextField(
      key: const ValueKey('attendance-history-search'),
      controller: controller,
      focusNode: focusNode,
      onChanged: onSearch,
      decoration: const InputDecoration(
        hintText: 'Buscar socio, CI o plan',
        prefixIcon: Icon(Icons.search),
        suffixText: 'CTRL K',
      ),
    );
    final dateButton = PulsoSecondaryButton(
      label: DateFormat('dd/MM/yyyy').format(date),
      icon: Icons.calendar_month_outlined,
      onPressed: onDate,
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        dateButton,
        PulsoSecondaryButton(
          label: 'Copiar CSV',
          icon: Icons.content_copy_outlined,
          onPressed: onCopy,
        ),
        PulsoIconButton(
          icon: Icons.refresh,
          tooltip: 'Refrescar historial',
          onPressed: onRefresh,
        ),
      ],
    );
    final filters = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _FilterChip(
          label: 'Todos',
          selected: filter == _AttendanceFilter.all,
          onTap: () => onFilter(_AttendanceFilter.all),
        ),
        _FilterChip(
          label: 'En sala',
          selected: filter == _AttendanceFilter.inside,
          onTap: () => onFilter(_AttendanceFilter.inside),
        ),
        _FilterChip(
          label: 'En pausa',
          selected: filter == _AttendanceFilter.paused,
          onTap: () => onFilter(_AttendanceFilter.paused),
        ),
        _FilterChip(
          label: 'Finalizadas',
          selected: filter == _AttendanceFilter.completed,
          onTap: () => onFilter(_AttendanceFilter.completed),
        ),
      ],
    );

    return PulsoPanel(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact) ...[
                search,
                const SizedBox(height: 10),
                actions,
              ] else
                Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 10),
                    actions,
                  ],
                ),
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  filters,
                  const SizedBox(height: 8),
                  Text(
                    '$resultCount visibles · día seleccionado',
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 9,
                      color: tokens.muted2,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Material(
      color: selected ? tokens.accentSoft : tokens.raised,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? tokens.accent : tokens.line),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: selected ? tokens.accent : tokens.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceCatalog extends StatelessWidget {
  const _AttendanceCatalog({
    required this.items,
    required this.clients,
    required this.plans,
    required this.loading,
    required this.error,
    required this.queryActive,
    required this.onRetry,
  });

  final List<AttendanceModel> items;
  final Map<String, ClientModel> clients;
  final Map<String, String> plans;
  final bool loading;
  final String? error;
  final bool queryActive;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.loading,
          message: 'Cargando historial…',
        ),
      );
    }
    if (error != null) {
      return PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.error,
          message: 'No se pudo cargar el historial.\n$error',
          onRetry: onRetry,
        ),
      );
    }
    if (items.isEmpty) {
      return PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.empty,
          message: queryActive
              ? 'No hay asistencias que coincidan con la consulta.'
              : 'No hay asistencias para la fecha seleccionada en esta página.',
        ),
      );
    }
    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 760
            ? _AttendanceCards(items: items, clients: clients, plans: plans)
            : _AttendanceTable(items: items, clients: clients, plans: plans),
      ),
    );
  }
}

class _AttendanceTable extends StatelessWidget {
  const _AttendanceTable({
    required this.items,
    required this.clients,
    required this.plans,
  });

  final List<AttendanceModel> items;
  final Map<String, ClientModel> clients;
  final Map<String, String> plans;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      children: [
        Container(
          color: tokens.raised,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: const Row(
            children: [
              Expanded(flex: 4, child: PulsoLabel('Socio')),
              Expanded(flex: 2, child: PulsoLabel('Plan')),
              Expanded(flex: 2, child: PulsoLabel('Entrada')),
              Expanded(flex: 2, child: PulsoLabel('Salida')),
              Expanded(flex: 2, child: PulsoLabel('Permanencia')),
              SizedBox(width: 92, child: PulsoLabel('Estado')),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            key: const PageStorageKey('pulso-attendance-history-list'),
            itemCount: items.length,
            itemBuilder: (context, index) => _AttendanceRow(
              attendance: items[index],
              client: clients[items[index].clientId],
              plan: plans[clients[items[index].clientId]?.planId] ?? 'Sin plan',
              alternate: index.isOdd,
            ),
          ),
        ),
      ],
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.attendance,
    required this.client,
    required this.plan,
    required this.alternate,
  });

  final AttendanceModel attendance;
  final ClientModel? client;
  final String plan;
  final bool alternate;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final name = _clientName(attendance, client);
    final status = attendance.isPaused
        ? 'EN PAUSA'
        : attendance.checkOut == null
        ? 'EN SALA'
        : 'FINALIZADA';
    final statusColor = attendance.isPaused
        ? tokens.warning
        : attendance.checkOut == null
        ? tokens.success
        : tokens.muted;
    return Container(
      color: alternate ? tokens.raised.withValues(alpha: 0.55) : tokens.surface,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: _MemberIdentity(
              name: name,
              id: attendance.clientId,
              photo: attendance.photoUrl,
              nota: _notaDeLaDecision(attendance),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              plan,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.chalkDim, fontSize: 12),
            ),
          ),
          Expanded(flex: 2, child: _TimeCell(attendance.checkIn)),
          Expanded(flex: 2, child: _TimeCell(attendance.checkOut)),
          Expanded(
            flex: 2,
            child: Text(
              _duration(attendance.activeElapsed(appClock.nowUtc())),
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tokens.chalk,
              ),
            ),
          ),
          SizedBox(
            width: 92,
            child: Text(
              status,
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceCards extends StatelessWidget {
  const _AttendanceCards({
    required this.items,
    required this.clients,
    required this.plans,
  });

  final List<AttendanceModel> items;
  final Map<String, ClientModel> clients;
  final Map<String, String> plans;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return ListView.separated(
      key: const PageStorageKey('pulso-attendance-history-list'),
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: tokens.line),
      itemBuilder: (context, index) {
        final attendance = items[index];
        final client = clients[attendance.clientId];
        final status = attendance.isPaused
            ? 'En pausa'
            : attendance.checkOut == null
            ? 'En sala'
            : 'Finalizada';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MemberIdentity(
                name: _clientName(attendance, client),
                id: attendance.clientId,
                photo: attendance.photoUrl,
                nota: _notaDeLaDecision(attendance),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 18,
                runSpacing: 10,
                children: [
                  _Datum(
                    label: 'Plan',
                    value: plans[client?.planId] ?? 'Sin plan',
                  ),
                  _Datum(label: 'Entrada', value: _time(attendance.checkIn)),
                  _Datum(label: 'Salida', value: _time(attendance.checkOut)),
                  _Datum(
                    label: 'Permanencia',
                    value: _duration(
                      attendance.activeElapsed(appClock.nowUtc()),
                    ),
                  ),
                  _Datum(label: 'Estado', value: status),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MemberIdentity extends StatelessWidget {
  const _MemberIdentity({
    required this.name,
    required this.id,
    required this.photo,
    this.nota,
  });

  final String name;
  final String id;
  final String? photo;

  /// §5.2 — con qué se decidió la entrada, cuando merece decirse.
  final String? nota;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final fallback = Center(
      child: Text(
        name.isEmpty ? 'S' : name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontFamily: PulsoFonts.display,
          fontWeight: FontWeight.w800,
          color: tokens.accent,
        ),
      ),
    );
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: tokens.raised2,
            border: Border.all(color: tokens.line),
          ),
          child: photo?.isNotEmpty == true
              ? Base64Image(
                  base64String: photo!,
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                  placeholder: fallback,
                )
              : fallback,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: tokens.chalk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'CI $id',
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 9,
                  color: tokens.muted2,
                ),
              ),
              if (nota != null) ...[
                const SizedBox(height: 3),
                Text(
                  nota!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: tokens.warning,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// §5.2 — qué se dice de una entrada que se autorizó sin poder comprobarla.
///
/// Solo se dice cuando decidió la copia. Marcar también las que resolvió el
/// concentrador llenaría la lista de avisos inofensivos, y una lista donde todo
/// está marcado no marca nada.
///
/// El texto se compone de los datos congelados en la fila, no de lo que la sede
/// sabe hoy: la entrada de anteayer se decidió con lo que había anteayer, y
/// haber sincronizado esta mañana no la convierte en comprobada.
String? _notaDeLaDecision(AttendanceModel attendance) {
  if (!attendance.decididaConLaCopia) return null;
  final dias = attendance.diasSinNoticias;
  return switch (attendance.conocimientoAlDecidir) {
    'A_CIEGAS' when dias == null =>
      'Decidida con la copia · esta sede no había sincronizado nunca',
    'A_CIEGAS' => 'Decidida con la copia · $dias días sin sincronizar',
    'CON_RETRASO' => 'Decidida con la copia · sin sincronizar desde el día anterior',
    // Al día y aun así con la copia: el concentrador no llegó a contestar.
    _ => 'Decidida con la copia · el concentrador no contestó',
  };
}

class _Datum extends StatelessWidget {
  const _Datum({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return SizedBox(
      width: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PulsoLabel(label),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: tokens.chalkDim,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell(this.value);
  final DateTime? value;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Text(
      _time(value),
      style: TextStyle(
        fontFamily: PulsoFonts.mono,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: value == null ? tokens.muted2 : tokens.chalkDim,
      ),
    );
  }
}

String _time(DateTime? value) =>
    value == null ? '—' : DateFormat('HH:mm').format(_wallTime(value));

class _AttendanceFooter extends StatelessWidget {
  const _AttendanceFooter({
    required this.page,
    required this.limit,
    required this.count,
    required this.loading,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int limit;
  final int count;
  final bool loading;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final start = count == 0 ? 0 : ((page - 1) * limit) + 1;
    final end = count == 0 ? 0 : start + count - 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REGISTROS $start–$end · PÁGINA $page',
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: tokens.muted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Instantes UTC · presentación ${appClock.gymTimezone}',
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontSize: 8,
                color: tokens.muted2,
              ),
            ),
          ],
        );
        final buttons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulsoIconButton(
              icon: Icons.chevron_left,
              tooltip: 'Página anterior',
              onPressed: loading ? null : onPrevious,
            ),
            const SizedBox(width: 6),
            PulsoIconButton(
              icon: Icons.chevron_right,
              tooltip: 'Página siguiente',
              onPressed: loading ? null : onNext,
            ),
          ],
        );
        return constraints.maxWidth < 520
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [text, const SizedBox(height: 10), buttons],
              )
            : Row(
                children: [
                  Expanded(child: text),
                  buttons,
                ],
              );
      },
    );
  }
}
