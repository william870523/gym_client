import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';
import 'package:gym_client/src/features/clients/data/repositories/client_repository.dart';

void main() {
  test('el payload editable no devuelve proyecciones de membresía', () {
    final payload = clientWritePayload(
      ClientModel(
        id: 'test-1',
        nombres: 'Prueba',
        membershipId: 'membership-read-only',
        membershipStatus: 'PENDIENTE_PAGO',
        peso: 75,
      ),
    );

    expect(payload['ci'], 'test-1');
    expect(payload.containsKey('membresia_id'), isFalse);
    expect(payload.containsKey('membresia_estado'), isFalse);
    expect(payload.containsKey('peso'), isFalse);
  });
}
