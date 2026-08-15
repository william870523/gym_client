import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/auth/domain/models/user.dart';
import 'package:gym_client/src/features/users/data/user_repository.dart';

void main() {
  test('la edición omite password nulo y proyecciones de lectura', () {
    final payload = userMutationPayload(
      const User(
        id: 'm2-user-camila',
        name: 'Camila Operadora',
        email: 'camila@example.test',
        role: 'reception',
        siteRole: 'accounting',
        gymId: 'local-gym-001',
        permissions: ['estadisticas.leer'],
      ),
    );

    expect(payload, {
      'user_nombre': 'Camila Operadora',
      'user_email': 'camila@example.test',
      'role': 'reception',
      'active': true,
    });
    expect(payload.containsKey('password'), isFalse);
    expect(payload.containsKey('rol_sede'), isFalse);
    expect(payload.containsKey('gym_id'), isFalse);
  });

  test('incluye password cuando el operador realmente lo cambia', () {
    final payload = userMutationPayload(
      const User(
        id: 'm2-user-camila',
        name: 'Camila Operadora',
        email: 'camila@example.test',
        role: 'reception',
        password: 'Nueva!2026',
      ),
    );

    expect(payload['password'], 'Nueva!2026');
  });
}
