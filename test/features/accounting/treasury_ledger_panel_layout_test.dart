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

/// Alto del panel del cierre diario.
///
/// El panel tiene altura fija y elegía el alto por debajo de 760 px, mientras
/// que el libro pasa a apilarse (cuentas sobre movimientos) por debajo de 880:
/// entre esos dos umbrales la vista desbordaba. Esta prueba fija los anchos de
/// la lista de comprobación de PULSO (360 / 768 / 1280).
class _FakeAccountingRepository extends AccountingRepository {
  _FakeAccountingRepository() : super(Dio());
}

TreasuryLedgerModel _ledger() {
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
    'recargos_condonados': {
      'condonaciones': 0,
      'por_moneda': [],
      'detalle': [],
    },
    'cobros_por_recepcionista': [
      {
        'cobrado_por_user_id': 'reception-ana',
        'cobrado_por_nombre_snapshot': 'Ana Recepción',
        'cobrado_por_rol_snapshot': 'reception',
        'cobrado_por_origen': 'user',
        'historico_sin_atribuir': false,
        'cuenta_id': 'cash-cup',
        'cuenta_nombre': 'Caja CUP',
        'moneda_id': 'cup',
        'moneda_codigo': 'CUP',
        'pagos': 2,
        'clientes': 2,
        'bruto': '60.00',
        'cambio': '3.00',
        'anulado': '0.00',
        'neto': '57.00',
      },
    ],
  });
}

Widget _harness() {
  return ProviderScope(
    overrides: [
      accountingRepositoryProvider.overrideWithValue(
        _FakeAccountingRepository(),
      ),
      treasuryLedgerProvider.overrideWith((ref, date) async => _ledger()),
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
  for (final size in [
    const Size(360, 1400),
    const Size(768, 1200),
    const Size(1280, 1200),
  ]) {
    testWidgets('el cierre no desborda a ${size.width.toInt()} px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('abre el detalle de cobros por recepcionista sin desbordar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('COBROS POR RECEPCIONISTA'), findsOneWidget);
    await tester.tap(find.byKey(const Key('treasury-collectors-toggle')));
    await tester.pump();

    expect(find.byKey(const Key('treasury-collectors-detail')), findsOneWidget);
    expect(find.text('Ana Recepción'), findsOneWidget);
    expect(find.text('CUP 57.00 neto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
