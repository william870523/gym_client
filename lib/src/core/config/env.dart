import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../window/window_manager.dart';

enum EnvType { dev, staging, prod }

class Env {
  static const EnvType _currentEnv =
      EnvType.dev; // Ajusta aquí para builds específicos

  // Permite override en tiempo de build: --dart-define=API_BASE_URL=...
  static const String _baseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  // URLs configurables desde .env
  static String get _localBase =>
      dotenv.env['LOCAL_API_URL'] ?? 'http://127.0.0.1:8081';
  static String get _remoteBase =>
      dotenv.env['REMOTE_API_URL'] ?? 'https://gym-remote-api.railway.app';
  static const String _prodBase = 'https://api.gymflow.com';

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;

    // Web => remoto; Desktop (Windows/macOS/Linux) => local por defecto
    if (kIsWeb) return _remoteBase;
    if (isDesktopPlatform) return _localBase;

    // Fallback según entorno declarado
    switch (_currentEnv) {
      case EnvType.dev:
        return _localBase;
      case EnvType.staging:
        return _remoteBase;
      case EnvType.prod:
        return _prodBase;
    }
  }

  static const int connectTimeout = 5000;
  static const int receiveTimeout = 10000;
}
