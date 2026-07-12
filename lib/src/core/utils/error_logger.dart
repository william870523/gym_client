import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class ErrorLogger {
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
    _logger.e(
      'Uncaught Error in ${library ?? "App"}',
      error: error,
      stackTrace: stack,
    );

    // Future: Write to file
    _writeToFile(error, stack);
  }

  static Future<void> _writeToFile(dynamic error, StackTrace? stack) async {
    try {
      if (!kIsWeb) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/app_errors.log');
        final timestamp = DateTime.now().toIso8601String();
        final logMessage = '[$timestamp] ERROR: $error\nSTACK: $stack\n\n';
        await file.writeAsString(logMessage, mode: FileMode.append);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to write error log: $e');
      }
    }
  }
}
