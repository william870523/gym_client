import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/api_client.dart';
import '../models/client_model.dart';
import '../models/client_record_model.dart';

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepository(ref.watch(apiClientProvider));
});

class ClientRepository {
  final Dio _dio;

  ClientRepository(this._dio);

  Future<List<ClientModel>> getClients({int page = 1, int limit = 10}) async {
    try {
      final response = await _dio.get(
        '/clientes',
        queryParameters: {'page': page, 'limit': limit},
      );
      final List data = response.data as List;
      return data.map((e) => ClientModel.fromJson(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<ClientModel> getClient(String ci) async {
    try {
      final response = await _dio.get('/clientes/$ci');
      return ClientModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<ClientRecordModel> getClientRecord(String ci) async {
    if (ci.trim().isEmpty) {
      throw const FormatException('La cédula del cliente es obligatoria.');
    }
    final response = await _dio.get('/clientes/$ci/expediente');
    return ClientRecordModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> pauseMembership({
    required String clientId,
    required String membershipId,
    required String reason,
  }) async {
    final operationId = const Uuid().v4();
    await _dio.post(
      '/clientes/$clientId/membresias/$membershipId/pausar',
      data: {'operation_id': operationId, 'motivo': reason.trim()},
    );
  }

  /// R5.4 — bandeja de avisos informativos para administración.
  Future<List<Map<String, dynamic>>> getAdminNotices({
    bool incluirLeidos = true,
  }) async {
    final response = await _dio.get(
      '/avisos-administracion',
      queryParameters: {if (incluirLeidos) 'leidos': 'todos'},
    );
    return (response.data as List)
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }

  /// R5.4 — marca como leídos todos los avisos pendientes (o los indicados).
  Future<int> markAdminNoticesRead({List<String>? avisoIds}) async {
    final response = await _dio.post(
      '/avisos-administracion/leer',
      data: {'aviso_ids': avisoIds ?? const []},
    );
    return (response.data is Map ? response.data['marcados'] : null) as int? ??
        0;
  }

  /// R5.4 — cambio de entrenador a petición del cliente (sin aprobación
  /// previa). `newTrainerId` nulo deja la membresía sin entrenador.
  Future<Map<String, dynamic>> changeMembershipTrainer({
    required String membershipId,
    String? newTrainerId,
    String? reason,
  }) async {
    try {
      final response = await _dio.post(
        '/membresias/$membershipId/cambiar-entrenador',
        data: {
          'nuevo_entrenador_id': newTrainerId,
          'motivo': reason?.trim().isNotEmpty == true ? reason!.trim() : null,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      final detail = e.response?.data is Map
          ? (e.response!.data as Map)['error']?.toString()
          : null;
      throw Exception(
        detail?.trim().isNotEmpty == true
            ? detail!.trim()
            : 'No se pudo cambiar el entrenador (${e.response?.statusCode ?? 'sin respuesta'}).',
      );
    }
  }

  Future<void> resumeMembership({
    required String clientId,
    required String membershipId,
  }) async {
    final operationId = const Uuid().v4();
    await _dio.post(
      '/clientes/$clientId/membresias/$membershipId/reanudar',
      data: {'operation_id': operationId},
    );
  }

  Future<void> requestMembershipAction({
    required String clientId,
    required String membershipId,
    required String kind,
    required String reason,
  }) async {
    await _dio.post(
      '/membresias/solicitudes',
      data: {
        'operation_id': const Uuid().v4(),
        'ci': clientId,
        'membresia_id': membershipId,
        'tipo': kind,
        'motivo': reason.trim(),
      },
    );
  }

  Future<List<ClientMembershipRequest>> getMembershipRequests({
    String? state,
  }) async {
    final response = await _dio.get(
      '/membresias/solicitudes',
      queryParameters: state == null ? null : {'estado': state},
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    final items = body['data'] is List ? body['data'] as List : const [];
    return items
        .map(
          (item) => ClientMembershipRequest.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> approveMembershipRequest(
    String requestId, {
    String? note,
  }) async {
    await _dio.post(
      '/membresias/solicitudes/$requestId/aprobar',
      data: {
        'operation_id': const Uuid().v4(),
        if (note?.trim().isNotEmpty == true) 'motivo': note!.trim(),
      },
    );
  }

  Future<void> rejectMembershipRequest({
    required String requestId,
    required String reason,
  }) async {
    await _dio.post(
      '/membresias/solicitudes/$requestId/rechazar',
      data: {'operation_id': const Uuid().v4(), 'motivo': reason.trim()},
    );
  }

  Future<ClientModel> createClient(ClientModel client) async {
    try {
      // API expects 'ci' as ID.
      // Ensure the model is converted properly.
      final data = clientWritePayload(client);
      final response = await _dio.post('/clientes', data: data);
      return ClientModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<ClientModel> updateClient(ClientModel client) async {
    if (client.id.isEmpty) {
      throw Exception('Client ID cannot be empty');
    }
    try {
      final data = clientWritePayload(client);
      await _dio.put('/clientes/${client.id}', data: data);
      return getClient(client.id);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteClient(String ci) async {
    try {
      await _dio.delete('/clientes/$ci');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addWeight(String ci, double weight, DateTime date) async {
    try {
      await _dio.post(
        '/cliente-pesos',
        data: {
          'ci': ci,
          'peso': weight,
          'fecha': date.toIso8601String(),
          // Default required fields
          'fecha_inicio': date.toIso8601String(),
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getWeights(String ci) async {
    if (ci.isEmpty) {
      return [];
    }
    try {
      final response = await _dio.get(
        '/cliente-pesos',
        queryParameters: {'ci': ci},
      );
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      rethrow;
    }
  }
}

Map<String, dynamic> clientWritePayload(ClientModel client) {
  final data = client.toJson();
  data.remove('peso');
  // Proyecciones devueltas por la API. No son campos editables de Cliente.
  data.remove('membresia_id');
  data.remove('membresia_estado');
  return data;
}
