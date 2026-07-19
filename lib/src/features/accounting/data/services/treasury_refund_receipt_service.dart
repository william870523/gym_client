import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../models/accounting_models.dart';

class TreasuryRefundReceiptService {
  const TreasuryRefundReceiptService();

  Future<bool> printReceipt(TreasuryRefundReceiptModel receipt) async {
    final bytes = await buildPdf(receipt);
    return Printing.layoutPdf(
      name: '${receipt.receiptNumber}.pdf',
      format: PdfPageFormat.a4,
      dynamicLayout: false,
      onLayout: (_) async => bytes,
    );
  }

  Future<Uint8List> buildPdf(TreasuryRefundReceiptModel receipt) async {
    final document = pw.Document(
      title: 'Comprobante ${receipt.receiptNumber}',
      author: 'GymOS',
      subject: 'Resolución de reembolso de cliente',
    );
    const ink = PdfColor.fromInt(0xff24211d);
    const muted = PdfColor.fromInt(0xff706a61);
    const line = PdfColor.fromInt(0xffd7cfc3);
    const accent = PdfColor.fromInt(0xffd94a24);
    final money = NumberFormat('#,##0.00');
    final registered = formatDateInZone(
      receipt.registeredAt,
      appClock.gymTimezone,
      pattern: 'dd/MM/yyyy HH:mm',
    );

    pw.Widget datum(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 125,
            child: pw.Text(
              label.toUpperCase(),
              style: const pw.TextStyle(fontSize: 8, color: muted),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 40, 42, 38),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(height: 3, color: ink),
            pw.SizedBox(height: 22),
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
                        fontSize: 9,
                        letterSpacing: 1.4,
                        color: muted,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'COMPROBANTE\nDE REEMBOLSO',
                      style: pw.TextStyle(
                        fontSize: 25,
                        fontWeight: pw.FontWeight.bold,
                        color: ink,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      receipt.status,
                      style: pw.TextStyle(
                        color: receipt.status == 'CONFIRMADO' ? accent : muted,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      receipt.receiptNumber,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Container(height: 1, color: line),
            pw.SizedBox(height: 18),
            pw.Text(
              '${receipt.currencyCode} ${money.format(receipt.amount)}',
              style: pw.TextStyle(
                fontSize: 32,
                fontWeight: pw.FontWeight.bold,
                color: accent,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              receipt.clientName.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: ink,
              ),
            ),
            pw.SizedBox(height: 22),
            datum('Identificación', receipt.clientId),
            datum('Plan de origen', receipt.planName),
            datum('Fecha de registro', '$registered · ${appClock.gymTimezone}'),
            datum('Resultado', receipt.status),
            datum('Cuenta de salida', receipt.accountName ?? 'No aplica'),
            datum('Método', receipt.paymentTypeName ?? 'Crédito interno'),
            datum('Registró', receipt.operatorName),
            datum('Motivo solicitud', receipt.requestReason),
            datum('Decisión Tesorería', receipt.reason),
            if (receipt.reversal != null) ...[
              pw.SizedBox(height: 14),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: accent),
                ),
                child: pw.Text(
                  'COMPROBANTE ANULADO · ${receipt.reversal?['motivo'] ?? 'Reversión registrada'}',
                  style: pw.TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
            pw.Spacer(),
            pw.Container(height: 1, color: line),
            pw.SizedBox(height: 8),
            pw.Text(
              'Documento auditable. Una reversión conserva este comprobante y reabre la solicitud de Tesorería.',
              style: const pw.TextStyle(fontSize: 8, color: muted),
            ),
          ],
        ),
      ),
    );
    return document.save();
  }
}
