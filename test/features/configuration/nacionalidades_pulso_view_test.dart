import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/configuration/data/models/nacionalidad_model.dart';
import 'package:gym_client/src/features/configuration/presentation/screens/nacionalidades_pulso_view.dart';
import 'package:gym_client/src/features/configuration/presentation/state/nacionalidad_notifier.dart';

void main() {
  const sizes = <String, Size>{
    'compacto': Size(390, 844),
    'mediano': Size(760, 900),
    'escritorio': Size(1280, 900),
    'monitor ancho': Size(1920, 1080),
  };

  for (final entry in sizes.entries) {
    testWidgets('Nacionalidades PULSO se adapta al ancho ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('NACIONALIDADES.', findRichText: true), findsOneWidget);
      expect(find.text('Dominicana'), findsOneWidget);
      expect(find.text('Estadounidense'), findsOneWidget);
      expect(find.text('MODO LOCAL'), findsOneWidget);
      expect(tester.takeException(), isNull);

      if (entry.key == 'mediano') {
        await tester.tap(find.text('Dominicana'));
        await tester.pumpAndSettle();
        expect(find.text('DETALLE SELECCIONADO'), findsOneWidget);
      }
      if (entry.key == 'escritorio') {
        await tester.tap(find.text('Dominicana'));
        await tester.pump();
        expect(find.text('DETALLE SELECCIONADO'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('filtra nacionalidades sin perder el catálogo', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('pulso-nationality-search')),
      'Domin',
    );
    await tester.pump();

    expect(find.text('Dominicana'), findsOneWidget);
    expect(find.text('Estadounidense'), findsNothing);
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
      nacionalidadProvider.overrideWith(
        () => _NationalityNotifier(const [
          NacionalidadModel(id: 'do', name: 'Dominicana', isoCode: 'DO'),
          NacionalidadModel(id: 'us', name: 'Estadounidense', isoCode: 'US'),
        ]),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: NacionalidadesPulsoView())),
  );
}

class _NationalityNotifier extends NacionalidadNotifier {
  _NationalityNotifier(this.items);

  final List<NacionalidadModel> items;

  @override
  Future<List<NacionalidadModel>> build() async => items;

  @override
  Future<void> refresh() async {
    state = AsyncData(items);
  }
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
