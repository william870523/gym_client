import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/flag_image.dart';
import '../models/nacionalidad_model.dart';

class NacionalidadRepository {
  final Dio _dio;

  NacionalidadRepository(this._dio);

  Future<List<NacionalidadModel>> getNacionalidades() async {
    try {
      final response = await _dio.get('/nacionalidades');

      if (response.data == null) return [];

      final List<dynamic> data = response.data is List ? response.data : [];

      return data.map((e) {
        // Defensive: If backend returns Buffer object instead of formatted string, clean it up
        if (e is Map<String, dynamic> &&
            e.containsKey('bandera') &&
            e['bandera'] is! String) {
          e['bandera'] = null; // Prevent deserialization crash
        }
        return NacionalidadModel.fromJson(e);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[REPO] Error fetching nacionalidades: $e');
      }
      throw Exception('Failed to fetch nacionalidades: $e');
    }
  }

  Future<NacionalidadModel> createNacionalidad(
    NacionalidadModel nacionalidad, {
    Uint8List? flagBytes,
  }) async {
    try {
      final map = nacionalidad.toJson();
      // Remove base64 string if present, we rely on flagBytes for upload
      map.remove('bandera');

      final formData = FormData.fromMap(map);

      if (flagBytes != null) {
        formData.files.add(
          MapEntry(
            'bandera_file',
            MultipartFile.fromBytes(
              flagBytes,
              filename: flagUploadFilename(flagBytes),
            ),
          ),
        );
      }

      final response = await _dio.post('/nacionalidades', data: formData);
      return NacionalidadModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create nacionalidad: $e');
    }
  }

  Future<void> updateNacionalidad(
    NacionalidadModel nacionalidad, {
    Uint8List? flagBytes,
  }) async {
    try {
      final map = nacionalidad.toJson();
      map.remove('bandera');

      final formData = FormData.fromMap(map);

      if (flagBytes != null) {
        formData.files.add(
          MapEntry(
            'bandera_file',
            MultipartFile.fromBytes(
              flagBytes,
              filename: flagUploadFilename(flagBytes),
            ),
          ),
        );
      }

      await _dio.put('/nacionalidades/${nacionalidad.id}', data: formData);
    } catch (e) {
      throw Exception('Failed to update nacionalidad: $e');
    }
  }

  Future<void> deleteNacionalidad(String id) async {
    try {
      await _dio.delete('/nacionalidades/$id');
    } catch (e) {
      throw Exception('Failed to delete nacionalidad: $e');
    }
  }
}

final nacionalidadRepositoryProvider = Provider<NacionalidadRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return NacionalidadRepository(dio);
});
