import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../config/env.dart';

part 'api_client.g.dart';

@Riverpod(keepAlive: true)
Dio apiClient(Ref ref) {
  final options = BaseOptions(
    baseUrl: Env.baseUrl,
    connectTimeout: const Duration(milliseconds: Env.connectTimeout),
    receiveTimeout: const Duration(milliseconds: Env.receiveTimeout),
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
  );

  final dio = Dio(options);
  print('?? [API_CLIENT] Base URL: ${options.baseUrl}');

  // Add Interceptors
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        print('?? [REQ] ${options.method} ${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('? [RES] ${response.statusCode} ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        print('? [ERR] ${e.message} @ ${e.requestOptions.path}');
        return handler.next(e);
      },
    ),
  );

  return dio;
}
