import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/exchange_rate_model.dart';
import '../../data/repositories/exchange_rate_repository.dart';

part 'exchange_rate_notifier.g.dart';

@riverpod
class ExchangeRateNotifier extends _$ExchangeRateNotifier {
  @override
  Future<List<ExchangeRateModel>> build() async {
    return _fetch();
  }

  Future<List<ExchangeRateModel>> _fetch() async {
    final repository = ref.read(exchangeRateRepositoryProvider);
    return repository.getExchangeRates();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch());
  }

  Future<ExchangeRateModel> create(Map<String, dynamic> data) async {
    final repository = ref.read(exchangeRateRepositoryProvider);
    final created = await repository.create(data);
    await refresh();
    return created;
  }

  Future<void> updateExchangeRate(String id, Map<String, dynamic> data) async {
    final repository = ref.read(exchangeRateRepositoryProvider);
    await repository.update(id, data);
    await refresh();
  }

  Future<void> delete(String id) async {
    final repository = ref.read(exchangeRateRepositoryProvider);
    await repository.delete(id);
    await refresh();
  }

  Future<void> replaceSiteSurcharges(
    String id,
    Map<String, String> values,
  ) async {
    await ref.read(exchangeRateRepositoryProvider).replaceSiteSurcharges(id, values);
    await refresh();
  }

  Future<void> resetSiteSurcharges(String id) async {
    await ref.read(exchangeRateRepositoryProvider).resetSiteSurcharges(id);
    await refresh();
  }

  Future<void> replaceGlobalSurcharges(
    String id,
    Map<String, String> values,
  ) async {
    await ref.read(exchangeRateRepositoryProvider).replaceGlobalSurcharges(id, values);
    await refresh();
  }
}
