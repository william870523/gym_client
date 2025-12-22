import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
abstract class User with _$User {
  const factory User({
    @JsonKey(name: 'user_id') required String id,
    @JsonKey(name: 'user_nombre') required String name,
    @JsonKey(name: 'user_email') required String email,
    required String role, // 'admin', 'reception', 'trainer', 'maintenance'
    @Default(true) bool active,
    @Default('active')
    String
    status, // Kept for backward compat if needed, but 'active' bool is primary
    String? imageUrl,
    String? token,
    @JsonKey(includeFromJson: false, includeToJson: true)
    String? password, // Only for creation/update, not returned by API

    @JsonKey(name: 'gym_id') String? gymId,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
