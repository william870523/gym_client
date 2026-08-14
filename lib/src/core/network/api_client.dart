import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/auth/presentation/state/auth_notifier.dart';
import '../../features/auth/presentation/state/sede_session_provider.dart';
import '../config/env.dart';

part 'api_client.g.dart';

final _apiLogger = Logger(printer: SimplePrinter(colors: false));

/// Cliente HTTP **atado a la sede activa**.
///
/// Observar aquí la sede no es un detalle: es la palanca que hace que cambiar
/// de sede tire TODOS los datos cacheados (docs/MULTI_SEDE.md §3.4 y §7). Como
/// cada repositorio observa este proveedor, y cada vista observa su repositorio,
/// al cambiar la sede se reconstruye la cadena entera y no sobrevive nada de la
/// sede anterior.
///
/// Por eso ningún repositorio debe usar `ref.read(apiClientProvider)`: leer sin
/// observar rompe la cadena en silencio y esa vista seguiría enseñando los
/// socios de la sede que se acaba de abandonar. Lo vigila
/// `test/core/network/api_client_dependency_test.dart`.
@Riverpod(keepAlive: true)
Dio apiClient(Ref ref) {
  // Sede activa (docs/MULTI_SEDE.md §3.3). El `gym_id` nunca viaja en el
  // cuerpo: el servidor comprueba que esta cuenta pueda trabajar en la sede
  // pedida y deriva de ahí el ámbito.
  final gymId = ref.watch(sedeSessionProvider)?.gymId;
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

        // La sede se fija al construir el cliente, no por petición: así una
        // respuesta en vuelo no puede aterrizar con la cabecera de la sede
        // nueva sobre datos pedidos para la vieja. Sin sede conocida no se
        // manda nada y el servidor usa la sede por defecto de la cuenta.
        if (gymId != null && gymId.isNotEmpty) {
          options.headers['X-Gym-Id'] = gymId;
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
          final serverDetail = serverErrorDetail(e.response?.data);
          _apiLogger.w(
            '[API] ${e.response?.statusCode ?? 'ERR'} ${e.requestOptions.path}: '
            '${serverDetail ?? e.message}',
          );
        }
        return handler.next(e);
      },
    ),
  );

  return dio;
}

/// Lo que el servidor dijo al rechazar, o `null` si no dijo nada.
///
/// Público a propósito: el registro de depuración no puede ser el único sitio
/// donde se lea el motivo. Los rechazos de negocio —«Desde la ficha no se
/// cambia el entrenador asignado…»— tienen que llegar a la pantalla con estas
/// mismas reglas, y una segunda idea de «qué dijo el servidor» se desincroniza
/// de esta el día que una API conteste `message` en vez de `error`.
String? serverErrorDetail(dynamic data) {
  if (data is Map) {
    final detail = data['error'] ?? data['message'] ?? data['detail'];
    if (detail != null && detail.toString().trim().isNotEmpty) {
      return detail.toString().trim();
    }
  }
  if (data is String && data.trim().isNotEmpty) return data.trim();
  return null;
}
