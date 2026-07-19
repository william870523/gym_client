import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/utils/datetime_zone.dart';
import '../models/client_record_model.dart';

class ClientStatementSnapshot {
  const ClientStatementSnapshot({
    required this.clientName,
    required this.clientId,
    required this.timezone,
    required this.generatedAt,
    required this.scope,
    required this.memberships,
    required this.payments,
    required this.totals,
  });

  final String clientName;
  final String clientId;
  final String timezone;
  final String generatedAt;
  final String scope;
  final List<ClientStatementMembership> memberships;
  final List<ClientStatementPayment> payments;
  final List<ClientStatementTotal> totals;

  factory ClientStatementSnapshot.fromRecord({
    required ClientRecordModel record,
    required List<ClientMembershipRecord> memberships,
    required String timezone,
    required DateTime generatedAtUtc,
    required String scope,
  }) {
    final paymentRows = <ClientStatementPayment>[];
    final statementMemberships = <ClientStatementMembership>[];

    for (final membership in memberships) {
      final trainers = membership.trainers
          .map((item) => item.trainerName ?? item.trainerId)
          .toSet()
          .join(' -> ');
      statementMemberships.add(
        ClientStatementMembership(
          id: membership.id,
          plan: membership.planName,
          period:
              '${_contractDate(membership.startDate)} - '
              '${_contractDate(membership.endDate)}',
          status: membership.status.replaceAll('_', ' '),
          origin: membership.origin.replaceAll('_', ' '),
          trainer: trainers.isEmpty ? '-' : trainers,
          contracted:
              '${membership.price.toStringAsFixed(2)} '
              '${membership.currencyCode ?? membership.currencyId}',
          paid:
              '${membership.paidAmount.toStringAsFixed(2)} '
              '${membership.currencyCode ?? membership.currencyId}',
          pauseSummary: membership.pauses.map(_pauseSummary).join('\n'),
          requestSummary: membership.requests.map(_requestSummary).join('\n'),
        ),
      );
      for (final payment in membership.payments) {
        paymentRows.add(
          ClientStatementPayment.fromRecord(
            payment,
            timezone: timezone,
            membershipId: membership.id,
            plan: membership.planName,
            membershipStatus: membership.status,
          ),
        );
      }
    }
    for (final payment in record.unlinkedPayments) {
      paymentRows.add(
        ClientStatementPayment.fromRecord(
          payment,
          timezone: timezone,
          membershipId: null,
          plan: 'Pago histórico sin membresía',
          membershipStatus: null,
        ),
      );
    }
    paymentRows.sort((a, b) => b.utcDate.compareTo(a.utcDate));

    final totals = <String, double>{};
    final paymentCount = <String, int>{};
    final seen = <String>{};
    for (final payment in paymentRows) {
      if (payment.voided || !seen.add(payment.id)) continue;
      totals.update(
        payment.currency,
        (value) => value + payment.total,
        ifAbsent: () => payment.total,
      );
      paymentCount.update(
        payment.currency,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    return ClientStatementSnapshot(
      clientName: record.client.fullName,
      clientId: record.client.id,
      timezone: timezone,
      generatedAt: DateFormat(
        'dd/MM/yyyy HH:mm',
      ).format(toGymWallClock(generatedAtUtc, timezone)),
      scope: scope,
      memberships: statementMemberships,
      payments: paymentRows,
      totals: [
        for (final entry in totals.entries)
          ClientStatementTotal(
            currency: entry.key,
            amount: entry.value,
            paymentCount: paymentCount[entry.key] ?? 0,
          ),
      ]..sort((a, b) => a.currency.compareTo(b.currency)),
    );
  }

  Map<String, dynamic> toJson() => {
    'client_name': clientName,
    'client_id': clientId,
    'timezone': timezone,
    'generated_at': generatedAt,
    'scope': scope,
    'memberships': memberships.map((item) => item.toJson()).toList(),
    'payments': payments.map((item) => item.toJson()).toList(),
    'totals': totals.map((item) => item.toJson()).toList(),
  };
}

class ClientStatementMembership {
  const ClientStatementMembership({
    required this.id,
    required this.plan,
    required this.period,
    required this.status,
    required this.origin,
    required this.trainer,
    required this.contracted,
    required this.paid,
    required this.pauseSummary,
    required this.requestSummary,
  });

  final String id;
  final String plan;
  final String period;
  final String status;
  final String origin;
  final String trainer;
  final String contracted;
  final String paid;
  final String pauseSummary;
  final String requestSummary;

  Map<String, dynamic> toJson() => {
    'id': id,
    'plan': plan,
    'period': period,
    'status': status,
    'origin': origin,
    'trainer': trainer,
    'contracted': contracted,
    'paid': paid,
    'pause_summary': pauseSummary,
    'request_summary': requestSummary,
  };
}

class ClientStatementPayment {
  const ClientStatementPayment({
    required this.id,
    required this.utcDate,
    required this.localDate,
    required this.membershipId,
    required this.plan,
    required this.membershipStatus,
    required this.voided,
    required this.currency,
    required this.total,
    required this.applied,
    required this.methods,
    required this.details,
  });

  final String id;
  final DateTime utcDate;
  final String localDate;
  final String? membershipId;
  final String plan;
  final String? membershipStatus;
  final bool voided;
  final String currency;
  final double total;
  final double? applied;
  final String methods;
  final List<ClientStatementPaymentDetail> details;

  factory ClientStatementPayment.fromRecord(
    ClientRecordPayment payment, {
    required String timezone,
    required String? membershipId,
    required String plan,
    required String? membershipStatus,
  }) {
    final methods = payment.details
        .map((item) => item.paymentTypeName ?? 'Sin clasificar')
        .toSet()
        .join(' + ');
    return ClientStatementPayment(
      id: payment.id,
      utcDate: payment.date,
      localDate: DateFormat(
        'dd/MM/yyyy HH:mm',
      ).format(toGymWallClock(payment.date, timezone)),
      membershipId: membershipId,
      plan: plan,
      membershipStatus: membershipStatus,
      voided: payment.isVoided,
      currency: payment.currencyCode ?? payment.currencyId,
      total: payment.total,
      applied: payment.appliedAmount,
      methods: methods.isEmpty ? 'Sin detalle' : methods,
      details: payment.details
          .map(ClientStatementPaymentDetail.fromRecord)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'utc_date': utcDate.toUtc().toIso8601String(),
    'local_date': localDate,
    'membership_id': membershipId,
    'plan': plan,
    'membership_status': membershipStatus,
    'voided': voided,
    'currency': currency,
    'total': total,
    'applied': applied,
    'methods': methods,
    'details': details.map((item) => item.toJson()).toList(),
  };
}

class ClientStatementPaymentDetail {
  const ClientStatementPaymentDetail({
    required this.method,
    required this.account,
    required this.currency,
    required this.amount,
    required this.rate,
  });

  final String method;
  final String account;
  final String currency;
  final double amount;
  final String rate;

  factory ClientStatementPaymentDetail.fromRecord(
    ClientRecordPaymentDetail detail,
  ) => ClientStatementPaymentDetail(
    method: detail.paymentTypeName ?? 'Sin clasificar',
    account: detail.accountName ?? 'Sin cuenta',
    currency: detail.currencyCode ?? detail.currencyId,
    amount: detail.amount,
    rate: detail.exchangeRate == null
        ? '1:1'
        : detail.exchangeRate!.toStringAsFixed(4),
  );

  Map<String, dynamic> toJson() => {
    'method': method,
    'account': account,
    'currency': currency,
    'amount': amount,
    'rate': rate,
  };
}

class ClientStatementTotal {
  const ClientStatementTotal({
    required this.currency,
    required this.amount,
    required this.paymentCount,
  });

  final String currency;
  final double amount;
  final int paymentCount;

  Map<String, dynamic> toJson() => {
    'currency': currency,
    'amount': amount,
    'payment_count': paymentCount,
  };
}

class ClientStatementExportService {
  Future<Uint8List> buildPdf(ClientStatementSnapshot snapshot) async {
    final regularFont = await rootBundle.load(
      'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
    );
    final boldFont = await rootBundle.load(
      'assets/fonts/AtkinsonHyperlegible-Bold.ttf',
    );
    final monoFont = await rootBundle.load(
      'assets/fonts/IBMPlexMono-Regular.ttf',
    );
    return compute(_renderClientStatementPdf, {
      'snapshot': snapshot.toJson(),
      'regular_font': _fontBytes(regularFont),
      'bold_font': _fontBytes(boldFont),
      'mono_font': _fontBytes(monoFont),
    });
  }

  Uint8List _fontBytes(ByteData data) =>
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

  Uint8List buildCsv(ClientStatementSnapshot snapshot) {
    final rows = <List<String>>[
      const [
        'cliente_ci',
        'cliente',
        'membresia_id',
        'plan',
        'estado_membresia',
        'pago_id',
        'fecha_gimnasio',
        'zona_horaria',
        'estado_pago',
        'moneda_pago',
        'total_pago',
        'importe_aplicado',
        'metodo',
        'cuenta',
        'moneda_detalle',
        'cantidad_detalle',
        'tasa_historica',
      ],
    ];
    for (final payment in snapshot.payments) {
      final details = payment.details.isEmpty
          ? const <ClientStatementPaymentDetail?>[null]
          : payment.details;
      for (final detail in details) {
        rows.add([
          snapshot.clientId,
          snapshot.clientName,
          payment.membershipId ?? '',
          payment.plan,
          payment.membershipStatus ?? '',
          payment.id,
          payment.localDate,
          snapshot.timezone,
          payment.voided ? 'ANULADO' : 'PAGADO',
          payment.currency,
          payment.total.toStringAsFixed(2),
          payment.applied?.toStringAsFixed(2) ?? '',
          detail?.method ?? '',
          detail?.account ?? '',
          detail?.currency ?? '',
          detail == null ? '' : _detailNumber(detail.amount),
          detail?.rate ?? '',
        ]);
      }
    }
    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
    return Uint8List.fromList([0xef, 0xbb, 0xbf, ...utf8.encode(csv)]);
  }

  Future<String?> savePdf(ClientStatementSnapshot snapshot) async {
    final bytes = await buildPdf(snapshot);
    return FilePicker.platform.saveFile(
      dialogTitle: 'Guardar estado de cuenta en PDF',
      fileName: _fileName(snapshot, 'pdf'),
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: bytes,
      lockParentWindow: true,
    );
  }

  Future<String?> saveCsv(ClientStatementSnapshot snapshot) {
    return FilePicker.platform.saveFile(
      dialogTitle: 'Guardar movimientos en CSV',
      fileName: _fileName(snapshot, 'csv'),
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      bytes: buildCsv(snapshot),
      lockParentWindow: true,
    );
  }

  Future<bool> printPdf(ClientStatementSnapshot snapshot) async {
    final bytes = await buildPdf(snapshot);
    return Printing.layoutPdf(
      name: _fileName(snapshot, 'pdf'),
      format: PdfPageFormat.a4,
      dynamicLayout: false,
      onLayout: (_) async => bytes,
    );
  }

  String _fileName(ClientStatementSnapshot snapshot, String extension) {
    final stamp = snapshot.generatedAt
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(0, 8);
    return 'estado-cuenta-${snapshot.clientId}-$stamp.$extension';
  }
}

Future<Uint8List> _renderClientStatementPdf(
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
  final document = pw.Document(
    title: 'Estado de cuenta - ${snapshot['client_name']}',
    author: 'GymOS',
    subject: 'Historial contractual y financiero por cliente',
  );
  const ink = PdfColor.fromInt(0xff24211d);
  const muted = PdfColor.fromInt(0xff6f6a62);
  const line = PdfColor.fromInt(0xffd8d0c4);
  const paper = PdfColor.fromInt(0xfffaf7f1);
  const accent = PdfColor.fromInt(0xffd94a24);
  const soft = PdfColor.fromInt(0xfff2e8de);
  final memberships = (snapshot['memberships'] as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
  final payments = (snapshot['payments'] as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
  final totals = (snapshot['totals'] as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(34, 34, 34, 32),
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        fontFallback: [mono],
      ),
      header: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: line, width: 0.7)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'DIAMOND GYM / GYMOS',
              style: pw.TextStyle(
                font: bold,
                fontSize: 9,
                letterSpacing: 1.2,
                color: ink,
              ),
            ),
            pw.Text(
              'ESTADO DE CUENTA',
              style: pw.TextStyle(font: mono, fontSize: 8, color: muted),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: line, width: 0.7)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Documento informativo - importes conservan su moneda original',
              style: pw.TextStyle(font: regular, fontSize: 7, color: muted),
            ),
            pw.Text(
              'Pág. ${context.pageNumber} / ${context.pagesCount}',
              style: pw.TextStyle(font: mono, fontSize: 7, color: muted),
            ),
          ],
        ),
      ),
      build: (context) => [
        pw.SizedBox(height: 20),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(width: 7, height: 58, color: accent),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ESTADO DE CUENTA.',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 28,
                      height: 0.92,
                      color: ink,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    '${snapshot['client_name']} / CI ${snapshot['client_id']}',
                    style: pw.TextStyle(font: bold, fontSize: 13, color: ink),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'GENERADO',
                  style: pw.TextStyle(font: mono, fontSize: 7, color: muted),
                ),
                pw.Text(
                  '${snapshot['generated_at']}',
                  style: pw.TextStyle(font: mono, fontSize: 8, color: ink),
                ),
                pw.Text(
                  '${snapshot['timezone']}',
                  style: pw.TextStyle(font: mono, fontSize: 7, color: muted),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          color: soft,
          child: pw.Row(
            children: [
              pw.Expanded(
                child: _pdfFact(
                  'ALCANCE',
                  '${snapshot['scope']}',
                  mono,
                  ink,
                  muted,
                ),
              ),
              pw.SizedBox(width: 14),
              _pdfFact('MEMBRESÍAS', '${memberships.length}', mono, ink, muted),
              pw.SizedBox(width: 14),
              _pdfFact('PAGOS', '${payments.length}', mono, ink, muted),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        _pdfSectionTitle('TOTALES VÁLIDOS POR MONEDA', bold, accent),
        if (totals.isEmpty)
          pw.Text(
            'Sin pagos válidos en el alcance seleccionado.',
            style: pw.TextStyle(font: regular, fontSize: 9, color: muted),
          )
        else
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final total in totals)
                pw.Container(
                  width: 150,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: paper,
                    border: pw.Border.all(color: line, width: 0.7),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${(total['amount'] as num).toStringAsFixed(2)} ${total['currency']}',
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 15,
                          color: ink,
                        ),
                      ),
                      pw.Text(
                        '${total['payment_count']} pago(s)',
                        style: pw.TextStyle(
                          font: mono,
                          fontSize: 7,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        pw.SizedBox(height: 18),
        _pdfSectionTitle('MEMBRESÍAS', bold, accent),
        if (memberships.isEmpty)
          pw.Text(
            'Ninguna membresía coincide con los filtros.',
            style: pw.TextStyle(font: regular, fontSize: 9, color: muted),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const [
              'Periodo',
              'Plan',
              'Estado',
              'Entrenador',
              'Contratado',
              'Aplicado',
            ],
            data: [
              for (final membership in memberships)
                [
                  membership['period'],
                  membership['plan'],
                  [
                    membership['status'],
                    if (membership['pause_summary'] != '')
                      membership['pause_summary'],
                    if (membership['request_summary'] != '')
                      membership['request_summary'],
                  ].join('\n'),
                  membership['trainer'],
                  membership['contracted'],
                  membership['paid'],
                ],
            ],
            headerStyle: pw.TextStyle(font: bold, fontSize: 7, color: ink),
            cellStyle: pw.TextStyle(font: regular, fontSize: 7.2, color: ink),
            headerDecoration: const pw.BoxDecoration(color: soft),
            cellDecoration: (index, data, rowNum) => pw.BoxDecoration(
              color: rowNum.isEven ? paper : PdfColors.white,
              border: const pw.Border(
                bottom: pw.BorderSide(color: line, width: 0.4),
              ),
            ),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 5,
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.3),
              1: pw.FlexColumnWidth(1.6),
              2: pw.FlexColumnWidth(0.8),
              3: pw.FlexColumnWidth(1.3),
              4: pw.FlexColumnWidth(0.9),
              5: pw.FlexColumnWidth(0.9),
            },
          ),
        pw.SizedBox(height: 18),
        _pdfSectionTitle('MOVIMIENTOS', bold, accent),
        if (payments.isEmpty)
          pw.Text(
            'No hay cobros en el alcance seleccionado.',
            style: pw.TextStyle(font: regular, fontSize: 9, color: muted),
          )
        else
          for (final payment in payments) ...[
            pw.Inseparable(
              child: pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(9),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: line, width: 0.7),
                  color: payment['voided'] == true ? soft : PdfColors.white,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            '${payment['plan']}',
                            style: pw.TextStyle(
                              font: bold,
                              fontSize: 9,
                              color: ink,
                            ),
                          ),
                        ),
                        pw.Text(
                          '${(payment['total'] as num).toStringAsFixed(2)} ${payment['currency']}',
                          style: pw.TextStyle(
                            font: bold,
                            fontSize: 9,
                            color: payment['voided'] == true ? muted : accent,
                            decoration: payment['voided'] == true
                                ? pw.TextDecoration.lineThrough
                                : pw.TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      '${payment['local_date']} / ${payment['methods']} / '
                      '${payment['voided'] == true ? 'ANULADO' : 'PAGADO'}',
                      style: pw.TextStyle(
                        font: mono,
                        fontSize: 7,
                        color: muted,
                      ),
                    ),
                    if ((payment['details'] as List).isNotEmpty) ...[
                      pw.SizedBox(height: 5),
                      for (final rawDetail in payment['details'] as List)
                        pw.Builder(
                          builder: (context) {
                            final detail = Map<String, dynamic>.from(
                              rawDetail as Map,
                            );
                            return pw.Text(
                              '${detail['method']} / ${detail['account']} / '
                              '${_detailNumber((detail['amount'] as num).toDouble())} '
                              '${detail['currency']} / tasa ${detail['rate']}',
                              style: pw.TextStyle(
                                font: regular,
                                fontSize: 7.2,
                                color: ink,
                              ),
                            );
                          },
                        ),
                    ],
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'ID ${payment['id']}',
                      style: pw.TextStyle(
                        font: mono,
                        fontSize: 6.3,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
      ],
    ),
  );
  return document.save();
}

pw.Widget _pdfSectionTitle(String text, pw.Font bold, PdfColor accent) =>
    pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 7),
      padding: const pw.EdgeInsets.only(left: 7),
      decoration: pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: accent, width: 3)),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: bold, fontSize: 9, letterSpacing: 0.8),
      ),
    );

pw.Widget _pdfFact(
  String label,
  String value,
  pw.Font mono,
  PdfColor ink,
  PdfColor muted,
) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(
      label,
      style: pw.TextStyle(font: mono, fontSize: 6.5, color: muted),
    ),
    pw.SizedBox(height: 2),
    pw.Text(
      value,
      style: pw.TextStyle(font: mono, fontSize: 8, color: ink),
    ),
  ],
);

String _contractDate(DateTime value) =>
    DateFormat('dd/MM/yyyy').format(value.toUtc());

String _pauseSummary(ClientMembershipPause pause) {
  final interval = pause.resumeDate == null
      ? 'desde ${_contractDate(pause.pauseDate)}'
      : '${_contractDate(pause.pauseDate)}–${_contractDate(pause.resumeDate!)}';
  final end = pause.recalculatedEndDate == null
      ? 'fin congelado ${_contractDate(pause.previousEndDate)}'
      : 'nuevo fin ${_contractDate(pause.recalculatedEndDate!)}';
  final state = pause.isActive ? 'EN PAUSA' : pause.status.replaceAll('_', ' ');
  return '$state · $interval · ${pause.remainingDays} días · '
      '${pause.reason} · $end';
}

String _requestSummary(ClientMembershipRequest request) {
  final effective = _contractDate(request.requestedEffectiveDate);
  final end = request.resultingEndDate ?? request.estimatedEndDate;
  final decision = request.deciderName == null
      ? ''
      : ' · decidió ${request.deciderName}'
            '${request.decisionReason == null ? '' : ': ${request.decisionReason}'}';
  return 'SOLICITUD ${request.kind} ${request.status} · $effective · '
      '${request.estimatedRemainingDays} días'
      '${end == null ? '' : ' · fin ${_contractDate(end)}'} · '
      '${request.requesterName}$decision';
}

String _detailNumber(double value) {
  final cents = double.parse(value.toStringAsFixed(2));
  return value == cents ? value.toStringAsFixed(2) : value.toStringAsFixed(4);
}

String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';
