import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/retention/data/models/retention_models.dart';
import 'package:gym_client/src/features/retention/presentation/screens/dropout_reasons_pulso_view.dart';
import 'package:gym_client/src/features/retention/presentation/state/retention_providers.dart';

const _catalog = [
  DropoutReasonModel(
    id: 'mbaja-precio',
    name: 'Precio',
    code: 'PRECIO',
    order: 1,
    active: true,
    isSystem: true,
    managements: 7,
  ),
  DropoutReasonModel(
    id: 'mbaja-horario',
    name: 'Horario',
    code: 'HORARIO',
    order: 2,
    active: true,
    isSystem: true,
    managements: 0,
  ),
  DropoutReasonModel(
    id: 'mbaja-musica',
    name: 'No le gusta la música',
    code: null,
    order: 3,
    active: false,
    isSystem: false,
    managements: 0,
  ),
];

void main() {
  testWidgets('resume el catálogo y señala el motivo líder', (tester) async {
    await _pump(tester, const Size(1280, 900));

    // El título es RichText porque el punto va en el color de acento (receta
    // PULSO), así que hay que pedirle al buscador que mire dentro.
    expect(
      find.text('MOTIVOS DE\nBAJA.', findRichText: true),
      findsOneWidget,
    );
    // Total, activos, gestiones con motivo y el líder por uso.
    expect(find.text('3'), findsWidgets);
    expect(find.text('Motivo líder'), findsOneWidget);
    expect(find.text('Precio'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('distingue en uso, sin uso e inactivo en la propia fila', (
    tester,
  ) async {
    await _pump(tester, const Size(1280, 900));

    expect(find.textContaining('En uso'), findsWidgets);
    expect(find.textContaining('Sin uso'), findsWidgets);
    expect(find.textContaining('Inactivo'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtra los que nadie ha usado', (tester) async {
    await _pump(tester, const Size(1280, 900));

    await tester.tap(find.textContaining('SIN USO'));
    await tester.pumpAndSettle();

    expect(_inList('Horario'), findsOneWidget);
    expect(_inList('No le gusta la música'), findsOneWidget);
    // «Precio» tiene 7 gestiones: queda fuera del filtro.
    expect(_inList('Precio'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('busca por código además de por nombre', (tester) async {
    await _pump(tester, const Size(1280, 900));

    await tester.enterText(
      find.byKey(const ValueKey('dropout-reason-search')),
      'HORARIO',
    );
    await tester.pumpAndSettle();

    expect(_inList('Horario'), findsOneWidget);
    expect(_inList('Precio'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un motivo ya usado explica por qué no se borra', (tester) async {
    await _pump(tester, const Size(1280, 900));

    // Seleccionar «Precio» abre el detalle lateral en pantalla ancha.
    await tester.tap(_inList('Precio'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Los motivos base no se borran'), findsOneWidget);
    expect(find.text('Participación'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el detalle se abre como diálogo en ancho compacto', (
    tester,
  ) async {
    await _pump(tester, const Size(520, 820));

    await tester.tap(_inList('Precio'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Participación'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un catálogo vacío lo dice en vez de mostrar una tabla vacía', (
    tester,
  ) async {
    await _pump(tester, const Size(1280, 900), catalog: const []);

    expect(
      find.textContaining('Todavía no hay motivos de baja'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}


/// Busca dentro de la tabla, no en toda la página: la banda de métricas también
/// nombra al motivo líder y confundiría cualquier aserción sobre el listado.
Finder _inList(String text) => find.descendant(
  of: find.byKey(const PageStorageKey('dropout-reason-list')),
  matching: find.text(text),
);

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  List<DropoutReasonModel> catalog = _catalog,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
        dropoutReasonCatalogProvider.overrideWith(
          () => _FakeCatalogNotifier(catalog),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: DropoutReasonsPulsoView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeCatalogNotifier extends DropoutReasonCatalogNotifier {
  _FakeCatalogNotifier(this._items);

  final List<DropoutReasonModel> _items;

  @override
  Future<List<DropoutReasonModel>> build() async => _items;
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
