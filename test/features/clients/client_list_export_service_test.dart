import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';
import 'package:gym_client/src/features/clients/data/services/client_list_export_service.dart';

void main() {
  final service = ClientListExportService();

  ClientListExportRow row(ClientModel client) => buildClientExportRow(
    client,
    plan: 'Mensual',
    estado: 'Vigente',
    vigencia: '20/08/2026',
  );

  test('el CSV lleva cabecera, alcance y una fila por socio', () {
    final bytes = service.buildCsv(
      rows: [
        row(
          ClientModel(
            id: '99081000003',
            nombres: 'Ana',
            apellidos: 'Pérez',
            telefono: 5551000,
            correo: 'ana@gym.test',
            categoria: 'VIEJO',
            membershipBalanceDue: 20,
          ),
        ),
      ],
      alcance: 'Asociados del plan Mensual',
      fechaCorte: '2026-07-25',
      zonaHoraria: 'America/Havana',
    );

    // BOM: sin él Excel abre los acentos rotos.
    expect(bytes.take(3), [0xef, 0xbb, 0xbf]);
    final text = utf8.decode(bytes.skip(3).toList());
    final lines = text.split('\r\n');

    expect(lines, hasLength(2));
    expect(lines.first, startsWith('"fecha_corte","zona_horaria","alcance"'));
    expect(lines[1], contains('"Asociados del plan Mensual"'));
    expect(lines[1], contains('"99081000003"'));
    expect(lines[1], contains('"Ana Pérez"'));
    expect(lines[1], contains('"20/08/2026"'));
    expect(lines[1], contains('"VIEJO"'));
    expect(lines[1], endsWith('"20.00"'));
  });

  test('las comillas del nombre no rompen la fila', () {
    final bytes = service.buildCsv(
      rows: [
        row(ClientModel(id: '1', nombres: 'Ana "La Jefa"', apellidos: 'Pérez')),
      ],
      alcance: 'Todos los socios visibles',
      fechaCorte: '2026-07-25',
      zonaHoraria: 'Etc/UTC',
    );

    final text = utf8.decode(bytes.skip(3).toList());
    expect(text, contains('"Ana ""La Jefa"" Pérez"'));
    expect(text.split('\r\n'), hasLength(2));
  });

  test('un socio sin nombre se exporta por su documento', () {
    final bytes = service.buildCsv(
      rows: [row(ClientModel(id: '77777777'))],
      alcance: 'Todos los socios visibles',
      fechaCorte: '2026-07-25',
      zonaHoraria: 'Etc/UTC',
    );

    final text = utf8.decode(bytes.skip(3).toList());
    expect(text, contains('"77777777","77777777"'));
    // Sin saldo conocido se exporta vacío, no un cero inventado.
    expect(text.trim(), endsWith('""'));
  });
}
