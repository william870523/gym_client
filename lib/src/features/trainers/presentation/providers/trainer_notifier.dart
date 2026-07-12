import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/trainer_model.dart';
import '../../data/repositories/trainer_repository.dart';

part 'trainer_notifier.g.dart';

@riverpod
class TrainerNotifier extends _$TrainerNotifier {
  @override
  FutureOr<List<TrainerModel>> build() {
    return ref.watch(trainerRepositoryProvider).getTrainers();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(trainerRepositoryProvider).getTrainers(),
    );
  }

  Future<void> createTrainer(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(trainerRepositoryProvider).createTrainer(data);
      return ref.read(trainerRepositoryProvider).getTrainers();
    });
  }

  Future<void> updateTrainer(String id, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(trainerRepositoryProvider).updateTrainer(id, data);
      return ref.read(trainerRepositoryProvider).getTrainers();
    });
  }

  Future<void> deleteTrainer(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(trainerRepositoryProvider).deleteTrainer(id);
      return ref.read(trainerRepositoryProvider).getTrainers();
    });
  }
}
