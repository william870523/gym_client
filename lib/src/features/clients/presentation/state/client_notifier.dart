import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/client_model.dart';
import '../../data/repositories/client_repository.dart';

final clientNotifierProvider =
    AsyncNotifierProvider<ClientNotifier, List<ClientModel>>(() {
      return ClientNotifier();
    });

class ClientNotifier extends AsyncNotifier<List<ClientModel>> {
  @override
  Future<List<ClientModel>> build() async {
    return ref.watch(clientRepositoryProvider).getClients(page: 1, limit: 2000);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(clientRepositoryProvider).getClients(page: 1, limit: 2000),
    );
  }

  Future<ClientModel> createClient(ClientModel client) async {
    final prevState = state;
    try {
      final created = await ref
          .read(clientRepositoryProvider)
          .createClient(client);
      await refresh();
      return created;
    } catch (e) {
      state = prevState;
      rethrow;
    }
  }

  Future<ClientModel> updateClient(ClientModel client) async {
    try {
      final updated = await ref
          .read(clientRepositoryProvider)
          .updateClient(client);
      await refresh();
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteClient(String ci) async {
    try {
      await ref.read(clientRepositoryProvider).deleteClient(ci);
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addWeight(String ci, double weight, DateTime date) async {
    try {
      await ref.read(clientRepositoryProvider).addWeight(ci, weight, date);
      await refresh();
    } catch (e) {
      rethrow;
    }
  }
}
