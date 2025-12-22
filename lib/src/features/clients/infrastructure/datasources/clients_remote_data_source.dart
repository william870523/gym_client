import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/models/client.dart';

part 'clients_remote_data_source.g.dart';

@Riverpod(keepAlive: true)
ClientsRemoteDataSource clientsRemoteDataSource(ClientsRemoteDataSourceRef ref) {
  return ClientsRemoteDataSource(ref.watch(apiClientProvider));
}

class ClientsRemoteDataSource {
  final Dio _dio;

  ClientsRemoteDataSource(this._dio);

  Future<List<Client>> fetchClients() async {
    final response = await _dio.get('/clients'); 
    // Assuming API returns List<Client> directly or { data: [] }
    // Adjust based on actual API response structure
    return (response.data as List)
        .map((e) => Client.fromJson(e))
        .toList();
  }

  Future<Client?> fetchClientById(String id) async {
    final response = await _dio.get('/clients/$id');
    return Client.fromJson(response.data);
  }
}
