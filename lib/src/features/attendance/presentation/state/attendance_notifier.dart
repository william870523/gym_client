import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/attendance_model.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../../clients/data/models/client_model.dart';
import 'attendance_history_provider.dart';

final attendanceNotifierProvider =
    AsyncNotifierProvider<AttendanceNotifier, List<AttendanceModel>>(() {
      return AttendanceNotifier();
    });

class AttendanceNotifier extends AsyncNotifier<List<AttendanceModel>> {
  final Set<String> _pendingCheckIns = {};

  @override
  Future<List<AttendanceModel>> build() async {
    return ref.read(attendanceRepositoryProvider).getDailyAttendances();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(attendanceRepositoryProvider).getDailyAttendances(),
    );
  }

  /// Entrada por identificación, sin exigir la ficha completa del socio.
  ///
  /// M4a: un visitante de otra sede **no tiene `ClientModel`** en esta
  /// instalación —su ficha vive en su sede y aquí solo llega la copia de solo
  /// lectura—, así que el mostrador necesita poder registrarle la entrada con
  /// lo único que tiene de él: su cédula. El servidor decide si puede pasar.
  /// Devuelve cómo se decidió la entrada, o `null` si no llegó a registrarse
  /// —ya estaba dentro, o hay otra en curso—.
  Future<EntradaRegistrada?> checkInPorCi(String ci) async {
    final alreadyInside =
        state.value?.any(
          (attendance) => attendance.clientId == ci && attendance.checkOut == null,
        ) ??
        false;
    if (alreadyInside || !_pendingCheckIns.add(ci)) return null;
    try {
      final entrada = await ref.read(attendanceRepositoryProvider).checkIn(ci);
      await refresh();
      ref.invalidate(attendanceHistoryProvider);
      return entrada;
    } finally {
      _pendingCheckIns.remove(ci);
    }
  }

  Future<void> checkIn(ClientModel client) async {
    final alreadyInside =
        state.value?.any(
          (attendance) =>
              attendance.clientId == client.id && attendance.checkOut == null,
        ) ??
        false;
    if (alreadyInside || !_pendingCheckIns.add(client.id)) return;
    try {
      await ref.read(attendanceRepositoryProvider).checkIn(client.id);
      await refresh();
      ref.invalidate(attendanceHistoryProvider);
    } catch (e) {
      rethrow;
    } finally {
      _pendingCheckIns.remove(client.id);
    }
  }

  Future<void> checkOut(String attendanceId) async {
    try {
      await ref.read(attendanceRepositoryProvider).checkOut(attendanceId);
      await refresh();
      ref.invalidate(attendanceHistoryProvider);
    } catch (e) {
      rethrow;
    }
  }

  /// Finaliza todas las asistencias activas del socio. Normalmente existe una;
  /// recorrerlas todas permite reparar de forma segura duplicados históricos.
  Future<void> checkOutClient(
    String clientId, {
    required String fallbackAttendanceId,
  }) async {
    final activeIds = state.value
        ?.where(
          (attendance) =>
              attendance.clientId == clientId && attendance.checkOut == null,
        )
        .map((attendance) => attendance.id)
        .toSet()
        .toList();
    final ids = (activeIds == null || activeIds.isEmpty)
        ? [fallbackAttendanceId]
        : activeIds;
    for (final id in ids) {
      await ref.read(attendanceRepositoryProvider).checkOut(id);
    }
    await refresh();
    ref.invalidate(attendanceHistoryProvider);
  }

  /// Pausa de permanencia persistida (Mostrador).
  Future<void> pause(String attendanceId) async {
    await ref.read(attendanceRepositoryProvider).pause(attendanceId);
    await refresh();
  }

  Future<void> resume(String attendanceId) async {
    await ref.read(attendanceRepositoryProvider).resume(attendanceId);
    await refresh();
  }

  // Helper to check if a client is already in the gym
  bool isClientCheckedIn(String clientId) {
    if (!state.hasValue) return false;
    return state.value!.any(
      (att) => att.clientId == clientId && att.status == 'activo',
    );
  }

  // Helper to check if client appears in today's list at all (active or finished)
  bool hasClientAttendedToday(String clientId) {
    if (!state.hasValue) return false;
    return state.value!.any((att) => att.clientId == clientId);
  }
}
