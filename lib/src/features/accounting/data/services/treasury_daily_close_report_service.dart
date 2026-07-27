import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../models/accounting_models.dart';

class TreasuryDailyCloseReportService {
  const TreasuryDailyCloseReportService();

  Future<bool> printReport({
    required TreasuryLedgerModel ledger,
    required TreasuryAccountDayModel account,
  }) async {
    final bytes = await buildPdf(ledger: ledger, account: account);
    final close = account.close;
    return Printing.layoutPdf(
      name: '${close?.receiptNumber ?? 'tesoreria-${ledger.businessDate}'}.pdf',
      format: PdfPageFormat.a4,
      dynamicLayout: false,
      onLayout: (_) async => bytes,
    );
  }

  Future<Uint8List> buildPdf({
    required TreasuryLedgerModel ledger,
    required TreasuryAccountDayModel account,
  }) async {
    final close = account.close;
    if (close == null) {
      throw StateError('La cuenta todavía no tiene un cierre imprimible.');
    }
    final money = NumberFormat('#,##0.00');
    final movements =
        ledger.movements
            .where((movement) => movement.accountId == account.id)
            .toList()
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    const ink = PdfColor.fromInt(0xff24211d);
    const muted = PdfColor.fromInt(0xff706a61);
    const line = PdfColor.fromInt(0xffd7cfc3);
    const accent = PdfColor.fromInt(0xffd94a24);
    const paper = PdfColor.fromInt(0xfff3ede5);
    final document = pw.Document(
      title: 'Cierre diario ${close.receiptNumber}',
      author: 'GymOS',
      subject: 'Cierre diario de Tesorería',
    );

    pw.Widget amount(String label, double value, {bool strong = false}) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: line),
              bottom: pw.BorderSide(color: line),
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label.toUpperCase(),
                style: const pw.TextStyle(
                  color: muted,
                  fontSize: 7,
                  letterSpacing: 0.8,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '${account.currencyCode} ${money.format(value)}',
                style: pw.TextStyle(
                  color: strong ? accent : ink,
                  fontSize: strong ? 15 : 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    pw.Widget cell(
      String value, {
      bool bold = false,
      pw.TextAlign align = pw.TextAlign.left,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 7),
        child: pw.Text(
          value,
          textAlign: align,
          style: pw.TextStyle(
            color: ink,
            fontSize: 7.5,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 32, 34, 32),
        build: (_) => [
          pw.Container(height: 3, color: ink),
          pw.SizedBox(height: 18),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'GYMOS · TESORERÍA',
                    style: const pw.TextStyle(
                      color: muted,
                      fontSize: 8,
                      letterSpacing: 1.3,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'CIERRE DIARIO\nDE CUENTA',
                    style: pw.TextStyle(
                      color: ink,
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    close.approvalState == 'APROBADA'
                        ? 'CERRADO · APROBADO'
                        : account.requiresReconciliation
                        ? 'REQUIERE CONCILIACIÓN'
                        : account.isReconciled
                        ? 'CONCILIADO'
                        : 'CERRADO',
                    style: pw.TextStyle(
                      color: account.requiresReconciliation ? accent : ink,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    close.receiptNumber,
                    style: const pw.TextStyle(fontSize: 9, color: muted),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            account.name.toUpperCase(),
            style: pw.TextStyle(
              color: ink,
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${ledger.businessDate} · ${account.currencyCode} · ${appClock.gymTimezone}',
            style: const pw.TextStyle(color: muted, fontSize: 9),
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              amount('Inicial', close.openingBalance),
              amount('Entradas', close.entries),
              amount('Salidas', close.exits),
            ],
          ),
          pw.Row(
            children: [
              amount('Esperado', close.expectedBalance, strong: true),
              amount('Contado', close.countedBalance),
              amount('Diferencia', close.difference),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            color: paper,
            padding: const pw.EdgeInsets.all(10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${close.movementCount} movimiento(s) incluidos en el cierre',
                  style: pw.TextStyle(
                    color: ink,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Cerró ${close.operatorName} · ${formatDateInZone(close.closedAt, appClock.gymTimezone, pattern: 'dd/MM/yyyy HH:mm')}',
                  style: const pw.TextStyle(color: muted, fontSize: 8),
                ),
              ],
            ),
          ),
          if (close.approvalState == 'APROBADA' ||
              close.varianceReason != null) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: ink)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'CONTROL DE DIFERENCIA',
                        style: pw.TextStyle(
                          color: ink,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Tolerancia ${account.currencyCode} ${money.format(close.appliedTolerance)}',
                        style: const pw.TextStyle(color: muted, fontSize: 8),
                      ),
                    ],
                  ),
                  if (close.varianceReason != null) ...[
                    pw.SizedBox(height: 5),
                    pw.Text(
                      close.varianceReason!,
                      style: const pw.TextStyle(color: ink, fontSize: 8),
                    ),
                  ],
                  if (close.approverName != null) ...[
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Aprobó ${close.approverName}'
                      '${close.approverRole == null ? '' : ' · ${close.approverRole}'}'
                      '${close.approvedAt == null ? '' : ' · ${formatDateInZone(close.approvedAt!, appClock.gymTimezone, pattern: 'dd/MM/yyyy HH:mm')}'}',
                      style: const pw.TextStyle(color: muted, fontSize: 8),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (account.lateMovementCount > 0) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: accent),
              ),
              child: pw.Text(
                '${account.lateMovementCount} movimiento(s) llegaron después del cierre. El comprobante original se conserva; la cuenta requiere conciliación.',
                style: pw.TextStyle(
                  color: accent,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
          if (account.reconciliations.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'CONCILIACIONES POSTERIORES AL CIERRE',
              style: const pw.TextStyle(
                color: muted,
                fontSize: 8,
                letterSpacing: 1.1,
              ),
            ),
            pw.SizedBox(height: 7),
            for (final reconciliation in account.reconciliations)
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 6),
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(
                  color: paper,
                  border: pw.Border(
                    left: pw.BorderSide(color: accent, width: 2),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          reconciliation.receiptNumber,
                          style: pw.TextStyle(
                            color: ink,
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          '${reconciliation.movementCount} mov. · ajuste ${account.currencyCode} ${money.format(reconciliation.netAdjustment)}',
                          style: const pw.TextStyle(color: accent, fontSize: 8),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      reconciliation.reason,
                      style: const pw.TextStyle(color: ink, fontSize: 8),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Evidencia: ${reconciliation.evidenceReference} · ${reconciliation.operatorName} · ${formatDateInZone(reconciliation.registeredAt, appClock.gymTimezone, pattern: 'dd/MM/yyyy HH:mm')}',
                      style: const pw.TextStyle(color: muted, fontSize: 7.5),
                    ),
                  ],
                ),
              ),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: ink)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'SALDO AJUSTADO VIGENTE',
                    style: pw.TextStyle(
                      color: ink,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${account.currencyCode} ${money.format(account.adjustedBalance ?? close.countedBalance)}',
                    style: pw.TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          pw.SizedBox(height: 18),
          pw.Text(
            'LIBRO DE MOVIMIENTOS DE LA CUENTA',
            style: const pw.TextStyle(
              color: muted,
              fontSize: 8,
              letterSpacing: 1.1,
            ),
          ),
          pw.SizedBox(height: 7),
          pw.Table(
            border: const pw.TableBorder(
              top: pw.BorderSide(color: line),
              bottom: pw.BorderSide(color: line),
              horizontalInside: pw.BorderSide(color: line),
            ),
            columnWidths: const {
              0: pw.FixedColumnWidth(48),
              1: pw.FixedColumnWidth(48),
              2: pw.FlexColumnWidth(2.7),
              3: pw.FlexColumnWidth(1.3),
              4: pw.FixedColumnWidth(72),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: paper),
                children: [
                  cell('HORA', bold: true),
                  cell('TIPO', bold: true),
                  cell('CONCEPTO', bold: true),
                  cell('MÉTODO', bold: true),
                  cell('IMPORTE', bold: true, align: pw.TextAlign.right),
                ],
              ),
              for (final movement in movements)
                pw.TableRow(
                  children: [
                    cell(
                      formatDateInZone(
                        movement.occurredAt,
                        appClock.gymTimezone,
                        pattern: 'HH:mm',
                      ),
                    ),
                    cell(movement.direction),
                    cell(
                      '${movement.concept.replaceAll('_', ' ')}'
                      '${movement.late ? ' · TARDÍO' : ''}'
                      '${movement.reconciled ? ' · CONCILIADO' : ''}'
                      '${movement.requiresReview ? ' · REVISAR' : ''}',
                    ),
                    cell(movement.paymentTypeName ?? '—'),
                    cell(
                      '${movement.isEntry ? '+' : '-'} ${money.format(movement.amount)}',
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
            ],
          ),
          // Recargos condonados del DÍA (docs/RECARGO_MORA.md §6-bis). Es
          // control, no caja: por eso va fuera del arqueo y se rotula así. No
          // pertenece a esta cuenta ni a su moneda, sino a la jornada.
          if (!ledger.waivedLateFees.isEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              'RECARGOS POR MORA CONDONADOS EN LA JORNADA',
              style: const pw.TextStyle(
                color: muted,
                fontSize: 8,
                letterSpacing: 1.1,
              ),
            ),
            pw.SizedBox(height: 7),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: ink)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Informativo: no entró ni salió dinero; no afecta el arqueo.',
                        style: const pw.TextStyle(color: muted, fontSize: 7.5),
                      ),
                      pw.Text(
                        // Una cifra por moneda; nunca un total mezclado.
                        ledger.waivedLateFees.byCurrency
                            .map(
                              (currency) =>
                                  '${currency.currencyCode} ${money.format(currency.amount)}',
                            )
                            .join('  ·  '),
                        style: pw.TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  for (final waived in ledger.waivedLateFees.details)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              '${waived.memberName} · ${waived.reason} · autorizó ${waived.authorizedBy}',
                              style: const pw.TextStyle(color: ink, fontSize: 8),
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            '${waived.currencyCode} ${money.format(waived.amount)}',
                            style: const pw.TextStyle(color: ink, fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          // R5.6 — quién recibió el dinero (docs/PAYMENT_COLLECTOR_ATTRIBUTION
          // §6). Va aparte del arqueo y no sustituye a «Cerró», que identifica
          // a quien contó la caja, no a quien cobró.
          if (ledger.collectorRows.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              'COBROS POR RECEPCIONISTA',
              style: const pw.TextStyle(
                color: muted,
                fontSize: 8,
                letterSpacing: 1.1,
              ),
            ),
            pw.SizedBox(height: 7),
            pw.TableHelper.fromTextArray(
              headers: const [
                'Cobrado por',
                'Cuenta',
                'Moneda',
                'Pagos',
                'Socios',
                'Bruto',
                'Cambio',
                'Anulado',
                'Neto',
              ],
              data: [
                for (final row in ledger.collectorRows)
                  [
                    row.unattributed
                        ? 'Sin atribuir · histórico'
                        : '${row.name}${(row.role ?? '').isEmpty ? '' : ' (${row.role})'}',
                    row.accountName,
                    // Cada fila vive en su moneda: no hay fila de total.
                    row.currencyCode,
                    '${row.payments}',
                    '${row.clients}',
                    money.format(row.gross),
                    money.format(row.change),
                    money.format(row.annulled),
                    money.format(row.net),
                  ],
              ],
              headerStyle: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: ink,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7.5, color: ink),
              cellAlignments: {
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
                7: pw.Alignment.centerRight,
                8: pw.Alignment.centerRight,
              },
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 3,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Un pago mixto cuenta como un solo cobro. Los importes no se suman '
              'entre monedas. «Cobrado por» no es «Cerrado por» ni «Anulado por».',
              style: const pw.TextStyle(color: muted, fontSize: 7),
            ),
          ],
          pw.SizedBox(height: 18),
          pw.Text(
            'Documento auditable. El cierre conserva una fotografía inmutable de los movimientos incluidos; los movimientos posteriores se concilian por separado.',
            style: const pw.TextStyle(color: muted, fontSize: 7.5),
          ),
        ],
      ),
    );
    return document.save();
  }
}
