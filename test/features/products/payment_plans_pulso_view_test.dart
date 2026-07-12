import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';
import 'package:gym_client/src/features/clients/presentation/state/client_notifier.dart';
import 'package:gym_client/src/features/financials/data/models/currency_model.dart';
import 'package:gym_client/src/features/financials/presentation/state/currency_notifier.dart';
import 'package:gym_client/src/features/products/data/models/payment_plan_model.dart';
import 'package:gym_client/src/features/products/presentation/screens/payment_plans_pulso_view.dart';
import 'package:gym_client/src/features/products/presentation/state/payment_plan_notifier.dart';

void main() {
  const sizes = <String, Size>{
    'compacto': Size(390, 844),
    'mediano': Size(760, 900),
    'escritorio': Size(1280, 900),
    'ventana baja': Size(1024, 650),
  };

  for (final entry in sizes.entries) {
    testWidgets('Planes PULSO se adapta al ancho ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(
        find.text('PLANES Y TARIFAS.', findRichText: true),
        findsOneWidget,
      );
      // El nombre del plan líder puede repetirse en la banda de métricas.
      expect(find.text('Mensual'), findsWidgets);
      expect(find.text('Semanal'), findsOneWidget);
      expect(find.text('MODO LOCAL'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final planRow = find.descendant(
        of: find.byKey(const PageStorageKey('pulso-plans-list')),
        matching: find.text('Mensual'),
      );
      if (entry.key == 'mediano') {
        await tester.tap(planRow);
        await tester.pumpAndSettle();
        expect(find.text('DETALLE SELECCIONADO'), findsOneWidget);
      }
      if (entry.key == 'escritorio') {
        await tester.tap(planRow);
        await tester.pump();
        expect(find.text('DETALLE SELECCIONADO'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cuenta socios activos y estima el ingreso mensual', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // Solo los socios ACTIVOS cuentan: 2 en Mensual, ninguno en Semanal.
    expect(find.text('2 socios'), findsOneWidget);
    expect(find.text('sin socios'), findsOneWidget);
    expect(find.text('Plan líder'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const PageStorageKey('pulso-plans-list')),
        matching: find.text('Mensual'),
      ),
    );
    await tester.pump();
    // 2 socios × Bs 250 × 30/30 días.
    expect(find.text('Bs 500.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite editar un plan y guarda los cambios', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final planNotifier = _PlanNotifier(_plans());
    await tester.pumpWidget(_harness(planNotifier: planNotifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar Mensual'));
    await tester.pumpAndSettle();
    expect(find.text('EDITAR PLAN'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('pulso-plan-name')),
      'Mensual plus',
    );
    await tester.tap(find.text('GUARDAR CAMBIOS'));
    await tester.pumpAndSettle();

    expect(planNotifier.updates, hasLength(1));
    final updated = planNotifier.updates.single;
    expect(updated.id, 'plan-mensual');
    expect(updated.nombre, 'Mensual plus');
    expect(updated.duracion, 30);
    expect(updated.monedaId, 'cur-bob');
    expect(find.text('EDITAR PLAN'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtra planes inactivos', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inactivos').last);
    await tester.pump();
    final list = find.byKey(const PageStorageKey('pulso-plans-list'));
    expect(
      find.descendant(of: list, matching: find.text('Semanal')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: list, matching: find.text('Mensual')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

List<PaymentPlanModel> _plans() => [
  PaymentPlanModel(
    id: 'plan-mensual',
    nombre: 'Mensual',
    importe: 250,
    duracion: 30,
    monedaId: 'cur-bob',
  ),
  PaymentPlanModel(
    id: 'plan-semanal',
    nombre: 'Semanal',
    importe: 80,
    duracion: 7,
    monedaId: 'cur-bob',
    activo: false,
  ),
];

Widget _harness({_PlanNotifier? planNotifier}) {
  return ProviderScope(
    overrides: [
      appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
      syncStatusProvider.overrideWith(
        (ref) => Stream.value(
          SyncStatusSnapshot.offline(
            detail: 'API remota no disponible',
            source: 'sync-local',
          ),
        ),
      ),
      currencyProvider.overrideWith(
        () => _CurrencyNotifier(const [
          CurrencyModel(
            id: 'cur-bob',
            name: 'Boliviano',
            code: 'BOB',
            symbol: 'Bs',
          ),
        ]),
      ),
      clientNotifierProvider.overrideWith(
        () => _ClientNotifier([
          ClientModel(id: '100', nombres: 'Ana', planId: 'plan-mensual'),
          ClientModel(id: '200', nombres: 'Luis', planId: 'plan-mensual'),
          ClientModel(
            id: '300',
            nombres: 'Eva',
            planId: 'plan-mensual',
            activo: false,
          ),
          ClientModel(id: '400', nombres: 'Juan'),
        ]),
      ),
      paymentPlanProvider.overrideWith(
        () => planNotifier ?? _PlanNotifier(_plans()),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: PaymentPlansPulsoView())),
  );
}

class _PlanNotifier extends PaymentPlanNotifier {
  _PlanNotifier(this.items);
  final List<PaymentPlanModel> items;
  final updates = <PaymentPlanModel>[];

  @override
  Future<List<PaymentPlanModel>> build() async => items;

  @override
  Future<void> updatePlan(PaymentPlanModel plan) async {
    updates.add(plan);
  }
}

class _CurrencyNotifier extends CurrencyNotifier {
  _CurrencyNotifier(this.items);
  final List<CurrencyModel> items;

  @override
  Future<List<CurrencyModel>> build() async => items;
}

class _ClientNotifier extends ClientNotifier {
  _ClientNotifier(this.items);
  final List<ClientModel> items;

  @override
  Future<List<ClientModel>> build() async => items;
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
