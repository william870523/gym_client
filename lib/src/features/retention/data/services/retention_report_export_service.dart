import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/utils/datetime_zone.dart';
import '../models/retention_models.dart';

class RetentionReportSnapshot {
  const RetentionReportSnapshot({
    required this.timezone,
    required this.generatedAt,
    required this.businessDate,
    required this.scope,
    required this.populationTotal,
    required this.visibleTotal,
    required this.retentionRate,
    required this.recoveryRate,
    required this.matureEligible,
    required this.retained,
    required this.historicalExits,
    required this.cohorts,
    required this.breakdowns,
    required this.rows,
  });

  factory RetentionReportSnapshot.fromDashboard({
    required RetentionDashboardModel dashboard,
    required List<RetentionItemModel> visibleItems,
    required String scope,
  }) {
    final plans = {
      for (final item in dashboard.breakdowns.plans) item.id: item,
    };
    final trainers = {
      for (final item in dashboard.breakdowns.trainers) item.id: item,
    };
    return RetentionReportSnapshot(
      timezone: dashboard.timezone,
      generatedAt: DateFormat(
        'dd/MM/yyyy HH:mm',
      ).format(toGymWallClock(dashboard.generatedAtUtc, dashboard.timezone)),
      businessDate: dashboard.businessDate,
      scope: scope,
      populationTotal: dashboard.metrics.totalVisible,
      visibleTotal: visibleItems.length,
      retentionRate: dashboard.metrics.retentionRatePct,
      recoveryRate: dashboard.metrics.recoveryRatePct,
      matureEligible: dashboard.metrics.matureEligible,
      retained: dashboard.metrics.retained,
      historicalExits: dashboard.metrics.historicalExits,
      cohorts: dashboard.cohorts,
      breakdowns: dashboard.breakdowns,
      rows: visibleItems
          .map(
            (item) => RetentionReportRow.fromItem(
              item,
              planBreakdown: plans[item.plan.id],
              trainerBreakdown: item.trainer == null
                  ? null
                  : trainers[item.trainer!.id],
            ),
          )
          .toList(growable: false),
    );
  }

  final String timezone;
  final String generatedAt;
  final String businessDate;
  final String scope;
  final int populationTotal;
  final int visibleTotal;
  final double? retentionRate;
  final double? recoveryRate;
  final int matureEligible;
  final int retained;
  final int historicalExits;
  final List<RetentionCohortModel> cohorts;
  final RetentionBreakdownsModel breakdowns;
  final List<RetentionReportRow> rows;

  Map<String, dynamic> toJson() => {
    'timezone': timezone,
    'generated_at': generatedAt,
    'business_date': businessDate,
    'scope': scope,
    'population_total': populationTotal,
    'visible_total': visibleTotal,
    'retention_rate': retentionRate,
    'recovery_rate': recoveryRate,
    'mature_eligible': matureEligible,
    'retained': retained,
    'historical_exits': historicalExits,
    'cohorts': [
      for (final item in cohorts)
        {
          'month': item.month,
          'total_due': item.totalDue,
          'mature_eligible': item.matureEligible,
          'retained': item.retained,
          'historical_exits': item.historicalExits,
          'recovered': item.recovered,
          'retention_rate_pct': item.retentionRatePct,
          'retention_change_pp': item.retentionChangePp,
          'provisional': item.provisional,
        },
    ],
    'breakdowns': {
      'plans': breakdowns.plans.map(_breakdownToJson).toList(growable: false),
      'trainers': breakdowns.trainers
          .map(_breakdownToJson)
          .toList(growable: false),
      'unattributed_trainer_total': breakdowns.unattributedTrainerTotal,
    },
    'rows': rows.map((item) => item.toJson()).toList(growable: false),
  };
}

class RetentionReportRow {
  const RetentionReportRow({
    required this.membershipId,
    required this.clientId,
    required this.clientName,
    required this.phone,
    required this.plan,
    required this.trainer,
    required this.expectedRenewalDate,
    required this.state,
    required this.reason,
    required this.management,
    required this.promiseDate,
    required this.nextManagementDate,
    required this.lastPaymentAtUtc,
    required this.lastAttendanceAtUtc,
    required this.planMatureEligible,
    required this.planRetained,
    required this.planRetentionRatePct,
    required this.trainerMatureEligible,
    required this.trainerRetained,
    required this.trainerRetentionRatePct,
  });

  factory RetentionReportRow.fromItem(
    RetentionItemModel item, {
    RetentionBreakdownRowModel? planBreakdown,
    RetentionBreakdownRowModel? trainerBreakdown,
  }) => RetentionReportRow(
    membershipId: item.membershipId,
    clientId: item.clientId,
    clientName: item.clientName,
    phone: item.phone,
    plan: item.plan.name,
    trainer: item.trainer?.name,
    expectedRenewalDate: item.expectedRenewalDate,
    state: item.state,
    reason: item.reason,
    management: item.management.status,
    promiseDate: item.management.promiseDate,
    nextManagementDate: item.management.nextManagementDate,
    lastPaymentAtUtc: item.lastPaymentAtUtc,
    lastAttendanceAtUtc: item.lastAttendanceAtUtc,
    planMatureEligible: planBreakdown?.matureEligible,
    planRetained: planBreakdown?.retained,
    planRetentionRatePct: planBreakdown?.retentionRatePct,
    trainerMatureEligible: trainerBreakdown?.matureEligible,
    trainerRetained: trainerBreakdown?.retained,
    trainerRetentionRatePct: trainerBreakdown?.retentionRatePct,
  );

  final String membershipId;
  final String clientId;
  final String clientName;
  final String? phone;
  final String plan;
  final String? trainer;
  final String expectedRenewalDate;
  final String state;
  final String reason;
  final String management;
  final String? promiseDate;
  final String? nextManagementDate;
  final DateTime? lastPaymentAtUtc;
  final DateTime? lastAttendanceAtUtc;
  final int? planMatureEligible;
  final int? planRetained;
  final double? planRetentionRatePct;
  final int? trainerMatureEligible;
  final int? trainerRetained;
  final double? trainerRetentionRatePct;

  Map<String, dynamic> toJson() => {
    'membership_id': membershipId,
    'client_id': clientId,
    'client_name': clientName,
    'phone': phone,
    'plan': plan,
    'trainer': trainer,
    'expected_renewal_date': expectedRenewalDate,
    'state': state,
    'reason': reason,
    'management': management,
    'promise_date': promiseDate,
    'next_management_date': nextManagementDate,
    'last_payment_at_utc': lastPaymentAtUtc?.toUtc().toIso8601String(),
    'last_attendance_at_utc': lastAttendanceAtUtc?.toUtc().toIso8601String(),
    'plan_mature_eligible': planMatureEligible,
    'plan_retained': planRetained,
    'plan_retention_rate_pct': planRetentionRatePct,
    'trainer_mature_eligible': trainerMatureEligible,
    'trainer_retained': trainerRetained,
    'trainer_retention_rate_pct': trainerRetentionRatePct,
  };
}

Map<String, dynamic> _breakdownToJson(RetentionBreakdownRowModel item) => {
  'id': item.id,
  'name': item.name,
  'total_due': item.totalDue,
  'mature_eligible': item.matureEligible,
  'open_cases': item.openCases,
  'retained': item.retained,
  'renewed_on_time': item.renewedOnTime,
  'renewed_in_grace': item.renewedInGrace,
  'historical_exits': item.historicalExits,
  'recovered': item.recovered,
  'retention_rate_pct': item.retentionRatePct,
  'recovery_rate_pct': item.recoveryRatePct,
};

class RetentionReportExportService {
  Future<Uint8List> buildPdf(RetentionReportSnapshot snapshot) async {
    final regularFont = await rootBundle.load(
      'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
    );
    final boldFont = await rootBundle.load(
      'assets/fonts/AtkinsonHyperlegible-Bold.ttf',
    );
    final monoFont = await rootBundle.load(
      'assets/fonts/IBMPlexMono-Regular.ttf',
    );
    return compute(_renderRetentionPdf, {
      'snapshot': snapshot.toJson(),
      'regular_font': _fontBytes(regularFont),
      'bold_font': _fontBytes(boldFont),
      'mono_font': _fontBytes(monoFont),
    });
  }

  Uint8List buildCsv(RetentionReportSnapshot snapshot) {
    final rows = <List<String>>[
      const [
        'fecha_corte',
        'zona_horaria',
        'alcance',
        'membresia_id',
        'ci',
        'socio',
        'telefono',
        'plan',
        'entrenador_atribuido',
        'renovacion_esperada',
        'estado_retencion',
        'explicacion',
        'estado_gestion',
        'promesa_fecha',
        'proxima_gestion_fecha',
        'ultimo_pago_utc',
        'ultima_asistencia_utc',
        'plan_casos_maduros',
        'plan_retenidos',
        'plan_retencion_pct',
        'entrenador_casos_maduros',
        'entrenador_retenidos',
        'entrenador_retencion_pct',
      ],
      for (final item in snapshot.rows)
        [
          snapshot.businessDate,
          snapshot.timezone,
          snapshot.scope,
          item.membershipId,
          item.clientId,
          item.clientName,
          item.phone ?? '',
          item.plan,
          item.trainer ?? '',
          item.expectedRenewalDate,
          item.state,
          item.reason,
          item.management,
          item.promiseDate ?? '',
          item.nextManagementDate ?? '',
          item.lastPaymentAtUtc?.toUtc().toIso8601String() ?? '',
          item.lastAttendanceAtUtc?.toUtc().toIso8601String() ?? '',
          item.planMatureEligible?.toString() ?? '',
          item.planRetained?.toString() ?? '',
          item.planRetentionRatePct?.toStringAsFixed(2) ?? '',
          item.trainerMatureEligible?.toString() ?? '',
          item.trainerRetained?.toString() ?? '',
          item.trainerRetentionRatePct?.toStringAsFixed(2) ?? '',
        ],
    ];
    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
    return Uint8List.fromList([0xef, 0xbb, 0xbf, ...utf8.encode(csv)]);
  }

  Future<String?> savePdf(RetentionReportSnapshot snapshot) async {
    final bytes = await buildPdf(snapshot);
    return FilePicker.platform.saveFile(
      dialogTitle: 'Guardar Control y Calidad en PDF',
      fileName: _fileName(snapshot, 'pdf'),
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: bytes,
      lockParentWindow: true,
    );
  }

  Future<String?> saveCsv(RetentionReportSnapshot snapshot) {
    return FilePicker.platform.saveFile(
      dialogTitle: 'Guardar Control y Calidad en CSV',
      fileName: _fileName(snapshot, 'csv'),
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      bytes: buildCsv(snapshot),
      lockParentWindow: true,
    );
  }

  Future<bool> printPdf(RetentionReportSnapshot snapshot) async {
    final bytes = await buildPdf(snapshot);
    return Printing.layoutPdf(
      name: _fileName(snapshot, 'pdf'),
      format: PdfPageFormat.a4.landscape,
      dynamicLayout: false,
      onLayout: (_) async => bytes,
    );
  }

  Uint8List _fontBytes(ByteData data) =>
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

  String _fileName(RetentionReportSnapshot snapshot, String extension) =>
      'control-calidad-${snapshot.businessDate}.$extension';
}

Future<Uint8List> _renderRetentionPdf(Map<String, dynamic> payload) async {
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
  final cohorts = (snapshot['cohorts'] as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
  final breakdowns = Map<String, dynamic>.from(snapshot['breakdowns'] as Map);
  final planBreakdowns = (breakdowns['plans'] as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
  final trainerBreakdowns = (breakdowns['trainers'] as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
  final rows = (snapshot['rows'] as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
  const ink = PdfColor.fromInt(0xff24211d);
  const muted = PdfColor.fromInt(0xff6f6a62);
  const line = PdfColor.fromInt(0xffd8d0c4);
  const paper = PdfColor.fromInt(0xfffaf7f1);
  const soft = PdfColor.fromInt(0xfff2e8de);
  const accent = PdfColor.fromInt(0xffd94a24);
  const success = PdfColor.fromInt(0xff2e7d57);

  final document = pw.Document(
    title: 'Control y Calidad - ${snapshot['business_date']}',
    author: 'GymOS',
    subject: 'Retención, cohortes y seguimiento operativo',
  );
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 26),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      header: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 7),
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
                fontSize: 8,
                letterSpacing: 1.1,
                color: ink,
              ),
            ),
            pw.Text(
              'CONTROL Y CALIDAD / ${snapshot['business_date']}',
              style: pw.TextStyle(font: mono, fontSize: 7, color: muted),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 7),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: line, width: 0.7)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'La gestión de contacto no equivale a pago ni renovación.',
              style: pw.TextStyle(fontSize: 6.5, color: muted),
            ),
            pw.Text(
              'Pág. ${context.pageNumber} / ${context.pagesCount}',
              style: pw.TextStyle(font: mono, fontSize: 6.5, color: muted),
            ),
          ],
        ),
      ),
      build: (_) => [
        pw.SizedBox(height: 18),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(width: 7, height: 54, color: accent),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CONTROL Y CALIDAD.',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 27,
                      height: 0.92,
                      color: ink,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    '${snapshot['scope']}',
                    style: pw.TextStyle(fontSize: 8.5, color: muted),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'GENERADO ${snapshot['generated_at']}',
                  style: pw.TextStyle(font: mono, fontSize: 7.5, color: ink),
                ),
                pw.Text(
                  '${snapshot['timezone']}',
                  style: pw.TextStyle(font: mono, fontSize: 7, color: muted),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Container(
          color: soft,
          padding: const pw.EdgeInsets.all(10),
          child: pw.Row(
            children: [
              _metric(
                'RETENCIÓN',
                _pct(snapshot['retention_rate']),
                success,
                bold,
                mono,
              ),
              _metric(
                'RECUPERACIÓN',
                _pct(snapshot['recovery_rate']),
                accent,
                bold,
                mono,
              ),
              _metric(
                'COHORTE MADURA',
                '${snapshot['mature_eligible']}',
                ink,
                bold,
                mono,
              ),
              _metric('RETENIDOS', '${snapshot['retained']}', ink, bold, mono),
              _metric(
                'SALIDAS HIST.',
                '${snapshot['historical_exits']}',
                ink,
                bold,
                mono,
              ),
              _metric(
                'FILAS EXPORTADAS',
                '${snapshot['visible_total']} / ${snapshot['population_total']}',
                ink,
                bold,
                mono,
              ),
            ],
          ),
        ),
        if (cohorts.isNotEmpty) ...[
          pw.SizedBox(height: 15),
          _sectionTitle('COHORTES MENSUALES', bold, accent),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Mes',
              'Vencían',
              'Maduros',
              'Retenidos',
              'Salidas',
              'Retención',
              'Δ pp',
              'Cierre',
            ],
            data: [
              for (final item in cohorts)
                [
                  item['month'],
                  item['total_due'],
                  item['mature_eligible'],
                  item['retained'],
                  item['historical_exits'],
                  _pct(item['retention_rate_pct']),
                  item['retention_change_pp'] == null
                      ? '-'
                      : (item['retention_change_pp'] as num).toStringAsFixed(1),
                  item['provisional'] == true ? 'PROVISIONAL' : 'CERRADA',
                ],
            ],
            headerStyle: pw.TextStyle(font: bold, fontSize: 7, color: ink),
            cellStyle: pw.TextStyle(fontSize: 7, color: ink),
            headerDecoration: const pw.BoxDecoration(color: soft),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 4,
            ),
          ),
        ],
        if (planBreakdowns.isNotEmpty || trainerBreakdowns.isNotEmpty) ...[
          pw.SizedBox(height: 15),
          _sectionTitle('LUPA COMPARATIVA', bold, accent),
          pw.Text(
            'Las tasas usan solo casos maduros. Una muestra pequeña describe casos y no demuestra superioridad.',
            style: pw.TextStyle(fontSize: 7, color: muted),
          ),
          if (planBreakdowns.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            _breakdownTable('POR PLAN', planBreakdowns, bold, ink, soft),
          ],
          if (trainerBreakdowns.isNotEmpty) ...[
            pw.SizedBox(height: 9),
            _breakdownTable(
              'POR ENTRENADOR',
              trainerBreakdowns,
              bold,
              ink,
              soft,
            ),
            if ((breakdowns['unattributed_trainer_total'] as num).toInt() > 0)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text(
                  '${breakdowns['unattributed_trainer_total']} caso(s) sin entrenador quedan fuera de esta comparación.',
                  style: pw.TextStyle(fontSize: 6.5, color: muted),
                ),
              ),
          ],
        ],
        pw.SizedBox(height: 15),
        _sectionTitle('COLA FILTRADA', bold, accent),
        if (rows.isEmpty)
          pw.Text(
            'No existen socios en el resultado visible.',
            style: pw.TextStyle(fontSize: 8.5, color: muted),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const [
              'Renovación',
              'Socio / CI',
              'Plan',
              'Entrenador',
              'Estado',
              'Gestión',
              'Próxima',
            ],
            data: [
              for (final item in rows)
                [
                  item['expected_renewal_date'],
                  '${item['client_name']}\n${item['client_id']}',
                  item['plan'],
                  item['trainer'] ?? '-',
                  _label(item['state'] as String),
                  _label(item['management'] as String),
                  item['next_management_date'] ?? '-',
                ],
            ],
            headerStyle: pw.TextStyle(font: bold, fontSize: 7, color: ink),
            cellStyle: pw.TextStyle(fontSize: 7, color: ink),
            headerDecoration: const pw.BoxDecoration(color: soft),
            cellDecoration: (index, data, rowNum) => pw.BoxDecoration(
              color: rowNum.isEven ? paper : PdfColors.white,
              border: const pw.Border(
                bottom: pw.BorderSide(color: line, width: 0.35),
              ),
            ),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 4.5,
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.8),
              1: pw.FlexColumnWidth(1.6),
              2: pw.FlexColumnWidth(1.3),
              3: pw.FlexColumnWidth(1.2),
              4: pw.FlexColumnWidth(1),
              5: pw.FlexColumnWidth(1.1),
              6: pw.FlexColumnWidth(0.8),
            },
          ),
      ],
    ),
  );
  return document.save();
}

pw.Widget _breakdownTable(
  String title,
  List<Map<String, dynamic>> rows,
  pw.Font bold,
  PdfColor ink,
  PdfColor soft,
) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
  children: [
    pw.Text(
      title,
      style: pw.TextStyle(font: bold, fontSize: 7.5, color: ink),
    ),
    pw.SizedBox(height: 4),
    pw.TableHelper.fromTextArray(
      headers: const [
        'Categoría',
        'Maduros',
        'Retenidos',
        'Puntual',
        'En gracia',
        'Salidas',
        'Abiertos',
        'Retención',
      ],
      data: [
        for (final item in rows)
          [
            item['name'],
            item['mature_eligible'],
            item['retained'],
            item['renewed_on_time'],
            item['renewed_in_grace'],
            item['historical_exits'],
            item['open_cases'],
            _pct(item['retention_rate_pct']),
          ],
      ],
      headerStyle: pw.TextStyle(font: bold, fontSize: 6.5, color: ink),
      cellStyle: pw.TextStyle(fontSize: 6.5, color: ink),
      headerDecoration: pw.BoxDecoration(color: soft),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.8),
        1: pw.FlexColumnWidth(0.7),
        2: pw.FlexColumnWidth(0.8),
        3: pw.FlexColumnWidth(0.7),
        4: pw.FlexColumnWidth(0.8),
        5: pw.FlexColumnWidth(0.7),
        6: pw.FlexColumnWidth(0.7),
        7: pw.FlexColumnWidth(0.8),
      },
    ),
  ],
);

pw.Widget _metric(
  String label,
  String value,
  PdfColor color,
  pw.Font bold,
  pw.Font mono,
) => pw.Expanded(
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(font: mono, fontSize: 6, color: color),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        value,
        style: pw.TextStyle(font: bold, fontSize: 15, color: color),
      ),
    ],
  ),
);

pw.Widget _sectionTitle(String text, pw.Font bold, PdfColor accent) =>
    pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.only(left: 7),
      decoration: pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: accent, width: 3)),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: bold, fontSize: 8.5, letterSpacing: 0.7),
      ),
    );

String _pct(dynamic value) =>
    value == null ? '-' : '${(value as num).toStringAsFixed(1)}%';

String _label(String value) => value.replaceAll('_', ' ');

String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';
