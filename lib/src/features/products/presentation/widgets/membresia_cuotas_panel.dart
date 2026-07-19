import 'package:flutter/material.dart';
import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/membresia_cuota_models.dart';

class MembresiaCuotasPanel extends StatelessWidget {
  final List<MembresiaCuotaModel> cuotas;
  final String symbol;
  final Function(MembresiaCuotaModel cuota)? onPayCuota;

  const MembresiaCuotasPanel({
    super.key,
    required this.cuotas,
    this.symbol = '\$',
    this.onPayCuota,
  });

  @override
  Widget build(BuildContext context) {
    final t = PulsoTokens.of(context);
    final sorted = List<MembresiaCuotaModel>.from(cuotas)
      ..sort((a, b) => a.numeroCuota.compareTo(b.numeroCuota));

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: t.raised,
              border: Border(bottom: BorderSide(color: t.line)),
            ),
            child: Row(
              children: [
                Container(width: 8, height: 8, color: t.accent),
                const SizedBox(width: 8),
                const PulsoLabel('CALENDARIO DE CUOTAS DEL CLIENTE'),
                const Spacer(),
                Text(
                  '${cuotas.where((c) => c.isPaid).length}/${cuotas.length} PAGADAS',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: t.chalk,
                  ),
                ),
              ],
            ),
          ),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Esta membresía no tiene esquema de cuotas (pago único completo).',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 12,
                    color: t.muted,
                  ),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 48,
                columnSpacing: 24,
                headingRowColor: WidgetStateProperty.all(t.raised),
                columns: [
                  DataColumn(label: Text('CUOTA', style: _headerStyle(t))),
                  DataColumn(label: Text('IMPORTE', style: _headerStyle(t))),
                  DataColumn(label: Text('COBERTURA', style: _headerStyle(t))),
                  DataColumn(label: Text('EXIGIBLE', style: _headerStyle(t))),
                  DataColumn(label: Text('ESTADO', style: _headerStyle(t))),
                  DataColumn(label: Text('ACCIÓN', style: _headerStyle(t))),
                ],
                rows: sorted.map((c) {
                  final statusColor = c.isPaid
                      ? t.success
                      : (DateTime.now().isAfter(c.fechaExigible) ? t.danger : t.warning);

                  return DataRow(
                    cells: [
                      DataCell(Text(
                        'Cuota #${c.numeroCuota}',
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontWeight: FontWeight.w700,
                          color: t.chalk,
                        ),
                      )),
                      DataCell(Text(
                        '$symbol${c.importe.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontWeight: FontWeight.w700,
                          color: t.chalk,
                        ),
                      )),
                      DataCell(Text(
                        '${c.diasCobertura} días (${_formatDate(c.fechaCoberturaInicio)} - ${_formatDate(c.fechaCoberturaFin)})',
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 11,
                          color: t.muted,
                        ),
                      )),
                      DataCell(Text(
                        _formatDate(c.fechaExigible),
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 11,
                          color: t.muted,
                        ),
                      )),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            c.estado,
                            style: TextStyle(
                              fontFamily: PulsoFonts.mono,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        c.isPaid
                            ? Text(
                                'Pagada',
                                style: TextStyle(
                                  fontFamily: PulsoFonts.mono,
                                  fontSize: 11,
                                  color: t.muted,
                                ),
                              )
                            : PulsoPrimaryButton(
                                label: 'Pagar',
                                icon: Icons.payments_outlined,
                                onPressed: onPayCuota != null ? () => onPayCuota!(c) : null,
                              ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  TextStyle _headerStyle(PulsoTokens t) {
    return TextStyle(
      fontFamily: PulsoFonts.mono,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: t.muted2,
      letterSpacing: 0.5,
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
