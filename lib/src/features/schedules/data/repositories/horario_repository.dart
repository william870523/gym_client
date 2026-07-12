import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../models/horario_model.dart';

final horarioRepositoryProvider = Provider<HorarioRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return HorarioRepository(dio);
});

class HorarioRepository {
  final Dio _dio;

  HorarioRepository(this._dio);

  Future<List<HorarioModel>> getAll() async {
    try {
      final response = await _dio.get('/horarios');
      final List<dynamic> data = response.data;
      return data.map((json) => HorarioModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error al obtener horarios: $e');
    }
  }

  Future<HorarioModel> getById(String id) async {
    final response = await _dio.get('/horarios/$id');
    return HorarioModel.fromJson(response.data);
  }

  Future<HorarioModel> create(HorarioModel horario) async {
    final response = await _dio.post('/horarios', data: horario.toJson());
    return HorarioModel.fromJson(response.data);
  }

  Future<HorarioModel> updateHorario(HorarioModel horario) async {
    final response = await _dio.put(
      '/horarios/${horario.id}',
      data: horario.toJson(),
    );
    return HorarioModel.fromJson(response.data);
  }

  Future<void> delete(String id) async {
    await _dio.delete('/horarios/$id');
  }
}
