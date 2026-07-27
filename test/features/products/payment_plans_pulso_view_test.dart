import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_client/src/features/products/data/repositories/payment_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';
import 'package:gym_client/src/features/clients/presentation/state/client_notifier.dart';
import 'package:gym_client/src/features/clients/presentation/state/clients_scope_filter_provider.dart';
import 'package:gym_client/src/features/dashboard/presentation/state/dashboard_nav_provider.dart';
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

  testWidgets('cuenta asociados y estima el ingreso mensual', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // Criterio del dueño (docs/PLAN_ASOCIADOS.md §5): vigente, pendiente de
    // pago y vencida reciente. Quedan fuera la vencida hace 90 días y la baja.
    expect(find.text('3 socios'), findsOneWidget);
    expect(find.text('sin socios'), findsOneWidget);
    expect(find.text('Plan líder'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const PageStorageKey('pulso-plans-list')),
        matching: find.text('Mensual'),
      ),
    );
    await tester.pump();
    // 3 asociados × Bs 250 × 30/30 días.
    expect(find.text('Bs 750.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el contador lleva a Clientes con el plan filtrado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = _container();
    await tester.pumpWidget(_harness(container: container));
    await tester.pumpAndSettle();

    // El contador es el enlace: pulsarlo deja el filtro puesto y salta a
    // Clientes (índice 1 del panel principal).
    await tester.tap(find.text('3 socios'));
    await tester.pumpAndSettle();

    final filter = container.read(clientsScopeFilterProvider);
    expect(filter?.kind, ClientsFilterKind.plan);
    expect(filter?.id, 'plan-mensual');
    expect(filter?.label, 'Mensual');
    expect(container.read(dashboardNavProvider), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un plan sin asociados no promete una lista vacía', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = _container();
    await tester.pumpWidget(_harness(container: container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('sin socios'));
    await tester.pumpAndSettle();

    expect(container.read(clientsScopeFilterProvider), isNull);
    expect(container.read(dashboardNavProvider), 0);
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

  testWidgets('bloquea guardar cuando el esquema de cuotas no cuadra', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final planNotifier = _PlanNotifier(_plans());
    await tester.pumpWidget(_harness(planNotifier: planNotifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar Mensual'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('pulso-plan-cuotas-toggle')),
    );
    await tester.tap(find.byKey(const ValueKey('pulso-plan-cuotas-toggle')));
    await tester.pumpAndSettle();

    // El borrador por defecto cuadra (mitad y mitad): se puede guardar.
    expect(find.text('Esquema de cuotas válido'), findsOneWidget);

    // Pasarse de la tarifa invalida el esquema, avisa el exceso por cuota y
    // deshabilita el guardado.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Importe (€)').first,
      '300',
    );
    await tester.pumpAndSettle();
    expect(find.text('Revisar totales del esquema'), findsOneWidget);
    expect(find.textContaining('Se pasa por'), findsOneWidget);

    await tester.tap(find.text('GUARDAR CAMBIOS'));
    await tester.pumpAndSettle();
    // El formulario sigue abierto y no se persistió nada.
    expect(find.text('EDITAR PLAN'), findsOneWidget);
    expect(planNotifier.updates, isEmpty);
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

  testWidgets('busca un plan por su código, no solo por el nombre', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // El operador teclea el código que ve en la tabla. Antes no devolvía nada
    // porque la búsqueda solo miraba nombre, duración, importe y moneda.
    await tester.enterText(find.byType(TextField).first, 'PCU-3');
    await tester.pumpAndSettle();

    final list = find.byKey(const PageStorageKey('pulso-plans-list'));
    expect(
      find.descendant(of: list, matching: find.text('Mensual')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: list, matching: find.text('Semanal')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

/// Socios de la fixture, uno por caso del criterio de asociado
/// (docs/PLAN_ASOCIADOS.md §5). El contador ya no cuenta la bandera `activo`
/// del cliente: cuenta membresías del plan.
List<ClientModel> _clients() {
  final today = DateTime.now().toUtc();
  return [
    // Vigente.
    ClientModel(
      id: '100',
      nombres: 'Ana',
      planId: 'plan-mensual',
      membershipStatus: 'ACTIVA',
      endDate: today.add(const Duration(days: 12)),
    ),
    // Contrató y aún no paga: también es asociado.
    ClientModel(
      id: '200',
      nombres: 'Luis',
      planId: 'plan-mensual',
      membershipStatus: 'PENDIENTE_PAGO',
    ),
    // Venció hace poco: dentro de la ventana de 30 días.
    ClientModel(
      id: '250',
      nombres: 'Rosa',
      planId: 'plan-mensual',
      membershipStatus: 'ACTIVA',
      endDate: today.subtract(const Duration(days: 10)),
    ),
    // Venció hace mucho: ya no es asociado.
    ClientModel(
      id: '260',
      nombres: 'Tomás',
      planId: 'plan-mensual',
      membershipStatus: 'ACTIVA',
      endDate: today.subtract(const Duration(days: 90)),
    ),
    // Sin membresía viva (baja): no cuenta.
    ClientModel(
      id: '300',
      nombres: 'Eva',
      planId: 'plan-mensual',
      activo: false,
    ),
    ClientModel(id: '400', nombres: 'Juan'),
  ];
}

List<PaymentPlanModel> _plans() => [
  PaymentPlanModel(
    id: 'plan-mensual',
    nombre: 'Mensual',
    codigo: 'PCU-3',
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

Widget _harness({_PlanNotifier? planNotifier, ProviderContainer? container}) {
  return UncontrolledProviderScope(
    container: container ?? _container(planNotifier: planNotifier),
    child: const MaterialApp(home: Scaffold(body: PaymentPlansPulsoView())),
  );
}

ProviderContainer _container({_PlanNotifier? planNotifier}) {
  final container = ProviderContainer(
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
      clientNotifierProvider.overrideWith(() => _ClientNotifier(_clients())),
      paymentPlanProvider.overrideWith(
        () => planNotifier ?? _PlanNotifier(_plans()),
      ),
      paymentPlanRepositoryProvider.overrideWith(
        (ref) => _FakePlanRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _FakePlanRepository extends PaymentPlanRepository {
  _FakePlanRepository() : super(Dio());
  final savedSchemes = <(String, List<Map<String, dynamic>>)>[];

  @override
  Future<List<Map<String, dynamic>>> getPlanCuotasScheme(String planId) async =>
      const [];

  @override
  Future<void> savePlanCuotasScheme(
    String planId,
    List<Map<String, dynamic>> tranches,
  ) async {
    savedSchemes.add((planId, tranches));
  }
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
