import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../models/multisede_access_model.dart';

final multisedeAccessRepositoryProvider = Provider<MultisedeAccessRepository>(
  (ref) => MultisedeAccessRepository(ref.watch(apiClientProvider)),
);

/// Acceso multi-sede: el plus del socio y su precio de cadena (M4a).
///
/// Propaga el `error` del cuerpo en vez de dejar salir el `DioException`, como
/// hacen sus vecinos desde el 13-08: los rechazos de este recurso llevan texto
/// útil —«no tiene precio configurado», «el socio pertenece a otra sede»— y
/// enseñar el volcado técnico en su lugar es tirar lo único que el operador
/// puede usar.
class MultisedeAccessRepository {
  MultisedeAccessRepository(this._dio);

  final Dio _dio;

  Future<MultisedePriceModel?> getPrecio() async {
    final response = await _dio.get('/acceso-multisede/precio');
    return MultisedePriceModel.fromJson(
      (response.data as Map).cast<String, dynamic>()['precio']
          as Map<String, dynamic>?,
    );
  }

  /// Socios de otras sedes a los que esta instalación puede atender.
  ///
  /// El mostrador los necesita para poder **encontrarlos**: su identificación
  /// busca en el padrón de la sede, y un visitante no está ahí por definición.
  Future<List<VisitanteModel>> getVisitantes() async {
    final response = await _dio.get("/acceso-multisede/visitantes");
    final lista = (response.data as Map).cast<String, dynamic>()["visitantes"];
    return [
      for (final fila in (lista as List? ?? const []))
        VisitanteModel.fromJson((fila as Map).cast<String, dynamic>()),
    ];
  }

  Future<MultisedeAccessModel?> getAcceso(String ci) async {
    final response = await _dio.get('/acceso-multisede/clientes/$ci');
    return MultisedeAccessModel.fromJson(
      (response.data as Map).cast<String, dynamic>()['acceso']
          as Map<String, dynamic>?,
    );
  }

  /// Concede el plus **sin cobrarlo**.
  ///
  /// Desde M4b la vista no lo usa: el botón del panel cobra. Se conserva
  /// porque el endpoint sigue existiendo para una corrección o una cortesía, y
  /// borrarlo aquí obligaría a reescribirlo el día que haga falta esa pantalla.
  /// Renovar antes de tiempo **encadena**: el mes nuevo empieza donde termina
  /// el vigente, no hoy.
  Future<MultisedeAccessModel?> marcar(String ci) async {
    try {
      final response = await _dio.post('/acceso-multisede/clientes/$ci');
      return MultisedeAccessModel.fromJson(
        (response.data as Map).cast<String, dynamic>()['acceso']
            as Map<String, dynamic>?,
      );
    } on DioException catch (e) {
      throw Exception(serverErrorDetail(e.response?.data) ?? 'No se pudo activar el acceso multi-sede.');
    }
  }

  /// **Cobra** el plus (M4b): extiende la vigencia y toma el dinero.
  ///
  /// Distinto de `marcar`, que concede sin cobrar. Son dos operaciones y no una
  /// con bandera: un solo camino que a veces mueve dinero y a veces no, según
  /// lo que lleve el cuerpo, es imposible de auditar después.
  ///
  /// Funciona sin conexión en el escritorio: la cola lo lleva al concentrador
  /// cuando vuelva. Obligar a abrir la web dejaría al socio esperando.
  Future<({MultisedeAccessModel? acceso, MultisedeCobroModel? cobro})> cobrar(
    String ci, {
    String? cuentaId,
    String? tipoPagoId,
  }) async {
    try {
      final response = await _dio.post(
        '/acceso-multisede/clientes/$ci/cobro',
        data: {'cuenta_id': cuentaId, 'tipo_pago_id': tipoPagoId},
      );
      final cuerpo = (response.data as Map).cast<String, dynamic>();
      return (
        acceso: MultisedeAccessModel.fromJson(
          cuerpo['acceso'] as Map<String, dynamic>?,
        ),
        cobro: MultisedeCobroModel.fromJson(
          cuerpo['cobro'] as Map<String, dynamic>?,
        ),
      );
    } on DioException catch (e) {
      throw Exception(
        serverErrorDetail(e.response?.data) ?? 'No se pudo cobrar el acceso multi-sede.',
      );
    }
  }

  Future<MultisedeAccessModel?> retirar(String ci) async {
    try {
      final response = await _dio.delete('/acceso-multisede/clientes/$ci');
      return MultisedeAccessModel.fromJson(
        (response.data as Map).cast<String, dynamic>()['acceso']
            as Map<String, dynamic>?,
      );
    } on DioException catch (e) {
      throw Exception(serverErrorDetail(e.response?.data) ?? 'No se pudo retirar el acceso multi-sede.');
    }
  }

  /// Qué se le cobraría hoy a un visitante (M4c), **sin cobrar nada**.
  ///
  /// El mostrador lo necesita antes de pulsar: enseñar el importe después de
  /// haberlo cobrado no sirve para decidir. En la instalación se responde con
  /// lo que hay en su base, así que funciona sin conexión.
  Future<CotizacionVisitaRespuesta> getCotizacionVisita(String ci) async {
    final response = await _dio.get('/acceso-multisede/visitantes/$ci/cotizacion');
    return CotizacionVisitaRespuesta.fromJson(
      (response.data as Map).cast<String, dynamic>(),
    );
  }

  /// Cobra el plan de un visitante: el efectivo entra aquí, el ingreso es de su
  /// sede. El método de pago es obligatorio —el detalle dice CÓMO se pagó—; la
  /// cuenta no, porque el efectivo se apunta en la tesorería de esta sede.
  Future<CobroCruzadoModel?> cobrarVisitante(
    String ci, {
    required String tipoPagoId,
    String? cuentaId,
  }) async {
    try {
      final response = await _dio.post(
        '/acceso-multisede/visitantes/$ci/cobro',
        data: {'tipo_pago_id': tipoPagoId, 'cuenta_id': cuentaId},
      );
      return CobroCruzadoModel.fromJson(
        ((response.data as Map).cast<String, dynamic>()['cobro'] as Map)
            .cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw Exception(
        serverErrorDetail(e.response?.data) ?? 'No se pudo cobrar al visitante.',
      );
    }
  }

  /// Fija el precio de cadena. La instalación responde 409
  /// `GLOBAL_CATALOG_REMOTE_ONLY`: esto solo tiene efecto desde la web y con
  /// autoridad de Dueño.
  Future<MultisedePriceModel?> fijarPrecio({
    required double precio,
    required String monedaId,
  }) async {
    try {
      final response = await _dio.put(
        '/acceso-multisede/precio',
        data: {'precio': precio.toStringAsFixed(2), 'moneda_id': monedaId},
      );
      return MultisedePriceModel.fromJson(
        (response.data as Map).cast<String, dynamic>()['precio']
            as Map<String, dynamic>?,
      );
    } on DioException catch (e) {
      throw Exception(serverErrorDetail(e.response?.data) ?? 'No se pudo fijar el precio.');
    }
  }
}

/// Precio vigente del plus. Se lee en las dos superficies: la instalación lo
/// necesita para decir cuánto cuesta antes de venderlo.
final multisedePrecioProvider = FutureProvider<MultisedePriceModel?>(
  (ref) => ref.watch(multisedeAccessRepositoryProvider).getPrecio(),
);

/// Qué se le cobraría a un visitante concreto.
final cotizacionVisitaProvider =
    FutureProvider.family<CotizacionVisitaRespuesta, String>(
      (ref, ci) =>
          ref.watch(multisedeAccessRepositoryProvider).getCotizacionVisita(ci),
    );

/// Visitantes que esta sede puede atender hoy.
final visitantesProvider = FutureProvider<List<VisitanteModel>>(
  (ref) => ref.watch(multisedeAccessRepositoryProvider).getVisitantes(),
);

/// Acceso de un socio concreto.
final multisedeAccesoProvider =
    FutureProvider.family<MultisedeAccessModel?, String>(
      (ref, ci) => ref.watch(multisedeAccessRepositoryProvider).getAcceso(ci),
    );
