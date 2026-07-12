// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'currency_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CurrencyModel {

@JsonKey(name: 'moneda_id') String get id;@JsonKey(name: 'moneda_nombre') String get name;@JsonKey(name: 'codigo') String get code;@JsonKey(name: 'simbolo') String? get symbol;@JsonKey(name: 'imagen') String? get flagImage;
/// Create a copy of CurrencyModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CurrencyModelCopyWith<CurrencyModel> get copyWith => _$CurrencyModelCopyWithImpl<CurrencyModel>(this as CurrencyModel, _$identity);

  /// Serializes this CurrencyModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CurrencyModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.code, code) || other.code == code)&&(identical(other.symbol, symbol) || other.symbol == symbol)&&(identical(other.flagImage, flagImage) || other.flagImage == flagImage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,code,symbol,flagImage);

@override
String toString() {
  return 'CurrencyModel(id: $id, name: $name, code: $code, symbol: $symbol, flagImage: $flagImage)';
}


}

/// @nodoc
abstract mixin class $CurrencyModelCopyWith<$Res>  {
  factory $CurrencyModelCopyWith(CurrencyModel value, $Res Function(CurrencyModel) _then) = _$CurrencyModelCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'moneda_id') String id,@JsonKey(name: 'moneda_nombre') String name,@JsonKey(name: 'codigo') String code,@JsonKey(name: 'simbolo') String? symbol,@JsonKey(name: 'imagen') String? flagImage
});




}
/// @nodoc
class _$CurrencyModelCopyWithImpl<$Res>
    implements $CurrencyModelCopyWith<$Res> {
  _$CurrencyModelCopyWithImpl(this._self, this._then);

  final CurrencyModel _self;
  final $Res Function(CurrencyModel) _then;

/// Create a copy of CurrencyModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? code = null,Object? symbol = freezed,Object? flagImage = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,symbol: freezed == symbol ? _self.symbol : symbol // ignore: cast_nullable_to_non_nullable
as String?,flagImage: freezed == flagImage ? _self.flagImage : flagImage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CurrencyModel].
extension CurrencyModelPatterns on CurrencyModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CurrencyModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CurrencyModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CurrencyModel value)  $default,){
final _that = this;
switch (_that) {
case _CurrencyModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CurrencyModel value)?  $default,){
final _that = this;
switch (_that) {
case _CurrencyModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'moneda_id')  String id, @JsonKey(name: 'moneda_nombre')  String name, @JsonKey(name: 'codigo')  String code, @JsonKey(name: 'simbolo')  String? symbol, @JsonKey(name: 'imagen')  String? flagImage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CurrencyModel() when $default != null:
return $default(_that.id,_that.name,_that.code,_that.symbol,_that.flagImage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'moneda_id')  String id, @JsonKey(name: 'moneda_nombre')  String name, @JsonKey(name: 'codigo')  String code, @JsonKey(name: 'simbolo')  String? symbol, @JsonKey(name: 'imagen')  String? flagImage)  $default,) {final _that = this;
switch (_that) {
case _CurrencyModel():
return $default(_that.id,_that.name,_that.code,_that.symbol,_that.flagImage);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'moneda_id')  String id, @JsonKey(name: 'moneda_nombre')  String name, @JsonKey(name: 'codigo')  String code, @JsonKey(name: 'simbolo')  String? symbol, @JsonKey(name: 'imagen')  String? flagImage)?  $default,) {final _that = this;
switch (_that) {
case _CurrencyModel() when $default != null:
return $default(_that.id,_that.name,_that.code,_that.symbol,_that.flagImage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CurrencyModel implements CurrencyModel {
  const _CurrencyModel({@JsonKey(name: 'moneda_id') required this.id, @JsonKey(name: 'moneda_nombre') required this.name, @JsonKey(name: 'codigo') required this.code, @JsonKey(name: 'simbolo') this.symbol, @JsonKey(name: 'imagen') this.flagImage});
  factory _CurrencyModel.fromJson(Map<String, dynamic> json) => _$CurrencyModelFromJson(json);

@override@JsonKey(name: 'moneda_id') final  String id;
@override@JsonKey(name: 'moneda_nombre') final  String name;
@override@JsonKey(name: 'codigo') final  String code;
@override@JsonKey(name: 'simbolo') final  String? symbol;
@override@JsonKey(name: 'imagen') final  String? flagImage;

/// Create a copy of CurrencyModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CurrencyModelCopyWith<_CurrencyModel> get copyWith => __$CurrencyModelCopyWithImpl<_CurrencyModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CurrencyModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CurrencyModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.code, code) || other.code == code)&&(identical(other.symbol, symbol) || other.symbol == symbol)&&(identical(other.flagImage, flagImage) || other.flagImage == flagImage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,code,symbol,flagImage);

@override
String toString() {
  return 'CurrencyModel(id: $id, name: $name, code: $code, symbol: $symbol, flagImage: $flagImage)';
}


}

/// @nodoc
abstract mixin class _$CurrencyModelCopyWith<$Res> implements $CurrencyModelCopyWith<$Res> {
  factory _$CurrencyModelCopyWith(_CurrencyModel value, $Res Function(_CurrencyModel) _then) = __$CurrencyModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'moneda_id') String id,@JsonKey(name: 'moneda_nombre') String name,@JsonKey(name: 'codigo') String code,@JsonKey(name: 'simbolo') String? symbol,@JsonKey(name: 'imagen') String? flagImage
});




}
/// @nodoc
class __$CurrencyModelCopyWithImpl<$Res>
    implements _$CurrencyModelCopyWith<$Res> {
  __$CurrencyModelCopyWithImpl(this._self, this._then);

  final _CurrencyModel _self;
  final $Res Function(_CurrencyModel) _then;

/// Create a copy of CurrencyModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? code = null,Object? symbol = freezed,Object? flagImage = freezed,}) {
  return _then(_CurrencyModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,symbol: freezed == symbol ? _self.symbol : symbol // ignore: cast_nullable_to_non_nullable
as String?,flagImage: freezed == flagImage ? _self.flagImage : flagImage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
