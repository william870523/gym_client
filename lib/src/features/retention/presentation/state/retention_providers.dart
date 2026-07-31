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

/// Catálogo de motivos de baja (PLAN_ESTADISTICAS.md §7-ter).
///
/// El parámetro dice si se quieren solo los activos: el diálogo de gestión pide
/// activos —no tiene sentido ofrecer un motivo retirado— y la vista de catálogo
/// los pide todos, para poder reactivar los apagados.
final dropoutReasonsProvider = FutureProvider.autoDispose
    .family<List<DropoutReasonModel>, bool>((ref, onlyActive) {
      return ref
          .watch(retentionRepositoryProvider)
          .getDropoutReasons(onlyActive: onlyActive);
    });

/// Catálogo administrable de motivos de baja, con sus escrituras.
///
/// Carga **todos** los motivos, incluidos los desactivados: la vista de
/// catálogo tiene que poder reactivarlos. El diálogo de gestión usa en cambio
/// [dropoutReasonsProvider] con `true`, que solo trae los que deben ofrecerse.
class DropoutReasonCatalogNotifier
    extends AsyncNotifier<List<DropoutReasonModel>> {
  @override
  Future<List<DropoutReasonModel>> build() => _fetch();

  Future<List<DropoutReasonModel>> _fetch() {
    return ref.read(retentionRepositoryProvider).getDropoutReasons();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
    // El desplegable de la gestión comparte catálogo: si aquí se desactiva un
    // motivo, allí tiene que dejar de ofrecerse sin recargar la aplicación.
    ref.invalidate(dropoutReasonsProvider);
  }

  Future<void> create({
    required String name,
    String? code,
    int order = 0,
    bool active = true,
  }) async {
    await ref
        .read(retentionRepositoryProvider)
        .createDropoutReason(
          name: name,
          code: code,
          order: order,
          active: active,
        );
    await refresh();
  }

  Future<void> edit({
    required String id,
    String? name,
    String? code,
    int? order,
    bool? active,
  }) async {
    await ref
        .read(retentionRepositoryProvider)
        .updateDropoutReason(
          id: id,
          name: name,
          code: code,
          order: order,
          active: active,
        );
    await refresh();
  }

  /// Desactivar es la salida cuando un motivo ya se usó: lo retira de gestiones
  /// nuevas sin tocar la historia que lo menciona.
  Future<void> setActive(DropoutReasonModel reason, bool active) {
    return edit(id: reason.id, active: active);
  }

  Future<void> remove(String id) async {
    await ref.read(retentionRepositoryProvider).deleteDropoutReason(id);
    await refresh();
  }
}

final dropoutReasonCatalogProvider =
    AsyncNotifierProvider<DropoutReasonCatalogNotifier, List<DropoutReasonModel>>(
      DropoutReasonCatalogNotifier.new,
    );
