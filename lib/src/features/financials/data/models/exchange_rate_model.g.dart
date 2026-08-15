// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exchange_rate_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ExchangeRateModel _$ExchangeRateModelFromJson(Map<String, dynamic> json) =>
    _ExchangeRateModel(
      id: json['tipo_cambio_id'] as String,
      monedaIdBase: json['moneda_id_base'] as String,
      monedaIdTarget: json['moneda_id_target'] as String,
      exchangeRate: decimalJsonToDouble(json['exchange_rate']),
      recargosJson: json['recargos_json'] as String?,
      recargosGlobalesJson: json['recargos_globales_json'] as String?,
      recargosSedeJson: json['recargos_sede_json'] as String?,
      recargosFuentesJson: json['recargos_fuentes_json'] as String?,
      recargosFuente: json['recargos_fuente'] as String? ?? 'NINGUNO',
      recargosGymId: json['recargos_gym_id'] as String?,
      puedeEditarGlobal: json['puede_editar_global'] as bool? ?? true,
      puedeEditarSede: json['puede_editar_sede'] as bool? ?? true,
      fechaInicio: DateTime.parse(json['fecha_inicio'] as String),
      fechaExpiracion: json['fecha_expiracion'] == null
          ? null
          : DateTime.parse(json['fecha_expiracion'] as String),
      activo: json['activo'] as bool? ?? true,
      monedaBase: json['moneda_base'] == null
          ? null
          : CurrencyModel.fromJson(json['moneda_base'] as Map<String, dynamic>),
      monedaTarget: json['moneda_target'] == null
          ? null
          : CurrencyModel.fromJson(
              json['moneda_target'] as Map<String, dynamic>,
            ),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$ExchangeRateModelToJson(_ExchangeRateModel instance) =>
    <String, dynamic>{
      'tipo_cambio_id': instance.id,
      'moneda_id_base': instance.monedaIdBase,
      'moneda_id_target': instance.monedaIdTarget,
      'exchange_rate': instance.exchangeRate,
      'recargos_json': instance.recargosJson,
      'recargos_globales_json': instance.recargosGlobalesJson,
      'recargos_sede_json': instance.recargosSedeJson,
      'recargos_fuentes_json': instance.recargosFuentesJson,
      'recargos_fuente': instance.recargosFuente,
      'recargos_gym_id': instance.recargosGymId,
      'puede_editar_global': instance.puedeEditarGlobal,
      'puede_editar_sede': instance.puedeEditarSede,
      'fecha_inicio': instance.fechaInicio.toIso8601String(),
      'fecha_expiracion': instance.fechaExpiracion?.toIso8601String(),
      'activo': instance.activo,
      'moneda_base': instance.monedaBase,
      'moneda_target': instance.monedaTarget,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
