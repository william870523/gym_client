import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/models/client.dart';
import '../../infrastructure/repositories/clients_repository_impl.dart';

part 'clients_providers.g.dart';

// Use Case: Get Clients
@riverpod
Future<List<Client>> getClients(Ref ref) async {
  final repository = ref.watch(clientsRepositoryProvider);
  return repository.getClients();
}

// Controller / Notifier could go here if more complex state needed
