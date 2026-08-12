class VoluntaryCancellationPreview {
  const VoluntaryCancellationPreview({
    required this.effectiveDate,
    required this.clientName,
    required this.planName,
    required this.membershipState,
    required this.currency,
    required this.currencySymbol,
    required this.totalDays,
    required this.consumedDays,
    required this.remainingDays,
    required this.paidAmount,
    required this.consumedValue,
    required this.unusedValue,
    required this.alternatives,
    required this.isPreviewOnly,
  });

  final String effectiveDate;
  final String clientName;
  final String planName;
  final String membershipState;
  final String currency;
  final String currencySymbol;
  final int totalDays;
  final int consumedDays;
  final int remainingDays;
  final double paidAmount;
  final double consumedValue;
  final double unusedValue;
  final List<VoluntaryCancellationAlternative> alternatives;
  final bool isPreviewOnly;

  factory VoluntaryCancellationPreview.fromJson(Map<String, dynamic> json) {
    final client = Map<String, dynamic>.from(json['socio'] as Map? ?? const {});
    final membership = Map<String, dynamic>.from(
      json['membresia'] as Map? ?? const {},
    );
    final valuation = Map<String, dynamic>.from(
      json['valoracion'] as Map? ?? const {},
    );
    final rules = Map<String, dynamic>.from(json['reglas'] as Map? ?? const {});
    final alternatives = json['alternativas'] is List
        ? json['alternativas'] as List
        : const [];
    return VoluntaryCancellationPreview(
      effectiveDate: json['fecha_efectiva']?.toString() ?? '',
      clientName: client['nombre']?.toString() ?? '',
      planName: membership['plan_nombre']?.toString() ?? '',
      membershipState: membership['estado']?.toString() ?? '',
      currency:
          membership['moneda_codigo']?.toString() ??
          membership['moneda_id']?.toString() ??
          '',
      currencySymbol: membership['moneda_simbolo']?.toString() ?? '',
      totalDays: _int(valuation['dias_totales']),
      consumedDays: _int(valuation['dias_consumidos']),
      remainingDays: _int(valuation['dias_restantes']),
      paidAmount: _double(valuation['importe_pagado']),
      consumedValue: _double(valuation['valor_consumido']),
      unusedValue: _double(valuation['valor_no_consumido']),
      alternatives: alternatives
          .whereType<Map>()
          .map(
            (item) => VoluntaryCancellationAlternative.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
      isPreviewOnly: rules['solo_previsualizacion'] == true,
    );
  }
}

class VoluntaryCancellationAlternative {
  const VoluntaryCancellationAlternative({
    required this.type,
    required this.amount,
    required this.description,
    required this.requiresTreasury,
  });

  final String type;
  final double amount;
  final String description;
  final bool requiresTreasury;

  factory VoluntaryCancellationAlternative.fromJson(
    Map<String, dynamic> json,
  ) => VoluntaryCancellationAlternative(
    type: json['tipo']?.toString() ?? '',
    amount: _double(json['importe']),
    description: json['descripcion']?.toString() ?? '',
    requiresTreasury: json['requiere_tesoreria'] == true,
  );
}

int _int(Object? value) => int.tryParse(value?.toString() ?? '') ?? 0;
double _double(Object? value) => double.tryParse(value?.toString() ?? '') ?? 0;
