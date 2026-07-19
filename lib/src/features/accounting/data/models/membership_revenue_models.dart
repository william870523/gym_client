class MembershipRevenueModel {
  const MembershipRevenueModel({
    required this.month,
    required this.nature,
    required this.periodState,
    required this.cutoffDate,
    required this.coverage,
    required this.currencies,
    required this.note,
    required this.limitations,
  });

  factory MembershipRevenueModel.fromJson(Map<String, dynamic> json) {
    return MembershipRevenueModel(
      month: _text(json['mes']),
      nature: _text(json['naturaleza']),
      periodState: _text(json['estado_periodo']),
      cutoffDate: _nullableText(json['fecha_corte']),
      coverage: MembershipRevenueCoverageModel.fromJson(
        _map(json['cobertura']),
      ),
      currencies: _maps(
        json['monedas'],
      ).map(MembershipRevenueCurrencyModel.fromJson).toList(growable: false),
      note: _text(json['nota']),
      limitations: (json['limitaciones'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }

  final String month;
  final String nature;
  final String periodState;
  final String? cutoffDate;
  final MembershipRevenueCoverageModel coverage;
  final List<MembershipRevenueCurrencyModel> currencies;
  final String note;
  final List<String> limitations;
}

class MembershipRevenueCoverageModel {
  const MembershipRevenueCoverageModel({
    required this.evaluatedMemberships,
    required this.withoutFinancialEvidence,
    required this.requiresReview,
    required this.complete,
  });

  factory MembershipRevenueCoverageModel.fromJson(Map<String, dynamic> json) {
    return MembershipRevenueCoverageModel(
      evaluatedMemberships: _integer(json['membresias_evaluadas']),
      withoutFinancialEvidence: _integer(json['sin_evidencia_financiera']),
      requiresReview: _integer(json['requieren_revision']),
      complete: json['completa'] == true,
    );
  }

  final int evaluatedMemberships;
  final int withoutFinancialEvidence;
  final int requiresReview;
  final bool complete;
}

class MembershipRevenueCurrencyModel {
  const MembershipRevenueCurrencyModel({
    required this.currencyId,
    required this.currencyCode,
    required this.funding,
    required this.earnedInMonth,
    required this.earnedToDate,
    required this.deferredService,
    required this.reclassifiedUnused,
    required this.cancellationAdjustment,
    required this.memberships,
  });

  factory MembershipRevenueCurrencyModel.fromJson(Map<String, dynamic> json) {
    return MembershipRevenueCurrencyModel(
      currencyId: _text(json['moneda_id']),
      currencyCode: _text(json['moneda_codigo'], fallback: '—'),
      funding: MembershipRevenueFundingModel.fromJson(
        _map(json['financiacion_mes']),
      ),
      earnedInMonth: _money(json['ingreso_devengado_mes']),
      earnedToDate: _money(json['ingreso_devengado_acumulado']),
      deferredService: _money(json['saldo_servicio_pendiente']),
      reclassifiedUnused: _money(json['valor_no_consumido_reclasificado']),
      cancellationAdjustment: _money(json['ajuste_cancelacion_mes']),
      memberships: _maps(
        json['membresias'],
      ).map(MembershipRevenueMembershipModel.fromJson).toList(growable: false),
    );
  }

  final String currencyId;
  final String currencyCode;
  final MembershipRevenueFundingModel funding;
  final String earnedInMonth;
  final String earnedToDate;
  final String deferredService;
  final String reclassifiedUnused;
  final String cancellationAdjustment;
  final List<MembershipRevenueMembershipModel> memberships;
}

class MembershipRevenueFundingModel {
  const MembershipRevenueFundingModel({
    required this.cashApplied,
    required this.creditApplied,
    required this.totalApplied,
  });

  factory MembershipRevenueFundingModel.fromJson(Map<String, dynamic> json) {
    return MembershipRevenueFundingModel(
      cashApplied: _money(json['efectivo_aplicado']),
      creditApplied: _money(json['credito_aplicado']),
      totalApplied: _money(json['total_aplicado']),
    );
  }

  final String cashApplied;
  final String creditApplied;
  final String totalApplied;
}

class MembershipRevenueMembershipModel {
  const MembershipRevenueMembershipModel({
    required this.membershipId,
    required this.clientId,
    required this.clientName,
    required this.planId,
    required this.planName,
    required this.state,
    required this.origin,
    required this.price,
    required this.funded,
    required this.earnedInMonth,
    required this.earnedToDate,
    required this.deferredService,
    required this.reclassifiedUnused,
    required this.cancellationAdjustment,
    required this.serviceDaysInMonth,
    required this.serviceDaysToDate,
    required this.contractedDays,
    required this.coverageState,
    required this.requiresReview,
    required this.explanation,
  });

  factory MembershipRevenueMembershipModel.fromJson(Map<String, dynamic> json) {
    return MembershipRevenueMembershipModel(
      membershipId: _text(json['membresia_id']),
      clientId: _text(json['ci']),
      clientName: _text(json['cliente_nombre'], fallback: 'Cliente'),
      planId: _text(json['plan_id']),
      planName: _text(json['plan_nombre'], fallback: 'Plan'),
      state: _text(json['estado']),
      origin: _text(json['origen']),
      price: _money(json['precio']),
      funded: _money(json['financiado']),
      earnedInMonth: _money(json['devengado_mes']),
      earnedToDate: _money(json['devengado_acumulado']),
      deferredService: _money(json['pendiente_servicio']),
      reclassifiedUnused: _money(json['valor_no_consumido_reclasificado']),
      cancellationAdjustment: _money(json['ajuste_cancelacion_mes']),
      serviceDaysInMonth: _integer(json['dias_servicio_mes']),
      serviceDaysToDate: _integer(json['dias_servicio_acumulados']),
      contractedDays: _integer(json['dias_contratados']),
      coverageState: _text(json['cobertura_estado']),
      requiresReview: json['requiere_revision'] == true,
      explanation: _text(json['explicacion']),
    );
  }

  final String membershipId;
  final String clientId;
  final String clientName;
  final String planId;
  final String planName;
  final String state;
  final String origin;
  final String price;
  final String funded;
  final String earnedInMonth;
  final String earnedToDate;
  final String deferredService;
  final String reclassifiedUnused;
  final String cancellationAdjustment;
  final int serviceDaysInMonth;
  final int serviceDaysToDate;
  final int contractedDays;
  final String coverageState;
  final bool requiresReview;
  final String explanation;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<Map<String, dynamic>> _maps(Object? value) => (value as List? ?? const [])
    .whereType<Map>()
    .map(Map<String, dynamic>.from)
    .toList(growable: false);

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

String _money(Object? value) => _text(value, fallback: '0.00');

int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
