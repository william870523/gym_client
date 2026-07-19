import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/client_record_model.dart';
import '../../data/repositories/client_repository.dart';

final clientRecordProvider = FutureProvider.autoDispose
    .family<ClientRecordModel, String>((ref, ci) {
      return ref.watch(clientRepositoryProvider).getClientRecord(ci);
    });

final membershipRequestsProvider = FutureProvider.autoDispose
    .family<List<ClientMembershipRequest>, String?>((ref, state) {
      return ref
          .watch(clientRepositoryProvider)
          .getMembershipRequests(state: state);
    });

enum ClientRecordPeriod {
  all('Todo el historial'),
  threeMonths('Últimos 3 meses'),
  sixMonths('Últimos 6 meses'),
  twelveMonths('Últimos 12 meses');

  const ClientRecordPeriod(this.label);
  final String label;
}

class ClientRecordFilter {
  const ClientRecordFilter({
    this.period = ClientRecordPeriod.all,
    this.planId,
    this.status,
  });

  final ClientRecordPeriod period;
  final String? planId;
  final String? status;

  bool get isActive =>
      period != ClientRecordPeriod.all || planId != null || status != null;

  ClientRecordFilter copyWith({
    ClientRecordPeriod? period,
    String? planId,
    bool clearPlan = false,
    String? status,
    bool clearStatus = false,
  }) => ClientRecordFilter(
    period: period ?? this.period,
    planId: clearPlan ? null : planId ?? this.planId,
    status: clearStatus ? null : status ?? this.status,
  );
}

class ClientRecordFilterNotifier extends Notifier<ClientRecordFilter> {
  @override
  ClientRecordFilter build() => const ClientRecordFilter();

  void setPeriod(ClientRecordPeriod value) {
    state = state.copyWith(period: value);
  }

  void setPlan(String? value) {
    state = state.copyWith(planId: value, clearPlan: value == null);
  }

  void setStatus(String? value) {
    state = state.copyWith(status: value, clearStatus: value == null);
  }

  void reset() {
    state = const ClientRecordFilter();
  }
}

final clientRecordFilterProvider =
    NotifierProvider.autoDispose<
      ClientRecordFilterNotifier,
      ClientRecordFilter
    >(ClientRecordFilterNotifier.new);
