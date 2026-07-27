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

/// Línea «recargos condonados» del cierre diario (docs/RECARGO_MORA.md §6-bis).
///
/// El importe lo calcula el servidor; la vista solo lo presenta. Se comprueba
/// que se muestre por moneda, que se abra el detalle y que desaparezca cuando
/// no hubo condonaciones.
class _FakeAccountingRepository extends AccountingRepository {
  _FakeAccountingRepository() : super(Dio());
}

TreasuryLedgerModel _ledger({required bool withWaived}) {
  return TreasuryLedgerModel.fromJson({
    'fecha_negocio': '2026-07-25',
    'resumen_monedas': [
      {
        'moneda_id': 'cup',
        'moneda_codigo': 'CUP',
        'entradas': '57.00',
        'salidas': '0.00',
        'neto': '57.00',
        'movimientos': 4,
      },
    ],
    'cuentas': [],
    'movimientos': [],
    'incidencias': {
      'sin_cuenta': 0,
      'requieren_revision': 0,
      'movimientos_tardios': 0,
    },
    'recargos_condonados': withWaived
        ? {
            'condonaciones': 3,
            'por_moneda': [
              {
                'moneda_id': 'cup',
                'moneda_codigo': 'CUP',
                'importe': '4.25',
                'condonaciones': 2,
              },
              {
                'moneda_id': 'usd',
                'moneda_codigo': 'USD',
                'importe': '5.50',
                'condonaciones': 1,
              },
            ],
            'detalle': [
              {
                'pago_cliente_id': 'pago-1',
                'ci': '99080900001',
                'socio': 'Marta Pérez',
                'importe': '3.00',
                'moneda_id': 'cup',
                'moneda_codigo': 'CUP',
                'motivo': 'Socio hospitalizado, autorizado',
                'condonado_por_user_id': 'user-1',
                'condonado_por': 'Ana Recepción',
              },
              {
                'pago_cliente_id': 'pago-2',
                'ci': '99080900003',
                'socio': 'Luis Gómez',
                'importe': '1.25',
                'moneda_id': 'cup',
                'moneda_codigo': 'CUP',
                'motivo': 'Corte de luz en el gimnasio',
                'condonado_por_user_id': 'user-1',
                'condonado_por': 'Ana Recepción',
              },
              {
                'pago_cliente_id': 'pago-3',
                'ci': '99080900004',
                'socio': 'Iván Soto',
                'importe': '5.50',
                'moneda_id': 'usd',
                'moneda_codigo': 'USD',
                'motivo': 'Error de la recepción',
                'condonado_por_user_id': 'user-2',
                'condonado_por': 'Beto Caja',
              },
            ],
          }
        : {'condonaciones': 0, 'por_moneda': [], 'detalle': []},
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
  testWidgets('muestra lo condonado por moneda, sin un total mezclado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(_ledger(withWaived: true)));
    await tester.pumpAndSettle();

    expect(find.text('RECARGOS CONDONADOS'), findsOneWidget);
    // Cada moneda con su cifra, separadas: nunca 9.75.
    expect(find.text('CUP 4.25  ·  USD 5.50'), findsOneWidget);
    expect(find.textContaining('no afecta el arqueo'), findsOneWidget);
    expect(find.text('9.75'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('al abrirla enseña socio, importe, motivo y quién autorizó', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(_ledger(withWaived: true)));
    await tester.pumpAndSettle();

    // Cerrada, el detalle no está.
    expect(find.text('Marta Pérez'), findsNothing);

    await tester.tap(find.text('RECARGOS CONDONADOS'));
    await tester.pumpAndSettle();

    expect(find.text('Marta Pérez'), findsOneWidget);
    expect(find.text('CUP 3.00'), findsOneWidget);
    expect(
      find.text('Socio hospitalizado, autorizado · autorizó Ana Recepción'),
      findsOneWidget,
    );
    expect(find.text('Iván Soto'), findsOneWidget);
    expect(find.text('USD 5.50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin condonaciones la línea no se dibuja', (tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(_ledger(withWaived: false)));
    await tester.pumpAndSettle();

    expect(find.text('RECARGOS CONDONADOS'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a 360 px de ancho no desborda', (tester) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(_ledger(withWaived: true)));
    await tester.pumpAndSettle();

    expect(find.text('RECARGOS CONDONADOS'), findsOneWidget);
    await tester.tap(find.text('RECARGOS CONDONADOS'));
    await tester.pumpAndSettle();

    expect(find.text('Marta Pérez'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a 768 px de ancho tampoco desborda', (tester) async {
    tester.view.physicalSize = const Size(768, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(_ledger(withWaived: true)));
    await tester.pumpAndSettle();

    expect(find.text('RECARGOS CONDONADOS'), findsOneWidget);
    expect(find.text('CUP 4.25  ·  USD 5.50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
