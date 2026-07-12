// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'nacionalidad_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NacionalidadModel {

@JsonKey(name: 'nacionalidad_id') String get id;@JsonKey(name: 'nacionalidad_nombre') String get name;@JsonKey(name: 'codigo_iso') String get isoCode;@JsonKey(name: 'bandera') String? get flagImage;// Base64 string
@JsonKey(name: 'is_deleted') bool get isDeleted;
/// Create a copy of NacionalidadModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NacionalidadModelCopyWith<NacionalidadModel> get copyWith => _$NacionalidadModelCopyWithImpl<NacionalidadModel>(this as NacionalidadModel, _$identity);

  /// Serializes this NacionalidadModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NacionalidadModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.isoCode, isoCode) || other.isoCode == isoCode)&&(identical(other.flagImage, flagImage) || other.flagImage == flagImage)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,isoCode,flagImage,isDeleted);

@override
String toString() {
  return 'NacionalidadModel(id: $id, name: $name, isoCode: $isoCode, flagImage: $flagImage, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class $NacionalidadModelCopyWith<$Res>  {
  factory $NacionalidadModelCopyWith(NacionalidadModel value, $Res Function(NacionalidadModel) _then) = _$NacionalidadModelCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'nacionalidad_id') String id,@JsonKey(name: 'nacionalidad_nombre') String name,@JsonKey(name: 'codigo_iso') String isoCode,@JsonKey(name: 'bandera') String? flagImage,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class _$NacionalidadModelCopyWithImpl<$Res>
    implements $NacionalidadModelCopyWith<$Res> {
  _$NacionalidadModelCopyWithImpl(this._self, this._then);

  final NacionalidadModel _self;
  final $Res Function(NacionalidadModel) _then;

/// Create a copy of NacionalidadModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? isoCode = null,Object? flagImage = freezed,Object? isDeleted = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isoCode: null == isoCode ? _self.isoCode : isoCode // ignore: cast_nullable_to_non_nullable
as String,flagImage: freezed == flagImage ? _self.flagImage : flagImage // ignore: cast_nullable_to_non_nullable
as String?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [NacionalidadModel].
extension NacionalidadModelPatterns on NacionalidadModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NacionalidadModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NacionalidadModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NacionalidadModel value)  $default,){
final _that = this;
switch (_that) {
case _NacionalidadModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NacionalidadModel value)?  $default,){
final _that = this;
switch (_that) {
case _NacionalidadModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'nacionalidad_id')  String id, @JsonKey(name: 'nacionalidad_nombre')  String name, @JsonKey(name: 'codigo_iso')  String isoCode, @JsonKey(name: 'bandera')  String? flagImage, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NacionalidadModel() when $default != null:
return $default(_that.id,_that.name,_that.isoCode,_that.flagImage,_that.isDeleted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'nacionalidad_id')  String id, @JsonKey(name: 'nacionalidad_nombre')  String name, @JsonKey(name: 'codigo_iso')  String isoCode, @JsonKey(name: 'bandera')  String? flagImage, @JsonKey(name: 'is_deleted')  bool isDeleted)  $default,) {final _that = this;
switch (_that) {
case _NacionalidadModel():
return $default(_that.id,_that.name,_that.isoCode,_that.flagImage,_that.isDeleted);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'nacionalidad_id')  String id, @JsonKey(name: 'nacionalidad_nombre')  String name, @JsonKey(name: 'codigo_iso')  String isoCode, @JsonKey(name: 'bandera')  String? flagImage, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,) {final _that = this;
switch (_that) {
case _NacionalidadModel() when $default != null:
return $default(_that.id,_that.name,_that.isoCode,_that.flagImage,_that.isDeleted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NacionalidadModel implements NacionalidadModel {
  const _NacionalidadModel({@JsonKey(name: 'nacionalidad_id') required this.id, @JsonKey(name: 'nacionalidad_nombre') required this.name, @JsonKey(name: 'codigo_iso') required this.isoCode, @JsonKey(name: 'bandera') this.flagImage, @JsonKey(name: 'is_deleted') this.isDeleted = false});
  factory _NacionalidadModel.fromJson(Map<String, dynamic> json) => _$NacionalidadModelFromJson(json);

@override@JsonKey(name: 'nacionalidad_id') final  String id;
@override@JsonKey(name: 'nacionalidad_nombre') final  String name;
@override@JsonKey(name: 'codigo_iso') final  String isoCode;
@override@JsonKey(name: 'bandera') final  String? flagImage;
// Base64 string
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;

/// Create a copy of NacionalidadModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NacionalidadModelCopyWith<_NacionalidadModel> get copyWith => __$NacionalidadModelCopyWithImpl<_NacionalidadModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NacionalidadModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NacionalidadModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.isoCode, isoCode) || other.isoCode == isoCode)&&(identical(other.flagImage, flagImage) || other.flagImage == flagImage)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,isoCode,flagImage,isDeleted);

@override
String toString() {
  return 'NacionalidadModel(id: $id, name: $name, isoCode: $isoCode, flagImage: $flagImage, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class _$NacionalidadModelCopyWith<$Res> implements $NacionalidadModelCopyWith<$Res> {
  factory _$NacionalidadModelCopyWith(_NacionalidadModel value, $Res Function(_NacionalidadModel) _then) = __$NacionalidadModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'nacionalidad_id') String id,@JsonKey(name: 'nacionalidad_nombre') String name,@JsonKey(name: 'codigo_iso') String isoCode,@JsonKey(name: 'bandera') String? flagImage,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class __$NacionalidadModelCopyWithImpl<$Res>
    implements _$NacionalidadModelCopyWith<$Res> {
  __$NacionalidadModelCopyWithImpl(this._self, this._then);

  final _NacionalidadModel _self;
  final $Res Function(_NacionalidadModel) _then;

/// Create a copy of NacionalidadModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? isoCode = null,Object? flagImage = freezed,Object? isDeleted = null,}) {
  return _then(_NacionalidadModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isoCode: null == isoCode ? _self.isoCode : isoCode // ignore: cast_nullable_to_non_nullable
as String,flagImage: freezed == flagImage ? _self.flagImage : flagImage // ignore: cast_nullable_to_non_nullable
as String?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
