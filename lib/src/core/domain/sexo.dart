/// Vocabulario único del sexo, espejo de `sexo-policy.ts` de las dos APIs
/// (docs/PLAN_ESTADISTICAS.md §7).
///
/// La regla que pidió el dueño: **lo que se ve en pantalla es lo que se guarda**.
/// El desplegable enseña «Masculino» y en la base pone `Masculino`.
///
/// Quien decide es el servidor; esto es para que la pantalla hable su mismo
/// idioma. Sigue leyendo las formas heredadas —`M`, `F`— porque un dato viejo
/// puede llegar de una versión anterior o de la cola de sincronización, pero
/// **nunca las escribe**.
library;

class Sexo {
  const Sexo._();

  static const masculino = 'Masculino';
  static const femenino = 'Femenino';
  static const otro = 'Otro';

  /// Los únicos valores que el cliente escribe.
  static const canonicos = <String>[masculino, femenino, otro];

  static const _equivalencias = <String, String>{
    'm': masculino,
    'masculino': masculino,
    'hombre': masculino,
    'male': masculino,
    'f': femenino,
    'femenino': femenino,
    'mujer': femenino,
    'female': femenino,
    'o': otro,
    'otro': otro,
    'otra': otro,
    'other': otro,
    'x': otro,
  };

  /// Devuelve el valor canónico, o `null` si no se sabe qué es.
  ///
  /// `null` no es «Otro»: «Otro» es una respuesta que alguien dio, y un valor
  /// ilegible es un dato que no se entiende. El defecto que esto evita es
  /// concreto: el listado de entrenadores convertía en `M` **todo** lo que no
  /// fuera exactamente `M` o `F`, así que una entrenadora guardada como
  /// «Femenino» aparecía como hombre.
  static String? normalizar(Object? valor) {
    if (valor == null) return null;
    final texto = _sinAcentos(valor.toString()).trim().toLowerCase();
    if (texto.isEmpty) return null;
    return _equivalencias[texto];
  }

  /// Para pintar: si no se entiende, se enseña tal cual en vez de mentir.
  static String etiqueta(Object? valor) {
    final normalizado = normalizar(valor);
    if (normalizado != null) return normalizado;
    final crudo = valor?.toString().trim() ?? '';
    return crudo.isEmpty ? 'Sin dato' : crudo;
  }

  static String _sinAcentos(String texto) {
    const con = 'áàäâãéèëêíìïîóòöôõúùüûñ';
    const sin = 'aaaaaeeeeiiiiooooouuuun';
    final buffer = StringBuffer();
    for (final rune in texto.runes) {
      final caracter = String.fromCharCode(rune);
      final indice = con.indexOf(caracter.toLowerCase());
      buffer.write(indice >= 0 ? sin[indice] : caracter);
    }
    return buffer.toString();
  }
}
