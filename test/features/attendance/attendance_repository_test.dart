import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/attendance/data/repositories/attendance_repository.dart';
import 'package:gym_client/src/features/attendance/presentation/state/attendance_history_provider.dart';

void main() {
  test('envía el día de negocio junto con la página', () async {
    final adapter = _AttendanceAdapter((_) => const []);
    final dio = Dio(BaseOptions(baseUrl: 'http://gym.test'))
      ..httpClientAdapter = adapter;

    await AttendanceRepository(
      dio,
    ).getAttendanceHistory(page: 3, limit: 15, calendarDate: '2026-07-29');

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.path, '/asistencias');
    expect(adapter.requests.single.queryParameters, {
      'page': 3,
      'limit': 15,
      'date': '2026-07-29',
    });
  });

  test('el CSV puede descargar más de una página del mismo día', () async {
    final adapter = _AttendanceAdapter((request) {
      final page = request.queryParameters['page'] as int;
      final count = page == 1 ? 200 : 1;
      return List.generate(count, (index) => _row('p$page-$index'));
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://gym.test'))
      ..httpClientAdapter = adapter;

    final result = await AttendanceRepository(
      dio,
    ).getAttendanceHistoryForDate('2026-07-29');

    expect(result, hasLength(201));
    expect(adapter.requests, hasLength(2));
    expect(
      adapter.requests.map((request) => request.queryParameters['date']),
      everyElement('2026-07-29'),
    );
  });

  test('un reintento puede limpiar el error anterior', () {
    final failed = AttendanceHistoryState(
      page: 1,
      limit: 15,
      attendances: const [],
      error: 'sin conexión',
    );

    expect(failed.copyWith(clearError: true).error, isNull);
  });
}

Map<String, Object?> _row(String id) => {
  'asistencia_id': id,
  'ci': 'HIST-001',
  'created_at': '2026-07-29T17:00:00.000Z',
  'fecha_salida': '2026-07-29T18:00:00.000Z',
  'pausa_inicio': null,
  'pausa_ms': 0,
};

class _AttendanceAdapter implements HttpClientAdapter {
  _AttendanceAdapter(this.rows);

  final List<Map<String, Object?>> Function(RequestOptions request) rows;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(rows(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
