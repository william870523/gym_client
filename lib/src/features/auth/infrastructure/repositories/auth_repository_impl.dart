import 'package:dio/dio.dart';
// ignore: invalid_use_of_internal_member
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/models/user.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_repository_impl.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  return AuthRepositoryImpl(client);
}

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._client);

  final Dio _client;

  @override
  Future<User> login(String email, String password) async {
    try {
      _client.options.headers.remove('Authorization');
      final response = await _client.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      final data = response.data ?? {};
      final token = data['token'] as String?;

      if (token == null || token.isEmpty) {
        throw Exception('No se recibió token');
      }

      // Persist token on client for subsequent requests
      _client.options.headers['Authorization'] = 'Bearer $token';

      return User(
        id: (data['user_id'] ?? data['id'] ?? '').toString(),
        name: (data['name'] ?? email.split('@')[0]) as String,
        email: (data['email'] ?? email) as String,
        role: (data['role'] ?? 'reception') as String,
        status: (data['status'] ?? 'active') as String,
        imageUrl: data['imageUrl'] as String?,
        token: token,
      );
    } on DioException catch (e) {
      String? errorCode;
      int? retryAfterSeconds;
      String? message;

      final data = e.response?.data;
      if (data is Map) {
        final code = data['error_code'];
        errorCode = code != null ? code.toString() : null;
        final retryAfter = data['retry_after_seconds'];
        retryAfterSeconds =
            retryAfter is int ? retryAfter : int.tryParse('$retryAfter');
        message = data['error']?.toString();
      }

      if (errorCode != null && errorCode.isNotEmpty) {
        final suffix =
            retryAfterSeconds != null ? ':$retryAfterSeconds' : '';
        throw Exception('error_code:$errorCode$suffix');
      }

      final fallbackMessage = message ?? e.message ?? 'Error de red';
      throw Exception(fallbackMessage);
    }
  }

  @override
  Future<void> logout() async {
    _client.options.headers.remove('Authorization');
  }

  @override
  Future<User?> getCurrentUser() async {
    // TODO: Implementar /auth/me cuando esté disponible
    return null;
  }
}
