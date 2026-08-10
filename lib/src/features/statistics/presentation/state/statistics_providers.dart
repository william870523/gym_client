import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/member_statistics.dart';
import '../../data/models/plan_statistics.dart';
import '../../data/models/trainer_statistics.dart';
import '../../data/models/statistics_rankings.dart';
import '../../data/models/statistics_ranking_page.dart';
import '../../data/models/statistics_segmentation.dart';
import '../../data/models/statistics_cohorts.dart';
import '../../data/models/accounting_statistics.dart';
import '../../data/models/statistics_forecast.dart';
import '../../../../core/theme/pulso/appearance_provider.dart';
import '../../data/repositories/statistics_repository.dart';
import '../../data/services/segmentation_saved_views_store.dart';

/// Socio cuyo perfil se está mirando. `null` = todavía no se ha elegido a nadie.
class SelectedMemberNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? ci) => state = ci;

  void clear() => state = null;
}

final selectedMemberProvider =
    NotifierProvider<SelectedMemberNotifier, String?>(
      SelectedMemberNotifier.new,
    );

/// Perfil estadístico del socio seleccionado.
final memberStatisticsProvider = FutureProvider.autoDispose
    .family<MemberStatistics, String>((ref, ci) {
      return ref.watch(statisticsRepositoryProvider).getMemberStatistics(ci);
    });

/// Entrenador cuyo perfil se está mirando.
class SelectedTrainerNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;

  void clear() => state = null;
}

final selectedTrainerProvider =
    NotifierProvider<SelectedTrainerNotifier, String?>(
      SelectedTrainerNotifier.new,
    );

final trainerStatisticsProvider = FutureProvider.autoDispose
    .family<TrainerStatistics, String>((ref, id) {
      return ref.watch(statisticsRepositoryProvider).getTrainerStatistics(id);
    });

/// Plan cuyo perfil se está mirando.
class SelectedPlanNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;

  void clear() => state = null;
}

final selectedPlanProvider = NotifierProvider<SelectedPlanNotifier, String?>(
  SelectedPlanNotifier.new,
);

final planStatisticsProvider = FutureProvider.autoDispose
    .family<PlanStatistics, String>((ref, id) {
      return ref.watch(statisticsRepositoryProvider).getPlanStatistics(id);
    });

final statisticsRankingsProvider = FutureProvider.autoDispose
    .family<StatisticsRankings, int>((ref, days) {
      return ref.watch(statisticsRepositoryProvider).getRankings(days);
    });

class StatisticsRankingQueryNotifier extends Notifier<StatisticsRankingQuery> {
  @override
  StatisticsRankingQuery build() => StatisticsRankingQuery.initial(
    type: StatisticsRankingType.trainers,
    days: 90,
  );

  void open({
    required StatisticsRankingType type,
    required int days,
    String? currencyId,
  }) {
    state = StatisticsRankingQuery.initial(
      type: type,
      days: days,
      currencyId: currencyId,
    );
  }

  void setDays(int days) => state = state.copyWith(days: days, page: 1);

  void setSearch(String search) =>
      state = state.copyWith(search: search.trim(), page: 1);

  void setOrder(String order) => state = state.copyWith(order: order, page: 1);

  void toggleDirection() => state = state.copyWith(
    direction: state.direction == 'desc' ? 'asc' : 'desc',
    page: 1,
  );

  void setPageSize(int pageSize) =>
      state = state.copyWith(pageSize: pageSize, page: 1);

  void setPage(int page) => state = state.copyWith(page: page);
}

final statisticsRankingQueryProvider =
    NotifierProvider<StatisticsRankingQueryNotifier, StatisticsRankingQuery>(
      StatisticsRankingQueryNotifier.new,
    );

final statisticsRankingPageProvider = FutureProvider.autoDispose
    .family<StatisticsRankingPage, StatisticsRankingQuery>((ref, query) {
      return ref.watch(statisticsRepositoryProvider).getRankingPage(query);
    });

/// Fase E3-b: cohortes de alta, mapa de demanda y calidad de datos.
///
/// Los tres comparten un solo selector de período y de granularidad, porque se
/// leen juntos: la cohorte dice cuántos se quedaron, la demanda cuándo vienen y
/// la calidad qué parte de las dos conclusiones es confiable.
class CohortsQuery {
  const CohortsQuery({this.days = 365, this.granularity = 'mes'});

  final int days;
  final String granularity;

  CohortsQuery copyWith({int? days, String? granularity}) => CohortsQuery(
    days: days ?? this.days,
    granularity: granularity ?? this.granularity,
  );

  @override
  bool operator ==(Object other) =>
      other is CohortsQuery &&
      other.days == days &&
      other.granularity == granularity;

  @override
  int get hashCode => Object.hash(days, granularity);
}

class CohortsQueryNotifier extends Notifier<CohortsQuery> {
  @override
  CohortsQuery build() => const CohortsQuery();

  void setDays(int days) => state = state.copyWith(days: days);

  void setGranularity(String granularity) =>
      state = state.copyWith(granularity: granularity);
}

final cohortsQueryProvider =
    NotifierProvider<CohortsQueryNotifier, CohortsQuery>(
      CohortsQueryNotifier.new,
    );

final cohortsProvider = FutureProvider.autoDispose
    .family<CohortsReport, CohortsQuery>((ref, query) {
      return ref
          .watch(statisticsRepositoryProvider)
          .getCohorts(days: query.days, granularity: query.granularity);
    });

final demandProvider = FutureProvider.autoDispose.family<DemandReport, int>((
  ref,
  days,
) {
  return ref.watch(statisticsRepositoryProvider).getDemand(days);
});

final dataQualityProvider = FutureProvider.autoDispose
    .family<QualityReport, int>((ref, days) {
      return ref.watch(statisticsRepositoryProvider).getQuality(days);
    });

final accountingStatisticsProvider =
    FutureProvider.autoDispose<AccountingStatistics>((ref) {
      return ref.watch(statisticsRepositoryProvider).getAccountingStatistics();
    });

class StatisticsForecastQueryNotifier
    extends Notifier<StatisticsForecastQuery> {
  @override
  StatisticsForecastQuery build() => const StatisticsForecastQuery();

  void setHistoryDays(int days) => state = state.copyWith(historyDays: days);
  void setHorizonDays(int days) => state = state.copyWith(horizonDays: days);
}

final statisticsForecastQueryProvider =
    NotifierProvider<StatisticsForecastQueryNotifier, StatisticsForecastQuery>(
      StatisticsForecastQueryNotifier.new,
    );

final statisticsForecastProvider = FutureProvider.autoDispose
    .family<StatisticsForecast, StatisticsForecastQuery>((ref, query) {
      return ref.watch(statisticsRepositoryProvider).getForecast(query);
    });

/// Cruzador de segmentación (docs/PLAN_ESTADISTICAS.md §5).
///
/// El catálogo lo manda el servidor: dimensiones, medidas y la definición de
/// cada una. La vista no lo duplica porque una definición escrita dos veces
/// acaba diciendo dos cosas.
final segmentationCatalogProvider = FutureProvider<SegmentationCatalog>((ref) {
  return ref.watch(statisticsRepositoryProvider).getSegmentationCatalog();
});

class SegmentationQueryNotifier extends Notifier<SegmentationQuery> {
  @override
  SegmentationQuery build() => const SegmentationQuery(
    dimension: 'plan',
    measure: 'asistencias',
    days: 90,
  );

  void setDimension(String dimension) =>
      state = state.copyWith(dimension: dimension);

  void setMeasure(String measure) => state = state.copyWith(measure: measure);

  void setDays(int days) => state = state.copyWith(days: days);

  void setCurrency(String? currencyId) => currencyId == null
      ? state = state.copyWith(clearCurrency: true)
      : state = state.copyWith(currencyId: currencyId);
}

final segmentationQueryProvider =
    NotifierProvider<SegmentationQueryNotifier, SegmentationQuery>(
      SegmentationQueryNotifier.new,
    );

final segmentationProvider = FutureProvider.autoDispose
    .family<SegmentationResult, SegmentationQuery>((ref, query) {
      return ref.watch(statisticsRepositoryProvider).getSegmentation(query);
    });

/// Vistas guardadas del cruzador (§5, «filtros guardados»).
///
/// Son preferencia de interfaz por usuario, no dato de negocio: ver el porqué
/// en `segmentation_saved_views_store.dart`.
final segmentationSavedViewsStoreProvider =
    Provider<SegmentationSavedViewsStore>(
      (ref) => SharedPreferencesSegmentationViewsStore(),
    );

class SegmentationSavedViewsNotifier
    extends AsyncNotifier<List<SegmentationSavedView>> {
  @override
  Future<List<SegmentationSavedView>> build() {
    final userId = ref.watch(appearanceUserProvider);
    return ref.read(segmentationSavedViewsStoreProvider).load(userId);
  }

  /// Guarda la consulta actual con un nombre. Repetir el nombre reemplaza, que
  /// es lo que espera quien vuelve a guardar «Lunes» tras cambiar el período.
  Future<void> guardar(String nombre, SegmentationQuery consulta) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return;
    final actuales = state.value ?? const <SegmentationSavedView>[];
    final siguientes = [
      ...actuales.where((vista) => !vista.sameName(limpio)),
      SegmentationSavedView(name: limpio, query: consulta),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    state = AsyncData(siguientes);
    await ref
        .read(segmentationSavedViewsStoreProvider)
        .save(ref.read(appearanceUserProvider), siguientes);
  }

  Future<void> borrar(String nombre) async {
    final actuales = state.value ?? const <SegmentationSavedView>[];
    final siguientes = actuales
        .where((vista) => !vista.sameName(nombre))
        .toList(growable: false);
    state = AsyncData(siguientes);
    await ref
        .read(segmentationSavedViewsStoreProvider)
        .save(ref.read(appearanceUserProvider), siguientes);
  }
}

final segmentationSavedViewsProvider =
    AsyncNotifierProvider<
      SegmentationSavedViewsNotifier,
      List<SegmentationSavedView>
    >(SegmentationSavedViewsNotifier.new);
