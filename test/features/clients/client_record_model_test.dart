import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/clients/data/models/client_record_model.dart';

void main() {
  test('expediente serializa importes exactos y fechas UTC', () {
    final source = jsonDecode(_fixture) as Map<String, dynamic>;
    final record = ClientRecordModel.fromJson(source);

    expect(record.client.fullName, 'Ana Pérez');
    expect(record.memberships.single.price, 50);
    expect(record.memberships.single.startDate.isUtc, isTrue);
    expect(record.memberships.single.pauses.single.remainingDays, 23);
    expect(record.memberships.single.pauses.single.pauseDate.isUtc, isTrue);
    expect(record.memberships.single.requests.single.status, 'RECHAZADA');
    expect(
      record.memberships.single.requests.single.requesterName,
      'Recepción',
    );
    expect(record.memberships.single.payments.single.appliedAmount, 50);
    expect(
      record.memberships.single.payments.single.details.single.paymentTypeName,
      'Efectivo',
    );
    expect(
      record.memberships.single.payments.single.details.single.accountName,
      'Caja USD',
    );
    expect(record.unlinkedPayments.single.isVoided, isTrue);
    expect(record.unlinkedPayments.single.voidedAt?.isUtc, isTrue);
    expect(record.totalsByCurrency.single.code, 'USD');

    final roundTrip = jsonDecode(jsonEncode(record.toJson()));
    final restored = ClientRecordModel.fromJson(
      Map<String, dynamic>.from(roundTrip as Map),
    );
    expect(restored.memberships.single.status, 'ACTIVA');
    expect(restored.totalsByCurrency.single.amount, 50);
  });

  test('rechaza un expediente sin identidad de cliente', () {
    expect(
      () => ClientRecordModel.fromJson({
        'cliente': {'nombres': 'Sin', 'apellidos': 'CI'},
      }),
      throwsFormatException,
    );
  });
}

const _fixture = r'''
{
  "cliente": {"ci":"100","nombres":"Ana","apellidos":"Pérez"},
  "membresias": [{
    "membresia_id":"membership-1",
    "id_planes_pago":"plan-1",
    "plan_nombre":"Mensual",
    "precio":"50.00",
    "moneda_id":"usd",
    "moneda_codigo":"USD",
    "moneda_simbolo":"$",
    "duracion_dias":30,
    "fecha_inicio":"2026-07-12T00:00:00.000Z",
    "fecha_fin":"2026-08-11T00:00:00.000Z",
    "estado":"ACTIVA",
    "origen":"ALTA",
    "importe_pagado":"50.00",
    "activada_at":"2026-07-12T20:00:00.000Z",
    "reconstruida":false,
    "confianza_reconstruccion":null,
    "pausas":[{
      "pausa_id":"pause-1",
      "fecha_pausa":"2026-07-19T00:00:00.000Z",
      "fecha_reanudacion":"2026-07-26T00:00:00.000Z",
      "fecha_fin_anterior":"2026-08-11T00:00:00.000Z",
      "fecha_fin_recalculada":"2026-08-18T00:00:00.000Z",
      "dias_restantes":23,
      "motivo":"Viaje familiar",
      "estado":"REANUDADA",
      "pausada_at":"2026-07-19T16:00:00.000Z",
      "reanudada_at":"2026-07-26T16:00:00.000Z"
    }],
    "solicitudes":[{
      "solicitud_id":"request-1",
      "membresia_id":"membership-1",
      "ci":"100",
      "tipo":"PAUSAR",
      "motivo":"Viaje familiar",
      "estado":"RECHAZADA",
      "fecha_efectiva_solicitada":"2026-07-18T00:00:00.000Z",
      "fecha_efectiva_aplicada":null,
      "dias_restantes_estimados":24,
      "dias_restantes_aplicados":null,
      "fecha_fin_estimada":"2026-08-11T00:00:00.000Z",
      "fecha_fin_resultante":null,
      "solicitada_por_user_id":"reception-1",
      "solicitada_por_nombre":"Recepción",
      "solicitada_at":"2026-07-18T16:00:00.000Z",
      "decidida_por_user_id":"admin-1",
      "decidida_por_nombre":"Administración",
      "decision_motivo":"Documento pendiente",
      "decidida_at":"2026-07-18T17:00:00.000Z"
    }],
    "entrenadores":[{
      "asignacion_id":"assignment-1",
      "id_entrenador":"trainer-1",
      "entrenador_nombre":"Coach Uno",
      "fecha_inicio":"2026-07-12T00:00:00.000Z",
      "fecha_fin":null,
      "estado":"ACTIVA",
      "motivo_cierre":null
    }],
    "pagos":[{
      "pago_cliente_id":"payment-1",
      "fecha":"2026-07-12T20:00:00.000Z",
      "monto_total":"50.00",
      "moneda_id":"usd",
      "moneda_codigo":"USD",
      "moneda_simbolo":"$",
      "id_planes_pago":"plan-1",
      "id_entrenador":"trainer-1",
      "aplicacion_id":"application-1",
      "monto_aplicado":"50.00",
      "detalles":[{
        "detalle_pago_id":"detail-1",
        "tipo_pago_id":"cash",
        "tipo_pago_nombre":"Efectivo",
        "cuenta_id":"cash-usd",
        "cuenta_nombre":"Caja USD",
        "moneda_id":"usd",
        "moneda_codigo":"USD",
        "moneda_simbolo":"$",
        "cantidad":"50.00",
        "tipo_cambio_id":null,
        "tipo_cambio_tasa":null
      }]
    }]
  }],
  "pagos_sin_membresia":[{
    "pago_cliente_id":"payment-void",
    "fecha":"2026-07-12T20:30:00.000Z",
    "monto_total":"25.00",
    "moneda_id":"usd",
    "moneda_codigo":"USD",
    "moneda_simbolo":"$",
    "id_planes_pago":"plan-1",
    "id_entrenador":null,
    "is_deleted":true,
    "deleted_at":"2026-07-12T20:31:00.000Z"
  }],
  "totales_por_moneda":[{
    "moneda_id":"usd",
    "moneda_nombre":"Dólar estadounidense",
    "codigo":"USD",
    "simbolo":"$",
    "monto_total":"50.00",
    "cantidad_pagos":1
  }]
}
''';
