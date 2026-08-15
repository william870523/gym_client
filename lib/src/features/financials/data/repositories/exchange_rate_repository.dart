import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/network/api_client.dart';
import '../models/exchange_rate_model.dart';

part 'exchange_rate_repository.g.dart';

@riverpod
ExchangeRateRepository exchangeRateRepository(Ref ref) {
  final dio = ref.watch(apiClientProvider);
  return ExchangeRateRepository(dio);
}

class ExchangeRateRepository {
  final Dio _dio;

  ExchangeRateRepository(this._dio);

  Future<List<ExchangeRateModel>> getExchangeRates() async {
    try {
      final response = await _dio.get('/tipos-cambio');
      return (response.data as List)
          .map((e) => ExchangeRateModel.fromJson(e))
          .toList();
    } catch (e) {
      throw Exception('Failed to load exchange rates: $e');
    }
  }

  Future<ExchangeRateModel> create(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/tipos-cambio', data: data);
      return ExchangeRateModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      if (e is DioException) {
        final message = e.response?.data?['error'] ?? e.message;
        throw Exception('Failed to create exchange rate: $message');
      }
      throw Exception('Failed to create exchange rate: $e');
    }
  }

  Future<void> replaceSiteSurcharges(
    String id,
    Map<String, String> values,
  ) async {
    await _dio.put('/tipos-cambio/$id/recargos/sede', data: {'recargos': values});
  }

  Future<void> resetSiteSurcharges(String id) async {
    await _dio.delete('/tipos-cambio/$id/recargos/sede');
  }

  Future<void> replaceGlobalSurcharges(
    String id,
    Map<String, String> values,
  ) async {
    await _dio.put('/tipos-cambio/$id/recargos/global', data: {'recargos': values});
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    try {
      await _dio.put('/tipos-cambio/$id', data: data);
    } catch (e) {
      throw Exception('Failed to update exchange rate: $e');
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/tipos-cambio/$id');
    } catch (e) {
      throw Exception('Failed to delete exchange rate: $e');
    }
  }
}
