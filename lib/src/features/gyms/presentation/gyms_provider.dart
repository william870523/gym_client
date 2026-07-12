import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_client/src/core/network/api_client.dart';
import '../data/gym_repository.dart';
import '../domain/models/gym.dart';

// Repository Provider
final gymRepositoryProvider = Provider<GymRepository>((ref) {
  return GymRepository(ref.watch(apiClientProvider));
});

// List Provider
final gymsListProvider = FutureProvider.autoDispose<List<Gym>>((ref) async {
  final repo = ref.watch(gymRepositoryProvider);
  return repo.getGyms();
});

// Controller Provider
final gymsControllerProvider = AsyncNotifierProvider<GymsController, void>(
  GymsController.new,
);

class GymsController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // No initial state beyond void/null as this controller manages actions
    return null;
  }

  Future<void> createGym(Gym gym) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(gymRepositoryProvider);
      await repo.createGym(gym);
      ref.invalidate(gymsListProvider);
    });
  }

  Future<void> updateGym(Gym gym) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(gymRepositoryProvider);
      await repo.updateGym(gym);
      ref.invalidate(gymsListProvider);
    });
  }

  Future<void> deleteGym(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(gymRepositoryProvider);
      await repo.deleteGym(id);
      ref.invalidate(gymsListProvider);
    });
  }
}
