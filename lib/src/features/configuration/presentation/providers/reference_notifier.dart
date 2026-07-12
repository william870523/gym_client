import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/reference_model.dart';
import '../../data/repositories/reference_repository.dart';

part 'reference_notifier.g.dart';

@riverpod
class ReferenceNotifier extends _$ReferenceNotifier {
  @override
  Future<List<ReferenceModel>> build() async {
    return _fetchReferences();
  }

  Future<List<ReferenceModel>> _fetchReferences() async {
    final repository = ref.read(referenceRepositoryProvider);
    return repository.getReferences();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchReferences());
  }

  Future<void> create(String name) async {
    final repository = ref.read(referenceRepositoryProvider);
    await repository.createReference({'nombre_referencia': name});
    await refresh();
  }

  Future<void> updateReference(String id, String name) async {
    final repository = ref.read(referenceRepositoryProvider);
    await repository.updateReference(id, {'nombre_referencia': name});
    await refresh();
  }

  Future<void> deleteReference(String id) async {
    final repository = ref.read(referenceRepositoryProvider);
    await repository.deleteReference(id);
    await refresh();
  }
}
