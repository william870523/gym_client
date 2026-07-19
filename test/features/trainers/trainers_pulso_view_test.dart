import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';
import 'package:gym_client/src/features/clients/presentation/state/client_notifier.dart';
import 'package:gym_client/src/features/trainers/data/models/trainer_model.dart';
import 'package:gym_client/src/features/trainers/data/models/trainer_offboarding_case.dart';
import 'package:gym_client/src/features/trainers/data/models/trainer_offboarding_impact.dart';
import 'package:gym_client/src/features/trainers/data/models/trainer_final_settlement.dart';
import 'package:gym_client/src/features/trainers/data/repositories/trainer_repository.dart';
import 'package:gym_client/src/features/trainers/presentation/providers/trainer_notifier.dart';
import 'package:gym_client/src/features/trainers/presentation/screens/trainers_pulso_view.dart';

void main() {
  const sizes = <String, Size>{
    'compacto': Size(390, 844),
    'mediano': Size(760, 900),
    'escritorio': Size(1280, 900),
    'ventana baja': Size(1024, 650),
  };

  for (final entry in sizes.entries) {
    testWidgets('Entrenadores PULSO se adapta al ancho ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('ENTRENADORES.', findRichText: true), findsOneWidget);
      // El nombre con mayor carga puede repetirse en la banda de métricas.
      expect(find.text('Ana Pérez'), findsWidgets);
      expect(find.text('Luis Gómez'), findsOneWidget);
      expect(find.text('MODO LOCAL'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final row = find.descendant(
        of: find.byKey(const PageStorageKey('pulso-trainers-list')),
        matching: find.text('Ana Pérez'),
      );
      if (entry.key == 'mediano') {
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.text('DETALLE SELECCIONADO'), findsOneWidget);
      }
      if (entry.key == 'escritorio') {
        await tester.tap(row);
        await tester.pump();
        expect(find.text('DETALLE SELECCIONADO'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cuenta socios asignados por entrenador', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // Solo socios ACTIVOS cuentan: 2 con Ana, ninguno con Luis.
    expect(find.text('2 socios'), findsOneWidget);
    expect(find.text('sin socios'), findsOneWidget);
    expect(find.text('Mayor carga'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite editar un entrenador y guarda los cambios', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final trainerNotifier = _TrainerNotifier(_trainers());
    await tester.pumpWidget(_harness(trainerNotifier: trainerNotifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar Ana Pérez'));
    await tester.pumpAndSettle();
    // Formulario PULSO en diálogo: el shell sigue visible detrás.
    expect(find.text('EDITAR ENTRENADOR'), findsOneWidget);
    expect(find.text('ENTRENADORES.', findRichText: true), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('pulso-trainer-nombres')),
      'Ana María',
    );
    await tester.tap(find.text('GUARDAR CAMBIOS'));
    await tester.pumpAndSettle();

    expect(trainerNotifier.updates, hasLength(1));
    final (id, payload) = trainerNotifier.updates.single;
    expect(id, 'tr-ana');
    expect(payload['nombres_entrenador'], 'Ana María');
    expect(payload['ci_entrenador'], '111');
    expect(payload['activo_entrenador'], true);
    expect(find.text('EDITAR ENTRENADOR'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtra entrenadores inactivos', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inactivos').last);
    await tester.pump();
    final list = find.byKey(const PageStorageKey('pulso-trainers-list'));
    expect(
      find.descendant(of: list, matching: find.text('Luis Gómez')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: list, matching: find.text('Ana Pérez')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('la baja muestra impacto y protege el registro', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Preparar baja de Ana Pérez'));
    await tester.pumpAndSettle();

    expect(find.text('Preparar baja de entrenador'), findsOneWidget);
    expect(find.textContaining('La baja no se ejecutó'), findsOneWidget);
    expect(find.text('Rosa Socia'), findsOneWidget);
    expect(find.text('CUP'), findsOneWidget);
    expect(find.text('REASIGNAR'), findsOneWidget);
    expect(
      find.byKey(const Key('offboarding-impact-table-scrollbar')),
      findsOneWidget,
    );
    expect(find.text('ABRIR EXPEDIENTE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el expediente conserva su cabecera y desplaza solo la tabla', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Preparar baja de Ana Pérez'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ABRIR EXPEDIENTE'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Motivo administrativo'),
      'Terminación de contrato demostrativa',
    );
    await tester.tap(find.text('CREAR EXPEDIENTE'));
    await tester.pumpAndSettle();

    expect(find.text('Expediente y decisiones por membresía'), findsOneWidget);
    final table = find.byKey(const Key('offboarding-case-table-scrollbar'));
    expect(table, findsOneWidget);
    await tester.drag(table, const Offset(0, -360));
    await tester.pump();
    expect(find.text('Expediente y decisiones por membresía'), findsOneWidget);
    expect(find.text('Fecha efectiva'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el asistente de baja también cabe en una ventana compacta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(540, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preparar baja'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('offboarding-impact-table-scrollbar')),
      findsOneWidget,
    );
    await tester.tap(find.text('ABRIR EXPEDIENTE'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Motivo administrativo'),
      'Terminación demostrativa en ventana compacta',
    );
    await tester.tap(find.text('CREAR EXPEDIENTE'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('offboarding-case-table-scrollbar')),
      findsOneWidget,
    );
    expect(find.text('Expediente y decisiones por membresía'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'aplica la reasignación conservando la cabecera y el scroll de la tabla',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _TrainerRepository(openCase: _readyCase());
      await tester.pumpWidget(_harness(repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Preparar baja de Ana Pérez'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ABRIR EXPEDIENTE'));
      await tester.pumpAndSettle();

      expect(find.text('APLICAR REASIGNACIONES'), findsOneWidget);
      expect(
        find.byKey(const Key('offboarding-case-table-scrollbar')),
        findsOneWidget,
      );
      await tester.tap(find.text('APLICAR REASIGNACIONES'));
      await tester.pumpAndSettle();
      expect(find.textContaining('El plan, precio y vigencia'), findsOneWidget);
      await tester.tap(find.text('APLICAR AHORA'));
      await tester.pumpAndSettle();

      expect(repository.executions, 1);
      expect(find.text('REASIGNACIONES APLICADAS'), findsOneWidget);
      expect(
        find.byKey(const Key('offboarding-execution-summary')),
        findsOneWidget,
      );
      expect(find.textContaining('1 membresía'), findsOneWidget);
      expect(find.textContaining('Falta liquidar lo ganado'), findsOneWidget);
      expect(
        find.byKey(const Key('offboarding-case-table-scrollbar')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'la liquidación final separa monedas y desplaza solo sus filas',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _TrainerRepository(openCase: _readyCase());
      await tester.pumpWidget(_harness(repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Preparar baja de Ana Pérez'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ABRIR EXPEDIENTE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('APLICAR REASIGNACIONES'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('APLICAR AHORA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LIQUIDACIÓN FINAL'));
      await tester.pumpAndSettle();

      expect(find.text('Liquidación extraordinaria final'), findsOneWidget);
      expect(
        find.byKey(const Key('final-settlement-currency-scrollbar')),
        findsOneWidget,
      );
      expect(find.text('CUP'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('Cuenta de salida'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

List<TrainerModel> _trainers() => [
  TrainerModel(
    id: 'tr-ana',
    ci: '111',
    nombres: 'Ana',
    apellidos: 'Pérez',
    telefono: 70000001,
    correo: 'ana@gym.test',
    activo: true,
    fechaInicio: DateTime.utc(2025, 3, 1),
  ),
  TrainerModel(
    id: 'tr-luis',
    ci: '222',
    nombres: 'Luis',
    apellidos: 'Gómez',
    activo: false,
    fechaInicio: DateTime.utc(2024, 6, 15),
  ),
];

Widget _harness({
  _TrainerNotifier? trainerNotifier,
  _TrainerRepository? repository,
}) {
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
      trainerProvider.overrideWith(
        () => trainerNotifier ?? _TrainerNotifier(_trainers()),
      ),
      trainerRepositoryProvider.overrideWithValue(
        repository ?? _TrainerRepository(),
      ),
      clientNotifierProvider.overrideWith(
        () => _ClientNotifier([
          ClientModel(id: '100', nombres: 'Rosa', trainerId: 'tr-ana'),
          ClientModel(id: '200', nombres: 'Iván', trainerId: 'tr-ana'),
          ClientModel(
            id: '300',
            nombres: 'Eva',
            trainerId: 'tr-ana',
            activo: false,
          ),
          ClientModel(id: '400', nombres: 'Juan'),
        ]),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: TrainersPulsoView())),
  );
}

class _TrainerNotifier extends TrainerNotifier {
  _TrainerNotifier(this.items);
  final List<TrainerModel> items;
  final updates = <(String, Map<String, dynamic>)>[];

  @override
  Future<List<TrainerModel>> build() async => items;

  @override
  Future<void> updateTrainer(String id, Map<String, dynamic> data) async {
    updates.add((id, data));
  }
}

class _ClientNotifier extends ClientNotifier {
  _ClientNotifier(this.items);
  final List<ClientModel> items;

  @override
  Future<List<ClientModel>> build() async => items;
}

class _TrainerRepository extends TrainerRepository {
  _TrainerRepository({this.openCase}) : super(Dio());

  final TrainerOffboardingCase? openCase;
  int executions = 0;
  int finalPreviews = 0;

  @override
  Future<TrainerOffboardingImpact> getOffboardingImpact(String id) async {
    return TrainerOffboardingImpact(
      trainerName: 'Ana Pérez',
      trainerId: id,
      businessDate: '2026-07-14',
      memberships: [
        TrainerOffboardingMembershipImpact(
          membershipId: 'membership-1',
          assignmentId: 'assignment-1',
          clientId: '100',
          clientName: 'Rosa Socia',
          planName: 'Trimestral con entrenador',
          status: 'ACTIVA',
          startDate: DateTime.utc(2026, 7, 1),
          endDate: DateTime.utc(2026, 10, 1),
          assignmentOrigin: 'HISTORIAL',
          recommendation: 'REASIGNAR',
        ),
      ],
      finances: const [
        TrainerOffboardingFinanceImpact(
          currencyCode: 'CUP',
          earnedCommission: 250,
          paidCommission: 100,
          pendingCommission: 150,
          futureCommission: 500,
          earnedFixed: 180,
          paidFixed: 0,
          pendingFixed: 180,
        ),
      ],
      activeProfiles: 1,
      blockers: const ['MEMBRESIAS_SIN_RESOLVER', 'SALDO_GANADO_PENDIENTE'],
      canDeleteDirectly: false,
    );
  }

  @override
  Future<TrainerOffboardingCase?> getOpenOffboardingCase(
    String trainerId,
  ) async => openCase;

  @override
  Future<TrainerOffboardingCase> executeOffboardingCase({
    required String trainerId,
    required String caseId,
    required String operationId,
  }) async {
    executions++;
    final current = openCase ?? _readyCase();
    return TrainerOffboardingCase(
      id: current.id,
      trainerId: current.trainerId,
      effectiveDate: current.effectiveDate,
      status: 'EN_EJECUCION',
      reason: current.reason,
      totalDecisions: current.totalDecisions,
      pendingDecisions: 0,
      createdBy: current.createdBy,
      createdAt: current.createdAt,
      impact: current.impact,
      decisions: [
        for (final decision in current.decisions)
          TrainerOffboardingDecision(
            id: decision.id,
            membershipId: decision.membershipId,
            clientId: decision.clientId,
            clientName: decision.clientName,
            planName: decision.planName,
            membershipStatus: decision.membershipStatus,
            startDate: decision.startDate,
            endDate: decision.endDate,
            type: decision.type,
            targetTrainerId: decision.targetTrainerId,
            targetTrainerName: decision.targetTrainerName,
            reason: decision.reason,
            executionState: 'APLICADA',
          ),
      ],
      executionOperationId: operationId,
      executedBy: 'Administración',
      executedAt: DateTime.utc(2026, 7, 14, 21),
      executionSummary: const {
        'membresias_aplicadas': 1,
        'asignaciones_creadas': 1,
        'cuotas_transferidas': 1,
        'cuotas_anuladas': 0,
      },
    );
  }

  @override
  Future<TrainerFinalSettlementPreview> previewFinalSettlement({
    required String trainerId,
    required String caseId,
  }) async {
    finalPreviews++;
    return TrainerFinalSettlementPreview(
      caseId: caseId,
      trainerId: trainerId,
      trainerName: 'Ana Pérez',
      effectiveDate: DateTime.utc(2026, 7, 14),
      status: 'EN_EJECUCION',
      currencies: [
        TrainerFinalSettlementCurrency(
          currencyId: 'cup',
          currencyCode: 'CUP',
          commissionTotal: 150,
          fixedTotal: 180,
          total: 330,
          concepts: 2,
          items: [
            TrainerFinalSettlementConcept(
              id: 'cuota-cup',
              type: 'COMISION',
              startDate: DateTime.utc(2026, 7, 1),
              endDate: DateTime.utc(2026, 7, 14),
              scheduledDate: DateTime.utc(2026, 8, 1),
              balance: 150,
            ),
          ],
        ),
        TrainerFinalSettlementCurrency(
          currencyId: 'usd',
          currencyCode: 'USD',
          commissionTotal: 20,
          fixedTotal: 0,
          total: 20,
          concepts: 1,
          items: const [],
        ),
      ],
      accounts: const [
        TrainerFinalSettlementAccount(
          id: 'account-cup',
          name: 'Caja CUP',
          currencyId: 'cup',
          currencyCode: 'CUP',
          paymentTypeId: 'cash',
        ),
        TrainerFinalSettlementAccount(
          id: 'account-usd',
          name: 'Caja USD',
          currencyId: 'usd',
          currencyCode: 'USD',
          paymentTypeId: 'cash',
        ),
      ],
      paymentTypes: const [
        TrainerFinalSettlementPaymentType(
          id: 'cash',
          name: 'Efectivo',
          code: 'EFECTIVO',
        ),
      ],
      history: const [],
    );
  }

  @override
  Future<TrainerOffboardingCase> createOffboardingCase({
    required String trainerId,
    required String effectiveDate,
    required String reason,
  }) async => _case(trainerId, reason);

  TrainerOffboardingCase _case(String trainerId, String reason) {
    final impact = TrainerOffboardingImpact(
      trainerName: 'Ana Pérez',
      trainerId: trainerId,
      businessDate: '2026-07-14',
      memberships: const [],
      finances: const [],
      activeProfiles: 1,
      blockers: const ['MEMBRESIAS_SIN_RESOLVER'],
      canDeleteDirectly: false,
    );
    return TrainerOffboardingCase(
      id: 'case-1',
      trainerId: trainerId,
      effectiveDate: DateTime.utc(2026, 7, 14),
      status: 'BORRADOR',
      reason: reason,
      totalDecisions: 12,
      pendingDecisions: 12,
      createdBy: 'Administración',
      createdAt: DateTime.utc(2026, 7, 14, 20),
      impact: impact,
      decisions: List.generate(
        12,
        (index) => TrainerOffboardingDecision(
          id: 'decision-$index',
          membershipId: 'membership-$index',
          clientId: '10$index',
          clientName: 'Socio demostrativo ${index + 1}',
          planName: 'Plan con entrenador',
          membershipStatus: 'ACTIVA',
          startDate: DateTime.utc(2026, 7, 1),
          endDate: DateTime.utc(2026, 10, 1),
          type: 'PENDIENTE',
          targetTrainerId: null,
          targetTrainerName: null,
          reason: null,
        ),
      ),
    );
  }
}

TrainerOffboardingCase _readyCase() {
  final impact = TrainerOffboardingImpact(
    trainerName: 'Ana Pérez',
    trainerId: 'tr-ana',
    businessDate: '2026-07-14',
    memberships: const [],
    finances: const [],
    activeProfiles: 1,
    blockers: const ['SALDO_GANADO_PENDIENTE'],
    canDeleteDirectly: false,
  );
  return TrainerOffboardingCase(
    id: 'case-ready',
    trainerId: 'tr-ana',
    effectiveDate: DateTime.utc(2026, 7, 14),
    status: 'LISTO_PARA_REVISION',
    reason: 'Terminación demostrativa',
    totalDecisions: 1,
    pendingDecisions: 0,
    createdBy: 'Administración',
    createdAt: DateTime.utc(2026, 7, 14, 20),
    impact: impact,
    decisions: [
      TrainerOffboardingDecision(
        id: 'decision-ready',
        membershipId: 'membership-ready',
        clientId: '100',
        clientName: 'Rosa Socia',
        planName: 'Trimestral con entrenador',
        membershipStatus: 'ACTIVA',
        startDate: DateTime.utc(2026, 7, 1),
        endDate: DateTime.utc(2026, 10, 1),
        type: 'REASIGNAR',
        targetTrainerId: 'tr-destino',
        targetTrainerName: 'Leo Destino',
        reason: 'Continuidad del servicio',
      ),
    ],
  );
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
