import '../models/sede_session.dart';
import '../models/user.dart';

abstract class AuthRepository {
  Future<User> login(String email, String password);
  Future<void> logout();
  Future<User?> getCurrentUser();

  /// Sede activa y nivel, resueltos por el servidor (`GET /auth/session`).
  /// Devuelve `null` si la instalación aún no expone la ruta.
  Future<SedeSession?> fetchSession();
}
