import '../../../../core/money/decimal_json.dart';

/// Acceso multi-sede de un socio: el «plus» que le deja entrenar en cualquier
/// sede de la cadena (M4a, docs/MULTI_SEDE.md §5 y §9-bis).
///
/// `vigente` **lo decide el servidor**, no esta clase. Es la misma razón por la
/// que la vigencia de una membresía se deriva y no se guarda: la fecha de
/// negocio es la del gimnasio, no la del equipo que abre la aplicación, y un
/// cálculo aquí diría «vigente» a medianoche de otro huso.
class MultisedeAccessModel {
  const MultisedeAccessModel({
    required this.id,
    required this.ci,
    required this.gymIdOrigen,
    required this.activo,
    required this.vigenteHasta,
    required this.vigente,
    required this.precioSnapshot,
    required this.monedaId,
    required this.marcadoPorUserId,
    required this.marcadoEnGymId,
    required this.version,
    required this.fechaNegocio,
  });

  final String id;
  final String ci;

  /// Sede dueña del socio. Puede no ser la sede en la que se está mirando.
  final String? gymIdOrigen;
  final bool activo;
  final DateTime vigenteHasta;

  /// Si cubre hoy, según la fecha de negocio del gimnasio.
  final bool vigente;

  /// Precio congelado al venderlo: subir la tarifa no reescribe lo ya cobrado.
  final double precioSnapshot;
  final String monedaId;
  final String marcadoPorUserId;
  final String marcadoEnGymId;
  final int version;

  /// Fecha de negocio **de la sede**, tal y como la calcula el servidor.
  ///
  /// La vista no la deduce del reloj del equipo: un socio de una sede en
  /// America/Los_Angeles atendido a las 23:00 estaría ya en «mañana» según UTC,
  /// y el periodo que la confirmación promete saldría desplazado un día
  /// respecto al que el servidor cobra. Pasó en el recorrido del 17-08-2026.
  final DateTime? fechaNegocio;

  static MultisedeAccessModel? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return MultisedeAccessModel(
      id: json['cliente_acceso_multisede_id'] as String,
      ci: json['ci'] as String,
      gymIdOrigen: json['gym_id'] as String?,
      activo: json['activo'] == true,
      vigenteHasta: DateTime.parse(json['vigente_hasta'] as String).toUtc(),
      vigente: json['vigente'] == true,
      // Prisma manda el decimal como texto exacto y las APIs viejas lo
      // mandaban como número: el adaptador de MONEY-01 acepta los dos.
      precioSnapshot: decimalJsonToDouble(json['precio_snapshot']),
      monedaId: json['moneda_id'] as String? ?? '',
      marcadoPorUserId: json['marcado_por_user_id'] as String? ?? '',
      marcadoEnGymId: json['marcado_en_gym_id'] as String? ?? '',
      version: (json['version'] as num?)?.toInt() ?? 1,
      fechaNegocio: json['fecha_negocio'] == null
          ? null
          : DateTime.parse(json['fecha_negocio'] as String).toUtc(),
    );
  }
}

/// Precio del plus, global para toda la cadena. Solo lo cambia el Dueño desde
/// la web; la instalación lo consume en solo lectura, como el resto de
/// catálogos globales desde M3.
class MultisedePriceModel {
  const MultisedePriceModel({required this.precio, required this.monedaId});

  final double precio;
  final String monedaId;

  static MultisedePriceModel? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return MultisedePriceModel(
      precio: decimalJsonToDouble(json['precio']),
      monedaId: json['moneda_id'] as String? ?? '',
    );
  }
}

/// Socio de otra sede que esta instalación puede atender (M4a).
///
/// Lleva lo justo para reconocerlo en el mostrador y decidir: identidad, de
/// dónde viene y si su plus cubre hoy. Ni pagos, ni plan, ni historial — eso
/// se queda en su sede.
class VisitanteModel {
  const VisitanteModel({
    required this.ci,
    required this.nombres,
    required this.apellidos,
    required this.gymIdOrigen,
    required this.accesoVigente,
    this.membresiaEstado,
    this.membresiaFechaFin,
  });

  final String ci;
  final String nombres;
  final String apellidos;
  final String gymIdOrigen;

  /// Lo decide el servidor contra la fecha de negocio de la sede.
  final bool accesoVigente;
  final String? membresiaEstado;
  final DateTime? membresiaFechaFin;

  String get nombreCompleto => '$nombres $apellidos'.trim();

  static VisitanteModel fromJson(Map<String, dynamic> json) => VisitanteModel(
    ci: json['ci'] as String,
    nombres: json['nombres'] as String? ?? '',
    apellidos: json['apellidos'] as String? ?? '',
    gymIdOrigen: json['gym_id_origen'] as String? ?? '',
    accesoVigente: json['acceso_vigente'] == true,
    membresiaEstado: json['membresia_estado'] as String?,
    membresiaFechaFin: json['membresia_fecha_fin'] == null
        ? null
        : DateTime.parse(json['membresia_fecha_fin'] as String).toUtc(),
  );
}

/// Cobro del plus multi-sede (M4b, docs/MULTI_SEDE.md §5.1).
///
/// Lleva el **periodo comprado** y no solo el importe, y es a propósito:
/// renovar antes de tiempo encadena desde el fin vigente, así que sin esas dos
/// fechas el socio no puede comprobar qué mes acaba de pagar.
///
/// `ingresoDe` es lo que separa este cobro de cualquier otro: el efectivo entró
/// en la caja de la sede, pero el ingreso es de la cadena. La vista lo dice con
/// esas palabras para que nadie sume mal.
class MultisedeCobroModel {
  const MultisedeCobroModel({
    required this.cobroId,
    required this.ci,
    required this.importe,
    required this.monedaId,
    required this.cubreDesde,
    required this.cubreHasta,
    required this.cobradoEnGymId,
    required this.ingresoDe,
  });

  final String cobroId;
  final String ci;
  final double importe;
  final String monedaId;
  final DateTime cubreDesde;

  /// Exclusiva, igual que `vigente_hasta`: ese día ya no cubre.
  final DateTime cubreHasta;
  final String cobradoEnGymId;

  /// `CADENA` hoy. Cuando M4c traiga el cobro cruzado, será una sede.
  final String ingresoDe;

  static MultisedeCobroModel? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return MultisedeCobroModel(
      cobroId: json['cobro_id'] as String,
      ci: json['ci'] as String? ?? '',
      importe: decimalJsonToDouble(json['importe']),
      monedaId: json['moneda_id'] as String? ?? '',
      cubreDesde: DateTime.parse(json['cubre_desde'] as String).toUtc(),
      cubreHasta: DateTime.parse(json['cubre_hasta'] as String).toUtc(),
      cobradoEnGymId: json['cobrado_en_gym_id'] as String? ?? '',
      ingresoDe: json['ingreso_de'] as String? ?? 'CADENA',
    );
  }
}
