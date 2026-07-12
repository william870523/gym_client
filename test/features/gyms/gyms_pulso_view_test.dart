import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/gyms/domain/models/gym.dart';
import 'package:gym_client/src/features/gyms/presentation/gyms_provider.dart';
import 'package:gym_client/src/features/gyms/presentation/screens/gyms_pulso_view.dart';

void main() {
  const sizes = <String, Size>{
    'compacto': Size(390, 844),
    'mediano': Size(760, 900),
    'escritorio': Size(1280, 900),
    'ventana baja': Size(1024, 650),
  };

  for (final entry in sizes.entries) {
    testWidgets('Gimnasios PULSO se adapta al ancho ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('GIMNASIOS.', findRichText: true), findsOneWidget);
      expect(find.text('Central'), findsOneWidget);
      expect(find.text('Norte'), findsOneWidget);
      expect(find.text('MODO LOCAL'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final row = find.descendant(
        of: find.byKey(const PageStorageKey('pulso-gyms-list')),
        matching: find.text('Central'),
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

  testWidgets('advierte una zona horaria neutral de arranque', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Norte'));
    await tester.pump();

    expect(find.text('Etc/UTC'), findsWidgets);
    expect(
      find.text(
        'Etc/UTC es un valor neutral de arranque; configure la zona real de la sede.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite editar una sede y conserva su zona IANA', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _GymsController();
    await tester.pumpWidget(_harness(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar Central'));
    await tester.pumpAndSettle();
    expect(find.text('EDITAR GIMNASIO'), findsOneWidget);
    expect(find.text('GIMNASIOS.', findRichText: true), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('pulso-gym-name')),
      'Central Renovado',
    );
    await tester.tap(find.text('GUARDAR CAMBIOS'));
    await tester.pumpAndSettle();

    expect(controller.updates, hasLength(1));
    final updated = controller.updates.single;
    expect(updated.id, 'gym-central');
    expect(updated.code, 'CTR');
    expect(updated.name, 'Central Renovado');
    expect(updated.timezone, 'America/Los_Angeles');
    expect(find.text('EDITAR GIMNASIO'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtra las sedes inactivas', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inactivas'));
    await tester.pump();
    final list = find.byKey(const PageStorageKey('pulso-gyms-list'));
    expect(
      find.descendant(of: list, matching: find.text('Norte')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: list, matching: find.text('Central')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

List<Gym> _gyms() => [
  Gym(
    id: 'gym-central',
    code: 'CTR',
    name: 'Central',
    address: '100 Main St',
    city: 'Los Angeles',
    state: 'California',
    country: 'US',
    timezone: 'America/Los_Angeles',
    zipCode: '90001',
  ),
  Gym(
    id: 'gym-norte',
    code: 'NTE',
    name: 'Norte',
    address: '20 North Ave',
    city: 'Madrid',
    state: 'Madrid',
    country: 'ES',
    timezone: 'Etc/UTC',
    zipCode: '28001',
    active: false,
  ),
];

Widget _harness({_GymsController? controller}) {
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
      gymsListProvider.overrideWith((ref) async => _gyms()),
      gymsControllerProvider.overrideWith(
        () => controller ?? _GymsController(),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: GymsPulsoView())),
  );
}

class _GymsController extends GymsController {
  final updates = <Gym>[];
  final creates = <Gym>[];

  @override
  FutureOr<void> build() => null;

  @override
  Future<void> updateGym(Gym gym) async {
    updates.add(gym);
  }

  @override
  Future<void> createGym(Gym gym) async {
    creates.add(gym);
  }
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
