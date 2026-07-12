import 'package:freezed_annotation/freezed_annotation.dart';

part 'nacionalidad_model.freezed.dart';
part 'nacionalidad_model.g.dart';

@freezed
sealed class NacionalidadModel with _$NacionalidadModel {
  const factory NacionalidadModel({
    @JsonKey(name: 'nacionalidad_id') required String id,
    @JsonKey(name: 'nacionalidad_nombre') required String name,
    @JsonKey(name: 'codigo_iso') required String isoCode,
    @JsonKey(name: 'bandera') String? flagImage, // Base64 string
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
  }) = _NacionalidadModel;

  factory NacionalidadModel.fromJson(Map<String, dynamic> json) =>
      _$NacionalidadModelFromJson(json);
}
