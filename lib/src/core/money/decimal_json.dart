/// Frontera de compatibilidad para valores Decimal enviados por Prisma.
///
/// MariaDB/Prisma serializa Decimal como texto para no degradarlo a un double;
/// versiones anteriores de las APIs SQLite lo enviaban como número JSON. La
/// UI acepta ambos y convierte solo para presentación e interacción local.
double decimalJsonToDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    if (parsed != null && parsed.isFinite) return parsed;
  }
  throw FormatException('Valor decimal JSON inválido: $value');
}

double? nullableDecimalJsonToDouble(Object? value) =>
    value == null ? null : decimalJsonToDouble(value);
