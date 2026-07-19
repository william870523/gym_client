class PlanCuotaEsquemaModel {
  final String? esquemaId;
  final String planId;
  final int numeroCuota;
  final double importe;
  final int diasCobertura;
  final int orden;

  PlanCuotaEsquemaModel({
    this.esquemaId,
    required this.planId,
    required this.numeroCuota,
    required this.importe,
    required this.diasCobertura,
    this.orden = 1,
  });

  factory PlanCuotaEsquemaModel.fromJson(Map<String, dynamic> json) {
    return PlanCuotaEsquemaModel(
      esquemaId: json['esquema_id'] as String?,
      planId: json['plan_id'] as String? ?? '',
      numeroCuota: json['numero_cuota'] as int? ?? 1,
      importe: (json['importe'] as num?)?.toDouble() ?? 0.0,
      diasCobertura: json['dias_cobertura'] as int? ?? 30,
      orden: json['orden'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (esquemaId != null) 'esquema_id': esquemaId,
      'plan_id': planId,
      'numero_cuota': numeroCuota,
      'importe': importe,
      'dias_cobertura': diasCobertura,
      'orden': orden,
    };
  }
}

class MembresiaCuotaModel {
  final String cuotaInstanciaId;
  final String membresiaId;
  final int numeroCuota;
  final double importe;
  final int diasCobertura;
  final DateTime fechaExigible;
  final DateTime fechaCoberturaInicio;
  final DateTime fechaCoberturaFin;
  final String estado; // PENDIENTE, PAGADA, ANTICIPADA, ANULADA
  final DateTime? fechaPagada;
  final String? pagoDetalleId;

  MembresiaCuotaModel({
    required this.cuotaInstanciaId,
    required this.membresiaId,
    required this.numeroCuota,
    required this.importe,
    required this.diasCobertura,
    required this.fechaExigible,
    required this.fechaCoberturaInicio,
    required this.fechaCoberturaFin,
    required this.estado,
    this.fechaPagada,
    this.pagoDetalleId,
  });

  factory MembresiaCuotaModel.fromJson(Map<String, dynamic> json) {
    return MembresiaCuotaModel(
      cuotaInstanciaId: json['cuota_instancia_id'] as String? ?? '',
      membresiaId: json['membresia_id'] as String? ?? '',
      numeroCuota: json['numero_cuota'] as int? ?? 1,
      importe: (json['importe'] as num?)?.toDouble() ?? 0.0,
      diasCobertura: json['dias_cobertura'] as int? ?? 30,
      fechaExigible: DateTime.tryParse(json['fecha_exigible'] as String? ?? '') ?? DateTime.now(),
      fechaCoberturaInicio: DateTime.tryParse(json['fecha_cobertura_inicio'] as String? ?? '') ?? DateTime.now(),
      fechaCoberturaFin: DateTime.tryParse(json['fecha_cobertura_fin'] as String? ?? '') ?? DateTime.now(),
      estado: json['estado'] as String? ?? 'PENDIENTE',
      fechaPagada: json['fecha_pagada'] != null ? DateTime.tryParse(json['fecha_pagada'] as String) : null,
      pagoDetalleId: json['pago_detalle_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cuota_instancia_id': cuotaInstanciaId,
      'membresia_id': membresiaId,
      'numero_cuota': numeroCuota,
      'importe': importe,
      'dias_cobertura': diasCobertura,
      'fecha_exigible': fechaExigible.toIso8601String(),
      'fecha_cobertura_inicio': fechaCoberturaInicio.toIso8601String(),
      'fecha_cobertura_fin': fechaCoberturaFin.toIso8601String(),
      'estado': estado,
      if (fechaPagada != null) 'fecha_pagada': fechaPagada!.toIso8601String(),
      if (pagoDetalleId != null) 'pago_detalle_id': pagoDetalleId,
    };
  }

  bool get isPaid => estado == 'PAGADA' || estado == 'ANTICIPADA';
  bool get isPending => estado == 'PENDIENTE';
}
