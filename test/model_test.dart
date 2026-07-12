import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';

void main() {
  test('ClientModel parsing test', () {
    final json = {
      "ci": "34",
      "nombres": "fd",
      "apellidos": "sdf",
      "sexo": "M",
      "foto_cliente": "...", // Truncated but string
      "cliente_peso_id": "360739d8-8c30-4375-aa20-1db7ae91d8d5",
      "estatura_cliente": 3453,
      "direccion": "345",
      "telefono": 5345,
      "nacionalidad_id": "055315c9-5f87-4a68-b09f-9e8d75646571",
      "correo": null,
      "objetivo": null,
      "id_planes_pago": "b3a95e7f-af27-4ff9-9c0d-c65aa2784768",
      "id_entrenador": "1787011d-b865-4f85-8d0a-7879cd2ef493",
      "fecha_inicio": "2026-01-05T10:09:09.720Z",
      "fecha_fin": "2026-01-05T10:09:09.720Z",
      "activo": true,
      "id_horarios": null,
      "referencia_id": "4abd2966-b474-43ce-a129-f517d855be21",
      "is_deleted": false,
      "created_at": "2026-01-04T09:50:39.466Z",
      "gym_id": "local-gym-001",
      "source_device": "device-001",
      "version": 4,
      "updated_at": "2026-01-05T10:05:41.405Z",
      "deleted_at": null,
    };

    final client = ClientModel.fromJson(json);

    expect(client.id, '34');
    expect(client.nombres, 'fd');
    expect(client.apellidos, 'sdf');
    expect(client.estatura_cliente, 3453);
    expect(client.startDate, DateTime.parse('2026-01-05T10:09:09.720Z'));
    expect(client.endDate, DateTime.parse('2026-01-05T10:09:09.720Z'));
    expect(client.activo, isTrue);
  });
}
