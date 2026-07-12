// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'exchange_rate_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ExchangeRateModel {

@JsonKey(name: 'tipo_cambio_id') String get id;@JsonKey(name: 'moneda_id_base') String get monedaIdBase;@JsonKey(name: 'moneda_id_target') String get monedaIdTarget;@JsonKey(name: 'exchange_rate') double get exchangeRate;@JsonKey(name: 'fecha_inicio') DateTime get fechaInicio;@JsonKey(name: 'fecha_expiracion') DateTime? get fechaExpiracion; bool get activo;@JsonKey(name: 'moneda_base') CurrencyModel? get monedaBase;@JsonKey(name: 'moneda_target') CurrencyModel? get monedaTarget;@JsonKey(name: 'created_at') DateTime? get createdAt;@JsonKey(name: 'updated_at') DateTime? get updatedAt;
/// Create a copy of ExchangeRateModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExchangeRateModelCopyWith<ExchangeRateModel> get copyWith => _$ExchangeRateModelCopyWithImpl<ExchangeRateModel>(this as ExchangeRateModel, _$identity);

  /// Serializes this ExchangeRateModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExchangeRateModel&&(identical(other.id, id) || other.id == id)&&(identical(other.monedaIdBase, monedaIdBase) || other.monedaIdBase == monedaIdBase)&&(identical(other.monedaIdTarget, monedaIdTarget) || other.monedaIdTarget == monedaIdTarget)&&(identical(other.exchangeRate, exchangeRate) || other.exchangeRate == exchangeRate)&&(identical(other.fechaInicio, fechaInicio) || other.fechaInicio == fechaInicio)&&(identical(other.fechaExpiracion, fechaExpiracion) || other.fechaExpiracion == fechaExpiracion)&&(identical(other.activo, activo) || other.activo == activo)&&(identical(other.monedaBase, monedaBase) || other.monedaBase == monedaBase)&&(identical(other.monedaTarget, monedaTarget) || other.monedaTarget == monedaTarget)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,monedaIdBase,monedaIdTarget,exchangeRate,fechaInicio,fechaExpiracion,activo,monedaBase,monedaTarget,createdAt,updatedAt);

@override
String toString() {
  return 'ExchangeRateModel(id: $id, monedaIdBase: $monedaIdBase, monedaIdTarget: $monedaIdTarget, exchangeRate: $exchangeRate, fechaInicio: $fechaInicio, fechaExpiracion: $fechaExpiracion, activo: $activo, monedaBase: $monedaBase, monedaTarget: $monedaTarget, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ExchangeRateModelCopyWith<$Res>  {
  factory $ExchangeRateModelCopyWith(ExchangeRateModel value, $Res Function(ExchangeRateModel) _then) = _$ExchangeRateModelCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'tipo_cambio_id') String id,@JsonKey(name: 'moneda_id_base') String monedaIdBase,@JsonKey(name: 'moneda_id_target') String monedaIdTarget,@JsonKey(name: 'exchange_rate') double exchangeRate,@JsonKey(name: 'fecha_inicio') DateTime fechaInicio,@JsonKey(name: 'fecha_expiracion') DateTime? fechaExpiracion, bool activo,@JsonKey(name: 'moneda_base') CurrencyModel? monedaBase,@JsonKey(name: 'moneda_target') CurrencyModel? monedaTarget,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});


$CurrencyModelCopyWith<$Res>? get monedaBase;$CurrencyModelCopyWith<$Res>? get monedaTarget;

}
/// @nodoc
class _$ExchangeRateModelCopyWithImpl<$Res>
    implements $ExchangeRateModelCopyWith<$Res> {
  _$ExchangeRateModelCopyWithImpl(this._self, this._then);

  final ExchangeRateModel _self;
  final $Res Function(ExchangeRateModel) _then;

/// Create a copy of ExchangeRateModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? monedaIdBase = null,Object? monedaIdTarget = null,Object? exchangeRate = null,Object? fechaInicio = null,Object? fechaExpiracion = freezed,Object? activo = null,Object? monedaBase = freezed,Object? monedaTarget = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,monedaIdBase: null == monedaIdBase ? _self.monedaIdBase : monedaIdBase // ignore: cast_nullable_to_non_nullable
as String,monedaIdTarget: null == monedaIdTarget ? _self.monedaIdTarget : monedaIdTarget // ignore: cast_nullable_to_non_nullable
as String,exchangeRate: null == exchangeRate ? _self.exchangeRate : exchangeRate // ignore: cast_nullable_to_non_nullable
as double,fechaInicio: null == fechaInicio ? _self.fechaInicio : fechaInicio // ignore: cast_nullable_to_non_nullable
as DateTime,fechaExpiracion: freezed == fechaExpiracion ? _self.fechaExpiracion : fechaExpiracion // ignore: cast_nullable_to_non_nullable
as DateTime?,activo: null == activo ? _self.activo : activo // ignore: cast_nullable_to_non_nullable
as bool,monedaBase: freezed == monedaBase ? _self.monedaBase : monedaBase // ignore: cast_nullable_to_non_nullable
as CurrencyModel?,monedaTarget: freezed == monedaTarget ? _self.monedaTarget : monedaTarget // ignore: cast_nullable_to_non_nullable
as CurrencyModel?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of ExchangeRateModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CurrencyModelCopyWith<$Res>? get monedaBase {
    if (_self.monedaBase == null) {
    return null;
  }

  return $CurrencyModelCopyWith<$Res>(_self.monedaBase!, (value) {
    return _then(_self.copyWith(monedaBase: value));
  });
}/// Create a copy of ExchangeRateModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CurrencyModelCopyWith<$Res>? get monedaTarget {
    if (_self.monedaTarget == null) {
    return null;
  }

  return $CurrencyModelCopyWith<$Res>(_self.monedaTarget!, (value) {
    return _then(_self.copyWith(monedaTarget: value));
  });
}
}


/// Adds pattern-matching-related methods to [ExchangeRateModel].
extension ExchangeRateModelPatterns on ExchangeRateModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExchangeRateModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExchangeRateModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExchangeRateModel value)  $default,){
final _that = this;
switch (_that) {
case _ExchangeRateModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExchangeRateModel value)?  $default,){
final _that = this;
switch (_that) {
case _ExchangeRateModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'tipo_cambio_id')  String id, @JsonKey(name: 'moneda_id_base')  String monedaIdBase, @JsonKey(name: 'moneda_id_target')  String monedaIdTarget, @JsonKey(name: 'exchange_rate')  double exchangeRate, @JsonKey(name: 'fecha_inicio')  DateTime fechaInicio, @JsonKey(name: 'fecha_expiracion')  DateTime? fechaExpiracion,  bool activo, @JsonKey(name: 'moneda_base')  CurrencyModel? monedaBase, @JsonKey(name: 'moneda_target')  CurrencyModel? monedaTarget, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExchangeRateModel() when $default != null:
return $default(_that.id,_that.monedaIdBase,_that.monedaIdTarget,_that.exchangeRate,_that.fechaInicio,_that.fechaExpiracion,_that.activo,_that.monedaBase,_that.monedaTarget,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'tipo_cambio_id')  String id, @JsonKey(name: 'moneda_id_base')  String monedaIdBase, @JsonKey(name: 'moneda_id_target')  String monedaIdTarget, @JsonKey(name: 'exchange_rate')  double exchangeRate, @JsonKey(name: 'fecha_inicio')  DateTime fechaInicio, @JsonKey(name: 'fecha_expiracion')  DateTime? fechaExpiracion,  bool activo, @JsonKey(name: 'moneda_base')  CurrencyModel? monedaBase, @JsonKey(name: 'moneda_target')  CurrencyModel? monedaTarget, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ExchangeRateModel():
return $default(_that.id,_that.monedaIdBase,_that.monedaIdTarget,_that.exchangeRate,_that.fechaInicio,_that.fechaExpiracion,_that.activo,_that.monedaBase,_that.monedaTarget,_that.createdAt,_that.updatedAt);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'tipo_cambio_id')  String id, @JsonKey(name: 'moneda_id_base')  String monedaIdBase, @JsonKey(name: 'moneda_id_target')  String monedaIdTarget, @JsonKey(name: 'exchange_rate')  double exchangeRate, @JsonKey(name: 'fecha_inicio')  DateTime fechaInicio, @JsonKey(name: 'fecha_expiracion')  DateTime? fechaExpiracion,  bool activo, @JsonKey(name: 'moneda_base')  CurrencyModel? monedaBase, @JsonKey(name: 'moneda_target')  CurrencyModel? monedaTarget, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ExchangeRateModel() when $default != null:
return $default(_that.id,_that.monedaIdBase,_that.monedaIdTarget,_that.exchangeRate,_that.fechaInicio,_that.fechaExpiracion,_that.activo,_that.monedaBase,_that.monedaTarget,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExchangeRateModel implements ExchangeRateModel {
  const _ExchangeRateModel({@JsonKey(name: 'tipo_cambio_id') required this.id, @JsonKey(name: 'moneda_id_base') required this.monedaIdBase, @JsonKey(name: 'moneda_id_target') required this.monedaIdTarget, @JsonKey(name: 'exchange_rate') required this.exchangeRate, @JsonKey(name: 'fecha_inicio') required this.fechaInicio, @JsonKey(name: 'fecha_expiracion') this.fechaExpiracion, this.activo = true, @JsonKey(name: 'moneda_base') this.monedaBase, @JsonKey(name: 'moneda_target') this.monedaTarget, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt});
  factory _ExchangeRateModel.fromJson(Map<String, dynamic> json) => _$ExchangeRateModelFromJson(json);

@override@JsonKey(name: 'tipo_cambio_id') final  String id;
@override@JsonKey(name: 'moneda_id_base') final  String monedaIdBase;
@override@JsonKey(name: 'moneda_id_target') final  String monedaIdTarget;
@override@JsonKey(name: 'exchange_rate') final  double exchangeRate;
@override@JsonKey(name: 'fecha_inicio') final  DateTime fechaInicio;
@override@JsonKey(name: 'fecha_expiracion') final  DateTime? fechaExpiracion;
@override@JsonKey() final  bool activo;
@override@JsonKey(name: 'moneda_base') final  CurrencyModel? monedaBase;
@override@JsonKey(name: 'moneda_target') final  CurrencyModel? monedaTarget;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;

/// Create a copy of ExchangeRateModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExchangeRateModelCopyWith<_ExchangeRateModel> get copyWith => __$ExchangeRateModelCopyWithImpl<_ExchangeRateModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExchangeRateModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExchangeRateModel&&(identical(other.id, id) || other.id == id)&&(identical(other.monedaIdBase, monedaIdBase) || other.monedaIdBase == monedaIdBase)&&(identical(other.monedaIdTarget, monedaIdTarget) || other.monedaIdTarget == monedaIdTarget)&&(identical(other.exchangeRate, exchangeRate) || other.exchangeRate == exchangeRate)&&(identical(other.fechaInicio, fechaInicio) || other.fechaInicio == fechaInicio)&&(identical(other.fechaExpiracion, fechaExpiracion) || other.fechaExpiracion == fechaExpiracion)&&(identical(other.activo, activo) || other.activo == activo)&&(identical(other.monedaBase, monedaBase) || other.monedaBase == monedaBase)&&(identical(other.monedaTarget, monedaTarget) || other.monedaTarget == monedaTarget)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,monedaIdBase,monedaIdTarget,exchangeRate,fechaInicio,fechaExpiracion,activo,monedaBase,monedaTarget,createdAt,updatedAt);

@override
String toString() {
  return 'ExchangeRateModel(id: $id, monedaIdBase: $monedaIdBase, monedaIdTarget: $monedaIdTarget, exchangeRate: $exchangeRate, fechaInicio: $fechaInicio, fechaExpiracion: $fechaExpiracion, activo: $activo, monedaBase: $monedaBase, monedaTarget: $monedaTarget, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ExchangeRateModelCopyWith<$Res> implements $ExchangeRateModelCopyWith<$Res> {
  factory _$ExchangeRateModelCopyWith(_ExchangeRateModel value, $Res Function(_ExchangeRateModel) _then) = __$ExchangeRateModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'tipo_cambio_id') String id,@JsonKey(name: 'moneda_id_base') String monedaIdBase,@JsonKey(name: 'moneda_id_target') String monedaIdTarget,@JsonKey(name: 'exchange_rate') double exchangeRate,@JsonKey(name: 'fecha_inicio') DateTime fechaInicio,@JsonKey(name: 'fecha_expiracion') DateTime? fechaExpiracion, bool activo,@JsonKey(name: 'moneda_base') CurrencyModel? monedaBase,@JsonKey(name: 'moneda_target') CurrencyModel? monedaTarget,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});


@override $CurrencyModelCopyWith<$Res>? get monedaBase;@override $CurrencyModelCopyWith<$Res>? get monedaTarget;

}
/// @nodoc
class __$ExchangeRateModelCopyWithImpl<$Res>
    implements _$ExchangeRateModelCopyWith<$Res> {
  __$ExchangeRateModelCopyWithImpl(this._self, this._then);

  final _ExchangeRateModel _self;
  final $Res Function(_ExchangeRateModel) _then;

/// Create a copy of ExchangeRateModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? monedaIdBase = null,Object? monedaIdTarget = null,Object? exchangeRate = null,Object? fechaInicio = null,Object? fechaExpiracion = freezed,Object? activo = null,Object? monedaBase = freezed,Object? monedaTarget = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_ExchangeRateModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,monedaIdBase: null == monedaIdBase ? _self.monedaIdBase : monedaIdBase // ignore: cast_nullable_to_non_nullable
as String,monedaIdTarget: null == monedaIdTarget ? _self.monedaIdTarget : monedaIdTarget // ignore: cast_nullable_to_non_nullable
as String,exchangeRate: null == exchangeRate ? _self.exchangeRate : exchangeRate // ignore: cast_nullable_to_non_nullable
as double,fechaInicio: null == fechaInicio ? _self.fechaInicio : fechaInicio // ignore: cast_nullable_to_non_nullable
as DateTime,fechaExpiracion: freezed == fechaExpiracion ? _self.fechaExpiracion : fechaExpiracion // ignore: cast_nullable_to_non_nullable
as DateTime?,activo: null == activo ? _self.activo : activo // ignore: cast_nullable_to_non_nullable
as bool,monedaBase: freezed == monedaBase ? _self.monedaBase : monedaBase // ignore: cast_nullable_to_non_nullable
as CurrencyModel?,monedaTarget: freezed == monedaTarget ? _self.monedaTarget : monedaTarget // ignore: cast_nullable_to_non_nullable
as CurrencyModel?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of ExchangeRateModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CurrencyModelCopyWith<$Res>? get monedaBase {
    if (_self.monedaBase == null) {
    return null;
  }

  return $CurrencyModelCopyWith<$Res>(_self.monedaBase!, (value) {
    return _then(_self.copyWith(monedaBase: value));
  });
}/// Create a copy of ExchangeRateModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CurrencyModelCopyWith<$Res>? get monedaTarget {
    if (_self.monedaTarget == null) {
    return null;
  }

  return $CurrencyModelCopyWith<$Res>(_self.monedaTarget!, (value) {
    return _then(_self.copyWith(monedaTarget: value));
  });
}
}

// dart format on
