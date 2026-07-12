import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../state/attendance_notifier.dart';
import '../../../clients/presentation/state/client_notifier.dart';
import '../../../clients/data/models/client_model.dart';
import '../../../products/presentation/state/payment_plan_notifier.dart';
import '../../../payments/presentation/widgets/process_payment_dialog.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';

class ManualAttendanceEntry extends ConsumerStatefulWidget {
  const ManualAttendanceEntry({super.key});

  @override
  ConsumerState<ManualAttendanceEntry> createState() =>
      _ManualAttendanceEntryState();
}

class _ManualAttendanceEntryState extends ConsumerState<ManualAttendanceEntry> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  ClientModel? _selectedClient;
  String _searchQuery = "";
  bool _isEntry = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _selectClient(ClientModel client) {
    setState(() {
      _selectedClient = client;
      _searchQuery = "";
      _searchController.clear();
      _focusNode.unfocus();

      // Auto-detect entry vs exit based on today's active attendance list
      final attendancesAsync = ref.read(attendanceNotifierProvider);
      bool alreadyCheckedIn = false;
      if (attendancesAsync.hasValue) {
        alreadyCheckedIn = attendancesAsync.value!.any(
          (a) => a.clientId == client.id && a.checkOut == null,
        );
      }
      _isEntry = !alreadyCheckedIn;
    });
  }

  Future<void> _registerAccess() async {
    if (_selectedClient == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isEntry) {
        // Register Check-In (Entrada)
        await ref
            .read(attendanceNotifierProvider.notifier)
            .checkIn(_selectedClient!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "✓ Entrada registrada con éxito para ${_selectedClient!.nombres}.",
              ),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        // Register Check-Out (Salida)
        final attendancesAsync = ref.read(attendanceNotifierProvider);
        String? activeAttendanceId;
        if (attendancesAsync.hasValue) {
          try {
            final active = attendancesAsync.value!.firstWhere(
              (a) => a.clientId == _selectedClient!.id && a.checkOut == null,
            );
            activeAttendanceId = active.id;
          } catch (_) {
            activeAttendanceId = null;
          }
        }

        if (activeAttendanceId != null) {
          await ref
              .read(attendanceNotifierProvider.notifier)
              .checkOut(activeAttendanceId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "✓ Salida registrada con éxito para ${_selectedClient!.nombres}.",
                ),
                backgroundColor: const Color(0xFFEA580C),
              ),
            );
            Navigator.pop(context);
          }
        } else {
          throw Exception(
            "No se encontró una sesión activa de entrada para este socio hoy.",
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "❌ Error al registrar acceso: ${e.toString().replaceAll("Exception: ", "")}",
            ),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openPaymentDialog() async {
    final client = _selectedClient;
    if (client == null) return;

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

    if (paid != true || !mounted) return;

    await ref.read(clientNotifierProvider.notifier).refresh();
    await ref.read(attendanceNotifierProvider.notifier).refresh();

    final clients = ref.read(clientNotifierProvider).asData?.value ?? [];
    ClientModel? updatedClient;
    for (final candidate in clients) {
      if (candidate.id == client.id) {
        updatedClient = candidate;
        break;
      }
    }
    if (updatedClient != null && mounted) {
      setState(() {
        _selectedClient = updatedClient;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    // Watch providers
    final clientsAsync = ref.watch(clientNotifierProvider);
    final plansAsync = ref.watch(paymentPlanProvider);

    // Resolve plan name
    String planName = "Plan Personalizado / Diario";
    if (plansAsync.hasValue &&
        _selectedClient != null &&
        _selectedClient!.planId != null) {
      final match = plansAsync.value!.where(
        (p) => p.id == _selectedClient!.planId,
      );
      if (match.isNotEmpty) {
        planName = match.first.nombre;
      }
    }

    // Expiration dates logic
    int daysRemaining = 0;
    bool isExpired = false;
    String expirationText = "Sin vencimiento";
    if (_selectedClient != null) {
      isExpired = !_selectedClient!.activo;
      if (_selectedClient!.endDate != null) {
        final now = toGymWallClock(appClock.nowUtc(), appClock.gymTimezone);
        final startOfToday = DateTime(now.year, now.month, now.day);
        final expiry = DateTime(
          _selectedClient!.endDate!.year,
          _selectedClient!.endDate!.month,
          _selectedClient!.endDate!.day,
        );
        final diff = expiry.difference(startOfToday).inDays;
        daysRemaining = diff;
        isExpired = diff < 0 || !_selectedClient!.activo;

        final formattedDate = DateFormat(
          'dd MMM yyyy',
          'es',
        ).format(_selectedClient!.endDate!);
        if (diff < 0) {
          expirationText = "$formattedDate (Vencido hace ${diff.abs()} días)";
        } else if (diff == 0) {
          expirationText = "$formattedDate (Vence hoy)";
        } else {
          expirationText = "$formattedDate ($diff días restantes)";
        }
      }
    }

    // Filter autocomplete suggestions
    final query = _searchQuery.trim().toLowerCase();
    final List<ClientModel> suggestions = [];
    if (query.isNotEmpty && _selectedClient == null && clientsAsync.hasValue) {
      final allClients = clientsAsync.value ?? [];
      suggestions.addAll(
        allClients
            .where((c) {
              final fullName = '${c.nombres ?? ''} ${c.apellidos ?? ''}'
                  .toLowerCase();
              return c.id.toLowerCase().contains(query) ||
                  fullName.contains(query);
            })
            .take(5),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;

        return Container(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Asistencia Manual",
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          "Busca un socio para registrar entrada o salida",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                    if (Navigator.canPop(context))
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        color: textMuted,
                      ),
                  ],
                ),
              ),

              // Main Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      // Search Bar & AutocompleteSuggestions
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "IDENTIFICAR SOCIO",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: textMuted,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: surfaceColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: borderColor),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.03,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.search,
                                            color: textMuted,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextField(
                                              controller: _searchController,
                                              focusNode: _focusNode,
                                              style: GoogleFonts.inter(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: textColor,
                                              ),
                                              decoration: InputDecoration(
                                                hintText:
                                                    "Escribe cédula, código o nombre...",
                                                hintStyle: GoogleFonts.inter(
                                                  color: textMuted.withValues(
                                                    alpha: 0.5,
                                                  ),
                                                  fontSize: 16,
                                                ),
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                            ),
                                          ),
                                          if (_searchQuery.isNotEmpty ||
                                              _selectedClient != null)
                                            IconButton(
                                              icon: const Icon(Icons.clear),
                                              color: textMuted,
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(() {
                                                  _selectedClient = null;
                                                  _searchQuery = "";
                                                });
                                                _focusNode.requestFocus();
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    height: 60,
                                    width: 60,
                                    decoration: BoxDecoration(
                                      color: surfaceColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: borderColor),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.03,
                                          ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      onPressed: () {
                                        // Mock QR scanning
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Escáner de código de barras activado en receptor físico.",
                                            ),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.qr_code_scanner),
                                      color: const Color(0xFF135BEC),
                                      iconSize: 24,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Autocomplete suggestion overlay
                          if (suggestions.isNotEmpty)
                            Positioned(
                              top: 85,
                              left: 0,
                              right: 72,
                              child: Material(
                                elevation: 8,
                                borderRadius: BorderRadius.circular(12),
                                color: surfaceColor,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: suggestions.length,
                                    separatorBuilder: (context, index) =>
                                        Divider(height: 1, color: borderColor),
                                    itemBuilder: (context, index) {
                                      final c = suggestions[index];
                                      return ListTile(
                                        leading: CircleAvatar(
                                          radius: 20,
                                          backgroundColor: isDark
                                              ? const Color(0xFF334155)
                                              : const Color(0xFFE2E8F0),
                                          backgroundImage: c.fotoCliente != null
                                              ? MemoryImage(c.fotoCliente!)
                                              : null,
                                          child: c.fotoCliente == null
                                              ? Text(
                                                  c.nombres
                                                          ?.substring(0, 1)
                                                          .toUpperCase() ??
                                                      "S",
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.bold,
                                                    color: textColor,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        title: Text(
                                          "${c.nombres} ${c.apellidos}",
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: textColor,
                                          ),
                                        ),
                                        subtitle: Text(
                                          "CI: ${c.id}",
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: textMuted,
                                          ),
                                        ),
                                        trailing: Icon(
                                          Icons.chevron_right,
                                          color: textMuted,
                                          size: 20,
                                        ),
                                        onTap: () => _selectClient(c),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Selection details
                      if (_selectedClient != null)
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildClientCard(
                                  _selectedClient!,
                                  planName,
                                  expirationText,
                                  isExpired,
                                  daysRemaining,
                                  textColor,
                                  textMuted,
                                  surfaceColor,
                                  borderColor,
                                  isDark,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 4,
                                child: _buildActionCard(
                                  _selectedClient!,
                                  isExpired,
                                  textColor,
                                  textMuted,
                                  surfaceColor,
                                  borderColor,
                                  isDark,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildClientCard(
                                _selectedClient!,
                                planName,
                                expirationText,
                                isExpired,
                                daysRemaining,
                                textColor,
                                textMuted,
                                surfaceColor,
                                borderColor,
                                isDark,
                              ),
                              const SizedBox(height: 24),
                              _buildActionCard(
                                _selectedClient!,
                                isExpired,
                                textColor,
                                textMuted,
                                surfaceColor,
                                borderColor,
                                isDark,
                              ),
                            ],
                          )
                      else
                        // Beautiful Empty State
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_search_rounded,
                                size: 80,
                                color: textMuted.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Ningún socio seleccionado",
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Utiliza la barra de búsqueda superior para identificar un cliente",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: textMuted,
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
        );
      },
    );
  }

  Widget _buildClientCard(
    ClientModel client,
    String planName,
    String expirationText,
    bool isExpired,
    int daysRemaining,
    Color textColor,
    Color textMuted,
    Color surfaceColor,
    Color borderColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  border: Border.all(
                    color: isExpired
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF16A34A),
                    width: 2.5,
                  ),
                  image: client.fotoCliente != null
                      ? DecorationImage(
                          image: MemoryImage(client.fotoCliente!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: client.fotoCliente == null
                    ? Icon(
                        Icons.person,
                        size: 40,
                        color: textMuted.withValues(alpha: 0.7),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${client.nombres} ${client.apellidos}",
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "C.I. ${client.id}",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Expired or Active Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isExpired
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isExpired ? "VENCIDO" : "ACTIVO",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isExpired
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.card_membership,
            "Membresía",
            planName,
            textColor,
          ),
          const SizedBox(height: 14),
          _buildInfoRow(
            Icons.calendar_today,
            "Vencimiento",
            expirationText,
            isExpired
                ? const Color(0xFFDC2626)
                : (daysRemaining <= 3
                      ? const Color(0xFFD97706)
                      : const Color(0xFF16A34A)),
          ),
          const SizedBox(height: 14),
          _buildInfoRow(
            Icons.schedule,
            "Horario",
            client.scheduleId == "0" || client.scheduleId == null
                ? "Libre entrada"
                : (client.scheduleId == "1"
                      ? "06:00 - 12:00"
                      : "12:00 - 22:00"),
            textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    ClientModel client,
    bool isExpired,
    Color textColor,
    Color textMuted,
    Color surfaceColor,
    Color borderColor,
    bool isDark,
  ) {
    // Expiration checks: if active check-out is active, allow exit. If expired, warn first.
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TIPO DE ACCESO",
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textMuted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isEntry = true;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isEntry
                            ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _isEntry
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.login,
                            color: _isEntry
                                ? const Color(0xFF135BEC)
                                : textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Entrada",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _isEntry
                                  ? const Color(0xFF135BEC)
                                  : textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isEntry = false;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isEntry
                            ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: !_isEntry
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.logout,
                            color: !_isEntry
                                ? const Color(0xFFEA580C)
                                : textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Salida",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: !_isEntry
                                  ? const Color(0xFFEA580C)
                                  : textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Billing / Expiry Warnings
          if (isExpired && _isEntry) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "PAGO REQUERIDO",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "El plan de este socio ha vencido. Flex Logic requiere registrar un pago antes del acceso.",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF7F1D1D),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Registration button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (isExpired && _isEntry
                        ? _openPaymentDialog
                        : _registerAccess),
              style: ElevatedButton.styleFrom(
                backgroundColor: isExpired && _isEntry
                    ? const Color(0xFFF59E0B)
                    : (_isEntry
                          ? const Color(0xFF135BEC)
                          : const Color(0xFFEA580C)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: _isLoading ? 0 : 2,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isExpired && _isEntry
                              ? Icons.payments_outlined
                              : Icons.check_circle_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            isExpired && _isEntry
                                ? "COBRAR MEMBRESÍA"
                                : "Registrar Acceso",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
}
