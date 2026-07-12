import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../models/accounting_models.dart';

final accountingRepositoryProvider = Provider<AccountingRepository>((ref) {
  return AccountingRepository(ref.watch(apiClientProvider));
});

class AccountingRepository {
  final Dio _dio;

  AccountingRepository(this._dio);

  Future<AccountingSummaryModel> getSummary() async {
    final response = await _dio.get('/contabilidad/summary');
    return AccountingSummaryModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<TrainerCommissionInstallmentModel>> getTrainerInstallments({
    String? status,
  }) async {
    final response = await _dio.get(
      '/contabilidad/trainer-installments',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'estado': status,
      },
    );
    return (response.data as List)
        .map(
          (item) => TrainerCommissionInstallmentModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<List<TrainerCommissionRuleModel>> getTrainerRules() async {
    final response = await _dio.get('/contabilidad/trainer-rules');
    return (response.data as List)
        .map(
          (item) => TrainerCommissionRuleModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> createTrainerRule(Map<String, dynamic> payload) async {
    await _dio.post('/contabilidad/trainer-rules', data: payload);
  }

  Future<void> updateTrainerRule(
    String id,
    Map<String, dynamic> payload,
  ) async {
    await _dio.put('/contabilidad/trainer-rules/$id', data: payload);
  }

  Future<void> deleteTrainerRule(String id) async {
    await _dio.delete('/contabilidad/trainer-rules/$id');
  }
}
