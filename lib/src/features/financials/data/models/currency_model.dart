import 'package:freezed_annotation/freezed_annotation.dart';

part 'currency_model.freezed.dart';
part 'currency_model.g.dart';

@freezed
sealed class CurrencyModel with _$CurrencyModel {
  const factory CurrencyModel({
    @JsonKey(name: 'moneda_id') required String id,
    @JsonKey(name: 'moneda_nombre') required String name,
    @JsonKey(name: 'codigo') required String code,
    @JsonKey(name: 'simbolo') String? symbol,
    @JsonKey(name: 'imagen') String? flagImage, // Base64 string
  }) = _CurrencyModel;

  factory CurrencyModel.fromJson(Map<String, dynamic> json) =>
      _$CurrencyModelFromJson(json);
}
