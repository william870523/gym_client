// ignore_for_file: non_constant_identifier_names

import 'dart:convert';
import 'dart:typed_data';
import 'package:json_annotation/json_annotation.dart';

part 'client_model.g.dart';

@JsonSerializable()
class ClientModel {
  @JsonKey(name: 'ci')
  final String id;
  @JsonKey(name: 'tipo_documento')
  final String? documentType;

  final String? nombres;
  final String? apellidos;
  final String? sexo;
  final String? correo;
  final int? telefono;
  @JsonKey(name: 'nacionalidad_id')
  final String? nacionalidadId;
  @JsonKey(name: 'id_planes_pago')
  final String? planId;
  @JsonKey(name: 'foto_cliente')
  final String? photoUrl;
  final bool activo;
  final String? direccion;
  @JsonKey(name: 'estatura_cliente')
  final double? estatura_cliente;
  final double? peso; // Added field
  final String? objetivo;
  @JsonKey(name: 'fecha_inicio')
  final DateTime? startDate;
  @JsonKey(name: 'fecha_fin')
  final DateTime? endDate;
  @JsonKey(name: 'referencia_id')
  final String? referralId;
  @JsonKey(name: 'id_entrenador')
  final String? trainerId;
  @JsonKey(name: 'id_horarios')
  final String? scheduleId;
  @JsonKey(name: 'membresia_id')
  final String? membershipId;
  @JsonKey(name: 'membresia_estado')
  final String? membershipStatus;

  /// Vigencia **derivada por el servidor** contra la fecha de negocio de la
  /// sede: `VIGENTE`, `VENCIDA_RECIENTE`, `VENCIDA`, `PAUSADA`,
  /// `PENDIENTE_PAGO`, `CANCELADA` o `SIN_MEMBRESIA`.
  ///
  /// No confundir con [membershipStatus], que es el estado *guardado* y nunca
  /// dice `VENCIDA`: registra el acto —se activó, se pausó, se canceló—, no la
  /// cobertura. La fecha la pone el servidor porque el reloj del dispositivo no
  /// es autoridad (docs/DEMO_MEMBERSHIP_VIGENCIA.md).
  @JsonKey(name: 'membresia_vigencia')
  final String? membershipVigencia;

  /// Días desde que terminó la cobertura; negativo si aún quedan.
  @JsonKey(name: 'membresia_dias_desde_vencimiento')
  final int? membershipDaysSinceExpiry;

  /// `true` solo si la membresía cubre hoy. Ni pausada ni vencida cubren.
  @JsonKey(name: 'membresia_cubre_hoy')
  final bool? membershipCoversToday;

  @JsonKey(name: 'membresia_precio')
  final double? membershipPrice;
  @JsonKey(name: 'membresia_importe_pagado')
  final double? membershipPaid;
  @JsonKey(name: 'membresia_saldo_pendiente')
  final double? membershipBalanceDue;
  // R5.3: categoría del cliente para el descuento (NUEVO | VIEJO).
  final String? categoria;

  ClientModel({
    required this.id,
    this.documentType,
    this.nombres,
    this.apellidos,
    this.sexo,
    this.correo,
    this.telefono,
    this.nacionalidadId,
    this.planId,
    this.photoUrl,
    this.activo = true,
    this.direccion,
    this.estatura_cliente,
    this.peso,
    this.objetivo,
    this.startDate,
    this.endDate,
    this.referralId,
    this.trainerId,
    this.scheduleId,
    this.membershipId,
    this.membershipStatus,
    this.membershipVigencia,
    this.membershipDaysSinceExpiry,
    this.membershipCoversToday,
    this.membershipPrice,
    this.membershipPaid,
    this.membershipBalanceDue,
    this.categoria,
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) =>
      _$ClientModelFromJson(json);

  Map<String, dynamic> toJson() => _$ClientModelToJson(this);

  ClientModel copyWith({
    String? id,
    String? documentType,
    String? nombres,
    String? apellidos,
    String? sexo,
    String? correo,
    int? telefono,
    String? nacionalidadId,
    String? planId,
    String? photoUrl,
    bool? activo,
    String? direccion,
    double? estatura_cliente,
    double? peso,
    String? objetivo,
    DateTime? startDate,
    DateTime? endDate,
    String? referralId,
    String? trainerId,
    String? scheduleId,
    String? membershipId,
    String? membershipStatus,
    String? membershipVigencia,
    int? membershipDaysSinceExpiry,
    bool? membershipCoversToday,
    double? membershipPrice,
    double? membershipPaid,
    double? membershipBalanceDue,
    String? categoria,
  }) {
    return ClientModel(
      id: id ?? this.id,
      documentType: documentType ?? this.documentType,
      nombres: nombres ?? this.nombres,
      apellidos: apellidos ?? this.apellidos,
      sexo: sexo ?? this.sexo,
      correo: correo ?? this.correo,
      telefono: telefono ?? this.telefono,
      nacionalidadId: nacionalidadId ?? this.nacionalidadId,
      planId: planId ?? this.planId,
      photoUrl: photoUrl ?? this.photoUrl,
      activo: activo ?? this.activo,
      direccion: direccion ?? this.direccion,
      estatura_cliente: estatura_cliente ?? this.estatura_cliente,
      peso: peso ?? this.peso,
      objetivo: objetivo ?? this.objetivo,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      referralId: referralId ?? this.referralId,
      trainerId: trainerId ?? this.trainerId,
      scheduleId: scheduleId ?? this.scheduleId,
      membershipId: membershipId ?? this.membershipId,
      membershipStatus: membershipStatus ?? this.membershipStatus,
      membershipVigencia: membershipVigencia ?? this.membershipVigencia,
      membershipDaysSinceExpiry:
          membershipDaysSinceExpiry ?? this.membershipDaysSinceExpiry,
      membershipCoversToday:
          membershipCoversToday ?? this.membershipCoversToday,
      membershipPrice: membershipPrice ?? this.membershipPrice,
      membershipPaid: membershipPaid ?? this.membershipPaid,
      membershipBalanceDue: membershipBalanceDue ?? this.membershipBalanceDue,
      categoria: categoria ?? this.categoria,
    );
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  Map<String, dynamic> extras = {};

  // Aliases for Spanish/Legacy compatibility
  String get ci => id;
  DateTime get fechaInicio => startDate ?? DateTime.now();
  DateTime get fechaFin => endDate ?? DateTime.now();
  double get estaturaCliente => estatura_cliente ?? 0.0;

  Uint8List? get fotoCliente {
    if (photoUrl == null || photoUrl!.isEmpty) return null;
    try {
      return base64Decode(photoUrl!);
    } catch (_) {
      return null;
    }
  }
}
