class MethodSurchargeQuote {
  final String policy;
  final String base;
  final String? percentage;
  final String surcharge;
  final String total;
  final String planEquivalent;
  final String totalPlanEquivalent;
  final int? exchangeRateVersion;

  const MethodSurchargeQuote({
    required this.policy,
    required this.base,
    required this.percentage,
    required this.surcharge,
    required this.total,
    required this.planEquivalent,
    required this.totalPlanEquivalent,
    required this.exchangeRateVersion,
  });

  factory MethodSurchargeQuote.fromJson(
    Map<String, dynamic> json,
  ) => MethodSurchargeQuote(
    policy: '${json['politica'] ?? ''}',
    base: '${json['base'] ?? '0.00'}',
    percentage: json['porcentaje']?.toString(),
    surcharge: '${json['recargo'] ?? '0.00'}',
    total: '${json['total'] ?? '0.00'}',
    planEquivalent: '${json['equivalente_plan'] ?? '0.00'}',
    totalPlanEquivalent:
        '${json['equivalente_total_plan'] ?? json['equivalente_plan'] ?? '0.00'}',
    exchangeRateVersion: (json['tipo_cambio_version'] as num?)?.toInt(),
  );

  double get baseValue => double.tryParse(base) ?? 0;
  double get percentageValue => double.tryParse(percentage ?? '') ?? 0;
  double get surchargeValue => double.tryParse(surcharge) ?? 0;
  double get totalValue => double.tryParse(total) ?? 0;
  double get planEquivalentValue => double.tryParse(planEquivalent) ?? 0;
  double get totalPlanEquivalentValue =>
      double.tryParse(totalPlanEquivalent) ?? 0;
}
