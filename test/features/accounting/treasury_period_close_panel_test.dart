import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_palette_id.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_theme.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_tokens.dart';
import 'package:gym_client/src/features/accounting/data/models/treasury_period_models.dart';
import 'package:gym_client/src/features/accounting/data/repositories/accounting_repository.dart';
import 'package:gym_client/src/features/accounting/data/services/treasury_period_close_report_service.dart';
import 'package:gym_client/src/features/accounting/presentation/state/accounting_providers.dart';
import 'package:gym_client/src/features/accounting/presentation/widgets/treasury_period_close_panel.dart';

class _FakeAccountingRepository extends AccountingRepository {
  _FakeAccountingRepository() : super(Dio());
}

Map<String, dynamic> _summaryJson({
  bool blocked = false,
  bool signed = false,
  bool canSign = true,
}) => {
  'origen_cierre': 'PERIODO',
  'tipo_periodo': 'PERSONALIZADO',
  'desde': '2025-03-03',
  'hasta': '2025-03-06',
  'dias_cantidad': 4,
  'timezone': 'America/Los_Angeles',
  'bloqueadores': blocked
      ? [
          {'codigo': 'MOVIMIENTO_TARDIO_SIN_CONCILIAR', 'cantidad': 1},
        ]
      : [],
  'resumen_monedas': [
    {
      'moneda_id': 'eur',
      'codigo': 'EUR',
      'cobro_bruto': '50.00',
      'cambio_entregado': '0.00',
      'anulaciones': '30.00',
      'cobro_neto': '20.00',
      'flujo_neto': '20.00',
      'cobros_cantidad_distinta': 2,
      'clientes_cantidad_distinta': 1,
      'cobertura_diaria': 100,
      'sin_atribuir_importe': '0.00',
      'cobradores': [
        {
          'user_id': 'bruno',
          'nombre': 'Bruno Recepción',
          'rol': 'reception',
          'cobros_cantidad_distinta': 2,
          'clientes_cantidad_distinta': 1,
          'cobro_bruto': '50.00',
          'cambio_entregado': '0.00',
          'anulaciones': '30.00',
          'cobro_neto': '20.00',
        },
      ],
      'cuentas': [
        {
          'cuenta_id': 'cash-eur',
          'nombre': 'Caja EUR',
          'dias_actividad': 2,
          'dias_cerrados': 2,
          'entradas': '50.00',
          'salidas': '30.00',
          'neto': '20.00',
        },
      ],
    },
    {
      'moneda_id': 'cup',
      'codigo': 'CUP',
      'cobro_bruto': '230.00',
      'cambio_entregado': '5.00',
      'anulaciones': '0.00',
      'cobro_neto': '225.00',
      'flujo_neto': '203.00',
      'cobros_cantidad_distinta': 3,
      'clientes_cantidad_distinta': 2,
      'cobertura_diaria': 100,
      'sin_atribuir_importe': '80.00',
      'cobradores': [],
      'cuentas': [],
    },
  ],
  'dias': [
    {
      'fecha_negocio': '2025-03-03',
      'cierre_ids': ['close-eur'],
      'monedas': [
        {
          'moneda_id': 'eur',
          'codigo': 'EUR',
          'entradas': '50.00',
          'salidas': '30.00',
          'neto': '20.00',
        },
      ],
    },
  ],
  'pagos': [
    {
      'pago_cliente_id': 'payment-1',
      'ocurrido_at_utc': '2025-03-03T14:00:00.000Z',
      'ci': '99081600001',
      'plan_codigo': 'PLAN',
      'cuota': '1/1',
      'cobrador': {'nombre': 'Bruno Recepción'},
      'reverso': {'anulado_por_nombre': 'Carla Supervisión'},
      'detalles': [
        {
          'movimiento_id': 'movement-1',
          'cuenta_id': 'cash-eur',
          'moneda_id': 'eur',
          'direccion': 'ENTRADA',
          'monto': '50.00',
          'origen_tipo': 'PAGO_CLIENTE',
          'tipo_pago_id': 'cash',
        },
      ],
    },
  ],
  'cierre_periodo': {
    'estado': signed ? 'CERRADO' : 'ABIERTO',
    'listo_para_firmar': !signed && !blocked,
    'capacidades': {
      'puede_firmar': !signed && !blocked && canSign,
      'puede_reabrir': signed,
    },
    if (signed)
      'ciclo_activo': {
        'cierre_periodo_id': 'period-close-1',
        'tipo_periodo': 'PERSONALIZADO',
        'desde': '2025-03-03',
        'hasta': '2025-03-06',
        'ciclo_numero': 1,
        'estado': 'CERRADO',
        'motivo_cierre': 'Certificación de prueba completa.',
        'cerrado_por_nombre': 'Carla Supervisión',
        'cerrado_por_rol': 'admin',
        'cerrado_at': '2026-08-01T10:00:00.000Z',
        'snapshot_sha256': 'abc123',
        'integridad_hash': true,
        'estado_integridad': 'VIGENTE',
      },
  },
};

Widget _harness({
  required TreasuryPeriodSummaryModel summary,
  Object? error,
  List<TreasuryPeriodCycleModel> cycles = const [],
}) => ProviderScope(
  overrides: [
    accountingRepositoryProvider.overrideWithValue(_FakeAccountingRepository()),
    treasuryPeriodSummaryProvider.overrideWith((ref, request) async {
      if (error != null) throw error;
      return summary;
    }),
    treasuryPeriodClosesProvider.overrideWith(
      (ref, request) async => TreasuryPeriodCyclesModel(cycles: cycles),
    ),
  ],
  child: MaterialApp(
    theme: PulsoThemeFactory.build(
      PulsoTokens.resolve(PulsoPaletteId.clay, Brightness.light),
    ),
    home: Scaffold(body: TreasuryPeriodClosePanel(onChanged: () {})),
  ),
);

void main() {
  final open = TreasuryPeriodSummaryModel.fromJson(_summaryJson());

  for (final size in [
    const Size(360, 1000),
    const Size(768, 1000),
    const Size(1280, 1000),
  ]) {
    testWidgets('carga sin desbordar a ${size.width.toInt()} px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(summary: open));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('treasury-period-scope')), findsOneWidget);
      expect(find.text('EUR'), findsWidgets);
      expect(find.text('CUP'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('explica el permiso ausente sin ocultar la acción', (
    tester,
  ) async {
    final summary = TreasuryPeriodSummaryModel.fromJson(
      _summaryJson(canSign: false),
    );
    await tester.pumpWidget(_harness(summary: summary));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('treasury-period-sign')), findsOneWidget);
    expect(
      find.text('Su rol no tiene permiso para firmar este período.'),
      findsOneWidget,
    );
  });

  testWidgets('muestra bloqueadores y conserva la firma deshabilitada', (
    tester,
  ) async {
    final summary = TreasuryPeriodSummaryModel.fromJson(
      _summaryJson(blocked: true),
    );
    await tester.pumpWidget(_harness(summary: summary));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('treasury-period-blockers')), findsOneWidget);
    expect(find.textContaining('MOVIMIENTO TARDIO'), findsOneWidget);
    expect(find.textContaining('La firma está deshabilitada'), findsOneWidget);
  });

  testWidgets('presenta el ciclo firmado y su reapertura', (tester) async {
    final summary = TreasuryPeriodSummaryModel.fromJson(
      _summaryJson(signed: true),
    );
    await tester.pumpWidget(
      _harness(summary: summary, cycles: [summary.activeCycle!]),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('treasury-period-reopen')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('treasury-period-history')),
    );
    await tester.tap(find.byKey(const Key('treasury-period-history')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ciclo 1 · CERRADO · VIGENTE'), findsOneWidget);
  });

  testWidgets('muestra el estado de error', (tester) async {
    await tester.pumpWidget(
      _harness(summary: open, error: StateError('fallo controlado')),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('No se pudo calcular el período'),
      findsOneWidget,
    );
  });

  test('CSV incluye BOM, monedas separadas y atribuciones', () {
    const service = TreasuryPeriodCloseReportService();
    final bytes = service.buildCsv(open);
    expect(bytes.take(3), [0xef, 0xbb, 0xbf]);
    final text = utf8.decode(bytes.skip(3).toList());
    expect(text, contains('"EUR"'));
    expect(text, contains('"Bruno Recepción"'));
    expect(text, contains('"Carla Supervisión"'));
    expect(text, contains('"50.00"'));
  });

  test('PDF firmado contiene contenido y se puede abrir', () async {
    const service = TreasuryPeriodCloseReportService();
    final signed = TreasuryPeriodSummaryModel.fromJson(
      _summaryJson(signed: true),
    );
    final bytes = await service.buildPdf(signed);
    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });
}
