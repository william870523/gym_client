import 'package:freezed_annotation/freezed_annotation.dart';
import 'currency_model.dart';

part 'exchange_rate_model.freezed.dart';
part 'exchange_rate_model.g.dart';

@freezed
sealed class ExchangeRateModel with _$ExchangeRateModel {
  const factory ExchangeRateModel({
    @JsonKey(name: 'tipo_cambio_id') required String id,
    @JsonKey(name: 'moneda_id_base') required String monedaIdBase,
    @JsonKey(name: 'moneda_id_target') required String monedaIdTarget,
    @JsonKey(name: 'exchange_rate') required double exchangeRate,
    @JsonKey(name: 'fecha_inicio') required DateTime fechaInicio,
    @JsonKey(name: 'fecha_expiracion') DateTime? fechaExpiracion,
    @Default(true) bool activo,
    @JsonKey(name: 'moneda_base') CurrencyModel? monedaBase,
    @JsonKey(name: 'moneda_target') CurrencyModel? monedaTarget,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _ExchangeRateModel;

  factory ExchangeRateModel.fromJson(Map<String, dynamic> json) =>
      _$ExchangeRateModelFromJson(json);
}
