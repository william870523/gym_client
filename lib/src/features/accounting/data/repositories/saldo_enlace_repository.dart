import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../models/saldo_enlace_models.dart';

final saldoEnlaceRepositoryProvider = Provider<SaldoEnlaceRepository>(
  (ref) => SaldoEnlaceRepository(ref.watch(apiClientProvider)),
);

/// Se intentó registrar una liquidación desde una instalación de sede.
///
/// La transferencia toca **dos negocios**: uno declara que pagó y el otro que
/// cobró. Si la sede deudora pudiera anotarla sola, podría declararse al día sin
/// que la acreedora se enterara. Quien arbitra es el concentrador.
///
/// Se distingue del error genérico para poder decirlo así en la vista: un fallo
/// sin explicación manda a buscar el problema al sitio equivocado.
class LiquidacionSoloEnElConcentrador implements Exception {
  const LiquidacionSoloEnElConcentrador(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// M8 — el saldo entre sedes y su liquidación (docs/MULTI_SEDE.md §5.4).
///
/// Las dos APIs publican `/saldo-enlace`, y no son la misma cosa: la sede lee
/// **lo suyo** —y puede leerlo sin conexión, porque sus asientos están en su
/// base— mientras que el concentrador lee el de cualquier sede y además
/// registra la transferencia. Por eso este repositorio vale para los dos
/// destinos: `gymId` solo viaja cuando hay a quién preguntárselo.
class SaldoEnlaceRepository {
  SaldoEnlaceRepository(this._dio);

  final Dio _dio;

  /// Lo que una sede debe. Sin `gymId`, la instalación contesta lo suyo.
  Future<SaldoSedeModel> getSaldo({String? gymId}) async {
    try {
      final response = await _dio.get(
        '/saldo-enlace/pendientes',
        queryParameters: {if (gymId != null) 'gym_id': gymId},
      );
      return SaldoSedeModel.fromJson((response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw Exception(
        serverErrorDetail(e.response?.data) ??
            'No se pudo leer el saldo entre sedes.',
      );
    }
  }

  /// Lo que esa sede ya ha liquidado, de lo más reciente a lo más antiguo.
  Future<List<LiquidacionModel>> getLiquidaciones({String? gymId}) async {
    try {
      final response = await _dio.get(
        '/saldo-enlace/liquidaciones',
        queryParameters: {if (gymId != null) 'gym_id': gymId},
      );
      final lista = (response.data as Map).cast<String, dynamic>()['liquidaciones'];
      return [
        for (final fila in (lista as List? ?? const []))
          LiquidacionModel.fromJson((fila as Map).cast<String, dynamic>()),
      ];
    } on DioException catch (e) {
      throw Exception(
        serverErrorDetail(e.response?.data) ??
            'No se pudieron leer las liquidaciones.',
      );
    }
  }

  /// Registra que la sede transfirió lo que debía.
  ///
  /// `liquidacionId` lo pone quien llama para poder **reintentar**: si la
  /// respuesta se pierde por el camino, repetir con el mismo identificador
  /// devuelve la que ya se registró en vez de anotar el pago dos veces. Sin eso,
  /// quien no vio la confirmación vuelve a darle al botón y la sede acaba
  /// habiendo «liquidado» el doble de lo que transfirió.
  Future<LiquidacionHechaModel> liquidar({
    required String liquidacionId,
    required String gymId,
    required AcreedorModel acreedor,
    required String monedaId,
    required String monto,
    bool aceptaDejarSaldoAFavor = false,
    String? referencia,
    String? nota,
  }) async {
    try {
      final response = await _dio.post(
        '/saldo-enlace/liquidaciones',
        data: {
          'liquidacion_id': liquidacionId,
          'gym_id': gymId,
          ...acreedor.aCuerpo(),
          'moneda_id': monedaId,
          'monto': monto,
          if (aceptaDejarSaldoAFavor) 'acepta_dejar_saldo_a_favor': true,
          if (referencia != null && referencia.trim().isNotEmpty)
            'referencia': referencia.trim(),
          if (nota != null && nota.trim().isNotEmpty) 'nota': nota.trim(),
        },
      );
      return LiquidacionHechaModel.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      final cuerpo = e.response?.data;
      final codigo = cuerpo is Map ? cuerpo['error_code']?.toString() : null;
      if (codigo == 'LIQUIDACION_SALDO_REMOTE_ONLY') {
        throw LiquidacionSoloEnElConcentrador(
          serverErrorDetail(cuerpo) ??
              'Registrar la liquidación es de la cadena: lo arbitra el concentrador.',
        );
      }
      throw Exception(
        serverErrorDetail(cuerpo) ?? 'No se pudo registrar la liquidación.',
      );
    }
  }

  /// Anula una liquidación: la marca y la **contraasienta**.
  ///
  /// No la borra. La transferencia ocurrió de verdad, y hacerla desaparecer
  /// dejaría el saldo cuadrando por casualidad y sin nadie a quien preguntarle.
  /// El motivo es obligatorio, y el servidor lo rechaza si falta.
  Future<void> anular({
    required String liquidacionId,
    required String motivo,
  }) async {
    try {
      await _dio.post(
        '/saldo-enlace/liquidaciones/$liquidacionId/anulacion',
        data: {'motivo': motivo.trim()},
      );
    } on DioException catch (e) {
      final cuerpo = e.response?.data;
      final codigo = cuerpo is Map ? cuerpo['error_code']?.toString() : null;
      if (codigo == 'LIQUIDACION_SALDO_REMOTE_ONLY') {
        throw LiquidacionSoloEnElConcentrador(
          serverErrorDetail(cuerpo) ??
              'Anular la liquidación es de la cadena: lo arbitra el concentrador.',
        );
      }
      throw Exception(
        serverErrorDetail(cuerpo) ?? 'No se pudo anular la liquidación.',
      );
    }
  }
}
