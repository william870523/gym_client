import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/statistics/data/models/accounting_statistics.dart';
import 'package:gym_client/src/features/statistics/presentation/screens/statistics_accounting_pulso_view.dart';
import 'package:gym_client/src/features/statistics/presentation/screens/statistics_shared.dart';
import 'package:gym_client/src/features/statistics/presentation/state/statistics_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final width in [390.0, 760.0, 1280.0]) {
    testWidgets('E4 se adapta sin overflow a ${width.toInt()} px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountingStatisticsProvider.overrideWith((ref) async => _report),
          ],
          child: const MaterialApp(
            home: Scaffold(body: StatisticsAccountingPulsoView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StatsHeader), findsOneWidget);
      expect(
        find.byKey(const ValueKey('contabilidad-moneda-cup')),
        findsOneWidget,
      );
      expect(find.text('Entradas por medio de pago'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

final _report = AccountingStatistics.fromJson({
  'zona': 'America/Havana',
  'fecha_corte': '2026-07-31',
  'periodo': {
    'desde': '2026-06',
    'hasta': '2026-07',
    'meses': ['2026-06', '2026-07'],
  },
  'monedas': [
    {
      'moneda_id': 'cup',
      'moneda_codigo': 'CUP',
      'serie': [
        _month('2026-06', '120.00', '70.00'),
        _month('2026-07', '150.00', '-8.00'),
      ],
    },
  ],
  'advertencias': ['No se mezclan monedas.'],
});

Map<String, Object> _month(String month, String income, String result) => {
  'mes': month,
  'ingresos_caja': income,
  'egresos_caja': '35.00',
  'neto_caja': '115.00',
  'ingresos_por_tipo_pago': [
    {'id': 'cash', 'nombre': 'Efectivo', 'importe': '100.00'},
    {'id': 'card', 'nombre': 'Tarjeta', 'importe': '50.00'},
  ],
  'ingresos_por_cuenta': [
    {'cuenta_id': 'box', 'cuenta_nombre': 'Caja', 'importe': income},
  ],
  'gasto_devengado': '25.00',
  'gasto_por_categoria': [
    {'id': 'rent', 'nombre': 'Alquiler', 'importe': '25.00'},
  ],
  'gasto_recurrente_previsto': [
    {'id': 'rent', 'nombre': 'Alquiler', 'importe': '20.00', 'plantillas': 1},
  ],
  'margen_directo': '115.00',
  'fijo_no_distribuido': '10.00',
  'margen_menos_fijo': '105.00',
  'resultado_operativo_devengado': result,
  'resultado_signo': result.startsWith('-') ? 'NEGATIVO' : 'POSITIVO',
  'revaluacion_cambiaria': '-3.00',
  'cierres': {
    'cantidad': 1,
    'saldo_esperado': '150.00',
    'saldo_contado': '148.00',
    'diferencia': '-2.00',
  },
  'cobros_por_recepcionista': [
    {
      'nombre': 'Ana',
      'pagos': 2,
      'clientes': 2,
      'neto': income,
      'historico_sin_atribuir': false,
    },
  ],
  'estado': {
    'devengo': 'PROVISIONAL',
    'certificado': false,
    'revaluacion': 'PROVISIONAL',
  },
};
