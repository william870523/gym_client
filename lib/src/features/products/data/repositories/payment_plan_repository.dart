import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/network/api_client.dart';
import '../models/payment_plan_model.dart';

part 'payment_plan_repository.g.dart';

@Riverpod(keepAlive: true)
PaymentPlanRepository paymentPlanRepository(Ref ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PaymentPlanRepository(apiClient);
}

class PaymentPlanRepository {
  final Dio _client;

  PaymentPlanRepository(this._client);

  Future<List<PaymentPlanModel>> getPaymentPlans() async {
    try {
      final response = await _client.get('/planes-pago');
      return (response.data as List)
          .map((e) => PaymentPlanModel.fromJson(e))
          .toList();
    } catch (e) {
      throw Exception('Failed to load payment plans: $e');
    }
  }

  Future<PaymentPlanModel> getPaymentPlan(String id) async {
    try {
      final response = await _client.get('/planes-pago/$id');
      return PaymentPlanModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to load payment plan: $e');
    }
  }

  Future<PaymentPlanModel> createPaymentPlan(PaymentPlanModel plan) async {
    try {
      // Exclude ID to allow server to generate it if null/empty
      final data = plan.toJson();
      if (plan.id == null || plan.id!.isEmpty) {
        data.remove('id_planes_pago');
      }

      final response = await _client.post('/planes-pago', data: data);
      return PaymentPlanModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create payment plan: $e');
    }
  }

  Future<PaymentPlanModel> updatePaymentPlan(PaymentPlanModel plan) async {
    try {
      final response = await _client.put(
        '/planes-pago/${plan.id}',
        data: plan.toJson(),
      );
      return PaymentPlanModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to update payment plan: $e');
    }
  }

  Future<void> deletePaymentPlan(String id) async {
    try {
      await _client.delete('/planes-pago/$id');
    } catch (e) {
      throw Exception('Failed to delete payment plan: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPlanCuotasScheme(String planId) async {
    try {
      final response = await _client.get('/planes-pago/$planId/cuotas');
      return (response.data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<void> savePlanCuotasScheme(
    String planId,
    List<Map<String, dynamic>> tranches,
  ) async {
    try {
      await _client.put(
        '/planes-pago/$planId/cuotas',
        data: {'tranches': tranches},
      );
    } catch (e) {
      // El servidor responde { error } con el motivo real; mostrarlo tal cual
      // en lugar del volcado técnico de DioException.
      if (e is DioException) {
        final detail = e.response?.data is Map
            ? (e.response!.data as Map)['error']?.toString()
            : null;
        if (detail != null && detail.trim().isNotEmpty) {
          throw Exception(detail.trim());
        }
      }
      throw Exception('Error al guardar el esquema de cuotas: $e');
    }
  }
}
