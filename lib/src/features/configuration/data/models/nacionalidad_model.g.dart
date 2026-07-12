// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nacionalidad_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NacionalidadModel _$NacionalidadModelFromJson(Map<String, dynamic> json) =>
    _NacionalidadModel(
      id: json['nacionalidad_id'] as String,
      name: json['nacionalidad_nombre'] as String,
      isoCode: json['codigo_iso'] as String,
      flagImage: json['bandera'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? false,
    );

Map<String, dynamic> _$NacionalidadModelToJson(_NacionalidadModel instance) =>
    <String, dynamic>{
      'nacionalidad_id': instance.id,
      'nacionalidad_nombre': instance.name,
      'codigo_iso': instance.isoCode,
      'bandera': instance.flagImage,
      'is_deleted': instance.isDeleted,
    };
