// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$User {

@JsonKey(name: 'user_id') String get id;@JsonKey(name: 'user_nombre') String get name;@JsonKey(name: 'user_email') String get email; String get role;// 'admin', 'reception', 'accounting', 'trainer'
@JsonKey(name: 'rol_sede') String? get siteRole; bool get active; String get status;// Kept for backward compat if needed, but 'active' bool is primary
 String? get imageUrl;@JsonKey(includeToJson: false) String? get token;@JsonKey(includeFromJson: false, includeToJson: true) String? get password;// Only for creation/update, not returned by API
@JsonKey(name: 'gym_id') String? get gymId; List<String> get permissions;
/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserCopyWith<User> get copyWith => _$UserCopyWithImpl<User>(this as User, _$identity);

  /// Serializes this User to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is User&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.role, role) || other.role == role)&&(identical(other.siteRole, siteRole) || other.siteRole == siteRole)&&(identical(other.active, active) || other.active == active)&&(identical(other.status, status) || other.status == status)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.token, token) || other.token == token)&&(identical(other.password, password) || other.password == password)&&(identical(other.gymId, gymId) || other.gymId == gymId)&&const DeepCollectionEquality().equals(other.permissions, permissions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,email,role,siteRole,active,status,imageUrl,token,password,gymId,const DeepCollectionEquality().hash(permissions));



}

/// @nodoc
abstract mixin class $UserCopyWith<$Res>  {
  factory $UserCopyWith(User value, $Res Function(User) _then) = _$UserCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'user_id') String id,@JsonKey(name: 'user_nombre') String name,@JsonKey(name: 'user_email') String email, String role,@JsonKey(name: 'rol_sede') String? siteRole, bool active, String status, String? imageUrl,@JsonKey(includeToJson: false) String? token,@JsonKey(includeFromJson: false, includeToJson: true) String? password,@JsonKey(name: 'gym_id') String? gymId, List<String> permissions
});




}
/// @nodoc
class _$UserCopyWithImpl<$Res>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._self, this._then);

  final User _self;
  final $Res Function(User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? email = null,Object? role = null,Object? siteRole = freezed,Object? active = null,Object? status = null,Object? imageUrl = freezed,Object? token = freezed,Object? password = freezed,Object? gymId = freezed,Object? permissions = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,siteRole: freezed == siteRole ? _self.siteRole : siteRole // ignore: cast_nullable_to_non_nullable
as String?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,token: freezed == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String?,password: freezed == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String?,gymId: freezed == gymId ? _self.gymId : gymId // ignore: cast_nullable_to_non_nullable
as String?,permissions: null == permissions ? _self.permissions : permissions // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [User].
extension UserPatterns on User {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _User value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _User() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _User value)  $default,){
final _that = this;
switch (_that) {
case _User():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _User value)?  $default,){
final _that = this;
switch (_that) {
case _User() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'user_id')  String id, @JsonKey(name: 'user_nombre')  String name, @JsonKey(name: 'user_email')  String email,  String role, @JsonKey(name: 'rol_sede')  String? siteRole,  bool active,  String status,  String? imageUrl, @JsonKey(includeToJson: false)  String? token, @JsonKey(includeFromJson: false, includeToJson: true)  String? password, @JsonKey(name: 'gym_id')  String? gymId,  List<String> permissions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.id,_that.name,_that.email,_that.role,_that.siteRole,_that.active,_that.status,_that.imageUrl,_that.token,_that.password,_that.gymId,_that.permissions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'user_id')  String id, @JsonKey(name: 'user_nombre')  String name, @JsonKey(name: 'user_email')  String email,  String role, @JsonKey(name: 'rol_sede')  String? siteRole,  bool active,  String status,  String? imageUrl, @JsonKey(includeToJson: false)  String? token, @JsonKey(includeFromJson: false, includeToJson: true)  String? password, @JsonKey(name: 'gym_id')  String? gymId,  List<String> permissions)  $default,) {final _that = this;
switch (_that) {
case _User():
return $default(_that.id,_that.name,_that.email,_that.role,_that.siteRole,_that.active,_that.status,_that.imageUrl,_that.token,_that.password,_that.gymId,_that.permissions);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'user_id')  String id, @JsonKey(name: 'user_nombre')  String name, @JsonKey(name: 'user_email')  String email,  String role, @JsonKey(name: 'rol_sede')  String? siteRole,  bool active,  String status,  String? imageUrl, @JsonKey(includeToJson: false)  String? token, @JsonKey(includeFromJson: false, includeToJson: true)  String? password, @JsonKey(name: 'gym_id')  String? gymId,  List<String> permissions)?  $default,) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.id,_that.name,_that.email,_that.role,_that.siteRole,_that.active,_that.status,_that.imageUrl,_that.token,_that.password,_that.gymId,_that.permissions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _User implements User {
  const _User({@JsonKey(name: 'user_id') required this.id, @JsonKey(name: 'user_nombre') required this.name, @JsonKey(name: 'user_email') required this.email, required this.role, @JsonKey(name: 'rol_sede') this.siteRole, this.active = true, this.status = 'active', this.imageUrl, @JsonKey(includeToJson: false) this.token, @JsonKey(includeFromJson: false, includeToJson: true) this.password, @JsonKey(name: 'gym_id') this.gymId, final  List<String> permissions = const []}): _permissions = permissions;
  factory _User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

@override@JsonKey(name: 'user_id') final  String id;
@override@JsonKey(name: 'user_nombre') final  String name;
@override@JsonKey(name: 'user_email') final  String email;
@override final  String role;
// 'admin', 'reception', 'accounting', 'trainer'
@override@JsonKey(name: 'rol_sede') final  String? siteRole;
@override@JsonKey() final  bool active;
@override@JsonKey() final  String status;
// Kept for backward compat if needed, but 'active' bool is primary
@override final  String? imageUrl;
@override@JsonKey(includeToJson: false) final  String? token;
@override@JsonKey(includeFromJson: false, includeToJson: true) final  String? password;
// Only for creation/update, not returned by API
@override@JsonKey(name: 'gym_id') final  String? gymId;
 final  List<String> _permissions;
@override@JsonKey() List<String> get permissions {
  if (_permissions is EqualUnmodifiableListView) return _permissions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_permissions);
}


/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserCopyWith<_User> get copyWith => __$UserCopyWithImpl<_User>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _User&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.role, role) || other.role == role)&&(identical(other.siteRole, siteRole) || other.siteRole == siteRole)&&(identical(other.active, active) || other.active == active)&&(identical(other.status, status) || other.status == status)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.token, token) || other.token == token)&&(identical(other.password, password) || other.password == password)&&(identical(other.gymId, gymId) || other.gymId == gymId)&&const DeepCollectionEquality().equals(other._permissions, _permissions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,email,role,siteRole,active,status,imageUrl,token,password,gymId,const DeepCollectionEquality().hash(_permissions));



}

/// @nodoc
abstract mixin class _$UserCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$UserCopyWith(_User value, $Res Function(_User) _then) = __$UserCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'user_id') String id,@JsonKey(name: 'user_nombre') String name,@JsonKey(name: 'user_email') String email, String role,@JsonKey(name: 'rol_sede') String? siteRole, bool active, String status, String? imageUrl,@JsonKey(includeToJson: false) String? token,@JsonKey(includeFromJson: false, includeToJson: true) String? password,@JsonKey(name: 'gym_id') String? gymId, List<String> permissions
});




}
/// @nodoc
class __$UserCopyWithImpl<$Res>
    implements _$UserCopyWith<$Res> {
  __$UserCopyWithImpl(this._self, this._then);

  final _User _self;
  final $Res Function(_User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? email = null,Object? role = null,Object? siteRole = freezed,Object? active = null,Object? status = null,Object? imageUrl = freezed,Object? token = freezed,Object? password = freezed,Object? gymId = freezed,Object? permissions = null,}) {
  return _then(_User(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,siteRole: freezed == siteRole ? _self.siteRole : siteRole // ignore: cast_nullable_to_non_nullable
as String?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,token: freezed == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String?,password: freezed == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String?,gymId: freezed == gymId ? _self.gymId : gymId // ignore: cast_nullable_to_non_nullable
as String?,permissions: null == permissions ? _self._permissions : permissions // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
