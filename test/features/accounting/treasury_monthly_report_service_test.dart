import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/accounting/data/models/accounting_models.dart';
import 'package:gym_client/src/features/accounting/data/services/treasury_monthly_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = TreasuryMonthlyReportService();
  final summary = _summary();
  final generatedAt = DateTime.utc(2026, 7, 18, 1, 30);

  test('CSV multimoneda separa secciones y conserva trazabilidad', () {
    final snapshot = service.snapshot(
      summary: summary,
      allCurrencies: true,
      selectedCurrencyId: 'cup',
      includeDailyTrend: true,
      generatedAtUtc: generatedAt,
      timezone: 'America/Havana',
    );
    final bytes = service.buildCsv(snapshot);
    final csv = utf8.decode(bytes.sublist(3));

    expect(bytes.take(3), [0xef, 0xbb, 0xbf]);
    expect(snapshot.currencies, hasLength(2));
    expect(csv, contains('"MONEDA","2026-07","CUP"'));
    expect(csv, contains('"MONEDA","2026-07","EUR"'));
    expect(csv, contains('"CUENTA","2026-07","CUP","Caja principal"'));
    expect(csv, contains('"DIA","2026-07","CUP"'));
    expect(csv, contains('"cierres_aprobados"'));
    expect(csv, contains('"solicitudes_pendientes"'));
    expect(csv, contains('"America/Havana"'));
    expect(csv, contains('"cierre_mensual_estado"'));
    expect(csv, contains('"CERRADO","close-month-01"'));
    expect(csv, contains('"0123456789abcdef"'));
    expect(csv, contains('"Administración Demo"'));
    expect(csv, isNot(contains('TOTAL GENERAL')));
  });

  test('filtro por cuenta recalcula totales y evita tendencia atribuida', () {
    final snapshot = service.snapshot(
      summary: summary,
      allCurrencies: false,
      selectedCurrencyId: 'cup',
      accountId: 'cup-bank',
      includeDailyTrend: true,
      generatedAtUtc: generatedAt,
      timezone: 'America/Havana',
    );
    final currency = snapshot.currencies.single;
    final csv = utf8.decode(service.buildCsv(snapshot).sublist(3));

    expect(currency.accounts.single.name, 'Banco CUP');
    expect(currency.entries, 500);
    expect(currency.exits, 150);
    expect(currency.net, 350);
    expect(snapshot.includeDailyTrend, isFalse);
    expect(csv, contains('"Banco CUP"'));
    expect(csv, isNot(contains('"Caja principal"')));
    expect(csv, isNot(contains('"DIA"')));
  });

  test('PDF ejecutivo se genera y puede conservarse para inspección', () async {
    final snapshot = service.snapshot(
      summary: summary,
      allCurrencies: true,
      selectedCurrencyId: 'cup',
      includeDailyTrend: true,
      generatedAtUtc: generatedAt,
      timezone: 'America/Havana',
    );
    final bytes = await service.buildPdf(snapshot);

    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(10000));

    final renderPath = Platform.environment['TREASURY_MONTHLY_PDF_RENDER_PATH'];
    if (renderPath != null && renderPath.isNotEmpty) {
      final file = File(renderPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    }
  });
}

TreasuryMonthlySummaryModel _summary() => TreasuryMonthlySummaryModel.fromJson({
  'mes': '2026-07',
  'fecha_desde': '2026-07-01',
  'fecha_hasta': '2026-07-31',
  'cierre_mensual': {
    'estado': 'CERRADO',
    'mes_terminado': true,
    'listo_para_cerrar': false,
    'capacidades': {'puede_cerrar': false, 'puede_reabrir': true},
    'ciclo_actual': {
      'cierre_mensual_id': 'close-month-01',
      'mes': '2026-07',
      'estado': 'CERRADO',
      'motivo_cierre': 'Revisión integral del período mensual.',
      'resumen_sha256': '0123456789abcdef',
      'integridad_verificada': true,
      'cerrado_por_nombre': 'Administración Demo',
      'cerrado_por_rol': 'admin',
      'cerrado_at': '2026-08-01T14:30:00.000Z',
    },
  },
  'monedas': [
    {
      'moneda_id': 'cup',
      'moneda_codigo': 'CUP',
      'entradas': 1500,
      'salidas': 350,
      'neto': 1150,
      'movimientos': 9,
      'cuentas_con_actividad': 2,
      'jornadas_actividad': 5,
      'jornadas_cerradas': 4,
      'jornadas_por_cerrar': 1,
      'cobertura_cierre': 80,
      'cierres': 4,
      'cierres_aprobados': 1,
      'cierres_dentro_tolerancia': 3,
      'solicitudes_pendientes': 1,
      'solicitudes_rechazadas': 1,
      'solicitudes_obsoletas': 0,
      'conciliaciones': 2,
      'ajustes_conciliados_mes': -20,
      'movimientos_conciliados': 2,
      'movimientos_tardios_pendientes': 1,
      'revisiones_pendientes': 0,
      'cuentas_sin_cierre': 0,
      'saldo_cierre_original': 1100,
      'ajustes_vigentes': -20,
      'saldo_vigente': 1080,
      'neto_pendiente_cierre': 70,
      'tendencia': [
        {
          'fecha': '2026-07-03',
          'entradas': 700,
          'salidas': 120,
          'neto': 580,
          'cierres': 2,
          'ajustes_conciliados': -10,
        },
        {
          'fecha': '2026-07-17',
          'entradas': 800,
          'salidas': 230,
          'neto': 570,
          'cierres': 2,
          'ajustes_conciliados': -10,
        },
      ],
      'cuentas': [
        _account(
          id: 'cup-cash',
          name: 'Caja principal',
          entries: 1000,
          exits: 200,
          status: 'PENDIENTE_APROBACION',
          pendingApprovals: 1,
        ),
        _account(
          id: 'cup-bank',
          name: 'Banco CUP',
          entries: 500,
          exits: 150,
          status: 'CONCILIADO',
          approvedCloses: 1,
        ),
      ],
    },
    {
      'moneda_id': 'eur',
      'moneda_codigo': 'EUR',
      'entradas': 210,
      'salidas': 40,
      'neto': 170,
      'movimientos': 3,
      'cuentas_con_actividad': 1,
      'jornadas_actividad': 2,
      'jornadas_cerradas': 2,
      'jornadas_por_cerrar': 0,
      'cobertura_cierre': 100,
      'cierres': 2,
      'cierres_aprobados': 0,
      'cierres_dentro_tolerancia': 2,
      'solicitudes_pendientes': 0,
      'solicitudes_rechazadas': 0,
      'solicitudes_obsoletas': 0,
      'conciliaciones': 0,
      'ajustes_conciliados_mes': 0,
      'movimientos_conciliados': 0,
      'movimientos_tardios_pendientes': 0,
      'revisiones_pendientes': 0,
      'cuentas_sin_cierre': 0,
      'saldo_cierre_original': 170,
      'ajustes_vigentes': 0,
      'saldo_vigente': 170,
      'neto_pendiente_cierre': 0,
      'tendencia': [
        {
          'fecha': '2026-07-10',
          'entradas': 210,
          'salidas': 40,
          'neto': 170,
          'cierres': 2,
          'ajustes_conciliados': 0,
        },
      ],
      'cuentas': [
        _account(
          id: 'eur-cash',
          name: 'Caja EUR',
          entries: 210,
          exits: 40,
          currencyId: 'eur',
          currencyCode: 'EUR',
          status: 'CERRADO',
        ),
      ],
    },
  ],
});

Map<String, dynamic> _account({
  required String id,
  required String name,
  required double entries,
  required double exits,
  required String status,
  String currencyId = 'cup',
  String currencyCode = 'CUP',
  int pendingApprovals = 0,
  int approvedCloses = 0,
}) => {
  'cuenta_id': id,
  'cuenta_nombre': name,
  'moneda_id': currencyId,
  'moneda_codigo': currencyCode,
  'entradas': entries,
  'salidas': exits,
  'neto': entries - exits,
  'movimientos': 4,
  'dias_actividad': 2,
  'jornadas_cerradas': pendingApprovals == 0 ? 2 : 1,
  'jornadas_por_cerrar': pendingApprovals == 0 ? 0 : 1,
  'cierres': 2,
  'cierres_aprobados': approvedCloses,
  'cierres_dentro_tolerancia': approvedCloses == 0 ? 1 : 1,
  'solicitudes_pendientes': pendingApprovals,
  'solicitudes_rechazadas': 0,
  'solicitudes_obsoletas': 0,
  'conciliaciones': 1,
  'ajustes_conciliados_mes': -10,
  'movimientos_conciliados': 1,
  'movimientos_tardios_pendientes': pendingApprovals,
  'revisiones_pendientes': 0,
  'ultimo_cierre_fecha': '2026-07-17',
  'saldo_cierre_original': entries - exits,
  'ajustes_vigentes': -10,
  'saldo_vigente': entries - exits - 10,
  'neto_pendiente_cierre': pendingApprovals == 0 ? 0 : 50,
  'estado': status,
};
