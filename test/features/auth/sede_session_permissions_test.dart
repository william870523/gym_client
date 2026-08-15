import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/auth/domain/models/sede_session.dart';

void main() {
  test('la sesión conserva los permisos revalidados por el servidor', () {
    final session = SedeSession.fromJson({
      'user_id': 'recepcion-a',
      'gym_id': 'gym-a',
      'role': 'reception',
      'es_plataforma': false,
      'origen': 'SYNCED_USER',
      'permissions': ['clientes.leer', 'cobros.registrar'],
    });

    expect(session.userId, 'recepcion-a');
    expect(session.role, 'reception');
    expect(session.permissions, ['clientes.leer', 'cobros.registrar']);
  });

  test('una respuesta anterior sin permissions falla cerrada en la UI', () {
    final session = SedeSession.fromJson({
      'user_id': 'legacy-a',
      'gym_id': 'gym-a',
      'role': 'reception',
      'es_plataforma': false,
    });

    expect(session.permissions, isEmpty);
  });
}
