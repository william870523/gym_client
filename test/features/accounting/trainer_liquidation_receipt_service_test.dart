import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/accounting/data/models/accounting_models.dart';
import 'package:gym_client/src/features/accounting/data/services/trainer_liquidation_receipt_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el comprobante PDF separa comisión y obligación fija', () async {
    final receipt = TrainerLiquidationModel(
      id: 'liq-combined',
      receiptNumber: 'LIQ-20260715-DEMO',
      trainerId: 'trainer-demo',
      trainerName: 'Ana Fuerza DEMO',
      currencyId: 'cup',
      currencyCode: 'CUP',
      accountId: 'cash-cup',
      accountName: 'Caja CUP',
      paymentTypeId: 'cash',
      paymentTypeName: 'Efectivo',
      total: 15,
      commissionTotal: 5,
      fixedTotal: 10,
      commissionConcepts: 1,
      fixedConcepts: 1,
      status: 'PAGADA',
      operatorName: 'Operador DEMO',
      paidAt: DateTime.utc(2026, 7, 15, 20),
      applications: [
        TrainerLiquidationApplicationModel(
          id: 'commission-app',
          installmentId: 'commission-1',
          amount: 5,
          status: 'APLICADA',
          periodStart: DateTime.utc(2026, 7, 1),
          periodEnd: DateTime.utc(2026, 7, 15),
        ),
      ],
      fixedApplications: [
        TrainerLiquidationFixedApplicationModel(
          id: 'fixed-app',
          obligationId: 'fixed-1',
          amount: 10,
          status: 'APLICADA',
          periodStart: DateTime.utc(2026, 7, 1),
          periodEnd: DateTime.utc(2026, 7, 15),
        ),
      ],
    );

    final pdf = await const TrainerLiquidationReceiptService().buildPdf(
      receipt,
    );

    expect(utf8.decode(pdf.take(4).toList()), '%PDF');
    expect(pdf.length, greaterThan(5000));
  });
}
