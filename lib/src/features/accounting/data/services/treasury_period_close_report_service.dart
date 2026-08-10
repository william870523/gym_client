import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/utils/datetime_zone.dart';
import '../models/treasury_period_models.dart';

class TreasuryPeriodCloseReportService {
  const TreasuryPeriodCloseReportService();

  Uint8List buildCsv(
    TreasuryPeriodSummaryModel summary, {
    List<String>? currencyIds,
  }) {
    final selected = currencyIds?.toSet();
    final currencies = {for (final item in summary.currencies) item.id: item};
    final accounts = {
      for (final currency in summary.currencies)
        for (final account in currency.accounts) account.id: account,
    };
    final days = {for (final item in summary.days) item.businessDate: item};
    final rows = <List<String>>[
      const [
        'periodo_desde',
        'periodo_hasta',
        'tipo_periodo',
        'dia_negocio',
        'cuenta',
        'moneda',
        'cliente',
        'plan',
        'cuota',
        'metodo_id',
        'bruto',
        'cambio',
        'anulacion',
        'neto',
        'cobrador',
        'anulador',
        'cierre_diario_ids',
        'movimiento_id',
        'sha256',
      ],
    ];
    for (final payment in summary.payments) {
      final instant = tryParseUtc(payment.occurredAtUtc);
      final day = instant == null
          ? ''
          : formatDateInZone(instant, summary.timezone);
      for (final detail in payment.details) {
        if (selected != null && !selected.contains(detail.currencyId)) continue;
        final gross = detail.originType == 'PAGO_CLIENTE' ? detail.amount : 0.0;
        final change = detail.originType == 'PAGO_CAMBIO' ? detail.amount : 0.0;
        final annulled = detail.originType == 'PAGO_REVERSION'
            ? detail.amount
            : 0.0;
        rows.add([
          summary.from,
          summary.to,
          summary.type,
          day,
          accounts[detail.accountId]?.name ?? detail.accountId,
          currencies[detail.currencyId]?.code ?? detail.currencyId,
          payment.clientId,
          payment.planCode ?? '',
          payment.installment ?? '',
          detail.paymentTypeId,
          _number(gross),
          _number(change),
          _number(annulled),
          _number(gross - change - annulled),
          payment.collectorName,
          payment.annulledBy ?? '',
          days[day]?.closeIds.join('|') ?? '',
          detail.id,
          summary.activeCycle?.hash ?? '',
        ]);
      }
    }
    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
    return Uint8List.fromList([0xef, 0xbb, 0xbf, ...utf8.encode(csv)]);
  }

  Future<Uint8List> buildPdf(
    TreasuryPeriodSummaryModel summary, {
    List<String>? currencyIds,
  }) async {
    final selected = currencyIds == null
        ? summary.currencies
        : summary.currencies
              .where((item) => currencyIds.contains(item.id))
              .toList(growable: false);
    final document = pw.Document(
      title: 'Cierre por período ${summary.from} ${summary.to}',
      author: 'GymOS',
      subject: 'Certificado contable de Tesorería',
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
          ),
        ),
        build: (_) => [
          _brandHeading(),
          pw.SizedBox(height: 18),
          pw.Text(
            'Certificado de cierre por período',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '${summary.from} - ${summary.to} · ${summary.dayCount} días comerciales · ${summary.type}',
            style: const pw.TextStyle(fontSize: 13),
          ),
          pw.Text('Zona de negocio: ${summary.timezone}'),
          pw.SizedBox(height: 14),
          _certificate(summary),
          pw.SizedBox(height: 14),
          if (summary.blockers.isNotEmpty) ...[
            pw.Text(
              'Incidencias',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Wrap(
              spacing: 12,
              children: [
                for (final item in summary.blockers)
                  pw.Text('${item.code}: ${item.count}'),
              ],
            ),
            pw.SizedBox(height: 14),
          ],
          for (var index = 0; index < selected.length; index++) ...[
            if (index > 0) pw.NewPage(),
            if (index > 0) _brandHeading(),
            if (index > 0) pw.SizedBox(height: 20),
            _currency(selected[index]),
            pw.SizedBox(height: 14),
          ],
          pw.NewPage(),
          _brandHeading(),
          pw.SizedBox(height: 20),
          pw.Text(
            'Detalle auditable',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Cliente',
              'Fecha UTC',
              'Cobrador',
              'Anulador',
              'Movimientos',
            ],
            data: [
              for (final payment in summary.payments.where(
                (payment) => payment.details.any(
                  (row) => selected.any((item) => item.id == row.currencyId),
                ),
              ))
                [
                  payment.clientId,
                  payment.occurredAtUtc,
                  payment.collectorName,
                  payment.annulledBy ?? '-',
                  payment.details
                      .where(
                        (row) =>
                            selected.any((item) => item.id == row.currencyId),
                      )
                      .map(
                        (row) =>
                            '${row.direction} ${_number(row.amount)} (${row.id})',
                      )
                      .join('\n'),
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Documento de control auditable. Las monedas se presentan por separado y nunca se suman entre sí.',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<String?> savePdf(
    TreasuryPeriodSummaryModel summary, {
    List<String>? currencyIds,
  }) async => FilePicker.platform.saveFile(
    dialogTitle: 'Guardar cierre por período en PDF',
    fileName: _fileName(summary, 'pdf'),
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
    bytes: await buildPdf(summary, currencyIds: currencyIds),
    lockParentWindow: true,
  );

  Future<String?> saveCsv(
    TreasuryPeriodSummaryModel summary, {
    List<String>? currencyIds,
  }) => FilePicker.platform.saveFile(
    dialogTitle: 'Guardar cierre por período en CSV',
    fileName: _fileName(summary, 'csv'),
    type: FileType.custom,
    allowedExtensions: const ['csv'],
    bytes: buildCsv(summary, currencyIds: currencyIds),
    lockParentWindow: true,
  );

  Future<bool> printPdf(
    TreasuryPeriodSummaryModel summary, {
    List<String>? currencyIds,
  }) async {
    final bytes = await buildPdf(summary, currencyIds: currencyIds);
    return Printing.layoutPdf(
      name: _fileName(summary, 'pdf'),
      format: PdfPageFormat.a4.landscape,
      dynamicLayout: false,
      onLayout: (_) async => bytes,
    );
  }

  pw.Widget _certificate(TreasuryPeriodSummaryModel summary) {
    final cycle = summary.activeCycle;
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Estado: ${summary.closeState}'),
          if (cycle == null)
            pw.Text('Borrador vivo: las cifras pueden cambiar hasta la firma.')
          else ...[
            pw.Text(
              'Ciclo ${cycle.cycleNumber} · ${cycle.integrityState} · firmado por ${cycle.closerName} (${cycle.closerRole})',
            ),
            pw.Text('Motivo: ${cycle.closeReason}'),
            pw.Text('SHA-256: ${cycle.hash}'),
          ],
        ],
      ),
    );
  }

  pw.Widget _brandHeading() => pw.Text(
    'GYMOS · TESORERÍA',
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  );

  pw.Widget _currency(TreasuryPeriodCurrencyModel currency) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        currency.code,
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      ),
      pw.TableHelper.fromTextArray(
        headers: const [
          'Bruto',
          'Cambio',
          'Anulaciones',
          'Cobro neto',
          'Flujo neto',
          'Cobros',
          'Clientes',
          'Cobertura',
        ],
        data: [
          [
            _number(currency.gross),
            _number(currency.change),
            _number(currency.annulled),
            _number(currency.netCollected),
            _number(currency.netFlow),
            '${currency.paymentCount}',
            '${currency.clientCount}',
            '${currency.coverage.toStringAsFixed(0)}%',
          ],
        ],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 9),
      ),
      pw.SizedBox(height: 6),
      pw.Text('Cobros por recepcionista'),
      pw.TableHelper.fromTextArray(
        headers: const [
          'Nombre',
          'Cobros',
          'Clientes',
          'Bruto',
          'Cambio',
          'Anulado',
          'Neto',
        ],
        data: [
          for (final row in currency.collectors)
            [
              row.name,
              '${row.paymentCount}',
              '${row.clientCount}',
              _number(row.gross),
              _number(row.change),
              _number(row.annulled),
              _number(row.net),
            ],
        ],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 8),
      ),
      pw.SizedBox(height: 6),
      pw.Text('Cobertura de cuentas/días'),
      pw.TableHelper.fromTextArray(
        headers: const [
          'Cuenta',
          'Días cerrados',
          'Días actividad',
          'Entradas',
          'Salidas',
          'Neto',
        ],
        data: [
          for (final row in currency.accounts)
            [
              row.name,
              '${row.closedDays}',
              '${row.activityDays}',
              _number(row.entries),
              _number(row.exits),
              _number(row.net),
            ],
        ],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 8),
      ),
    ],
  );

  String _fileName(TreasuryPeriodSummaryModel summary, String extension) =>
      'tesoreria-periodo-${summary.from}-${summary.to}.$extension';

  String _number(double value) => value.toStringAsFixed(2);

  String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';
}
