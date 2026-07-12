class AccountingSummaryModel {
  final double pendingTrainerAmount;
  final int pendingTrainerCount;
  final int overdueTrainerCount;
  final int paidTrainerCount;
  final int activeRuleCount;
  final int defaultRuleCount;
  final int individualRuleCount;
  final int fixedPayrollProfiles;
  final int fixedPayrollPending;

  AccountingSummaryModel({
    required this.pendingTrainerAmount,
    required this.pendingTrainerCount,
    required this.overdueTrainerCount,
    required this.paidTrainerCount,
    required this.activeRuleCount,
    required this.defaultRuleCount,
    required this.individualRuleCount,
    required this.fixedPayrollProfiles,
    required this.fixedPayrollPending,
  });

  factory AccountingSummaryModel.fromJson(Map<String, dynamic> json) {
    final trainer = json['trainer_commissions'] as Map<String, dynamic>? ?? {};
    final rules = json['rules'] as Map<String, dynamic>? ?? {};
    final fixedPayroll = json['fixed_payroll'] as Map<String, dynamic>? ?? {};

    return AccountingSummaryModel(
      pendingTrainerAmount:
          (trainer['pending_amount'] as num?)?.toDouble() ?? 0,
      pendingTrainerCount: trainer['pending_count'] as int? ?? 0,
      overdueTrainerCount: trainer['overdue_count'] as int? ?? 0,
      paidTrainerCount: trainer['paid_count'] as int? ?? 0,
      activeRuleCount: rules['active_count'] as int? ?? 0,
      defaultRuleCount: rules['default_count'] as int? ?? 0,
      individualRuleCount: rules['individual_count'] as int? ?? 0,
      fixedPayrollProfiles: fixedPayroll['active_profiles'] as int? ?? 0,
      fixedPayrollPending: fixedPayroll['pending_payments'] as int? ?? 0,
    );
  }
}

class TrainerCommissionRuleModel {
  final String id;
  final String? trainerId;
  final String planId;
  final String type;
  final double value;
  final bool active;
  final DateTime startDate;
  final DateTime? endDate;
  final String planName;
  final String trainerName;

  TrainerCommissionRuleModel({
    required this.id,
    required this.trainerId,
    required this.planId,
    required this.type,
    required this.value,
    required this.active,
    required this.startDate,
    required this.endDate,
    required this.planName,
    required this.trainerName,
  });

  factory TrainerCommissionRuleModel.fromJson(Map<String, dynamic> json) {
    return TrainerCommissionRuleModel(
      id: json['regla_id'] as String,
      trainerId: json['id_entrenador'] as String?,
      planId: json['id_planes_pago'] as String,
      type: json['tipo_calculo'] as String? ?? 'PERCENTAGE',
      value: (json['valor_calculo'] as num?)?.toDouble() ?? 0,
      active: json['activo'] == true || json['activo'] == 1,
      startDate:
          DateTime.tryParse(json['fecha_inicio']?.toString() ?? '') ??
          DateTime.now(),
      endDate: json['fecha_fin'] == null
          ? null
          : DateTime.tryParse(json['fecha_fin'].toString()),
      planName:
          json['plan_nombre'] as String? ?? json['id_planes_pago'] as String,
      trainerName:
          json['entrenador_nombre'] as String? ?? 'Regla general del plan',
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'id_entrenador': trainerId,
      'id_planes_pago': planId,
      'tipo_calculo': type,
      'valor_calculo': value,
      'activo': active,
      'fecha_inicio': startDate.toUtc().toIso8601String(),
      'fecha_fin': endDate?.toUtc().toIso8601String(),
    };
  }
}

class TrainerCommissionInstallmentModel {
  final String id;
  final String trainerId;
  final String trainerName;
  final String currencyCode;
  final double amount;
  final String status;
  final DateTime scheduledDate;
  final DateTime periodStart;
  final DateTime periodEnd;

  TrainerCommissionInstallmentModel({
    required this.id,
    required this.trainerId,
    required this.trainerName,
    required this.currencyCode,
    required this.amount,
    required this.status,
    required this.scheduledDate,
    required this.periodStart,
    required this.periodEnd,
  });

  factory TrainerCommissionInstallmentModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return TrainerCommissionInstallmentModel(
      id: json['cuota_id'] as String,
      trainerId: json['id_entrenador'] as String? ?? '',
      trainerName: json['entrenador_nombre'] as String? ?? '',
      currencyCode:
          json['moneda_codigo'] as String? ??
          json['moneda_id'] as String? ??
          '',
      amount: (json['monto'] as num?)?.toDouble() ?? 0,
      status: json['estado'] as String? ?? 'PENDIENTE',
      scheduledDate:
          DateTime.tryParse(json['fecha_programada']?.toString() ?? '') ??
          DateTime.now(),
      periodStart:
          DateTime.tryParse(json['periodo_inicio']?.toString() ?? '') ??
          DateTime.now(),
      periodEnd:
          DateTime.tryParse(json['periodo_fin']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
