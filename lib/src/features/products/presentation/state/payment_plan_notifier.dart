import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/payment_plan_model.dart';
import '../../data/repositories/payment_plan_repository.dart';

part 'payment_plan_notifier.g.dart';

@riverpod
class PaymentPlanNotifier extends _$PaymentPlanNotifier {
  @override
  FutureOr<List<PaymentPlanModel>> build() async {
    return _fetchPlans();
  }

  Future<List<PaymentPlanModel>> _fetchPlans() async {
    final repository = ref.read(paymentPlanRepositoryProvider);
    return await repository.getPaymentPlans();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchPlans());
  }

  /// Devuelve el plan creado (el servidor genera el id): el formulario lo
  /// necesita para guardar el esquema de cuotas de un plan nuevo.
  Future<PaymentPlanModel> create(PaymentPlanModel plan) async {
    final repository = ref.read(paymentPlanRepositoryProvider);
    final created = await repository.createPaymentPlan(plan);
    ref.invalidateSelf();
    return created;
  }

  Future<void> updatePlan(PaymentPlanModel plan) async {
    final repository = ref.read(paymentPlanRepositoryProvider);
    await AsyncValue.guard(() async {
      await repository.updatePaymentPlan(plan);
    });
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    final repository = ref.read(paymentPlanRepositoryProvider);
    await AsyncValue.guard(() async {
      await repository.deletePaymentPlan(id);
    });
    ref.invalidateSelf();
  }
}
