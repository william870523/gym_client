// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentModel _$PaymentModelFromJson(Map<String, dynamic> json) => PaymentModel(
  id: json['pago_cliente_id'] as String,
  ci: json['ci'] as String,
  fecha: DateTime.parse(json['fecha'] as String),
  amount: (json['monto_total'] as num).toDouble(),
  trainerId: json['id_entrenador'] as String?,
  planId: json['id_planes_pago'] as String,
  currencyId: json['moneda_id'] as String,
  isDeleted: json['is_deleted'] as bool? ?? false,
  version: (json['version'] as num?)?.toInt() ?? 1,
  details: (json['details'] as List<dynamic>?)
      ?.map((e) => PaymentDetailModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  clientName: json['clientName'] as String?,
);

Map<String, dynamic> _$PaymentModelToJson(PaymentModel instance) =>
    <String, dynamic>{
      'pago_cliente_id': instance.id,
      'ci': instance.ci,
      'fecha': instance.fecha.toIso8601String(),
      'monto_total': instance.amount,
      'id_entrenador': instance.trainerId,
      'id_planes_pago': instance.planId,
      'moneda_id': instance.currencyId,
      'is_deleted': instance.isDeleted,
      'version': instance.version,
    };

PaymentDetailModel _$PaymentDetailModelFromJson(Map<String, dynamic> json) =>
    PaymentDetailModel(
      id: json['detalle_pago_id'] as String,
      paymentId: json['pago_cliente_id'] as String,
      paymentTypeId: json['tipo_pago_id'] as String,
      currencyId: json['moneda_id'] as String,
      accountId: json['cuenta_id'] as String?,
      amount: (json['cantidad'] as num).toDouble(),
      exchangeRateId: json['tipo_cambio_id'] as String?,
      exchangeRateValue: (json['exchangeRateValue'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$PaymentDetailModelToJson(PaymentDetailModel instance) =>
    <String, dynamic>{
      'detalle_pago_id': instance.id,
      'pago_cliente_id': instance.paymentId,
      'tipo_pago_id': instance.paymentTypeId,
      'moneda_id': instance.currencyId,
      'cuenta_id': instance.accountId,
      'cantidad': instance.amount,
      'tipo_cambio_id': instance.exchangeRateId,
    };
