import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';
import 'package:gym_client/src/features/clients/presentation/state/client_notifier.dart';
import 'package:gym_client/src/features/configuration/data/models/reference_model.dart';
import 'package:gym_client/src/features/configuration/presentation/providers/reference_notifier.dart';
import 'package:gym_client/src/features/configuration/presentation/screens/references_pulso_view.dart';

void main() {
  const sizes = <String, Size>{
    'compacto': Size(390, 844),
    'mediano': Size(760, 900),
    'escritorio': Size(1280, 900),
    'ventana baja': Size(1024, 650),
  };

  for (final entry in sizes.entries) {
    testWidgets('Referencias PULSO se adapta al ancho ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('REFERENCIAS.', findRichText: true), findsOneWidget);
      // El nombre del canal líder puede repetirse en la banda de métricas.
      expect(find.text('Instagram'), findsWidgets);
      expect(find.text('Volante'), findsOneWidget);
      expect(find.text('MODO LOCAL'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final instagramRow = find.descendant(
        of: find.byKey(const PageStorageKey('pulso-references-list')),
        matching: find.text('Instagram'),
      );
      if (entry.key == 'mediano') {
        await tester.tap(instagramRow);
        await tester.pumpAndSettle();
        expect(find.text('DETALLE SELECCIONADO'), findsOneWidget);
      }
      if (entry.key == 'escritorio') {
        await tester.tap(instagramRow);
        await tester.pump();
        expect(find.text('DETALLE SELECCIONADO'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cuenta socios captados por canal', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // Instagram capta 2 socios; Volante ninguno.
    expect(find.text('2 socios'), findsOneWidget);
    expect(find.text('Canal líder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtra canales con y sin socios', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sin socios').last);
    await tester.pump();
    final list = find.byKey(const PageStorageKey('pulso-references-list'));
    expect(
      find.descendant(of: list, matching: find.text('Volante')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: list, matching: find.text('Instagram')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _harness() {
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
      referenceProvider.overrideWith(
        () => _ReferenceNotifier([
          ReferenceModel(id: 'ref-instagram', nombre: 'Instagram'),
          ReferenceModel(id: 'ref-volante', nombre: 'Volante'),
        ]),
      ),
      clientNotifierProvider.overrideWith(
        () => _ClientNotifier([
          ClientModel(id: '100', nombres: 'Ana', referralId: 'ref-instagram'),
          ClientModel(id: '200', nombres: 'Luis', referralId: 'ref-instagram'),
          ClientModel(id: '300', nombres: 'Eva'),
        ]),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: ReferencesPulsoView())),
  );
}

class _ReferenceNotifier extends ReferenceNotifier {
  _ReferenceNotifier(this.items);
  final List<ReferenceModel> items;

  @override
  Future<List<ReferenceModel>> build() async => items;
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
