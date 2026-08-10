import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/accounting/data/models/treasury_period_models.dart';
import 'package:gym_client/src/features/accounting/data/services/treasury_period_close_report_service.dart';

void main() {
  test('genera PDF y CSV R5.7 desde la captura SQLite real', () async {
    final repositoryRoot = Directory.current.parent;
    final evidenceDirectory = Directory(
      '${repositoryRoot.path}${Platform.pathSeparator}docs${Platform.pathSeparator}evidence${Platform.pathSeparator}r57',
    );
    final source = File(
      '${evidenceDirectory.path}${Platform.pathSeparator}summary-sqlite.json',
    );
    final decoded =
        jsonDecode(await source.readAsString()) as Map<String, dynamic>;
    final summary = TreasuryPeriodSummaryModel.fromJson(
      Map<String, dynamic>.from(decoded['custom'] as Map),
    );
    const service = TreasuryPeriodCloseReportService();
    final pdf = await service.buildPdf(summary);
    final csv = service.buildCsv(summary);
    final pdfFile = File(
      '${evidenceDirectory.path}${Platform.pathSeparator}treasury-period-2025-03-03-2025-03-06.pdf',
    );
    final csvFile = File(
      '${evidenceDirectory.path}${Platform.pathSeparator}treasury-period-2025-03-03-2025-03-06.csv',
    );
    await pdfFile.writeAsBytes(pdf, flush: true);
    await csvFile.writeAsBytes(csv, flush: true);

    expect(await pdfFile.length(), greaterThan(1000));
    expect(await csvFile.length(), greaterThan(100));
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
    expect(csv.take(3), [0xef, 0xbb, 0xbf]);
    // ignore: avoid_print
    print('${pdfFile.path} · ${await pdfFile.length()} bytes');
    // ignore: avoid_print
    print('${csvFile.path} · ${await csvFile.length()} bytes');
  });
}
