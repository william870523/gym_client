// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trainer_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TrainerModel {

@JsonKey(name: 'id_entrenador') String get id;@JsonKey(name: 'ci_entrenador') String get ci;@JsonKey(name: 'tipo_documento') String? get documentType;@JsonKey(name: 'nombres_entrenador') String? get nombres;@JsonKey(name: 'apellidos_entrenador') String? get apellidos;@JsonKey(name: 'sexo_entrenador') String? get sexo;@JsonKey(name: 'foto_entrenador') String? get foto;@JsonKey(name: 'direccion_entrenador') String? get direccion;@JsonKey(name: 'telefono_entrenador') int? get telefono;@JsonKey(name: 'correo_entrenador') String? get correo;@JsonKey(name: 'activo_entrenador') bool get activo;@JsonKey(name: 'fecha_incio_entrenador') DateTime get fechaInicio;@JsonKey(name: 'version') int? get version;@JsonKey(name: 'gym_id') String? get gymId;@JsonKey(name: 'is_deleted') bool get isDeleted;
/// Create a copy of TrainerModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrainerModelCopyWith<TrainerModel> get copyWith => _$TrainerModelCopyWithImpl<TrainerModel>(this as TrainerModel, _$identity);

  /// Serializes this TrainerModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrainerModel&&(identical(other.id, id) || other.id == id)&&(identical(other.ci, ci) || other.ci == ci)&&(identical(other.documentType, documentType) || other.documentType == documentType)&&(identical(other.nombres, nombres) || other.nombres == nombres)&&(identical(other.apellidos, apellidos) || other.apellidos == apellidos)&&(identical(other.sexo, sexo) || other.sexo == sexo)&&(identical(other.foto, foto) || other.foto == foto)&&(identical(other.direccion, direccion) || other.direccion == direccion)&&(identical(other.telefono, telefono) || other.telefono == telefono)&&(identical(other.correo, correo) || other.correo == correo)&&(identical(other.activo, activo) || other.activo == activo)&&(identical(other.fechaInicio, fechaInicio) || other.fechaInicio == fechaInicio)&&(identical(other.version, version) || other.version == version)&&(identical(other.gymId, gymId) || other.gymId == gymId)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ci,documentType,nombres,apellidos,sexo,foto,direccion,telefono,correo,activo,fechaInicio,version,gymId,isDeleted);

@override
String toString() {
  return 'TrainerModel(id: $id, ci: $ci, documentType: $documentType, nombres: $nombres, apellidos: $apellidos, sexo: $sexo, foto: $foto, direccion: $direccion, telefono: $telefono, correo: $correo, activo: $activo, fechaInicio: $fechaInicio, version: $version, gymId: $gymId, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class $TrainerModelCopyWith<$Res>  {
  factory $TrainerModelCopyWith(TrainerModel value, $Res Function(TrainerModel) _then) = _$TrainerModelCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'id_entrenador') String id,@JsonKey(name: 'ci_entrenador') String ci,@JsonKey(name: 'tipo_documento') String? documentType,@JsonKey(name: 'nombres_entrenador') String? nombres,@JsonKey(name: 'apellidos_entrenador') String? apellidos,@JsonKey(name: 'sexo_entrenador') String? sexo,@JsonKey(name: 'foto_entrenador') String? foto,@JsonKey(name: 'direccion_entrenador') String? direccion,@JsonKey(name: 'telefono_entrenador') int? telefono,@JsonKey(name: 'correo_entrenador') String? correo,@JsonKey(name: 'activo_entrenador') bool activo,@JsonKey(name: 'fecha_incio_entrenador') DateTime fechaInicio,@JsonKey(name: 'version') int? version,@JsonKey(name: 'gym_id') String? gymId,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class _$TrainerModelCopyWithImpl<$Res>
    implements $TrainerModelCopyWith<$Res> {
  _$TrainerModelCopyWithImpl(this._self, this._then);

  final TrainerModel _self;
  final $Res Function(TrainerModel) _then;

/// Create a copy of TrainerModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ci = null,Object? documentType = freezed,Object? nombres = freezed,Object? apellidos = freezed,Object? sexo = freezed,Object? foto = freezed,Object? direccion = freezed,Object? telefono = freezed,Object? correo = freezed,Object? activo = null,Object? fechaInicio = null,Object? version = freezed,Object? gymId = freezed,Object? isDeleted = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ci: null == ci ? _self.ci : ci // ignore: cast_nullable_to_non_nullable
as String,documentType: freezed == documentType ? _self.documentType : documentType // ignore: cast_nullable_to_non_nullable
as String?,nombres: freezed == nombres ? _self.nombres : nombres // ignore: cast_nullable_to_non_nullable
as String?,apellidos: freezed == apellidos ? _self.apellidos : apellidos // ignore: cast_nullable_to_non_nullable
as String?,sexo: freezed == sexo ? _self.sexo : sexo // ignore: cast_nullable_to_non_nullable
as String?,foto: freezed == foto ? _self.foto : foto // ignore: cast_nullable_to_non_nullable
as String?,direccion: freezed == direccion ? _self.direccion : direccion // ignore: cast_nullable_to_non_nullable
as String?,telefono: freezed == telefono ? _self.telefono : telefono // ignore: cast_nullable_to_non_nullable
as int?,correo: freezed == correo ? _self.correo : correo // ignore: cast_nullable_to_non_nullable
as String?,activo: null == activo ? _self.activo : activo // ignore: cast_nullable_to_non_nullable
as bool,fechaInicio: null == fechaInicio ? _self.fechaInicio : fechaInicio // ignore: cast_nullable_to_non_nullable
as DateTime,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int?,gymId: freezed == gymId ? _self.gymId : gymId // ignore: cast_nullable_to_non_nullable
as String?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TrainerModel].
extension TrainerModelPatterns on TrainerModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrainerModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrainerModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrainerModel value)  $default,){
final _that = this;
switch (_that) {
case _TrainerModel():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrainerModel value)?  $default,){
final _that = this;
switch (_that) {
case _TrainerModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'id_entrenador')  String id, @JsonKey(name: 'ci_entrenador')  String ci, @JsonKey(name: 'tipo_documento')  String? documentType, @JsonKey(name: 'nombres_entrenador')  String? nombres, @JsonKey(name: 'apellidos_entrenador')  String? apellidos, @JsonKey(name: 'sexo_entrenador')  String? sexo, @JsonKey(name: 'foto_entrenador')  String? foto, @JsonKey(name: 'direccion_entrenador')  String? direccion, @JsonKey(name: 'telefono_entrenador')  int? telefono, @JsonKey(name: 'correo_entrenador')  String? correo, @JsonKey(name: 'activo_entrenador')  bool activo, @JsonKey(name: 'fecha_incio_entrenador')  DateTime fechaInicio, @JsonKey(name: 'version')  int? version, @JsonKey(name: 'gym_id')  String? gymId, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrainerModel() when $default != null:
return $default(_that.id,_that.ci,_that.documentType,_that.nombres,_that.apellidos,_that.sexo,_that.foto,_that.direccion,_that.telefono,_that.correo,_that.activo,_that.fechaInicio,_that.version,_that.gymId,_that.isDeleted);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'id_entrenador')  String id, @JsonKey(name: 'ci_entrenador')  String ci, @JsonKey(name: 'tipo_documento')  String? documentType, @JsonKey(name: 'nombres_entrenador')  String? nombres, @JsonKey(name: 'apellidos_entrenador')  String? apellidos, @JsonKey(name: 'sexo_entrenador')  String? sexo, @JsonKey(name: 'foto_entrenador')  String? foto, @JsonKey(name: 'direccion_entrenador')  String? direccion, @JsonKey(name: 'telefono_entrenador')  int? telefono, @JsonKey(name: 'correo_entrenador')  String? correo, @JsonKey(name: 'activo_entrenador')  bool activo, @JsonKey(name: 'fecha_incio_entrenador')  DateTime fechaInicio, @JsonKey(name: 'version')  int? version, @JsonKey(name: 'gym_id')  String? gymId, @JsonKey(name: 'is_deleted')  bool isDeleted)  $default,) {final _that = this;
switch (_that) {
case _TrainerModel():
return $default(_that.id,_that.ci,_that.documentType,_that.nombres,_that.apellidos,_that.sexo,_that.foto,_that.direccion,_that.telefono,_that.correo,_that.activo,_that.fechaInicio,_that.version,_that.gymId,_that.isDeleted);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'id_entrenador')  String id, @JsonKey(name: 'ci_entrenador')  String ci, @JsonKey(name: 'tipo_documento')  String? documentType, @JsonKey(name: 'nombres_entrenador')  String? nombres, @JsonKey(name: 'apellidos_entrenador')  String? apellidos, @JsonKey(name: 'sexo_entrenador')  String? sexo, @JsonKey(name: 'foto_entrenador')  String? foto, @JsonKey(name: 'direccion_entrenador')  String? direccion, @JsonKey(name: 'telefono_entrenador')  int? telefono, @JsonKey(name: 'correo_entrenador')  String? correo, @JsonKey(name: 'activo_entrenador')  bool activo, @JsonKey(name: 'fecha_incio_entrenador')  DateTime fechaInicio, @JsonKey(name: 'version')  int? version, @JsonKey(name: 'gym_id')  String? gymId, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,) {final _that = this;
switch (_that) {
case _TrainerModel() when $default != null:
return $default(_that.id,_that.ci,_that.documentType,_that.nombres,_that.apellidos,_that.sexo,_that.foto,_that.direccion,_that.telefono,_that.correo,_that.activo,_that.fechaInicio,_that.version,_that.gymId,_that.isDeleted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TrainerModel implements TrainerModel {
  const _TrainerModel({@JsonKey(name: 'id_entrenador') required this.id, @JsonKey(name: 'ci_entrenador') required this.ci, @JsonKey(name: 'tipo_documento') this.documentType, @JsonKey(name: 'nombres_entrenador') this.nombres, @JsonKey(name: 'apellidos_entrenador') this.apellidos, @JsonKey(name: 'sexo_entrenador') this.sexo, @JsonKey(name: 'foto_entrenador') this.foto, @JsonKey(name: 'direccion_entrenador') this.direccion, @JsonKey(name: 'telefono_entrenador') this.telefono, @JsonKey(name: 'correo_entrenador') this.correo, @JsonKey(name: 'activo_entrenador') required this.activo, @JsonKey(name: 'fecha_incio_entrenador') required this.fechaInicio, @JsonKey(name: 'version') this.version, @JsonKey(name: 'gym_id') this.gymId, @JsonKey(name: 'is_deleted') this.isDeleted = false});
  factory _TrainerModel.fromJson(Map<String, dynamic> json) => _$TrainerModelFromJson(json);

@override@JsonKey(name: 'id_entrenador') final  String id;
@override@JsonKey(name: 'ci_entrenador') final  String ci;
@override@JsonKey(name: 'tipo_documento') final  String? documentType;
@override@JsonKey(name: 'nombres_entrenador') final  String? nombres;
@override@JsonKey(name: 'apellidos_entrenador') final  String? apellidos;
@override@JsonKey(name: 'sexo_entrenador') final  String? sexo;
@override@JsonKey(name: 'foto_entrenador') final  String? foto;
@override@JsonKey(name: 'direccion_entrenador') final  String? direccion;
@override@JsonKey(name: 'telefono_entrenador') final  int? telefono;
@override@JsonKey(name: 'correo_entrenador') final  String? correo;
@override@JsonKey(name: 'activo_entrenador') final  bool activo;
@override@JsonKey(name: 'fecha_incio_entrenador') final  DateTime fechaInicio;
@override@JsonKey(name: 'version') final  int? version;
@override@JsonKey(name: 'gym_id') final  String? gymId;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;

/// Create a copy of TrainerModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrainerModelCopyWith<_TrainerModel> get copyWith => __$TrainerModelCopyWithImpl<_TrainerModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrainerModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrainerModel&&(identical(other.id, id) || other.id == id)&&(identical(other.ci, ci) || other.ci == ci)&&(identical(other.documentType, documentType) || other.documentType == documentType)&&(identical(other.nombres, nombres) || other.nombres == nombres)&&(identical(other.apellidos, apellidos) || other.apellidos == apellidos)&&(identical(other.sexo, sexo) || other.sexo == sexo)&&(identical(other.foto, foto) || other.foto == foto)&&(identical(other.direccion, direccion) || other.direccion == direccion)&&(identical(other.telefono, telefono) || other.telefono == telefono)&&(identical(other.correo, correo) || other.correo == correo)&&(identical(other.activo, activo) || other.activo == activo)&&(identical(other.fechaInicio, fechaInicio) || other.fechaInicio == fechaInicio)&&(identical(other.version, version) || other.version == version)&&(identical(other.gymId, gymId) || other.gymId == gymId)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ci,documentType,nombres,apellidos,sexo,foto,direccion,telefono,correo,activo,fechaInicio,version,gymId,isDeleted);

@override
String toString() {
  return 'TrainerModel(id: $id, ci: $ci, documentType: $documentType, nombres: $nombres, apellidos: $apellidos, sexo: $sexo, foto: $foto, direccion: $direccion, telefono: $telefono, correo: $correo, activo: $activo, fechaInicio: $fechaInicio, version: $version, gymId: $gymId, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class _$TrainerModelCopyWith<$Res> implements $TrainerModelCopyWith<$Res> {
  factory _$TrainerModelCopyWith(_TrainerModel value, $Res Function(_TrainerModel) _then) = __$TrainerModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'id_entrenador') String id,@JsonKey(name: 'ci_entrenador') String ci,@JsonKey(name: 'tipo_documento') String? documentType,@JsonKey(name: 'nombres_entrenador') String? nombres,@JsonKey(name: 'apellidos_entrenador') String? apellidos,@JsonKey(name: 'sexo_entrenador') String? sexo,@JsonKey(name: 'foto_entrenador') String? foto,@JsonKey(name: 'direccion_entrenador') String? direccion,@JsonKey(name: 'telefono_entrenador') int? telefono,@JsonKey(name: 'correo_entrenador') String? correo,@JsonKey(name: 'activo_entrenador') bool activo,@JsonKey(name: 'fecha_incio_entrenador') DateTime fechaInicio,@JsonKey(name: 'version') int? version,@JsonKey(name: 'gym_id') String? gymId,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class __$TrainerModelCopyWithImpl<$Res>
    implements _$TrainerModelCopyWith<$Res> {
  __$TrainerModelCopyWithImpl(this._self, this._then);

  final _TrainerModel _self;
  final $Res Function(_TrainerModel) _then;

/// Create a copy of TrainerModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ci = null,Object? documentType = freezed,Object? nombres = freezed,Object? apellidos = freezed,Object? sexo = freezed,Object? foto = freezed,Object? direccion = freezed,Object? telefono = freezed,Object? correo = freezed,Object? activo = null,Object? fechaInicio = null,Object? version = freezed,Object? gymId = freezed,Object? isDeleted = null,}) {
  return _then(_TrainerModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ci: null == ci ? _self.ci : ci // ignore: cast_nullable_to_non_nullable
as String,documentType: freezed == documentType ? _self.documentType : documentType // ignore: cast_nullable_to_non_nullable
as String?,nombres: freezed == nombres ? _self.nombres : nombres // ignore: cast_nullable_to_non_nullable
as String?,apellidos: freezed == apellidos ? _self.apellidos : apellidos // ignore: cast_nullable_to_non_nullable
as String?,sexo: freezed == sexo ? _self.sexo : sexo // ignore: cast_nullable_to_non_nullable
as String?,foto: freezed == foto ? _self.foto : foto // ignore: cast_nullable_to_non_nullable
as String?,direccion: freezed == direccion ? _self.direccion : direccion // ignore: cast_nullable_to_non_nullable
as String?,telefono: freezed == telefono ? _self.telefono : telefono // ignore: cast_nullable_to_non_nullable
as int?,correo: freezed == correo ? _self.correo : correo // ignore: cast_nullable_to_non_nullable
as String?,activo: null == activo ? _self.activo : activo // ignore: cast_nullable_to_non_nullable
as bool,fechaInicio: null == fechaInicio ? _self.fechaInicio : fechaInicio // ignore: cast_nullable_to_non_nullable
as DateTime,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int?,gymId: freezed == gymId ? _self.gymId : gymId // ignore: cast_nullable_to_non_nullable
as String?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
