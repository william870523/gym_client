import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/models/client.dart';
import '../../domain/repositories/clients_repository.dart';
import '../datasources/clients_remote_data_source.dart';

part 'clients_repository_impl.g.dart';

@Riverpod(keepAlive: true)
ClientsRepository clientsRepository(Ref ref) {
  return ClientsRepositoryImpl(ref.watch(clientsRemoteDataSourceProvider));
}

class ClientsRepositoryImpl implements ClientsRepository {
  final ClientsRemoteDataSource _remoteDataSource;

  ClientsRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<Client>> getClients() async {
    return _remoteDataSource.fetchClients();
  }

  @override
  Future<Client?> getClientById(String id) async {
    return _remoteDataSource.fetchClientById(id);
  }
}
