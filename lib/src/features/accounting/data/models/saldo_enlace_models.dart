/// M8 — el saldo entre sedes y su liquidación (docs/MULTI_SEDE.md §5.4).
///
/// Los importes viajan y se guardan **como texto decimal** de punta a punta
/// (MONEY-01). Aquí no se convierten a `double` ni para ordenar: en coma
/// flotante, a partir de cierto volumen de asientos se pierden centavos, y un
/// saldo entre sedes es exactamente donde eso acaba en una discusión.
library;

String? _texto(Object? valor) {
  if (valor == null) return null;
  final texto = valor.toString().trim();
  return texto.isEmpty ? null : texto;
}

DateTime? _instante(Object? valor) {
  final texto = _texto(valor);
  return texto == null ? null : DateTime.tryParse(texto)?.toLocal();
}

/// A quién se le debe. La cadena no es una sede más, y por eso no lleva `gymId`.
class AcreedorModel {
  const AcreedorModel({
    required this.tipo,
    required this.nombre,
    this.gymId,
  });

  final String tipo;
  final String nombre;
  final String? gymId;

  bool get esCadena => tipo == 'CADENA';

  factory AcreedorModel.fromJson(Map<String, dynamic> json) => AcreedorModel(
    tipo: _texto(json['tipo']) ?? 'SEDE',
    nombre: _texto(json['nombre']) ?? _texto(json['gym_id']) ?? '—',
    gymId: _texto(json['gym_id']),
  );

  /// Lo que el servidor espera de vuelta para saber a quién se paga.
  Map<String, dynamic> aCuerpo() => {
    'acreedor_tipo': tipo,
    if (!esCadena) 'acreedor_gym_id': gymId,
  };
}

/// Una línea del saldo: lo que una sede le debe a un acreedor en una moneda.
class LineaSaldoModel {
  const LineaSaldoModel({
    required this.acreedor,
    required this.monedaId,
    required this.saldo,
    required this.generado,
    required this.deshecho,
    required this.asientos,
  });

  final AcreedorModel acreedor;
  final String monedaId;

  /// Lo que se debe. Negativo = ya se pagó de más y queda a favor.
  final String saldo;

  /// Lo que nació de cobros y lo que se ha ido deshaciendo, para cuadrar a mano.
  final String generado;
  final String deshecho;
  final int asientos;

  bool get aFavor => saldo.startsWith('-');
  bool get saldado => !aFavor && double.tryParse(saldo) == 0;

  factory LineaSaldoModel.fromJson(Map<String, dynamic> json) => LineaSaldoModel(
    acreedor: AcreedorModel.fromJson(
      ((json['acreedor'] as Map?) ?? const {}).cast<String, dynamic>(),
    ),
    monedaId: _texto(json['moneda_id']) ?? '',
    saldo: _texto(json['saldo']) ?? '0.00',
    generado: _texto(json['generado']) ?? '0.00',
    deshecho: _texto(json['deshecho']) ?? '0.00',
    asientos: (json['asientos'] as num?)?.toInt() ?? 0,
  );
}

/// El saldo de una sede: lo vivo y lo completo.
///
/// Llegan las dos listas a propósito. `pendientes` es lo que se puede liquidar;
/// `lineas` incluye además las saldadas y las pagadas de más, porque una línea
/// en cero no se puede liquidar pero desaparecerla sin más deja a quien busca
/// una deuda que recuerda haber visto pensando que se perdió.
class SaldoSedeModel {
  const SaldoSedeModel({
    required this.gymId,
    required this.nombre,
    required this.pendientes,
    required this.lineas,
  });

  final String gymId;
  final String nombre;
  final List<LineaSaldoModel> pendientes;
  final List<LineaSaldoModel> lineas;

  bool get sinDeuda => pendientes.isEmpty;

  factory SaldoSedeModel.fromJson(Map<String, dynamic> json) {
    final sede = ((json['sede'] as Map?) ?? const {}).cast<String, dynamic>();
    List<LineaSaldoModel> leer(Object? lista) => [
      for (final fila in (lista as List? ?? const []))
        LineaSaldoModel.fromJson((fila as Map).cast<String, dynamic>()),
    ];
    return SaldoSedeModel(
      gymId: _texto(sede['gym_id']) ?? '',
      nombre: _texto(sede['nombre']) ?? _texto(sede['gym_id']) ?? '—',
      pendientes: leer(json['pendientes']),
      lineas: leer(json['lineas']),
    );
  }
}

/// Una transferencia ya registrada.
class LiquidacionModel {
  const LiquidacionModel({
    required this.liquidacionId,
    required this.acreedor,
    required this.monedaId,
    required this.monto,
    required this.saldoAntes,
    required this.saldoDespues,
    required this.dejoSaldoAFavor,
    required this.registradaPor,
    this.referencia,
    this.nota,
    this.ocurridoAt,
  });

  final String liquidacionId;
  final AcreedorModel acreedor;
  final String monedaId;
  final String monto;

  /// Lo que se debía cuando se registró. Si mañana aparece un cobro atrasado el
  /// saldo recalculado cambia, y esta foto es lo único que explica por qué se
  /// transfirió esa cifra y no otra.
  final String saldoAntes;
  final String saldoDespues;
  final bool dejoSaldoAFavor;

  /// Quién la registró, congelado: no cambia si a esa persona la renombran.
  final String registradaPor;
  final String? referencia;
  final String? nota;
  final DateTime? ocurridoAt;

  factory LiquidacionModel.fromJson(Map<String, dynamic> json) {
    final actor = ((json['registrado_por'] as Map?) ?? const {}).cast<String, dynamic>();
    return LiquidacionModel(
      liquidacionId: _texto(json['liquidacion_id']) ?? '',
      acreedor: AcreedorModel.fromJson(
        ((json['acreedor'] as Map?) ?? const {}).cast<String, dynamic>(),
      ),
      monedaId: _texto(json['moneda_id']) ?? '',
      monto: _texto(json['monto']) ?? '0.00',
      saldoAntes: _texto(json['saldo_antes']) ?? '0.00',
      saldoDespues: _texto(json['saldo_despues']) ?? '0.00',
      dejoSaldoAFavor: json['dejo_saldo_a_favor'] == true,
      registradaPor: _texto(actor['nombre']) ?? _texto(actor['user_id']) ?? '—',
      referencia: _texto(json['referencia']),
      nota: _texto(json['nota']),
      ocurridoAt: _instante(json['ocurrido_at']),
    );
  }
}

/// Lo que contesta el servidor al registrar una liquidación.
class LiquidacionHechaModel {
  const LiquidacionHechaModel({
    required this.saldoAntes,
    required this.monto,
    required this.saldoDespues,
    required this.liquidaDelTodo,
    required this.dejaSaldoAFavor,
    required this.yaEstaba,
  });

  final String saldoAntes;
  final String monto;
  final String saldoDespues;
  final bool liquidaDelTodo;
  final bool dejaSaldoAFavor;

  /// El servidor devolvió la que ya había: alguien volvió a pulsar el botón.
  final bool yaEstaba;

  factory LiquidacionHechaModel.fromJson(Map<String, dynamic> json) =>
      LiquidacionHechaModel(
        saldoAntes: _texto(json['saldo_antes']) ?? '0.00',
        monto: _texto(json['monto']) ?? '0.00',
        saldoDespues: _texto(json['saldo_despues']) ?? '0.00',
        liquidaDelTodo: json['liquida_del_todo'] == true,
        dejaSaldoAFavor: json['deja_saldo_a_favor'] == true,
        yaEstaba: json['ya_estaba'] == true,
      );
}
