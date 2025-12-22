class Gym {
  final String id;
  final String name;
  final String code;

  Gym({required this.id, required this.name, required this.code});

  factory Gym.fromJson(Map<String, dynamic> json) {
    return Gym(
      id: json['gym_id'] ?? '',
      name: json['nombre'] ?? '',
      code: json['codigo'] ?? '',
    );
  }
}
