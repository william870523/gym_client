/// Sesión resuelta por el servidor: en qué sede se está trabajando y si esta
/// cuenta es **Dueño de la cadena** (docs/MULTI_SEDE.md §3).
///
/// No sale del token ni de la respuesta del login: los dos se congelan al
/// entrar, y el nivel de Dueño llega y se revoca por sincronización. El cliente
/// lo pregunta a `GET /auth/session`, que lo resuelve contra la base con las
/// mismas reglas que aplican los endpoints.
///
/// Sirve para dos cosas y solo dos: mandar la cabecera `X-Gym-Id` con la sede
/// activa, y decidir qué mandos de sede se enseñan. **No es un permiso**: quien
/// manda es el servidor, que vuelve a comprobarlo en cada petición.
class SedeSession {
  const SedeSession({
    required this.userId,
    required this.gymId,
    required this.role,
    required this.esPlataforma,
    this.origen,
  });

  final String userId;
  final String? gymId;
  final String? role;
  final bool esPlataforma;
  final String? origen;

  factory SedeSession.fromJson(Map<String, dynamic> json) {
    String? text(Object? value) {
      final result = value?.toString().trim();
      return result == null || result.isEmpty ? null : result;
    }

    return SedeSession(
      userId: text(json['user_id']) ?? '',
      gymId: text(json['gym_id']),
      role: text(json['role']),
      esPlataforma: json['es_plataforma'] == true,
      origen: text(json['origen']),
    );
  }
}
