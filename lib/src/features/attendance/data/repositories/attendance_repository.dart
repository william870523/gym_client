import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../models/attendance_model.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref.watch(apiClientProvider));
});

class AttendanceRepository {
  final Dio _dio;

  AttendanceRepository(this._dio);

  Future<List<AttendanceModel>> getDailyAttendances() async {
    try {
      final response = await _dio.get('/asistencias/hoy');
      final List data = response.data as List;
      return data.map((e) => AttendanceModel.fromJson(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<EntradaRegistrada> checkIn(String clientId) async {
    try {
      final response = await _dio.post('/asistencias', data: {'ci': clientId});
      // §5.2 — la respuesta trae, en la entrada de un visitante, con qué dato
      // se autorizó. Descartarlo aquí dejaría al mostrador sin saber que acaba
      // de dejar pasar a alguien con información que puede estar vieja.
      return EntradaRegistrada.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> checkOut(String attendanceId) async {
    try {
      await _dio.put('/asistencias/$attendanceId/finalizar');
    } catch (e) {
      rethrow;
    }
  }

  /// Abre una pausa de permanencia (el socio salió un momento).
  Future<void> pause(String attendanceId) async {
    await _dio.put('/asistencias/$attendanceId/pausar');
  }

  /// Cierra la pausa vigente acumulando su duración.
  Future<void> resume(String attendanceId) async {
    await _dio.put('/asistencias/$attendanceId/reanudar');
  }

  Future<List<AttendanceModel>> getAttendanceHistory({
    int page = 1,
    int limit = 50,
    String? calendarDate,
  }) async {
    try {
      final response = await _dio.get(
        '/asistencias',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (calendarDate != null) 'date': calendarDate,
        },
      );
      final List data = response.data as List;
      return data.map((e) => AttendanceModel.fromJson(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Descarga todo el día seleccionado para que el CSV no quede truncado por
  /// la página visible. La API limita cada lote a 200 registros.
  Future<List<AttendanceModel>> getAttendanceHistoryForDate(
    String calendarDate,
  ) async {
    const pageSize = 200;
    final result = <AttendanceModel>[];
    for (var page = 1; page <= 1000; page += 1) {
      final batch = await getAttendanceHistory(
        page: page,
        limit: pageSize,
        calendarDate: calendarDate,
      );
      result.addAll(batch);
      if (batch.length < pageSize) return result;
    }
    throw StateError('El historial excede el límite seguro de exportación.');
  }
}
