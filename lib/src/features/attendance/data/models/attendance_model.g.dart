// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$AttendanceModelToJson(AttendanceModel instance) =>
    <String, dynamic>{
      'asistencia_id': instance.id,
      'ci': instance.clientId,
      'created_at': instance.checkIn.toIso8601String(),
      'fecha_salida': instance.checkOut?.toIso8601String(),
      'pausa_inicio': instance.pauseStart?.toIso8601String(),
      'pausa_ms': instance.pausedMs,
      'isPaused': instance.isPaused,
    };
