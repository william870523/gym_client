import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../models/retention_models.dart';

final retentionRepositoryProvider = Provider<RetentionRepository>((ref) {
  return RetentionRepository(ref.watch(apiClientProvider));
});

class RetentionRepository {
  const RetentionRepository(this._dio);

  final Dio _dio;

  Future<RetentionDashboardModel> getDashboard({
    RetentionDashboardQuery query = const RetentionDashboardQuery(),
  }) async {
    final response = await _dio.get(
      '/retencion',
      queryParameters: query.toQueryParameters(),
    );
    return RetentionDashboardModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<RetentionSettingsModel> getSettings() async {
    final response = await _dio.get('/configuracion/retention');
    return RetentionSettingsModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<RetentionSettingsModel> updateSettings({
    required int graceDays,
    required int horizonDays,
  }) async {
    final response = await _dio.put(
      '/configuracion/retention',
      data: {'grace_days': graceDays, 'horizon_days': horizonDays},
    );
    return RetentionSettingsModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<RetentionManagementRecord>> getManagementHistory(
    String membershipId,
  ) async {
    final response = await _dio.get(
      '/retencion/$membershipId/gestiones',
      queryParameters: const {'limite': 100},
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return (body['data'] as List? ?? const [])
        .map(
          (item) => RetentionManagementRecord.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<RetentionManagementRecord> createManagement({
    required String membershipId,
    required String result,
    required String channel,
    String? note,
    String? promiseDate,
    String? nextManagementDate,
  }) async {
    final response = await _dio.post(
      '/retencion/gestiones',
      data: {
        'operation_id': const Uuid().v4(),
        'membresia_id': membershipId,
        'resultado': result,
        'canal': channel,
        'nota': note,
        'promesa_fecha': promiseDate,
        'proxima_gestion_fecha': nextManagementDate,
      },
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return RetentionManagementRecord.fromJson(
      Map<String, dynamic>.from(body['management'] as Map),
    );
  }
}
