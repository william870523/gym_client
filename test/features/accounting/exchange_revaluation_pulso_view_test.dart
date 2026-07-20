import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/accounting/data/models/exchange_revaluation_models.dart';
import 'package:gym_client/src/features/accounting/data/repositories/accounting_repository.dart';
import 'package:gym_client/src/features/accounting/presentation/screens/exchange_revaluation_pulso_view.dart';

void main() {
  testWidgets('muestra la pérdida cambiaria y el desglose por moneda', (
    tester,
  ) async {
    await _pump(tester, const Size(1000, 900), _FakeRepo(_lossReport()));

    expect(find.text('REVALUACIÓN\nCAMBIARIA.'), findsOneWidget);
    expect(find.textContaining('PÉRDIDA CAMBIARIA'), findsOneWidget);
    expect(find.text('-5.60 EUR'), findsWidgets); // total y/o por moneda
    expect(find.text('MONEDA · CUP'), findsOneWidget);
    expect(find.text('14.00 EUR'), findsOneWidget); // valor al cobro
    expect(find.text('8.40 EUR'), findsOneWidget); // valor al corte
    expect(tester.takeException(), isNull);
  });

  testWidgets('explica la falta de moneda base', (tester) async {
    await _pump(
      tester,
      const Size(500, 800),
      _FakeRepo(_noBaseReport()),
    );

    expect(find.textContaining('Configura la moneda base'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Size size,
  AccountingRepository repository,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
        accountingRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        home: Scaffold(body: ExchangeRevaluationPulsoView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeRepo extends AccountingRepository {
  _FakeRepo(this._report) : super(Dio());
  final ExchangeRevaluationModel _report;

  @override
  Future<ExchangeRevaluationModel> getExchangeRevaluation({String? month}) async =>
      _report;
}

ExchangeRevaluationModel _lossReport() =>
    ExchangeRevaluationModel.fromJson(const {
      'mes': '2026-07',
      'fecha_corte': '2026-07-31',
      'estado': 'PROVISIONAL',
      'moneda_base_id': 'eur',
      'moneda_base_codigo': 'EUR',
      'total_revaluacion': '-5.60',
      'efecto_total': 'PERDIDA',
      'cobros': 2,
      'cobros_sin_tasa_corte': 0,
      'nota': 'nota',
      'limitaciones': ['Es un informe de lectura.'],
      'monedas': [
        {
          'moneda_id': 'cup',
          'moneda_codigo': 'CUP',
          'cobros': 2,
          'importe_debil': '4200.00',
          'valor_al_cobro': '14.00',
          'valor_al_corte': '8.40',
          'revaluacion': '-5.60',
          'efecto': 'PERDIDA',
          'cobros_sin_tasa_corte': 0,
        },
      ],
    });

ExchangeRevaluationModel _noBaseReport() =>
    ExchangeRevaluationModel.fromJson(const {
      'mes': '2026-07',
      'fecha_corte': '2026-07-31',
      'estado': 'SIN_MONEDA_BASE',
      'total_revaluacion': '0.00',
      'monedas': [],
      'cobros': 0,
      'cobros_sin_tasa_corte': 0,
      'nota': 'Configura la moneda base (BASE_CURRENCY_ID).',
      'limitaciones': [],
    });

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
