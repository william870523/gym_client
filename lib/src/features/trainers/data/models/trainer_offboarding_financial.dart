class TrainerOffboardingFinancialPlan {
  const TrainerOffboardingFinancialPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.currencyId,
    required this.durationDays,
    required this.includesTrainer,
  });

  final String id;
  final String name;
  final double price;
  final String currencyId;
  final int durationDays;
  final bool includesTrainer;

  factory TrainerOffboardingFinancialPlan.fromJson(Map<String, dynamic> json) {
    return TrainerOffboardingFinancialPlan(
      id: json['id']?.toString() ?? '',
      name: json['nombre']?.toString() ?? '',
      price: (json['precio'] as num?)?.toDouble() ?? 0,
      currencyId: json['moneda_id']?.toString() ?? '',
      durationDays: (json['duracion_dias'] as num?)?.toInt() ?? 0,
      includesTrainer: json['incluye_entrenador'] == true,
    );
  }
}

class TrainerOffboardingFinancialValuation {
  const TrainerOffboardingFinancialValuation({
    required this.method,
    required this.totalDays,
    required this.consumedDays,
    required this.remainingDays,
    required this.paid,
    required this.consumedValue,
    required this.unusedValue,
  });

  final String method;
  final int totalDays;
  final int consumedDays;
  final int remainingDays;
  final double paid;
  final double consumedValue;
  final double unusedValue;

  factory TrainerOffboardingFinancialValuation.fromJson(
    Map<String, dynamic> json,
  ) {
    return TrainerOffboardingFinancialValuation(
      method: json['metodo']?.toString() ?? '',
      totalDays: (json['dias_totales'] as num?)?.toInt() ?? 0,
      consumedDays: (json['dias_consumidos'] as num?)?.toInt() ?? 0,
      remainingDays: (json['dias_restantes'] as num?)?.toInt() ?? 0,
      paid: (json['importe_pagado'] as num?)?.toDouble() ?? 0,
      consumedValue: (json['valor_consumido'] as num?)?.toDouble() ?? 0,
      unusedValue: (json['valor_no_consumido'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TrainerOffboardingFinancialDestination {
  const TrainerOffboardingFinancialDestination({
    required this.creditApplied,
    required this.amountDue,
    required this.remainingCredit,
    required this.refundAmount,
    required this.status,
  });

  final double creditApplied;
  final double amountDue;
  final double remainingCredit;
  final double refundAmount;
  final String status;

  factory TrainerOffboardingFinancialDestination.fromJson(
    Map<String, dynamic> json,
  ) {
    return TrainerOffboardingFinancialDestination(
      creditApplied: (json['credito_aplicado'] as num?)?.toDouble() ?? 0,
      amountDue: (json['importe_pendiente'] as num?)?.toDouble() ?? 0,
      remainingCredit: (json['saldo_credito'] as num?)?.toDouble() ?? 0,
      refundAmount: (json['importe_reembolso'] as num?)?.toDouble() ?? 0,
      status: json['estado']?.toString() ?? '',
    );
  }
}

class TrainerOffboardingFinancialPreview {
  const TrainerOffboardingFinancialPreview({
    required this.currencyId,
    required this.planName,
    required this.membershipStatus,
    required this.valuation,
    required this.plans,
    this.destination,
  });

  final String currencyId;
  final String planName;
  final String membershipStatus;
  final TrainerOffboardingFinancialValuation valuation;
  final List<TrainerOffboardingFinancialPlan> plans;
  final TrainerOffboardingFinancialDestination? destination;

  factory TrainerOffboardingFinancialPreview.fromJson(
    Map<String, dynamic> json,
  ) {
    final membership = Map<String, dynamic>.from(
      json['membresia'] as Map? ?? const {},
    );
    return TrainerOffboardingFinancialPreview(
      currencyId: membership['moneda_id']?.toString() ?? '',
      planName: membership['plan_nombre']?.toString() ?? '',
      membershipStatus: membership['estado']?.toString() ?? '',
      valuation: TrainerOffboardingFinancialValuation.fromJson(
        Map<String, dynamic>.from(json['valoracion'] as Map? ?? const {}),
      ),
      plans: (json['planes'] as List? ?? const [])
          .map(
            (item) => TrainerOffboardingFinancialPlan.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      destination: json['destino'] is Map
          ? TrainerOffboardingFinancialDestination.fromJson(
              Map<String, dynamic>.from(json['destino'] as Map),
            )
          : null,
    );
  }
}
