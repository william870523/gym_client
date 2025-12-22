import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/models/gym.dart';

// Provider for the Gym Repository
final gymRepositoryProvider = Provider<GymRepository>((ref) {
  final dio = ref.read(apiClientProvider);
  return GymRepository(dio);
});

// Future Provider to fetch the list of gyms
final gymsListProvider = FutureProvider<List<Gym>>((ref) async {
  final repo = ref.read(gymRepositoryProvider);
  return repo.getGyms();
});

class GymRepository {
  final Dio _dio;
  GymRepository(this._dio);

  Future<List<Gym>> getGyms() async {
    try {
      final response = await _dio.get(
        '/gyms',
      ); // Calls our new remote endpoint (Local/Remote agnostic via base url)
      /* 
       Note: Local API does NOT have /gyms endpoint usually, 
       but if we are in Local mode, we probably don't need to fetch gyms (auto-assigned).
       But if we DO fetch, it will likely fail 404 or 403 unless we mock it.
       The UI logic will protect this call (only if kIsWeb).
      */

      final List data = response.data is List ? response.data : [];
      return data.map((e) => Gym.fromJson(e)).toList();
    } catch (e) {
      if (e is DioException && e.response?.statusCode != 200) {
        // Maybe log?
      }
      return []; // Return empty on error
    }
  }
}
