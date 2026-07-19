import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../models/operational_results_models.dart';

class OperationalResultsReportSnapshot {
  const OperationalResultsReportSnapshot({
    required this.result,
    required this.currencies,
    required this.generatedAtUtc,
    required this.generatedAtLocal,
    required this.timezone,
    required this.scope,
  });

  final OperationalResultsModel result;
  final List<OperationalResultsCurrencyModel> currencies;
  final DateTime generatedAtUtc;
  final String generatedAtLocal;
  final String timezone;
  final String scope;

  Map<String, dynamic> toJson() => {
    'month': result.month,
    'period_state': result.periodState,
    'certified': result.certified,
    'certification_note': result.certificationNote,
    'generated_at_utc': generatedAtUtc.toIso8601String(),
    'generated_at_local': generatedAtLocal,
    'timezone': timezone,
    'scope': scope,
    'close': _closeToJson(result.monthlyClose),
    'currencies': currencies.map(_currencyToJson).toList(growable: false),
    'limitations': result.limitations,
  };
}

class OperationalResultsReportService {
  const OperationalResultsReportService();

  OperationalResultsReportSnapshot snapshot({
    required OperationalResultsModel result,
    required bool allCurrencies,
    required String selectedCurrencyId,
    DateTime? generatedAtUtc,
    String? timezone,
  }) {
    final currencies = allCurrencies
        ? result.currencies
        : result.currencies
              .where((item) => item.currencyId == selectedCurrencyId)
              .toList(growable: false);
    if (currencies.isEmpty) {
      throw StateError('El alcance elegido no contiene datos exportables.');
    }
    final generated = (generatedAtUtc ?? appClock.nowUtc()).toUtc();
    final gymTimezone =
        timezone ?? result.monthlyClose?.timezone ?? appClock.gymTimezone;
    return OperationalResultsReportSnapshot(
      result: result,
      currencies: currencies,
      generatedAtUtc: generated,
      generatedAtLocal: formatDateInZone(
        generated,
        gymTimezone,
        pattern: 'dd/MM/yyyy HH:mm',
      ),
      timezone: gymTimezone,
      scope: allCurrencies
          ? 'Todas las monedas, cada una en su propia sección'
          : 'Moneda ${currencies.single.currencyCode}',
    );
  }

  Future<Uint8List> buildPdf(OperationalResultsReportSnapshot snapshot) async {
    final regular = await rootBundle.load(
      'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
    );
    final bold = await rootBundle.load(
      'assets/fonts/AtkinsonHyperlegible-Bold.ttf',
    );
    final mono = await rootBundle.load('assets/fonts/IBMPlexMono-Regular.ttf');
    return compute(_renderOperationalResultsPdf, {
      'snapshot': snapshot.toJson(),
      'regular_font': _fontBytes(regular),
      'bold_font': _fontBytes(bold),
      'mono_font': _fontBytes(mono),
    });
  }

  Uint8List buildCsv(OperationalResultsReportSnapshot snapshot) {
    final close = snapshot.result.monthlyClose;
    final rows = <List<String>>[
      const [
        'tipo_fila',
        'mes',
        'moneda',
        'entidad_id',
        'nombre',
        'estado',
        'entradas',
        'salidas',
        'efecto_flujo',
        'ganado_pendiente',
        'pagadero_ahora',
        'futuro',
        'reembolso_pendiente',
        'reserva_inmediata',
        'compromiso_total',
        'movimientos_o_conceptos',
        'requiere_revision',
        'fecha',
        'alcance',
        'zona_horaria',
        'generado_at_utc',
        'certificado',
        'cierre_mensual_id',
        'resumen_sha256',
        'integridad_verificada',
      ],
    ];
    List<String> tail() => [
      snapshot.scope,
      snapshot.timezone,
      snapshot.generatedAtUtc.toIso8601String(),
      snapshot.result.certified ? 'SI' : 'NO',
      close?.id ?? '',
      close?.sha256 ?? '',
      close?.integrityVerified == true ? 'SI' : 'NO',
    ];

    for (final currency in snapshot.currencies) {
      final obligations = currency.obligations;
      rows.add([
        'MONEDA',
        snapshot.result.month,
        currency.currencyCode,
        currency.currencyId,
        currency.currencyCode,
        currency.requiresAttention ? 'REQUIERE_REVISION' : 'REVISADO',
        currency.cash.ledgerEntries,
        currency.cash.ledgerExits,
        currency.cash.operationalFlow,
        obligations.trainerEarnedPending ?? '',
        obligations.trainerPayableNow ?? '',
        obligations.trainerFuture ?? '',
        obligations.refundsPending ?? '',
        obligations.immediateReserve ?? '',
        obligations.totalCommitment ?? '',
        '${currency.concepts.length}',
        currency.requiresAttention ? 'SI' : 'NO',
        obligations.cutoffDate ?? '',
        ...tail(),
      ]);
      for (final concept in currency.concepts) {
        rows.add([
          'CONCEPTO',
          snapshot.result.month,
          currency.currencyCode,
          concept.category,
          concept.label,
          concept.scope,
          concept.entries,
          concept.exits,
          concept.cashEffect,
          '',
          '',
          '',
          '',
          '',
          '',
          '${concept.movementCount}',
          concept.requiresReview ? 'SI' : 'NO',
          '',
          ...tail(),
        ]);
      }
      for (final account in currency.accounts) {
        rows.add([
          'CUENTA',
          snapshot.result.month,
          currency.currencyCode,
          account.id ?? '',
          account.name,
          account.requiresReview ? 'REQUIERE_REVISION' : 'REVISADA',
          account.entries,
          account.exits,
          account.operationalFlow,
          '',
          '',
          '',
          '',
          '',
          '',
          '${account.movementCount}',
          account.requiresReview ? 'SI' : 'NO',
          '',
          ...tail(),
        ]);
      }
      for (final trainer in obligations.trainers) {
        rows.add([
          'ENTRENADOR',
          snapshot.result.month,
          currency.currencyCode,
          trainer.trainerId,
          trainer.trainerName,
          trainer.requiresReview ? 'REQUIERE_REVISION' : 'PENDIENTE',
          '',
          '',
          '',
          trainer.earnedPending,
          trainer.payableNow,
          trainer.future,
          '',
          '',
          '',
          '${trainer.conceptCount}',
          trainer.requiresReview ? 'SI' : 'NO',
          trainer.nextPaymentDate ?? '',
          ...tail(),
        ]);
      }
      for (final refund in obligations.refunds) {
        rows.add([
          'REEMBOLSO',
          snapshot.result.month,
          currency.currencyCode,
          refund.adjustmentId,
          '${refund.clientName} (${refund.clientId})',
          'PENDIENTE',
          '',
          '',
          '',
          '',
          '',
          '',
          refund.amount,
          '',
          '',
          '1',
          'NO',
          refund.requestedAt?.toIso8601String() ?? '',
          ...tail(),
        ]);
      }
    }
    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
    return Uint8List.fromList([0xef, 0xbb, 0xbf, ...utf8.encode(csv)]);
  }

  Future<String?> savePdf(OperationalResultsReportSnapshot snapshot) async {
    return FilePicker.platform.saveFile(
      dialogTitle: 'Guardar Resultado de caja en PDF',
      fileName: _fileName(snapshot, 'pdf'),
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: await buildPdf(snapshot),
      lockParentWindow: true,
    );
  }

  Future<String?> saveCsv(OperationalResultsReportSnapshot snapshot) {
    return FilePicker.platform.saveFile(
      dialogTitle: 'Guardar Resultado de caja en CSV',
      fileName: _fileName(snapshot, 'csv'),
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      bytes: buildCsv(snapshot),
      lockParentWindow: true,
    );
  }

  Future<bool> printPdf(OperationalResultsReportSnapshot snapshot) async {
    final bytes = await buildPdf(snapshot);
    return Printing.layoutPdf(
      name: _fileName(snapshot, 'pdf'),
      format: PdfPageFormat.a4.landscape,
      dynamicLayout: false,
      onLayout: (_) async => bytes,
    );
  }

  static Uint8List _fontBytes(ByteData data) =>
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

  String _fileName(
    OperationalResultsReportSnapshot snapshot,
    String extension,
  ) {
    final scope = snapshot.currencies.length == 1
        ? snapshot.currencies.single.currencyCode.toLowerCase()
        : 'multimoneda';
    final status = snapshot.result.certified ? 'certificado' : 'borrador';
    return 'resultado-caja-${snapshot.result.month}-$scope-$status.$extension';
  }
}

Map<String, dynamic> _closeToJson(OperationalMonthlyCloseModel? close) => {
  'id': close?.id,
  'state': close?.state,
  'sha256': close?.sha256,
  'integrity_verified': close?.integrityVerified ?? false,
  'snapshot_version': close?.snapshotVersion ?? 0,
  'signer_name': close?.signerName,
  'signer_role': close?.signerRole,
  'reason': close?.reason,
  'timezone': close?.timezone,
  'closed_at': close?.closedAt?.toIso8601String(),
};

Map<String, dynamic> _currencyToJson(
  OperationalResultsCurrencyModel currency,
) => {
  'id': currency.currencyId,
  'code': currency.currencyCode,
  'requires_attention': currency.requiresAttention,
  'cash': {
    'gross_collections': currency.cash.grossCollections,
    'ledger_exits': currency.cash.ledgerExits,
    'operational_flow': currency.cash.operationalFlow,
    'ledger_net': currency.cash.ledgerNet,
    'trainer_payments': currency.cash.trainerPaymentsNet,
    'refunds': currency.cash.refundsNet,
  },
  'obligations': {
    'available': currency.obligations.available,
    'cutoff_date': currency.obligations.cutoffDate,
    'earned_pending': currency.obligations.trainerEarnedPending,
    'payable_now': currency.obligations.trainerPayableNow,
    'future': currency.obligations.trainerFuture,
    'refunds_pending': currency.obligations.refundsPending,
    'immediate_reserve': currency.obligations.immediateReserve,
    'total_commitment': currency.obligations.totalCommitment,
    'trainers': currency.obligations.trainers
        .map(
          (item) => {
            'id': item.trainerId,
            'name': item.trainerName,
            'earned_pending': item.earnedPending,
            'payable_now': item.payableNow,
            'future': item.future,
            'concept_count': item.conceptCount,
            'next_payment_date': item.nextPaymentDate,
            'requires_review': item.requiresReview,
          },
        )
        .toList(growable: false),
    'refunds': currency.obligations.refunds
        .map(
          (item) => {
            'id': item.adjustmentId,
            'client_id': item.clientId,
            'client_name': item.clientName,
            'amount': item.amount,
            'requested_at': item.requestedAt?.toIso8601String(),
          },
        )
        .toList(growable: false),
  },
  'concepts': currency.concepts
      .map(
        (item) => {
          'id': item.category,
          'label': item.label,
          'scope': item.scope,
          'entries': item.entries,
          'exits': item.exits,
          'effect': item.cashEffect,
          'movement_count': item.movementCount,
          'requires_review': item.requiresReview,
        },
      )
      .toList(growable: false),
  'accounts': currency.accounts
      .map(
        (item) => {
          'id': item.id,
          'name': item.name,
          'entries': item.entries,
          'exits': item.exits,
          'ledger_net': item.ledgerNet,
          'operational_flow': item.operationalFlow,
          'movement_count': item.movementCount,
          'requires_review': item.requiresReview,
        },
      )
      .toList(growable: false),
};

String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

Future<Uint8List> _renderOperationalResultsPdf(
  Map<String, dynamic> payload,
) async {
  final snapshot = Map<String, dynamic>.from(payload['snapshot'] as Map);
  final regular = pw.Font.ttf(
    ByteData.sublistView(payload['regular_font'] as Uint8List),
  );
  final bold = pw.Font.ttf(
    ByteData.sublistView(payload['bold_font'] as Uint8List),
  );
  final mono = pw.Font.ttf(
    ByteData.sublistView(payload['mono_font'] as Uint8List),
  );
  const ink = PdfColor.fromInt(0xff24211d);
  const muted = PdfColor.fromInt(0xff706a61);
  const line = PdfColor.fromInt(0xffd7cfc3);
  const paper = PdfColor.fromInt(0xfff3ede5);
  const accent = PdfColor.fromInt(0xffd94a24);
  const success = PdfColor.fromInt(0xff2f7654);
  const warning = PdfColor.fromInt(0xff9a6a12);
  final document = pw.Document(
    title: 'Resultado operativo de caja ${snapshot['month']}',
    author: 'GymOS',
    subject: 'Flujo de caja, reservas y trazabilidad por moneda',
  );
  final currencies = (snapshot['currencies'] as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList(growable: false);
  final close = Map<String, dynamic>.from(snapshot['close'] as Map);
  final certified =
      snapshot['certified'] == true &&
      close['integrity_verified'] == true &&
      (close['snapshot_version'] as num? ?? 0) >= 2;

  pw.TextStyle style({
    double size = 7,
    PdfColor color = ink,
    bool strong = false,
    bool monospace = false,
  }) => pw.TextStyle(
    font: monospace ? mono : (strong ? bold : regular),
    fontSize: size,
    color: color,
  );

  pw.Widget metric(String label, String value, {bool highlight = false}) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: line),
              bottom: pw.BorderSide(color: line),
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label.toUpperCase(), style: style(size: 6, color: muted)),
              pw.SizedBox(height: 3),
              pw.Text(
                value,
                style: style(
                  size: highlight ? 12 : 10,
                  color: highlight ? accent : ink,
                  strong: true,
                  monospace: true,
                ),
              ),
            ],
          ),
        ),
      );

  pw.Widget table({
    required List<String> headers,
    required List<List<String>> rows,
    Map<int, pw.TableColumnWidth>? widths,
  }) => pw.Table(
    border: const pw.TableBorder(
      top: pw.BorderSide(color: line),
      bottom: pw.BorderSide(color: line),
      horizontalInside: pw.BorderSide(color: line),
    ),
    columnWidths: widths,
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: paper),
        children: headers
            .map(
              (value) => pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(value, style: style(size: 6, strong: true)),
              ),
            )
            .toList(growable: false),
      ),
      for (final row in rows)
        pw.TableRow(
          children: row
              .map(
                (value) => pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(value, style: style(size: 6)),
                ),
              )
              .toList(growable: false),
        ),
    ],
  );

  final content = <pw.Widget>[
    pw.Container(height: 3, color: ink),
    pw.SizedBox(height: 12),
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('GYMOS - DIRECCION FINANCIERA', style: style(color: muted)),
            pw.SizedBox(height: 4),
            pw.Text('RESULTADO DE CAJA', style: style(size: 22, strong: true)),
            pw.Text(
              '${snapshot['month']} - ${snapshot['scope']}',
              style: style(size: 8, color: muted, monospace: true),
            ),
          ],
        ),
        pw.Container(
          width: 300,
          padding: const pw.EdgeInsets.all(9),
          color: certified
              ? const PdfColor.fromInt(0xffe5f1e9)
              : const PdfColor.fromInt(0xfffff3da),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                certified ? 'CORTE CERTIFICADO' : 'BORRADOR OPERATIVO',
                style: style(
                  size: 8,
                  strong: true,
                  color: certified ? success : warning,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                certified
                    ? 'Firmó ${close['signer_name']} (${close['signer_role']}) - SHA-256 verificado'
                    : snapshot['certification_note'].toString(),
                style: style(size: 6.5, color: muted),
              ),
              if (certified) ...[
                pw.SizedBox(height: 3),
                pw.Text(
                  'ID: ${close['id']}',
                  style: style(size: 6, monospace: true),
                ),
                pw.Text(
                  'Motivo: ${close['reason']}',
                  maxLines: 2,
                  style: style(size: 6),
                ),
                pw.Text(
                  'SHA-256: ${close['sha256']}',
                  style: style(size: 5.5, monospace: true),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  ];

  for (var index = 0; index < currencies.length; index++) {
    if (index > 0) content.add(pw.NewPage());
    final currency = currencies[index];
    final code = currency['code'].toString();
    final cash = Map<String, dynamic>.from(currency['cash'] as Map);
    final obligations = Map<String, dynamic>.from(
      currency['obligations'] as Map,
    );
    final concepts = (currency['concepts'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
    final accounts = (currency['accounts'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
    final trainers = (obligations['trainers'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
    final refunds = (obligations['refunds'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
    content.addAll([
      pw.SizedBox(height: 14),
      pw.Container(
        color: ink,
        padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '$code - CAJA Y RESERVAS',
              style: style(color: PdfColors.white, strong: true),
            ),
            pw.Text(
              currency['requires_attention'] == true
                  ? 'REQUIERE REVISION'
                  : 'REVISADO',
              style: style(color: PdfColors.white, strong: true),
            ),
          ],
        ),
      ),
      pw.Row(
        children: [
          metric(
            'Cobrado',
            '$code ${_moneyText(cash['gross_collections'])}',
            highlight: true,
          ),
          metric(
            'Salió del libro',
            '$code ${_moneyText(cash['ledger_exits'])}',
          ),
          metric(
            'Flujo operativo',
            '$code ${_moneyText(cash['operational_flow'])}',
          ),
          metric('Neto del libro', '$code ${_moneyText(cash['ledger_net'])}'),
        ],
      ),
      pw.Row(
        children: [
          metric(
            'Reserva inmediata',
            '$code ${_moneyText(obligations['immediate_reserve'])}',
            highlight: true,
          ),
          metric(
            'Pagadero ahora',
            '$code ${_moneyText(obligations['payable_now'])}',
          ),
          metric('Fondo futuro', '$code ${_moneyText(obligations['future'])}'),
          metric(
            'Devoluciones',
            '$code ${_moneyText(obligations['refunds_pending'])}',
          ),
        ],
      ),
      pw.SizedBox(height: 9),
      pw.Text('CONCEPTOS', style: style(size: 7, strong: true, color: muted)),
      pw.SizedBox(height: 4),
      table(
        headers: const [
          'CONCEPTO',
          'AMBITO',
          'ENTRADAS',
          'SALIDAS',
          'EFECTO',
          'MOV.',
        ],
        widths: const {0: pw.FlexColumnWidth(2.5)},
        rows: concepts
            .map(
              (row) => [
                row['label'].toString(),
                row['scope'].toString(),
                _moneyText(row['entries']),
                _moneyText(row['exits']),
                _moneyText(row['effect']),
                row['movement_count'].toString(),
              ],
            )
            .toList(growable: false),
      ),
      pw.SizedBox(height: 9),
      pw.Text('CUENTAS', style: style(size: 7, strong: true, color: muted)),
      pw.SizedBox(height: 4),
      table(
        headers: const [
          'CUENTA',
          'ENTRADAS',
          'SALIDAS',
          'NETO LIBRO',
          'FLUJO',
          'MOV.',
          'ESTADO',
        ],
        widths: const {0: pw.FlexColumnWidth(2.5)},
        rows: accounts
            .map(
              (row) => [
                row['name'].toString(),
                _moneyText(row['entries']),
                _moneyText(row['exits']),
                _moneyText(row['ledger_net']),
                _moneyText(row['operational_flow']),
                row['movement_count'].toString(),
                row['requires_review'] == true ? 'REVISAR' : 'REVISADA',
              ],
            )
            .toList(growable: false),
      ),
    ]);
    if (trainers.isNotEmpty) {
      content.addAll([
        pw.SizedBox(height: 9),
        pw.Text(
          'OBLIGACIONES POR ENTRENADOR',
          style: style(size: 7, strong: true, color: muted),
        ),
        pw.SizedBox(height: 4),
        table(
          headers: const [
            'ENTRENADOR',
            'GANADO',
            'PAGADERO',
            'FUTURO',
            'CONCEPTOS',
            'PROX. FECHA',
          ],
          widths: const {0: pw.FlexColumnWidth(2.5)},
          rows: trainers
              .map(
                (row) => [
                  row['name'].toString(),
                  _moneyText(row['earned_pending']),
                  _moneyText(row['payable_now']),
                  _moneyText(row['future']),
                  row['concept_count'].toString(),
                  row['next_payment_date']?.toString() ?? '',
                ],
              )
              .toList(growable: false),
        ),
      ]);
    }
    if (refunds.isNotEmpty) {
      content.addAll([
        pw.SizedBox(height: 9),
        pw.Text(
          'DEVOLUCIONES PENDIENTES',
          style: style(size: 7, strong: true, color: muted),
        ),
        pw.SizedBox(height: 4),
        table(
          headers: const ['CLIENTE', 'CI', 'IMPORTE', 'SOLICITADA'],
          widths: const {0: pw.FlexColumnWidth(2.5)},
          rows: refunds
              .map(
                (row) => [
                  row['client_name'].toString(),
                  row['client_id'].toString(),
                  _moneyText(row['amount']),
                  (row['requested_at']?.toString() ?? '').split('T').first,
                ],
              )
              .toList(growable: false),
        ),
      ]);
    }
  }

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(28, 25, 28, 25),
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        fontFallback: [regular],
      ),
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 5),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: line)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'GymOS - ${snapshot['month']} - ${snapshot['timezone']} - emitido ${snapshot['generated_at_local']}',
              style: style(size: 6, color: muted),
            ),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: style(size: 6, color: muted, monospace: true),
            ),
          ],
        ),
      ),
      build: (_) => content,
    ),
  );
  return document.save();
}

String _moneyText(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return '-';
  final negative = raw.startsWith('-');
  final clean = negative ? raw.substring(1) : raw;
  final parts = clean.split('.');
  var whole = parts.first.replaceAll(RegExp(r'[^0-9]'), '');
  if (whole.isEmpty) whole = '0';
  final fraction = parts.length > 1
      ? parts[1].padRight(2, '0').substring(0, 2)
      : '00';
  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${negative ? '-' : ''}$grouped.$fraction';
}
