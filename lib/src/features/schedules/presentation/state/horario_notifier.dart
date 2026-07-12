import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/horario_model.dart';
import '../../data/repositories/horario_repository.dart';

final horarioNotifierProvider =
    AsyncNotifierProvider<HorarioNotifier, List<HorarioModel>>(
      HorarioNotifier.new,
    );

class HorarioNotifier extends AsyncNotifier<List<HorarioModel>> {
  @override
  Future<List<HorarioModel>> build() async {
    return _fetchHorarios();
  }

  Future<List<HorarioModel>> _fetchHorarios() async {
    final repository = ref.read(horarioRepositoryProvider);
    return repository.getAll();
  }

  Future<void> create({
    required String nombre,
    required int horaInicio,
    required int horaFin,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(horarioRepositoryProvider);
      final newHorario = HorarioModel(
        id: '',
        nombre: nombre,
        horaInicio: horaInicio,
        horaFin: horaFin,
      );
      await repository.create(newHorario);
      return _fetchHorarios();
    });
  }

  Future<void> updateHorario(HorarioModel horario) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(horarioRepositoryProvider);
      await repository.updateHorario(horario);
      return _fetchHorarios();
    });
  }

  Future<void> delete(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(horarioRepositoryProvider);
      await repository.delete(id);
      return _fetchHorarios();
    });
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchHorarios());
  }
}
