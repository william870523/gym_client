import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:intl/intl.dart';

import 'manual_attendance_entry.dart';
import '../../../../core/widgets/base64_image.dart';
import '../../../clients/data/models/client_model.dart';
import '../../../clients/presentation/state/client_notifier.dart';
import '../../../clients/presentation/widgets/client_form.dart';
import '../../presentation/state/attendance_notifier.dart';
import '../../../payments/presentation/widgets/process_payment_dialog.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';

DateTime _entryGymNow() =>
    toGymWallClock(appClock.nowUtc(), appClock.gymTimezone);

class EntryRegisterSection extends ConsumerStatefulWidget {
  const EntryRegisterSection({super.key});

  @override
  ConsumerState<EntryRegisterSection> createState() =>
      _EntryRegisterSectionState();
}

class _EntryRegisterSectionState extends ConsumerState<EntryRegisterSection> {
  final TextEditingController _searchController = TextEditingController();
  PlutoGridStateManager? _stateManager;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_stateManager == null) return;
    _stateManager!.setFilter((element) {
      // Use status_info as it now holds the ClientModel.
      // Alternatively, check member_info since all visible cells now hold the model.
      final client = element.cells['member_info']?.value as ClientModel?;
      if (client == null) return false;

      final query = _searchController.text.trim().toLowerCase();
      if (query.isEmpty) return true;

      final name = '${client.nombres ?? ''} ${client.apellidos ?? ''}'
          .toLowerCase();
      final ci = client.id.toLowerCase();

      return name.contains(query) || ci.contains(query);
    });
  }

  bool _isMembershipActive(ClientModel client) {
    if (client.planId == null || client.planId!.trim().isEmpty) return false;
    if (!client.activo) return false;

    final endDate = client.endDate;
    if (endDate == null) return true;

    final now = _entryGymNow();
    final today = DateTime(now.year, now.month, now.day);
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);

    return !normalizedEnd.isBefore(today);
  }

  Future<void> _openPaymentDialog(ClientModel client) async {
    final planId = client.planId;
    if (planId == null || planId.isEmpty) {
      if (!mounted) return;
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

    if (paid == true && mounted) {
      await ref.read(clientNotifierProvider.notifier).refresh();
      await ref.read(attendanceNotifierProvider.notifier).refresh();
    }
  }

  Future<void> _checkInClient(ClientModel client) async {
    final name = '${client.nombres ?? ''} ${client.apellidos ?? ''}'.trim();
    try {
      await ref.read(attendanceNotifierProvider.notifier).checkIn(client);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${name.isEmpty ? client.ci : name} ingresó al gimnasio.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo registrar la entrada de '
            '${name.isEmpty ? client.ci : name}: $error',
          ),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  /// Abre la ficha del cliente para editarla (p. ej. asignar un plan) sin
  /// salir de la pantalla de recepción. Al cerrar, refresca el listado.
  Future<void> _openEditClient(ClientModel client) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClientForm(client: client),
    );
    if (mounted) {
      await ref.read(clientNotifierProvider.notifier).refresh();
      await ref.read(attendanceNotifierProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clientsAsync = ref.watch(clientNotifierProvider);
    final activeAttendances = ref.watch(attendanceNotifierProvider);
    final attendanceNotifier = ref.watch(attendanceNotifierProvider.notifier);

    // Tailwind Colors
    final slate50 = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final slate100 = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final slate200 = isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0);
    final slate400 = const Color(0xFF94A3B8);
    final slate500 = const Color(0xFF64748B);
    final slate900 = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);

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
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(bottom: BorderSide(color: slate100)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REGISTRO DE ENTRADA',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: slate900,
                        letterSpacing: 0,
                      ),
                    ),
                    Text(
                      'Búsqueda y control de acceso',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: slate500,
                      ),
                    ),
                  ],
                );

                final actions = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 180,
                          maxWidth: 256,
                        ),
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: slate50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: slate200),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              Icon(Icons.search, size: 18, color: slate400),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (_) => _onSearchChanged(),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: slate900,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Nombre o CI...',
                                    hintStyle: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: slate400,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Acceso manual',
                      child: IconButton.filledTonal(
                        onPressed: () {
                          showDialog(
                            context: context,
                            barrierDismissible: true,
                            builder: (context) => const Dialog(
                              backgroundColor: Colors.transparent,
                              surfaceTintColor: Colors.transparent,
                              child: ManualAttendanceEntry(),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.qr_code_scanner,
                          size: 18,
                          color: slate500,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: slate100,
                          minimumSize: const Size(36, 36),
                          fixedSize: const Size(36, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 12), actions],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 12),
                    actions,
                  ],
                );
              },
            ),
          ),
          // Grid
          Expanded(
            child: clientsAsync.when(
              data: (clients) {
                // Ensure we update clients list

                // Filter out clients who have already attended today (active or finished)
                final filteredClients = clients.where((c) {
                  return !attendanceNotifier.hasClientAttendedToday(c.id);
                }).toList();

                return PlutoGrid(
                  key: ValueKey(
                    '${filteredClients.length}-${activeAttendances.asData?.value.length}',
                  ),
                  columns: _buildColumns(context),
                  rows: _buildRows(filteredClients, context),
                  onLoaded: (PlutoGridOnLoadedEvent event) {
                    _stateManager = event.stateManager;
                    event.stateManager.setShowColumnFilter(false);
                    // Hide default column headers if we want to match exact mock, but mock has headers.
                    // We will style headers to look like mock.
                  },
                  configuration: PlutoGridConfiguration(
                    style: PlutoGridStyleConfig(
                      gridBackgroundColor: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      rowColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      gridBorderColor: Colors.transparent,
                      borderColor: Colors.transparent,
                      oddRowColor: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      evenRowColor: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      activatedColor: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFF1F5F9),

                      // Text Styles
                      cellTextStyle: GoogleFonts.inter(
                        fontSize: 12,
                        color: slate900,
                      ),
                      columnTextStyle: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: slate400,
                        letterSpacing: 1.0,
                      ),

                      // Dimensions
                      rowHeight: 72, // Match mock row height (approx)
                      columnHeight: 40,
                    ),
                    columnSize: const PlutoGridColumnSizeConfig(
                      autoSizeMode: PlutoAutoSizeMode.scale,
                    ),
                  ),
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: const Color(0xFF135BEC),
                ),
              ),
              error: (err, stack) => Center(
                child: Text(
                  'Error: $err',
                  style: GoogleFonts.inter(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<PlutoColumn> _buildColumns(BuildContext context) {
    return [
      PlutoColumn(
        title: 'SOCIO',
        field: 'member_info',
        type: PlutoColumnType.text(),
        enableRowChecked: false,
        enableEditingMode: false,
        enableSorting: true,
        renderer: (rendererContext) {
          final client = rendererContext.cell.value as ClientModel;
          return _buildMemberCell(client, context);
        },
      ),
      PlutoColumn(
        title: 'ESTADO MEMBRESÍA',
        field: 'status_info',
        type: PlutoColumnType.text(),
        enableEditingMode: false,
        width: 150,
        renderer: (rendererContext) {
          final client = rendererContext.cell.value as ClientModel;
          return _buildStatusCell(client, context);
        },
      ),
      PlutoColumn(
        title: 'ACCIÓN',
        field: 'action',
        textAlign: PlutoColumnTextAlign.center,
        type: PlutoColumnType.text(),
        enableEditingMode: false,
        width: 120,
        renderer: (rendererContext) {
          final client = rendererContext.cell.value as ClientModel;
          return _buildActionCell(client, context);
        },
      ),
    ];
  }

  List<PlutoRow> _buildRows(List<ClientModel> clients, BuildContext context) {
    return clients.map((client) {
      return PlutoRow(
        cells: {
          'member_info': PlutoCell(value: client),
          'status_info': PlutoCell(value: client),
          'action': PlutoCell(value: client),
        },
      );
    }).toList();
  }

  // --- Renderers ---

  Widget _buildMemberCell(ClientModel client, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final slate200 = isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0);
    final slate400 = const Color(0xFF94A3B8);
    final slate900 = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);

    final initials = (client.nombres?.isNotEmpty ?? false)
        ? client.nombres!.substring(0, 1).toUpperCase()
        : 'C';
    final name = "${client.nombres ?? ''} ${client.apellidos ?? ''}".trim();

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            shape: BoxShape.circle,
            border: Border.all(color: slate200),
          ),
          clipBehavior: Clip.antiAlias,
          child: client.photoUrl != null && client.photoUrl!.isNotEmpty
              ? Base64Image(
                  base64String: client.photoUrl!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                )
              : Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: slate400,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name.isEmpty ? 'Sin Nombre' : name,
                maxLines: 1,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: slate900,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                client.ci,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.robotoMono(fontSize: 10, color: slate400),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCell(ClientModel client, BuildContext context) {
    // Status Logic
    final hasPlan = client.planId != null && client.planId!.trim().isNotEmpty;
    final isActive = _isMembershipActive(client);
    final now = _entryGymNow();
    // Normalize dates to start of day for accurate day calculation
    final today = DateTime(now.year, now.month, now.day);
    DateTime? endDate;
    if (client.endDate != null) {
      endDate = DateTime(
        client.endDate!.year,
        client.endDate!.month,
        client.endDate!.day,
      );
    }

    // Colors
    final success = const Color(0xFF22C55E);
    final danger = const Color(0xFFEF4444);
    final warning = const Color(0xFFF59E0B);
    final slate400 = const Color(0xFF94A3B8);
    final slate500 = const Color(0xFF64748B);

    final statusColor = !hasPlan ? warning : (isActive ? success : danger);

    String dateText = '';
    String daysText = '';

    if (!hasPlan) {
      dateText = 'Membresía no asignada';
      daysText = 'Edite el socio para elegir un plan';
    } else if (endDate != null) {
      final formattedDate = DateFormat('dd/MM/yyyy').format(endDate);
      final daysDiff = endDate.difference(today).inDays;

      if (isActive) {
        dateText = 'Vence: $formattedDate';
        if (daysDiff == 0) {
          daysText = 'Hoy es el último día';
        } else if (daysDiff == 1) {
          daysText = 'Queda 1 día';
        } else {
          daysText = 'Quedan $daysDiff días';
        }
      } else {
        dateText = 'Venció: $formattedDate';
        final daysAgo = daysDiff.abs();
        if (daysAgo == 0) {
          // Should normally be catched by isActive check but handled just in case
          daysText = 'Vence hoy';
        } else if (daysAgo == 1) {
          daysText = 'Hace 1 día';
        } else {
          daysText = 'Hace $daysAgo días';
        }
      }
    } else {
      dateText = 'Sin fecha fin';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: statusColor.withValues(alpha: 0.2)),
          ),
          child: Text(
            !hasPlan ? 'SIN PLAN' : (isActive ? 'ACTIVO' : 'VENCIDO'),
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: statusColor,
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (dateText.isNotEmpty)
          Text(
            dateText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isActive ? slate500 : statusColor,
            ),
          ),
        if (daysText.isNotEmpty)
          Text(
            daysText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.normal,
              color: isActive ? slate400 : statusColor.withValues(alpha: 0.8),
            ),
          ),
      ],
    );
  }

  Widget _buildActionCell(ClientModel client, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Status Logic
    final isActive = _isMembershipActive(client);
    final hasPlan = client.planId != null && client.planId!.isNotEmpty;

    final success = const Color(0xFF22C55E);
    final warning = const Color(0xFFF59E0B); // Amber for 'Cobrar'
    final slate = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final slateBorder = isDark
        ? const Color(0xFF475569)
        : const Color(0xFFE2E8F0);

    final btnColor = !hasPlan ? warning : (isActive ? success : warning);
    // Si no tiene plan asignado, la acción primaria es editar la ficha para
    // asignárselo; si lo tiene, es registrar entrada (activo) o cobrar.
    final primaryTooltip = isActive
        ? 'Registrar entrada'
        : hasPlan
        ? 'Cobrar membresía'
        : 'Asignar un plan';

    return Align(
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Editar ficha (asignar plan / actualizar datos) sin salir de aquí.
          Tooltip(
            message: 'Editar socio',
            child: SizedBox(
              width: 34,
              height: 34,
              child: OutlinedButton(
                onPressed: () => _openEditClient(client),
                style: OutlinedButton.styleFrom(
                  foregroundColor: slate,
                  padding: EdgeInsets.zero,
                  side: BorderSide(color: slateBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(34, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Icon(Icons.edit_outlined, size: 16),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Acción primaria según estado.
          Tooltip(
            message: primaryTooltip,
            child: SizedBox(
              width: 34,
              height: 34,
              child: ElevatedButton(
                onPressed: () {
                  if (!hasPlan) {
                    _openEditClient(client);
                  } else if (isActive) {
                    _checkInClient(client);
                  } else {
                    _openPaymentDialog(client);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                  shadowColor: btnColor.withValues(alpha: 0.2),
                  minimumSize: const Size(34, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Icon(
                  !hasPlan
                      ? Icons.assignment_ind_outlined
                      : isActive
                      ? Icons.login_rounded
                      : Icons.payments_outlined,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
