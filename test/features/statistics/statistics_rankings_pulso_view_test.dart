import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/core/widgets/pulso_widgets.dart';
import 'package:gym_client/src/features/dashboard/presentation/state/dashboard_nav_provider.dart';
import 'package:gym_client/src/features/financials/data/models/currency_model.dart';
import 'package:gym_client/src/features/financials/presentation/state/currency_notifier.dart';
import 'package:gym_client/src/features/statistics/data/models/statistics_rankings.dart';
import 'package:gym_client/src/features/statistics/data/models/statistics_ranking_page.dart';
import 'package:gym_client/src/features/statistics/presentation/screens/statistics_rankings_pulso_view.dart';
import 'package:gym_client/src/features/statistics/presentation/state/statistics_providers.dart';

final _rankingsJson = <String, dynamic>{
  'zona': 'America/Los_Angeles',
  'dia_negocio': '2026-07-30',
  'periodo': {'dias': 90, 'desde': '2026-05-02', 'hasta': '2026-07-30'},
  'periodoAnterior': {'dias': 90, 'desde': '2026-02-01', 'hasta': '2026-05-01'},
  'resumen': {
    'sociosRegistrados': 120,
    'sociosActivos': 94,
    'sociosConCobertura': 82,
    'menores18': 7,
    'sinFechaNacimiento': 2,
    'porSexo': [
      {'etiqueta': 'F', 'total': 62},
      {'etiqueta': 'M', 'total': 58},
    ],
  },
  'planes': [
    {
      'id': 'plan-1',
      'nombre': 'Trimestral',
      'vendidos': 26,
      'sociosConCobertura': 21,
      'renovaciones': 7,
      'comparacion': {
        'metrica': 'vendidos',
        'actual': 26,
        'anterior': 10,
        'delta': 16,
        'variacionPorcentual': 160,
      },
    },
  ],
  'entrenadores': [
    {
      'id': 'trainer-1',
      'nombre': 'Yoandry Pérez',
      'carteraActiva': 18,
      'ganados': 6,
      'perdidos': 2,
    },
  ],
  'socios': {
    'porVisitas': [
      {
        'ci': '76120323785',
        'nombre': 'Luis Martínez',
        'visitas': 38,
        'diasSinVisita': 1,
        'ultimaVisita': '2026-07-29T12:00:00.000Z',
      },
    ],
    'porInactividad': [
      {
        'ci': '88060138877',
        'nombre': 'Rosa Peña',
        'visitas': 1,
        'diasSinVisita': 42,
        'ultimaVisita': '2026-06-18T12:00:00.000Z',
      },
    ],
    'porCambiosEntrenador': [
      {'ci': '88060138877', 'nombre': 'Rosa Peña', 'cambios': 3},
    ],
    'porValor': [
      {
        'monedaId': 'cup-1',
        'ranking': [
          {
            'ci': '76120323785',
            'nombre': 'Luis Martínez',
            'monedaId': 'cup-1',
            'total': 12000,
          },
        ],
      },
    ],
  },
};

final _rankings = StatisticsRankings.fromJson(_rankingsJson);

final _conAlertas = StatisticsRankings.fromJson({
  ..._rankingsJson,
  'alertas': [
    {
      'id': 'asistencia-caida',
      'familia': 'asistencia',
      'severidad': 'peligro',
      'titulo': 'La asistencia cae',
      'detalle': 'Se registraron 210 visitas frente a 400 del bloque anterior.',
      'regla': 'Asistencia: se avisa cuando las visitas caen 15 % o más.',
      'comparacion': {
        'metrica': 'visitas',
        'actual': 210,
        'anterior': 400,
        'delta': -190,
        'variacionPorcentual': -47.5,
      },
      'muestra': {
        'valor': 210,
        'base': 400,
        'etiqueta': 'visitas del período sobre las del anterior',
      },
      'destino': {'tipo': 'ranking', 'ranking': 'socios-inactividad'},
    },
    {
      'id': 'mora-aumento:cup-1',
      'familia': 'mora',
      'severidad': 'aviso',
      'titulo': 'Sube el recargo de mora',
      'detalle': 'El recargo cobrado pasó de 1.000,00 a 1.400,00.',
      'regla': 'Mora: se avisa, por moneda y sin sumarlas, cuando sube 25 %.',
      'comparacion': {
        'metrica': 'recargoMora',
        'actual': 1400,
        'anterior': 1000,
        'delta': 400,
        'variacionPorcentual': 40,
      },
      'muestra': {
        'valor': 9,
        'base': 6,
        'etiqueta': 'cobros con recargo sobre los del bloque anterior',
      },
      'monedaId': 'cup-1',
      'destino': null,
    },
  ],
  'alertasOmitidas': 2,
  'reglasAlerta': [
    {'familia': 'asistencia', 'texto': 'Asistencia: cae 15 % o más.'},
  ],
});

void main() {
  testWidgets('el aviso enseña su regla, su denominador y su destino', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
        currencyProvider.overrideWith(
          () => _Currencies(const [
            CurrencyModel(id: 'cup-1', name: 'Peso cubano', code: 'CUP'),
          ]),
        ),
        statisticsRankingsProvider.overrideWith(
          (ref, days) async => _conAlertas,
        ),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: StatisticsRankingsPulsoView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Requiere atención'), findsOneWidget);
    expect(find.text('1 peligro · 1 aviso'), findsOneWidget);
    expect(find.text('PELIGRO'), findsOneWidget);
    // La regla viaja completa: un aviso sin su umbral a la vista es opinión.
    expect(
      find.textContaining('Regla · Asistencia: se avisa cuando las visitas'),
      findsOneWidget,
    );
    expect(
      find.textContaining('210 de 400 · visitas del período'),
      findsOneWidget,
    );
    expect(find.textContaining('Y 2 aviso(s) más'), findsOneWidget);

    // La mora se rotula con su moneda y no navega a ninguna parte todavía.
    expect(
      find.text('Sube el recargo de mora · CUP · Peso cubano'),
      findsOneWidget,
    );
    expect(find.textContaining('Sin destino todavía'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('asistencia-caida')));
    await tester.pump();
    expect(container.read(dashboardNavProvider), 32);
    expect(
      container.read(statisticsRankingQueryProvider).type,
      StatisticsRankingType.memberInactivity,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin avisos declara qué reglas se miraron', (tester) async {
    final container = ProviderContainer(
      overrides: [
        appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
        currencyProvider.overrideWith(() => _Currencies(const [])),
        statisticsRankingsProvider.overrideWith(
          (ref, days) async => StatisticsRankings.fromJson({
            ..._rankingsJson,
            'alertas': const [],
            'reglasAlerta': [
              {
                'familia': 'entrenador',
                'texto': 'Entrenadores: cartera que cae 20 % o más.',
              },
            ],
          }),
        ),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1280, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: StatisticsRankingsPulsoView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('alertas-vacio')), findsOneWidget);
    expect(find.text('sin avisos'), findsOneWidget);
    expect(
      find.text('Entrenadores: cartera que cae 20 % o más.'),
      findsOneWidget,
    );
  });

  testWidgets('muestra preguntas comparativas y declara la inactividad', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
        currencyProvider.overrideWith(
          () => _Currencies(const [
            CurrencyModel(id: 'cup-1', name: 'Peso cubano', code: 'CUP'),
          ]),
        ),
        statisticsRankingsProvider.overrideWith((ref, days) async => _rankings),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: StatisticsRankingsPulsoView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('PULSO DEL\nGIMNASIO.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Top 5 · planes más contratados'), findsOneWidget);
    expect(find.text('Top 5 · inactividad observada'), findsOneWidget);
    expect(find.textContaining('antes 10 · +160%'), findsOneWidget);
    expect(find.textContaining('anterior 2026-02-01'), findsOneWidget);
    expect(
      find.text('Días sin visitar; no supone una frecuencia obligatoria'),
      findsOneWidget,
    );
    expect(find.textContaining('CUP · Peso cubano'), findsWidgets);

    final trainerPanel = find.ancestor(
      of: find.text('Top 5 · cartera por entrenador'),
      matching: find.byType(PulsoPanel),
    );
    await tester.tap(
      find.descendant(
        of: trainerPanel.first,
        matching: find.text('VER RANKING COMPLETO'),
      ),
    );
    await tester.pump();
    expect(container.read(dashboardNavProvider), 32);
    expect(
      container.read(statisticsRankingQueryProvider).type,
      StatisticsRankingType.trainers,
    );

    await tester.tap(find.byKey(const ValueKey('ranking-plan-1')));
    await tester.pump();
    expect(container.read(selectedPlanProvider), 'plan-1');
    expect(container.read(dashboardNavProvider), 30);
    expect(tester.takeException(), isNull);
  });
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
