import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/payment_type_model.dart';

final paymentTypeRepositoryProvider = Provider<PaymentTypeRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return PaymentTypeRepository(dio);
});

class PaymentTypeRepository {
  final Dio _dio;

  PaymentTypeRepository(this._dio);

  Future<List<PaymentTypeModel>> getPaymentTypes() async {
    try {
      final response = await _dio.get('/tipos-pago');
      final List<dynamic> data = response.data;
      return data
          .map((json) => PaymentTypeModel.fromJson(json))
          .where((item) => !item.isDeleted)
          .toList();
    } catch (e) {
      throw Exception('Error al obtener tipos de pago: $e');
    }
  }

  Future<void> create(String name, String code, bool active) async {
    try {
      await _dio.post(
        '/tipos-pago',
        data: {'nombre_tipo_pago': name, 'codigo': code, 'activo': active},
      );
    } catch (e) {
      throw Exception('Error al crear tipo de pago: $e');
    }
  }

  Future<void> update(String id, String name, String code, bool active) async {
    try {
      await _dio.put(
        '/tipos-pago/$id',
        data: {'nombre_tipo_pago': name, 'codigo': code, 'activo': active},
      );
    } catch (e) {
      throw Exception('Error al actualizar tipo de pago: $e');
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/tipos-pago/$id');
    } catch (e) {
      throw Exception('Error al eliminar tipo de pago: $e');
    }
  }
}
