import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../models/cierre_cadena_models.dart';
import '../models/cierre_cadena_m6_models.dart';

final cierreCadenaRepositoryProvider = Provider<CierreCadenaRepository>(
  (ref) => CierreCadenaRepository(ref.watch(apiClientProvider)),
);

/// Se pidió al concentrador algo que una instalación de sede no puede dar.
///
/// Vale para el semáforo, el consolidado y el detalle de otra sede: los tres
/// contestan 409 desde la instalación, y los tres tienen que leerse como «esto
/// vive en el concentrador» y no como «no hay datos».
///
/// No es un fallo del que haya que enseñar el volcado: es una pregunta hecha en
/// el sitio equivocado, y la vista lo explica en una línea. Distinguirlo del
/// error genérico es lo que evita que el escritorio muestre «sin datos» —que se
/// lee como «ninguna sede ha cerrado»— cuando lo que pasa es que este dato vive
/// en el concentrador.
class SemaforoSoloEnElConcentrador implements Exception {
  const SemaforoSoloEnElConcentrador(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// M5 — la solicitud de cierre de la cadena y su semáforo (§6.2).
///
/// Las dos APIs publican `/cierre-cadena`, y a propósito no son la misma cosa:
/// la sede **lee** lo que se le pide y el concentrador además lo **emite** y
/// calcula el semáforo. Por eso este repositorio vale para los dos destinos: lo
/// que cambia es qué contesta cada uno, y eso ya está dicho en sus respuestas.
class CierreCadenaRepository {
  CierreCadenaRepository(this._dio);

  final Dio _dio;

  /// Las solicitudes vivas. En la sede son «lo que administración me pide».
  Future<List<SolicitudCierreModel>> getSolicitudes() async {
    try {
      final response = await _dio.get('/cierre-cadena/solicitudes');
      final lista = (response.data as Map).cast<String, dynamic>()['solicitudes'];
      return [
        for (final fila in (lista as List? ?? const []))
          SolicitudCierreModel.fromJson((fila as Map).cast<String, dynamic>()),
      ].whereType<SolicitudCierreModel>().toList(growable: false);
    } on DioException catch (e) {
      throw Exception(
        serverErrorDetail(e.response?.data) ??
            'No se pudieron leer las solicitudes de cierre.',
      );
    }
  }

  /// El semáforo del período. Solo el concentrador puede contestarlo.
  Future<SemaforoCadenaModel> getSemaforo({
    String? solicitudId,
    DateTime? desde,
    DateTime? hastaExclusivo,
  }) async {
    String fecha(DateTime valor) =>
        '${valor.year.toString().padLeft(4, '0')}-'
        '${valor.month.toString().padLeft(2, '0')}-'
        '${valor.day.toString().padLeft(2, '0')}';
    try {
      final response = await _dio.get(
        '/cierre-cadena/semaforo',
        queryParameters: {
          if (solicitudId != null) 'solicitud_id': solicitudId,
          if (solicitudId == null && desde != null) 'fecha_inicio': fecha(desde),
          if (solicitudId == null && hastaExclusivo != null)
            'fecha_fin_exclusiva': fecha(hastaExclusivo),
        },
      );
      return SemaforoCadenaModel.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      final cuerpo = e.response?.data;
      final codigo = cuerpo is Map ? cuerpo['error_code']?.toString() : null;
      if (codigo == 'SEMAFORO_CADENA_REMOTE_ONLY') {
        throw SemaforoSoloEnElConcentrador(
          serverErrorDetail(cuerpo) ??
              'El semáforo de la cadena vive en el concentrador.',
        );
      }
      throw Exception(
        serverErrorDetail(cuerpo) ?? 'No se pudo leer el semáforo de cierre.',
      );
    }
  }

  /// Emite la solicitud. Pedir dos veces el mismo período es la misma
  /// solicitud —el identificador se deriva de él—, así que reintentar no deja
  /// un aviso más en cada sede.
  Future<SolicitudCierreModel?> pedirCierre({
    required String tipoPeriodo,
    required DateTime desde,
    required DateTime hastaExclusivo,
    String? nota,
  }) async {
    try {
      final response = await _dio.post(
        '/cierre-cadena/solicitudes',
        data: {
          'tipo_periodo': tipoPeriodo,
          'fecha_inicio': desde.toUtc().toIso8601String(),
          'fecha_fin_exclusiva': hastaExclusivo.toUtc().toIso8601String(),
          if (nota != null && nota.trim().isNotEmpty) 'nota': nota.trim(),
        },
      );
      return SolicitudCierreModel.fromJson(
        ((response.data as Map).cast<String, dynamic>()['solicitud'] as Map)
            .cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw Exception(
        serverErrorDetail(e.response?.data) ??
            'No se pudo pedir el cierre del período.',
      );
    }
  }

  /// El informe agregado del período (§6.3). Cambia si llegan datos nuevos.
  Future<ConsolidadoModel> getConsolidado({
    required DateTime desde,
    required DateTime hastaExclusivo,
  }) async {
    try {
      final response = await _dio.get(
        '/cierre-cadena/consolidado',
        queryParameters: {
          'fecha_inicio': _fecha(desde),
          'fecha_fin_exclusiva': _fecha(hastaExclusivo),
        },
      );
      return ConsolidadoModel.fromJson((response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _traducir(e, 'No se pudo leer el consolidado de la cadena.');
    }
  }

  /// Los certificados firmados. `historico` trae también los anulados, que se
  /// conservan a propósito: son la prueba de lo que se cerró entonces.
  Future<List<CertificadoModel>> getCertificados({bool historico = false}) async {
    try {
      final response = await _dio.get(
        '/cierre-cadena/certificados',
        queryParameters: historico ? {'historico': 'todos'} : null,
      );
      final lista = (response.data as Map).cast<String, dynamic>()['certificados'];
      return [
        for (final fila in (lista as List? ?? const []))
          CertificadoModel.fromJson((fila as Map).cast<String, dynamic>()),
      ];
    } on DioException catch (e) {
      throw _traducir(e, 'No se pudieron leer los certificados.');
    }
  }

  /// Firma el certificado del período. `motivo` es obligatorio para rehacer uno
  /// vigente: el anterior no se pisa, se anula y se conserva.
  Future<CertificadoModel?> firmarCertificado({
    required String tipoPeriodo,
    required DateTime desde,
    required DateTime hastaExclusivo,
    String? motivo,
  }) async {
    try {
      final response = await _dio.post(
        '/cierre-cadena/certificados',
        data: {
          'tipo_periodo': tipoPeriodo,
          'fecha_inicio': _fecha(desde),
          'fecha_fin_exclusiva': _fecha(hastaExclusivo),
          if (motivo != null && motivo.trim().isNotEmpty) 'motivo': motivo.trim(),
        },
      );
      final cuerpo = (response.data as Map).cast<String, dynamic>();
      return CertificadoModel.fromJson(
        (cuerpo['certificado'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _traducir(e, 'No se pudo firmar el certificado.');
    }
  }

  /// El detalle de cobros de una sede (§6.4), en solo lectura.
  Future<DetalleSedeModel> getDetalleDeSede({
    required String gymId,
    required DateTime desde,
    required DateTime hastaExclusivo,
  }) async {
    try {
      final response = await _dio.get(
        '/cierre-cadena/detalle',
        queryParameters: {
          'gym_id': gymId,
          'fecha_inicio': _fecha(desde),
          'fecha_fin_exclusiva': _fecha(hastaExclusivo),
        },
      );
      return DetalleSedeModel.fromJson((response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _traducir(e, 'No se pudo leer el detalle de esa sede.');
    }
  }

  /// Retira la solicitud **y sus avisos**: dejarlos puestos tendría a cada sede
  /// reclamada por un cierre que ya nadie pide.
  Future<void> retirarSolicitud({
    required String solicitudId,
    required String motivo,
  }) async {
    try {
      await _dio.post(
        '/cierre-cadena/solicitudes/$solicitudId/retiro',
        data: {'motivo': motivo},
      );
    } on DioException catch (e) {
      throw Exception(
        serverErrorDetail(e.response?.data) ?? 'No se pudo retirar la solicitud.',
      );
    }
  }

  /// Fecha comercial, sin hora y sin pasar por la zona local: el servidor las
  /// guarda como días de negocio y convertirlas les resta el huso.
  String _fecha(DateTime valor) =>
      '${valor.year.toString().padLeft(4, '0')}-'
      '${valor.month.toString().padLeft(2, '0')}-'
      '${valor.day.toString().padLeft(2, '0')}';

  /// Distingue «preguntaste en el sitio equivocado» de un error de verdad.
  Object _traducir(DioException e, String porDefecto) {
    final cuerpo = e.response?.data;
    final codigo = cuerpo is Map ? cuerpo['error_code']?.toString() : null;
    if (codigo != null && codigo.endsWith('_REMOTE_ONLY')) {
      return SemaforoSoloEnElConcentrador(
        serverErrorDetail(cuerpo) ?? 'Esto vive en el concentrador.',
      );
    }
    return Exception(serverErrorDetail(cuerpo) ?? porDefecto);
  }
}
