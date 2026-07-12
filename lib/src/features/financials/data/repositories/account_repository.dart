import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/network/api_client.dart';
import '../models/account_model.dart';

part 'account_repository.g.dart';

class AccountRepository {
  final Dio _client;

  AccountRepository(this._client);

  Future<List<AccountModel>> getAccounts() async {
    try {
      final response = await _client.get('/cuentas');
      return (response.data as List)
          .map((e) => AccountModel.fromJson(e))
          .toList();
    } catch (e) {
      throw Exception('Failed to load accounts: $e');
    }
  }

  Future<AccountModel> getAccount(String id) async {
    try {
      final response = await _client.get('/cuentas/$id');
      return AccountModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to load account: $e');
    }
  }

  Future<AccountModel> createAccount(Map<String, dynamic> data) async {
    try {
      final response = await _client.post('/cuentas', data: data);
      return AccountModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create account: $e');
    }
  }

  Future<void> updateAccount(String id, Map<String, dynamic> data) async {
    try {
      await _client.put('/cuentas/$id', data: data);
    } catch (e) {
      throw Exception('Failed to update account: $e');
    }
  }

  Future<void> deleteAccount(String id) async {
    try {
      await _client.delete('/cuentas/$id');
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }
}

@riverpod
AccountRepository accountRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  return AccountRepository(client);
}
