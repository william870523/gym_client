// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'currency_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CurrencyModel _$CurrencyModelFromJson(Map<String, dynamic> json) =>
    _CurrencyModel(
      id: json['moneda_id'] as String,
      name: json['moneda_nombre'] as String,
      code: json['codigo'] as String,
      symbol: json['simbolo'] as String?,
      flagImage: json['imagen'] as String?,
    );

Map<String, dynamic> _$CurrencyModelToJson(_CurrencyModel instance) =>
    <String, dynamic>{
      'moneda_id': instance.id,
      'moneda_nombre': instance.name,
      'codigo': instance.code,
      'simbolo': instance.symbol,
      'imagen': instance.flagImage,
    };
