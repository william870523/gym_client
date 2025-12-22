import '../models/client.dart';

abstract class ClientsRepository {
  Future<List<Client>> getClients();
  Future<Client?> getClientById(String id);
  // Future<void> createClient(Client client);
}
