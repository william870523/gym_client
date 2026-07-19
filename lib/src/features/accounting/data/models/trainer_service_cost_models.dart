class TrainerServiceCostModel {
  const TrainerServiceCostModel({
    required this.month,
    required this.nature,
    required this.periodState,
    required this.cutoffDate,
    required this.coverage,
    required this.currencies,
    required this.note,
    required this.limitations,
  });

  factory TrainerServiceCostModel.fromJson(Map<String, dynamic> json) {
    return TrainerServiceCostModel(
      month: _text(json['mes']),
      nature: _text(json['naturaleza']),
      periodState: _text(json['estado_periodo']),
      cutoffDate: _nullableText(json['fecha_corte']),
      coverage: TrainerServiceCostCoverageModel.fromJson(
        _map(json['cobertura']),
      ),
      currencies: _maps(
        json['monedas'],
      ).map(TrainerServiceCostCurrencyModel.fromJson).toList(growable: false),
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
  final TrainerServiceCostCoverageModel coverage;
  final List<TrainerServiceCostCurrencyModel> currencies;
  final String note;
  final List<String> limitations;
}

class TrainerServiceCostCoverageModel {
  const TrainerServiceCostCoverageModel({
    required this.evaluatedConcepts,
    required this.requiresReview,
    required this.withPause,
    required this.complete,
  });

  factory TrainerServiceCostCoverageModel.fromJson(Map<String, dynamic> json) {
    return TrainerServiceCostCoverageModel(
      evaluatedConcepts: _integer(json['conceptos_evaluados']),
      requiresReview: _integer(json['requieren_revision']),
      withPause: _integer(json['conceptos_con_pausa']),
      complete: json['completa'] == true,
    );
  }

  final int evaluatedConcepts;
  final int requiresReview;
  final int withPause;
  final bool complete;
}

class TrainerServiceCostCurrencyModel {
  const TrainerServiceCostCurrencyModel({
    required this.currencyId,
    required this.currencyCode,
    required this.earnedInMonth,
    required this.earnedToDate,
    required this.paidInMonth,
    required this.paidToDate,
    required this.earnedPending,
    required this.futureCommitted,
    required this.paidAdvance,
    required this.trainers,
    required this.costs,
  });

  factory TrainerServiceCostCurrencyModel.fromJson(Map<String, dynamic> json) {
    return TrainerServiceCostCurrencyModel(
      currencyId: _text(json['moneda_id']),
      currencyCode: _text(json['moneda_codigo'], fallback: '—'),
      earnedInMonth: _money(json['costo_devengado_mes']),
      earnedToDate: _money(json['costo_devengado_acumulado']),
      paidInMonth: _money(json['pagado_mes_neto']),
      paidToDate: _money(json['pagado_acumulado']),
      earnedPending: _money(json['ganado_pendiente_pago']),
      futureCommitted: _money(json['costo_futuro_comprometido']),
      paidAdvance: _money(json['pago_anticipado']),
      trainers: _maps(
        json['entrenadores'],
      ).map(TrainerServiceCostTrainerModel.fromJson).toList(growable: false),
      costs: _maps(
        json['costos'],
      ).map(TrainerServiceCostRowModel.fromJson).toList(growable: false),
    );
  }

  final String currencyId;
  final String currencyCode;
  final String earnedInMonth;
  final String earnedToDate;
  final String paidInMonth;
  final String paidToDate;
  final String earnedPending;
  final String futureCommitted;
  final String paidAdvance;
  final List<TrainerServiceCostTrainerModel> trainers;
  final List<TrainerServiceCostRowModel> costs;
}

class TrainerServiceCostTrainerModel {
  const TrainerServiceCostTrainerModel({
    required this.trainerId,
    required this.trainerName,
    required this.earnedInMonth,
    required this.earnedToDate,
    required this.paidToDate,
    required this.earnedPending,
    required this.futureCommitted,
    required this.concepts,
    required this.clients,
    required this.plans,
    required this.requiresReview,
  });

  factory TrainerServiceCostTrainerModel.fromJson(Map<String, dynamic> json) {
    return TrainerServiceCostTrainerModel(
      trainerId: _text(json['entrenador_id']),
      trainerName: _text(json['entrenador_nombre'], fallback: 'Entrenador'),
      earnedInMonth: _money(json['costo_devengado_mes']),
      earnedToDate: _money(json['costo_devengado_acumulado']),
      paidToDate: _money(json['pagado_acumulado']),
      earnedPending: _money(json['ganado_pendiente_pago']),
      futureCommitted: _money(json['costo_futuro_comprometido']),
      concepts: _integer(json['conceptos']),
      clients: _integer(json['clientes']),
      plans: _integer(json['planes']),
      requiresReview: json['requiere_revision'] == true,
    );
  }

  final String trainerId;
  final String trainerName;
  final String earnedInMonth;
  final String earnedToDate;
  final String paidToDate;
  final String earnedPending;
  final String futureCommitted;
  final int concepts;
  final int clients;
  final int plans;
  final bool requiresReview;
}

class TrainerServiceCostRowModel {
  const TrainerServiceCostRowModel({
    required this.costId,
    required this.source,
    required this.trainerId,
    required this.trainerName,
    required this.membershipId,
    required this.clientId,
    required this.clientName,
    required this.planId,
    required this.planName,
    required this.earningMethod,
    required this.state,
    required this.periodStart,
    required this.periodEnd,
    required this.scheduledDate,
    required this.total,
    required this.earnedInMonth,
    required this.earnedToDate,
    required this.paidInMonth,
    required this.paidToDate,
    required this.earnedPending,
    required this.futureCommitted,
    required this.paidAdvance,
    required this.serviceDaysInMonth,
    required this.serviceDaysToDate,
    required this.contractedDays,
    required this.attribution,
    required this.requiresReview,
    required this.explanation,
  });

  factory TrainerServiceCostRowModel.fromJson(Map<String, dynamic> json) {
    return TrainerServiceCostRowModel(
      costId: _text(json['costo_id']),
      source: _text(json['fuente']),
      trainerId: _text(json['entrenador_id']),
      trainerName: _text(json['entrenador_nombre'], fallback: 'Entrenador'),
      membershipId: _nullableText(json['membresia_id']),
      clientId: _nullableText(json['ci']),
      clientName: _nullableText(json['cliente_nombre']),
      planId: _nullableText(json['plan_id']),
      planName: _nullableText(json['plan_nombre']),
      earningMethod: _text(json['metodo_devengo']),
      state: _text(json['estado']),
      periodStart: _text(json['periodo_inicio']),
      periodEnd: _text(json['periodo_fin']),
      scheduledDate: _text(json['fecha_programada']),
      total: _money(json['costo_total']),
      earnedInMonth: _money(json['costo_devengado_mes']),
      earnedToDate: _money(json['costo_devengado_acumulado']),
      paidInMonth: _money(json['pagado_mes_neto']),
      paidToDate: _money(json['pagado_acumulado']),
      earnedPending: _money(json['ganado_pendiente_pago']),
      futureCommitted: _money(json['costo_futuro_comprometido']),
      paidAdvance: _money(json['pago_anticipado']),
      serviceDaysInMonth: _integer(json['dias_servicio_mes']),
      serviceDaysToDate: _integer(json['dias_servicio_acumulados']),
      contractedDays: _integer(json['dias_contratados']),
      attribution: _text(json['atribucion']),
      requiresReview: json['requiere_revision'] == true,
      explanation: _text(json['explicacion']),
    );
  }

  final String costId;
  final String source;
  final String trainerId;
  final String trainerName;
  final String? membershipId;
  final String? clientId;
  final String? clientName;
  final String? planId;
  final String? planName;
  final String earningMethod;
  final String state;
  final String periodStart;
  final String periodEnd;
  final String scheduledDate;
  final String total;
  final String earnedInMonth;
  final String earnedToDate;
  final String paidInMonth;
  final String paidToDate;
  final String earnedPending;
  final String futureCommitted;
  final String paidAdvance;
  final int serviceDaysInMonth;
  final int serviceDaysToDate;
  final int contractedDays;
  final String attribution;
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
