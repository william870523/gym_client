import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/network/api_client.dart';
import '../models/reference_model.dart';

part 'reference_repository.g.dart';

class ReferenceRepository {
  final Dio _client;

  ReferenceRepository(this._client);

  Future<List<ReferenceModel>> getReferences() async {
    try {
      final response = await _client.get('/referencias');
      return (response.data as List)
          .map((e) => ReferenceModel.fromJson(e))
          .toList();
    } catch (e) {
      throw Exception('Failed to load references: $e');
    }
  }

  Future<ReferenceModel> createReference(Map<String, dynamic> data) async {
    try {
      final response = await _client.post('/referencias', data: data);
      return ReferenceModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create reference: $e');
    }
  }

  Future<void> updateReference(String id, Map<String, dynamic> data) async {
    try {
      await _client.put('/referencias/$id', data: data);
    } catch (e) {
      throw Exception('Failed to update reference: $e');
    }
  }

  Future<void> deleteReference(String id) async {
    try {
      await _client.delete('/referencias/$id');
    } catch (e) {
      throw Exception('Failed to delete reference: $e');
    }
  }
}

@riverpod
ReferenceRepository referenceRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  return ReferenceRepository(client);
}
