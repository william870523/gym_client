import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/identity/document_type.dart';

void main() {
  group('restrictDocumentText', () {
    test('CI conserva solo once dígitos', () {
      expect(
        restrictDocumentText('87A01-12.20001234', DocumentType.cubanCi),
        '87011220001',
      );
    });

    test('pasaporte conserva únicamente letras y números', () {
      expect(
        restrictDocumentText('02ab-12.,_34567', DocumentType.passport),
        '02AB12345',
      );
    });

    test('otro documento y legado no alteran el valor', () {
      expect(
        restrictDocumentText('DOC-12/34.5', DocumentType.other),
        'DOC-12/34.5',
      );
      expect(
        restrictDocumentText('LEGACY.01', DocumentType.unknown),
        'LEGACY.01',
      );
    });
  });
}
