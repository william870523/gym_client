import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class ErrorLogger {
  static const _duplicateWindow = Duration(seconds: 5);
  static const _maxFingerprints = 32;

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );
  static final Map<String, _ErrorBurst> _recentErrors = {};
  static Future<void> _fileWriteQueue = Future<void>.value();

  static Future<void> init() async {
    FlutterError.onError = (FlutterErrorDetails details) {
      logError(details.exception, details.stack, library: details.library);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      logError(error, stack);
      return true;
    };
  }

  static void logError(dynamic error, StackTrace? stack, {String? library}) {
    final now = DateTime.now().toUtc();
    final fingerprint = _fingerprint(error, stack, library);
    final previous = _recentErrors[fingerprint];
    if (previous != null &&
        now.difference(previous.lastEmittedAt) < _duplicateWindow) {
      previous.suppressed += 1;
      return;
    }

    final suppressed = previous?.suppressed ?? 0;
    _recentErrors[fingerprint] = _ErrorBurst(lastEmittedAt: now);
    _trimFingerprints();
    final repeatedSuffix = suppressed == 0
        ? ''
        : ' · $suppressed repetición(es) idéntica(s) omitida(s)';
    _logger.e(
      'Uncaught Error in ${library ?? "App"}$repeatedSuffix',
      error: error,
      stackTrace: stack,
    );

    final logMessage =
        '[${now.toIso8601String()}] ERROR'
        '${library == null ? '' : ' [$library]'}: $error\n'
        'STACK: $stack\n'
        '${suppressed == 0 ? '' : 'SUPPRESSED_DUPLICATES: $suppressed\n'}\n';
    _fileWriteQueue = _fileWriteQueue
        .then((_) => _writeToFile(logMessage))
        .catchError((Object writeError, StackTrace writeStack) {
          if (kDebugMode) {
            debugPrint('Failed to write error log: $writeError');
          }
        });
  }

  static String _fingerprint(
    dynamic error,
    StackTrace? stack,
    String? library,
  ) {
    final normalizedError = error.toString().replaceAll(
      RegExp(r'#[0-9a-fA-F]+'),
      '#*',
    );
    final stackHead = (stack?.toString().split('\n') ?? const <String>[])
        .take(8)
        .join('\n');
    return '${library ?? 'App'}|${error.runtimeType}|$normalizedError|$stackHead';
  }

  static void _trimFingerprints() {
    if (_recentErrors.length <= _maxFingerprints) return;
    final oldest = _recentErrors.entries.reduce(
      (current, candidate) =>
          candidate.value.lastEmittedAt.isBefore(current.value.lastEmittedAt)
          ? candidate
          : current,
    );
    _recentErrors.remove(oldest.key);
  }

  static Future<void> _writeToFile(String logMessage) async {
    try {
      if (!kIsWeb) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/app_errors.log');
        await file.writeAsString(logMessage, mode: FileMode.append);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to write error log: $e');
      }
    }
  }
}

class _ErrorBurst {
  _ErrorBurst({required this.lastEmittedAt});

  final DateTime lastEmittedAt;
  int suppressed = 0;
}
