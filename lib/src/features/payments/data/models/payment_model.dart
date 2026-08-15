import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../core/money/decimal_json.dart';

part 'payment_model.g.dart';

@JsonSerializable()
class PaymentModel {
  @JsonKey(name: 'pago_cliente_id')
  final String id;

  final String ci;

  final DateTime fecha;

  @JsonKey(name: 'monto_total', fromJson: decimalJsonToDouble)
  final double amount;

  @JsonKey(name: 'id_entrenador')
  final String? trainerId;

  @JsonKey(name: 'id_planes_pago')
  final String planId;

  @JsonKey(name: 'moneda_id')
  final String currencyId;

  @JsonKey(name: 'membresia_id')
  final String? membershipId;

  @JsonKey(name: 'precio_lista_snapshot', fromJson: nullableDecimalJsonToDouble)
  final double? listPriceSnapshot;

  @JsonKey(name: 'descuento_pct_snapshot')
  final String? discountPctSnapshot;

  @JsonKey(name: 'descuento_monto_snapshot', fromJson: nullableDecimalJsonToDouble)
  final double? discountAmountSnapshot;

  @JsonKey(name: 'categoria_cliente_snapshot')
  final String? clientCategorySnapshot;

  @JsonKey(name: 'plan_codigo_snapshot')
  final String? planCodeSnapshot;

  @JsonKey(name: 'cuota_sufijo_snapshot')
  final String? installmentSuffixSnapshot;

  // H5: cobrador congelado al cobrar (R5.6). Mismo cuarteto que el expediente.
  @JsonKey(name: 'cobrado_por_user_id')
  final String? collectorUserId;

  @JsonKey(name: 'cobrado_por_nombre_snapshot')
  final String? collectorName;

  @JsonKey(name: 'cobrado_por_rol_snapshot')
  final String? collectorRole;

  @JsonKey(name: 'cobrado_por_origen')
  final String? collectorOrigin;

  @JsonKey(name: 'anulado_por_user_id')
  final String? voidedByUserId;

  @JsonKey(name: 'anulado_por_nombre_snapshot')
  final String? voidedByName;

  @JsonKey(name: 'motivo_anulacion')
  final String? voidReason;

  @JsonKey(name: 'anulado_at')
  final DateTime? voidedAt;

  @JsonKey(name: 'is_deleted')
  final bool isDeleted;

  final int version;

  // UI-only helper for details (not strictly in DB table 'pago_cliente', but useful for API aggregation)
  @JsonKey(includeFromJson: true, includeToJson: false)
  final List<PaymentDetailModel>? details;

  // UI-only helper for Client Name (joined in API)
  @JsonKey(includeFromJson: true, includeToJson: false)
  final String? clientName;

  PaymentModel({
    required this.id,
    required this.ci,
    required this.fecha,
    required this.amount,
    this.trainerId,
    required this.planId,
    required this.currencyId,
    this.membershipId,
    this.listPriceSnapshot,
    this.discountPctSnapshot,
    this.discountAmountSnapshot,
    this.clientCategorySnapshot,
    this.planCodeSnapshot,
    this.installmentSuffixSnapshot,
    this.collectorUserId,
    this.collectorName,
    this.collectorRole,
    this.collectorOrigin,
    this.voidedByUserId,
    this.voidedByName,
    this.voidReason,
    this.voidedAt,
    this.isDeleted = false,
    this.version = 1,
    this.details,
    this.clientName,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) =>
      _$PaymentModelFromJson(json);
  Map<String, dynamic> toJson() => _$PaymentModelToJson(this);
}

@JsonSerializable()
class PaymentDetailModel {
  @JsonKey(name: 'detalle_pago_id')
  final String id;

  @JsonKey(name: 'pago_cliente_id')
  final String paymentId;

  @JsonKey(name: 'tipo_pago_id')
  final String paymentTypeId;

  @JsonKey(name: 'moneda_id')
  final String currencyId;

  @JsonKey(name: 'cuenta_id')
  final String? accountId;

  @JsonKey(name: 'cantidad', fromJson: decimalJsonToDouble)
  final double amount;

  @JsonKey(name: 'tipo_cambio_id')
  final String? exchangeRateId;

  @JsonKey(name: 'recargo_metodo_base')
  final String? methodSurchargeBase;

  @JsonKey(name: 'recargo_metodo_tasa_version')
  final int? methodSurchargeRateVersion;

  // Exchange rate value (snapshot)
  @JsonKey(
    includeFromJson: true,
    includeToJson: false,
    fromJson: nullableDecimalJsonToDouble,
  )
  final double? exchangeRateValue;

  PaymentDetailModel({
    required this.id,
    required this.paymentId,
    required this.paymentTypeId,
    required this.currencyId,
    this.accountId,
    required this.amount,
    this.exchangeRateId,
    this.methodSurchargeBase,
    this.methodSurchargeRateVersion,
    this.exchangeRateValue,
  });

  factory PaymentDetailModel.fromJson(Map<String, dynamic> json) =>
      _$PaymentDetailModelFromJson(json);
  Map<String, dynamic> toJson() => _$PaymentDetailModelToJson(this);

  PaymentDetailModel copyWith({
    String? id,
    String? paymentId,
    String? paymentTypeId,
    String? currencyId,
    String? accountId,
    double? amount,
    String? exchangeRateId,
    String? methodSurchargeBase,
    int? methodSurchargeRateVersion,
    double? exchangeRateValue,
  }) {
    return PaymentDetailModel(
      id: id ?? this.id,
      paymentId: paymentId ?? this.paymentId,
      paymentTypeId: paymentTypeId ?? this.paymentTypeId,
      currencyId: currencyId ?? this.currencyId,
      accountId: accountId ?? this.accountId,
      amount: amount ?? this.amount,
      exchangeRateId: exchangeRateId ?? this.exchangeRateId,
      methodSurchargeBase: methodSurchargeBase ?? this.methodSurchargeBase,
      methodSurchargeRateVersion:
          methodSurchargeRateVersion ?? this.methodSurchargeRateVersion,
      exchangeRateValue: exchangeRateValue ?? this.exchangeRateValue,
    );
  }
}
