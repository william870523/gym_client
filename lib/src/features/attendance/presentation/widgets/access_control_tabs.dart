import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:intl/intl.dart';
import '../../data/models/attendance_model.dart';
import '../../presentation/state/attendance_notifier.dart';
import '../../../../core/widgets/base64_image.dart';
import '../../../clients/data/models/client_model.dart';
import '../../../clients/presentation/state/client_notifier.dart';
import 'attendance_timer.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';

DateTime _accessWallTime(DateTime instant) =>
    toGymWallClock(instant, appClock.gymTimezone);

String _attendanceRowsKey(
  String prefix,
  List<AttendanceModel> attendances, {
  int clientCount = 0,
}) {
  final signature = attendances
      .map(
        (a) =>
            '${a.id}:${a.status}:${a.checkOut?.toIso8601String() ?? 'active'}',
      )
      .join('|');
  // Se incluye el nº de clientes del catálogo: cuando el catálogo carga, la
  // clave cambia y PlutoGrid reconstruye las filas ya con nombre y foto.
  return '$prefix:c$clientCount:$signature';
}

/// Resuelve nombre y foto de un asistente. Prefiere los datos que traiga la
/// asistencia (join del API); si faltan, los busca en el catálogo de clientes
/// por cédula; como último recurso muestra la cédula.
({String name, String? photo}) _resolveAttendee(
  AttendanceModel att,
  Map<String, ClientModel> byCi,
) {
  final c = byCi[att.clientId];
  final catalogName = c == null
      ? ''
      : '${c.nombres ?? ''} ${c.apellidos ?? ''}'.trim();
  final name = (att.clientName?.trim().isNotEmpty ?? false)
      ? att.clientName!.trim()
      : catalogName.isNotEmpty
      ? catalogName
      : att.clientId;
  final photo = (att.photoUrl?.trim().isNotEmpty ?? false)
      ? att.photoUrl
      : (c?.photoUrl?.trim().isNotEmpty ?? false)
      ? c!.photoUrl
      : null;
  return (name: name, photo: photo);
}

class AccessControlTabs extends ConsumerStatefulWidget {
  const AccessControlTabs({super.key});

  @override
  ConsumerState<AccessControlTabs> createState() => _AccessControlTabsState();
}

class _AccessControlTabsState extends ConsumerState<AccessControlTabs> {
  int _selectedIndex = 0; // 0: Sala, 1: Historial

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tailwind Colors
    final slate50 = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final slate100 = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final slate200 = isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0);
    final slate400 = const Color(0xFF94A3B8);
    final slate500 = const Color(0xFF64748B);
    final slate600 = const Color(0xFF475569);
    final slate900 = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final primary = const Color(0xFF135BEC);
    final success = const Color(0xFF22C55E);

    return Container(
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
          // Tab Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: slate100)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildTabItem(
                      0,
                      'Clientes en el Gimnasio',
                      slate400,
                      slate600,
                      primary,
                    ),
                    const SizedBox(width: 24),
                    _buildTabItem(
                      1,
                      'HISTORIAL DIARIO',
                      slate400,
                      slate600,
                      primary,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: slate50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: slate200),
                      ),
                      child: Icon(
                        Icons.calendar_month,
                        size: 18,
                        color: slate500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(height: 16, width: 1, color: slate200),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '24 OCTUBRE 2023',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _selectedIndex == 0
                ? _buildActiveAttendancesGrid(isDark)
                : _buildHistorialContent(
                    isDark,
                    slate900,
                    slate500,
                    slate50,
                    slate100,
                    slate200,
                    slate400,
                    success,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(
    int index,
    String text,
    Color inactiveColor,
    Color hoverColor,
    Color activeColor,
  ) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? activeColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: isSelected ? activeColor : inactiveColor,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveAttendancesGrid(bool isDark) {
    final attendancesAsync = ref.watch(attendanceNotifierProvider);
    final clients = ref.watch(clientNotifierProvider).value ?? const [];
    final byCi = {for (final c in clients) c.id: c};

    return attendancesAsync.when(
      data: (attendances) {
        // Filter only active attendances
        final active = attendances.where((a) => a.status == 'activo').toList();

        return PlutoGrid(
          key: ValueKey(
            _attendanceRowsKey('active', active, clientCount: byCi.length),
          ),
          columns: _buildColumns(context, byCi),
          rows: _buildRows(active, context),
          onLoaded: (PlutoGridOnLoadedEvent event) {
            event.stateManager.setShowColumnFilter(false);
          },
          configuration: PlutoGridConfiguration(
            style: PlutoGridStyleConfig(
              gridBackgroundColor: isDark
                  ? const Color(0xFF1E293B)
                  : Colors.white,
              rowColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              gridBorderColor: Colors.transparent,
              borderColor: Colors.transparent,
              oddRowColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              evenRowColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              activatedColor: isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFF1F5F9),
              cellTextStyle: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              columnTextStyle: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF94A3B8),
              ),
              rowHeight: 64,
              columnHeight: 40,
            ),
            columnSize: const PlutoGridColumnSizeConfig(
              autoSizeMode: PlutoAutoSizeMode.scale,
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  List<PlutoColumn> _buildColumns(
    BuildContext context,
    Map<String, ClientModel> byCi,
  ) {
    return [
      PlutoColumn(
        title: 'SOCIO',
        field: 'client_info',
        type: PlutoColumnType.text(),
        enableRowChecked: false,
        enableEditingMode: false,
        renderer: (rendererContext) {
          final att = rendererContext.cell.value as AttendanceModel;
          return _buildClientCell(att, byCi, context);
        },
      ),
      PlutoColumn(
        title: 'INICIO',
        field: 'check_in',
        type: PlutoColumnType.text(),
        enableEditingMode: false,
        width: 100,
        renderer: (rendererContext) {
          final att = rendererContext.cell.value as AttendanceModel;
          return _buildTimeCell(_accessWallTime(att.checkIn), context);
        },
      ),
      PlutoColumn(
        title: 'TIEMPO',
        field: 'timer',
        type: PlutoColumnType.text(),
        enableEditingMode: false,
        width: 240,
        renderer: (rendererContext) {
          final att = rendererContext.cell.value as AttendanceModel;
          return AttendanceTimer(checkInTime: att.checkIn);
        },
      ),
      PlutoColumn(
        title: 'ACCIONES',
        field: 'actions',
        type: PlutoColumnType.text(),
        enableEditingMode: false,
        width: 100,
        textAlign: PlutoColumnTextAlign.right,
        renderer: (rendererContext) {
          final att = rendererContext.cell.value as AttendanceModel;
          return _buildActionCell(att, context);
        },
      ),
    ];
  }

  List<PlutoRow> _buildRows(
    List<AttendanceModel> attendances,
    BuildContext context,
  ) {
    return attendances.map((att) {
      return PlutoRow(
        cells: {
          'client_info': PlutoCell(value: att),
          'check_in': PlutoCell(value: att),
          'timer': PlutoCell(value: att),
          'actions': PlutoCell(value: att),
        },
      );
    }).toList();
  }

  Widget _buildClientCell(
    AttendanceModel att,
    Map<String, ClientModel> byCi,
    BuildContext context,
  ) {
    final resolved = _resolveAttendee(att, byCi);
    final initials = resolved.name.trim().isNotEmpty
        ? resolved.name.trim().substring(0, 1).toUpperCase()
        : '?';

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: resolved.photo != null
              ? Base64Image(
                  base64String: resolved.photo!,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                )
              : Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            resolved.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeCell(DateTime time, BuildContext context) {
    final formatted = DateFormat.jm().format(time);
    return Text(formatted, style: GoogleFonts.inter(fontSize: 12));
  }

  Widget _buildActionCell(AttendanceModel att, BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFEE2E2), // Red-100
          border: Border.all(color: const Color(0xFFFECACA)), // Red-200
        ),
        child: IconButton(
          icon: const Icon(
            Icons.exit_to_app,
            color: Color(0xFFEF4444),
          ), // Red-500
          onPressed: () async {
            await ref
                .read(attendanceNotifierProvider.notifier)
                .checkOut(att.id);
          },
          tooltip: 'Dar Salida',
          iconSize: 20,
        ),
      ),
    );
  }

  Widget _buildHistorialContent(
    bool isDark,
    Color textMain,
    Color textSub,
    Color bgHeader,
    Color border,
    Color cellBorder,
    Color headerText,
    Color success,
  ) {
    return _HistoryTab(key: const ValueKey('HistoryTab'));
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceState = ref.watch(attendanceNotifierProvider);
    final clients = ref.watch(clientNotifierProvider).value ?? const [];
    final byCi = {for (final c in clients) c.id: c};

    return attendanceState.when(
      data: (attendances) {
        // Filter history: must have checkout time (finished) or explicit status
        // AND match today (API already filters by today, so we just check for completion)
        // User requested: "Los que han hecho salida ese día"
        final historyList = attendances
            .where((a) => a.checkOut != null)
            .toList();

        if (historyList.isEmpty) {
          return const Center(child: Text('No hay historial registrado hoy.'));
        }

        return PlutoGrid(
          key: ValueKey(
            _attendanceRowsKey(
              'history',
              historyList,
              clientCount: byCi.length,
            ),
          ),
          columns: _buildColumns(context),
          rows: _buildRows(historyList, byCi),
          configuration: PlutoGridConfiguration(
            style: PlutoGridStyleConfig(
              gridBackgroundColor: Colors.transparent,
              rowColor: Colors.transparent,
              gridBorderColor: Colors.transparent,
              borderColor: Colors.transparent,
              activatedColor: Theme.of(
                context,
              ).primaryColor.withValues(alpha: 0.1),
              cellTextStyle: Theme.of(context).textTheme.bodyMedium!,
              columnTextStyle: Theme.of(
                context,
              ).textTheme.titleSmall!.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  List<PlutoColumn> _buildColumns(BuildContext context) {
    return [
      PlutoColumn(
        title: 'SOCIO',
        field: 'member_info',
        type: PlutoColumnType.text(),
        width: 200,
        enableEditingMode: false,
        renderer: (rendererContext) {
          final data =
              rendererContext.row.cells['member_info']!.value
                  as Map<String, dynamic>;
          final name = data['name'] as String;
          final photo = data['photo'] as String?;

          return Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade200,
                ),
                clipBehavior: Clip.antiAlias,
                child: photo != null && photo.isNotEmpty
                    ? Base64Image(base64String: photo, fit: BoxFit.cover)
                    : Icon(Icons.person, size: 18, color: Colors.grey.shade400),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),
      PlutoColumn(
        title: 'ENTRADA',
        field: 'check_in',
        type: PlutoColumnType.text(),
        width: 100,
        enableEditingMode: false,
        formatter: (value) {
          if (value is DateTime) return DateFormat('HH:mm').format(value);
          return '';
        },
      ),
      PlutoColumn(
        title: 'SALIDA',
        field: 'check_out',
        type: PlutoColumnType.text(),
        width: 100,
        enableEditingMode: false,
        formatter: (value) {
          if (value is DateTime) return DateFormat('HH:mm').format(value);
          return '-';
        },
      ),
      PlutoColumn(
        title: 'TIEMPO TOTAL',
        field: 'duration',
        type: PlutoColumnType.text(),
        width: 120,
        enableEditingMode: false,
        renderer: (rendererContext) {
          final duration = rendererContext.cell.value as Duration;
          return Text(
            _formatDuration(duration),
            style: const TextStyle(fontWeight: FontWeight.bold),
          );
        },
      ),
    ];
  }

  List<PlutoRow> _buildRows(
    List<AttendanceModel> attendances,
    Map<String, ClientModel> byCi,
  ) {
    return attendances.map((a) {
      final duration = a.checkOut?.difference(a.checkIn) ?? Duration.zero;
      final resolved = _resolveAttendee(a, byCi);

      return PlutoRow(
        cells: {
          'member_info': PlutoCell(
            value: {'name': resolved.name, 'photo': resolved.photo},
          ),
          'check_in': PlutoCell(value: _accessWallTime(a.checkIn)),
          'check_out': PlutoCell(
            value: a.checkOut == null ? null : _accessWallTime(a.checkOut!),
          ),
          'duration': PlutoCell(value: duration),
        },
      );
    }).toList();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }
}
