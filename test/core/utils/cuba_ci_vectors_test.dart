// El parser Dart se valida contra la MISMA tabla de vectores que ejecutan los
// gemelos TypeScript de gym-local-api y gym-remote-api. Es lo único que impide
// que las tres implementaciones de la regla del CI se separen con el tiempo.
//
// Tabla: shared/cuba-ci/vectors.json (en la raíz del monorepo).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/utils/cuba_ci.dart';

void main() {
  final archivo = File('../shared/cuba-ci/vectors.json');
  final tabla =
      jsonDecode(archivo.readAsStringSync()) as Map<String, dynamic>;
  final fechaReferencia = DateTime.parse(
    '${tabla['fechaReferencia'] as String}T00:00:00.000Z',
  );
  final edadMaxima = tabla['edadMaxima'] as int;
  final vectores = (tabla['vectores'] as List).cast<Map<String, dynamic>>();

  String? diaIso(DateTime? fecha) =>
      fecha?.toIso8601String().substring(0, 10);

  String? nombreSexo(CubaCiSexo? sexo) => switch (sexo) {
    CubaCiSexo.masculino => 'masculino',
    CubaCiSexo.femenino => 'femenino',
    null => null,
  };

  group('análisis del CI cubano — vectores compartidos', () {
    test('la tabla de vectores se carga y no está vacía', () {
      expect(vectores, isNotEmpty);
    });

    for (final vector in vectores) {
      final ci = vector['ci'] as String;
      test('$ci — ${vector['descripcion']}', () {
        final analisis = analizarCubaCi(
          ci,
          fechaReferencia: fechaReferencia,
          edadMaxima: edadMaxima,
        );

        expect(
          analisis.estado == CubaCiEstado.valido,
          vector['valido'] as bool,
          reason: 'estado',
        );
        if (vector['incompleto'] == true) {
          expect(analisis.estado, CubaCiEstado.incompleto);
        }
        expect(
          diaIso(analisis.fechaNacimiento),
          vector['fechaNacimiento'] as String?,
          reason: 'fechaNacimiento',
        );
        expect(analisis.siglo, vector['siglo'] as String?, reason: 'siglo');
        expect(analisis.edad, vector['edad'] as int?, reason: 'edad');
        expect(
          nombreSexo(analisis.sexoCodificado),
          vector['sexo'] as String?,
          reason: 'sexo',
        );
        expect(
          analisis.errores.map((error) => error.codigo.name).toList()..sort(),
          (vector['errores'] as List).cast<String>().toList()..sort(),
          reason: 'errores',
        );
      });
    }
  });
}
