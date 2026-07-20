import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/clients/domain/client_discount.dart';

/// R5.3 — El desglose del cliente debe coincidir EXACTAMENTE con el backend
/// (`client-discount-policy.ts`). El backend usa ceil a nivel de céntimos y
/// luego ceil a múltiplo de 100; un half-up divergía cuando el redondeo cruzaba
/// un múltiplo de 100 (30.00 @16.67 %: 24.00 correcto vs 25.00 erróneo).
void main() {
  group('clientDiscountBreakdown · porcentaje global (sin excepción)', () {
    test('30.00 @16.67 % cobra 24.00 (coincide con el backend, no 25.00)', () {
      final r = clientDiscountBreakdown(
        listPrice: 30.0,
        category: ClientCategory.viejo,
        discountPct: '16.67',
        planFixedOldPrice: null,
      );
      expect(r.descuento, 6.0);
      expect(r.precioFinal, 24.0);
      expect(r.motivo, 'PORCENTAJE_GLOBAL');
      expect(r.hasDiscount, isTrue);
    });

    test('12.00 @16.67 % cobra 9.00 (descuento 3.00)', () {
      final r = clientDiscountBreakdown(
        listPrice: 12.0,
        category: ClientCategory.viejo,
        discountPct: '16.67',
        planFixedOldPrice: null,
      );
      expect(r.descuento, 3.0);
      expect(r.precioFinal, 9.0);
    });

    test('25.00 @16.67 % cobra 20.00 (descuento 5.00)', () {
      final r = clientDiscountBreakdown(
        listPrice: 25.0,
        category: ClientCategory.viejo,
        discountPct: '16.67',
        planFixedOldPrice: null,
      );
      expect(r.descuento, 5.0);
      expect(r.precioFinal, 20.0);
    });
  });

  group('clientDiscountBreakdown · excepción fija de plan', () {
    test('12.00 con excepción 10.00 cobra 10.00 y anula el %', () {
      final r = clientDiscountBreakdown(
        listPrice: 12.0,
        category: ClientCategory.viejo,
        discountPct: '16.67',
        planFixedOldPrice: 10.0,
      );
      expect(r.descuento, 2.0);
      expect(r.precioFinal, 10.0);
      expect(r.motivo, 'EXCEPCION_FIJA');
      expect(r.descuentoPct, isNull);
    });
  });

  group('clientDiscountBreakdown · cliente NUEVO', () {
    test('no aplica descuento', () {
      final r = clientDiscountBreakdown(
        listPrice: 30.0,
        category: ClientCategory.nuevo,
        discountPct: '16.67',
        planFixedOldPrice: null,
      );
      expect(r.descuento, 0.0);
      expect(r.precioFinal, 30.0);
      expect(r.motivo, 'SIN_DESCUENTO');
      expect(r.hasDiscount, isFalse);
    });
  });
}
