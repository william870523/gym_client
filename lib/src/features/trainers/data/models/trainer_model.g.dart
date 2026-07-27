// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trainer_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TrainerModel _$TrainerModelFromJson(Map<String, dynamic> json) =>
    _TrainerModel(
      id: json['id_entrenador'] as String,
      ci: json['ci_entrenador'] as String,
      documentType: json['tipo_documento'] as String?,
      nombres: json['nombres_entrenador'] as String?,
      apellidos: json['apellidos_entrenador'] as String?,
      sexo: json['sexo_entrenador'] as String?,
      foto: json['foto_entrenador'] as String?,
      direccion: json['direccion_entrenador'] as String?,
      telefono: (json['telefono_entrenador'] as num?)?.toInt(),
      correo: json['correo_entrenador'] as String?,
      activo: json['activo_entrenador'] as bool,
      fechaInicio: DateTime.parse(json['fecha_incio_entrenador'] as String),
      version: (json['version'] as num?)?.toInt(),
      gymId: json['gym_id'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? false,
    );

Map<String, dynamic> _$TrainerModelToJson(_TrainerModel instance) =>
    <String, dynamic>{
      'id_entrenador': instance.id,
      'ci_entrenador': instance.ci,
      'tipo_documento': instance.documentType,
      'nombres_entrenador': instance.nombres,
      'apellidos_entrenador': instance.apellidos,
      'sexo_entrenador': instance.sexo,
      'foto_entrenador': instance.foto,
      'direccion_entrenador': instance.direccion,
      'telefono_entrenador': instance.telefono,
      'correo_entrenador': instance.correo,
      'activo_entrenador': instance.activo,
      'fecha_incio_entrenador': instance.fechaInicio.toIso8601String(),
      'version': instance.version,
      'gym_id': instance.gymId,
      'is_deleted': instance.isDeleted,
    };
