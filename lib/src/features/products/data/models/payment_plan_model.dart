class PaymentPlanModel {
  final String? id;
  final String nombre;
  final double importe;
  final int duracion; // In days
  final String monedaId;
  final bool activo;
  final bool incluyeEntrenador;
  final String comisionEntrenadorTipo; // NONE, PERCENTAGE, FIXED_AMOUNT
  final double? comisionEntrenadorValor;
  final bool aceptaCuotas;
  // R5.3: código corto para recepción (PMV, TCN...). Campo libre.
  final String? codigo;
  // R5.3: precio fijo para cliente VIEJO; null = aplicar % global.
  final double? precioViejoExcepcion;
  final bool isDeleted;
  final String? gymId;
  final int version;

  PaymentPlanModel({
    this.id,
    required this.nombre,
    required this.importe,
    required this.duracion,
    required this.monedaId,
    this.activo = true,
    this.incluyeEntrenador = false,
    this.comisionEntrenadorTipo = 'NONE',
    this.comisionEntrenadorValor,
    this.aceptaCuotas = false,
    this.codigo,
    this.precioViejoExcepcion,
    this.isDeleted = false,
    this.gymId,
    this.version = 1,
  });

  factory PaymentPlanModel.fromJson(Map<String, dynamic> json) {
    return PaymentPlanModel(
      id: json['id_planes_pago'] as String?,
      nombre: json['nombre_plan_pago'] as String? ?? '',
      importe: (json['importe_plan_pago'] as num?)?.toDouble() ?? 0.0,
      duracion: json['duracion_plan_pago'] as int? ?? 0,
      monedaId: json['moneda_id'] as String? ?? '',
      activo: json['activo'] == 1 || json['activo'] == true,
      incluyeEntrenador:
          json['incluye_entrenador'] == 1 || json['incluye_entrenador'] == true,
      comisionEntrenadorTipo:
          json['comision_entrenador_tipo'] as String? ?? 'NONE',
      comisionEntrenadorValor:
          (json['comision_entrenador_valor'] as num?)?.toDouble(),
      aceptaCuotas: json['acepta_cuotas'] == 1 || json['acepta_cuotas'] == true,
      codigo: json['codigo'] as String?,
      precioViejoExcepcion:
          (json['precio_viejo_excepcion'] as num?)?.toDouble(),
      isDeleted: json['is_deleted'] == 1 || json['is_deleted'] == true,
      gymId: json['gym_id'] as String?,
      version: json['version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id_planes_pago': id,
      'nombre_plan_pago': nombre,
      'importe_plan_pago': importe,
      'duracion_plan_pago': duracion,
      'moneda_id': monedaId,
      'activo': activo,
      'incluye_entrenador': incluyeEntrenador,
      'comision_entrenador_tipo': comisionEntrenadorTipo,
      'comision_entrenador_valor': comisionEntrenadorValor,
      'acepta_cuotas': aceptaCuotas,
      if (codigo != null) 'codigo': codigo,
      if (precioViejoExcepcion != null)
        'precio_viejo_excepcion': precioViejoExcepcion,
      'is_deleted': isDeleted,
      'gym_id': gymId,
      'version': version,
    };
  }

  PaymentPlanModel copyWith({
    String? id,
    String? nombre,
    double? importe,
    int? duracion,
    String? monedaId,
    bool? activo,
    bool? incluyeEntrenador,
    String? comisionEntrenadorTipo,
    double? comisionEntrenadorValor,
    bool? aceptaCuotas,
    String? codigo,
    double? precioViejoExcepcion,
    bool? isDeleted,
    String? gymId,
    int? version,
  }) {
    return PaymentPlanModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      importe: importe ?? this.importe,
      duracion: duracion ?? this.duracion,
      monedaId: monedaId ?? this.monedaId,
      activo: activo ?? this.activo,
      incluyeEntrenador: incluyeEntrenador ?? this.incluyeEntrenador,
      comisionEntrenadorTipo:
          comisionEntrenadorTipo ?? this.comisionEntrenadorTipo,
      comisionEntrenadorValor:
          comisionEntrenadorValor ?? this.comisionEntrenadorValor,
      aceptaCuotas: aceptaCuotas ?? this.aceptaCuotas,
      codigo: codigo ?? this.codigo,
      precioViejoExcepcion:
          precioViejoExcepcion ?? this.precioViejoExcepcion,
      isDeleted: isDeleted ?? this.isDeleted,
      gymId: gymId ?? this.gymId,
      version: version ?? this.version,
    );
  }

  String get formattedDuration {
    if (duracion == 365) return '1 Año';
    if (duracion % 30 == 0) {
      final months = duracion ~/ 30;
      return '$months Mes${months > 1 ? "es" : ""}';
    }
    if (duracion % 7 == 0) {
      final weeks = duracion ~/ 7;
      return '$weeks Semana${weeks > 1 ? "s" : ""}';
    }
    return '$duracion Día${duracion > 1 ? "s" : ""}';
  }
}
