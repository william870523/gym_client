import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/auth/presentation/state/auth_notifier.dart';
import '../config/env.dart';

part 'api_client.g.dart';

final _apiLogger = Logger(printer: SimplePrinter(colors: false));

@Riverpod(keepAlive: true)
Dio apiClient(Ref ref) {
  final options = BaseOptions(
    baseUrl: Env.baseUrl,
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
  );

  final dio = Dio(options);
  if (kDebugMode) {
    _apiLogger.d('[API] Base URL: ${options.baseUrl}');
  }

  // Add Interceptors
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (kDebugMode) {
          _apiLogger.d('[API] ${options.method} ${options.path}');
        }

        // Inject Token if available
        final authState = ref.read(authProvider);
        final token = authState.value?.token;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        return handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          _apiLogger.d(
            '[API] ${response.statusCode} ${response.requestOptions.path}',
          );
        }
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        if (kDebugMode) {
          _apiLogger.w(
            '[API] ${e.response?.statusCode ?? 'ERR'} ${e.requestOptions.path}: ${e.message}',
          );
        }
        return handler.next(e);
      },
    ),
  );

  return dio;
}
