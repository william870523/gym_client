import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/network/api_client.dart';
import '../models/trainer_model.dart';
import '../models/trainer_offboarding_impact.dart';
import '../models/trainer_offboarding_case.dart';
import '../models/trainer_offboarding_financial.dart';
import '../models/trainer_final_settlement.dart';
import 'package:uuid/uuid.dart';

part 'trainer_repository.g.dart';

class TrainerRepository {
  final Dio _dio;

  TrainerRepository(this._dio);

  String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString();
  }

  String? _asNullableString(dynamic value) {
    if (value == null) return null;
    final result = value.toString();
    return result.isNotEmpty ? result : null;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  bool _asBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      if (value == 'true') return true;
      if (value == 'false') return false;
    }
    return fallback;
  }

  DateTime _asDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  String? _asBase64(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List) {
      final bytes = value
          .whereType<num>()
          .map((num item) => item.toInt())
          .toList();
      if (bytes.isNotEmpty) return base64Encode(bytes);
    }
    if (value is Map) {
      final data = value['data'];
      if (data is List) {
        final bytes = data
            .whereType<num>()
            .map((num item) => item.toInt())
            .toList();
        if (bytes.isNotEmpty) return base64Encode(bytes);
      }
    }
    return null;
  }

  TrainerModel? _parseTrainer(dynamic item) {
    if (item is! Map<String, dynamic>) return null;

    final id = _asString(item['id_entrenador']).trim();
    if (id.isEmpty) return null;

    final sexo = _asString(item['sexo_entrenador'], fallback: 'M').trim();
    final sexoValue = sexo == 'F' || sexo == 'M' ? sexo : 'M';

    return TrainerModel(
      id: id,
      ci: _asString(item['ci_entrenador']).trim(),
      nombres: _asString(item['nombres_entrenador']).trim(),
      apellidos: _asString(item['apellidos_entrenador']).trim(),
      sexo: sexoValue,
      foto: _asBase64(item['foto_entrenador']),
      direccion: _asNullableString(item['direccion_entrenador']),
      telefono: _asInt(item['telefono_entrenador']),
      correo: _asNullableString(item['correo_entrenador']),
      activo: _asBool(item['activo_entrenador']),
      fechaInicio: _asDate(item['fecha_incio_entrenador']),
      version: _asInt(item['version']),
      gymId: _asNullableString(item['gym_id']),
      isDeleted: item['is_deleted'] == true,
    );
  }

  TrainerModel _fallbackTrainerFromPayload(
    Map<String, dynamic> payload, {
    String? idOverride,
  }) {
    final rawId = (idOverride ?? _asString(payload['id_entrenador'])).trim();
    final id = rawId.isNotEmpty
        ? rawId
        : 'temp-${DateTime.now().millisecondsSinceEpoch}';

    final sexo = _asString(payload['sexo_entrenador'], fallback: 'M').trim();
    final sexoValue = sexo == 'F' || sexo == 'M' ? sexo : 'M';

    return TrainerModel(
      id: id,
      ci: _asString(payload['ci_entrenador']).trim(),
      nombres: _asString(payload['nombres_entrenador']).trim(),
      apellidos: _asString(payload['apellidos_entrenador']).trim(),
      sexo: sexoValue,
      foto: _asBase64(payload['foto_entrenador']),
      direccion: _asNullableString(payload['direccion_entrenador']),
      telefono: _asInt(payload['telefono_entrenador']),
      correo: _asNullableString(payload['correo_entrenador']),
      activo: _asBool(payload['activo_entrenador']),
      fechaInicio: _asDate(payload['fecha_incio_entrenador']),
      version: _asInt(payload['version']),
      gymId: _asNullableString(payload['gym_id']),
      isDeleted: payload['is_deleted'] == true,
    );
  }

  Future<List<TrainerModel>> getTrainers() async {
    try {
      final response = await _dio.get('/entrenadores');
      final data = response.data;
      if (data is! List) return [];
      return data.map(_parseTrainer).whereType<TrainerModel>().toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<TrainerModel> createTrainer(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/entrenadores', data: data);
      final responseData = response.data;
      if (responseData is Map && responseData.containsKey('error')) {
        throw Exception(responseData['error']);
      }
      if (responseData is Map<String, dynamic>) {
        final parsed = _parseTrainer(responseData);
        if (parsed != null) return parsed;
      }
      return _fallbackTrainerFromPayload(data);
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('error')) {
          throw Exception(data['error']);
        }
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<TrainerModel> updateTrainer(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.put('/entrenadores/$id', data: data);
      final responseData = response.data;
      if (responseData is Map && responseData.containsKey('error')) {
        throw Exception(responseData['error']);
      }
      if (responseData is Map<String, dynamic>) {
        final parsed = _parseTrainer(responseData);
        if (parsed != null) return parsed;
      }
      return _fallbackTrainerFromPayload(data, idOverride: id);
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('error')) {
          throw Exception(data['error']);
        }
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteTrainer(String id) async {
    try {
      await _dio.delete('/entrenadores/$id');
    } catch (e) {
      rethrow;
    }
  }

  Future<TrainerOffboardingImpact> getOffboardingImpact(String id) async {
    final response = await _dio.get('/entrenadores/$id/offboarding-impact');
    return TrainerOffboardingImpact.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TrainerOffboardingCase?> getOpenOffboardingCase(
    String trainerId,
  ) async {
    final response = await _dio.get(
      '/entrenadores/$trainerId/offboarding-case',
    );
    final data = response.data;
    if (data is Map && data['data'] == null) return null;
    return TrainerOffboardingCase.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<TrainerOffboardingCase> createOffboardingCase({
    required String trainerId,
    required String effectiveDate,
    required String reason,
  }) async {
    final response = await _dio.post(
      '/entrenadores/$trainerId/offboarding-cases',
      data: {'fecha_efectiva': effectiveDate, 'motivo': reason},
    );
    return TrainerOffboardingCase.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TrainerOffboardingCase> updateOffboardingDecision({
    required String trainerId,
    required String caseId,
    required String membershipId,
    required String type,
    String? targetTrainerId,
    String? reason,
  }) async {
    final response = await _dio.patch(
      '/entrenadores/$trainerId/offboarding-cases/$caseId/decisions/$membershipId',
      data: {
        'operation_id': const Uuid().v4(),
        'tipo': type,
        'id_entrenador_destino': targetTrainerId,
        'motivo': reason,
      },
    );
    return TrainerOffboardingCase.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TrainerOffboardingCase> executeOffboardingCase({
    required String trainerId,
    required String caseId,
    required String operationId,
  }) async {
    final response = await _dio.post(
      '/entrenadores/$trainerId/offboarding-cases/$caseId/execute',
      data: {'operation_id': operationId},
    );
    return TrainerOffboardingCase.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TrainerOffboardingFinancialPreview> previewOffboardingFinancial({
    required String trainerId,
    required String caseId,
    required String membershipId,
    String? type,
    String? destinationPlanId,
  }) async {
    final response = await _dio.get(
      '/entrenadores/$trainerId/offboarding-cases/$caseId/decisions/$membershipId/financial-preview',
      queryParameters: {
        if (type != null) 'tipo': type,
        if (destinationPlanId != null) 'plan_destino_id': destinationPlanId,
      },
    );
    return TrainerOffboardingFinancialPreview.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TrainerOffboardingCase> resolveOffboardingFinancial({
    required String trainerId,
    required String caseId,
    required String membershipId,
    required String type,
    String? destinationPlanId,
    String? targetTrainerId,
    required String reason,
  }) async {
    final response = await _dio.post(
      '/entrenadores/$trainerId/offboarding-cases/$caseId/decisions/$membershipId/financial-resolution',
      data: {
        'operation_id': const Uuid().v4(),
        'tipo': type,
        'plan_destino_id': destinationPlanId,
        'id_entrenador_destino': targetTrainerId,
        'motivo': reason,
      },
    );
    return TrainerOffboardingCase.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TrainerFinalSettlementPreview> previewFinalSettlement({
    required String trainerId,
    required String caseId,
  }) async {
    final response = await _dio.get(
      '/entrenadores/$trainerId/offboarding-cases/$caseId/final-settlement',
    );
    return TrainerFinalSettlementPreview.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TrainerFinalSettlementResult> createFinalSettlement({
    required String trainerId,
    required String caseId,
    required String currencyId,
    required String accountId,
    required String paymentTypeId,
    String? notes,
  }) async {
    final response = await _dio.post(
      '/entrenadores/$trainerId/offboarding-cases/$caseId/final-settlement',
      data: {
        'operacion_id': const Uuid().v4(),
        'moneda_id': currencyId,
        'cuenta_id': accountId,
        'tipo_pago_id': paymentTypeId,
        'notas': notes,
      },
    );
    return TrainerFinalSettlementResult.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TrainerFinalSettlementResult> closeFinalSettlement({
    required String trainerId,
    required String caseId,
  }) async {
    final response = await _dio.post(
      '/entrenadores/$trainerId/offboarding-cases/$caseId/final-settlement/close',
      data: {'operacion_id': const Uuid().v4()},
    );
    return TrainerFinalSettlementResult.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}

@riverpod
TrainerRepository trainerRepository(Ref ref) {
  final dio = ref.watch(apiClientProvider);
  return TrainerRepository(dio);
}
