import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/dashboard/presentation/state/dashboard_nav_provider.dart';
import 'package:gym_client/src/features/financials/data/models/currency_model.dart';
import 'package:gym_client/src/features/financials/presentation/state/currency_notifier.dart';
import 'package:gym_client/src/features/statistics/data/models/statistics_ranking_page.dart';
import 'package:gym_client/src/features/statistics/data/models/statistics_comparison.dart';
import 'package:gym_client/src/features/statistics/data/models/statistics_ranking_csv.dart';
import 'package:gym_client/src/features/statistics/data/services/statistics_ranking_export_service.dart';
import 'package:gym_client/src/features/statistics/presentation/screens/statistics_ranking_explorer_pulso_view.dart';
import 'package:gym_client/src/features/statistics/presentation/state/statistics_providers.dart';

void main() {
  testWidgets('pagina, busca y abre el perfil sin montar todo el padrón', (
    tester,
  ) async {
    StatisticsRankingQuery? exportedQuery;
    final container = ProviderContainer(
      overrides: [
        appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
        currencyProvider.overrideWith(() => _Currencies()),
        statisticsRankingPageProvider.overrideWith((ref, query) async {
          return StatisticsRankingPage(
            zone: 'America/Los_Angeles',
            businessDay: '2026-07-30',
            period: const StatisticsRankingPeriod(
              days: 90,
              from: '2026-05-02',
              to: '2026-07-30',
            ),
            previousPeriod: const StatisticsRankingPeriod(
              days: 90,
              from: '2026-02-01',
              to: '2026-05-01',
            ),
            pagination: StatisticsRankingPagination(
              number: query.page,
              size: query.pageSize,
              total: 53,
              totalPages: 3,
            ),
            rows: const [
              StatisticsRankingRow(
                id: 'trainer-1',
                name: 'Adriana Cartera',
                values: {'carteraActiva': 18, 'ganados': 6, 'perdidos': 2},
                comparison: StatisticsMetricComparison(
                  metric: 'carteraActiva',
                  current: 18,
                  previous: 12,
                  delta: 6,
                  percentageChange: 50,
                ),
              ),
            ],
          );
        }),
        statisticsRankingExporterProvider.overrideWithValue((query) async {
          exportedQuery = query;
          return const StatisticsRankingExportResult(rows: 53, saved: true);
        }),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: StatisticsRankingExplorerPulsoView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('CARTERA POR ENTRENADOR'), findsWidgets);
    expect(find.text('53 registros'), findsOneWidget);
    expect(find.text('PERÍODO ANTERIOR'), findsOneWidget);
    expect(find.text('+50%'), findsOneWidget);
    expect(find.textContaining('anterior 2026-02-01'), findsOneWidget);
    expect(find.text('Página 1 de 3 · 25 por página'), findsOneWidget);
    expect(
      find.text(
        'El CSV incluye todos los registros filtrados, no solo esta página.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull, reason: 'carga inicial');

    await tester.tap(find.text('SIGUIENTE'));
    await tester.pumpAndSettle();
    expect(container.read(statisticsRankingQueryProvider).page, 2);
    expect(find.text('Página 2 de 3 · 25 por página'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'página siguiente');

    await tester.enterText(find.byKey(const ValueKey('ranking-search')), 'Ana');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(container.read(statisticsRankingQueryProvider).search, 'Ana');
    expect(container.read(statisticsRankingQueryProvider).page, 1);
    expect(tester.takeException(), isNull, reason: 'búsqueda');

    await tester.tap(find.byKey(const ValueKey('ranking-export-csv')));
    await tester.pumpAndSettle();
    expect(exportedQuery?.search, 'Ana');
    expect(exportedQuery?.page, 1);
    expect(find.text('CSV guardado: 53 registros exportados.'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'exportación CSV');

    await tester.tap(find.byKey(const ValueKey('ranking-explorer-trainer-1')));
    await tester.pump();
    expect(container.read(selectedTrainerProvider), 'trainer-1');
    expect(container.read(dashboardNavProvider), 29);
    expect(tester.takeException(), isNull, reason: 'abrir perfil');
  });

  testWidgets('conserva controles utilizables en ancho compacto y mediano', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
        currencyProvider.overrideWith(() => _Currencies()),
        statisticsRankingPageProvider.overrideWith((ref, query) async {
          return StatisticsRankingPage(
            zone: 'America/Havana',
            businessDay: '2026-07-30',
            pagination: StatisticsRankingPagination(
              number: query.page,
              size: query.pageSize,
              total: 1,
              totalPages: 1,
            ),
            rows: const [
              StatisticsRankingRow(
                id: 'trainer-1',
                name: 'Adriana',
                values: {'carteraActiva': 2, 'ganados': 1, 'perdidos': 0},
              ),
            ],
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(520, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: StatisticsRankingExplorerPulsoView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ranking-search')), findsOneWidget);
    expect(find.byKey(const ValueKey('ranking-order')), findsOneWidget);
    expect(find.text('Página 1 de 1 · 25 por página'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(760, 900);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ranking-page-size')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Currencies extends CurrencyNotifier {
  @override
  Future<List<CurrencyModel>> build() async => const [];
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
