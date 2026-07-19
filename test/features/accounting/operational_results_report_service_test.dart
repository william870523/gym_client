import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/accounting/data/models/operational_results_models.dart';
import 'package:gym_client/src/features/accounting/data/services/operational_results_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const reports = OperationalResultsReportService();

  test('CSV conserva importes exactos y trazabilidad R3 por tipo de fila', () {
    final snapshot = reports.snapshot(
      result: _certifiedResult(),
      allCurrencies: true,
      selectedCurrencyId: 'cup',
      generatedAtUtc: DateTime.utc(2026, 7, 1, 15),
      timezone: 'America/Havana',
    );
    final bytes = reports.buildCsv(snapshot);
    final csv = utf8.decode(bytes, allowMalformed: false);

    expect(bytes.take(3), [0xef, 0xbb, 0xbf]);
    expect(csv, contains('"MONEDA"'));
    expect(csv, contains('"CONCEPTO"'));
    expect(csv, contains('"CUENTA"'));
    expect(csv, contains('"ENTRENADOR"'));
    expect(csv, contains('"REEMBOLSO"'));
    expect(csv, contains('"90071992547409.91"'));
    expect(csv, contains('"close-r3"'));
    expect(csv, contains('"hash-r3"'));
    expect(csv, isNot(contains('TOTAL_GENERAL')));
  });

  test('PDF certificado se genera con fuentes embebidas', () async {
    final snapshot = reports.snapshot(
      result: _certifiedResult(),
      allCurrencies: false,
      selectedCurrencyId: 'cup',
      generatedAtUtc: DateTime.utc(2026, 7, 1, 15),
      timezone: 'America/Havana',
    );
    final bytes = await reports.buildPdf(snapshot);
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(10000));

    final output = Platform.environment['OPERATIONAL_RESULTS_PDF_RENDER_PATH'];
    if (output != null && output.trim().isNotEmpty) {
      await File(output).writeAsBytes(bytes, flush: true);
    }
  });
}

OperationalResultsModel _certifiedResult() => OperationalResultsModel.fromJson({
  'mes': '2026-06',
  'estado_periodo': 'CERTIFICADO',
  'naturaleza': 'RESULTADO_OPERATIVO_DE_CAJA',
  'certificado': true,
  'nota_certificacion': 'Resultado congelado y verificado.',
  'limitaciones': ['No representa utilidad devengada.'],
  'cierre_tesoreria': {
    'cierre_mensual_id': 'close-r3',
    'estado': 'CERRADO',
    'resumen_sha256': 'hash-r3',
    'integridad_verificada': true,
    'snapshot_version': 2,
    'cerrado_at': '2026-07-01T14:00:00.000Z',
    'firmado_por_nombre': 'Administración Demo',
    'firmado_por_rol': 'admin',
    'motivo': 'Resultado revisado para dirección.',
    'timezone': 'America/Havana',
  },
  'monedas': [
    {
      'moneda_id': 'cup',
      'moneda_codigo': 'CUP',
      'caja': {
        'cobros_brutos': '90071992547409.91',
        'cambio_entregado_neto': '10.00',
        'anulaciones_netas': '0.00',
        'pagos_entrenadores_netos': '20.00',
        'reembolsos_netos': '5.00',
        'otros_egresos_operativos': '1.00',
        'flujo_operativo': '90071992547373.91',
        'flujo_no_operativo': '0.00',
        'flujo_pendiente_clasificacion': '0.00',
        'entradas_libro': '90071992547409.91',
        'salidas_libro': '36.00',
        'neto_libro': '90071992547373.91',
      },
      'obligaciones': {
        'disponible': true,
        'fecha_corte': '2026-06-30',
        'entrenador_ganado_pendiente': '25.00',
        'entrenador_pagadero_ahora': '20.00',
        'entrenador_futuro': '30.00',
        'reembolsos_pendientes': '5.00',
        'reserva_inmediata': '30.00',
        'compromiso_total': '60.00',
        'entrenadores_pendientes': 1,
        'cuotas_vencidas': 1,
        'reembolsos_cantidad': 1,
        'revisiones_pendientes': 0,
        'motivo': 'Reserva operativa.',
        'entrenadores': [
          {
            'entrenador_id': 'trainer-1',
            'entrenador_nombre': 'Entrenadora Demo',
            'ganado_pendiente': '25.00',
            'pagadero_ahora': '20.00',
            'futuro': '30.00',
            'conceptos': 2,
            'conceptos_vencidos': 1,
            'conceptos_comision': 2,
            'conceptos_fijos': 0,
            'proxima_fecha_pago': '2026-07-01',
            'requiere_revision': false,
          },
        ],
        'reembolsos': [
          {
            'ajuste_financiero_id': 'refund-1',
            'ci': 'CI-1',
            'cliente_nombre': 'Cliente Demo',
            'monto': '5.00',
            'solicitado_at': '2026-06-28T12:00:00.000Z',
          },
        ],
      },
      'conceptos': [
        {
          'categoria': 'COBROS_PLANES',
          'etiqueta': 'Cobros de planes',
          'ambito': 'OPERATIVO',
          'entradas': '90071992547409.91',
          'salidas': '0.00',
          'efecto_flujo': '90071992547409.91',
          'movimientos': 1,
          'requiere_revision': false,
        },
      ],
      'cuentas': [
        {
          'cuenta_id': 'cash-cup',
          'cuenta_nombre': 'Caja CUP',
          'entradas': '90071992547409.91',
          'salidas': '36.00',
          'neto_libro': '90071992547373.91',
          'flujo_operativo': '90071992547373.91',
          'movimientos': 4,
          'requiere_revision': false,
        },
      ],
      'calidad': {
        'movimientos_sin_cuenta': 0,
        'clasificacion_pendiente': 0,
        'jornadas_por_cerrar': 0,
        'revisiones_pendientes': 0,
      },
    },
  ],
});
