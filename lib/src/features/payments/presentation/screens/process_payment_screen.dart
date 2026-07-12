import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../clients/data/models/client_model.dart';

// Defined locally to match HTML exactly without dependencies
class _AppColors {
  static const primary = Color(0xFF135bec);
  static const backgroundLight = Color(0xFFf8f9fc);
  static const backgroundSurface = Colors.white;
  static const success = Color(0xFF16a34a);
  static const warning = Color(0xFFca8a04);
  static const error = Color(0xFFdc2626);
  static const textMain = Color(0xFF0f172a);
  static const textSecondary = Color(0xFF64748b);
  static const borderColor = Color(0xFFe2e8f0);
}

class ProcessPaymentScreen extends ConsumerStatefulWidget {
  final ClientModel client;
  final String planId;

  const ProcessPaymentScreen({
    super.key,
    required this.client,
    required this.planId,
  });

  @override
  ConsumerState<ProcessPaymentScreen> createState() =>
      _ProcessPaymentScreenState();
}

class _ProcessPaymentScreenState extends ConsumerState<ProcessPaymentScreen> {
  // Static mock state
  final List<Map<String, dynamic>> _paymentRows = [
    {
      'type': 'Efectivo',
      'currency': 'USD',
      'amount': '30.00',
      'rate': '1.0000',
      'account': null,
    },
    {
      'type': 'Transferencia',
      'currency': 'EUR',
      'amount': null,
      'rate': '1.1000',
      'account': null,
    }, // Empty amount
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.backgroundLight,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Column(
                  children: [
                    _buildClientInfoCard(),
                    const SizedBox(height: 24),
                    _buildPaymentDetailsSection(),
                  ],
                ),
              ),
            ),
          ),
          _buildStickyFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _AppColors.backgroundSurface,
        border: Border(bottom: BorderSide(color: _AppColors.borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Cobros',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _AppColors.textSecondary,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 14,
                            color: _AppColors.textSecondary,
                          ),
                          Text(
                            'Transacciones',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cobrar Plan #40291',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _AppColors.textMain,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Sistema Online Indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _AppColors.success.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                          ), // Ping effect mock
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: _AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'SISTEMA ONLINE',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            'Sincronizado hace 1 min',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: Colors.green.shade600,
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
          // Right actions
          Row(
            children: [
              Container(
                width: 256,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search,
                      size: 20,
                      color: _AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Buscar...',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.notifications_none,
                color: _AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClientInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cliente (Vertical Stack)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLIENTE',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        backgroundColor: Colors.transparent,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _AppColors.borderColor),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Foto del Cliente',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: _AppColors.textMain,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 280,
                                  height: 280,
                                  color: _AppColors.backgroundLight,
                                  child: widget.client.fotoCliente != null
                                      ? Image.memory(
                                          widget.client.fotoCliente!,
                                          fit: BoxFit.cover,
                                        )
                                      : Center(
                                          child: Text(
                                            (widget.client.nombres ?? '?')[0],
                                            style: GoogleFonts.inter(
                                              fontSize: 80,
                                              fontWeight: FontWeight.bold,
                                              color: _AppColors.textMain,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '${widget.client.nombres} ${widget.client.apellidos}',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _AppColors.textMain,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: CircleAvatar(
                      radius: 28,
                      backgroundImage: widget.client.fotoCliente != null
                          ? MemoryImage(widget.client.fotoCliente!)
                          : const NetworkImage(
                              "https://lh3.googleusercontent.com/aida-public/AB6AXuCz9IcV5-Pr10cBxDuvrTeaBDAi3nJwYvT0JhJaQed7gsilm6DB9C-qg6zxU-2RZLzdT9KFUZ8Ye88l4eXklJhjZ4b0PRAX0afy2sokzmDQwWbgzNSNIrqPqGoLVDovMn-tr58NtTl5Ih9s3g7TGXx_sSNy2piYGRmkTwxnr2sj1dqQeFoOKxV3ZRKVu5c13aDw7B-d1yZO6oXMw2oLflX4l2Ybi3f2MPbbiPVwQ0SYE_eYSccE3BKxWrtmLejbsk10XH85nkFTg-E",
                            ) as ImageProvider,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Juan Pérez',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _AppColors.textMain,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 130, color: Colors.grey.shade100),
          const SizedBox(width: 24),
          // Plan Info (Vertical Stack)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  'PLAN SUSCRITO',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Plan Gold',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Mensual',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: _AppColors.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Vence: 30 Nov, 2023',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(width: 1, height: 130, color: Colors.grey.shade100),
          const SizedBox(width: 24),
          // Progress Bar Box
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL DEL PLAN',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '\$45.00',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _AppColors.textMain,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'PAGADO',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '\$30.00',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _AppColors.success,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress Bar
                  Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        height: 8,
                        width: 250,
                        decoration: BoxDecoration(
                          color: _AppColors.success,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ), // Mock 66% visual
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progreso: 66%',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _AppColors.textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _AppColors.error.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _AppColors.error.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          'Saldo Restante: \$15.00',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailsSection() {
    return Column(
      children: [
        Row(
          children: [
            Text(
              'Detalle del Pago',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _AppColors.textMain,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'Crítico',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 1000,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _AppColors.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50.withValues(alpha: 0.8),
                      border: const Border(
                        bottom: BorderSide(color: _AppColors.borderColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        _colHeader('TIPO DE PAGO', 2),
                        _colHeader('MONEDA', 1),
                        _colHeader('CANTIDAD', 2),
                        _colHeader('TASA DE CAMBIO', 2, subtext: 'Automática'),
                        _colHeader('CUENTA DESTINO', 3, subtext: '(Condicional)'),
                        _colHeader(
                          'EQUIVALENTE',
                          2,
                          subtext: 'Calculado',
                          align: TextAlign.right,
                        ),
                        const SizedBox(width: 48), // Action space
                      ],
                    ),
                  ),
                  // Rows
                  ..._paymentRows.map((row) => _buildPaymentRow(row)),
                  // Add Row Button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.grey.shade50.withValues(alpha: 0.5),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        label: const Text('Añadir otro método de pago'),
                        style: TextButton.styleFrom(
                          foregroundColor: _AppColors.primary,
                          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: _AppColors.borderColor),
                  // Footer Totals
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey.shade100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Total Acumulado:',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '\$30.00',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _AppColors.textMain,
                              ),
                            ),
                            Text(
                              'Faltan \$15.00',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _AppColors.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          width: 48 + 16,
                        ), // Align with last column + actions
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Error Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _AppColors.error.withValues(alpha: 0.05),
            border: Border.all(color: _AppColors.error.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.gpp_maybe,
                  size: 20,
                  color: _AppColors.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pago Incompleto',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: _AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'El monto total registrado es inferior al precio del plan. Por favor, agregue otro método de pago o registre el saldo pendiente.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF991b1b),
                      ),
                    ), // red-800
                  ],
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFb91c1c),
                ),
                child: Text(
                  'Corregir Saldo',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ), // red-700
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _colHeader(
    String text,
    int flex, {
    String? subtext,
    TextAlign align = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: align == TextAlign.right
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _AppColors.textSecondary,
            ),
          ),
          if (subtext != null)
            Text(
              subtext,
              style: GoogleFonts.inter(
                fontSize: 9,
                color: _AppColors.textMain.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(Map<String, dynamic> row) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white),
        ), // Spacer? No, border between rows
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Align to top for inputs
        children: [
          // Type
          Expanded(
            flex: 2,
            child: _seamlessDropdown(row['type'], [
              'Efectivo',
              'Transferencia',
              'Tarjeta',
            ], icon: Icons.payments),
          ),
          const SizedBox(width: 8),
          // Currency
          Expanded(
            flex: 1,
            child: _seamlessDropdown(row['currency'], ['USD', 'EUR', 'VES']),
          ),
          const SizedBox(width: 8),
          // Amount
          Expanded(
            flex: 2,
            child: _seamlessInput(
              row['amount'] ?? '',
              placeholder: '0.00',
              isBold: true,
            ),
          ),
          const SizedBox(width: 8),
          // Rate
          Expanded(flex: 2, child: _lockedInput(row['rate'])),
          const SizedBox(width: 8),
          // Account
          Expanded(
            flex: 3,
            child: row['type'] == 'Efectivo'
                ? Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.transparent),
                    ),
                    child: Text(
                      'No requerido',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : _warningDropdown(),
          ),
          const SizedBox(width: 8),
          // Equivalent
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(10),
              alignment: Alignment.centerRight,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                row['amount'] != null ? '\$${row['amount']}' : '\$0.00',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
          // Delete
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.delete_outline, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _seamlessDropdown(String value, List<String> items, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.transparent), // Seamless
        color: Colors.white,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.grey.shade400),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _AppColors.textMain,
              ),
            ),
          ),
          const Icon(Icons.arrow_drop_down, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _seamlessInput(
    String value, {
    String? placeholder,
    bool isBold = false,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.transparent), // Seamless
        color: Colors.white,
      ),
      child: Text(
        value.isEmpty ? (placeholder ?? '') : value,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          color: value.isEmpty ? Colors.grey.shade400 : _AppColors.textMain,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _lockedInput(String value) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
        color: Colors.grey.shade100,
      ),
      child: Row(
        children: [
          const Icon(Icons.lock, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _warningDropdown() {
    return Stack(
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _AppColors.warning),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: _AppColors.primary.withValues(alpha: 0.05),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Seleccione cuenta...',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _AppColors.textMain,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.grey),
            ],
          ),
        ),
        Positioned(
          top: -6,
          right: 8,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Icon(Icons.warning, size: 10, color: _AppColors.warning),
                const SizedBox(width: 2),
                Text(
                  'REQUERIDO',
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: _AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _AppColors.borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 800,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_sync, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Guardado localmente • ',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Ver historial',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _AppColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _AppColors.textMain,
                      side: const BorderSide(color: _AppColors.borderColor),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.save, size: 20),
                    label: const Text('Guardar Pago'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      shadowColor: _AppColors.primary.withValues(alpha: 0.4),
                      textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
