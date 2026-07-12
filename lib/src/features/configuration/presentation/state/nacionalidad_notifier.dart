import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/nacionalidad_model.dart';
import '../../data/repositories/nacionalidad_repository.dart';

class NacionalidadNotifier extends AsyncNotifier<List<NacionalidadModel>> {
  @override
  Future<List<NacionalidadModel>> build() async {
    return ref.watch(nacionalidadRepositoryProvider).getNacionalidades();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(nacionalidadRepositoryProvider).getNacionalidades(),
    );
  }

  Future<void> create(String name, String isoCode, Uint8List? flagBytes) async {
    final repo = ref.read(nacionalidadRepositoryProvider);
    final newNacionalidad = NacionalidadModel(
      id: const Uuid().v4(),
      name: name,
      isoCode: isoCode,
      flagImage: null, // Image handled via flagBytes
    );
    await repo.createNacionalidad(newNacionalidad, flagBytes: flagBytes);
    await refresh();
  }

  Future<void> updateNacionalidad(
    String id,
    String name,
    String isoCode,
    Uint8List? flagBytes,
  ) async {
    final repo = ref.read(nacionalidadRepositoryProvider);
    final updatedNacionalidad = NacionalidadModel(
      id: id,
      name: name,
      isoCode: isoCode,
      flagImage: null, // Image handled via flagBytes
    );
    await repo.updateNacionalidad(updatedNacionalidad, flagBytes: flagBytes);
    await refresh();
  }

  Future<void> delete(String id) async {
    await ref.read(nacionalidadRepositoryProvider).deleteNacionalidad(id);
    await refresh();
  }
}

final nacionalidadProvider =
    AsyncNotifierProvider<NacionalidadNotifier, List<NacionalidadModel>>(
      () => NacionalidadNotifier(),
    );
