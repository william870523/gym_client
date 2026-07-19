import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../models/management_margin_annual_models.dart';

class ManagementMarginAnnualReportSnapshot {
  const ManagementMarginAnnualReportSnapshot({
    required this.result,
    required this.currencies,
    required this.generatedAtUtc,
    required this.generatedAtLocal,
    required this.timezone,
    required this.scope,
  });

  final ManagementMarginAnnualResultsModel result;
  final List<ManagementMarginAnnualCurrencyModel> currencies;
  final DateTime generatedAtUtc;
  final String generatedAtLocal;
  final String timezone;
  final String scope;

  Map<String, dynamic> toJson() => {
    'year': result.year,
    'nature': result.nature,
    'current_business_month': result.currentBusinessMonth,
    'coverage_note': result.coverageNote,
    'generated_at_utc': generatedAtUtc.toIso8601String(),
    'generated_at_local': generatedAtLocal,
    'timezone': timezone,
    'scope': scope,
    'coverage': {
      'eligible_months': result.coverage.eligibleMonths,
      'certified_months': result.coverage.certifiedMonths,
      'certified_eligible_months': result.coverage.certifiedEligibleMonths,
      'pending_months': result.coverage.pendingMonths,
      'eligible_percentage': result.coverage.eligiblePercentage,
      'complete': result.coverage.complete,
    },
    'months': result.months
        .map(
          (item) => {
            'month': item.month,
            'state': item.state,
            'reason': item.reason,
            'close_id': item.monthlyCloseId,
            'sha256': item.sha256,
            'closed_at': item.closedAt?.toIso8601String(),
          },
        )
        .toList(growable: false),
    'currencies': currencies
        .map(
          (item) => {
            'id': item.currencyId,
            'code': item.currencyCode,
            'month_count': item.monthCount,
            'totals': {
              'revenue': item.accrualTotals.revenue,
              'direct_cost': item.accrualTotals.directCost,
              'direct_margin': item.accrualTotals.directMargin,
              'fixed': item.accrualTotals.fixed,
              'margin_after_fixed': item.accrualTotals.marginAfterFixed,
              'margin_pct': item.accrualTotals.marginPct,
            },
            'latest_cut': item.latestCut == null
                ? null
                : {
                    'month': item.latestCut!.month,
                    'revenue_to_date': item.latestCut!.revenueToDate,
                    'direct_cost_to_date': item.latestCut!.directCostToDate,
                    'direct_margin_to_date': item.latestCut!.directMarginToDate,
                    'fixed_to_date': item.latestCut!.fixedToDate,
                    'margin_after_fixed_to_date':
                        item.latestCut!.marginAfterFixedToDate,
                    'margin_pct_to_date': item.latestCut!.marginPctToDate,
                  },
            'months': item.months
                .map(
                  (month) => {
                    'month': month.month,
                    'revenue': month.revenue,
                    'direct_cost': month.directCost,
                    'direct_margin': month.directMargin,
                    'fixed': month.fixed,
                    'margin_after_fixed': month.marginAfterFixed,
                    'margin_pct': month.marginPct,
                    'direct_margin_to_date': month.directMarginToDate,
                    'margin_after_fixed_to_date': month.marginAfterFixedToDate,
                  },
                )
                .toList(growable: false),
          },
        )
        .toList(growable: false),
    'limitations': result.limitations,
  };
}

class ManagementMarginAnnualReportService {
  const ManagementMarginAnnualReportService();

  ManagementMarginAnnualReportSnapshot snapshot({
    required ManagementMarginAnnualResultsModel result,
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
    final gymTimezone = timezone ?? appClock.gymTimezone;
    return ManagementMarginAnnualReportSnapshot(
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

  Uint8List buildCsv(ManagementMarginAnnualReportSnapshot snapshot) {
    final rows = <List<String>>[
      const [
        'tipo_fila',
        'anio',
        'mes',
        'moneda',
        'estado_mes',
        'ingreso_devengado',
        'costo_directo',
        'margen_directo',
        'fijo_no_distribuido',
        'margen_menos_fijo',
        'margen_pct',
        'margen_acumulado_ultimo_corte',
        'cierre_mensual_id',
        'resumen_sha256',
        'alcance',
        'zona_horaria',
        'generado_at_utc',
      ],
    ];
    for (final currency in snapshot.currencies) {
      rows.add([
        'MONEDA',
        snapshot.result.year,
        '',
        currency.currencyCode,
        '',
        currency.accrualTotals.revenue,
        currency.accrualTotals.directCost,
        currency.accrualTotals.directMargin,
        currency.accrualTotals.fixed,
        currency.accrualTotals.marginAfterFixed,
        currency.accrualTotals.marginPct ?? '',
        currency.latestCut?.directMarginToDate ?? '',
        '',
        '',
        snapshot.scope,
        snapshot.timezone,
        snapshot.generatedAtUtc.toIso8601String(),
      ]);
      for (final month in snapshot.result.months) {
        final currencyMonth = currency.months
            .where((item) => item.month == month.month)
            .firstOrNull;
        rows.add([
          'MES',
          snapshot.result.year,
          month.month,
          currency.currencyCode,
          month.state,
          currencyMonth?.revenue ?? '',
          currencyMonth?.directCost ?? '',
          currencyMonth?.directMargin ?? '',
          currencyMonth?.fixed ?? '',
          currencyMonth?.marginAfterFixed ?? '',
          currencyMonth?.marginPct ?? '',
          currencyMonth?.directMarginToDate ?? '',
          month.monthlyCloseId ?? '',
          month.sha256 ?? '',
          snapshot.scope,
          snapshot.timezone,
          snapshot.generatedAtUtc.toIso8601String(),
        ]);
      }
    }
    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
    return Uint8List.fromList([0xef, 0xbb, 0xbf, ...utf8.encode(csv)]);
  }

  Future<Uint8List> buildPdf(
    ManagementMarginAnnualReportSnapshot snapshot,
  ) async {
    final regular = await rootBundle.load(
      'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
    );
    final bold = await rootBundle.load(
      'assets/fonts/AtkinsonHyperlegible-Bold.ttf',
    );
    final mono = await rootBundle.load('assets/fonts/IBMPlexMono-Regular.ttf');
    return compute(_renderManagementMarginAnnualPdf, {
      'snapshot': snapshot.toJson(),
      'regular_font': _fontBytes(regular),
      'bold_font': _fontBytes(bold),
      'mono_font': _fontBytes(mono),
    });
  }

  Future<String?> saveCsv(ManagementMarginAnnualReportSnapshot snapshot) {
    return FilePicker.platform.saveFile(
      dialogTitle: 'Guardar devengado anual en CSV',
      fileName: _fileName(snapshot, 'csv'),
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      bytes: buildCsv(snapshot),
      lockParentWindow: true,
    );
  }

  Future<String?> savePdf(ManagementMarginAnnualReportSnapshot snapshot) async {
    return FilePicker.platform.saveFile(
      dialogTitle: 'Guardar devengado anual en PDF',
      fileName: _fileName(snapshot, 'pdf'),
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: await buildPdf(snapshot),
      lockParentWindow: true,
    );
  }

  Future<bool> printPdf(ManagementMarginAnnualReportSnapshot snapshot) async {
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
    ManagementMarginAnnualReportSnapshot snapshot,
    String extension,
  ) {
    final scope = snapshot.currencies.length == 1
        ? snapshot.currencies.single.currencyCode.toLowerCase()
        : 'multimoneda';
    return 'devengado-certificado-${snapshot.result.year}-$scope.$extension';
  }
}

String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

Future<Uint8List> _renderManagementMarginAnnualPdf(
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

  pw.TextStyle style({
    double size = 9,
    bool strong = false,
    PdfColor color = ink,
  }) => pw.TextStyle(
    font: strong ? bold : regular,
    fontSize: size,
    color: color,
    fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
  final monoStyle = pw.TextStyle(font: mono, fontSize: 8, color: ink);
  final doc = pw.Document();
  final currencies = (snapshot['currencies'] as List? ?? const [])
      .whereType<Map>()
      .map(Map<String, dynamic>.from)
      .toList(growable: false);
  final months = (snapshot['months'] as List? ?? const [])
      .whereType<Map>()
      .map(Map<String, dynamic>.from)
      .toList(growable: false);
  final coverage = Map<String, dynamic>.from(snapshot['coverage'] as Map);

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(
          base: regular,
          bold: bold,
          fontFallback: [regular],
        ),
      ),
      build: (context) => [
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: line, width: 1)),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'GYM·OS — FINANZAS Y NÓMINA',
                      style: style(size: 8, color: muted, strong: true),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'DEVENGADO CERTIFICADO ${snapshot['year']}',
                      style: style(size: 22, strong: true),
                    ),
                    pw.Text(
                      '${snapshot['scope']} · ${snapshot['generated_at_local']} · ${snapshot['timezone']}',
                      style: style(size: 8, color: muted),
                    ),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                color: (coverage['complete'] == true) ? success : warning,
                child: pw.Text(
                  '${coverage['certified_eligible_months']}/${coverage['eligible_months']} MESES',
                  style: style(size: 9, strong: true, color: PdfColors.white),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          snapshot['coverage_note']?.toString() ?? '',
          style: style(size: 10, strong: true),
        ),
        pw.SizedBox(height: 12),
        for (final currency in currencies) ...[
          _currencyPdfBlock(
            currency,
            months,
            style,
            monoStyle,
            paper,
            line,
            accent,
            warning,
          ),
          pw.SizedBox(height: 12),
        ],
        pw.Text(
          'No suma monedas diferentes. Los totales suman importes devengados del mes; los acumulados corresponden al último corte certificado.',
          style: style(size: 8, color: muted),
        ),
      ],
    ),
  );
  return doc.save();
}

pw.Widget _currencyPdfBlock(
  Map<String, dynamic> currency,
  List<Map<String, dynamic>> months,
  pw.TextStyle Function({PdfColor color, double size, bool strong}) style,
  pw.TextStyle monoStyle,
  PdfColor paper,
  PdfColor line,
  PdfColor accent,
  PdfColor warning,
) {
  final totals = Map<String, dynamic>.from(currency['totals'] as Map);
  final currencyMonths = (currency['months'] as List? ?? const [])
      .whereType<Map>()
      .map(Map<String, dynamic>.from)
      .toList(growable: false);
  Map<String, dynamic>? findCurrencyMonth(String month) {
    for (final item in currencyMonths) {
      if (item['month'] == month) return item;
    }
    return null;
  }

  return pw.Container(
    decoration: pw.BoxDecoration(
      color: paper,
      border: pw.Border.all(color: line),
    ),
    padding: const pw.EdgeInsets.all(10),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                currency['code']?.toString() ?? '—',
                style: style(size: 16, strong: true, color: accent),
              ),
            ),
            pw.Text(
              'Margen anual: ${totals['direct_margin']} · ${totals['margin_pct'] ?? '—'}%',
              style: style(size: 11, strong: true),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder(horizontalInside: pw.BorderSide(color: line)),
          columnWidths: const {
            0: pw.FixedColumnWidth(58),
            1: pw.FixedColumnWidth(86),
            2: pw.FlexColumnWidth(),
            3: pw.FixedColumnWidth(80),
            4: pw.FixedColumnWidth(80),
            5: pw.FixedColumnWidth(80),
            6: pw.FixedColumnWidth(80),
          },
          children: [
            pw.TableRow(
              children:
                  [
                        'Mes',
                        'Estado',
                        'Evidencia',
                        'Ingreso',
                        'Costo',
                        'Margen',
                        'Margen - fijo',
                      ]
                      .map(
                        (text) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4),
                          child: pw.Text(
                            text,
                            style: style(size: 8, strong: true),
                          ),
                        ),
                      )
                      .toList(growable: false),
            ),
            for (final month in months)
              pw.TableRow(
                children:
                    [
                          month['month']?.toString() ?? '',
                          month['state']?.toString() ?? '',
                          _short(month['sha256']?.toString()),
                          findCurrencyMonth(
                                month['month']?.toString() ?? '',
                              )?['revenue']?.toString() ??
                              '—',
                          findCurrencyMonth(
                                month['month']?.toString() ?? '',
                              )?['direct_cost']?.toString() ??
                              '—',
                          findCurrencyMonth(
                                month['month']?.toString() ?? '',
                              )?['direct_margin']?.toString() ??
                              '—',
                          findCurrencyMonth(
                                month['month']?.toString() ?? '',
                              )?['margin_after_fixed']?.toString() ??
                              '—',
                        ]
                        .map(
                          (text) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 3),
                            child: pw.Text(
                              text,
                              style:
                                  text == 'SIN_CIERRE' ||
                                      text == 'SNAPSHOT_ANTERIOR'
                                  ? style(size: 7, color: warning)
                                  : monoStyle,
                            ),
                          ),
                        )
                        .toList(growable: false),
              ),
          ],
        ),
      ],
    ),
  );
}

String _short(String? value) {
  if (value == null || value.isEmpty) return '—';
  return value.length <= 10 ? value : value.substring(0, 10);
}
