import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/accounting/data/models/accounting_models.dart';
import 'package:gym_client/src/features/accounting/data/services/treasury_daily_close_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'el cierre diario genera un informe con su libro de movimientos',
    () async {
      final close = TreasuryCloseModel(
        id: 'close-demo',
        operationId: 'operation-demo',
        receiptNumber: 'CIE-20260715-DEMO',
        businessDate: '2026-07-15',
        accountId: 'cash-cup',
        currencyId: 'cup',
        openingBalance: 100,
        entries: 50,
        exits: 15,
        expectedBalance: 135,
        countedBalance: 140,
        difference: 5,
        approvalState: 'APROBADA',
        appliedTolerance: 2,
        requestId: 'request-demo',
        varianceReason: 'Diferencia verificada contra el efectivo contado.',
        approverName: 'Administración DEMO',
        approverRole: 'admin',
        approvedAt: DateTime.utc(2026, 7, 15, 21, 5),
        movementCount: 2,
        movementsThrough: DateTime.utc(2026, 7, 15, 20),
        operatorName: 'Operador DEMO',
        closedAt: DateTime.utc(2026, 7, 15, 21),
      );
      final account = TreasuryAccountDayModel(
        id: 'cash-cup',
        name: 'Caja CUP',
        currencyId: 'cup',
        currencyCode: 'CUP',
        entries: 50,
        exits: 15,
        net: 35,
        movementCount: 2,
        reviewCount: 0,
        suggestedOpeningBalance: 100,
        status: 'CONCILIADO',
        lateMovementCount: 0,
        reconciledMovementCount: 1,
        adjustedBalance: 155,
        reconciliations: [
          TreasuryReconciliationModel(
            id: 'reconciliation-demo',
            receiptNumber: 'CON-20260715-DEMO',
            closeId: 'close-demo',
            movementCount: 1,
            entries: 15,
            exits: 0,
            netAdjustment: 15,
            originalCloseBalance: 140,
            adjustedBalance: 155,
            reason: 'Movimiento sincronizado después del cierre.',
            evidenceReference: 'SYNC-20260715-01',
            operatorName: 'Operador DEMO',
            registeredAt: DateTime.utc(2026, 7, 16, 1),
            movementIds: const ['entry-demo'],
          ),
        ],
        close: close,
      );
      final ledger = TreasuryLedgerModel(
        businessDate: '2026-07-15',
        currencySummaries: const [
          TreasuryCurrencySummaryModel(
            currencyId: 'cup',
            currencyCode: 'CUP',
            entries: 50,
            exits: 15,
            net: 35,
            movementCount: 2,
          ),
        ],
        accounts: [account],
        movements: [
          TreasuryMovementModel(
            id: 'entry-demo',
            sourceType: 'PAGO_CLIENTE',
            sourceId: 'payment-demo',
            direction: 'ENTRADA',
            concept: 'PLAN_CLIENTE',
            accountId: 'cash-cup',
            accountName: 'Caja CUP',
            currencyId: 'cup',
            currencyCode: 'CUP',
            paymentTypeId: 'cash',
            paymentTypeName: 'Efectivo',
            amount: 50,
            occurredAt: DateTime.utc(2026, 7, 15, 16),
            description: 'Cobro de plan',
            counterMovementId: null,
            requiresReview: false,
            reviewReason: null,
            late: false,
            reconciled: true,
          ),
          TreasuryMovementModel(
            id: 'exit-demo',
            sourceType: 'LIQUIDACION_ENTRENADOR',
            sourceId: 'settlement-demo',
            direction: 'SALIDA',
            concept: 'PAGO_ENTRENADOR',
            accountId: 'cash-cup',
            accountName: 'Caja CUP',
            currencyId: 'cup',
            currencyCode: 'CUP',
            paymentTypeId: 'cash',
            paymentTypeName: 'Efectivo',
            amount: 15,
            occurredAt: DateTime.utc(2026, 7, 15, 20),
            description: 'Pago de entrenador',
            counterMovementId: null,
            requiresReview: false,
            reviewReason: null,
            late: false,
          ),
        ],
        incidents: const TreasuryIncidentsModel(
          withoutAccount: 0,
          requiringReview: 0,
          lateMovements: 0,
        ),
      );

      final pdf = await const TreasuryDailyCloseReportService().buildPdf(
        ledger: ledger,
        account: account,
      );

      expect(utf8.decode(pdf.take(4).toList()), '%PDF');
      expect(pdf.length, greaterThan(5000));
      final renderPath = Platform.environment['TREASURY_PDF_RENDER_PATH'];
      if (renderPath != null && renderPath.isNotEmpty) {
        final file = File(renderPath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(pdf, flush: true);
      }
    },
  );
}
