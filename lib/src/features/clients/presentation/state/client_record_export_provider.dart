import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/client_record_document.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/services/client_statement_export_service.dart';

enum ClientRecordExportOperation { idle, pdf, print, csv }

final clientStatementExportServiceProvider =
    Provider<ClientStatementExportService>((ref) {
      return ClientStatementExportService();
    });

class ClientRecordExportNotifier extends Notifier<ClientRecordExportOperation> {
  @override
  ClientRecordExportOperation build() => ClientRecordExportOperation.idle;

  Future<String?> savePdf(ClientStatementSnapshot snapshot) =>
      _run(ClientRecordExportOperation.pdf, () async {
        final service = ref.read(clientStatementExportServiceProvider);
        final bytes = await service.buildPdf(snapshot);
        await _register(
          snapshot,
          bytes,
          'PDF',
          'ARCHIVO',
          service.fileName(snapshot, 'pdf'),
        );
        return service.savePdfBytes(snapshot, bytes);
      });

  Future<String?> saveCsv(ClientStatementSnapshot snapshot) =>
      _run(ClientRecordExportOperation.csv, () async {
        final service = ref.read(clientStatementExportServiceProvider);
        final bytes = service.buildCsv(snapshot);
        await _register(
          snapshot,
          bytes,
          'CSV',
          'ARCHIVO',
          service.fileName(snapshot, 'csv'),
        );
        return service.saveCsvBytes(snapshot, bytes);
      });

  Future<bool> printPdf(ClientStatementSnapshot snapshot) =>
      _run(ClientRecordExportOperation.print, () async {
        final service = ref.read(clientStatementExportServiceProvider);
        final bytes = await service.buildPdf(snapshot);
        await _register(
          snapshot,
          bytes,
          'PDF',
          'IMPRESION',
          service.fileName(snapshot, 'pdf'),
        );
        return service.printPdfBytes(snapshot, bytes);
      });

  Future<void> _register(
    ClientStatementSnapshot snapshot,
    List<int> bytes,
    String format,
    String destination,
    String fileName,
  ) async {
    await ref
        .read(clientRepositoryProvider)
        .registerClientRecordDocument(
          clientId: snapshot.clientId,
          operationId: const Uuid().v4(),
          format: format,
          destination: destination,
          fileName: fileName,
          bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
          filters: {
            'alcance': snapshot.scope,
            'zona_horaria': snapshot.timezone,
            'membresias': snapshot.memberships.length,
            'pagos': snapshot.payments.length,
          },
        );
    ref.invalidate(clientRecordDocumentsProvider(snapshot.clientId));
  }

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

final clientRecordDocumentsProvider = FutureProvider.autoDispose
    .family<List<ClientRecordDocument>, String>((ref, clientId) {
      return ref
          .watch(clientRepositoryProvider)
          .getClientRecordDocuments(clientId);
    });
