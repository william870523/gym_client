import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/accounting/data/models/operational_results_models.dart';

void main() {
  test('conserva decimales exactos y obligaciones ausentes', () {
    final model = OperationalResultsModel.fromJson({
      'mes': '2026-06',
      'estado_periodo': 'PROVISIONAL',
      'naturaleza': 'RESULTADO_OPERATIVO_DE_CAJA',
      'certificado': false,
      'cierre_tesoreria': null,
      'nota_certificacion': 'Proyección viva.',
      'limitaciones': ['No representa utilidad.'],
      'monedas': [
        {
          'moneda_id': 'cup',
          'moneda_codigo': 'CUP',
          'caja': {
            'cobros_brutos': '90071992547409.91',
            'cambio_entregado_neto': '0.00',
            'anulaciones_netas': '0.00',
            'pagos_entrenadores_netos': '20.00',
            'reembolsos_netos': '0.00',
            'otros_egresos_operativos': '0.00',
            'flujo_operativo': '90071992547389.91',
            'flujo_no_operativo': '0.00',
            'flujo_pendiente_clasificacion': '0.00',
            'entradas_libro': '90071992547409.91',
            'salidas_libro': '20.00',
            'neto_libro': '90071992547389.91',
          },
          'obligaciones': {
            'disponible': false,
            'entrenador_ganado_pendiente': null,
            'entrenador_futuro': null,
            'reembolsos_pendientes': null,
            'motivo': 'Disponible en R2.',
          },
          'conceptos': [],
          'cuentas': [],
          'calidad': {
            'movimientos_sin_cuenta': 0,
            'clasificacion_pendiente': 0,
            'jornadas_por_cerrar': 2,
            'revisiones_pendientes': 0,
          },
        },
        {
          'moneda_id': 'eur',
          'moneda_codigo': 'EUR',
          'caja': {'cobros_brutos': '10.00'},
          'obligaciones': {'disponible': false},
          'conceptos': [],
          'cuentas': [],
          'calidad': {},
        },
      ],
    });

    expect(model.currencies, hasLength(2));
    expect(model.currencies.first.cash.grossCollections, '90071992547409.91');
    expect(model.currencies.first.obligations.available, isFalse);
    expect(model.currencies.first.obligations.trainerEarnedPending, isNull);
    expect(model.currencies.first.quality.openBusinessDays, 2);
    expect(model.currencies.last.currencyCode, 'EUR');
    expect(model.currencies.last.cash.grossCollections, '10.00');
  });

  test('lee reserva, entrenadores y reembolsos R2 sin convertir el dinero', () {
    final model = OperationalResultsModel.fromJson({
      'mes': '2026-07',
      'monedas': [
        {
          'moneda_id': 'cup',
          'moneda_codigo': 'CUP',
          'caja': {},
          'conceptos': [],
          'cuentas': [],
          'calidad': {},
          'obligaciones': {
            'disponible': true,
            'fecha_corte': '2026-07-17',
            'entrenador_ganado_pendiente': '90071992547409.91',
            'entrenador_pagadero_ahora': '20.00',
            'entrenador_futuro': '30.00',
            'reembolsos_pendientes': '5.00',
            'reserva_inmediata': '90071992547414.91',
            'compromiso_total': '90071992547444.91',
            'entrenadores_pendientes': 1,
            'cuotas_vencidas': 2,
            'reembolsos_cantidad': 1,
            'revisiones_pendientes': 0,
            'cobertura_futuro': 'Comisiones materializadas.',
            'motivo': 'No equivale a saldo libre.',
            'entrenadores': [
              {
                'entrenador_id': 'trainer-1',
                'entrenador_nombre': 'Entrenadora Demo',
                'ganado_pendiente': '20.00',
                'pagadero_ahora': '20.00',
                'futuro': '30.00',
                'conceptos': 3,
                'conceptos_vencidos': 2,
                'conceptos_comision': 2,
                'conceptos_fijos': 1,
                'proxima_fecha_pago': '2026-07-18',
                'requiere_revision': false,
              },
            ],
            'reembolsos': [
              {
                'ajuste_financiero_id': 'refund-1',
                'ci': 'CI-1',
                'cliente_nombre': 'Cliente Demo',
                'monto': '5.00',
                'solicitado_at': '2026-07-16T10:00:00.000Z',
              },
            ],
          },
        },
      ],
    });

    final obligations = model.currencies.single.obligations;
    expect(obligations.available, isTrue);
    expect(obligations.trainerEarnedPending, '90071992547409.91');
    expect(obligations.immediateReserve, '90071992547414.91');
    expect(obligations.overdueInstallmentCount, 2);
    expect(obligations.trainers.single.trainerName, 'Entrenadora Demo');
    expect(obligations.refunds.single.clientName, 'Cliente Demo');
    expect(
      obligations.refunds.single.requestedAt,
      DateTime.utc(2026, 7, 16, 10),
    );
  });

  test('lee la evidencia completa de un snapshot certificado R3', () {
    final model = OperationalResultsModel.fromJson({
      'mes': '2026-06',
      'estado_periodo': 'CERTIFICADO',
      'certificado': true,
      'cierre_tesoreria': {
        'cierre_mensual_id': 'close-r3',
        'estado': 'CERRADO',
        'resumen_sha256': 'abc123',
        'integridad_verificada': true,
        'snapshot_version': 2,
        'cerrado_at': '2026-07-01T14:00:00.000Z',
        'firmado_por_nombre': 'Administración',
        'firmado_por_rol': 'admin',
        'motivo': 'Cierre mensual revisado.',
        'timezone': 'America/Havana',
        'generado_at_utc': '2026-07-01T13:59:59.000Z',
      },
      'monedas': [],
    });

    expect(model.certified, isTrue);
    expect(model.monthlyClose?.integrityVerified, isTrue);
    expect(model.monthlyClose?.snapshotVersion, 2);
    expect(model.monthlyClose?.signerName, 'Administración');
    expect(model.monthlyClose?.timezone, 'America/Havana');
    expect(
      model.monthlyClose?.generatedAtUtc,
      DateTime.utc(2026, 7, 1, 13, 59, 59),
    );
  });
}
