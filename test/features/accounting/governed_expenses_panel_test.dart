import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_palette_id.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_theme.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_tokens.dart';
import 'package:gym_client/src/features/accounting/data/models/accounting_models.dart';
import 'package:gym_client/src/features/accounting/data/models/recurring_expense_models.dart';
import 'package:gym_client/src/features/accounting/data/repositories/accounting_repository.dart';
import 'package:gym_client/src/features/accounting/presentation/screens/accounting_view.dart';
import 'package:gym_client/src/features/accounting/presentation/state/accounting_providers.dart';
import 'package:gym_client/src/features/accounting/presentation/widgets/governed_expenses_panel.dart';
import 'package:gym_client/src/features/accounting/presentation/widgets/recurring_expenses_panel.dart';
import 'package:gym_client/src/features/financials/data/models/currency_model.dart';
import 'package:gym_client/src/features/financials/presentation/state/currency_notifier.dart';

class _FakeAccountingRepository extends AccountingRepository {
  _FakeAccountingRepository() : super(Dio());
}

GovernedExpensesReportModel _report() =>
    GovernedExpensesReportModel.fromJson(const {
      'mes': '2026-07',
      'fecha_corte': '2026-07-19',
      'monedas': [
        {
          'moneda_id': 'cur-cup',
          'moneda_codigo': 'CUP',
          'devengado_mes': '1500.00',
          'pagado_mes': '500.00',
          'pagado_acumulado': '500.00',
          'pendiente_pago': '1000.00',
          'gastos': [
            {
              'gasto_id': 'g-cup',
              'categoria_id': 'c1',
              'categoria_nombre': 'Alquiler',
              'categoria_naturaleza': 'ADMINISTRATIVO',
              'moneda_id': 'cur-cup',
              'moneda_codigo': 'CUP',
              'descripcion': 'Alquiler local julio',
              'importe': '1500.00',
              'mes_pertenencia': '2026-07',
              'pagado_acumulado': '500.00',
              'estado': 'PARCIAL',
              'aplicaciones': [],
            },
          ],
        },
        {
          'moneda_id': 'cur-eur',
          'moneda_codigo': 'EUR',
          'devengado_mes': '25.00',
          'pagado_mes': '0.00',
          'pagado_acumulado': '0.00',
          'pendiente_pago': '25.00',
          'gastos': [
            {
              'gasto_id': 'g-eur',
              'categoria_id': 'c1',
              'categoria_nombre': 'Alquiler',
              'categoria_naturaleza': 'OPERATIVO',
              'moneda_id': 'cur-eur',
              'moneda_codigo': 'EUR',
              'descripcion': 'Licencia europea',
              'importe': '25.00',
              'mes_pertenencia': '2026-07',
              'pagado_acumulado': '0.00',
              'estado': 'PENDIENTE',
              'aplicaciones': [],
            },
          ],
        },
      ],
    });

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
      currencyProvider.overrideWith(
        () => _CurrencyNotifier(const [
          CurrencyModel(id: 'cur-eur', name: 'Euro', code: 'EUR', symbol: '€'),
        ]),
      ),
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
  test('el modelo conserva monedas y aliases reales del informe', () {
    final report = _report();

    expect(report.monedas.map((item) => item.codigoMoneda), ['CUP', 'EUR']);
    expect(report.monedas[0].devengadoMes, '1500.00');
    expect(report.monedas[1].pendientePago, '25.00');
    expect(report.monedas[0].gastos.single.monto, '1500.00');
    expect(report.monedas[0].gastos.single.periodoPertenenciaMes, '2026-07');
    expect(report.monedas[0].gastos.single.naturaleza, 'ADMINISTRATIVO');
  });

  testWidgets('la interfaz separa CUP y EUR sin símbolo monetario supuesto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('governed-expenses-currency-CUP')), findsOne);
    expect(find.byKey(const Key('governed-expenses-currency-EUR')), findsOne);
    expect(find.text('1500.00 CUP'), findsAtLeastNWidgets(2));
    expect(find.text('25.00 EUR'), findsAtLeastNWidgets(2));
    expect(find.textContaining(r'$'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final entry in const {
    'compacto': Size(390, 844),
    'expandido': Size(1280, 900),
  }.entries) {
    testWidgets(
      'ruta real Gastos → Recurrentes tiene un solo scroll vertical ${entry.key}',
      (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_accountingRouteHarness());
        await tester.pumpAndSettle();

        final expensesTab = find.text('GASTOS DEVENGADOS');
        await tester.ensureVisible(expensesTab);
        await tester.tap(expensesTab);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('governed-expenses-scroll')),
          findsOneWidget,
        );

        final recurringAction = find.byKey(
          const Key('governed-expenses-recurring-action'),
        );
        await tester.ensureVisible(recurringAction);
        await tester.tap(recurringAction);
        await tester.pumpAndSettle();

        expect(find.byType(RecurringExpensesPanel), findsOneWidget);
        expect(
          find.byKey(const Key('recurring-expenses-list')),
          findsOneWidget,
        );
        expect(
          find.ancestor(
            of: find.byType(RecurringExpensesPanel),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is SingleChildScrollView &&
                  widget.scrollDirection == Axis.vertical,
            ),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

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

Widget _accountingRouteHarness() {
  final summary = AccountingSummaryModel(
    pendingTrainerAmount: 0,
    pendingTrainerCount: 0,
    overdueTrainerCount: 0,
    paidTrainerCount: 0,
    activeRuleCount: 0,
    defaultRuleCount: 0,
    individualRuleCount: 0,
    fixedPayrollProfiles: 0,
    fixedPayrollPending: 0,
  );
  return ProviderScope(
    overrides: [
      appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
      syncStatusProvider.overrideWith(
        (ref) => Stream.value(
          SyncStatusSnapshot.offline(
            detail: 'Sin cambios pendientes',
            source: 'test',
          ),
        ),
      ),
      accountingSummaryProvider.overrideWith((ref) async => summary),
      trainerPayablesProvider.overrideWith((ref) async => []),
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
      recurringExpensePlanProvider.overrideWith(
        (ref, month) async => _recurringPlan(),
      ),
      recurringExpensesProvider.overrideWith((ref) async => []),
    ],
    child: const MaterialApp(home: Scaffold(body: AccountingView())),
  );
}

RecurringExpensePlanModel _recurringPlan() =>
    RecurringExpensePlanModel.fromJson(const {
      'mes': '2026-07',
      'estado_periodo': 'ABIERTO',
      'puede_generar': false,
      'motivo_bloqueo': 'No hay gastos pendientes de generar.',
      'resumen': {
        'plantillas_evaluadas': 0,
        'a_generar': 0,
        'omitidas': 0,
        'ya_generadas': 0,
      },
      'a_generar': [],
      'omitidas': [],
      'totales_por_moneda': [],
      'nota': 'Vista de prueba sin mezclar monedas.',
      'limitaciones': ['No mezcla ni convierte monedas.'],
      'generados': [],
    });

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}

class _CurrencyNotifier extends CurrencyNotifier {
  _CurrencyNotifier(this.items);
  final List<CurrencyModel> items;

  @override
  Future<List<CurrencyModel>> build() async => items;
}
