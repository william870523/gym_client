import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/domain/sexo.dart';

/// Espejo Dart de `sexo-policy.ts`. Los casos son los mismos que fija la prueba
/// del servidor, porque una regla en dos implementaciones solo sirve si las dos
/// responden igual.
void main() {
  test('solo se escribe lo que se ve en pantalla', () {
    expect(Sexo.canonicos, ['Masculino', 'Femenino', 'Otro']);
  });

  test('lee las formas heredadas sin volver a escribirlas', () {
    for (final entrada in ['M', 'm', 'masculino', 'MASCULINO', ' Masculino ']) {
      expect(Sexo.normalizar(entrada), Sexo.masculino, reason: entrada);
    }
    for (final entrada in ['F', 'f', 'Femenino', 'MUJER']) {
      expect(Sexo.normalizar(entrada), Sexo.femenino, reason: entrada);
    }
    for (final entrada in ['O', 'Otro', 'otra', 'X']) {
      expect(Sexo.normalizar(entrada), Sexo.otro, reason: entrada);
    }
  });

  test('no adivina por la primera letra', () {
    // «Mujer» empieza por M: adivinar la habría hecho hombre.
    expect(Sexo.normalizar('Mujer'), Sexo.femenino);
    expect(Sexo.normalizar('Masajista'), isNull);
  });

  test('no depende de los acentos', () {
    expect(Sexo.normalizar('Otró'), Sexo.otro);
  });

  test('lo ilegible no se convierte en «Otro»', () {
    for (final entrada in [null, '', '   ', '?', 'sin dato']) {
      expect(Sexo.normalizar(entrada), isNull, reason: '$entrada');
    }
  });

  test('la etiqueta enseña el valor crudo en vez de mentir', () {
    expect(Sexo.etiqueta('F'), 'Femenino');
    expect(Sexo.etiqueta('no binario'), 'no binario');
    expect(Sexo.etiqueta(null), 'Sin dato');
  });

  test('el defecto que esto evita: la entrenadora que salía hombre', () {
    // El listado hacía `sexo == 'F' || sexo == 'M' ? sexo : 'M'`, así que con
    // la base ya normalizada TODAS las entrenadoras habrían salido como 'M'.
    expect(Sexo.normalizar('Femenino'), Sexo.femenino);
    expect(Sexo.normalizar('Femenino'), isNot(Sexo.masculino));
  });
}
