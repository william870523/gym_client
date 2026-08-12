import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../data/models/attendance_model.dart';
import '../../data/repositories/attendance_repository.dart';

String _todayCalendarDate() {
  final today = toGymWallClock(appClock.nowUtc(), appClock.gymTimezone);
  return '${today.year.toString().padLeft(4, '0')}-'
      '${today.month.toString().padLeft(2, '0')}-'
      '${today.day.toString().padLeft(2, '0')}';
}

class AttendanceHistoryState {
  final int page;
  final int limit;
  final String calendarDate;
  final List<AttendanceModel> attendances;
  final bool isLoading;
  final String? error;

  AttendanceHistoryState({
    required this.page,
    required this.limit,
    required this.attendances,
    String? calendarDate,
    this.isLoading = false,
    this.error,
  }) : calendarDate = calendarDate ?? _todayCalendarDate();

  AttendanceHistoryState copyWith({
    int? page,
    int? limit,
    String? calendarDate,
    List<AttendanceModel>? attendances,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AttendanceHistoryState(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      calendarDate: calendarDate ?? this.calendarDate,
      attendances: attendances ?? this.attendances,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class AttendanceHistoryNotifier extends Notifier<AttendanceHistoryState> {
  @override
  AttendanceHistoryState build() {
    // Schedule asynchronous loading of first page
    Future.microtask(() => loadPage(1));
    return AttendanceHistoryState(page: 1, limit: 15, attendances: []);
  }

  Future<void> loadPage(int page, {String? calendarDate}) async {
    final selectedDate = calendarDate ?? state.calendarDate;
    final dateChanged = selectedDate != state.calendarDate;
    state = state.copyWith(
      page: page,
      isLoading: true,
      calendarDate: selectedDate,
      attendances: dateChanged ? const [] : state.attendances,
      clearError: true,
    );
    try {
      final results = await ref
          .read(attendanceRepositoryProvider)
          .getAttendanceHistory(
            page: page,
            limit: state.limit,
            calendarDate: selectedDate,
          );
      state = state.copyWith(
        page: page,
        attendances: results,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<List<AttendanceModel>> loadAllForSelectedDate() {
    return ref
        .read(attendanceRepositoryProvider)
        .getAttendanceHistoryForDate(state.calendarDate);
  }

  Future<void> nextPage() async {
    if (state.attendances.length < state.limit) return; // Probable end of pages
    await loadPage(state.page + 1);
  }

  Future<void> prevPage() async {
    if (state.page <= 1) return;
    await loadPage(state.page - 1);
  }
}

final attendanceHistoryProvider =
    NotifierProvider<AttendanceHistoryNotifier, AttendanceHistoryState>(
      AttendanceHistoryNotifier.new,
    );
