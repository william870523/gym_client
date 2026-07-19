import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/accounting/data/models/accounting_models.dart';
import 'package:gym_client/src/features/accounting/data/services/treasury_refund_receipt_service.dart';

void main() {
  test('el comprobante PDF conserva salida, cliente y estado', () async {
    final receipt = TreasuryRefundReceiptModel(
      id: 'refund-1',
      adjustmentId: 'adjustment-1',
      receiptNumber: 'RMB-20260715-DEMO',
      clientId: 'DEMO-001',
      clientName: 'Paula Reembolso DEMO',
      planName: 'Trimestral',
      currencyCode: 'CUP',
      amount: 6000,
      status: 'CONFIRMADO',
      accountName: 'Caja CUP',
      paymentTypeName: 'Efectivo',
      reason: 'Salida autorizada por Tesorería.',
      requestReason: 'Baja del entrenador asignado.',
      operatorName: 'Administración',
      registeredAt: DateTime.utc(2026, 7, 15, 18),
      effectiveDate: DateTime.utc(2026, 7, 15),
      reversal: null,
    );
    final bytes = await const TreasuryRefundReceiptService().buildPdf(receipt);
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
