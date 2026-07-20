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
import 'package:gym_client/src/features/accounting/presentation/widgets/governed_expenses_panel.dart';
import 'package:gym_client/src/features/financials/data/models/currency_model.dart';
import 'package:gym_client/src/features/financials/presentation/state/currency_notifier.dart';

class _FakeAccountingRepository extends AccountingRepository {
  _FakeAccountingRepository() : super(Dio());
}

GovernedExpensesReportModel _report() => GovernedExpensesReportModel(
  mes: '2026-07',
  fechaNegocio: '2026-07-19',
  gastos: [
    GastoGobernadoModel.fromJson(const {
      'gasto_id': 'g1',
      'descripcion': 'Alquiler local julio',
      'categoria_nombre': 'Alquiler',
      'monto': '500.00',
      'pagado_acumulado': '0.00',
      'estado': 'PENDIENTE',
      'aplicaciones': [],
    }),
  ],
  resumenPorCategoria: const {},
  resumenPorNaturaleza: const {},
  totalDevengado: '500.00',
  totalPagado: '0.00',
  totalPendiente: '500.00',
);

Widget _harness() {
  return ProviderScope(
    overrides: [
      accountingRepositoryProvider.overrideWithValue(
        _FakeAccountingRepository(),
      ),
      governedExpensesProvider.overrideWith((ref, month) async => _report()),
      governedExpenseCategoriesProvider.overrideWith(
        (ref) async => [
          GastoCategoriaModel.fromJson(const {
            'categoria_id': 'c1',
            'nombre': 'Alquiler',
            'naturaleza': 'OPERATIVO',
          }),
        ],
      ),
      governedExpenseSuppliersProvider.overrideWith((ref) async => []),
      currencyProvider.overrideWith(() => _CurrencyNotifier(const [
        CurrencyModel(id: 'cur-eur', name: 'Euro', code: 'EUR', symbol: '€'),
      ])),
    ],
    child: MaterialApp(
      theme: PulsoThemeFactory.build(
        PulsoTokens.resolve(PulsoPaletteId.clay, Brightness.light),
      ),
      home: Scaffold(
        body: GovernedExpensesPanel(initialMonth: '2026-07', onBack: () {}),
      ),
    ),
  );
}

void main() {
  testWidgets('el gasto abre el diálogo PULSO de nuevo gasto', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // El gasto de la fixture aparece.
    expect(find.text('Alquiler local julio'), findsOneWidget);

    // El botón primario PULSO muestra su rótulo en mayúsculas.
    expect(find.text('NUEVO GASTO'), findsOneWidget);
    await tester.tap(find.text('NUEVO GASTO'));
    await tester.pumpAndSettle();

    // El diálogo usa la gramática PULSO (no un AlertDialog Material).
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.textContaining('Gasto devengado por su mes de pertenencia'),
      findsOneWidget,
    );
    expect(find.text('GUARDAR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _CurrencyNotifier extends CurrencyNotifier {
  _CurrencyNotifier(this.items);
  final List<CurrencyModel> items;

  @override
  Future<List<CurrencyModel>> build() async => items;
}
