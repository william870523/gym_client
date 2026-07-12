import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/payment_type_model.dart';
import '../../data/repositories/payment_type_repository.dart';

final paymentTypeNotifierProvider =
    AsyncNotifierProvider<PaymentTypeNotifier, List<PaymentTypeModel>>(
      PaymentTypeNotifier.new,
    );

class PaymentTypeNotifier extends AsyncNotifier<List<PaymentTypeModel>> {
  @override
  Future<List<PaymentTypeModel>> build() async {
    return _getPaymentTypes();
  }

  Future<List<PaymentTypeModel>> _getPaymentTypes() async {
    final repository = ref.read(paymentTypeRepositoryProvider);
    return repository.getPaymentTypes();
  }

  Future<void> create(String name, String code, bool active) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(paymentTypeRepositoryProvider);
      await repository.create(name, code, active);
      return _getPaymentTypes();
    });
  }

  Future<void> updatePaymentType(
    String id,
    String name,
    String code,
    bool active,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(paymentTypeRepositoryProvider);
      await repository.update(id, name, code, active);
      return _getPaymentTypes();
    });
  }

  Future<void> delete(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(paymentTypeRepositoryProvider);
      await repository.delete(id);
      return _getPaymentTypes();
    });
  }
}
