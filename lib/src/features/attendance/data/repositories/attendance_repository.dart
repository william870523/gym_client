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

  Future<AttendanceModel> checkIn(String clientId) async {
    try {
      final response = await _dio.post('/asistencias', data: {'ci': clientId});
      return AttendanceModel.fromJson(response.data);
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

  Future<List<AttendanceModel>> getAttendanceHistory({int page = 1, int limit = 50}) async {
    try {
      final response = await _dio.get('/asistencias', queryParameters: {'page': page, 'limit': limit});
      final List data = response.data as List;
      return data.map((e) => AttendanceModel.fromJson(e)).toList();
    } catch (e) {
      rethrow;
    }
  }
}

