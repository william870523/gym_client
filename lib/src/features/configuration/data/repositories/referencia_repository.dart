import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../models/referencia_model.dart';

final referenciaRepositoryProvider = Provider<ReferenciaRepository>((ref) {
  return ReferenciaRepository(ref.watch(apiClientProvider));
});

class ReferenciaRepository {
  final Dio _dio;

  ReferenciaRepository(this._dio);

  Future<List<ReferenciaModel>> getReferencias() async {
    try {
      final response = await _dio.get('/referencias');
      return (response.data as List)
          .map((e) => ReferenciaModel.fromJson(e))
          .toList();
    } catch (e) {
      throw Exception('Error al cargar referencias: $e');
    }
  }
}
