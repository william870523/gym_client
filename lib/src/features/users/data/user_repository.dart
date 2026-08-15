import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/network/api_client.dart';
import '../../auth/domain/models/user.dart';

part 'user_repository.g.dart';

class UserSiteAssignment {
  const UserSiteAssignment({
    required this.id,
    required this.userId,
    required this.gymId,
    required this.role,
    required this.active,
  });

  final String id;
  final String userId;
  final String gymId;
  final String role;
  final bool active;

  factory UserSiteAssignment.fromJson(Map<String, dynamic> json) {
    return UserSiteAssignment(
      id: (json['usuario_sede_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      gymId: (json['gym_id'] ?? '').toString(),
      role: (json['rol'] ?? '').toString(),
      active: json['activo'] != false,
    );
  }
}

/// Contrato de escritura del API de usuarios. Las proyecciones de lectura y,
/// sobre todo, `password: null` no deben viajar: Zod distingue entre un campo
/// omitido y uno presente con null, y el segundo invalida una edición normal.
Map<String, dynamic> userMutationPayload(User user) => {
  'user_nombre': user.name,
  'user_email': user.email,
  'role': user.role,
  'active': user.active,
  if (user.password != null) 'password': user.password,
};

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
      if (kDebugMode) {
        debugPrint('Error fetching users: $e');
      }
      rethrow;
    }
  }

  Future<void> createUser(User user) async {
    try {
      await _client.post('/users', data: userMutationPayload(user));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error creating user: $e');
      }
      rethrow;
    }
  }

  Future<void> updateUser(User user) async {
    try {
      await _client.put('/users/${user.id}', data: userMutationPayload(user));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating user: $e');
      }
      rethrow;
    }
  }

  Future<void> deleteUser(String id) async {
    try {
      await _client.delete('/users/$id');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting user: $e');
      }
      rethrow;
    }
  }

  Future<List<UserSiteAssignment>> getUserSites(String userId) async {
    final response = await _client.get<List<dynamic>>('/users/$userId/sedes');
    return (response.data ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              UserSiteAssignment.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<void> putUserSite(String userId, String gymId, String role) async {
    await _client.put('/users/$userId/sedes/$gymId', data: {'rol': role});
  }

  Future<void> deleteUserSite(String userId, String gymId) async {
    await _client.delete('/users/$userId/sedes/$gymId');
  }
}
