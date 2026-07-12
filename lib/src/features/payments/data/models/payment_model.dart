import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_model.g.dart';

@JsonSerializable()
class PaymentModel {
  @JsonKey(name: 'pago_cliente_id')
  final String id;

  final String ci;

  final DateTime fecha;

  @JsonKey(name: 'monto_total')
  final double amount;

  @JsonKey(name: 'id_entrenador')
  final String? trainerId;

  @JsonKey(name: 'id_planes_pago')
  final String planId;

  @JsonKey(name: 'moneda_id')
  final String currencyId;

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

  @JsonKey(name: 'cantidad')
  final double amount;

  @JsonKey(name: 'tipo_cambio_id')
  final String? exchangeRateId;

  // Exchange rate value (snapshot)
  @JsonKey(includeFromJson: true, includeToJson: false)
  final double? exchangeRateValue;

  PaymentDetailModel({
    required this.id,
    required this.paymentId,
    required this.paymentTypeId,
    required this.currencyId,
    this.accountId,
    required this.amount,
    this.exchangeRateId,
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
      exchangeRateValue: exchangeRateValue ?? this.exchangeRateValue,
    );
  }
}
