// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'referencia_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReferenciaModel _$ReferenciaModelFromJson(Map<String, dynamic> json) =>
    _ReferenciaModel(
      id: json['referencia_id'] as String,
      nombre: json['nombre_referencia'] as String,
      isDeleted: json['is_deleted'] as bool? ?? false,
    );

Map<String, dynamic> _$ReferenciaModelToJson(_ReferenciaModel instance) =>
    <String, dynamic>{
      'referencia_id': instance.id,
      'nombre_referencia': instance.nombre,
      'is_deleted': instance.isDeleted,
    };
