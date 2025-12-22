import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/network/api_client.dart';
import '../../auth/domain/models/user.dart';

part 'user_repository.g.dart';

@Riverpod(keepAlive: true)
UserRepository userRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  return UserRepository(client);
}

class UserRepository {
  final Dio _client;

  UserRepository(this._client);

  Future<List<User>> getUsers({
    String? query,
    String? role,
    String? status,
  }) async {
    try {
      final response = await _client.get(
        '/users',
        queryParameters: {
          if (query != null && query.isNotEmpty) 'q': query,
          if (role != null && role.isNotEmpty) 'role': role,
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );

      final List<dynamic> list = response.data is List ? response.data : [];
      return list.map((json) => User.fromJson(json)).toList();
    } catch (e) {
      // Return empty list on error for now or rethrow
      print('Error fetching users: $e');
      rethrow;
    }
  }

  Future<void> createUser(User user) async {
    try {
      await _client.post('/users', data: user.toJson());
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  Future<void> updateUser(User user) async {
    try {
      await _client.put('/users/${user.id}', data: user.toJson());
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(String id) async {
    try {
      await _client.delete('/users/$id');
    } catch (e) {
      print('Error deleting user: $e');
      rethrow;
    }
  }
}
