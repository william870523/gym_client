import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../models/member_statistics.dart';
import '../models/plan_statistics.dart';
import '../models/trainer_statistics.dart';
import '../models/statistics_ranking_csv.dart';
import '../models/statistics_rankings.dart';
import '../models/statistics_ranking_page.dart';
import '../models/statistics_segmentation.dart';

final statisticsRepositoryProvider = Provider<StatisticsRepository>((ref) {
  return StatisticsRepository(ref.watch(apiClientProvider));
});

/// Acceso a la estadística (docs/PLAN_ESTADISTICAS.md). Solo lectura: aquí no
/// hay ningún método que escriba, y no debe haberlo.
class StatisticsRepository {
  const StatisticsRepository(this._dio);

  final Dio _dio;

  Future<MemberStatistics> getMemberStatistics(String ci) async {
    final respuesta = await _dio.get('/estadisticas/socio/$ci');
    return MemberStatistics.fromJson(
      Map<String, dynamic>.from(respuesta.data as Map),
    );
  }

  Future<TrainerStatistics> getTrainerStatistics(String id) async {
    final respuesta = await _dio.get('/estadisticas/entrenador/$id');
    return TrainerStatistics.fromJson(
      Map<String, dynamic>.from(respuesta.data as Map),
    );
  }

  Future<PlanStatistics> getPlanStatistics(String id) async {
    final respuesta = await _dio.get('/estadisticas/plan/$id');
    return PlanStatistics.fromJson(
      Map<String, dynamic>.from(respuesta.data as Map),
    );
  }

  Future<StatisticsRankings> getRankings(int days) async {
    final respuesta = await _dio.get(
      '/estadisticas/rankings',
      queryParameters: {'dias': days},
    );
    return StatisticsRankings.fromJson(
      Map<String, dynamic>.from(respuesta.data as Map),
    );
  }

  Future<StatisticsRankingPage> getRankingPage(
    StatisticsRankingQuery query,
  ) async {
    final respuesta = await _dio.get(
      '/estadisticas/ranking/${query.type.apiValue}',
      queryParameters: {
        'dias': query.days,
        'pagina': query.page,
        'tamano': query.pageSize,
        'q': query.search,
        'orden': query.order,
        'direccion': query.direction,
        if (query.currencyId != null) 'moneda_id': query.currencyId,
      },
    );
    return StatisticsRankingPage.fromJson(
      Map<String, dynamic>.from(respuesta.data as Map),
    );
  }

  Future<SegmentationCatalog> getSegmentationCatalog() async {
    final respuesta = await _dio.get('/estadisticas/segmentacion/catalogo');
    return SegmentationCatalog.fromJson(
      Map<String, dynamic>.from(respuesta.data as Map),
    );
  }

  Future<SegmentationResult> getSegmentation(SegmentationQuery query) async {
    final respuesta = await _dio.get(
      '/estadisticas/segmentacion',
      queryParameters: {
        'dimension': query.dimension,
        'medida': query.measure,
        'dias': query.days,
        if (query.currencyId != null) 'moneda_id': query.currencyId,
      },
    );
    return SegmentationResult.fromJson(
      Map<String, dynamic>.from(respuesta.data as Map),
    );
  }

  Future<StatisticsRankingCsv> getSegmentationCsv(
    SegmentationQuery query,
  ) async {
    final respuesta = await _dio.get<List<int>>(
      '/estadisticas/segmentacion/csv',
      queryParameters: {
        'dimension': query.dimension,
        'medida': query.measure,
        'dias': query.days,
        if (query.currencyId != null) 'moneda_id': query.currencyId,
      },
      options: Options(responseType: ResponseType.bytes),
    );
    final disposition = respuesta.headers.value('content-disposition') ?? '';
    final match = RegExp(
      r'''filename="?([^";]+)"?''',
      caseSensitive: false,
    ).firstMatch(disposition);
    final data = respuesta.data ?? const <int>[];
    return StatisticsRankingCsv(
      bytes: data is Uint8List ? data : Uint8List.fromList(data),
      fileName:
          match?.group(1) ??
          'segmentacion-${query.measure}-por-${query.dimension}.csv',
      rows: int.tryParse(respuesta.headers.value('x-exported-rows') ?? '') ?? 0,
    );
  }

  /// Descarga el conjunto completo que coincide con los filtros. La API genera
  /// el CSV para no cargar miles de filas en memoria de la vista paginada.
  Future<StatisticsRankingCsv> getRankingCsv(
    StatisticsRankingQuery query,
  ) async {
    final respuesta = await _dio.get<List<int>>(
      '/estadisticas/ranking/${query.type.apiValue}/csv',
      queryParameters: {
        'dias': query.days,
        'q': query.search,
        'orden': query.order,
        'direccion': query.direction,
        if (query.currencyId != null) 'moneda_id': query.currencyId,
      },
      options: Options(responseType: ResponseType.bytes),
    );
    final disposition = respuesta.headers.value('content-disposition') ?? '';
    final match = RegExp(
      r'''filename="?([^";]+)"?''',
      caseSensitive: false,
    ).firstMatch(disposition);
    final data = respuesta.data ?? const <int>[];
    return StatisticsRankingCsv(
      bytes: data is Uint8List ? data : Uint8List.fromList(data),
      fileName:
          match?.group(1) ??
          'estadisticas-${query.type.apiValue}-${query.days}-dias.csv',
      rows: int.tryParse(respuesta.headers.value('x-exported-rows') ?? '') ?? 0,
    );
  }
}
