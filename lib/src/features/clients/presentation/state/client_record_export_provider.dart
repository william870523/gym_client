import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/client_statement_export_service.dart';

enum ClientRecordExportOperation { idle, pdf, print, csv }

final clientStatementExportServiceProvider =
    Provider<ClientStatementExportService>((ref) {
      return ClientStatementExportService();
    });

class ClientRecordExportNotifier extends Notifier<ClientRecordExportOperation> {
  @override
  ClientRecordExportOperation build() => ClientRecordExportOperation.idle;

  Future<String?> savePdf(ClientStatementSnapshot snapshot) => _run(
    ClientRecordExportOperation.pdf,
    () => ref.read(clientStatementExportServiceProvider).savePdf(snapshot),
  );

  Future<String?> saveCsv(ClientStatementSnapshot snapshot) => _run(
    ClientRecordExportOperation.csv,
    () => ref.read(clientStatementExportServiceProvider).saveCsv(snapshot),
  );

  Future<bool> printPdf(ClientStatementSnapshot snapshot) => _run(
    ClientRecordExportOperation.print,
    () => ref.read(clientStatementExportServiceProvider).printPdf(snapshot),
  );

  Future<T> _run<T>(
    ClientRecordExportOperation operation,
    Future<T> Function() action,
  ) async {
    if (state != ClientRecordExportOperation.idle) {
      throw StateError('Ya existe una exportación en curso.');
    }
    state = operation;
    try {
      return await action();
    } finally {
      state = ClientRecordExportOperation.idle;
    }
  }
}

final clientRecordExportProvider =
    NotifierProvider.autoDispose<
      ClientRecordExportNotifier,
      ClientRecordExportOperation
    >(ClientRecordExportNotifier.new);
