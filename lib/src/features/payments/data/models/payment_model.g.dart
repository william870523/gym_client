// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentModel _$PaymentModelFromJson(Map<String, dynamic> json) => PaymentModel(
  id: json['pago_cliente_id'] as String,
  ci: json['ci'] as String,
  fecha: DateTime.parse(json['fecha'] as String),
  amount: decimalJsonToDouble(json['monto_total']),
  trainerId: json['id_entrenador'] as String?,
  planId: json['id_planes_pago'] as String,
  currencyId: json['moneda_id'] as String,
  membershipId: json['membresia_id'] as String?,
  listPriceSnapshot: nullableDecimalJsonToDouble(json['precio_lista_snapshot']),
  discountPctSnapshot: json['descuento_pct_snapshot'] as String?,
  discountAmountSnapshot: nullableDecimalJsonToDouble(
    json['descuento_monto_snapshot'],
  ),
  clientCategorySnapshot: json['categoria_cliente_snapshot'] as String?,
  planCodeSnapshot: json['plan_codigo_snapshot'] as String?,
  installmentSuffixSnapshot: json['cuota_sufijo_snapshot'] as String?,
  collectorUserId: json['cobrado_por_user_id'] as String?,
  collectorName: json['cobrado_por_nombre_snapshot'] as String?,
  collectorRole: json['cobrado_por_rol_snapshot'] as String?,
  collectorOrigin: json['cobrado_por_origen'] as String?,
  voidedByUserId: json['anulado_por_user_id'] as String?,
  voidedByName: json['anulado_por_nombre_snapshot'] as String?,
  voidReason: json['motivo_anulacion'] as String?,
  voidedAt: json['anulado_at'] == null
      ? null
      : DateTime.parse(json['anulado_at'] as String),
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
      'membresia_id': instance.membershipId,
      'precio_lista_snapshot': instance.listPriceSnapshot,
      'descuento_pct_snapshot': instance.discountPctSnapshot,
      'descuento_monto_snapshot': instance.discountAmountSnapshot,
      'categoria_cliente_snapshot': instance.clientCategorySnapshot,
      'plan_codigo_snapshot': instance.planCodeSnapshot,
      'cuota_sufijo_snapshot': instance.installmentSuffixSnapshot,
      'cobrado_por_user_id': instance.collectorUserId,
      'cobrado_por_nombre_snapshot': instance.collectorName,
      'cobrado_por_rol_snapshot': instance.collectorRole,
      'cobrado_por_origen': instance.collectorOrigin,
      'anulado_por_user_id': instance.voidedByUserId,
      'anulado_por_nombre_snapshot': instance.voidedByName,
      'motivo_anulacion': instance.voidReason,
      'anulado_at': instance.voidedAt?.toIso8601String(),
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
      amount: decimalJsonToDouble(json['cantidad']),
      exchangeRateId: json['tipo_cambio_id'] as String?,
      methodSurchargeBase: json['recargo_metodo_base'] as String?,
      methodSurchargeRateVersion: (json['recargo_metodo_tasa_version'] as num?)
          ?.toInt(),
      exchangeRateValue: nullableDecimalJsonToDouble(json['exchangeRateValue']),
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
      'recargo_metodo_base': instance.methodSurchargeBase,
      'recargo_metodo_tasa_version': instance.methodSurchargeRateVersion,
    };
