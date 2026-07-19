import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/retention_report_export_service.dart';

enum RetentionExportOperation { idle, pdf, print, csv }

final retentionReportExportServiceProvider =
    Provider<RetentionReportExportService>((ref) {
      return RetentionReportExportService();
    });

class RetentionExportNotifier extends Notifier<RetentionExportOperation> {
  @override
  RetentionExportOperation build() => RetentionExportOperation.idle;

  Future<String?> savePdf(RetentionReportSnapshot snapshot) => _run(
    RetentionExportOperation.pdf,
    () => ref.read(retentionReportExportServiceProvider).savePdf(snapshot),
  );

  Future<String?> saveCsv(RetentionReportSnapshot snapshot) => _run(
    RetentionExportOperation.csv,
    () => ref.read(retentionReportExportServiceProvider).saveCsv(snapshot),
  );

  Future<bool> printPdf(RetentionReportSnapshot snapshot) => _run(
    RetentionExportOperation.print,
    () => ref.read(retentionReportExportServiceProvider).printPdf(snapshot),
  );

  Future<T> _run<T>(
    RetentionExportOperation operation,
    Future<T> Function() action,
  ) async {
    if (state != RetentionExportOperation.idle) {
      throw StateError('Ya existe una exportación en curso.');
    }
    state = operation;
    try {
      return await action();
    } finally {
      state = RetentionExportOperation.idle;
    }
  }
}

final retentionExportProvider =
    NotifierProvider.autoDispose<
      RetentionExportNotifier,
      RetentionExportOperation
    >(RetentionExportNotifier.new);
