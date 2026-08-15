import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/money/decimal_json.dart';
import 'package:gym_client/src/features/financials/data/models/exchange_rate_model.dart';
import 'package:gym_client/src/features/payments/data/models/payment_model.dart';
import 'package:gym_client/src/features/products/data/models/payment_plan_model.dart';

void main() {
  test('la frontera decimal acepta JSON num y texto exacto', () {
    expect(decimalJsonToDouble('0.30'), 0.30);
    expect(decimalJsonToDouble(0.31), 0.31);
    expect(nullableDecimalJsonToDouble(null), isNull);
    expect(() => decimalJsonToDouble('no-es-decimal'), throwsFormatException);
  });

  test('pagos, detalles, planes y tasas leen Decimal serializado como texto', () {
    final payment = PaymentModel.fromJson({
      'pago_cliente_id': 'pago-1',
      'ci': 'cliente-1',
      'fecha': '2026-08-15T00:00:00.000Z',
      'monto_total': '0.30',
      'id_planes_pago': 'plan-1',
      'moneda_id': 'cup',
      'precio_lista_snapshot': '0.40',
      'descuento_monto_snapshot': '0.10',
    });
    final detail = PaymentDetailModel.fromJson({
      'detalle_pago_id': 'detalle-1',
      'pago_cliente_id': 'pago-1',
      'tipo_pago_id': 'efectivo',
      'moneda_id': 'cup',
      'cantidad': '0.30',
      'exchangeRateValue': '405.12345678',
    });
    final plan = PaymentPlanModel.fromJson({
      'id_planes_pago': 'plan-1',
      'nombre_plan_pago': 'Plan exacto',
      'importe_plan_pago': '0.30',
      'duracion_plan_pago': 30,
      'moneda_id': 'cup',
      'comision_entrenador_valor': '1.250000',
      'precio_viejo_excepcion': '0.20',
    });
    final rate = ExchangeRateModel.fromJson({
      'tipo_cambio_id': 'rate-1',
      'moneda_id_base': 'usd',
      'moneda_id_target': 'cup',
      'exchange_rate': '405.12345678',
      'fecha_inicio': '2026-08-15T00:00:00.000Z',
    });

    expect(payment.amount, 0.30);
    expect(payment.listPriceSnapshot, 0.40);
    expect(payment.discountAmountSnapshot, 0.10);
    expect(detail.amount, 0.30);
    expect(detail.exchangeRateValue, 405.12345678);
    expect(plan.importe, 0.30);
    expect(plan.comisionEntrenadorValor, 1.25);
    expect(plan.precioViejoExcepcion, 0.20);
    expect(rate.exchangeRate, 405.12345678);
  });
}
