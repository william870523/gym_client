import 'package:flutter_test/flutter_test.dart';

void main() {
  group('R5.1 — Recargo por Método de Pago y Validación de Cobro Completo', () {
    Map<String, double> calculateSurchargeBreakdown(double totalReceived) {
      const surchargePct = 5.0;
      if (totalReceived <= 0) {
        return {'baseInPayment': 0.0, 'surchargeInPayment': 0.0};
      }
      final totalCents = (totalReceived * 100).round();
      for (var baseCents = totalCents; baseCents >= 0; baseCents--) {
        final base = baseCents / 100;
        final surcharge = (base * surchargePct / 100).ceilToDouble();
        if ((base + surcharge - totalReceived).abs() <= 0.001) {
          return {'baseInPayment': base, 'surchargeInPayment': surcharge};
        }
      }
      throw StateError('Total sin desglose exacto');
    }

    test(
      '10 EUR recibidos aplican 9 EUR al plan; 11 aplican los 10 requeridos',
      () {
        expect(calculateSurchargeBreakdown(10), {
          'baseInPayment': 9.0,
          'surchargeInPayment': 1.0,
        });
        expect(calculateSurchargeBreakdown(11), {
          'baseInPayment': 10.0,
          'surchargeInPayment': 1.0,
        });
      },
    );

    test(
      '470 CUP al 5% con tasa /450 abona €0.99 al plan de €1.00 y NO habilita confirmación (falta €0.01)',
      () {
        final res = calculateSurchargeBreakdown(470.0);
        expect(res['surchargeInPayment'], equals(23.0));
        expect(res['baseInPayment'], equals(447.0));

        final equivalentEUR = 447.0 / 450.0;
        final remainingEUR = 1.00 - equivalentEUR;

        // Invariante de cobro completo: faltar 0.01 EUR es INCOMPLETO
        final isComplete = remainingEUR <= 0.001;
        expect(isComplete, isFalse);
      },
    );

    test(
      '475 CUP al 5% con tasa /450 abona €1.00+ al plan de €1.00 y SÍ habilita confirmación',
      () {
        final res = calculateSurchargeBreakdown(475.0);
        final equivalentEUR = res['baseInPayment']! / 450.0;
        final remainingEUR = 1.00 - equivalentEUR;

        final isComplete = remainingEUR <= 0.001;
        expect(isComplete, isTrue);
      },
    );
  });
}
