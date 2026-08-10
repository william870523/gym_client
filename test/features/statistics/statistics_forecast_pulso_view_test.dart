import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/statistics/data/models/statistics_forecast.dart';
import 'package:gym_client/src/features/statistics/presentation/screens/statistics_forecast_pulso_view.dart';
import 'package:gym_client/src/features/statistics/presentation/screens/statistics_shared.dart';
import 'package:gym_client/src/features/statistics/presentation/state/statistics_providers.dart';

StatisticsForecast _forecast() {
  final weekdays = <String>[
    'Domingo',
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
  ];
  return StatisticsForecast.fromJson({
    'zona': 'America/Los_Angeles',
    'dia_negocio': '2026-07-31',
    'disponible': true,
    'motivoNoDisponible': null,
    'historia': {
      'diasSolicitados': 180,
      'desde': '2026-02-03',
      'hasta': '2026-07-30',
      'diasUtiles': 178,
      'muestrasMinimasPorDiaSemana': 25,
    },
    'horizonte': {'dias': 28, 'desde': '2026-08-01', 'hasta': '2026-08-28'},
    'metodo': {
      'nombre': 'Mediana estacional por día de semana',
      'estimacion': 'Mediana histórica del mismo día de la semana.',
      'intervalo': 'Banda empírica central 80 %: percentiles 10 y 90.',
      'minimo': '8 observaciones completas por día de la semana.',
      'garantia': 'No es IA, presupuesto, aforo ni garantía.',
    },
    'tendenciaReciente': {
      'actual28Dias': 1024,
      'anterior28Dias': 849,
      'variacionPorcentual': 20.61,
      'estado': 'SUBE',
      'regla': 'SUBE desde +10 %, BAJA desde -10 %.',
    },
    'porDiaSemana': [
      for (var index = 0; index < 7; index += 1)
        {
          'diaSemana': index,
          'etiqueta': weekdays[index],
          'muestras': 25,
          'inferior': index + 1,
          'central': index + 10,
          'superior': index + 20,
        },
    ],
    'proyeccionDiaria': [
      for (var index = 0; index < 28; index += 1)
        {
          'dia': '2026-08-${(index + 1).toString().padLeft(2, '0')}',
          'diaSemana': index % 7,
          'etiqueta': weekdays[index % 7],
          'inferior': 5,
          'central': 16,
          'superior': 31,
        },
    ],
    'proyeccionSemanal': [
      for (var index = 0; index < 4; index += 1)
        {
          'semana': index + 1,
          'desde': '2026-08-${(index * 7 + 1).toString().padLeft(2, '0')}',
          'hasta': '2026-08-${(index * 7 + 7).toString().padLeft(2, '0')}',
          'inferior': 58,
          'central': 118,
          'superior': 246,
        },
    ],
    'totalHorizonte': {'inferior': 232, 'central': 472, 'superior': 984},
    'historiaReciente': [
      for (var index = 0; index < 28; index += 1)
        {
          'dia': '2026-07-${(index + 3).toString().padLeft(2, '0')}',
          'visitas': 20 + (index % 7) * 3,
        },
    ],
    'advertencias': [
      'Demanda observada no significa ocupación.',
      'La banda no es una garantía.',
    ],
  });
}

void main() {
  for (final size in const [
    Size(390, 2200),
    Size(760, 2200),
    Size(1280, 2200),
  ]) {
    testWidgets('pronóstico E5 se adapta sin overflow a ${size.width}', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
          statisticsForecastProvider.overrideWith(
            (ref, query) async => _forecast(),
          ),
        ],
      );
      addTearDown(container.dispose);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: StatisticsForecastPulsoView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StatsHeader), findsOneWidget);
      expect(find.textContaining('472'), findsWidgets);
      expect(find.text('Próximas semanas'), findsOneWidget);
      expect(find.text('Cómo se calcula'), findsOneWidget);
      expect(find.textContaining('No es IA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('el selector conserva la consulta como estado Riverpod', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
        statisticsForecastProvider.overrideWith(
          (ref, query) async => _forecast(),
        ),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1280, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: StatisticsForecastPulsoView()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pronostico-horizonte-7')));
    await tester.pumpAndSettle();
    expect(container.read(statisticsForecastQueryProvider).horizonDays, 7);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryAppearanceStore implements AppearanceStore {
  AppearancePreference? value;

  @override
  Future<AppearancePreference?> load() async => value;

  @override
  Future<void> save(AppearancePreference preference) async {
    value = preference;
  }
}
