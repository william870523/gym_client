import 'package:freezed_annotation/freezed_annotation.dart';

part 'trainer_model.freezed.dart';
part 'trainer_model.g.dart';

@freezed
sealed class TrainerModel with _$TrainerModel {
  const factory TrainerModel({
    @JsonKey(name: 'id_entrenador') required String id,
    @JsonKey(name: 'ci_entrenador') required String ci,
    @JsonKey(name: 'nombres_entrenador') String? nombres,
    @JsonKey(name: 'apellidos_entrenador') String? apellidos,
    @JsonKey(name: 'sexo_entrenador') String? sexo,
    @JsonKey(name: 'foto_entrenador') String? foto,
    @JsonKey(name: 'direccion_entrenador') String? direccion,
    @JsonKey(name: 'telefono_entrenador') int? telefono,
    @JsonKey(name: 'correo_entrenador') String? correo,
    @JsonKey(name: 'activo_entrenador') required bool activo,
    @JsonKey(name: 'fecha_incio_entrenador') required DateTime fechaInicio,
    @JsonKey(name: 'version') int? version,
    @JsonKey(name: 'gym_id') String? gymId,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
  }) = _TrainerModel;

  factory TrainerModel.fromJson(Map<String, dynamic> json) =>
      _$TrainerModelFromJson(json);
}
