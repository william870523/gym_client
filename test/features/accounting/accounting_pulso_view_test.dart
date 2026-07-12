import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/accounting/data/models/accounting_models.dart';
import 'package:gym_client/src/features/accounting/presentation/screens/accounting_view.dart';
import 'package:gym_client/src/features/accounting/presentation/state/accounting_providers.dart';
import 'package:gym_client/src/features/products/data/models/payment_plan_model.dart';
import 'package:gym_client/src/features/products/presentation/state/payment_plan_notifier.dart';
import 'package:gym_client/src/features/trainers/data/models/trainer_model.dart';
import 'package:gym_client/src/features/trainers/presentation/providers/trainer_notifier.dart';

void main() {
  for (final entry in const {
    'compacto': Size(390, 844),
    'mediano': Size(760, 900),
    'escritorio': Size(1280, 900),
  }.entries) {
    testWidgets('Contabilidad PULSO se adapta al ancho ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('CONTABILIDAD.', findRichText: true), findsOneWidget);
      expect(find.text('Cuotas pendientes'), findsOneWidget);
      expect(find.text('USD 100.00'), findsOneWidget);
      expect(find.text('PYG 200.00'), findsOneWidget);
      expect(find.textContaining('sin mezclar monedas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('conecta cuotas, reglas y nómina desde las pestañas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('CUOTAS ENTRENADORES'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Coach'), findsWidgets);
    expect(find.text('USD 100.00'), findsOneWidget);

    await tester.tap(find.text('REGLAS DE COMISIÓN'));
    await tester.pumpAndSettle();
    expect(find.text('Mensual'), findsOneWidget);
    expect(find.text('10.00%'), findsOneWidget);
    expect(find.text('NUEVA REGLA'), findsOneWidget);

    await tester.tap(find.text('NÓMINA FIJA'));
    await tester.pumpAndSettle();
    expect(find.text('0 perfiles activos'), findsOneWidget);
    expect(find.textContaining('comisiones'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rechaza porcentajes mayores de cien', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('REGLAS DE COMISIÓN'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar Mensual'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '120');
    await tester.tap(find.text('GUARDAR'));
    await tester.pump();

    expect(find.text('Ingrese un porcentaje entre 0 y 100.'), findsOneWidget);
    expect(find.text('Editar regla'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _harness() {
  final summary = AccountingSummaryModel(
    pendingTrainerAmount: 300,
    pendingTrainerCount: 2,
    overdueTrainerCount: 1,
    paidTrainerCount: 5,
    activeRuleCount: 1,
    defaultRuleCount: 1,
    individualRuleCount: 0,
    fixedPayrollProfiles: 0,
    fixedPayrollPending: 0,
  );
  final installments = [
    TrainerCommissionInstallmentModel(
      id: 'i1',
      trainerId: 't1',
      trainerName: 'Ana Coach',
      currencyCode: 'USD',
      amount: 100,
      status: 'PENDIENTE',
      scheduledDate: DateTime.utc(2026, 7, 10),
      periodStart: DateTime.utc(2026, 7, 1),
      periodEnd: DateTime.utc(2026, 7, 15),
    ),
    TrainerCommissionInstallmentModel(
      id: 'i2',
      trainerId: 't2',
      trainerName: 'Luis Coach',
      currencyCode: 'PYG',
      amount: 200,
      status: 'PENDIENTE',
      scheduledDate: DateTime.utc(2026, 7, 12),
      periodStart: DateTime.utc(2026, 7, 1),
      periodEnd: DateTime.utc(2026, 7, 15),
    ),
  ];
  final rules = [
    TrainerCommissionRuleModel(
      id: 'r1',
      trainerId: null,
      planId: 'p1',
      type: 'PERCENTAGE',
      value: 10,
      active: true,
      startDate: DateTime.utc(2026, 1, 1),
      endDate: null,
      planName: 'Mensual',
      trainerName: 'Regla general del plan',
    ),
  ];
  final plans = [
    PaymentPlanModel(
      id: 'p1',
      nombre: 'Mensual',
      importe: 50,
      duracion: 30,
      monedaId: 'USD',
    ),
  ];
  final trainers = [
    TrainerModel(
      id: 't1',
      ci: 'T1',
      nombres: 'Ana',
      apellidos: 'Coach',
      activo: true,
      fechaInicio: DateTime.utc(2025),
    ),
  ];

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
      trainerCommissionInstallmentsProvider.overrideWith(
        (ref) async => installments,
      ),
      trainerCommissionRulesProvider.overrideWith((ref) async => rules),
      paymentPlanProvider.overrideWith(() => _PlanNotifier(plans)),
      trainerProvider.overrideWith(() => _TrainerNotifier(trainers)),
    ],
    child: const MaterialApp(home: Scaffold(body: AccountingView())),
  );
}

class _PlanNotifier extends PaymentPlanNotifier {
  _PlanNotifier(this.items);
  final List<PaymentPlanModel> items;

  @override
  Future<List<PaymentPlanModel>> build() async => items;
}

class _TrainerNotifier extends TrainerNotifier {
  _TrainerNotifier(this.items);
  final List<TrainerModel> items;

  @override
  Future<List<TrainerModel>> build() async => items;
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
