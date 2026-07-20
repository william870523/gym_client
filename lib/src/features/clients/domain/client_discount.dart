library;

/// R5.3 — Cálculo del descuento por categoría de cliente (VIEJO/NUEVO).
///
/// Réplica exacta del redondeo del backend (`client-discount-policy.ts`):
/// ceil al entero superior en unidades principales (múltiplos de 100 centavos),
/// para que cliente y servidor coincidan sin centavos fraccionarios.
///
/// **Orden de capas al cobrar:**
///   1. precio de lista del plan;
///   2. este descuento R5.3 → precio con descuento;
///   3. recargo R5.1 por método de pago → precio final.

enum ClientCategory { nuevo, viejo }

const String _defaultDiscountPct = '16.67';

extension ClientCategoryX on String? {
  ClientCategory get toClientCategory {
    final v = (this ?? '').trim().toUpperCase();
    return v == 'VIEJO' ? ClientCategory.viejo : ClientCategory.nuevo;
  }
}

class ClientDiscountBreakdown {
  final double precioLista;
  final String? descuentoPct;
  final double descuento;
  final double precioFinal;
  final String motivo; // SIN_DESCUENTO | PORCENTAJE_GLOBAL | EXCEPCION_FIJA

  const ClientDiscountBreakdown({
    required this.precioLista,
    required this.descuentoPct,
    required this.descuento,
    required this.precioFinal,
    required this.motivo,
  });

  bool get hasDiscount => descuento > 0.005;
}

String _minorToMoney(int minor) {
  final negative = minor < 0;
  final absolute = negative ? -minor : minor;
  final whole = absolute ~/ 100;
  final decimal = (absolute % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}$whole.$decimal';
}

/// Devuelve el descuento en centavos, aplicando ceil a múltiplos de 100.
int _discountMinor({
  required int listMinor,
  required ClientCategory category,
  required double pct,
  required int? planFixedOldMinor,
}) {
  if (listMinor < 0) return 0;
  if (category != ClientCategory.viejo) return 0;
  if (planFixedOldMinor != null && planFixedOldMinor >= 0) {
    if (planFixedOldMinor > listMinor) return 0;
    return listMinor - planFixedOldMinor;
  }
  if (pct <= 0 || pct > 100) return 0;
  // rawCents = listMinor * pct / 100, half-up.
  final rawCents = (listMinor * pct + 50) / 100;
  final rawCentsInt = rawCents.floor();
  if (rawCentsInt <= 0) return 0;
  // Ceil a múltiplo de 100.
  final integerUnits = (rawCentsInt + 99) ~/ 100;
  return integerUnits * 100;
}

/// Desglose completo del descuento. `discountPct` es el % global (p. ej. "16.67")
/// tal cual llega de la configuración; si es null usa el default 16.67 %.
ClientDiscountBreakdown clientDiscountBreakdown({
  required double listPrice,
  required ClientCategory category,
  required String? discountPct,
  required double? planFixedOldPrice,
}) {
  final listMinor = (listPrice * 100).round();
  final pct = double.tryParse(discountPct ?? _defaultDiscountPct) ??
      double.parse(_defaultDiscountPct);
  final fixedOldMinor = planFixedOldPrice == null
      ? null
      : (planFixedOldPrice * 100).round();
  final discount = _discountMinor(
    listMinor: listMinor,
    category: category,
    pct: pct,
    planFixedOldMinor: fixedOldMinor,
  );
  String motivo;
  String? pctOut;
  if (category != ClientCategory.viejo) {
    motivo = 'SIN_DESCUENTO';
    pctOut = null;
  } else if (fixedOldMinor != null) {
    motivo = 'EXCEPCION_FIJA';
    pctOut = null;
  } else {
    motivo = 'PORCENTAJE_GLOBAL';
    pctOut = discountPct ?? _defaultDiscountPct;
  }
  return ClientDiscountBreakdown(
    precioLista: double.parse(_minorToMoney(listMinor)),
    descuentoPct: pctOut,
    descuento: double.parse(_minorToMoney(discount)),
    precioFinal: double.parse(_minorToMoney(listMinor - discount)),
    motivo: motivo,
  );
}
