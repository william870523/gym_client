import 'dart:convert';

class ImageUtils {
  /// Limpia una cadena Base64 de metadatos, prefijos y caracteres no válidos.
  ///
  /// Elimina:
  /// - Esquemas Data URI (data:image/x;base64,)
  /// - Espacios en blanco y saltos de línea
  /// - Caracteres de escape JSON (ej: \/)
  static String sanitizeBase64(String input) {
    if (input.isEmpty) return "";

    String sanitized = input.trim();

    // 1. Remover prefijos de Data URI si existen
    if (sanitized.contains(',')) {
      sanitized = sanitized.split(',').last;
    }

    // 2. Limpiar escapes JSON comunes (si la cadena vino de un JSON crudo mal parseado)
    sanitized = sanitized.replaceAll(r'\/', '/');

    // 3. Eliminar espacios en blanco, saltos de línea, tabs
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), '');

    return sanitized;
  }

  /// Valida si una cadena parece ser un Base64 válido.
  static bool isValidBase64(String input) {
    try {
      base64Decode(sanitizeBase64(input));
      return true;
    } catch (_) {
      return false;
    }
  }
}
