import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../models/currency_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'currency_repository.g.dart';

class CurrencyRepository {
  final Dio _client;

  CurrencyRepository(this._client);

  Future<List<CurrencyModel>> getCurrencies() async {
    try {
      final response = await _client.get('/monedas');
      return (response.data as List)
          .map((e) => CurrencyModel.fromJson(e))
          .toList();
    } catch (e) {
      throw Exception('Failed to load currencies: $e');
    }
  }

  Future<CurrencyModel> createCurrency(
    Map<String, dynamic> data, {
    Uint8List? imageBytes,
  }) async {
    try {
      // Clean 'imagen' string field as we use bytes
      data.remove('imagen');
      final formData = FormData.fromMap(data);

      if (imageBytes != null) {
        formData.files.add(
          MapEntry(
            'imagen_file',
            MultipartFile.fromBytes(imageBytes, filename: 'flag.png'),
          ),
        );
      }

      final response = await _client.post('/monedas', data: formData);
      return CurrencyModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create currency: $e');
    }
  }

  Future<void> updateCurrency(
    String id,
    Map<String, dynamic> data, {
    Uint8List? imageBytes,
  }) async {
    try {
      data.remove('imagen');
      final formData = FormData.fromMap(data);

      if (imageBytes != null) {
        formData.files.add(
          MapEntry(
            'imagen_file',
            MultipartFile.fromBytes(imageBytes, filename: 'flag.png'),
          ),
        );
      }

      await _client.put('/monedas/$id', data: formData);
    } catch (e) {
      throw Exception('Failed to update currency: $e');
    }
  }

  Future<void> deleteCurrency(String id) async {
    try {
      await _client.delete('/monedas/$id');
    } catch (e) {
      throw Exception('Failed to delete currency: $e');
    }
  }
}

@riverpod
CurrencyRepository currencyRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  return CurrencyRepository(client);
}
