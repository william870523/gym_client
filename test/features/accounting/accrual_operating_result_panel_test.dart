import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_palette_id.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_theme.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_tokens.dart';
import 'package:gym_client/src/features/accounting/data/models/accrual_operating_result_models.dart';
import 'package:gym_client/src/features/accounting/data/repositories/accounting_repository.dart';
import 'package:gym_client/src/features/accounting/presentation/state/accounting_providers.dart';
import 'package:gym_client/src/features/accounting/presentation/widgets/accrual_operating_result_panel.dart';

class _FakeAccountingRepository extends AccountingRepository {
  _FakeAccountingRepository() : super(Dio());
}

AccrualOperatingResultModel _result({
  bool marginCertified = false,
  bool expenseCertified = false,
  String result = '5500.00',
}) {
  return AccrualOperatingResultModel.fromJson({
    'mes': '2026-07',
    'naturaleza': 'RESULTADO_OPERATIVO_DEVENGADO',
    'estado_periodo': 'PROVISIONAL',
    'fecha_corte': '2026-07-19',
    'certificado': marginCertified && expenseCertified,
    'margen_certificado': marginCertified,
    'gasto_certificado': expenseCertified,
    'nota_certificacion': marginCertified && !expenseCertified
        ? 'El margen está certificado pero el cierre firmado es anterior a R4.6.'
        : 'El resultado operativo devengado es una proyección viva.',
    'cobertura': {
      'membresias_evaluadas': 8,
      'conceptos_costo_evaluados': 3,
      'gastos_evaluados': 3,
      'gastos_pendientes_pago': 1,
      'gastos_de_otro_mes_pagados_en_el_mes': 2,
      'requieren_revision': 0,
      'completa': true,
    },
    'monedas': [
      {
        'moneda_id': 'cup',
        'moneda_codigo': 'CUP',
        'ingreso_devengado_mes': '10000.00',
        'costo_directo_mes': '2000.00',
        'margen_directo_mes': '8000.00',
        'fijo_no_distribuido_mes': '1000.00',
        'margen_menos_fijo_mes': '7000.00',
        'gasto_devengado_mes': '1500.00',
        'gasto_pagado_mes': '900.00',
        'gasto_pendiente_pago': '600.00',
        'resultado_operativo_devengado_mes': result,
        'resultado_operativo_pct_ingreso_mes': 55,
        'gasto_por_naturaleza': [
          {
            'naturaleza': 'OPERATIVO',
            'gastos': 2,
            'devengado_mes': '1200.00',
            'pct_ingreso_mes': 12,
          },
          {
            'naturaleza': 'ADMINISTRATIVO',
            'gastos': 1,
            'devengado_mes': '300.00',
            'pct_ingreso_mes': 3,
          },
        ],
        'solo_gasto': false,
        'explicacion':
            'El margen del mes cubre la compensación fija y el gasto gobernado del período.',
      },
    ],
    'nota': 'Es el resultado operativo del período, no la utilidad del gimnasio.',
    'limitaciones': ['No mezcla ni convierte monedas.'],
  });
}

Widget _harness(AccrualOperatingResultModel model) {
  return ProviderScope(
    overrides: [
      accountingRepositoryProvider.overrideWithValue(
        _FakeAccountingRepository(),
      ),
      accrualOperatingResultProvider.overrideWith((ref, month) async => model),
    ],
    child: MaterialApp(
      theme: PulsoThemeFactory.build(
        PulsoTokens.resolve(PulsoPaletteId.clay, Brightness.light),
      ),
      home: Scaffold(
        body: AccrualOperatingResultPanel(
          initialMonth: '2026-07',
          onBack: () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('la cascada muestra cómo se arma el resultado del mes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(_result()));
    await tester.pumpAndSettle();

    // Los pasos de la cascada, en orden contable.
    expect(find.text('Ingreso devengado del mes'), findsOneWidget);
    expect(find.text('Costo directo de comisión'), findsOneWidget);
    expect(find.text('Margen menos fijo'), findsOneWidget);
    expect(find.text('Gasto gobernado del mes'), findsOneWidget);
    expect(find.text('Resultado operativo devengado'), findsOneWidget);

    // La cifra focal aparece con separador de miles.
    expect(find.text('5,500.00 CUP'), findsWidgets);

    // El desglose por naturaleza usa etiquetas legibles, no las constantes.
    expect(find.text('Operativo'), findsOneWidget);
    expect(find.text('Administrativo'), findsOneWidget);
    expect(find.text('COSTO_VENTAS'), findsNothing);

    // Nada de Material por defecto en el panel.
    expect(find.byType(Card), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un cierre anterior a R4.6 se muestra como parcial', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(_result(marginCertified: true, expenseCertified: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('CERTIFICACIÓN PARCIAL'), findsOneWidget);
    // Los pagos de otro mes se explican como movimiento de caja, no de devengo.
    expect(
      find.textContaining('pago(s) de otro mes hechos en este mes'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('un resultado negativo no se pinta como logro', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(_result(result: '-1200.00')));
    await tester.pumpAndSettle();

    expect(find.text('-1,200.00 CUP'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
