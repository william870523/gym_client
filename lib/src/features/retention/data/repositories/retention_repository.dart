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
    String? reasonId,
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
        'motivo_baja_id': reasonId,
        'promesa_fecha': promiseDate,
        'proxima_gestion_fecha': nextManagementDate,
      },
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return RetentionManagementRecord.fromJson(
      Map<String, dynamic>.from(body['management'] as Map),
    );
  }

  // --- Catálogo de motivos de baja (PLAN_ESTADISTICAS.md §7-ter) ---

  /// [onlyActive] pide solo los que deben ofrecerse en gestiones nuevas; la
  /// vista de catálogo los quiere todos, para poder reactivar los apagados.
  Future<List<DropoutReasonModel>> getDropoutReasons({
    bool onlyActive = false,
  }) async {
    final response = await _dio.get(
      '/motivos-baja',
      queryParameters: onlyActive ? const {'activos': 'true'} : null,
    );
    return (response.data as List? ?? const [])
        .map(
          (item) =>
              DropoutReasonModel.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<DropoutReasonModel> createDropoutReason({
    required String name,
    String? code,
    int order = 0,
    bool active = true,
  }) async {
    final response = await _dio.post(
      '/motivos-baja',
      data: {
        'nombre': name,
        'codigo': code,
        'orden': order,
        'activo': active,
      },
    );
    return DropoutReasonModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<DropoutReasonModel> updateDropoutReason({
    required String id,
    String? name,
    String? code,
    int? order,
    bool? active,
  }) async {
    final response = await _dio.put(
      '/motivos-baja/$id',
      data: {
        if (name != null) 'nombre': name,
        if (code != null) 'codigo': code,
        if (order != null) 'orden': order,
        if (active != null) 'activo': active,
      },
    );
    return DropoutReasonModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> deleteDropoutReason(String id) async {
    await _dio.delete('/motivos-baja/$id');
  }
}
