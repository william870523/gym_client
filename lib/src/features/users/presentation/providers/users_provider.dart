import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../auth/domain/models/user.dart';
import '../../data/user_repository.dart';

part 'users_provider.g.dart';

@Riverpod(keepAlive: true)
class Users extends _$Users {
  @override
  FutureOr<List<User>> build() async {
    return _fetchUsers();
  }

  Future<List<User>> _fetchUsers({
    String? query,
    String? role,
    String? status,
  }) async {
    final repository = ref.read(userRepositoryProvider);
    return repository.getUsers(query: query, role: role, status: status);
  }

  Future<void> refresh({String? query, String? role, String? status}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetchUsers(query: query, role: role, status: status),
    );
  }

  Future<void> deleteUser(String id) async {
    final repository = ref.read(userRepositoryProvider);
    await repository.deleteUser(id);
    // Optimistic update or refresh
    ref.invalidateSelf();
  }

  Future<void> createUser(User user) async {
    final repository = ref.read(userRepositoryProvider);
    await repository.createUser(user);
    ref.invalidateSelf();
  }

  Future<void> updateUser(User user) async {
    final repository = ref.read(userRepositoryProvider);
    await repository.updateUser(user);
    ref.invalidateSelf();
  }

  Future<List<UserSiteAssignment>> getUserSites(String userId) {
    return ref.read(userRepositoryProvider).getUserSites(userId);
  }

  Future<void> replaceUserSites(
    User user,
    Map<String, String> desired,
  ) async {
    final repository = ref.read(userRepositoryProvider);
    final current = await repository.getUserSites(user.id);
    final currentByGym = {for (final item in current) item.gymId: item};

    for (final entry in desired.entries) {
      final existing = currentByGym[entry.key];
      if (existing == null || !existing.active || existing.role != entry.value) {
        await repository.putUserSite(user.id, entry.key, entry.value);
      }
    }
    for (final existing in current) {
      if (!desired.containsKey(existing.gymId) && existing.gymId != user.gymId) {
        await repository.deleteUserSite(user.id, existing.gymId);
      }
    }
    ref.invalidateSelf();
  }
}
