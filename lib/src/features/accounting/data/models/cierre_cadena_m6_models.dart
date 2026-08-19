/// M6 — lo que ve contabilidad central de la cadena (docs/MULTI_SEDE.md §6.3 y
/// §6.4): el informe agregado, el certificado firmado y el detalle por sede.
///
/// Las tres se miran en el mismo sitio porque son pasos del mismo trabajo: veo
/// quién falta, miro el total, lo congelo, y si algo chirría abro el detalle de
/// la sede que lo produce.
library;

import 'cierre_cadena_models.dart' show SedeAusenteModel;

String? _texto(Object? valor) {
  final resultado = valor?.toString().trim();
  return resultado == null || resultado.isEmpty ? null : resultado;
}

/// Un **instante**: pasa a la zona de quien mira.
DateTime? _instante(Object? valor) {
  final texto = _texto(valor);
  return texto == null ? null : DateTime.tryParse(texto)?.toLocal();
}

/// Una **fecha comercial**: se queda como viene. El servidor guarda los días de
/// negocio como medianoche UTC, y convertirlos a local les resta el huso y el
/// día retrocede (visto en el recorrido de M5).
DateTime? _fechaComercial(Object? valor) {
  final texto = _texto(valor);
  final fecha = texto == null ? null : DateTime.tryParse(texto);
  return fecha == null
      ? null
      : DateTime(fecha.toUtc().year, fecha.toUtc().month, fecha.toUtc().day);
}

/// El aporte de una sede a un bloque de moneda del consolidado.
class AporteSedeModel {
  const AporteSedeModel({
    required this.gymId,
    required this.nombre,
    required this.ingreso,
    required this.cobradoCuentaAjena,
    required this.origenCierre,
  });

  final String gymId;
  final String nombre;
  final String ingreso;
  final String cobradoCuentaAjena;

  /// `MENSUAL` o `PERIODO`: de qué cierre sale la cifra, para ir a buscarla.
  final String origenCierre;

  factory AporteSedeModel.fromJson(Map<String, dynamic> json) => AporteSedeModel(
    gymId: _texto(json['gym_id']) ?? '',
    nombre: _texto(json['nombre']) ?? _texto(json['gym_id']) ?? '—',
    ingreso: _texto(json['ingreso']) ?? '0.00',
    cobradoCuentaAjena: _texto(json['cobrado_cuenta_ajena']) ?? '0.00',
    origenCierre: _texto(json['origen_cierre']) ?? 'PERIODO',
  );
}

/// Un bloque de moneda del consolidado. Los bloques **nunca** se suman entre sí.
class BloqueMonedaModel {
  const BloqueMonedaModel({
    required this.monedaId,
    required this.monedaCodigo,
    required this.ingreso,
    required this.cobradoCuentaAjena,
    required this.sedes,
  });

  final String monedaId;
  final String monedaCodigo;
  final String ingreso;

  /// Efectivo cobrado por cuenta de otro. **No** está dentro de `ingreso`:
  /// sumarlo contaría dos veces el mismo dinero (§6.3).
  final String cobradoCuentaAjena;
  final List<AporteSedeModel> sedes;

  bool get tieneAjeno => cobradoCuentaAjena != '0.00';

  factory BloqueMonedaModel.fromJson(Map<String, dynamic> json) => BloqueMonedaModel(
    monedaId: _texto(json['moneda_id']) ?? '',
    monedaCodigo: _texto(json['moneda_codigo']) ?? _texto(json['moneda_id']) ?? '—',
    ingreso: _texto(json['ingreso']) ?? '0.00',
    cobradoCuentaAjena: _texto(json['cobrado_cuenta_ajena']) ?? '0.00',
    sedes: [
      for (final fila in (json['sedes'] as List? ?? const []))
        AporteSedeModel.fromJson((fila as Map).cast<String, dynamic>()),
    ],
  );
}

/// El informe agregado del período (§6.3). Cambia si llegan datos nuevos.
class ConsolidadoModel {
  const ConsolidadoModel({
    required this.clase,
    required this.monedas,
    required this.ausentes,
    required this.sedesIncluidas,
    required this.avisos,
    this.motivoParaNoFirmar,
  });

  final String clase;
  final List<BloqueMonedaModel> monedas;
  final List<SedeAusenteModel> ausentes;
  final int sedesIncluidas;

  /// Lo que los cierres incluidos **no pueden afirmar**. Quien firme lo ve.
  final List<String> avisos;
  final String? motivoParaNoFirmar;

  bool get esParcial => clase == 'PARCIAL_DECLARADO';
  bool get sePuedeFirmar => motivoParaNoFirmar == null;

  factory ConsolidadoModel.fromJson(Map<String, dynamic> json) => ConsolidadoModel(
    clase: _texto(json['clase']) ?? 'COMPLETO',
    monedas: [
      for (final fila in (json['monedas'] as List? ?? const []))
        BloqueMonedaModel.fromJson((fila as Map).cast<String, dynamic>()),
    ],
    ausentes: [
      for (final fila in (json['ausentes'] as List? ?? const []))
        SedeAusenteModel.fromJson((fila as Map).cast<String, dynamic>()),
    ],
    sedesIncluidas: (json['sedes_incluidas'] as num?)?.toInt() ?? 0,
    avisos: [
      for (final aviso in (json['avisos'] as List? ?? const [])) aviso.toString(),
    ],
    motivoParaNoFirmar: _texto(json['motivo_para_no_firmar']),
  );
}

/// La foto congelada de un período (§6.4). Esta no cambia.
class CertificadoModel {
  const CertificadoModel({
    required this.certificadoId,
    required this.cicloNumero,
    required this.clase,
    required this.estado,
    required this.sedesIncluidas,
    required this.sha256,
    this.fechaInicio,
    this.fechaFinExclusiva,
    this.firmadoPor,
    this.firmadoAt,
    this.anuladoMotivo,
    this.integro,
  });

  final String certificadoId;
  final int cicloNumero;
  final String clase;
  final String estado;
  final int sedesIncluidas;
  final String sha256;
  final DateTime? fechaInicio;
  final DateTime? fechaFinExclusiva;
  final String? firmadoPor;
  final DateTime? firmadoAt;
  final String? anuladoMotivo;

  /// Si el sello cuadra con la foto guardada. Se comprueba **al leer**: un sello
  /// que solo se mira el día que se pone no protege de nada.
  final bool? integro;

  bool get vigente => estado == 'VIGENTE';
  bool get esParcial => clase == 'PARCIAL_DECLARADO';

  /// Último día incluido, que es lo que el operador entiende por «hasta».
  DateTime? get ultimoDiaIncluido =>
      fechaFinExclusiva?.subtract(const Duration(days: 1));

  factory CertificadoModel.fromJson(Map<String, dynamic> json) => CertificadoModel(
    certificadoId: _texto(json['certificado_id']) ?? '',
    cicloNumero: (json['ciclo_numero'] as num?)?.toInt() ?? 1,
    clase: _texto(json['clase']) ?? 'COMPLETO',
    estado: _texto(json['estado']) ?? 'VIGENTE',
    sedesIncluidas: (json['sedes_incluidas'] as num?)?.toInt() ?? 0,
    sha256: _texto(json['foto_sha256']) ?? '',
    fechaInicio: _fechaComercial(json['fecha_inicio']),
    fechaFinExclusiva: _fechaComercial(json['fecha_fin_exclusiva']),
    firmadoPor: _texto(json['firmado_por']),
    firmadoAt: _instante(json['firmado_at']),
    anuladoMotivo: _texto(json['anulado_motivo']),
    integro: json['integro'] is bool ? json['integro'] as bool : null,
  );
}

/// Un cobro del detalle, con lo que es **para la sede que se está mirando**.
class CobroDetalleModel {
  const CobroDetalleModel({
    required this.pagoClienteId,
    required this.monedaId,
    required this.monto,
    required this.clase,
    required this.anulado,
    this.ocurridoAt,
    this.ci,
    this.plan,
    this.cobrador,
  });

  final String pagoClienteId;
  final String monedaId;
  final String monto;

  /// `INGRESO_Y_EFECTIVO`, `SOLO_INGRESO` o `SOLO_EFECTIVO`.
  final String clase;
  final bool anulado;
  final DateTime? ocurridoAt;
  final String? ci;
  final String? plan;
  final String? cobrador;

  /// Dicho con palabras, no con un código: quien audita no tiene por qué
  /// aprenderse el vocabulario del esquema.
  String get rotuloClase => switch (clase) {
    'SOLO_INGRESO' => 'Suyo · el dinero está en otra caja',
    'SOLO_EFECTIVO' => 'En su caja · el ingreso es de otra sede',
    _ => 'Suyo y en su caja',
  };

  factory CobroDetalleModel.fromJson(Map<String, dynamic> json) => CobroDetalleModel(
    pagoClienteId: _texto(json['pago_cliente_id']) ?? '',
    monedaId: _texto(json['moneda_id']) ?? '',
    monto: _texto(json['monto']) ?? '0.00',
    clase: _texto(json['clase']) ?? 'INGRESO_Y_EFECTIVO',
    anulado: json['anulado'] == true,
    ocurridoAt: _instante(json['ocurrido_at']),
    ci: _texto(json['ci']),
    plan: _texto(json['plan']),
    cobrador: _texto(json['cobrador']),
  );
}

class TotalDetalleModel {
  const TotalDetalleModel({
    required this.monedaId,
    required this.ingreso,
    required this.efectivo,
    required this.cobradoCuentaAjena,
    required this.cobros,
    required this.anulados,
  });

  final String monedaId;

  /// Lo que la sede ganó.
  final String ingreso;

  /// Lo que pasó por su caja, sea suyo el ingreso o no.
  final String efectivo;
  final String cobradoCuentaAjena;
  final int cobros;
  final int anulados;

  factory TotalDetalleModel.fromJson(Map<String, dynamic> json) => TotalDetalleModel(
    monedaId: _texto(json['moneda_id']) ?? '',
    ingreso: _texto(json['ingreso']) ?? '0.00',
    efectivo: _texto(json['efectivo']) ?? '0.00',
    cobradoCuentaAjena: _texto(json['cobrado_cuenta_ajena']) ?? '0.00',
    cobros: (json['cobros'] as num?)?.toInt() ?? 0,
    anulados: (json['anulados'] as num?)?.toInt() ?? 0,
  );
}

/// El detalle de una sede (§6.4), en solo lectura.
class DetalleSedeModel {
  const DetalleSedeModel({
    required this.gymId,
    required this.nombre,
    required this.origen,
    required this.nota,
    required this.totales,
    required this.cobros,
    this.cerradoAt,
    this.cerradoPor,
  });

  final String gymId;
  final String nombre;

  /// `CIERRE_FIRMADO` o `EN_VIVO`. Un listado en vivo cambia mañana, y quien lo
  /// imprima para discutir una cifra tiene que saber cuál está mirando.
  final String origen;
  final String nota;
  final List<TotalDetalleModel> totales;
  final List<CobroDetalleModel> cobros;
  final DateTime? cerradoAt;
  final String? cerradoPor;

  bool get esFirmado => origen == 'CIERRE_FIRMADO';

  factory DetalleSedeModel.fromJson(Map<String, dynamic> json) {
    final sede = (json['sede'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cierre = (json['cierre'] as Map?)?.cast<String, dynamic>();
    return DetalleSedeModel(
      gymId: _texto(sede['gym_id']) ?? '',
      nombre: _texto(sede['nombre']) ?? '—',
      origen: _texto(json['origen']) ?? 'EN_VIVO',
      nota: _texto(json['nota']) ?? '',
      totales: [
        for (final fila in (json['totales'] as List? ?? const []))
          TotalDetalleModel.fromJson((fila as Map).cast<String, dynamic>()),
      ],
      cobros: [
        for (final fila in (json['cobros'] as List? ?? const []))
          CobroDetalleModel.fromJson((fila as Map).cast<String, dynamic>()),
      ],
      cerradoAt: _instante(cierre?['cerrado_at']),
      cerradoPor: _texto(cierre?['cerrado_por']),
    );
  }
}
