import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/account_model.dart';
import '../../data/repositories/account_repository.dart';

part 'account_notifier.g.dart';

@riverpod
class AccountNotifier extends _$AccountNotifier {
  @override
  Future<List<AccountModel>> build() async {
    return _fetchAccounts();
  }

  Future<List<AccountModel>> _fetchAccounts() async {
    final repository = ref.read(accountRepositoryProvider);
    return repository.getAccounts();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchAccounts());
  }

  Future<void> createAccount(
    String name,
    String currencyId, {
    String? paymentTypeId,
  }) async {
    final repository = ref.read(accountRepositoryProvider);
    await repository.createAccount({
      'nombre_cuenta': name,
      'moneda_id': currencyId,
      'tipo_pago_id': paymentTypeId,
    });
    await refresh();
  }

  Future<void> updateAccount(
    String id,
    String name,
    String currencyId, {
    String? paymentTypeId,
  }) async {
    final repository = ref.read(accountRepositoryProvider);
    await repository.updateAccount(id, {
      'nombre_cuenta': name,
      'moneda_id': currencyId,
      'tipo_pago_id': paymentTypeId,
    });
    await refresh();
  }

  Future<void> deleteAccount(String id) async {
    final repository = ref.read(accountRepositoryProvider);
    await repository.deleteAccount(id);
    await refresh();
  }
}
