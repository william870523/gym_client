import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../models/client_discount_settings_model.dart';

/// R5.3 — Repositorio del % global de descuento para cliente VIEJO.
final clientDiscountRepositoryProvider = Provider<ClientDiscountRepository>(
  (ref) => ClientDiscountRepository(ref.watch(apiClientProvider)),
);

class ClientDiscountRepository {
  const ClientDiscountRepository(this._dio);
  final Dio _dio;

  Future<ClientDiscountSettingsModel> get() async {
    final response = await _dio.get('/configuracion/client-discount');
    return ClientDiscountSettingsModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<ClientDiscountSettingsModel> update({
    required String clienteViejoPct,
  }) async {
    final response = await _dio.put(
      '/configuracion/client-discount',
      data: {'cliente_viejo_pct': clienteViejoPct},
    );
    return ClientDiscountSettingsModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}
