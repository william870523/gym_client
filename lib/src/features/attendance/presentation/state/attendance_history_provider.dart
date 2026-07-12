import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/attendance_model.dart';
import '../../data/repositories/attendance_repository.dart';

class AttendanceHistoryState {
  final int page;
  final int limit;
  final List<AttendanceModel> attendances;
  final bool isLoading;
  final String? error;

  AttendanceHistoryState({
    required this.page,
    required this.limit,
    required this.attendances,
    this.isLoading = false,
    this.error,
  });

  AttendanceHistoryState copyWith({
    int? page,
    int? limit,
    List<AttendanceModel>? attendances,
    bool? isLoading,
    String? error,
  }) {
    return AttendanceHistoryState(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      attendances: attendances ?? this.attendances,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
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

  Future<void> loadPage(int page) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await ref.read(attendanceRepositoryProvider).getAttendanceHistory(
        page: page,
        limit: state.limit,
      );
      state = state.copyWith(
        page: page,
        attendances: results,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
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
