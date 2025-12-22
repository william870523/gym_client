// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Client _$ClientFromJson(Map<String, dynamic> json) => _Client(
  ci: json['ci'] as String,
  nombres: json['nombres'] as String,
  apellidos: json['apellidos'] as String,
  fechaRegistro: DateTime.parse(json['fecha_registro'] as String),
  gymId: json['gym_id'] as String?,
);

Map<String, dynamic> _$ClientToJson(_Client instance) => <String, dynamic>{
  'ci': instance.ci,
  'nombres': instance.nombres,
  'apellidos': instance.apellidos,
  'fecha_registro': instance.fechaRegistro.toIso8601String(),
  'gym_id': instance.gymId,
};
