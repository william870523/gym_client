// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'referencia_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReferenciaModel {

@JsonKey(name: 'referencia_id') String get id;@JsonKey(name: 'nombre_referencia') String get nombre;@JsonKey(name: 'is_deleted') bool get isDeleted;
/// Create a copy of ReferenciaModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReferenciaModelCopyWith<ReferenciaModel> get copyWith => _$ReferenciaModelCopyWithImpl<ReferenciaModel>(this as ReferenciaModel, _$identity);

  /// Serializes this ReferenciaModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReferenciaModel&&(identical(other.id, id) || other.id == id)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nombre,isDeleted);

@override
String toString() {
  return 'ReferenciaModel(id: $id, nombre: $nombre, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class $ReferenciaModelCopyWith<$Res>  {
  factory $ReferenciaModelCopyWith(ReferenciaModel value, $Res Function(ReferenciaModel) _then) = _$ReferenciaModelCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'referencia_id') String id,@JsonKey(name: 'nombre_referencia') String nombre,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class _$ReferenciaModelCopyWithImpl<$Res>
    implements $ReferenciaModelCopyWith<$Res> {
  _$ReferenciaModelCopyWithImpl(this._self, this._then);

  final ReferenciaModel _self;
  final $Res Function(ReferenciaModel) _then;

/// Create a copy of ReferenciaModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? nombre = null,Object? isDeleted = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ReferenciaModel].
extension ReferenciaModelPatterns on ReferenciaModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReferenciaModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReferenciaModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReferenciaModel value)  $default,){
final _that = this;
switch (_that) {
case _ReferenciaModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReferenciaModel value)?  $default,){
final _that = this;
switch (_that) {
case _ReferenciaModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'referencia_id')  String id, @JsonKey(name: 'nombre_referencia')  String nombre, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReferenciaModel() when $default != null:
return $default(_that.id,_that.nombre,_that.isDeleted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'referencia_id')  String id, @JsonKey(name: 'nombre_referencia')  String nombre, @JsonKey(name: 'is_deleted')  bool isDeleted)  $default,) {final _that = this;
switch (_that) {
case _ReferenciaModel():
return $default(_that.id,_that.nombre,_that.isDeleted);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'referencia_id')  String id, @JsonKey(name: 'nombre_referencia')  String nombre, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,) {final _that = this;
switch (_that) {
case _ReferenciaModel() when $default != null:
return $default(_that.id,_that.nombre,_that.isDeleted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReferenciaModel implements ReferenciaModel {
  const _ReferenciaModel({@JsonKey(name: 'referencia_id') required this.id, @JsonKey(name: 'nombre_referencia') required this.nombre, @JsonKey(name: 'is_deleted') this.isDeleted = false});
  factory _ReferenciaModel.fromJson(Map<String, dynamic> json) => _$ReferenciaModelFromJson(json);

@override@JsonKey(name: 'referencia_id') final  String id;
@override@JsonKey(name: 'nombre_referencia') final  String nombre;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;

/// Create a copy of ReferenciaModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReferenciaModelCopyWith<_ReferenciaModel> get copyWith => __$ReferenciaModelCopyWithImpl<_ReferenciaModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReferenciaModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReferenciaModel&&(identical(other.id, id) || other.id == id)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nombre,isDeleted);

@override
String toString() {
  return 'ReferenciaModel(id: $id, nombre: $nombre, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class _$ReferenciaModelCopyWith<$Res> implements $ReferenciaModelCopyWith<$Res> {
  factory _$ReferenciaModelCopyWith(_ReferenciaModel value, $Res Function(_ReferenciaModel) _then) = __$ReferenciaModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'referencia_id') String id,@JsonKey(name: 'nombre_referencia') String nombre,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class __$ReferenciaModelCopyWithImpl<$Res>
    implements _$ReferenciaModelCopyWith<$Res> {
  __$ReferenciaModelCopyWithImpl(this._self, this._then);

  final _ReferenciaModel _self;
  final $Res Function(_ReferenciaModel) _then;

/// Create a copy of ReferenciaModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? nombre = null,Object? isDeleted = null,}) {
  return _then(_ReferenciaModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
