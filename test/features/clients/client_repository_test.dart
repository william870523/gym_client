import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
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

  group('el motivo del rechazo llega intacto a quien guarda', () {
    // El texto exacto de `cliente-condiciones-contractuales.ts`, gemelo en las
    // dos APIs. Se copia entero a propósito: es lo que tiene que leer el
    // operador, y una prueba que solo mirase el código 409 no vería si el
    // mensaje se pierde por el camino.
    const motivo =
        'Desde la ficha no se cambia el entrenador asignado: tiene '
        'consecuencias sobre cobros o comisiones y se hace por «Cambiar '
        'entrenador, desde el expediente del socio».';

    test('un 409 al editar se propaga con el texto del servidor', () async {
      final adapter = _ClientAdapter(status: 409, body: {'error': motivo});
      final repository = ClientRepository(
        Dio(BaseOptions(baseUrl: 'http://gym.test'))
          ..httpClientAdapter = adapter,
      );

      await expectLater(
        repository.updateClient(ClientModel(id: '91021020015', nombres: 'Ana')),
        throwsA(
          isA<Exception>().having((e) => e.toString(), 'mensaje', contains(motivo)),
        ),
      );
      // Y no llegó a releer: el guardado no ocurrió.
      expect(adapter.requests.map((r) => r.method), ['PUT']);
    });

    test('un 409 al dar de alta también dice por qué', () async {
      final repository = ClientRepository(
        Dio(BaseOptions(baseUrl: 'http://gym.test'))
          ..httpClientAdapter = _ClientAdapter(
            status: 409,
            body: {'error': 'Ya existe un socio con ese carné.'},
          ),
      );

      await expectLater(
        repository.createClient(ClientModel(id: '91021020015', nombres: 'Ana')),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'mensaje',
            contains('Ya existe un socio con ese carné.'),
          ),
        ),
      );
    });

    test('si el servidor no explica nada, queda el aviso genérico', () async {
      final repository = ClientRepository(
        Dio(BaseOptions(baseUrl: 'http://gym.test'))
          ..httpClientAdapter = _ClientAdapter(status: 500, body: const {}),
      );

      await expectLater(
        repository.updateClient(ClientModel(id: '91021020015', nombres: 'Ana')),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'mensaje',
            contains('El servidor rechazó el guardado (500)'),
          ),
        ),
      );
    });
  });
}

class _ClientAdapter implements HttpClientAdapter {
  _ClientAdapter({required this.status, required this.body});

  final int status;
  final Map<String, Object?> body;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
