import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/clients/presentation/state/clients_scope_filter_provider.dart';
import 'package:gym_client/src/features/dashboard/presentation/state/dashboard_nav_provider.dart';
import 'package:gym_client/src/features/financials/data/models/currency_model.dart';
import 'package:gym_client/src/features/financials/presentation/state/currency_notifier.dart';
import 'package:gym_client/src/features/statistics/data/models/statistics_segmentation.dart';
import 'package:gym_client/src/features/statistics/data/services/segmentation_saved_views_store.dart';
import 'package:gym_client/src/features/statistics/presentation/screens/statistics_segmentation_pulso_view.dart';
import 'package:gym_client/src/features/statistics/presentation/state/statistics_providers.dart';

final _catalogo = SegmentationCatalog.fromJson({
  'dimensiones': [
    {'dimension': 'plan', 'titulo': 'Plan'},
    {'dimension': 'tipo_pago', 'titulo': 'Medio de pago'},
    {'dimension': 'moneda', 'titulo': 'Moneda'},
  ],
  'medidas': [
    {
      'medida': 'asistencias',
      'titulo': 'Asistencias',
      'dinero': false,
      'tasa': false,
      'ignoraPeriodo': false,
      'definicion': 'Visitas registradas dentro del período.',
    },
    {
      'medida': 'visitasPorSocio',
      'titulo': 'Visitas por socio',
      'dinero': false,
      'tasa': true,
      'ignoraPeriodo': false,
      'definicion':
          'Visitas del período divididas entre los socios distintos que '
          'vinieron.',
    },
    {
      'medida': 'ingreso',
      'titulo': 'Ingreso cobrado',
      'dinero': true,
      'tasa': false,
      'ignoraPeriodo': false,
      'definicion': 'Importe cobrado en el período, sin cobros anulados.',
    },
  ],
});

Map<String, dynamic> _resultado({
  required String dimension,
  required String medida,
  bool compatible = true,
}) => {
  'zona': 'America/Los_Angeles',
  'dia_negocio': '2026-07-31',
  'periodo': {
    'dias': 90,
    'desde': '2026-05-03',
    'hasta': '2026-07-31',
    'aplica': true,
  },
  'dimension': dimension,
  'dimensionTitulo': dimension == 'plan' ? 'Plan' : 'Medio de pago',
  'medida': medida,
  'medidaTitulo': medida == 'asistencias' ? 'Asistencias' : 'Visitas por socio',
  'definicion': 'Visitas registradas dentro del período.',
  'dinero': false,
  'tasa': medida == 'visitasPorSocio',
  'compatible': compatible,
  'motivo': compatible
      ? null
      : '«Asistencias» no se puede agrupar por medio de pago: medio de pago es '
            'un dato del cobro y este recuento no cuenta cobros.',
  'monedaId': null,
  'total': medida == 'visitasPorSocio' ? null : 900,
  'filas': compatible
      ? [
          {
            'clave': 'p1',
            'etiqueta': 'Mensual',
            'valor': medida == 'visitasPorSocio' ? 25.68 : 642,
            'numerador': medida == 'visitasPorSocio' ? 642 : null,
            'denominador': medida == 'visitasPorSocio' ? 25 : null,
            'participacion': medida == 'visitasPorSocio' ? null : 71.33,
            'muestraBaja': false,
          },
          {
            'clave': 'p2',
            'etiqueta': 'Semanal',
            'valor': medida == 'visitasPorSocio' ? 21.5 : 258,
            'numerador': medida == 'visitasPorSocio' ? 86 : null,
            'denominador': medida == 'visitasPorSocio' ? 4 : null,
            'participacion': medida == 'visitasPorSocio' ? null : 28.67,
            'muestraBaja': medida == 'visitasPorSocio',
          },
        ]
      : const [],
};

ProviderContainer _contenedor(Map<String, dynamic> resultado) =>
    ProviderContainer(
      overrides: [
        appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
        currencyProvider.overrideWith(
          () => _Currencies(const [
            CurrencyModel(id: 'cup-1', name: 'Peso cubano', code: 'CUP'),
          ]),
        ),
        segmentationSavedViewsStoreProvider.overrideWithValue(
          _MemoriaVistas(),
        ),
        segmentationCatalogProvider.overrideWith((ref) async => _catalogo),
        segmentationProvider.overrideWith(
          (ref, query) async => SegmentationResult.fromJson(resultado),
        ),
      ],
    );

Future<void> _montar(WidgetTester tester, ProviderContainer container) async {
  tester.view.physicalSize = const Size(1280, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: StatisticsSegmentationPulsoView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cruza, enseña la definición y reparte participación', (
    tester,
  ) async {
    final container = _contenedor(
      _resultado(dimension: 'plan', medida: 'asistencias'),
    );
    addTearDown(container.dispose);
    await _montar(tester, container);

    expect(find.text('Asistencias por plan'), findsOneWidget);
    // La definición viaja con el dato: es parte del contrato, no un adorno.
    expect(
      find.text('Visitas registradas dentro del período.'),
      findsOneWidget,
    );
    expect(find.text('Ranking'), findsOneWidget);
    expect(find.text('Participación'), findsOneWidget);
    expect(find.textContaining('total 900'), findsOneWidget);
    expect(find.byKey(const ValueKey('cruzador-fila-p1')), findsOneWidget);
    expect(find.text('71.33%'), findsOneWidget);
  });

  testWidgets('una tasa lleva denominador, avisa de muestra baja y no hace dona', (
    tester,
  ) async {
    final container = _contenedor(
      _resultado(dimension: 'plan', medida: 'visitasPorSocio'),
    );
    addTearDown(container.dispose);
    container
        .read(segmentationQueryProvider.notifier)
        .setMeasure('visitasPorSocio');
    await _montar(tester, container);

    expect(find.textContaining('sobre 25'), findsOneWidget);
    expect(find.textContaining('muestra baja'), findsOneWidget);
    // Sumar medias no da un todo: no hay dona ni total.
    expect(find.text('Participación'), findsNothing);
    expect(find.textContaining('sin total: no se suman medias'), findsOneWidget);
  });

  testWidgets('una combinación imposible se explica en vez de dar cero', (
    tester,
  ) async {
    final container = _contenedor(
      _resultado(
        dimension: 'tipo_pago',
        medida: 'asistencias',
        compatible: false,
      ),
    );
    addTearDown(container.dispose);
    await _montar(tester, container);

    expect(find.byKey(const ValueKey('cruzador-incompatible')), findsOneWidget);
    expect(find.textContaining('es un dato del cobro'), findsOneWidget);
    expect(find.textContaining('no se contó cero'), findsOneWidget);
    expect(find.text('Ranking'), findsNothing);
  });

  testWidgets('la fila lleva a Clientes con ese corte ya puesto', (
    tester,
  ) async {
    final container = _contenedor(
      _resultado(dimension: 'plan', medida: 'asistencias'),
    );
    addTearDown(container.dispose);
    await _montar(tester, container);

    expect(
      find.textContaining('Cada fila abre Clientes con ese corte'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('cruzador-fila-p1')));
    await tester.pump();

    final filtro = container.read(clientsScopeFilterProvider);
    expect(filtro, isNotNull);
    expect(filtro!.attribute, ClientsAttribute.plan);
    expect(filtro.id, 'p1');
    expect(filtro.label, 'Mensual');
    expect(filtro.heading, 'Socios por plan:');
    expect(container.read(dashboardNavProvider), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('una fila de eje del cobro no navega, y lo dice', (tester) async {
    final resultado = _resultado(dimension: 'plan', medida: 'asistencias');
    resultado['dimension'] = 'tipo_pago';
    resultado['dimensionTitulo'] = 'Medio de pago';
    final container = _contenedor(resultado);
    addTearDown(container.dispose);
    await _montar(tester, container);

    expect(
      find.textContaining('no es un dato del socio'),
      findsOneWidget,
    );
    // `warnIfMissed: false` es aquí la afirmación, no un parche: no hay nada
    // pulsable en esa fila, que es exactamente lo que se quiere comprobar.
    await tester.tap(
      find.byKey(const ValueKey('cruzador-fila-p1')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(find.descendant(
      of: find.byKey(const ValueKey('cruzador-fila-p1')),
      matching: find.byType(InkWell),
    ), findsNothing);
    expect(container.read(clientsScopeFilterProvider), isNull);
    expect(container.read(dashboardNavProvider), isNot(1));
  });

  testWidgets('una vista guardada devuelve el cruce entero de un toque', (
    tester,
  ) async {
    final container = _contenedor(
      _resultado(dimension: 'plan', medida: 'asistencias'),
    );
    addTearDown(container.dispose);
    await _montar(tester, container);

    expect(find.byKey(const ValueKey('cruzador-sin-vistas')), findsOneWidget);

    // Se cambia el cruce y se guarda con nombre.
    container.read(segmentationQueryProvider.notifier).setMeasure('ingreso');
    container.read(segmentationQueryProvider.notifier).setDays(30);
    await tester.pumpAndSettle();
    await container
        .read(segmentationSavedViewsProvider.notifier)
        .guardar('Ingreso mensual', container.read(segmentationQueryProvider));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('cruzador-vista-Ingreso mensual')),
      findsOneWidget,
    );

    // Se vuelve a otro cruce y la vista lo restituye entero.
    container.read(segmentationQueryProvider.notifier).setMeasure('asistencias');
    container.read(segmentationQueryProvider.notifier).setDays(365);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('cruzador-vista-Ingreso mensual')),
    );
    await tester.pumpAndSettle();

    final consulta = container.read(segmentationQueryProvider);
    expect(consulta.measure, 'ingreso');
    expect(consulta.days, 30);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la moneda solo se pide cuando la medida es dinero', (
    tester,
  ) async {
    final container = _contenedor(
      _resultado(dimension: 'plan', medida: 'asistencias'),
    );
    addTearDown(container.dispose);
    await _montar(tester, container);
    expect(find.byKey(const ValueKey('cruzador-moneda')), findsNothing);

    container.read(segmentationQueryProvider.notifier).setMeasure('ingreso');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cruzador-moneda')), findsOneWidget);

    // Con la moneda como eje vuelve a sobrar: cada fila ya es una moneda.
    container.read(segmentationQueryProvider.notifier).setDimension('moneda');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cruzador-moneda')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

/// Las vistas guardadas son preferencia de interfaz: en la prueba se guardan
/// en memoria para no tocar el almacén real del puesto.
class _MemoriaVistas implements SegmentationSavedViewsStore {
  List<SegmentationSavedView> _vistas = const [];
  @override
  Future<List<SegmentationSavedView>> load(String? userId) async => _vistas;
  @override
  Future<void> save(String? userId, List<SegmentationSavedView> views) async {
    _vistas = views;
  }
}

class _Currencies extends CurrencyNotifier {
  _Currencies(this.values);
  final List<CurrencyModel> values;
  @override
  Future<List<CurrencyModel>> build() async => values;
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;
  @override
  Future<void> save(AppearancePreference preference) async {}
}
