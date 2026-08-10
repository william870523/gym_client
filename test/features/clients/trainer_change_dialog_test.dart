import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/features/auth/domain/models/user.dart';
import 'package:gym_client/src/features/auth/presentation/state/auth_notifier.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';
import 'package:gym_client/src/features/clients/data/models/client_record_model.dart';
import 'package:gym_client/src/features/clients/data/repositories/client_repository.dart';
import 'package:gym_client/src/features/clients/presentation/state/client_record_provider.dart';
import 'package:gym_client/src/features/clients/presentation/widgets/client_record_dialog.dart';
import 'package:gym_client/src/features/trainers/data/models/trainer_model.dart';
import 'package:gym_client/src/features/trainers/presentation/providers/trainer_notifier.dart';

/// R5.4 · Unidad 08 — diálogo de cambio de entrenador.
///
/// Lo que fija esta prueba:
///
///  - **el entrenador actual se ve**: sin eso el operador elige a ciegas;
///  - **el efecto financiero se pide al servidor y se presenta**, nunca se
///    calcula aquí. La prueba comprueba que las cifras que aparecen son
///    exactamente las que devolvió el repositorio;
///  - **cabe en 360, 768 y 1280 px**. El ancho estaba fijado a 420 y en
///    compacto se desbordaba.
void main() {
  for (final entry in const {
    'compacto': Size(360, 780),
    'mediano': Size(768, 900),
    'escritorio': Size(1280, 900),
  }.entries) {
    testWidgets('el diálogo de cambio de entrenador cabe en ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _FakeClientRepository();

      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      final accion = find.byKey(
        const ValueKey('membership-change-trainer-membership-1'),
      );
      await tester.ensureVisible(accion);
      await tester.tap(accion);
      await tester.pumpAndSettle();

      // El entrenador actual, visible antes de elegir nada.
      expect(find.byKey(const ValueKey('change-trainer-current')), findsOneWidget);
      expect(find.textContaining('Coach Uno'), findsWidgets);
      // Todavía no hay destino: no hay cifras que enseñar.
      expect(
        find.byKey(const ValueKey('change-trainer-preview-empty')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('la previsualización enseña el reparto que devuelve el servidor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeClientRepository();

    await tester.pumpWidget(_harness(repository));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('membership-change-trainer-membership-1')),
    );
    await tester.pumpAndSettle();

    // Marcar «sin entrenador» ya es un destino válido y dispara el cálculo.
    await tester.tap(find.byKey(const ValueKey('change-trainer-none')));
    await tester.pumpAndSettle();

    expect(repository.previewCalls, 1);
    expect(repository.lastPreviewTrainerId, isNull);
    expect(find.byKey(const ValueKey('change-trainer-preview')), findsOneWidget);
    // Las cifras son las del servidor, tal cual: aquí no se suma nada.
    expect(find.text('583.33'), findsOneWidget);
    // Aparece dos veces a propósito: sin entrenador destino, el tramo futuro
    // ES el crédito que se libera al socio. Son la misma cifra con dos
    // lecturas distintas, y el diálogo enseña las dos.
    expect(find.text('116.67'), findsNWidgets(2));
    expect(find.textContaining('Crédito liberado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un rechazo del servidor se enseña y no se inventa un reparto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeClientRepository()..failPreview = true;

    await tester.pumpWidget(_harness(repository));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('membership-change-trainer-membership-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('change-trainer-none')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('change-trainer-preview-error')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('change-trainer-preview')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el motivo sigue alcanzable tras elegir entrenador destino', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(_FakeClientRepository()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('membership-change-trainer-membership-1')),
    );
    await tester.pumpAndSettle();

    // Elegir un entrenador destino del desplegable.
    await tester.tap(find.byKey(const ValueKey('change-trainer-target')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coach Dos').last);
    await tester.pumpAndSettle();

    // El motivo tiene que seguir ahí Y poder escribirse sin buscarlo.
    final motivo = find.byKey(const ValueKey('change-trainer-reason'));
    expect(motivo, findsOneWidget);
    await tester.enterText(motivo, 'El socio lo pidió');
    await tester.pump();
    expect(find.text('El socio lo pidió'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _harness(ClientRepository repository) => ProviderScope(
  overrides: [
    appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
    clientRecordProvider('100').overrideWith((ref) async => _record()),
    authProvider.overrideWith(_AdminAuthNotifier.new),
    clientRepositoryProvider.overrideWithValue(repository),
    // Catálogo cortado: sin esto la prueba saldría a la API real.
    trainerProvider.overrideWith(_FakeTrainerNotifier.new),
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
      planName: 'Trimestral',
      price: 300,
      currencyId: 'cup',
      currencyCode: 'CUP',
      currencySymbol: r'$',
      durationDays: 90,
      startDate: DateTime.utc(2026, 7, 1),
      endDate: DateTime.utc(2026, 9, 29),
      status: 'ACTIVA',
      origin: 'ALTA',
      paidAmount: 300,
      activatedAt: DateTime.utc(2026, 7, 1),
      reconstructed: false,
      pauses: const [],
      trainers: [
        ClientTrainerAssignment(
          id: 'assignment-1',
          trainerId: 'trainer-1',
          trainerName: 'Coach Uno',
          startDate: DateTime.utc(2026, 7, 1),
          status: 'ACTIVA',
        ),
      ],
      payments: const [],
    ),
  ],
  unlinkedPayments: const [],
  totalsByCurrency: const [],
);

class _FakeClientRepository extends ClientRepository {
  _FakeClientRepository() : super(Dio());

  int previewCalls = 0;
  String? lastPreviewTrainerId;
  bool failPreview = false;

  @override
  Future<List<ClientModel>> getClients({int page = 1, int limit = 10}) async =>
      const [];

  @override
  Future<Map<String, dynamic>> previewMembershipTrainerChange({
    required String membershipId,
    String? newTrainerId,
  }) async {
    previewCalls += 1;
    lastPreviewTrainerId = newTrainerId;
    if (failPreview) {
      throw Exception(
        'Existe una cuota futura pagada o parcial del entrenador saliente.',
      );
    }
    return {
      'membresia_id': membershipId,
      'fecha_efectiva': '2026-08-01',
      'entrenador_anterior': 'Coach Uno',
      'entrenador_nuevo': null,
      'sin_entrenador': true,
      'tramo_ganado': '583.33',
      'tramo_futuro': '116.67',
      'cuotas_transferibles': 0,
      'cuotas_anulables': 1,
      'credito_liberado': '116.67',
    };
  }
}

class _FakeTrainerNotifier extends TrainerNotifier {
  @override
  Future<List<TrainerModel>> build() async => [
    TrainerModel(
      id: 'trainer-2',
      ci: 'ENT-2',
      nombres: 'Coach',
      apellidos: 'Dos',
      activo: true,
      fechaInicio: DateTime.utc(2025, 1, 1),
    ),
  ];
}

class _AdminAuthNotifier extends AuthNotifier {
  @override
  Future<User?> build() async => const User(
    id: 'admin-1',
    name: 'Administración',
    email: 'admin@gym.test',
    role: 'admin',
  );
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
