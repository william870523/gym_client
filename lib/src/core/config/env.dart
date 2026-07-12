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

  // URLs configurables para desarrollo local. En web se debe preferir
  // --dart-define=API_BASE_URL=... porque los assets son publicos.
  static String get _localBase =>
      (dotenv.isInitialized ? dotenv.env['LOCAL_API_URL'] : null) ??
      'http://127.0.0.1:8080';
  static String get _remoteBase =>
      (dotenv.isInitialized ? dotenv.env['REMOTE_API_URL'] : null) ??
      'https://gym-remote-api.railway.app';
  static const String _prodBase = 'https://api.gymflow.com';

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;

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
