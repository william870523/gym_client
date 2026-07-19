import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/retention_models.dart';
import '../../data/repositories/retention_repository.dart';

class RetentionFilterNotifier extends Notifier<RetentionDashboardQuery> {
  @override
  RetentionDashboardQuery build() => const RetentionDashboardQuery();

  void setPeriod(String from, String to) {
    state = state.copyWith(from: from, to: to);
  }

  void setPlan(String? planId) {
    state = state.copyWith(planId: planId, clearPlan: planId == null);
  }

  void setTrainer(String? trainerId) {
    state = state.copyWith(
      trainerId: trainerId,
      clearTrainer: trainerId == null,
    );
  }

  void clear() => state = const RetentionDashboardQuery();

  void replace(RetentionDashboardQuery query) => state = query;
}

final retentionFilterProvider =
    NotifierProvider.autoDispose<
      RetentionFilterNotifier,
      RetentionDashboardQuery
    >(RetentionFilterNotifier.new);

final retentionDashboardProvider =
    FutureProvider.autoDispose<RetentionDashboardModel>((ref) {
      final query = ref.watch(retentionFilterProvider);
      return ref.watch(retentionRepositoryProvider).getDashboard(query: query);
    });

final retentionSettingsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(retentionRepositoryProvider).getSettings();
});

final retentionManagementHistoryProvider = FutureProvider.autoDispose
    .family<List<RetentionManagementRecord>, String>((ref, membershipId) {
      return ref
          .watch(retentionRepositoryProvider)
          .getManagementHistory(membershipId);
    });
