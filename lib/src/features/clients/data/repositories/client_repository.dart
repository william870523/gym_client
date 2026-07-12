import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../models/client_model.dart';

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

  Future<ClientModel> createClient(ClientModel client) async {
    try {
      // API expects 'ci' as ID.
      // Ensure the model is converted properly.
      final data = client.toJson();
      data.remove('peso');
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
      final data = client.toJson();
      data.remove('peso');
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
