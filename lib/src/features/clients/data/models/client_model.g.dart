// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClientModel _$ClientModelFromJson(Map<String, dynamic> json) => ClientModel(
  id: json['ci'] as String,
  nombres: json['nombres'] as String?,
  apellidos: json['apellidos'] as String?,
  sexo: json['sexo'] as String?,
  correo: json['correo'] as String?,
  telefono: (json['telefono'] as num?)?.toInt(),
  nacionalidadId: json['nacionalidad_id'] as String?,
  planId: json['id_planes_pago'] as String?,
  photoUrl: json['foto_cliente'] as String?,
  activo: json['activo'] as bool? ?? true,
  direccion: json['direccion'] as String?,
  estatura_cliente: (json['estatura_cliente'] as num?)?.toDouble(),
  peso: (json['peso'] as num?)?.toDouble(),
  objetivo: json['objetivo'] as String?,
  startDate: json['fecha_inicio'] == null
      ? null
      : DateTime.parse(json['fecha_inicio'] as String),
  endDate: json['fecha_fin'] == null
      ? null
      : DateTime.parse(json['fecha_fin'] as String),
  referralId: json['referencia_id'] as String?,
  trainerId: json['id_entrenador'] as String?,
  scheduleId: json['id_horarios'] as String?,
);

Map<String, dynamic> _$ClientModelToJson(ClientModel instance) =>
    <String, dynamic>{
      'ci': instance.id,
      'nombres': instance.nombres,
      'apellidos': instance.apellidos,
      'sexo': instance.sexo,
      'correo': instance.correo,
      'telefono': instance.telefono,
      'nacionalidad_id': instance.nacionalidadId,
      'id_planes_pago': instance.planId,
      'foto_cliente': instance.photoUrl,
      'activo': instance.activo,
      'direccion': instance.direccion,
      'estatura_cliente': instance.estatura_cliente,
      'peso': instance.peso,
      'objetivo': instance.objetivo,
      'fecha_inicio': instance.startDate?.toIso8601String(),
      'fecha_fin': instance.endDate?.toIso8601String(),
      'referencia_id': instance.referralId,
      'id_entrenador': instance.trainerId,
      'id_horarios': instance.scheduleId,
    };
