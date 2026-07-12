import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/network/api_client.dart';
import '../models/trainer_model.dart';

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
}

@riverpod
TrainerRepository trainerRepository(Ref ref) {
  final dio = ref.watch(apiClientProvider);
  return TrainerRepository(dio);
}
