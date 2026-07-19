import 'operational_results_models.dart';

class ManagementMarginModel {
  const ManagementMarginModel({
    required this.month,
    required this.nature,
    required this.periodState,
    required this.certified,
    required this.monthlyClose,
    required this.certificationNote,
    required this.cutoffDate,
    required this.coverage,
    required this.currencies,
    required this.note,
    required this.limitations,
  });

  factory ManagementMarginModel.fromJson(Map<String, dynamic> json) {
    return ManagementMarginModel(
      month: _text(json['mes']),
      nature: _text(json['naturaleza']),
      periodState: _text(json['estado_periodo']),
      certified: json['certificado'] == true,
      monthlyClose: json['cierre_tesoreria'] is Map
          ? OperationalMonthlyCloseModel.fromJson(
              Map<String, dynamic>.from(json['cierre_tesoreria'] as Map),
            )
          : null,
      certificationNote: _text(json['nota_certificacion']),
      cutoffDate: _nullableText(json['fecha_corte']),
      coverage: ManagementMarginCoverageModel.fromJson(_map(json['cobertura'])),
      currencies: _maps(
        json['monedas'],
      ).map(ManagementMarginCurrencyModel.fromJson).toList(growable: false),
      note: _text(json['nota']),
      limitations: (json['limitaciones'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }

  final String month;
  final String nature;
  final String periodState;
  final bool certified;
  final OperationalMonthlyCloseModel? monthlyClose;
  final String certificationNote;
  final String? cutoffDate;
  final ManagementMarginCoverageModel coverage;
  final List<ManagementMarginCurrencyModel> currencies;
  final String note;
  final List<String> limitations;
}

class ManagementMarginCoverageModel {
  const ManagementMarginCoverageModel({
    required this.evaluatedMemberships,
    required this.evaluatedCostConcepts,
    required this.requiresReview,
    required this.sharedMemberships,
    required this.withoutTrainer,
    required this.costWithoutRevenue,
    required this.complete,
  });

  factory ManagementMarginCoverageModel.fromJson(Map<String, dynamic> json) {
    return ManagementMarginCoverageModel(
      evaluatedMemberships: _integer(json['membresias_evaluadas']),
      evaluatedCostConcepts: _integer(json['conceptos_costo_evaluados']),
      requiresReview: _integer(json['requieren_revision']),
      sharedMemberships: _integer(json['membresias_compartidas']),
      withoutTrainer: _integer(json['membresias_sin_entrenador']),
      costWithoutRevenue: _integer(json['conceptos_costo_sin_ingreso']),
      complete: json['completa'] == true,
    );
  }

  final int evaluatedMemberships;
  final int evaluatedCostConcepts;
  final int requiresReview;
  final int sharedMemberships;
  final int withoutTrainer;
  final int costWithoutRevenue;
  final bool complete;
}

class ManagementMarginCurrencyModel {
  const ManagementMarginCurrencyModel({
    required this.currencyId,
    required this.currencyCode,
    required this.revenueInMonth,
    required this.revenueToDate,
    required this.directCostInMonth,
    required this.directCostToDate,
    required this.marginInMonth,
    required this.marginToDate,
    required this.marginPctToDate,
    required this.fixedInMonth,
    required this.fixedToDate,
    required this.marginAfterFixedInMonth,
    required this.marginAfterFixedToDate,
    required this.plans,
    required this.trainers,
    required this.clients,
    required this.attribution,
  });

  factory ManagementMarginCurrencyModel.fromJson(Map<String, dynamic> json) {
    return ManagementMarginCurrencyModel(
      currencyId: _text(json['moneda_id']),
      currencyCode: _text(json['moneda_codigo'], fallback: '—'),
      revenueInMonth: _money(json['ingreso_devengado_mes']),
      revenueToDate: _money(json['ingreso_devengado_acumulado']),
      directCostInMonth: _money(json['costo_directo_mes']),
      directCostToDate: _money(json['costo_directo_acumulado']),
      marginInMonth: _money(json['margen_directo_mes']),
      marginToDate: _money(json['margen_directo_acumulado']),
      marginPctToDate: _nullableText(json['margen_directo_pct_acumulado']),
      fixedInMonth: _money(json['fijo_no_distribuido_mes']),
      fixedToDate: _money(json['fijo_no_distribuido_acumulado']),
      marginAfterFixedInMonth: _money(json['margen_menos_fijo_mes']),
      marginAfterFixedToDate: _money(json['margen_menos_fijo_acumulado']),
      plans: _maps(
        json['planes'],
      ).map(ManagementMarginPlanModel.fromJson).toList(growable: false),
      trainers: _maps(
        json['entrenadores'],
      ).map(ManagementMarginTrainerModel.fromJson).toList(growable: false),
      clients: _maps(
        json['clientes'],
      ).map(ManagementMarginClientModel.fromJson).toList(growable: false),
      attribution: ManagementMarginAttributionModel.fromJson(
        _map(json['atribucion']),
      ),
    );
  }

  final String currencyId;
  final String currencyCode;
  final String revenueInMonth;
  final String revenueToDate;
  final String directCostInMonth;
  final String directCostToDate;
  final String marginInMonth;
  final String marginToDate;
  final String? marginPctToDate;
  final String fixedInMonth;
  final String fixedToDate;
  final String marginAfterFixedInMonth;
  final String marginAfterFixedToDate;
  final List<ManagementMarginPlanModel> plans;
  final List<ManagementMarginTrainerModel> trainers;
  final List<ManagementMarginClientModel> clients;
  final ManagementMarginAttributionModel attribution;
}

class ManagementMarginPlanModel {
  const ManagementMarginPlanModel({
    required this.planId,
    required this.planName,
    required this.memberships,
    required this.clients,
    required this.revenueInMonth,
    required this.revenueToDate,
    required this.costInMonth,
    required this.costToDate,
    required this.marginInMonth,
    required this.marginToDate,
    required this.marginPctToDate,
    required this.requiresReview,
  });

  factory ManagementMarginPlanModel.fromJson(Map<String, dynamic> json) {
    return ManagementMarginPlanModel(
      planId: _text(json['plan_id']),
      planName: _text(json['plan_nombre'], fallback: 'Plan sin identificar'),
      memberships: _integer(json['membresias']),
      clients: _integer(json['clientes']),
      revenueInMonth: _money(json['ingreso_devengado_mes']),
      revenueToDate: _money(json['ingreso_devengado_acumulado']),
      costInMonth: _money(json['costo_directo_mes']),
      costToDate: _money(json['costo_directo_acumulado']),
      marginInMonth: _money(json['margen_directo_mes']),
      marginToDate: _money(json['margen_directo_acumulado']),
      marginPctToDate: _nullableText(json['margen_directo_pct_acumulado']),
      requiresReview: json['requiere_revision'] == true,
    );
  }

  final String planId;
  final String planName;
  final int memberships;
  final int clients;
  final String revenueInMonth;
  final String revenueToDate;
  final String costInMonth;
  final String costToDate;
  final String marginInMonth;
  final String marginToDate;
  final String? marginPctToDate;
  final bool requiresReview;
}

class ManagementMarginTrainerModel {
  const ManagementMarginTrainerModel({
    required this.trainerId,
    required this.trainerName,
    required this.linkedMemberships,
    required this.sharedMemberships,
    required this.clients,
    required this.plans,
    required this.revenueInMonth,
    required this.revenueToDate,
    required this.costInMonth,
    required this.costToDate,
    required this.marginInMonth,
    required this.marginToDate,
    required this.marginPctToDate,
    required this.fixedInMonth,
    required this.fixedToDate,
    required this.sharedCostToDate,
    required this.orphanCostToDate,
    required this.fullyAttributed,
    required this.requiresReview,
  });

  factory ManagementMarginTrainerModel.fromJson(Map<String, dynamic> json) {
    return ManagementMarginTrainerModel(
      trainerId: _text(json['entrenador_id']),
      trainerName: _text(json['entrenador_nombre'], fallback: 'Entrenador'),
      linkedMemberships: _integer(json['membresias_vinculadas']),
      sharedMemberships: _integer(json['membresias_compartidas']),
      clients: _integer(json['clientes']),
      plans: _integer(json['planes']),
      revenueInMonth: _money(json['ingreso_devengado_mes']),
      revenueToDate: _money(json['ingreso_devengado_acumulado']),
      costInMonth: _money(json['costo_directo_mes']),
      costToDate: _money(json['costo_directo_acumulado']),
      marginInMonth: _money(json['margen_directo_mes']),
      marginToDate: _money(json['margen_directo_acumulado']),
      marginPctToDate: _nullableText(json['margen_directo_pct_acumulado']),
      fixedInMonth: _money(json['fijo_no_distribuido_mes']),
      fixedToDate: _money(json['fijo_no_distribuido_acumulado']),
      sharedCostToDate: _money(json['costo_compartido_acumulado']),
      orphanCostToDate: _money(json['costo_sin_ingreso_acumulado']),
      fullyAttributed: json['atribucion_completa'] == true,
      requiresReview: json['requiere_revision'] == true,
    );
  }

  final String trainerId;
  final String trainerName;
  final int linkedMemberships;
  final int sharedMemberships;
  final int clients;
  final int plans;
  final String revenueInMonth;
  final String revenueToDate;
  final String costInMonth;
  final String costToDate;
  final String marginInMonth;
  final String marginToDate;
  final String? marginPctToDate;
  final String fixedInMonth;
  final String fixedToDate;
  final String sharedCostToDate;
  final String orphanCostToDate;
  final bool fullyAttributed;
  final bool requiresReview;
}

class ManagementMarginClientModel {
  const ManagementMarginClientModel({
    required this.clientId,
    required this.clientName,
    required this.memberships,
    required this.plans,
    required this.revenueInMonth,
    required this.revenueToDate,
    required this.costInMonth,
    required this.costToDate,
    required this.marginInMonth,
    required this.marginToDate,
    required this.marginPctToDate,
    required this.requiresReview,
  });

  factory ManagementMarginClientModel.fromJson(Map<String, dynamic> json) {
    return ManagementMarginClientModel(
      clientId: _text(json['ci']),
      clientName: _text(json['cliente_nombre'], fallback: 'Socio'),
      memberships: _integer(json['membresias']),
      plans: _integer(json['planes']),
      revenueInMonth: _money(json['ingreso_devengado_mes']),
      revenueToDate: _money(json['ingreso_devengado_acumulado']),
      costInMonth: _money(json['costo_directo_mes']),
      costToDate: _money(json['costo_directo_acumulado']),
      marginInMonth: _money(json['margen_directo_mes']),
      marginToDate: _money(json['margen_directo_acumulado']),
      marginPctToDate: _nullableText(json['margen_directo_pct_acumulado']),
      requiresReview: json['requiere_revision'] == true,
    );
  }

  final String clientId;
  final String clientName;
  final int memberships;
  final int plans;
  final String revenueInMonth;
  final String revenueToDate;
  final String costInMonth;
  final String costToDate;
  final String marginInMonth;
  final String marginToDate;
  final String? marginPctToDate;
  final bool requiresReview;
}

class ManagementMarginAttributionModel {
  const ManagementMarginAttributionModel({
    required this.sharedMemberships,
    required this.sharedRevenueInMonth,
    required this.sharedRevenueToDate,
    required this.sharedCostInMonth,
    required this.sharedCostToDate,
    required this.withoutTrainerMemberships,
    required this.withoutTrainerRevenueInMonth,
    required this.withoutTrainerRevenueToDate,
    required this.orphanCostConcepts,
    required this.orphanCostInMonth,
    required this.orphanCostToDate,
    required this.costWithoutPlan,
    required this.costWithoutClient,
  });

  factory ManagementMarginAttributionModel.fromJson(Map<String, dynamic> json) {
    return ManagementMarginAttributionModel(
      sharedMemberships: _integer(json['membresias_compartidas']),
      sharedRevenueInMonth: _money(json['ingreso_compartido_mes']),
      sharedRevenueToDate: _money(json['ingreso_compartido_acumulado']),
      sharedCostInMonth: _money(json['costo_compartido_mes']),
      sharedCostToDate: _money(json['costo_compartido_acumulado']),
      withoutTrainerMemberships: _integer(json['membresias_sin_entrenador']),
      withoutTrainerRevenueInMonth: _money(json['ingreso_sin_entrenador_mes']),
      withoutTrainerRevenueToDate: _money(
        json['ingreso_sin_entrenador_acumulado'],
      ),
      orphanCostConcepts: _integer(json['conceptos_costo_sin_ingreso']),
      orphanCostInMonth: _money(json['costo_sin_ingreso_mes']),
      orphanCostToDate: _money(json['costo_sin_ingreso_acumulado']),
      costWithoutPlan: json['costo_sin_plan'] == true,
      costWithoutClient: json['costo_sin_socio'] == true,
    );
  }

  final int sharedMemberships;
  final String sharedRevenueInMonth;
  final String sharedRevenueToDate;
  final String sharedCostInMonth;
  final String sharedCostToDate;
  final int withoutTrainerMemberships;
  final String withoutTrainerRevenueInMonth;
  final String withoutTrainerRevenueToDate;
  final int orphanCostConcepts;
  final String orphanCostInMonth;
  final String orphanCostToDate;
  final bool costWithoutPlan;
  final bool costWithoutClient;
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
