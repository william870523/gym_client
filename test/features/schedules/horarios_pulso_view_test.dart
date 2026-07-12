import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';
import 'package:gym_client/src/features/clients/presentation/state/client_notifier.dart';
import 'package:gym_client/src/features/schedules/data/models/horario_model.dart';
import 'package:gym_client/src/features/schedules/presentation/screens/horarios_pulso_view.dart';
import 'package:gym_client/src/features/schedules/presentation/state/horario_notifier.dart';

void main() {
  const sizes = <String, Size>{
    'compacto': Size(390, 844),
    'mediano': Size(760, 900),
    'escritorio': Size(1280, 900),
    'ventana baja': Size(1024, 650),
  };

  for (final entry in sizes.entries) {
    testWidgets('Horarios PULSO se adapta al ancho ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('HORARIOS.', findRichText: true), findsOneWidget);
      // El nombre de la franja pico puede repetirse en la banda de métricas.
      expect(find.text('Mañana'), findsWidgets);
      expect(find.text('Tarde'), findsOneWidget);
      expect(find.text('MODO LOCAL'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final row = find.descendant(
        of: find.byKey(const PageStorageKey('pulso-horarios-list')),
        matching: find.text('Mañana'),
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

  testWidgets('cuenta socios por franja y marca solapamientos', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // Solo socios ACTIVOS: 2 en Mañana; Tarde queda vacía y en advertencia.
    expect(find.text('2 socios'), findsOneWidget);
    expect(find.text('sin socios'), findsOneWidget);
    expect(find.text('Franja pico'), findsOneWidget);
    // Mañana (06:00–09:00) y Tarde (08:00–11:00) se solapan: dos indicadores.
    expect(find.byTooltip('Se solapa con otra franja'), findsNWidgets(2));

    await tester.tap(
      find.descendant(
        of: find.byKey(const PageStorageKey('pulso-horarios-list')),
        matching: find.text('Mañana'),
      ),
    );
    await tester.pump();
    expect(find.text('SOLAPA CON'), findsOneWidget);
    // El detalle lista a Tarde como franja solapada (además de su fila).
    expect(find.text('Tarde'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite editar un horario y guarda los cambios', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final horarioNotifier = _HorarioNotifier(_horarios());
    await tester.pumpWidget(_harness(horarioNotifier: horarioNotifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar Mañana'));
    await tester.pumpAndSettle();
    expect(find.text('EDITAR HORARIO'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('pulso-horario-name')),
      'Mañana temprano',
    );
    await tester.tap(find.text('GUARDAR CAMBIOS'));
    await tester.pumpAndSettle();

    expect(horarioNotifier.updates, hasLength(1));
    final updated = horarioNotifier.updates.single;
    expect(updated.id, 'h-manana');
    expect(updated.nombre, 'Mañana temprano');
    expect(updated.horaInicio, 360);
    expect(updated.horaFin, 540);
    expect(find.text('EDITAR HORARIO'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtra franjas vacías', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vacías').last);
    await tester.pump();
    final list = find.byKey(const PageStorageKey('pulso-horarios-list'));
    expect(
      find.descendant(of: list, matching: find.text('Tarde')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: list, matching: find.text('Mañana')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

List<HorarioModel> _horarios() => [
  HorarioModel(id: 'h-manana', nombre: 'Mañana', horaInicio: 360, horaFin: 540),
  HorarioModel(id: 'h-tarde', nombre: 'Tarde', horaInicio: 480, horaFin: 660),
];

Widget _harness({_HorarioNotifier? horarioNotifier}) {
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
      horarioNotifierProvider.overrideWith(
        () => horarioNotifier ?? _HorarioNotifier(_horarios()),
      ),
      clientNotifierProvider.overrideWith(
        () => _ClientNotifier([
          ClientModel(id: '100', nombres: 'Ana', scheduleId: 'h-manana'),
          ClientModel(id: '200', nombres: 'Luis', scheduleId: 'h-manana'),
          ClientModel(
            id: '300',
            nombres: 'Eva',
            scheduleId: 'h-manana',
            activo: false,
          ),
          ClientModel(id: '400', nombres: 'Juan'),
        ]),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: HorariosPulsoView())),
  );
}

class _HorarioNotifier extends HorarioNotifier {
  _HorarioNotifier(this.items);
  final List<HorarioModel> items;
  final updates = <HorarioModel>[];

  @override
  Future<List<HorarioModel>> build() async => items;

  @override
  Future<void> updateHorario(HorarioModel horario) async {
    updates.add(horario);
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
