import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/currency_model.dart';
import '../../data/repositories/currency_repository.dart';
import '../../data/full_currencies.dart';

final currencyProvider =
    AsyncNotifierProvider<CurrencyNotifier, List<CurrencyModel>>(() {
      return CurrencyNotifier();
    });

class CurrencyNotifier extends AsyncNotifier<List<CurrencyModel>> {
  @override
  Future<List<CurrencyModel>> build() async {
    return _fetchCurrencies();
  }

  Future<List<CurrencyModel>> _fetchCurrencies() async {
    final repository = ref.read(currencyRepositoryProvider);
    return repository.getCurrencies();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchCurrencies());
  }

  Future<void> createCurrency(
    String name,
    String code,
    String symbol,
    Uint8List? flagBytes,
  ) async {
    final repository = ref.read(currencyRepositoryProvider);
    await repository.createCurrency({
      'moneda_nombre': name,
      'codigo': code,
      'simbolo': symbol,
      'imagen': null,
    }, imageBytes: flagBytes);
    await refresh();
  }

  Future<void> updateCurrency(
    String id,
    String name,
    String code,
    String symbol,
    Uint8List? flagBytes,
  ) async {
    final repository = ref.read(currencyRepositoryProvider);
    await repository.updateCurrency(id, {
      'moneda_nombre': name,
      'codigo': code,
      'simbolo': symbol,
      'imagen': null,
    }, imageBytes: flagBytes);
    await refresh();
  }

  Future<void> deleteCurrency(String id) async {
    final repository = ref.read(currencyRepositoryProvider);
    await repository.deleteCurrency(id);
    await refresh();
  }

  Future<void> seedWorldCurrencies() async {
    state = const AsyncValue.loading();
    final repository = ref.read(currencyRepositoryProvider);

    for (var currency in kWorldCurrencies) {
      try {
        await repository.createCurrency({
          'moneda_nombre': currency['name'],
          'codigo': currency['code'],
          'simbolo': currency['symbol'],
          'imagen': null,
        });
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Skipping ${currency['code']}: $e');
        }
      }
    }

    await refresh();
  }
}
