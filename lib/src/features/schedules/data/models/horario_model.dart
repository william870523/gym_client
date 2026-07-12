class HorarioModel {
  final String id;
  final String nombre;
  final int horaInicio; // Minutes since midnight
  final int horaFin; // Minutes since midnight
  final String? gymId;
  final int version;

  HorarioModel({
    required this.id,
    required this.nombre,
    required this.horaInicio,
    required this.horaFin,
    this.gymId,
    this.version = 1,
  });

  factory HorarioModel.fromJson(Map<String, dynamic> json) {
    return HorarioModel(
      id: json['horario_id'] ?? '',
      nombre: json['nombre_horario'] ?? '',
      horaInicio: json['hora_inicio'] ?? 0,
      horaFin: json['hora_fin'] ?? 0,
      gymId: json['gym_id'],
      version: json['version'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'horario_id': id,
      'nombre_horario': nombre,
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
      if (gymId != null) 'gym_id': gymId,
    };
  }

  /// Converts minutes since midnight to HH:MM format
  static String formatTime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final period = hours >= 12 ? 'PM' : 'AM';
    final displayHours = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours);
    return '${displayHours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')} $period';
  }

  /// Converts TimeOfDay to minutes since midnight
  static int toMinutes(int hours, int minutes) {
    return hours * 60 + minutes;
  }

  String get horaInicioFormatted => formatTime(horaInicio);
  String get horaFinFormatted => formatTime(horaFin);

  HorarioModel copyWith({
    String? id,
    String? nombre,
    int? horaInicio,
    int? horaFin,
    String? gymId,
    int? version,
  }) {
    return HorarioModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFin: horaFin ?? this.horaFin,
      gymId: gymId ?? this.gymId,
      version: version ?? this.version,
    );
  }
}
