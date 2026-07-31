import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_client/src/core/network/api_client.dart';
import 'package:gym_client/src/features/configuration/data/models/payment_type_model.dart';
import 'package:gym_client/src/features/financials/data/models/account_model.dart';
import 'package:gym_client/src/features/financials/data/models/exchange_rate_model.dart';
import 'package:gym_client/src/features/payments/data/models/payment_model.dart';
import 'package:gym_client/src/features/payments/data/models/payment_reversal_model.dart';
import 'package:gym_client/src/features/payments/data/models/recargo_mora_quote.dart';
import 'package:uuid/uuid.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(apiClientProvider));
});

class PaymentRepository {
  final Dio _client;

  PaymentRepository(this._client);

  Future<List<PaymentModel>> getPayments({
    int page = 1,
    int limit = 500,
  }) async {
    try {
      final response = await _client.get(
        '/pagos',
        queryParameters: {'page': page, 'limit': limit},
      );
      return (response.data as List)
          .map((e) => PaymentModel.fromJson(e))
          .toList();
    } catch (e) {
      throw Exception('Error fetching payments: $e');
    }
  }

  Future<List<PaymentModel>> getPaymentsByClient(
    String ci, {
    int page = 1,
    int limit = 25,
  }) async {
    try {
      final response = await _client.get(
        '/pagos/cliente/$ci',
        queryParameters: {'page': page, 'limit': limit},
      );
      return (response.data as List)
          .map((e) => PaymentModel.fromJson(e))
          .toList();
    } catch (e) {
      throw Exception('Error fetching client payments: $e');
    }
  }

  Future<PaymentModel> createPayment(
    PaymentModel payment,
    List<PaymentDetailModel> details, {
    // R5.2 — banderas del cobro por cuotas (modo_cuotas, numero_cuota).
    Map<String, dynamic>? extra,
  }) async {
    try {
      final payload = payment.toJson();
      payload['detalles'] = details.map((e) => e.toJson()).toList();
      if (extra != null) payload.addAll(extra);
      final response = await _client.post('/pagos/process', data: payload);
      return PaymentModel.fromJson(response.data);
    } on DioException catch (e) {
      final responseData = e.response?.data;
      final serverMessage = responseData is Map
          ? responseData['error']?.toString()
          : null;
      throw Exception(
        serverMessage?.trim().isNotEmpty == true
            ? serverMessage
            : 'El servidor rechazó el pago (${e.response?.statusCode ?? 'sin respuesta'}).',
      );
    } catch (e) {
      throw Exception('Error creating payment: $e');
    }
  }

  /// Cotización autoritativa del recargo por mora (docs/RECARGO_MORA.md).
  ///
  /// El importe SIEMPRE lo calcula el servidor: la vista solo presenta lo que
  /// aquí se devuelve. Un fallo no debe impedir cobrar, así que se propaga
  /// como excepción y la ventana decide mostrar el aviso.
  Future<RecargoMoraQuote> getRecargoMoraQuote({
    required String ci,
    required String planId,
    String? membresiaId,
    int? numeroCuota,
    bool aplicar = true,
  }) async {
    try {
      final response = await _client.get(
        '/pagos/recargo-mora/quote',
        queryParameters: {
          'ci': ci,
          'plan_id': planId,
          if (membresiaId != null) 'membresia_id': membresiaId,
          if (numeroCuota != null) 'numero_cuota': numeroCuota,
          'aplicar': aplicar.toString(),
        },
      );
      return RecargoMoraQuote.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map ? data['error']?.toString() : null;
      throw Exception(
        message?.trim().isNotEmpty == true
            ? message
            : 'No se pudo calcular el recargo por mora.',
      );
    }
  }

  Future<PaymentReversalResult> voidPayment(
    String paymentId, {
    required String reason,
  }) async {
    try {
      final response = await _client.post(
        '/pagos/$paymentId/reversar',
        data: {'operation_id': const Uuid().v4(), 'motivo': reason.trim()},
      );
      return PaymentReversalResult.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (e) {
      final responseData = e.response?.data;
      final serverMessage = responseData is Map
          ? responseData['error']?.toString()
          : null;
      throw Exception(
        serverMessage?.trim().isNotEmpty == true
            ? serverMessage
            : 'No se pudo anular el pago (${e.response?.statusCode ?? 'sin respuesta'}).',
      );
    }
  }

  Future<List<PaymentTypeModel>> getPaymentTypes() async {
    try {
      final response = await _client.get('/tipos-pago');
      return (response.data as List)
          .map((e) => PaymentTypeModel.fromJson(e))
          .toList();
    } catch (e) {
      throw Exception('Error fetching payment types: $e');
    }
  }

  Future<List<AccountModel>> getAccounts() async {
    try {
      final response = await _client.get('/cuentas');
      return (response.data as List)
          .map((e) => AccountModel.fromJson(e))
          .toList();
    } catch (e) {
      throw Exception('Error fetching accounts: $e');
    }
  }

  Future<List<ExchangeRateModel>> getExchangeRates() async {
    try {
      final response = await _client.get('/tipos-cambio');
      return (response.data as List)
          .map((e) => ExchangeRateModel.fromJson(e))
          .toList();
    } catch (e) {
      throw Exception('Error fetching exchange rates: $e');
    }
  }
}
