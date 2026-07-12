import 'package:freezed_annotation/freezed_annotation.dart';

part 'referencia_model.freezed.dart';
part 'referencia_model.g.dart';

@freezed
sealed class ReferenciaModel with _$ReferenciaModel {
  const factory ReferenciaModel({
    @JsonKey(name: 'referencia_id') required String id,
    @JsonKey(name: 'nombre_referencia') required String nombre,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
  }) = _ReferenciaModel;

  factory ReferenciaModel.fromJson(Map<String, dynamic> json) =>
      _$ReferenciaModelFromJson(json);
}
