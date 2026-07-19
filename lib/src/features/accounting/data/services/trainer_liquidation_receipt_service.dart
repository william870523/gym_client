import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../models/accounting_models.dart';

class TrainerLiquidationReceiptService {
  const TrainerLiquidationReceiptService();

  Future<bool> printReceipt(TrainerLiquidationModel receipt) async {
    final bytes = await buildPdf(receipt);
    return Printing.layoutPdf(
      name: '${receipt.receiptNumber}.pdf',
      format: PdfPageFormat.a4,
      dynamicLayout: false,
      onLayout: (_) async => bytes,
    );
  }

  Future<Uint8List> buildPdf(TrainerLiquidationModel receipt) async {
    final document = pw.Document(
      title: 'Comprobante ${receipt.receiptNumber}',
      author: 'GymOS',
      subject: 'Liquidación de entrenador',
    );
    const ink = PdfColor.fromInt(0xff24211d);
    const muted = PdfColor.fromInt(0xff706a61);
    const line = PdfColor.fromInt(0xffd7cfc3);
    const accent = PdfColor.fromInt(0xffd94a24);
    final money = NumberFormat('#,##0.00');
    final paidAt = formatDateInZone(
      receipt.paidAt,
      appClock.gymTimezone,
      pattern: 'dd/MM/yyyy HH:mm',
    );

    pw.Widget datum(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
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
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 38, 40, 36),
        build: (_) => [
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
                    'GYMOS · NÓMINA',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.4,
                      color: muted,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'COMPROBANTE\nDE LIQUIDACIÓN',
                    style: pw.TextStyle(
                      fontSize: 25,
                      lineSpacing: 1,
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
                      color: receipt.status == 'PAGADA' ? accent : muted,
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
            '${receipt.currencyCode} ${money.format(receipt.total)}',
            style: pw.TextStyle(
              fontSize: 32,
              fontWeight: pw.FontWeight.bold,
              color: accent,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            receipt.trainerName.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: ink,
            ),
          ),
          pw.SizedBox(height: 22),
          datum('Fecha de negocio', '$paidAt · ${appClock.gymTimezone}'),
          if (receipt.type == 'BAJA_FINAL')
            datum(
              'Tipo',
              'Liquidación extraordinaria final · expediente ${receipt.offboardingCaseId ?? '—'}',
            ),
          datum('Cuenta de salida', receipt.accountName),
          datum('Método', receipt.paymentTypeName),
          datum('Registró', receipt.operatorName),
          datum(
            'Comisiones',
            '${receipt.currencyCode} ${money.format(receipt.commissionTotal)} · ${receipt.commissionConcepts} concepto(s)',
          ),
          datum(
            'Obligaciones fijas',
            '${receipt.currencyCode} ${money.format(receipt.fixedTotal)} · ${receipt.fixedConcepts} concepto(s)',
          ),
          if (receipt.notes?.trim().isNotEmpty == true)
            datum('Notas', receipt.notes!.trim()),
          pw.SizedBox(height: 14),
          pw.Text(
            'DESGLOSE DE LA LIQUIDACIÓN',
            style: const pw.TextStyle(
              fontSize: 8,
              color: muted,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: const pw.TableBorder(
              top: pw.BorderSide(color: line),
              bottom: pw.BorderSide(color: line),
              horizontalInside: pw.BorderSide(color: line),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.5),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xfff3ede5),
                ),
                children: [
                  _cell('CONCEPTO', bold: true),
                  _cell('PERIODO', bold: true),
                  _cell('ESTADO', bold: true),
                  _cell('IMPORTE', bold: true, alignRight: true),
                ],
              ),
              for (final item in receipt.applications)
                pw.TableRow(
                  children: [
                    _cell('COMISIÓN'),
                    _cell(
                      item.periodStart == null || item.periodEnd == null
                          ? item.installmentId
                          : '${DateFormat('dd/MM/yyyy').format(item.periodStart!.toUtc())} - ${DateFormat('dd/MM/yyyy').format(item.periodEnd!.toUtc())}',
                    ),
                    _cell(item.status),
                    _cell(money.format(item.amount), alignRight: true),
                  ],
                ),
              for (final item in receipt.fixedApplications)
                pw.TableRow(
                  children: [
                    _cell('FIJO'),
                    _cell(
                      item.periodStart == null || item.periodEnd == null
                          ? item.obligationId
                          : '${DateFormat('dd/MM/yyyy').format(item.periodStart!.toUtc())} - ${DateFormat('dd/MM/yyyy').format(item.periodEnd!.toUtc())}',
                    ),
                    _cell(item.status),
                    _cell(money.format(item.amount), alignRight: true),
                  ],
                ),
            ],
          ),
          if (receipt.reversal != null) ...[
            pw.SizedBox(height: 22),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: accent),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CONTRAMOVIMIENTO REGISTRADO',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: accent,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    receipt.reversal!.reason,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
          pw.SizedBox(height: 22),
          pw.Text(
            'Documento operativo emitido por GymOS. Los importes conservan su moneda original.',
            style: const pw.TextStyle(fontSize: 8, color: muted),
          ),
        ],
      ),
    );
    return document.save();
  }
}

pw.Widget _cell(String value, {bool bold = false, bool alignRight = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    child: pw.Text(
      value,
      textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}
