import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/utils/cuba_ci.dart';

void main() {
  final referenceDate = DateTime.utc(2026, 7, 25);

  group('analizarCubaCi', () {
    test('reconstruye los tres siglos y acepta un año bisiesto real', () {
      final nineteenth = analizarCubaCi(
        '85020290001',
        fechaReferencia: referenceDate,
        edadMaxima: 200,
      );
      final twentieth = analizarCubaCi(
        '91021020015',
        fechaReferencia: referenceDate,
      );
      final twentyFirst = analizarCubaCi(
        '00022960001',
        fechaReferencia: referenceDate,
      );

      expect(nineteenth.esValido, isTrue);
      expect(nineteenth.fechaNacimiento, DateTime.utc(1885, 2, 2));
      expect(nineteenth.siglo, 'XIX');
      expect(twentieth.fechaNacimiento, DateTime.utc(1991, 2, 10));
      expect(twentieth.siglo, 'XX');
      expect(twentyFirst.fechaNacimiento, DateTime.utc(2000, 2, 29));
      expect(twentyFirst.siglo, 'XXI');
    });

    test('deriva el sexo codificado desde el décimo dígito', () {
      expect(
        analizarCubaCi(
          '00022960001',
          fechaReferencia: referenceDate,
        ).sexoCodificado,
        CubaCiSexo.masculino,
      );
      expect(
        analizarCubaCi(
          '91021020015',
          fechaReferencia: referenceDate,
        ).sexoCodificado,
        CubaCiSexo.femenino,
      );
      expect(sexoDesdeDigito10('0'), CubaCiSexo.masculino);
      expect(sexoDesdeDigito10('9'), CubaCiSexo.femenino);
      expect(sexoDesdeDigito10('A'), isNull);
    });

    test('distingue entrada parcial de una estructura inválida', () {
      final partial = analizarCubaCi('9102', fechaReferencia: referenceDate);
      final invalidMonth = analizarCubaCi(
        '91131020001',
        fechaReferencia: referenceDate,
      );

      expect(partial.estado, CubaCiEstado.incompleto);
      expect(partial.errores, isEmpty);
      expect(invalidMonth.estado, CubaCiEstado.invalido);
      expect(invalidMonth.errores.single.codigo, CubaCiErrorCodigo.mesInvalido);
    });

    test('avisa en cuanto mes o día parcial ya no pueden ser válidos', () {
      final month = analizarCubaCi('912', fechaReferencia: referenceDate);
      final day = analizarCubaCi('91024', fechaReferencia: referenceDate);

      expect(month.estado, CubaCiEstado.invalido);
      expect(month.errores.single.codigo, CubaCiErrorCodigo.mesInvalido);
      expect(day.estado, CubaCiEstado.invalido);
      expect(day.errores.single.codigo, CubaCiErrorCodigo.diaInvalido);
    });

    test('admite 100 años y rechaza 101 con la edad calculada', () {
      final exactlyHundred = analizarCubaCi(
        '26072520001',
        fechaReferencia: referenceDate,
      );
      final oneHundredOne = analizarCubaCi(
        '25072520001',
        fechaReferencia: referenceDate,
      );

      expect(exactlyHundred.esValido, isTrue);
      expect(exactlyHundred.edad, 100);
      expect(oneHundredOne.edad, 101);
      expect(
        oneHundredOne.errores.single.codigo,
        CubaCiErrorCodigo.edadFueraRango,
      );
      expect(oneHundredOne.errores.single.mensaje, contains('101 años'));
    });

    test('rechaza fechas inexistentes y futuras con errores diferentes', () {
      final nonLeap = analizarCubaCi(
        '91022920001',
        fechaReferencia: referenceDate,
      );
      final future = analizarCubaCi(
        '30010160001',
        fechaReferencia: referenceDate,
      );

      expect(
        nonLeap.errores.map((error) => error.codigo),
        contains(CubaCiErrorCodigo.fechaInvalida),
      );
      expect(
        future.errores.map((error) => error.codigo),
        contains(CubaCiErrorCodigo.fechaFutura),
      );
    });

    test('no interpreta un documento alfanumérico como CI cubano', () {
      final analysis = analizarCubaCi(
        'PAS-12345',
        fechaReferencia: referenceDate,
      );

      expect(analysis.estado, CubaCiEstado.invalido);
      expect(
        analysis.errores.single.codigo,
        CubaCiErrorCodigo.caracteresNoNumericos,
      );
    });

    test('no intenta calcular el dígito verificador número 11', () {
      final endingOne = analizarCubaCi(
        '00022960001',
        fechaReferencia: referenceDate,
      );
      final endingNine = analizarCubaCi(
        '00022960009',
        fechaReferencia: referenceDate,
      );

      expect(endingOne.esValido, isTrue);
      expect(endingNine.esValido, isTrue);
    });
  });
}
