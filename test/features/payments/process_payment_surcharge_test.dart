import 'package:flutter_test/flutter_test.dart';

void main() {
  group('R5.1 — Recargo por Método de Pago y Validación de Cobro Completo', () {
    Map<String, double> calculateSurchargeBreakdown(double paymentAmount) {
      const surchargePct = 5.0;
      if (paymentAmount <= 0) {
        return {'baseInPayment': 0.0, 'surchargeInPayment': 0.0};
      }
      final rawSurcharge = paymentAmount * (surchargePct / (100.0 + surchargePct));
      final surchargeInPayment = rawSurcharge.ceilToDouble();
      final baseInPayment = paymentAmount - surchargeInPayment;
      return {
        'baseInPayment': baseInPayment,
        'surchargeInPayment': surchargeInPayment,
      };
    }

    test('470 CUP al 5% con tasa /450 abona €0.99 al plan de €1.00 y NO habilita confirmación (falta €0.01)', () {
      final res = calculateSurchargeBreakdown(470.0);
      expect(res['surchargeInPayment'], equals(23.0));
      expect(res['baseInPayment'], equals(447.0));

      final equivalentEUR = 447.0 / 450.0;
      final remainingEUR = 1.00 - equivalentEUR;

      // Invariante de cobro completo: faltar 0.01 EUR es INCOMPLETO
      final isComplete = remainingEUR <= 0.001;
      expect(isComplete, isFalse);
    });

    test('475 CUP al 5% con tasa /450 abona €1.00+ al plan de €1.00 y SÍ habilita confirmación', () {
      final res = calculateSurchargeBreakdown(475.0);
      final equivalentEUR = res['baseInPayment']! / 450.0;
      final remainingEUR = 1.00 - equivalentEUR;

      final isComplete = remainingEUR <= 0.001;
      expect(isComplete, isTrue);
    });
  });
}
