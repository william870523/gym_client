// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'client.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Client {

 String get ci; String get nombres; String get apellidos;@JsonKey(name: 'fecha_registro') DateTime get fechaRegistro;@JsonKey(name: 'gym_id') String? get gymId;
/// Create a copy of Client
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClientCopyWith<Client> get copyWith => _$ClientCopyWithImpl<Client>(this as Client, _$identity);

  /// Serializes this Client to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Client&&(identical(other.ci, ci) || other.ci == ci)&&(identical(other.nombres, nombres) || other.nombres == nombres)&&(identical(other.apellidos, apellidos) || other.apellidos == apellidos)&&(identical(other.fechaRegistro, fechaRegistro) || other.fechaRegistro == fechaRegistro)&&(identical(other.gymId, gymId) || other.gymId == gymId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ci,nombres,apellidos,fechaRegistro,gymId);

@override
String toString() {
  return 'Client(ci: $ci, nombres: $nombres, apellidos: $apellidos, fechaRegistro: $fechaRegistro, gymId: $gymId)';
}


}

/// @nodoc
abstract mixin class $ClientCopyWith<$Res>  {
  factory $ClientCopyWith(Client value, $Res Function(Client) _then) = _$ClientCopyWithImpl;
@useResult
$Res call({
 String ci, String nombres, String apellidos,@JsonKey(name: 'fecha_registro') DateTime fechaRegistro,@JsonKey(name: 'gym_id') String? gymId
});




}
/// @nodoc
class _$ClientCopyWithImpl<$Res>
    implements $ClientCopyWith<$Res> {
  _$ClientCopyWithImpl(this._self, this._then);

  final Client _self;
  final $Res Function(Client) _then;

/// Create a copy of Client
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ci = null,Object? nombres = null,Object? apellidos = null,Object? fechaRegistro = null,Object? gymId = freezed,}) {
  return _then(_self.copyWith(
ci: null == ci ? _self.ci : ci // ignore: cast_nullable_to_non_nullable
as String,nombres: null == nombres ? _self.nombres : nombres // ignore: cast_nullable_to_non_nullable
as String,apellidos: null == apellidos ? _self.apellidos : apellidos // ignore: cast_nullable_to_non_nullable
as String,fechaRegistro: null == fechaRegistro ? _self.fechaRegistro : fechaRegistro // ignore: cast_nullable_to_non_nullable
as DateTime,gymId: freezed == gymId ? _self.gymId : gymId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Client].
extension ClientPatterns on Client {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Client value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Client() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Client value)  $default,){
final _that = this;
switch (_that) {
case _Client():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Client value)?  $default,){
final _that = this;
switch (_that) {
case _Client() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ci,  String nombres,  String apellidos, @JsonKey(name: 'fecha_registro')  DateTime fechaRegistro, @JsonKey(name: 'gym_id')  String? gymId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Client() when $default != null:
return $default(_that.ci,_that.nombres,_that.apellidos,_that.fechaRegistro,_that.gymId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ci,  String nombres,  String apellidos, @JsonKey(name: 'fecha_registro')  DateTime fechaRegistro, @JsonKey(name: 'gym_id')  String? gymId)  $default,) {final _that = this;
switch (_that) {
case _Client():
return $default(_that.ci,_that.nombres,_that.apellidos,_that.fechaRegistro,_that.gymId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ci,  String nombres,  String apellidos, @JsonKey(name: 'fecha_registro')  DateTime fechaRegistro, @JsonKey(name: 'gym_id')  String? gymId)?  $default,) {final _that = this;
switch (_that) {
case _Client() when $default != null:
return $default(_that.ci,_that.nombres,_that.apellidos,_that.fechaRegistro,_that.gymId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Client implements Client {
  const _Client({required this.ci, required this.nombres, required this.apellidos, @JsonKey(name: 'fecha_registro') required this.fechaRegistro, @JsonKey(name: 'gym_id') this.gymId});
  factory _Client.fromJson(Map<String, dynamic> json) => _$ClientFromJson(json);

@override final  String ci;
@override final  String nombres;
@override final  String apellidos;
@override@JsonKey(name: 'fecha_registro') final  DateTime fechaRegistro;
@override@JsonKey(name: 'gym_id') final  String? gymId;

/// Create a copy of Client
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClientCopyWith<_Client> get copyWith => __$ClientCopyWithImpl<_Client>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClientToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Client&&(identical(other.ci, ci) || other.ci == ci)&&(identical(other.nombres, nombres) || other.nombres == nombres)&&(identical(other.apellidos, apellidos) || other.apellidos == apellidos)&&(identical(other.fechaRegistro, fechaRegistro) || other.fechaRegistro == fechaRegistro)&&(identical(other.gymId, gymId) || other.gymId == gymId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ci,nombres,apellidos,fechaRegistro,gymId);

@override
String toString() {
  return 'Client(ci: $ci, nombres: $nombres, apellidos: $apellidos, fechaRegistro: $fechaRegistro, gymId: $gymId)';
}


}

/// @nodoc
abstract mixin class _$ClientCopyWith<$Res> implements $ClientCopyWith<$Res> {
  factory _$ClientCopyWith(_Client value, $Res Function(_Client) _then) = __$ClientCopyWithImpl;
@override @useResult
$Res call({
 String ci, String nombres, String apellidos,@JsonKey(name: 'fecha_registro') DateTime fechaRegistro,@JsonKey(name: 'gym_id') String? gymId
});




}
/// @nodoc
class __$ClientCopyWithImpl<$Res>
    implements _$ClientCopyWith<$Res> {
  __$ClientCopyWithImpl(this._self, this._then);

  final _Client _self;
  final $Res Function(_Client) _then;

/// Create a copy of Client
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ci = null,Object? nombres = null,Object? apellidos = null,Object? fechaRegistro = null,Object? gymId = freezed,}) {
  return _then(_Client(
ci: null == ci ? _self.ci : ci // ignore: cast_nullable_to_non_nullable
as String,nombres: null == nombres ? _self.nombres : nombres // ignore: cast_nullable_to_non_nullable
as String,apellidos: null == apellidos ? _self.apellidos : apellidos // ignore: cast_nullable_to_non_nullable
as String,fechaRegistro: null == fechaRegistro ? _self.fechaRegistro : fechaRegistro // ignore: cast_nullable_to_non_nullable
as DateTime,gymId: freezed == gymId ? _self.gymId : gymId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
