import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/clients/data/models/client_record_model.dart';
import 'package:gym_client/src/features/clients/data/services/client_statement_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('estado de cuenta separa monedas y conserva el pago mixto', () async {
    final record = await _loadRecord();
    final snapshot = ClientStatementSnapshot.fromRecord(
      record: record,
      memberships: record.memberships,
      timezone: 'America/Los_Angeles',
      generatedAtUtc: DateTime.utc(2026, 7, 12, 20),
      scope: 'Todo el historial / Todos los planes / Todos los estados',
    );
    final service = ClientStatementExportService();

    expect(snapshot.totals, isNotEmpty);
    expect(snapshot.memberships.single.pauseSummary, contains('60 días'));
    expect(
      snapshot.memberships.single.pauseSummary,
      contains('Viaje familiar'),
    );
    expect(
      snapshot.totals.any(
        (item) => item.currency == 'CUP' && item.amount >= 9000,
      ),
      isTrue,
    );
    final csvBytes = service.buildCsv(snapshot);
    expect(csvBytes.take(3), [0xef, 0xbb, 0xbf]);
    final csv = utf8.decode(csvBytes, allowMalformed: true);
    expect(csv, contains('14.0625'));
    expect(csv, contains('ANULADO'));
    expect(csv, contains('America/Los_Angeles'));

    final pdf = await service.buildPdf(snapshot);
    expect(utf8.decode(pdf.take(4).toList()), '%PDF');
    expect(pdf.length, greaterThan(10000));

    const previewPath = String.fromEnvironment('GYMOS_PDF_PREVIEW_PATH');
    if (previewPath.isNotEmpty) {
      final file = File(previewPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(pdf, flush: true);
    }

    const csvPreviewPath = String.fromEnvironment('GYMOS_CSV_PREVIEW_PATH');
    if (csvPreviewPath.isNotEmpty) {
      final file = File(csvPreviewPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(csvBytes, flush: true);
    }
  });
}

Future<ClientRecordModel> _loadRecord() async {
  const recordPath = String.fromEnvironment('GYMOS_RECORD_JSON');
  if (recordPath.isNotEmpty) {
    final source = jsonDecode(await File(recordPath).readAsString());
    return ClientRecordModel.fromJson(Map<String, dynamic>.from(source as Map));
  }
  return _fixture();
}

ClientRecordModel _fixture() => ClientRecordModel(
  client: const ClientRecordIdentity(
    id: '99010100001',
    firstName: 'Marina Historia',
    lastName: 'DEMO',
  ),
  memberships: [
    ClientMembershipRecord(
      id: 'membership-1',
      planId: 'plan-coached',
      planName: 'Entrenamiento 3 meses',
      price: 9000,
      currencyId: 'cup',
      currencyCode: 'CUP',
      durationDays: 90,
      startDate: DateTime.utc(2025, 9, 1),
      endDate: DateTime.utc(2025, 11, 30),
      status: 'VENCIDA',
      origin: 'CAMBIO',
      paidAmount: 9000,
      reconstructed: false,
      pauses: [
        ClientMembershipPause(
          id: 'pause-active',
          pauseDate: DateTime.utc(2025, 10, 1),
          previousEndDate: DateTime.utc(2025, 11, 30),
          remainingDays: 60,
          reason: 'Viaje familiar',
          status: 'ACTIVA',
          pausedAt: DateTime.utc(2025, 10, 1, 16),
        ),
      ],
      trainers: const [],
      payments: [
        ClientRecordPayment(
          id: 'payment-mixed',
          date: DateTime.utc(2025, 9, 1, 15, 15),
          total: 9000,
          currencyId: 'cup',
          currencyCode: 'CUP',
          planId: 'plan-coached',
          applicationId: 'application-1',
          appliedAmount: 9000,
          details: const [
            ClientRecordPaymentDetail(
              id: 'detail-cup',
              paymentTypeId: 'cash',
              paymentTypeName: 'Efectivo',
              accountName: 'Caja CUP',
              currencyId: 'cup',
              currencyCode: 'CUP',
              amount: 4500,
            ),
            ClientRecordPaymentDetail(
              id: 'detail-usd',
              paymentTypeId: 'transfer',
              paymentTypeName: 'Transferencia',
              accountName: 'Caja USD',
              currencyId: 'usd',
              currencyCode: 'USD',
              amount: 14.0625,
              exchangeRateId: 'rate-usd-cup',
              exchangeRate: 320,
              exchangeRateBaseCurrencyId: 'usd',
              exchangeRateTargetCurrencyId: 'cup',
            ),
          ],
        ),
      ],
    ),
  ],
  unlinkedPayments: [
    ClientRecordPayment(
      id: 'payment-void',
      date: DateTime.utc(2026, 6, 1, 15, 25),
      total: 9000,
      currencyId: 'cup',
      currencyCode: 'CUP',
      planId: 'plan-coached',
      isVoided: true,
      voidedAt: DateTime.utc(2026, 6, 1, 15, 28),
    ),
  ],
  totalsByCurrency: const [],
);
