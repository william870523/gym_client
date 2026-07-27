/// Cotización del recargo por mora devuelta por el servidor.
///
/// Diseño: docs/RECARGO_MORA.md. El cliente NUNCA calcula el importe; solo
/// presenta estos valores y envía `aplicar_recargo_mora` al cobrar.
class RecargoMoraQuote {
  /// true cuando el recargo se cobra de verdad en este cobro.
  final bool aplicado;

  /// PORCENTAJE | MONTO_FIJO | POR_DIA, o null si el plan no tiene recargo.
  final String? modo;
  final int diasAtraso;

  /// Importes como string decimal, tal cual los envía el servidor.
  final String base;
  final String recargo;
  final String total;

  /// OK | SIN_CONFIG | INACTIVO | SIN_ATRASO | NO_APLICADO.
  final String motivo;
  final bool planTieneRecargo;
  final bool planRecargoActivo;
  final String monedaId;
  final DateTime? vencimiento;

  const RecargoMoraQuote({
    required this.aplicado,
    required this.modo,
    required this.diasAtraso,
    required this.base,
    required this.recargo,
    required this.total,
    required this.motivo,
    required this.planTieneRecargo,
    required this.planRecargoActivo,
    required this.monedaId,
    this.vencimiento,
  });

  factory RecargoMoraQuote.fromJson(Map<String, dynamic> json) {
    return RecargoMoraQuote(
      aplicado: json['aplicado'] == true,
      modo: json['modo'] as String?,
      diasAtraso: (json['dias_atraso'] as num?)?.toInt() ?? 0,
      base: json['base']?.toString() ?? '0.00',
      recargo: json['recargo']?.toString() ?? '0.00',
      total: json['total']?.toString() ?? '0.00',
      motivo: json['motivo'] as String? ?? 'SIN_CONFIG',
      planTieneRecargo: json['plan_tiene_recargo'] == true,
      planRecargoActivo: json['plan_recargo_activo'] == true,
      monedaId: json['moneda_id'] as String? ?? '',
      vencimiento: json['vencimiento'] != null
          ? DateTime.tryParse(json['vencimiento'] as String)
          : null,
    );
  }

  /// El importe del recargo como número, para ajustar el monto a cobrar.
  double get recargoValor => double.tryParse(recargo) ?? 0.0;

  /// Texto corto que explica el estado, para mostrar bajo la casilla.
  String get explicacion {
    switch (motivo) {
      case 'OK':
        final unidad = diasAtraso == 1 ? 'día' : 'días';
        return '$diasAtraso $unidad de atraso · recargo $recargo';
      case 'SIN_ATRASO':
        return 'El pago está al día: no corresponde recargo.';
      case 'INACTIVO':
        return 'El plan tiene recargo configurado pero no está activo.';
      case 'NO_APLICADO':
        return 'Marque la casilla para aplicar el recargo.';
      case 'SIN_CONFIG':
      default:
        return 'Este plan no cobra recargo por mora.';
    }
  }
}
