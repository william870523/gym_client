import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_palette_id.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_theme.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_tokens.dart';
import 'package:gym_client/src/features/accounting/data/models/accounting_models.dart';
import 'package:gym_client/src/features/accounting/data/repositories/accounting_repository.dart';
import 'package:gym_client/src/features/accounting/presentation/state/accounting_providers.dart';
import 'package:gym_client/src/features/accounting/presentation/widgets/treasury_ledger_panel.dart';

/// Bloque «Cobros por recepcionista» del cierre diario
/// (docs/PAYMENT_COLLECTOR_ATTRIBUTION.md §6).
///
/// El servidor calcula y agrupa; la vista solo presenta. Lo que se comprueba
/// aquí: que se vea quién cobró, que no se sumen monedas, que el grupo
/// histórico se rotule como tal y que un pago mixto no cuente doble.
class _FakeAccountingRepository extends AccountingRepository {
  _FakeAccountingRepository() : super(Dio());
}

TreasuryLedgerModel _ledger({required bool withCollectors}) {
  return TreasuryLedgerModel.fromJson({
    'fecha_negocio': '2026-07-25',
    'resumen_monedas': [
      {
        'moneda_id': 'cup',
        'moneda_codigo': 'CUP',
        'entradas': '110.00',
        'salidas': '10.00',
        'neto': '100.00',
        'movimientos': 5,
      },
    ],
    'cuentas': [],
    'movimientos': [
      {
        'movimiento_id': 'mov-1',
        'origen_tipo': 'PAGO_CLIENTE',
        'origen_id': 'pago-1',
        'direccion': 'ENTRADA',
        'concepto': 'PLAN_CLIENTE',
        'cuenta_id': 'caja',
        'cuenta_nombre': 'Caja principal',
        'moneda_id': 'cup',
        'moneda_codigo': 'CUP',
        'monto': '50.00',
        'ocurrido_at': '2026-07-25T14:00:00.000Z',
        'cobrado_por_user_id': 'ana',
        'cobrado_por_nombre_snapshot': 'Ana Recepción',
        'cobrado_por_rol_snapshot': 'recepcionista',
      },
      {
        'movimiento_id': 'mov-2',
        'origen_tipo': 'PAGO_REVERSION',
        'origen_id': 'rev-1',
        'direccion': 'SALIDA',
        'concepto': 'ANULACION_COBRO',
        'cuenta_id': 'caja',
        'cuenta_nombre': 'Caja principal',
        'moneda_id': 'cup',
        'moneda_codigo': 'CUP',
        'monto': '10.00',
        'ocurrido_at': '2026-07-25T18:00:00.000Z',
        'cobrado_por_user_id': 'ana',
        'cobrado_por_nombre_snapshot': 'Ana Recepción',
        'anulado_por_nombre_snapshot': 'Carla Supervisión',
      },
      {
        'movimiento_id': 'mov-3',
        'origen_tipo': 'PAGO_CLIENTE',
        'origen_id': 'pago-viejo',
        'direccion': 'ENTRADA',
        'concepto': 'PLAN_CLIENTE',
        'cuenta_id': 'caja',
        'cuenta_nombre': 'Caja principal',
        'moneda_id': 'cup',
        'moneda_codigo': 'CUP',
        'monto': '20.00',
        'ocurrido_at': '2026-07-25T09:00:00.000Z',
      },
    ],
    'incidencias': {
      'sin_cuenta': 0,
      'requieren_revision': 0,
      'movimientos_tardios': 0,
    },
    'recargos_condonados': {
      'condonaciones': 0,
      'por_moneda': [],
      'detalle': [],
    },
    'cobros_por_recepcionista': withCollectors
        ? [
            {
              'cuenta_id': 'caja',
              'cuenta_nombre': 'Caja principal',
              'moneda_id': 'cup',
              'moneda_codigo': 'CUP',
              'cobrado_por_user_id': 'ana',
              'cobrado_por_nombre_snapshot': 'Ana Recepción',
              'cobrado_por_rol_snapshot': 'recepcionista',
              'cobrado_por_origen': 'LOCAL_USER',
              'historico_sin_atribuir': false,
              'pagos': 2,
              'clientes': 2,
              'bruto': '50.00',
              'cambio': '0.00',
              'anulado': '10.00',
              'neto': '40.00',
            },
            {
              'cuenta_id': 'caja-usd',
              'cuenta_nombre': 'Caja divisas',
              'moneda_id': 'usd',
              'moneda_codigo': 'USD',
              'cobrado_por_user_id': 'bruno',
              'cobrado_por_nombre_snapshot': 'Bruno Turno Tarde',
              'cobrado_por_rol_snapshot': 'recepcionista',
              'cobrado_por_origen': 'SYNCED_USER',
              'historico_sin_atribuir': false,
              // Pago mixto de dos detalles: sigue siendo un solo cobro.
              'pagos': 1,
              'clientes': 1,
              'bruto': '30.00',
              'cambio': '0.00',
              'anulado': '0.00',
              'neto': '30.00',
            },
            {
              'cuenta_id': 'caja',
              'cuenta_nombre': 'Caja principal',
              'moneda_id': 'cup',
              'moneda_codigo': 'CUP',
              'cobrado_por_user_id': null,
              'cobrado_por_nombre_snapshot': null,
              'historico_sin_atribuir': true,
              'pagos': 1,
              'clientes': 1,
              'bruto': '20.00',
              'cambio': '0.00',
              'anulado': '0.00',
              'neto': '20.00',
            },
          ]
        : [],
    'cobros_sin_atribuir': withCollectors ? 1 : 0,
  });
}

Widget _harness(TreasuryLedgerModel ledger) {
  return ProviderScope(
    overrides: [
      accountingRepositoryProvider.overrideWithValue(
        _FakeAccountingRepository(),
      ),
      treasuryLedgerProvider.overrideWith((ref, date) async => ledger),
    ],
    child: MaterialApp(
      theme: PulsoThemeFactory.build(
        PulsoTokens.resolve(PulsoPaletteId.clay, Brightness.light),
      ),
      home: Scaffold(body: TreasuryLedgerPanel(onChanged: () {})),
    ),
  );
}

void main() {
  Future<void> pumpAt(WidgetTester tester, Size size, Widget widget) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  testWidgets('resume cuántas personas cobraron y cuántos cobros hubo', (
    tester,
  ) async {
    await pumpAt(
      tester,
      const Size(1280, 1400),
      _harness(_ledger(withCollectors: true)),
    );

    expect(find.text('COBROS POR RECEPCIONISTA'), findsOneWidget);
    // Dos grupos con persona y uno histórico, anunciado aparte para que nadie
    // lo confunda con un cobrador más.
    expect(
      find.text('2 atribuido(s) · 1 histórico(s) sin atribuir'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('al abrirlo enseña a cada cobrador con su moneda', (
    tester,
  ) async {
    await pumpAt(
      tester,
      const Size(1280, 1400),
      _harness(_ledger(withCollectors: true)),
    );

    expect(find.text('Ana Recepción'), findsNothing);

    await tester.tap(find.text('COBROS POR RECEPCIONISTA'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Recepción'), findsOneWidget);
    expect(find.text('Bruno Turno Tarde'), findsOneWidget);
    // Cada fila en su moneda; nunca un total de 90.00 mezclando CUP y USD.
    expect(find.text('CUP 40.00 neto'), findsOneWidget);
    expect(find.text('USD 30.00 neto'), findsOneWidget);
    expect(find.text('90.00'), findsNothing);
    // Lo anulado se enseña aparte del bruto, no escondido dentro del neto.
    expect(
      find.text('Bruto 50.00 · cambio 0.00 · anulado 10.00'),
      findsOneWidget,
    );
    // Un pago mixto es un cobro, no dos.
    expect(
      find.textContaining('Caja divisas · 1 pago(s) · 1 cliente(s)'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('el cobro histórico se rotula «sin atribuir», no en blanco', (
    tester,
  ) async {
    await pumpAt(
      tester,
      const Size(1280, 1400),
      _harness(_ledger(withCollectors: true)),
    );

    await tester.tap(find.text('COBROS POR RECEPCIONISTA'));
    await tester.pumpAndSettle();

    expect(find.text('Sin atribuir · histórico'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el movimiento dice quién cobró y quién anuló', (tester) async {
    await pumpAt(
      tester,
      const Size(1280, 1400),
      _harness(_ledger(withCollectors: true)),
    );

    // Cobrado por A / anulado por B: son responsabilidades distintas y las dos
    // se conservan.
    expect(
      find.textContaining('Cobrado por Ana Recepción · Anulado por Carla'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin cobros del día el bloque no se dibuja', (tester) async {
    await pumpAt(
      tester,
      const Size(1280, 1400),
      _harness(_ledger(withCollectors: false)),
    );

    expect(find.text('COBROS POR RECEPCIONISTA'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(360, 1600), Size(768, 1400)]) {
    testWidgets('a ${size.width.toInt()} px no desborda', (tester) async {
      await pumpAt(tester, size, _harness(_ledger(withCollectors: true)));

      expect(find.text('COBROS POR RECEPCIONISTA'), findsOneWidget);
      await tester.tap(find.text('COBROS POR RECEPCIONISTA'));
      await tester.pumpAndSettle();

      expect(find.text('Ana Recepción'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
