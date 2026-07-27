import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../models/accounting_models.dart';

class TreasuryMonthlyReportSnapshot {
  TreasuryMonthlyReportSnapshot({
    required this.month,
    required this.startDate,
    required this.endDate,
    required this.generatedAtUtc,
    required this.generatedAtLocal,
    required this.timezone,
    required this.scope,
    required this.includeDailyTrend,
    required this.currencies,
    this.collectors = const [],
    required this.closeState,
    this.closeId,
    this.closeActor,
    this.closeActorRole,
    this.closedAtLocal,
    this.closeReason,
    this.closeHash,
    this.closeIntegrityVerified = false,
  });

  final String month;
  final String startDate;
  final String endDate;
  final DateTime generatedAtUtc;
  final String generatedAtLocal;
  final String timezone;
  final String scope;
  final bool includeDailyTrend;
  final List<TreasuryMonthlyReportCurrency> currencies;
  /// R5.6 — cobros del mes por persona y moneda, tal y como los agrupa el
  /// servidor. Vacío en informes anteriores al corte.
  final List<TreasuryCollectorRowModel> collectors;
  final String closeState;
  final String? closeId;
  final String? closeActor;
  final String? closeActorRole;
  final String? closedAtLocal;
  final String? closeReason;
  final String? closeHash;
  final bool closeIntegrityVerified;

  Map<String, dynamic> toJson() => {
    'month': month,
    'start_date': startDate,
    'end_date': endDate,
    'generated_at_utc': generatedAtUtc.toUtc().toIso8601String(),
    'generated_at_local': generatedAtLocal,
    'timezone': timezone,
    'scope': scope,
    'include_daily_trend': includeDailyTrend,
    'currencies': currencies.map((item) => item.toJson()).toList(),
    'monthly_close': {
      'state': closeState,
      'id': closeId,
      'actor': closeActor,
      'actor_role': closeActorRole,
      'closed_at_local': closedAtLocal,
      'reason': closeReason,
      'sha256': closeHash,
      'integrity_verified': closeIntegrityVerified,
    },
  };
}

class TreasuryMonthlyReportCurrency {
  TreasuryMonthlyReportCurrency({
    required this.source,
    required this.accounts,
    required this.filteredToAccount,
  });

  final TreasuryMonthlyCurrencyModel source;
  final List<TreasuryMonthlyAccountModel> accounts;
  final bool filteredToAccount;

  double get entries => filteredToAccount
      ? accounts.fold(0, (sum, item) => sum + item.entries)
      : source.entries;
  double get exits => filteredToAccount
      ? accounts.fold(0, (sum, item) => sum + item.exits)
      : source.exits;
  double get net => entries - exits;
  int get movementCount => filteredToAccount
      ? accounts.fold(0, (sum, item) => sum + item.movementCount)
      : source.movementCount;
  int get activityJourneys => filteredToAccount
      ? accounts.fold(0, (sum, item) => sum + item.activityDays)
      : source.activityJourneys;
  int get closedJourneys => filteredToAccount
      ? accounts.fold(0, (sum, item) => sum + item.closedJourneys)
      : source.closedJourneys;
  int get openJourneys => activityJourneys - closedJourneys;
  double get closeCoverage =>
      activityJourneys == 0 ? 100 : (closedJourneys / activityJourneys * 100);
  int get closeCount => filteredToAccount
      ? accounts.fold(0, (sum, item) => sum + item.closeCount)
      : source.closeCount;
  int get approvedCloseCount => filteredToAccount
      ? accounts.fold(0, (sum, item) => sum + item.approvedCloseCount)
      : source.approvedCloseCount;
  int get withinToleranceCloseCount => filteredToAccount
      ? accounts.fold(0, (sum, item) => sum + item.withinToleranceCloseCount)
      : source.withinToleranceCloseCount;
  int get pendingApprovalCount => filteredToAccount
      ? accounts.fold(0, (sum, item) => sum + item.pendingApprovalCount)
      : source.pendingApprovalCount;
  int get rejectedRequestCount => filteredToAccount
      ? accounts.fold(0, (sum, item) => sum + item.rejectedRequestCount)
      : source.rejectedRequestCount;
  int get obsoleteRequestCount => filteredToAccount
      ? accounts.fold(0, (sum, item) => sum + item.obsoleteRequestCount)
      : source.obsoleteRequestCount;
  int get reconciliationCount => filteredToAccount
      ? accounts.fold(0, (sum, item) => sum + item.reconciliationCount)
      : source.reconciliationCount;
  double get monthlyReconciledAdjustments => filteredToAccount
      ? accounts.fold(0, (sum, item) => sum + item.monthlyReconciledAdjustments)
      : source.monthlyReconciledAdjustments;
  int get pendingLateMovementCount => filteredToAccount
      ? accounts.fold(0, (sum, item) => sum + item.pendingLateMovementCount)
      : source.pendingLateMovementCount;
  int get pendingReviewCount => filteredToAccount
      ? accounts.fold(0, (sum, item) => sum + item.pendingReviewCount)
      : source.pendingReviewCount;
  int get unassignedMovementCount =>
      filteredToAccount ? 0 : source.unassignedMovementCount;
  int get accountsWithoutClose => filteredToAccount
      ? accounts.where((item) => item.status == 'SIN_CIERRE').length
      : source.accountsWithoutClose;
  double get originalCloseBalance => filteredToAccount
      ? accounts.fold(0, (sum, item) => sum + (item.originalCloseBalance ?? 0))
      : source.originalCloseBalance;
  double get currentAdjustments => filteredToAccount
      ? accounts.fold(0, (sum, item) => sum + (item.currentAdjustments ?? 0))
      : source.currentAdjustments;
  double get currentBalance => filteredToAccount
      ? accounts.fold(0, (sum, item) => sum + (item.currentBalance ?? 0))
      : source.currentBalance;
  double get pendingCloseNet => filteredToAccount
      ? accounts.fold(0, (sum, item) => sum + item.pendingCloseNet)
      : source.pendingCloseNet;
  List<TreasuryMonthlyTrendModel> get trend =>
      filteredToAccount ? const [] : source.trend;

  bool get requiresAttention =>
      openJourneys > 0 ||
      pendingApprovalCount > 0 ||
      pendingLateMovementCount > 0 ||
      pendingReviewCount > 0 ||
      unassignedMovementCount > 0 ||
      accountsWithoutClose > 0;

  Map<String, dynamic> toJson() => {
    'currency_id': source.currencyId,
    'currency_code': source.currencyCode,
    'entries': entries,
    'exits': exits,
    'net': net,
    'movement_count': movementCount,
    'activity_journeys': activityJourneys,
    'closed_journeys': closedJourneys,
    'open_journeys': openJourneys,
    'close_coverage': closeCoverage,
    'close_count': closeCount,
    'approved_close_count': approvedCloseCount,
    'within_tolerance_close_count': withinToleranceCloseCount,
    'pending_approval_count': pendingApprovalCount,
    'rejected_request_count': rejectedRequestCount,
    'obsolete_request_count': obsoleteRequestCount,
    'reconciliation_count': reconciliationCount,
    'monthly_reconciled_adjustments': monthlyReconciledAdjustments,
    'pending_late_movement_count': pendingLateMovementCount,
    'pending_review_count': pendingReviewCount,
    'unassigned_movement_count': unassignedMovementCount,
    'accounts_without_close': accountsWithoutClose,
    'original_close_balance': originalCloseBalance,
    'current_adjustments': currentAdjustments,
    'current_balance': currentBalance,
    'pending_close_net': pendingCloseNet,
    'requires_attention': requiresAttention,
    'accounts': accounts.map(_accountToJson).toList(),
    'trend': trend.map(_trendToJson).toList(),
  };
}

class TreasuryMonthlyReportService {
  const TreasuryMonthlyReportService();

  TreasuryMonthlyReportSnapshot snapshot({
    required TreasuryMonthlySummaryModel summary,
    required bool allCurrencies,
    required String selectedCurrencyId,
    String? accountId,
    bool includeDailyTrend = true,
    DateTime? generatedAtUtc,
    String? timezone,
  }) {
    final generated = (generatedAtUtc ?? appClock.nowUtc()).toUtc();
    final gymTimezone = timezone ?? appClock.gymTimezone;
    final sources = allCurrencies
        ? summary.currencies
        : summary.currencies
              .where((item) => item.currencyId == selectedCurrencyId)
              .toList();
    final reportCurrencies = <TreasuryMonthlyReportCurrency>[];
    for (final source in sources) {
      final selectedAccounts = accountId == null
          ? source.accounts
          : source.accounts.where((item) => item.id == accountId).toList();
      if (accountId != null && selectedAccounts.isEmpty) continue;
      reportCurrencies.add(
        TreasuryMonthlyReportCurrency(
          source: source,
          accounts: selectedAccounts,
          filteredToAccount: accountId != null,
        ),
      );
    }
    if (reportCurrencies.isEmpty) {
      throw StateError('El alcance elegido no contiene datos exportables.');
    }
    final account = accountId == null
        ? null
        : reportCurrencies.first.accounts.first;
    final close = summary.monthlyClose.currentCycle;
    final closedAt = close == null ? null : DateTime.tryParse(close.closedAt);
    return TreasuryMonthlyReportSnapshot(
      month: summary.month,
      startDate: summary.startDate,
      endDate: summary.endDate,
      generatedAtUtc: generated,
      generatedAtLocal: formatDateInZone(
        generated,
        gymTimezone,
        pattern: 'dd/MM/yyyy HH:mm',
      ),
      timezone: gymTimezone,
      scope: allCurrencies
          ? 'Todas las monedas, separadas por sección'
          : account == null
          ? 'Moneda ${reportCurrencies.first.source.currencyCode} · todas las cuentas'
          : 'Moneda ${reportCurrencies.first.source.currencyCode} · cuenta ${account.name}',
      includeDailyTrend: includeDailyTrend && accountId == null,
      currencies: reportCurrencies,
      // Solo las monedas que el informe incluye: exportar un alcance de una
      // moneda no debe arrastrar los cobros de otra.
      collectors: summary.collectorRows
          .where(
            (row) => reportCurrencies.any(
              (currency) => currency.source.currencyId == row.currencyId,
            ),
          )
          .toList(growable: false),
      closeState: summary.monthlyClose.state,
      closeId: close?.id,
      closeActor: close?.closerName,
      closeActorRole: close?.closerRole,
      closedAtLocal: closedAt == null
          ? null
          : formatDateInZone(
              closedAt,
              gymTimezone,
              pattern: 'dd/MM/yyyy HH:mm',
            ),
      closeReason: close?.closeReason,
      closeHash: close?.hash,
      closeIntegrityVerified: close?.integrityVerified ?? false,
    );
  }

  Future<Uint8List> buildPdf(TreasuryMonthlyReportSnapshot snapshot) async {
    final regularFont = await rootBundle.load(
      'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
    );
    final boldFont = await rootBundle.load(
      'assets/fonts/AtkinsonHyperlegible-Bold.ttf',
    );
    final monoFont = await rootBundle.load(
      'assets/fonts/IBMPlexMono-Regular.ttf',
    );
    return compute(_renderTreasuryMonthlyPdf, {
      'snapshot': snapshot.toJson(),
      'regular_font': _fontBytes(regularFont),
      'bold_font': _fontBytes(boldFont),
      'mono_font': _fontBytes(monoFont),
    });
  }

  Uint8List buildCsv(TreasuryMonthlyReportSnapshot snapshot) {
    final rows = <List<String>>[
      const [
        'tipo_fila',
        'mes',
        'moneda',
        'cuenta',
        // R5.6: vacío salvo en las filas COBRADOR.
        'cobrado_por',
        'fecha',
        'estado',
        'entradas',
        'salidas',
        'neto',
        'movimientos',
        'jornadas_actividad',
        'jornadas_cerradas',
        'jornadas_por_cerrar',
        'cobertura_cierre_pct',
        'cierres',
        'cierres_aprobados',
        'cierres_dentro_tolerancia',
        'solicitudes_pendientes',
        'solicitudes_rechazadas',
        'solicitudes_obsoletas',
        'conciliaciones',
        'ajustes_conciliados_mes',
        'movimientos_tardios_pendientes',
        'revisiones_pendientes',
        'movimientos_sin_cuenta',
        'cuentas_sin_cierre',
        'saldo_cierre_original',
        'ajustes_vigentes',
        'saldo_vigente',
        'neto_pendiente_cierre',
        'alcance',
        'zona_horaria',
        'generado_at_utc',
        'cierre_mensual_estado',
        'cierre_mensual_id',
        'firmado_por',
        'firmado_rol',
        'firmado_at_local',
        'resumen_sha256',
        'integridad_verificada',
      ],
    ];
    for (final currency in snapshot.currencies) {
      rows.add([
        'MONEDA',
        snapshot.month,
        currency.source.currencyCode,
        '',
        '',
        '',
        currency.requiresAttention ? 'REQUIERE_ATENCION' : 'AL_DIA',
        _number(currency.entries),
        _number(currency.exits),
        _number(currency.net),
        '${currency.movementCount}',
        '${currency.activityJourneys}',
        '${currency.closedJourneys}',
        '${currency.openJourneys}',
        currency.closeCoverage.toStringAsFixed(1),
        '${currency.closeCount}',
        '${currency.approvedCloseCount}',
        '${currency.withinToleranceCloseCount}',
        '${currency.pendingApprovalCount}',
        '${currency.rejectedRequestCount}',
        '${currency.obsoleteRequestCount}',
        '${currency.reconciliationCount}',
        _number(currency.monthlyReconciledAdjustments),
        '${currency.pendingLateMovementCount}',
        '${currency.pendingReviewCount}',
        '${currency.unassignedMovementCount}',
        '${currency.accountsWithoutClose}',
        _number(currency.originalCloseBalance),
        _number(currency.currentAdjustments),
        _number(currency.currentBalance),
        _number(currency.pendingCloseNet),
        snapshot.scope,
        snapshot.timezone,
        snapshot.generatedAtUtc.toIso8601String(),
        ..._closureCsv(snapshot),
      ]);
      for (final account in currency.accounts) {
        rows.add([
          'CUENTA',
          snapshot.month,
          account.currencyCode,
          account.name,
          '',
          account.lastCloseDate ?? '',
          account.status,
          _number(account.entries),
          _number(account.exits),
          _number(account.net),
          '${account.movementCount}',
          '${account.activityDays}',
          '${account.closedJourneys}',
          '${account.openJourneys}',
          account.activityDays == 0
              ? '100.0'
              : (account.closedJourneys / account.activityDays * 100)
                    .toStringAsFixed(1),
          '${account.closeCount}',
          '${account.approvedCloseCount}',
          '${account.withinToleranceCloseCount}',
          '${account.pendingApprovalCount}',
          '${account.rejectedRequestCount}',
          '${account.obsoleteRequestCount}',
          '${account.reconciliationCount}',
          _number(account.monthlyReconciledAdjustments),
          '${account.pendingLateMovementCount}',
          '${account.pendingReviewCount}',
          '',
          account.status == 'SIN_CIERRE' ? '1' : '0',
          account.originalCloseBalance == null
              ? ''
              : _number(account.originalCloseBalance!),
          account.currentAdjustments == null
              ? ''
              : _number(account.currentAdjustments!),
          account.currentBalance == null
              ? ''
              : _number(account.currentBalance!),
          _number(account.pendingCloseNet),
          snapshot.scope,
          snapshot.timezone,
          snapshot.generatedAtUtc.toIso8601String(),
          ..._closureCsv(snapshot),
        ]);
      }
      // R5.6 — una fila por persona dentro de esta moneda. Van con su propio
      // `tipo_fila` para que nadie las sume con las de cuenta o de día: son la
      // misma plata mirada por quien la recibió.
      for (final collector in snapshot.collectors.where(
        (row) => row.currencyId == currency.source.currencyId,
      )) {
        rows.add([
          'COBRADOR',
          snapshot.month,
          collector.currencyCode,
          collector.accountName,
          collector.unattributed
              ? 'Sin atribuir · histórico'
              : collector.name,
          '',
          collector.unattributed
              ? 'SIN_ATRIBUIR'
              : (collector.role ?? collector.origin ?? ''),
          _number(collector.gross),
          _number(collector.annulled),
          _number(collector.net),
          '${collector.payments}',
          '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '',
          '', '', '',
          snapshot.scope,
          snapshot.timezone,
          snapshot.generatedAtUtc.toIso8601String(),
          ..._closureCsv(snapshot),
        ]);
      }
      if (snapshot.includeDailyTrend) {
        for (final day in currency.trend) {
          rows.add([
            'DIA',
            snapshot.month,
            currency.source.currencyCode,
            '',
            '',
            day.businessDate,
            '',
            _number(day.entries),
            _number(day.exits),
            _number(day.net),
            '',
            '',
            '',
            '',
            '',
            '',
            '${day.closeCount}',
            '',
            '',
            '',
            '',
            '',
            '',
            _number(day.reconciledAdjustments),
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            snapshot.scope,
            snapshot.timezone,
            snapshot.generatedAtUtc.toIso8601String(),
            ..._closureCsv(snapshot),
          ]);
        }
      }
    }
    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
    return Uint8List.fromList([0xef, 0xbb, 0xbf, ...utf8.encode(csv)]);
  }

  Future<String?> savePdf(TreasuryMonthlyReportSnapshot snapshot) async {
    final bytes = await buildPdf(snapshot);
    return FilePicker.platform.saveFile(
      dialogTitle: 'Guardar consolidado mensual en PDF',
      fileName: _fileName(snapshot, 'pdf'),
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: bytes,
      lockParentWindow: true,
    );
  }

  Future<String?> saveCsv(TreasuryMonthlyReportSnapshot snapshot) {
    return FilePicker.platform.saveFile(
      dialogTitle: 'Guardar consolidado mensual en CSV',
      fileName: _fileName(snapshot, 'csv'),
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      bytes: buildCsv(snapshot),
      lockParentWindow: true,
    );
  }

  Future<bool> printPdf(TreasuryMonthlyReportSnapshot snapshot) async {
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

  String _fileName(TreasuryMonthlyReportSnapshot snapshot, String extension) {
    final code = snapshot.currencies.length == 1
        ? snapshot.currencies.first.source.currencyCode.toLowerCase()
        : 'multimoneda';
    return 'tesoreria-mensual-${snapshot.month}-$code.$extension';
  }
}

Map<String, dynamic> _accountToJson(TreasuryMonthlyAccountModel account) => {
  'id': account.id,
  'name': account.name,
  'currency_code': account.currencyCode,
  'entries': account.entries,
  'exits': account.exits,
  'net': account.net,
  'movement_count': account.movementCount,
  'activity_days': account.activityDays,
  'closed_journeys': account.closedJourneys,
  'open_journeys': account.openJourneys,
  'close_count': account.closeCount,
  'approved_close_count': account.approvedCloseCount,
  'within_tolerance_close_count': account.withinToleranceCloseCount,
  'pending_approval_count': account.pendingApprovalCount,
  'rejected_request_count': account.rejectedRequestCount,
  'obsolete_request_count': account.obsoleteRequestCount,
  'reconciliation_count': account.reconciliationCount,
  'monthly_reconciled_adjustments': account.monthlyReconciledAdjustments,
  'pending_late_movement_count': account.pendingLateMovementCount,
  'pending_review_count': account.pendingReviewCount,
  'last_close_date': account.lastCloseDate,
  'original_close_balance': account.originalCloseBalance,
  'current_adjustments': account.currentAdjustments,
  'current_balance': account.currentBalance,
  'pending_close_net': account.pendingCloseNet,
  'status': account.status,
};

Map<String, dynamic> _trendToJson(TreasuryMonthlyTrendModel item) => {
  'business_date': item.businessDate,
  'entries': item.entries,
  'exits': item.exits,
  'net': item.net,
  'close_count': item.closeCount,
  'reconciled_adjustments': item.reconciledAdjustments,
};

String _number(double value) => value.toStringAsFixed(2);

List<String> _closureCsv(TreasuryMonthlyReportSnapshot snapshot) => [
  snapshot.closeState,
  snapshot.closeId ?? '',
  snapshot.closeActor ?? '',
  snapshot.closeActorRole ?? '',
  snapshot.closedAtLocal ?? '',
  snapshot.closeHash ?? '',
  snapshot.closeIntegrityVerified ? 'SI' : 'NO',
];

String _csvCell(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

Future<Uint8List> _renderTreasuryMonthlyPdf(
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
    title: 'Consolidado mensual de Tesorería ${snapshot['month']}',
    author: 'GymOS',
    subject: 'Flujo, cierres, aprobaciones y conciliaciones por moneda',
  );
  const ink = PdfColor.fromInt(0xff24211d);
  const muted = PdfColor.fromInt(0xff706a61);
  const line = PdfColor.fromInt(0xffd7cfc3);
  const accent = PdfColor.fromInt(0xffd94a24);
  const warning = PdfColor.fromInt(0xff9a6a12);
  const success = PdfColor.fromInt(0xff2f7654);
  const paper = PdfColor.fromInt(0xfff3ede5);
  final money = NumberFormat('#,##0.00', 'en_US');
  final currencies = (snapshot['currencies'] as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
  final monthlyClose = Map<String, dynamic>.from(
    snapshot['monthly_close'] as Map? ?? const <String, dynamic>{},
  );
  final periodClosed = monthlyClose['state'] == 'CERRADO';

  pw.TextStyle textStyle({
    double size = 8,
    PdfColor color = ink,
    bool strong = false,
    bool monospace = false,
  }) => pw.TextStyle(
    font: monospace ? mono : (strong ? bold : regular),
    fontSize: size,
    color: color,
  );

  String amount(dynamic value) => money.format((value as num?) ?? 0);

  pw.Widget metric(String label, String value, {bool highlight = false}) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(9),
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
                style: textStyle(size: 6.5, color: muted),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                value,
                style: textStyle(
                  size: highlight ? 14 : 11,
                  color: highlight ? accent : ink,
                  strong: true,
                  monospace: true,
                ),
              ),
            ],
          ),
        ),
      );

  pw.Widget cell(
    String value, {
    bool strong = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor color = ink,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
    child: pw.Text(
      value,
      textAlign: align,
      style: textStyle(size: 6.5, color: color, strong: strong),
    ),
  );

  pw.Widget dailyChart(Map<String, dynamic> currency) {
    final trend = (currency['trend'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where(
          (item) =>
              ((item['entries'] as num?) ?? 0) != 0 ||
              ((item['exits'] as num?) ?? 0) != 0,
        )
        .toList();
    if (trend.isEmpty) {
      return pw.Text(
        'Sin jornadas con flujo para representar.',
        style: textStyle(color: muted),
      );
    }
    final maxMagnitude = trend
        .map((item) => (((item['net'] as num?) ?? 0).toDouble()).abs())
        .fold<double>(0, (max, value) => value > max ? value : max);
    return pw.Container(
      height: 66,
      padding: const pw.EdgeInsets.fromLTRB(8, 8, 8, 4),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: line)),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          for (final day in trend)
            pw.Expanded(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 8,
                    height: maxMagnitude == 0
                        ? 2
                        : 5 +
                              ((((day['net'] as num?) ?? 0).toDouble().abs() /
                                      maxMagnitude) *
                                  34),
                    color: ((day['net'] as num?) ?? 0) < 0 ? warning : success,
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    day['business_date'].toString().substring(8),
                    style: textStyle(size: 5.5, color: muted, monospace: true),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  final content = <pw.Widget>[
    pw.Container(height: 3, color: ink),
    pw.SizedBox(height: 14),
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'GYMOS · TESORERÍA',
              style: textStyle(size: 7, color: muted),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'CONSOLIDADO MENSUAL',
              style: textStyle(size: 23, strong: true),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              '${snapshot['start_date']} al ${snapshot['end_date']}',
              style: textStyle(size: 9, color: muted, monospace: true),
            ),
          ],
        ),
        pw.Container(
          width: 260,
          padding: const pw.EdgeInsets.all(10),
          color: paper,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'ALCANCE',
                style: textStyle(size: 6.5, color: muted, strong: true),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                snapshot['scope'].toString(),
                style: textStyle(size: 8, strong: true),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Emitido ${snapshot['generated_at_local']} · ${snapshot['timezone']}',
                style: textStyle(size: 7, color: muted),
              ),
            ],
          ),
        ),
      ],
    ),
    pw.SizedBox(height: 14),
    pw.Text(
      currencies.length == 1
          ? 'La moneda se presenta en su unidad original; no se aplican tasas ni conversiones.'
          : 'Cada moneda conserva su sección y unidad original. No existe un total general que mezcle divisas.',
      style: textStyle(size: 8, color: muted),
    ),
    pw.SizedBox(height: 10),
    pw.Container(
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: periodClosed
            ? const PdfColor.fromInt(0xffe5f1e9)
            : const PdfColor.fromInt(0xfffff3da),
        border: pw.Border.all(color: periodClosed ? success : warning),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                periodClosed
                    ? 'PERÍODO CERRADO Y FIRMADO'
                    : 'PERÍODO ABIERTO · INFORME NO FIRMADO',
                style: textStyle(
                  size: 8,
                  color: periodClosed ? success : warning,
                  strong: true,
                ),
              ),
              pw.Text(
                periodClosed && monthlyClose['integrity_verified'] == true
                    ? 'SHA-256 VERIFICADO'
                    : periodClosed
                    ? 'REVISAR INTEGRIDAD'
                    : 'BORRADOR OPERATIVO',
                style: textStyle(
                  size: 7,
                  color: periodClosed ? success : warning,
                  strong: true,
                  monospace: true,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            periodClosed
                ? 'Firmó ${monthlyClose['actor']} (${monthlyClose['actor_role']}) · ${monthlyClose['closed_at_local']} · ${snapshot['timezone']}'
                : 'Las cifras pueden cambiar hasta que un rol autorizado complete el cierre mensual.',
            style: textStyle(size: 7, color: muted),
          ),
          if (periodClosed) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              'Motivo: ${monthlyClose['reason']}',
              style: textStyle(size: 7, color: ink),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Huella: ${monthlyClose['sha256']}',
              style: textStyle(size: 6.5, color: muted, monospace: true),
            ),
          ],
        ],
      ),
    ),
  ];

  for (
    var currencyIndex = 0;
    currencyIndex < currencies.length;
    currencyIndex++
  ) {
    final currency = currencies[currencyIndex];
    if (currencyIndex > 0) content.add(pw.NewPage());
    final code = currency['currency_code'].toString();
    final attention = currency['requires_attention'] == true;
    final accounts = (currency['accounts'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    content.addAll([
      pw.SizedBox(height: 18),
      pw.Column(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            color: ink,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '$code · RESUMEN EJECUTIVO',
                  style: textStyle(
                    size: 10,
                    color: PdfColors.white,
                    strong: true,
                  ),
                ),
                pw.Text(
                  attention ? 'REQUIERE ATENCIÓN' : 'AL DÍA',
                  style: textStyle(
                    size: 8,
                    color: attention ? PdfColors.orange200 : PdfColors.green200,
                    strong: true,
                  ),
                ),
              ],
            ),
          ),
          pw.Row(
            children: [
              metric(
                'Entradas',
                '$code ${amount(currency['entries'])}',
                highlight: true,
              ),
              metric('Salidas', '$code ${amount(currency['exits'])}'),
              metric('Flujo neto', '$code ${amount(currency['net'])}'),
              metric(
                'Cobertura de cierre',
                '${(currency['close_coverage'] as num).toStringAsFixed(1)}%',
              ),
            ],
          ),
          pw.Row(
            children: [
              metric(
                'Saldo original',
                '$code ${amount(currency['original_close_balance'])}',
              ),
              metric(
                'Ajustes vigentes',
                '$code ${amount(currency['current_adjustments'])}',
              ),
              metric(
                'Saldo vigente',
                '$code ${amount(currency['current_balance'])}',
                highlight: true,
              ),
              metric(
                'Neto por cerrar',
                '$code ${amount(currency['pending_close_net'])}',
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(9),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: attention ? warning : success),
            ),
            child: pw.Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                pw.Text(
                  '${currency['closed_journeys']}/${currency['activity_journeys']} jornadas cerradas',
                  style: textStyle(size: 7.5, strong: true),
                ),
                pw.Text(
                  '${currency['approved_close_count']} cierres aprobados',
                  style: textStyle(size: 7.5),
                ),
                pw.Text(
                  '${currency['within_tolerance_close_count']} dentro de tolerancia',
                  style: textStyle(size: 7.5),
                ),
                pw.Text(
                  '${currency['pending_approval_count']} aprobación pendiente',
                  style: textStyle(size: 7.5, color: attention ? warning : ink),
                ),
                pw.Text(
                  '${currency['reconciliation_count']} conciliaciones',
                  style: textStyle(size: 7.5),
                ),
                pw.Text(
                  '${currency['pending_late_movement_count']} tardíos pendientes',
                  style: textStyle(size: 7.5, color: attention ? warning : ink),
                ),
                pw.Text(
                  '${currency['pending_review_count']} revisiones pendientes',
                  style: textStyle(size: 7.5, color: attention ? warning : ink),
                ),
                pw.Text(
                  '${currency['unassigned_movement_count']} movimientos sin cuenta',
                  style: textStyle(size: 7.5, color: attention ? warning : ink),
                ),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 11),
      pw.Text(
        'DESGLOSE POR CUENTA',
        style: textStyle(size: 8, color: muted, strong: true),
      ),
      pw.SizedBox(height: 5),
      pw.Table(
        border: const pw.TableBorder(
          top: pw.BorderSide(color: line),
          bottom: pw.BorderSide(color: line),
          horizontalInside: pw.BorderSide(color: line),
        ),
        columnWidths: const {
          0: pw.FlexColumnWidth(2.2),
          1: pw.FlexColumnWidth(1.1),
          2: pw.FlexColumnWidth(1),
          3: pw.FlexColumnWidth(1),
          4: pw.FlexColumnWidth(1),
          5: pw.FlexColumnWidth(1.1),
          6: pw.FlexColumnWidth(1.2),
          7: pw.FlexColumnWidth(1.2),
          8: pw.FlexColumnWidth(1.2),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: paper),
            children: [
              cell('CUENTA', strong: true),
              cell('ESTADO', strong: true),
              cell('ENTRADAS', strong: true, align: pw.TextAlign.right),
              cell('SALIDAS', strong: true, align: pw.TextAlign.right),
              cell('NETO', strong: true, align: pw.TextAlign.right),
              cell('CIERRE', strong: true),
              cell('APROBACIÓN', strong: true),
              cell('INCIDENCIAS', strong: true),
              cell('SALDO VIGENTE', strong: true, align: pw.TextAlign.right),
            ],
          ),
          for (final account in accounts)
            pw.TableRow(
              children: [
                cell(account['name'].toString(), strong: true),
                cell(account['status'].toString().replaceAll('_', ' ')),
                cell(amount(account['entries']), align: pw.TextAlign.right),
                cell(amount(account['exits']), align: pw.TextAlign.right),
                cell(amount(account['net']), align: pw.TextAlign.right),
                cell(
                  '${account['closed_journeys']}/${account['activity_days']} jornadas',
                ),
                cell(
                  '${account['approved_close_count']} aprob. · ${account['pending_approval_count']} pend.',
                ),
                cell(
                  '${account['pending_late_movement_count']} tard. · ${account['pending_review_count']} rev.',
                  color:
                      ((account['pending_late_movement_count'] as num) > 0 ||
                          (account['pending_review_count'] as num) > 0)
                      ? warning
                      : ink,
                ),
                cell(
                  account['current_balance'] == null
                      ? '—'
                      : amount(account['current_balance']),
                  align: pw.TextAlign.right,
                ),
              ],
            ),
        ],
      ),
    ]);
    if (snapshot['include_daily_trend'] == true &&
        (currency['trend'] as List).isNotEmpty) {
      content.addAll([
        pw.SizedBox(height: 12),
        pw.Text(
          'FLUJO NETO POR JORNADA · MAGNITUD Y SIGNO',
          style: textStyle(size: 8, color: muted, strong: true),
        ),
        pw.SizedBox(height: 5),
        dailyChart(currency),
      ]);
    }
  }

  content.addAll([
    pw.SizedBox(height: 16),
    pw.Text(
      'Documento de control. Los importes conservan su moneda original; los cierres y conciliaciones proceden del libro auditable de Tesorería.',
      style: textStyle(size: 7, color: muted),
    ),
  ]);

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 26),
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
              'GymOS · ${snapshot['month']} · ${snapshot['timezone']}',
              style: textStyle(size: 6.5, color: muted),
            ),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: textStyle(size: 6.5, color: muted, monospace: true),
            ),
          ],
        ),
      ),
      build: (_) => content,
    ),
  );
  return document.save();
}
