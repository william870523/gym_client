import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/clients/data/models/client_record_document.dart';

void main() {
  test('interpreta metadatos auditables de una emisión', () {
    final document = ClientRecordDocument.fromJson(const {
      'documento_id': 'doc-1',
      'ci': '99010100001',
      'formato': 'CSV',
      'destino': 'ARCHIVO',
      'nombre_archivo': 'expediente.csv',
      'mime_type': 'text/csv; charset=utf-8',
      'tamano_bytes': 121,
      'sha256': 'abc123',
      'filtros': {'alcance': 'COMPLETO'},
      'emitido_por_nombre_snapshot': 'Administración Demo',
      'emitido_por_rol_snapshot': 'admin',
      'emitido_por_origen': 'REMOTE_USER',
      'emitido_at': '2026-08-10T15:00:00.000Z',
    });

    expect(document.id, 'doc-1');
    expect(document.sizeBytes, 121);
    expect(document.filters['alcance'], 'COMPLETO');
    expect(document.issuedByName, 'Administración Demo');
    expect(document.issuedAtUtc.isUtc, isTrue);
  });
}
