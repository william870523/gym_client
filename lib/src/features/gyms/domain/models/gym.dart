class Gym {
  final String id;
  final String code;
  final String name;
  final String? address;
  final String? city;
  final String? state; // provincia
  final String? country;
  final String? timezone;
  final String? zipCode;
  final bool active;

  Gym({
    required this.id,
    required this.code,
    required this.name,
    this.address,
    this.city,
    this.state,
    this.country,
    this.timezone,
    this.zipCode,
    this.active = true,
  });

  factory Gym.fromJson(Map<String, dynamic> json) {
    return Gym(
      id: json['gym_id']?.toString() ?? '',
      code: json['codigo']?.toString() ?? '',
      name: json['nombre']?.toString() ?? '',
      address: json['direccion']?.toString(),
      city: json['ciudad']?.toString(),
      state: json['provincia']?.toString(),
      country: json['pais']?.toString(),
      timezone: json['timezone']?.toString() ?? 'Etc/UTC',
      zipCode: json['codigo_postal']?.toString(),
      active: json['activo'] == true || json['activo'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gym_id': id,
      'codigo': code,
      'nombre': name,
      'direccion': address,
      'ciudad': city,
      'provincia': state,
      'pais': country,
      'timezone': timezone,
      'codigo_postal': zipCode,
      'activo': active,
    };
  }

  Gym copyWith({
    String? id,
    String? code,
    String? name,
    String? address,
    String? city,
    String? state,
    String? country,
    String? timezone,
    String? zipCode,
    bool? active,
  }) {
    return Gym(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      timezone: timezone ?? this.timezone,
      zipCode: zipCode ?? this.zipCode,
      active: active ?? this.active,
    );
  }
}
