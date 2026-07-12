// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_User _$UserFromJson(Map<String, dynamic> json) => _User(
  id: json['user_id'] as String,
  name: json['user_nombre'] as String,
  email: json['user_email'] as String,
  role: json['role'] as String,
  active: json['active'] as bool? ?? true,
  status: json['status'] as String? ?? 'active',
  imageUrl: json['imageUrl'] as String?,
  token: json['token'] as String?,
  gymId: json['gym_id'] as String?,
  permissions:
      (json['permissions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$UserToJson(_User instance) => <String, dynamic>{
  'user_id': instance.id,
  'user_nombre': instance.name,
  'user_email': instance.email,
  'role': instance.role,
  'active': instance.active,
  'status': instance.status,
  'imageUrl': instance.imageUrl,
  'password': instance.password,
  'gym_id': instance.gymId,
  'permissions': instance.permissions,
};
