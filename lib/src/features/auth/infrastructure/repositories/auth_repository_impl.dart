import 'package:dio/dio.dart';
// ignore: invalid_use_of_internal_member
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/models/sede_session.dart';
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

      // El API local anida los datos en `user`:
      // { token, user: { id, username, role } }.
      // Se mantienen los campos de nivel superior como respaldo.
      final userMap = data['user'] is Map
          ? Map<String, dynamic>.from(data['user'] as Map)
          : <String, dynamic>{};

      return User(
        id: (userMap['id'] ?? data['user_id'] ?? data['id'] ?? '').toString(),
        name: (userMap['username'] ??
                userMap['name'] ??
                data['name'] ??
                email.split('@')[0])
            .toString(),
        email: (userMap['email'] ?? data['email'] ?? email).toString(),
        role: (userMap['role'] ?? data['role'] ?? 'reception').toString(),
        status:
            (userMap['status'] ?? data['status'] ?? 'active').toString(),
        imageUrl: (userMap['imageUrl'] ?? data['imageUrl']) as String?,
        token: token,
      );
    } on DioException catch (e) {
      String? errorCode;
      int? retryAfterSeconds;
      String? message;

      final data = e.response?.data;
      if (data is Map) {
        final code = data['error_code'];
        errorCode = code?.toString();
        final retryAfter = data['retry_after_seconds'];
        retryAfterSeconds = retryAfter is int
            ? retryAfter
            : int.tryParse('$retryAfter');
        message = data['error']?.toString();
      }

      if (errorCode != null && errorCode.isNotEmpty) {
        final suffix = retryAfterSeconds != null ? ':$retryAfterSeconds' : '';
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

  @override
  Future<SedeSession?> fetchSession() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/auth/session',
      );
      final data = response.data;
      if (data == null) return null;
      return SedeSession.fromJson(data);
    } on DioException {
      // Una instalación sin la ruta —o sin red en ese instante— no debe
      // impedir entrar: se trabaja sin sede declarada y el servidor sigue
      // decidiendo el ámbito por su cuenta.
      return null;
    }
  }
}
