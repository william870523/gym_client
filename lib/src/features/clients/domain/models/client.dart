import 'package:freezed_annotation/freezed_annotation.dart';

part 'client.freezed.dart';
part 'client.g.dart';

@freezed
class Client with _$Client {
  const factory Client({
    required String ci,
    required String nombres,
    required String apellidos,
    @JsonKey(name: 'fecha_registro') required DateTime fechaRegistro,
    @JsonKey(name: 'gym_id') String? gymId,
    // Add other fields as needed
  }) = _Client;

  factory Client.fromJson(Map<String, dynamic> json) => _$ClientFromJson(json);
}
