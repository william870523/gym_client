import 'dart:async';

import 'package:dio/dio.dart';

class AppClock {
  Duration _offset = Duration.zero;
  String _gymTimezone = 'Etc/UTC';
  DateTime? _synchronizedAtUtc;
  int? _roundTripMs;
  Timer? _timer;
  bool _synchronizing = false;
  String? _baseUrl;
  String? _gymId;

  String get gymTimezone => _gymTimezone;
  Duration get offset => _offset;
  DateTime? get synchronizedAtUtc => _synchronizedAtUtc;
  int? get roundTripMs => _roundTripMs;
  bool get isSynchronized => _synchronizedAtUtc != null;
  bool get systemClockIsReliable => _offset.inMilliseconds.abs() <= 2000;

  DateTime nowUtc() => DateTime.now().toUtc().add(_offset);

  Future<void> synchronize(String baseUrl, {String? gymId}) async {
    if (_synchronizing) return;
    _synchronizing = true;
    _baseUrl = baseUrl;
    _gymId = gymId ?? _gymId;

    try {
      final startedUtc = DateTime.now().toUtc();
      final stopwatch = Stopwatch()..start();
      final normalizedBase = baseUrl.replaceFirst(RegExp(r'/+$'), '');
      final response =
          await Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ),
          ).get<Map<String, dynamic>>(
            '$normalizedBase/system/time',
            queryParameters: {
              if (_gymId != null && _gymId!.isNotEmpty) 'gym_id': _gymId,
            },
            options: Options(headers: const {'Cache-Control': 'no-cache'}),
          );
      stopwatch.stop();

      final data = response.data;
      if (data == null) throw const FormatException('Respuesta de hora vacía');
      final authorityMs = _readAuthorityMs(data);
      final midpoint = startedUtc.add(
        Duration(microseconds: stopwatch.elapsedMicroseconds ~/ 2),
      );

      _offset = Duration(
        milliseconds: authorityMs - midpoint.millisecondsSinceEpoch,
      );
      _roundTripMs = stopwatch.elapsedMilliseconds;
      _synchronizedAtUtc = DateTime.now().toUtc();

      final timezone = data['gym_timezone']?.toString().trim();
      if (timezone != null && timezone.isNotEmpty) {
        _gymTimezone = timezone;
      }
    } finally {
      _synchronizing = false;
    }
  }

  void startPeriodicSync({Duration interval = const Duration(minutes: 5)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      final baseUrl = _baseUrl;
      if (baseUrl != null) {
        unawaited(
          synchronize(baseUrl, gymId: _gymId).catchError((_) {
            // Mantiene el último desfase válido mientras la red está caída.
          }),
        );
      }
    });
  }

  int _readAuthorityMs(Map<String, dynamic> data) {
    final numeric = data['trusted_utc_ms'] ?? data['server_utc_ms'];
    if (numeric is num) return numeric.round();

    final text = data['trusted_utc'] ?? data['server_utc'];
    final parsed = DateTime.tryParse(text?.toString() ?? '');
    if (parsed == null) {
      throw const FormatException('La API no devolvió una hora UTC válida');
    }
    return parsed.toUtc().millisecondsSinceEpoch;
  }
}

final appClock = AppClock();
