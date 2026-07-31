import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/features/statistics/data/models/statistics_segmentation.dart';
import 'package:gym_client/src/features/statistics/data/services/segmentation_saved_views_store.dart';
import 'package:gym_client/src/features/statistics/presentation/state/statistics_providers.dart';

/// Filtros guardados del cruzador (docs/PLAN_ESTADISTICAS.md §5).
class _MemoriaStore implements SegmentationSavedViewsStore {
  final Map<String, List<SegmentationSavedView>> _porUsuario = {};
  int escrituras = 0;

  @override
  Future<List<SegmentationSavedView>> load(String? userId) async =>
      _porUsuario[userId ?? ''] ?? const [];

  @override
  Future<void> save(String? userId, List<SegmentationSavedView> views) async {
    escrituras += 1;
    _porUsuario[userId ?? ''] = views;
  }
}

const _consulta = SegmentationQuery(
  dimension: 'tipo_pago',
  measure: 'ingreso',
  days: 90,
  currencyId: 'cup-1',
);

ProviderContainer _contenedor(_MemoriaStore store, {String? usuario}) {
  final container = ProviderContainer(
    overrides: [
      segmentationSavedViewsStoreProvider.overrideWithValue(store),
    ],
  );
  if (usuario != null) {
    container.read(appearanceUserProvider.notifier).set(usuario);
  }
  return container;
}

void main() {
  test('guarda el cruce entero, no solo el eje', () async {
    final store = _MemoriaStore();
    final container = _contenedor(store, usuario: 'ana');
    addTearDown(container.dispose);
    await container.read(segmentationSavedViewsProvider.future);

    await container
        .read(segmentationSavedViewsProvider.notifier)
        .guardar('Lunes', _consulta);

    final guardadas = container.read(segmentationSavedViewsProvider).value!;
    expect(guardadas, hasLength(1));
    // Recuperar media configuración obligaría a rehacer la otra mitad.
    expect(guardadas.single.query.dimension, 'tipo_pago');
    expect(guardadas.single.query.measure, 'ingreso');
    expect(guardadas.single.query.days, 90);
    expect(guardadas.single.query.currencyId, 'cup-1');
  });

  test('volver a guardar con el mismo nombre reemplaza, no duplica', () async {
    final store = _MemoriaStore();
    final container = _contenedor(store, usuario: 'ana');
    addTearDown(container.dispose);
    await container.read(segmentationSavedViewsProvider.future);
    final notifier = container.read(segmentationSavedViewsProvider.notifier);

    await notifier.guardar('Lunes', _consulta);
    await notifier.guardar('  lunes  ', _consulta.copyWith(days: 30));

    final guardadas = container.read(segmentationSavedViewsProvider).value!;
    expect(guardadas, hasLength(1));
    expect(guardadas.single.query.days, 30);
  });

  test('un nombre vacío no crea una vista sin nombre', () async {
    final store = _MemoriaStore();
    final container = _contenedor(store, usuario: 'ana');
    addTearDown(container.dispose);
    await container.read(segmentationSavedViewsProvider.future);

    await container
        .read(segmentationSavedViewsProvider.notifier)
        .guardar('   ', _consulta);

    expect(container.read(segmentationSavedViewsProvider).value, isEmpty);
    expect(store.escrituras, 0);
  });

  test('borrar quita solo la suya', () async {
    final store = _MemoriaStore();
    final container = _contenedor(store, usuario: 'ana');
    addTearDown(container.dispose);
    await container.read(segmentationSavedViewsProvider.future);
    final notifier = container.read(segmentationSavedViewsProvider.notifier);

    await notifier.guardar('Lunes', _consulta);
    await notifier.guardar('Viernes', _consulta.copyWith(days: 365));
    await notifier.borrar('Lunes');

    final guardadas = container.read(segmentationSavedViewsProvider).value!;
    expect(guardadas.map((v) => v.name), ['Viernes']);
  });

  test('se ordenan por nombre para que no bailen entre sesiones', () async {
    final store = _MemoriaStore();
    final container = _contenedor(store, usuario: 'ana');
    addTearDown(container.dispose);
    await container.read(segmentationSavedViewsProvider.future);
    final notifier = container.read(segmentationSavedViewsProvider.notifier);

    await notifier.guardar('Zeta', _consulta);
    await notifier.guardar('alfa', _consulta);

    expect(
      container.read(segmentationSavedViewsProvider).value!.map((v) => v.name),
      ['alfa', 'Zeta'],
    );
  });

  test('son de cada cuenta: otra sesión no ve las ajenas', () async {
    final store = _MemoriaStore();
    final deAna = _contenedor(store, usuario: 'ana');
    addTearDown(deAna.dispose);
    await deAna.read(segmentationSavedViewsProvider.future);
    await deAna
        .read(segmentationSavedViewsProvider.notifier)
        .guardar('Lunes', _consulta);

    final deLuis = _contenedor(store, usuario: 'luis');
    addTearDown(deLuis.dispose);
    expect(await deLuis.read(segmentationSavedViewsProvider.future), isEmpty);
    expect(await store.load('ana'), hasLength(1));
  });

  test('sobrevive a la serialización de ida y vuelta', () {
    const vista = SegmentationSavedView(name: 'Lunes', query: _consulta);
    final recuperada = SegmentationSavedView.fromJson(vista.toJson());
    expect(recuperada.name, 'Lunes');
    expect(recuperada.query, _consulta);
  });

  test('una preferencia sin moneda no inventa ninguna', () {
    final vista = SegmentationSavedView.fromJson({
      'nombre': 'Visitas',
      'dimension': 'plan',
      'medida': 'asistencias',
      'dias': 30,
    });
    expect(vista.query.currencyId, isNull);
    expect(vista.query.days, 30);
  });
}
