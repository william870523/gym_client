import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/features/auth/domain/models/user.dart';
import 'package:gym_client/src/features/auth/presentation/state/auth_notifier.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';
import 'package:gym_client/src/features/clients/data/models/client_record_model.dart';
import 'package:gym_client/src/features/clients/data/repositories/client_repository.dart';
import 'package:gym_client/src/features/clients/presentation/state/client_record_provider.dart';
import 'package:gym_client/src/features/clients/presentation/widgets/client_record_dialog.dart';

void main() {
  const sizes = <String, Size>{
    'compacto': Size(390, 844),
    'mediano': Size(760, 900),
    'escritorio': Size(1280, 900),
    'ventana baja': Size(1024, 650),
  };

  for (final entry in sizes.entries) {
    testWidgets('expediente PULSO se adapta al ancho ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('client-record-dialog')),
        findsOneWidget,
      );
      expect(find.text('PULSO · EXPEDIENTE DEL SOCIO'), findsOneWidget);
      expect(find.text('ANA PÉREZ'), findsOneWidget);
      expect(find.text('Mensual'), findsOneWidget);
      expect(
        find.text('Coach Uno · 12/07/2026 → actual · ACTIVA'),
        findsOneWidget,
      );
      expect(find.textContaining('REANUDADA · 01/07/2026'), findsOneWidget);
      expect(find.text(r'$50.00'), findsOneWidget);
      expect(find.textContaining('ANULADO'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('filtra membresías y abre el recibo con su desglose', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('Trimestral anterior'), findsOneWidget);
    final statusFilter = find.byKey(const ValueKey('record-status-all'));
    await tester.ensureVisible(statusFilter);
    await tester.tap(statusFilter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ACTIVA').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('record-filter-count')), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Trimestral anterior'), findsNothing);

    final payment = find.byKey(const ValueKey('record-payment-payment-1'));
    await tester.ensureVisible(payment);
    await tester.tap(payment);
    await tester.pumpAndSettle();

    expect(find.text('PAGO CONFIRMADO'), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.text('Caja USD · misma moneda · tasa 1:1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('abre las opciones de PDF, impresión y CSV', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('EXPORTAR'));
    await tester.pumpAndSettle();

    expect(find.text('EXPORTAR / IMPRIMIR'), findsOneWidget);
    expect(find.text('GUARDAR PDF'), findsOneWidget);
    expect(find.text('IMPRIMIR'), findsOneWidget);
    expect(find.text('GUARDAR CSV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('administración registra el motivo de una pausa', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeClientRepository();

    await tester.pumpWidget(_harness(admin: true, repository: repository));
    await tester.pumpAndSettle();

    final action = find.byKey(const ValueKey('membership-action-membership-1'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('membership-pause-reason')),
      'Viaje de trabajo',
    );
    await tester.tap(find.text('CONFIRMAR PAUSA'));
    await tester.pumpAndSettle();

    expect(repository.pausedMembershipId, 'membership-1');
    expect(repository.pauseReason, 'Viaje de trabajo');
    expect(tester.takeException(), isNull);
  });

  testWidgets('recepción solicita pausa sin cambiar la vigencia directamente', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeClientRepository();

    await tester.pumpWidget(_harness(reception: true, repository: repository));
    await tester.pumpAndSettle();

    final action = find.byKey(const ValueKey('membership-action-membership-1'));
    await tester.ensureVisible(action);
    expect(find.text('SOLICITAR PAUSA'), findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('membership-request-reason')),
      'Viaje de trabajo',
    );
    await tester.pump();
    final send = find.text('ENVIAR SOLICITUD');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(repository.requestedMembershipId, 'membership-1');
    expect(repository.requestedKind, 'PAUSAR');
    expect(repository.requestReason, 'Viaje de trabajo');
    expect(repository.pausedMembershipId, isNull);
    expect(tester.takeException(), isNull);
  });

  /// Regla PULSO: la tabla scrollea, no la vista. Los filtros son el mando del
  /// expediente; dentro del scroll, con un historial largo había que subir
  /// hasta arriba solo para cambiar uno.
  testWidgets('en escritorio los filtros no se van con el scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final filtros = find.text('EXPLORAR HISTORIAL');
    expect(filtros, findsOneWidget);
    final antes = tester.getTopLeft(filtros);

    // Se desplaza el historial hacia arriba.
    await tester.drag(
      find.text('HISTORIAL DE MEMBRESÍAS'),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    // La barra sigue visible y en el mismo sitio: no viajó con el scroll.
    expect(filtros, findsOneWidget);
    expect(tester.getTopLeft(filtros), antes);
    expect(tester.takeException(), isNull);
  });

  testWidgets('en compacto los filtros siguen accesibles dentro del scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // No se fijan (no cabrían), pero existen una sola vez: sin duplicados.
    expect(find.text('EXPLORAR HISTORIAL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _harness({
  bool admin = false,
  bool reception = false,
  ClientRepository? repository,
}) => ProviderScope(
  overrides: [
    appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
    clientRecordProvider('100').overrideWith((ref) async => _record()),
    if (admin) authProvider.overrideWith(_AdminAuthNotifier.new),
    if (reception) authProvider.overrideWith(_ReceptionAuthNotifier.new),
    if (repository != null)
      clientRepositoryProvider.overrideWithValue(repository),
  ],
  child: const MaterialApp(
    home: Scaffold(body: ClientRecordDialog(clientId: '100')),
  ),
);

ClientRecordModel _record() => ClientRecordModel(
  client: const ClientRecordIdentity(
    id: '100',
    firstName: 'Ana',
    lastName: 'Pérez',
  ),
  memberships: [
    ClientMembershipRecord(
      id: 'membership-1',
      planId: 'plan-1',
      planName: 'Mensual',
      price: 50,
      currencyId: 'usd',
      currencyCode: 'USD',
      currencySymbol: r'$',
      durationDays: 30,
      startDate: DateTime.utc(2026, 7, 12),
      endDate: DateTime.utc(2026, 8, 11),
      status: 'ACTIVA',
      origin: 'ALTA',
      paidAmount: 50,
      activatedAt: DateTime.utc(2026, 7, 12, 20),
      reconstructed: false,
      pauses: [
        ClientMembershipPause(
          id: 'pause-1',
          pauseDate: DateTime.utc(2026, 7, 1),
          resumeDate: DateTime.utc(2026, 7, 5),
          previousEndDate: DateTime.utc(2026, 8, 7),
          recalculatedEndDate: DateTime.utc(2026, 8, 11),
          remainingDays: 33,
          reason: 'Viaje familiar',
          status: 'REANUDADA',
          pausedAt: DateTime.utc(2026, 7, 1, 16),
          resumedAt: DateTime.utc(2026, 7, 5, 16),
        ),
      ],
      trainers: [
        ClientTrainerAssignment(
          id: 'assignment-1',
          trainerId: 'trainer-1',
          trainerName: 'Coach Uno',
          startDate: DateTime.utc(2026, 7, 12),
          status: 'ACTIVA',
        ),
      ],
      payments: [
        ClientRecordPayment(
          id: 'payment-1',
          date: DateTime.utc(2026, 7, 12, 20),
          total: 50,
          currencyId: 'usd',
          currencyCode: 'USD',
          currencySymbol: r'$',
          planId: 'plan-1',
          applicationId: 'application-1',
          appliedAmount: 50,
          details: const [
            ClientRecordPaymentDetail(
              id: 'detail-1',
              paymentTypeId: 'cash',
              paymentTypeName: 'Efectivo',
              accountId: 'cash-usd',
              accountName: 'Caja USD',
              currencyId: 'usd',
              currencyCode: 'USD',
              currencySymbol: r'$',
              amount: 50,
            ),
          ],
        ),
      ],
    ),
    ClientMembershipRecord(
      id: 'membership-2',
      planId: 'plan-2',
      planName: 'Trimestral anterior',
      price: 120,
      currencyId: 'usd',
      currencyCode: 'USD',
      currencySymbol: r'$',
      durationDays: 90,
      startDate: DateTime.utc(2025, 10, 1),
      endDate: DateTime.utc(2025, 12, 30),
      status: 'VENCIDA',
      origin: 'ALTA',
      paidAmount: 120,
      reconstructed: false,
      trainers: const [],
      payments: const [],
    ),
  ],
  unlinkedPayments: [
    ClientRecordPayment(
      id: 'payment-void',
      date: DateTime.utc(2026, 7, 12, 20, 30),
      total: 25,
      currencyId: 'usd',
      currencyCode: 'USD',
      currencySymbol: r'$',
      planId: 'plan-1',
      isVoided: true,
      voidedAt: DateTime.utc(2026, 7, 12, 20, 31),
    ),
  ],
  totalsByCurrency: const [
    ClientCurrencyTotal(
      currencyId: 'usd',
      currencyName: 'Dólar estadounidense',
      code: 'USD',
      symbol: r'$',
      amount: 50,
      paymentCount: 1,
    ),
  ],
);

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}

class _AdminAuthNotifier extends AuthNotifier {
  @override
  FutureOr<User?> build() => const User(
    id: 'admin-1',
    name: 'Administración',
    email: 'admin@gym.test',
    role: 'admin',
  );
}

class _ReceptionAuthNotifier extends AuthNotifier {
  @override
  FutureOr<User?> build() => const User(
    id: 'reception-1',
    name: 'Recepción',
    email: 'recepcion@gym.test',
    role: 'recepcionista',
  );
}

class _FakeClientRepository extends ClientRepository {
  _FakeClientRepository() : super(Dio());

  String? pausedMembershipId;
  String? pauseReason;
  String? requestedMembershipId;
  String? requestedKind;
  String? requestReason;

  @override
  Future<List<ClientModel>> getClients({int page = 1, int limit = 10}) async =>
      const [];

  @override
  Future<void> pauseMembership({
    required String clientId,
    required String membershipId,
    required String reason,
  }) async {
    pausedMembershipId = membershipId;
    pauseReason = reason;
  }

  @override
  Future<void> requestMembershipAction({
    required String clientId,
    required String membershipId,
    required String kind,
    required String reason,
  }) async {
    requestedMembershipId = membershipId;
    requestedKind = kind;
    requestReason = reason;
  }
}
