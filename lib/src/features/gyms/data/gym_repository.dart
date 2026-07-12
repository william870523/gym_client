import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_client/src/core/network/api_client.dart';
import '../domain/models/gym.dart';

final gymRepositoryProvider = Provider<GymRepository>((ref) {
  return GymRepository(ref.watch(apiClientProvider));
});

class GymRepository {
  final Dio _dio;

  GymRepository(this._dio);

  Future<List<Gym>> getGyms() async {
    try {
      final response = await _dio.get('/gyms'); // Assuming all gyms endpoint
      final List data = response.data as List;
      return data.map((e) => Gym.fromJson(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Gym> getGym(String id) async {
    try {
      final response = await _dio.get('/gyms/$id');
      return Gym.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Gym> createGym(Gym gym) async {
    try {
      final response = await _dio.post('/gyms', data: gym.toJson());
      return Gym.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Gym> updateGym(Gym gym) async {
    try {
      final response = await _dio.put('/gyms/${gym.id}', data: gym.toJson());
      return Gym.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteGym(String id) async {
    try {
      await _dio.delete('/gyms/$id');
    } catch (e) {
      rethrow;
    }
  }
}
