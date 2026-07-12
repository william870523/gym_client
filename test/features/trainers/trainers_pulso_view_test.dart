import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';
import 'package:gym_client/src/features/clients/presentation/state/client_notifier.dart';
import 'package:gym_client/src/features/trainers/data/models/trainer_model.dart';
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

Widget _harness({_TrainerNotifier? trainerNotifier}) {
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

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
