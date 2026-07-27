DateTime _requiredUtcInstant(Object? value, String field) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw FormatException('La API no devolvió $field como instante UTC.');
  }
  return parsed.toUtc();
}

double _moneyValue(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}

class AccountingSummaryModel {
  final double pendingTrainerAmount;
  final int pendingTrainerCount;
  final int overdueTrainerCount;
  final int paidTrainerCount;
  final int activeRuleCount;
  final int defaultRuleCount;
  final int individualRuleCount;
  final int scheduledRuleCount;
  final int conflictRuleCount;
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
    this.scheduledRuleCount = 0,
    this.conflictRuleCount = 0,
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
      scheduledRuleCount: rules['scheduled_count'] as int? ?? 0,
      conflictRuleCount: rules['conflict_count'] as int? ?? 0,
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
  final String validityStatus;
  final bool hasConflict;

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
    this.validityStatus = 'VIGENTE',
    this.hasConflict = false,
  });

  factory TrainerCommissionRuleModel.fromJson(Map<String, dynamic> json) {
    return TrainerCommissionRuleModel(
      id: json['regla_id'] as String,
      trainerId: json['id_entrenador'] as String?,
      planId: json['id_planes_pago'] as String,
      type: json['tipo_calculo'] as String? ?? 'PERCENTAGE',
      value: (json['valor_calculo'] as num?)?.toDouble() ?? 0,
      active: json['activo'] == true || json['activo'] == 1,
      startDate: _requiredUtcInstant(json['fecha_inicio'], 'fecha_inicio'),
      endDate: json['fecha_fin'] == null
          ? null
          : _requiredUtcInstant(json['fecha_fin'], 'fecha_fin'),
      planName:
          json['plan_nombre'] as String? ?? json['id_planes_pago'] as String,
      trainerName:
          json['entrenador_nombre'] as String? ?? 'Regla general del plan',
      validityStatus:
          json['vigencia_estado'] as String? ??
          ((json['activo'] == true || json['activo'] == 1)
              ? 'VIGENTE'
              : 'INACTIVA'),
      hasConflict:
          json['tiene_conflicto'] == true || json['tiene_conflicto'] == 1,
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
  final String currencyId;
  final String currencyCode;
  final double amount;
  final double appliedAmount;
  final double remainingAmount;
  final String status;
  final bool payable;
  final DateTime scheduledDate;
  final DateTime periodStart;
  final DateTime periodEnd;

  TrainerCommissionInstallmentModel({
    required this.id,
    required this.trainerId,
    required this.trainerName,
    this.currencyId = '',
    required this.currencyCode,
    required this.amount,
    this.appliedAmount = 0,
    double? remainingAmount,
    required this.status,
    this.payable = false,
    required this.scheduledDate,
    required this.periodStart,
    required this.periodEnd,
  }) : remainingAmount = remainingAmount ?? amount;

  factory TrainerCommissionInstallmentModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return TrainerCommissionInstallmentModel(
      id: json['cuota_id'] as String,
      trainerId: json['id_entrenador'] as String? ?? '',
      trainerName: json['entrenador_nombre'] as String? ?? '',
      currencyId: json['moneda_id'] as String? ?? '',
      currencyCode:
          json['moneda_codigo'] as String? ??
          json['moneda_id'] as String? ??
          '',
      amount: _moneyValue(json['monto']),
      appliedAmount: _moneyValue(json['monto_aplicado']),
      remainingAmount: json.containsKey('saldo_pendiente')
          ? _moneyValue(json['saldo_pendiente'])
          : null,
      status: json['estado'] as String? ?? 'PENDIENTE',
      payable: json['es_pagadera'] == true || json['es_pagadera'] == 1,
      scheduledDate: _requiredUtcInstant(
        json['fecha_programada'],
        'fecha_programada',
      ),
      periodStart: _requiredUtcInstant(
        json['periodo_inicio'],
        'periodo_inicio',
      ),
      periodEnd: _requiredUtcInstant(json['periodo_fin'], 'periodo_fin'),
    );
  }
}

class TrainerPayableModel {
  final String id;
  final String sourceType;
  final String trainerId;
  final String trainerName;
  final String currencyId;
  final String currencyCode;
  final double amount;
  final double appliedAmount;
  final double remainingAmount;
  final String status;
  final bool payable;
  final DateTime scheduledDate;
  final DateTime periodStart;
  final DateTime periodEnd;

  const TrainerPayableModel({
    required this.id,
    required this.sourceType,
    required this.trainerId,
    required this.trainerName,
    required this.currencyId,
    required this.currencyCode,
    required this.amount,
    required this.appliedAmount,
    required this.remainingAmount,
    required this.status,
    required this.payable,
    required this.scheduledDate,
    required this.periodStart,
    required this.periodEnd,
  });

  bool get isCommission => sourceType == 'COMISION';
  bool get isFixed => sourceType == 'FIJO';
  String get sourceLabel => isFixed ? 'Fijo' : 'Comisión';

  factory TrainerPayableModel.fromJson(Map<String, dynamic> json) {
    final sourceType = (json['origen_tipo'] as String? ?? 'COMISION')
        .toUpperCase();
    final fallbackId = sourceType == 'FIJO'
        ? json['obligacion_id']
        : json['cuota_id'];
    return TrainerPayableModel(
      id: json['referencia_id'] as String? ?? fallbackId as String? ?? '',
      sourceType: sourceType,
      trainerId: json['id_entrenador'] as String? ?? '',
      trainerName: json['entrenador_nombre'] as String? ?? '',
      currencyId: json['moneda_id'] as String? ?? '',
      currencyCode:
          json['moneda_codigo'] as String? ??
          json['moneda_id'] as String? ??
          '',
      amount: _moneyValue(json['monto']),
      appliedAmount: _moneyValue(json['monto_aplicado']),
      remainingAmount: json.containsKey('saldo_pendiente')
          ? _moneyValue(json['saldo_pendiente'])
          : _moneyValue(json['monto']),
      status: json['estado'] as String? ?? 'PENDIENTE',
      payable: json['es_pagadera'] == true || json['es_pagadera'] == 1,
      scheduledDate: _requiredUtcInstant(
        json['fecha_programada'],
        'fecha_programada',
      ),
      periodStart: _requiredUtcInstant(
        json['periodo_inicio'],
        'periodo_inicio',
      ),
      periodEnd: _requiredUtcInstant(json['periodo_fin'], 'periodo_fin'),
    );
  }
}

class TrainerPayoutAccountModel {
  final String id;
  final String name;
  final String currencyId;
  final String currencyCode;
  final String? paymentTypeId;

  const TrainerPayoutAccountModel({
    required this.id,
    required this.name,
    required this.currencyId,
    required this.currencyCode,
    required this.paymentTypeId,
  });

  factory TrainerPayoutAccountModel.fromJson(Map<String, dynamic> json) {
    return TrainerPayoutAccountModel(
      id: json['cuenta_id'] as String,
      name: json['nombre_cuenta'] as String? ?? '',
      currencyId: json['moneda_id'] as String? ?? '',
      currencyCode: json['moneda_codigo'] as String? ?? '',
      paymentTypeId: json['tipo_pago_id'] as String?,
    );
  }
}

class TrainerPayoutMethodModel {
  final String id;
  final String name;
  final String? code;

  const TrainerPayoutMethodModel({
    required this.id,
    required this.name,
    this.code,
  });

  factory TrainerPayoutMethodModel.fromJson(Map<String, dynamic> json) {
    return TrainerPayoutMethodModel(
      id: json['tipo_pago_id'] as String,
      name: json['nombre_tipo_pago'] as String? ?? '',
      code: json['codigo'] as String?,
    );
  }
}

class TrainerPayoutOptionsModel {
  final List<TrainerPayoutAccountModel> accounts;
  final List<TrainerPayoutMethodModel> methods;

  const TrainerPayoutOptionsModel({
    required this.accounts,
    required this.methods,
  });

  factory TrainerPayoutOptionsModel.fromJson(Map<String, dynamic> json) {
    return TrainerPayoutOptionsModel(
      accounts: (json['accounts'] as List? ?? const [])
          .map(
            (item) => TrainerPayoutAccountModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      methods: (json['payment_types'] as List? ?? const [])
          .map(
            (item) => TrainerPayoutMethodModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class TrainerLiquidationApplicationModel {
  final String id;
  final String installmentId;
  final double amount;
  final String status;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  const TrainerLiquidationApplicationModel({
    required this.id,
    required this.installmentId,
    required this.amount,
    required this.status,
    this.periodStart,
    this.periodEnd,
  });

  factory TrainerLiquidationApplicationModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final installment = json['cuota'] is Map
        ? Map<String, dynamic>.from(json['cuota'] as Map)
        : const <String, dynamic>{};
    return TrainerLiquidationApplicationModel(
      id: json['aplicacion_id'] as String? ?? '',
      installmentId: json['cuota_id'] as String? ?? '',
      amount: _moneyValue(json['monto_aplicado']),
      status: json['estado'] as String? ?? 'APLICADA',
      periodStart: installment['periodo_inicio'] == null
          ? null
          : _requiredUtcInstant(
              installment['periodo_inicio'],
              'periodo_inicio',
            ),
      periodEnd: installment['periodo_fin'] == null
          ? null
          : _requiredUtcInstant(installment['periodo_fin'], 'periodo_fin'),
    );
  }
}

class TrainerLiquidationFixedApplicationModel {
  final String id;
  final String obligationId;
  final double amount;
  final String status;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  const TrainerLiquidationFixedApplicationModel({
    required this.id,
    required this.obligationId,
    required this.amount,
    required this.status,
    this.periodStart,
    this.periodEnd,
  });

  factory TrainerLiquidationFixedApplicationModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final obligation = json['obligacion'] is Map
        ? Map<String, dynamic>.from(json['obligacion'] as Map)
        : const <String, dynamic>{};
    return TrainerLiquidationFixedApplicationModel(
      id: json['aplicacion_id'] as String? ?? '',
      obligationId: json['obligacion_id'] as String? ?? '',
      amount: _moneyValue(json['monto_aplicado']),
      status: json['estado'] as String? ?? 'APLICADA',
      periodStart: obligation['periodo_inicio'] == null
          ? null
          : _requiredUtcInstant(obligation['periodo_inicio'], 'periodo_inicio'),
      periodEnd: obligation['periodo_fin'] == null
          ? null
          : _requiredUtcInstant(obligation['periodo_fin'], 'periodo_fin'),
    );
  }
}

class TrainerLiquidationReversalModel {
  final String id;
  final String reason;
  final DateTime registeredAt;
  final String operatorName;

  const TrainerLiquidationReversalModel({
    required this.id,
    required this.reason,
    required this.registeredAt,
    required this.operatorName,
  });

  factory TrainerLiquidationReversalModel.fromJson(Map<String, dynamic> json) {
    return TrainerLiquidationReversalModel(
      id: json['reversion_id'] as String? ?? '',
      reason: json['motivo'] as String? ?? '',
      registeredAt: _requiredUtcInstant(json['registrada_at'], 'registrada_at'),
      operatorName: json['registrada_por_nombre_snapshot'] as String? ?? '',
    );
  }
}

class TrainerLiquidationModel {
  final String id;
  final String receiptNumber;
  final String type;
  final String? offboardingCaseId;
  final String trainerId;
  final String trainerName;
  final String currencyId;
  final String currencyCode;
  final String accountId;
  final String accountName;
  final String paymentTypeId;
  final String paymentTypeName;
  final double total;
  final double commissionTotal;
  final double fixedTotal;
  final int commissionConcepts;
  final int fixedConcepts;
  final String status;
  final String operatorName;
  final DateTime paidAt;
  final String? notes;
  final List<TrainerLiquidationApplicationModel> applications;
  final List<TrainerLiquidationFixedApplicationModel> fixedApplications;
  final TrainerLiquidationReversalModel? reversal;
  final bool idempotent;

  const TrainerLiquidationModel({
    required this.id,
    required this.receiptNumber,
    this.type = 'ORDINARIA',
    this.offboardingCaseId,
    required this.trainerId,
    required this.trainerName,
    required this.currencyId,
    required this.currencyCode,
    required this.accountId,
    required this.accountName,
    required this.paymentTypeId,
    required this.paymentTypeName,
    required this.total,
    this.commissionTotal = 0,
    this.fixedTotal = 0,
    this.commissionConcepts = 0,
    this.fixedConcepts = 0,
    required this.status,
    required this.operatorName,
    required this.paidAt,
    this.notes,
    this.applications = const [],
    this.fixedApplications = const [],
    this.reversal,
    this.idempotent = false,
  });

  factory TrainerLiquidationModel.fromJson(Map<String, dynamic> json) {
    return TrainerLiquidationModel(
      id: json['liquidacion_id'] as String,
      receiptNumber: json['comprobante_numero'] as String? ?? '',
      type: json['tipo'] as String? ?? 'ORDINARIA',
      offboardingCaseId: json['expediente_id'] as String?,
      trainerId: json['id_entrenador'] as String? ?? '',
      trainerName:
          json['entrenador_nombre'] as String? ??
          json['id_entrenador'] as String? ??
          '',
      currencyId: json['moneda_id'] as String? ?? '',
      currencyCode:
          json['moneda_codigo'] as String? ??
          json['moneda_id'] as String? ??
          '',
      accountId: json['cuenta_id'] as String? ?? '',
      accountName:
          json['cuenta_nombre'] as String? ??
          json['cuenta_id'] as String? ??
          '',
      paymentTypeId: json['tipo_pago_id'] as String? ?? '',
      paymentTypeName:
          json['tipo_pago_nombre'] as String? ??
          json['tipo_pago_id'] as String? ??
          '',
      total: _moneyValue(json['monto_total']),
      commissionTotal: json.containsKey('monto_comision')
          ? _moneyValue(json['monto_comision'])
          : _moneyValue(json['monto_total']),
      fixedTotal: _moneyValue(json['monto_fijo']),
      commissionConcepts:
          (json['conceptos_comision'] as num?)?.toInt() ??
          (json['aplicaciones'] as List?)?.length ??
          0,
      fixedConcepts:
          (json['conceptos_fijos'] as num?)?.toInt() ??
          (json['aplicaciones_fijas'] as List?)?.length ??
          0,
      status: json['estado'] as String? ?? 'PAGADA',
      operatorName: json['pagada_por_nombre_snapshot'] as String? ?? '',
      paidAt: _requiredUtcInstant(json['pagada_at'], 'pagada_at'),
      notes: json['notas'] as String?,
      applications: (json['aplicaciones'] as List? ?? const [])
          .map(
            (item) => TrainerLiquidationApplicationModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      fixedApplications: (json['aplicaciones_fijas'] as List? ?? const [])
          .map(
            (item) => TrainerLiquidationFixedApplicationModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      reversal: json['reversion'] is Map
          ? TrainerLiquidationReversalModel.fromJson(
              Map<String, dynamic>.from(json['reversion'] as Map),
            )
          : null,
      idempotent: json['idempotent'] == true,
    );
  }
}

class TrainerCompensationProfileModel {
  final String id;
  final String trainerId;
  final String trainerName;
  final bool trainerActive;
  final String modality;
  final String earningMethod;
  final String payoutFrequency;
  final int? cutoffDay;
  final double? fixedAmount;
  final String? currencyId;
  final String? currencyCode;
  final String? preferredAccountId;
  final String? preferredAccountName;
  final DateTime startDate;
  final DateTime? endDate;
  final String? notes;
  final String validityStatus;
  final bool hasConflict;

  const TrainerCompensationProfileModel({
    required this.id,
    required this.trainerId,
    required this.trainerName,
    required this.trainerActive,
    required this.modality,
    required this.earningMethod,
    required this.payoutFrequency,
    required this.cutoffDay,
    required this.fixedAmount,
    required this.currencyId,
    required this.currencyCode,
    required this.preferredAccountId,
    required this.preferredAccountName,
    required this.startDate,
    required this.endDate,
    required this.notes,
    required this.validityStatus,
    required this.hasConflict,
  });

  factory TrainerCompensationProfileModel.fromJson(Map<String, dynamic> json) {
    return TrainerCompensationProfileModel(
      id: json['perfil_id'] as String,
      trainerId: json['id_entrenador'] as String? ?? '',
      trainerName:
          json['entrenador_nombre'] as String? ??
          json['id_entrenador'] as String? ??
          '',
      trainerActive:
          json['entrenador_activo'] == true || json['entrenador_activo'] == 1,
      modality: json['modalidad'] as String? ?? 'COMISION',
      earningMethod: json['metodo_devengo'] as String? ?? 'PERIODOS_IGUALES',
      payoutFrequency: json['frecuencia_desembolso'] as String? ?? 'MENSUAL',
      cutoffDay: (json['dia_corte'] as num?)?.toInt(),
      fixedAmount: json['monto_fijo'] == null
          ? null
          : _moneyValue(json['monto_fijo']),
      currencyId: json['moneda_id'] as String?,
      currencyCode: json['moneda_codigo'] as String?,
      preferredAccountId: json['cuenta_preferida_id'] as String?,
      preferredAccountName: json['cuenta_preferida_nombre'] as String?,
      startDate: _requiredUtcInstant(json['fecha_inicio'], 'fecha_inicio'),
      endDate: json['fecha_fin'] == null
          ? null
          : _requiredUtcInstant(json['fecha_fin'], 'fecha_fin'),
      notes: json['notas'] as String?,
      validityStatus: json['vigencia_estado'] as String? ?? 'VIGENTE',
      hasConflict: json['tiene_conflicto'] == true,
    );
  }
}

class TrainerFixedObligationModel {
  final String id;
  final String profileId;
  final String trainerId;
  final String trainerName;
  final String currencyId;
  final String currencyCode;
  final double amount;
  final String status;
  final String prorationMethod;
  final int coveredDays;
  final int periodDays;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime scheduledDate;

  const TrainerFixedObligationModel({
    required this.id,
    required this.profileId,
    required this.trainerId,
    required this.trainerName,
    required this.currencyId,
    required this.currencyCode,
    required this.amount,
    required this.status,
    required this.prorationMethod,
    required this.coveredDays,
    required this.periodDays,
    required this.periodStart,
    required this.periodEnd,
    required this.scheduledDate,
  });

  factory TrainerFixedObligationModel.fromJson(Map<String, dynamic> json) {
    return TrainerFixedObligationModel(
      id: json['obligacion_id'] as String,
      profileId: json['perfil_compensacion_id'] as String? ?? '',
      trainerId: json['id_entrenador'] as String? ?? '',
      trainerName:
          json['entrenador_nombre'] as String? ??
          json['id_entrenador'] as String? ??
          '',
      currencyId: json['moneda_id'] as String? ?? '',
      currencyCode:
          json['moneda_codigo'] as String? ??
          json['moneda_id'] as String? ??
          '',
      amount: _moneyValue(json['monto']),
      status: json['estado'] as String? ?? 'PENDIENTE',
      prorationMethod:
          json['metodo_prorrateo'] as String? ?? 'PERIODOS_IGUALES',
      coveredDays: (json['dias_cubiertos'] as num?)?.toInt() ?? 0,
      periodDays: (json['dias_periodo'] as num?)?.toInt() ?? 0,
      periodStart: _requiredUtcInstant(
        json['periodo_inicio'],
        'periodo_inicio',
      ),
      periodEnd: _requiredUtcInstant(json['periodo_fin'], 'periodo_fin'),
      scheduledDate: _requiredUtcInstant(
        json['fecha_programada'],
        'fecha_programada',
      ),
    );
  }
}

class TreasuryRefundModel {
  final String adjustmentId;
  final String caseId;
  final String? refundId;
  final String? receiptNumber;
  final String status;
  final String? lastReceiptStatus;
  final String clientId;
  final String clientName;
  final String planName;
  final String membershipId;
  final String currencyId;
  final String currencyCode;
  final double amount;
  final DateTime effectiveDate;
  final DateTime requestedAt;
  final String requestedBy;
  final String requestReason;
  final String? accountId;
  final String? paymentTypeId;
  final String? treasuryReason;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  const TreasuryRefundModel({
    required this.adjustmentId,
    required this.caseId,
    required this.refundId,
    required this.receiptNumber,
    required this.status,
    required this.lastReceiptStatus,
    required this.clientId,
    required this.clientName,
    required this.planName,
    required this.membershipId,
    required this.currencyId,
    required this.currencyCode,
    required this.amount,
    required this.effectiveDate,
    required this.requestedAt,
    required this.requestedBy,
    required this.requestReason,
    required this.accountId,
    required this.paymentTypeId,
    required this.treasuryReason,
    required this.resolvedAt,
    required this.resolvedBy,
  });

  bool get isPending => status == 'PENDIENTE';
  bool get canReverse => status == 'CONFIRMADO' && refundId != null;

  factory TreasuryRefundModel.fromJson(Map<String, dynamic> json) {
    return TreasuryRefundModel(
      adjustmentId: json['ajuste_financiero_id'] as String? ?? '',
      caseId: json['expediente_id'] as String? ?? '',
      refundId: json['reembolso_id'] as String?,
      receiptNumber: json['comprobante_numero'] as String?,
      status: json['estado'] as String? ?? 'PENDIENTE',
      lastReceiptStatus: json['ultimo_comprobante_estado'] as String?,
      clientId: json['ci'] as String? ?? '',
      clientName: json['socio_nombre'] as String? ?? '',
      planName: json['plan_nombre'] as String? ?? '',
      membershipId: json['membresia_id'] as String? ?? '',
      currencyId: json['moneda_id'] as String? ?? '',
      currencyCode: json['moneda_codigo'] as String? ?? '',
      amount: _moneyValue(json['monto']),
      effectiveDate: _requiredUtcInstant(
        json['fecha_efectiva'],
        'fecha_efectiva',
      ),
      requestedAt: _requiredUtcInstant(json['solicitado_at'], 'solicitado_at'),
      requestedBy: json['solicitado_por'] as String? ?? '',
      requestReason: json['motivo_solicitud'] as String? ?? '',
      accountId: json['cuenta_id'] as String?,
      paymentTypeId: json['tipo_pago_id'] as String?,
      treasuryReason: json['motivo_tesoreria'] as String?,
      resolvedAt: json['resuelto_at'] == null
          ? null
          : _requiredUtcInstant(json['resuelto_at'], 'resuelto_at'),
      resolvedBy: json['resuelto_por'] as String?,
    );
  }
}

class TreasuryRefundOptionsModel {
  final List<TrainerPayoutAccountModel> accounts;
  final List<TrainerPayoutMethodModel> methods;

  const TreasuryRefundOptionsModel({
    required this.accounts,
    required this.methods,
  });

  factory TreasuryRefundOptionsModel.fromJson(Map<String, dynamic> json) {
    return TreasuryRefundOptionsModel(
      accounts: (json['cuentas'] as List? ?? const [])
          .map(
            (item) => TrainerPayoutAccountModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      methods: (json['tipos_pago'] as List? ?? const [])
          .map(
            (item) => TrainerPayoutMethodModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class TreasuryRefundReceiptModel {
  final String id;
  final String adjustmentId;
  final String receiptNumber;
  final String clientId;
  final String clientName;
  final String planName;
  final String currencyCode;
  final double amount;
  final String status;
  final String? accountName;
  final String? paymentTypeName;
  final String reason;
  final String requestReason;
  final String operatorName;
  final DateTime registeredAt;
  final DateTime? effectiveDate;
  final Map<String, dynamic>? reversal;

  const TreasuryRefundReceiptModel({
    required this.id,
    required this.adjustmentId,
    required this.receiptNumber,
    required this.clientId,
    required this.clientName,
    required this.planName,
    required this.currencyCode,
    required this.amount,
    required this.status,
    required this.accountName,
    required this.paymentTypeName,
    required this.reason,
    required this.requestReason,
    required this.operatorName,
    required this.registeredAt,
    required this.effectiveDate,
    required this.reversal,
  });

  factory TreasuryRefundReceiptModel.fromJson(Map<String, dynamic> json) {
    return TreasuryRefundReceiptModel(
      id: json['reembolso_id'] as String? ?? '',
      adjustmentId: json['ajuste_financiero_id'] as String? ?? '',
      receiptNumber: json['comprobante_numero'] as String? ?? '',
      clientId: json['ci'] as String? ?? '',
      clientName: json['socio_nombre'] as String? ?? '',
      planName: json['plan_nombre'] as String? ?? '',
      currencyCode: json['moneda_codigo'] as String? ?? '',
      amount: _moneyValue(json['monto']),
      status: json['estado'] as String? ?? '',
      accountName: json['cuenta_nombre'] as String?,
      paymentTypeName: json['tipo_pago_nombre'] as String?,
      reason: json['motivo'] as String? ?? '',
      requestReason: json['solicitud_motivo'] as String? ?? '',
      operatorName: json['registrada_por_nombre_snapshot'] as String? ?? '',
      registeredAt: _requiredUtcInstant(json['registrada_at'], 'registrada_at'),
      effectiveDate: json['fecha_efectiva'] == null
          ? null
          : _requiredUtcInstant(json['fecha_efectiva'], 'fecha_efectiva'),
      reversal: json['reversion'] is Map
          ? Map<String, dynamic>.from(json['reversion'] as Map)
          : null,
    );
  }
}

class TreasuryCurrencySummaryModel {
  final String currencyId;
  final String currencyCode;
  final double entries;
  final double exits;
  final double net;
  final int movementCount;

  const TreasuryCurrencySummaryModel({
    required this.currencyId,
    required this.currencyCode,
    required this.entries,
    required this.exits,
    required this.net,
    required this.movementCount,
  });

  factory TreasuryCurrencySummaryModel.fromJson(Map<String, dynamic> json) {
    return TreasuryCurrencySummaryModel(
      currencyId: json['moneda_id'] as String? ?? '',
      currencyCode:
          json['moneda_codigo'] as String? ??
          json['moneda_id'] as String? ??
          '',
      entries: _moneyValue(json['entradas']),
      exits: _moneyValue(json['salidas']),
      net: _moneyValue(json['neto']),
      movementCount: (json['movimientos'] as num?)?.toInt() ?? 0,
    );
  }
}

class TreasuryCloseModel {
  final String id;
  final String operationId;
  final String receiptNumber;
  final String businessDate;
  final String accountId;
  final String currencyId;
  final double openingBalance;
  final double entries;
  final double exits;
  final double expectedBalance;
  final double countedBalance;
  final double difference;
  final String approvalState;
  final double appliedTolerance;
  final String? requestId;
  final String? varianceReason;
  final String? approverName;
  final String? approverRole;
  final DateTime? approvedAt;
  final int movementCount;
  final DateTime? movementsThrough;
  final String operatorName;
  final DateTime closedAt;

  const TreasuryCloseModel({
    required this.id,
    required this.operationId,
    required this.receiptNumber,
    required this.businessDate,
    required this.accountId,
    required this.currencyId,
    required this.openingBalance,
    required this.entries,
    required this.exits,
    required this.expectedBalance,
    required this.countedBalance,
    required this.difference,
    this.approvalState = 'NO_REQUERIDA',
    this.appliedTolerance = 0,
    this.requestId,
    this.varianceReason,
    this.approverName,
    this.approverRole,
    this.approvedAt,
    required this.movementCount,
    required this.movementsThrough,
    required this.operatorName,
    required this.closedAt,
  });

  factory TreasuryCloseModel.fromJson(Map<String, dynamic> json) {
    return TreasuryCloseModel(
      id: json['cierre_id'] as String? ?? '',
      operationId: json['operacion_id'] as String? ?? '',
      receiptNumber: json['comprobante_numero'] as String? ?? '',
      businessDate: json['fecha_negocio']?.toString().substring(0, 10) ?? '',
      accountId: json['cuenta_id'] as String? ?? '',
      currencyId: json['moneda_id'] as String? ?? '',
      openingBalance: _moneyValue(json['saldo_inicial']),
      entries: _moneyValue(json['total_entradas']),
      exits: _moneyValue(json['total_salidas']),
      expectedBalance: _moneyValue(json['saldo_esperado']),
      countedBalance: _moneyValue(json['saldo_contado']),
      difference: _moneyValue(json['diferencia']),
      approvalState: json['aprobacion_estado'] as String? ?? 'NO_REQUERIDA',
      appliedTolerance: _moneyValue(json['tolerancia_aplicada']),
      requestId: json['solicitud_id'] as String?,
      varianceReason: json['justificacion_diferencia'] as String?,
      approverName: json['aprobado_por_nombre_snapshot'] as String?,
      approverRole: json['aprobado_por_rol_snapshot'] as String?,
      approvedAt: json['aprobado_at'] == null
          ? null
          : _requiredUtcInstant(json['aprobado_at'], 'aprobado_at'),
      movementCount: (json['movimientos_cantidad'] as num?)?.toInt() ?? 0,
      movementsThrough: json['movimientos_hasta_at'] == null
          ? null
          : _requiredUtcInstant(
              json['movimientos_hasta_at'],
              'movimientos_hasta_at',
            ),
      operatorName: json['cerrado_por_nombre_snapshot'] as String? ?? '',
      closedAt: _requiredUtcInstant(json['cerrado_at'], 'cerrado_at'),
    );
  }
}

class TreasuryAccountDayModel {
  final String id;
  final String name;
  final String currencyId;
  final String currencyCode;
  final double entries;
  final double exits;
  final double net;
  final int movementCount;
  final int reviewCount;
  final double suggestedOpeningBalance;
  final String status;
  final int lateMovementCount;
  final int reconciledMovementCount;
  final double? adjustedBalance;
  final List<TreasuryReconciliationModel> reconciliations;
  final TreasuryCloseModel? close;
  final TreasuryCloseRequestModel? pendingApproval;

  const TreasuryAccountDayModel({
    required this.id,
    required this.name,
    required this.currencyId,
    required this.currencyCode,
    required this.entries,
    required this.exits,
    required this.net,
    required this.movementCount,
    required this.reviewCount,
    required this.suggestedOpeningBalance,
    required this.status,
    required this.lateMovementCount,
    this.reconciledMovementCount = 0,
    this.adjustedBalance,
    this.reconciliations = const [],
    required this.close,
    this.pendingApproval,
  });

  bool get isOpen => status == 'ABIERTO';
  bool get requiresReconciliation => status == 'REQUIERE_CONCILIACION';
  bool get isReconciled => status == 'CONCILIADO';
  bool get isPendingApproval => status == 'PENDIENTE_APROBACION';

  factory TreasuryAccountDayModel.fromJson(Map<String, dynamic> json) {
    return TreasuryAccountDayModel(
      id: json['cuenta_id'] as String? ?? '',
      name: json['cuenta_nombre'] as String? ?? '',
      currencyId: json['moneda_id'] as String? ?? '',
      currencyCode:
          json['moneda_codigo'] as String? ??
          json['moneda_id'] as String? ??
          '',
      entries: _moneyValue(json['entradas']),
      exits: _moneyValue(json['salidas']),
      net: _moneyValue(json['neto']),
      movementCount: (json['movimientos'] as num?)?.toInt() ?? 0,
      reviewCount: (json['revisiones'] as num?)?.toInt() ?? 0,
      suggestedOpeningBalance: _moneyValue(json['saldo_inicial_sugerido']),
      status: json['estado'] as String? ?? 'ABIERTO',
      lateMovementCount: (json['movimientos_tardios'] as num?)?.toInt() ?? 0,
      reconciledMovementCount:
          (json['movimientos_conciliados'] as num?)?.toInt() ?? 0,
      adjustedBalance: json['saldo_ajustado'] == null
          ? null
          : _moneyValue(json['saldo_ajustado']),
      reconciliations: (json['conciliaciones'] as List? ?? const [])
          .map(
            (item) => TreasuryReconciliationModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      close: json['cierre'] is Map
          ? TreasuryCloseModel.fromJson(
              Map<String, dynamic>.from(json['cierre'] as Map),
            )
          : null,
      pendingApproval: json['solicitud_aprobacion'] is Map
          ? TreasuryCloseRequestModel.fromJson(
              Map<String, dynamic>.from(json['solicitud_aprobacion'] as Map),
            )
          : null,
    );
  }
}

class TreasuryCloseRequestModel {
  final String id;
  final String businessDate;
  final String accountId;
  final String currencyId;
  final double openingBalance;
  final double entries;
  final double exits;
  final double expectedBalance;
  final double countedBalance;
  final double difference;
  final double appliedTolerance;
  final int movementCount;
  final String reason;
  final String status;
  final String requesterId;
  final String requesterName;
  final String requesterRole;
  final DateTime requestedAt;
  final String? deciderName;
  final String? deciderRole;
  final String? decisionReason;
  final DateTime? decidedAt;
  final String? closeId;

  const TreasuryCloseRequestModel({
    required this.id,
    required this.businessDate,
    required this.accountId,
    required this.currencyId,
    required this.openingBalance,
    required this.entries,
    required this.exits,
    required this.expectedBalance,
    required this.countedBalance,
    required this.difference,
    required this.appliedTolerance,
    required this.movementCount,
    required this.reason,
    required this.status,
    required this.requesterId,
    required this.requesterName,
    required this.requesterRole,
    required this.requestedAt,
    this.deciderName,
    this.deciderRole,
    this.decisionReason,
    this.decidedAt,
    this.closeId,
  });

  factory TreasuryCloseRequestModel.fromJson(Map<String, dynamic> json) {
    return TreasuryCloseRequestModel(
      id: json['solicitud_id'] as String? ?? '',
      businessDate: json['fecha_negocio'] as String? ?? '',
      accountId: json['cuenta_id'] as String? ?? '',
      currencyId: json['moneda_id'] as String? ?? '',
      openingBalance: _moneyValue(json['saldo_inicial']),
      entries: _moneyValue(json['total_entradas']),
      exits: _moneyValue(json['total_salidas']),
      expectedBalance: _moneyValue(json['saldo_esperado']),
      countedBalance: _moneyValue(json['saldo_contado']),
      difference: _moneyValue(json['diferencia']),
      appliedTolerance: _moneyValue(json['tolerancia_aplicada']),
      movementCount: (json['movimientos_cantidad'] as num?)?.toInt() ?? 0,
      reason: json['motivo'] as String? ?? '',
      status: json['estado'] as String? ?? 'PENDIENTE',
      requesterId: json['solicitada_por_user_id'] as String? ?? '',
      requesterName: json['solicitada_por_nombre_snapshot'] as String? ?? '',
      requesterRole: json['solicitada_por_rol_snapshot'] as String? ?? '',
      requestedAt: _requiredUtcInstant(json['solicitada_at'], 'solicitada_at'),
      deciderName: json['decidida_por_nombre_snapshot'] as String?,
      deciderRole: json['decidida_por_rol_snapshot'] as String?,
      decisionReason: json['decision_motivo'] as String?,
      decidedAt: json['decidida_at'] == null
          ? null
          : _requiredUtcInstant(json['decidida_at'], 'decidida_at'),
      closeId: json['cierre_id'] as String?,
    );
  }
}

class TreasuryClosePolicyModel {
  final double defaultTolerance;
  final Map<String, double> currencyTolerances;
  final List<String> submitterRoles;
  final List<String> approverRoles;
  final bool allowSelfApproval;
  final bool requireVarianceReason;

  const TreasuryClosePolicyModel({
    this.defaultTolerance = 0,
    this.currencyTolerances = const {},
    this.submitterRoles = const ['admin'],
    this.approverRoles = const ['admin'],
    this.allowSelfApproval = false,
    this.requireVarianceReason = true,
  });

  double toleranceFor(String currencyId) =>
      currencyTolerances[currencyId] ?? defaultTolerance;

  factory TreasuryClosePolicyModel.fromJson(Map<String, dynamic> json) {
    final raw = Map<String, dynamic>.from(
      json['tolerancias_por_moneda'] as Map? ?? const {},
    );
    return TreasuryClosePolicyModel(
      defaultTolerance: _moneyValue(json['tolerancia_predeterminada']),
      currencyTolerances: {
        for (final entry in raw.entries) entry.key: _moneyValue(entry.value),
      },
      submitterRoles: (json['roles_solicitantes'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      approverRoles: (json['roles_aprobadores'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      allowSelfApproval: json['permite_autoaprobacion'] == true,
      requireVarianceReason: json['exige_motivo_diferencia'] != false,
    );
  }
}

class TreasuryCloseCapabilitiesModel {
  final bool canSubmit;
  final bool canApprove;
  final bool allowSelfApproval;
  final String userId;
  final String role;

  const TreasuryCloseCapabilitiesModel({
    this.canSubmit = false,
    this.canApprove = false,
    this.allowSelfApproval = false,
    this.userId = '',
    this.role = '',
  });

  factory TreasuryCloseCapabilitiesModel.fromJson(Map<String, dynamic> json) {
    return TreasuryCloseCapabilitiesModel(
      canSubmit: json['puede_solicitar'] == true,
      canApprove: json['puede_aprobar'] == true,
      allowSelfApproval: json['permite_autoaprobacion'] == true,
      userId: json['user_id'] as String? ?? '',
      role: json['rol'] as String? ?? '',
    );
  }
}

class TreasuryReconciliationModel {
  final String id;
  final String receiptNumber;
  final String closeId;
  final int movementCount;
  final double entries;
  final double exits;
  final double netAdjustment;
  final double originalCloseBalance;
  final double adjustedBalance;
  final String reason;
  final String evidenceReference;
  final String operatorName;
  final DateTime registeredAt;
  final List<String> movementIds;

  const TreasuryReconciliationModel({
    required this.id,
    required this.receiptNumber,
    required this.closeId,
    required this.movementCount,
    required this.entries,
    required this.exits,
    required this.netAdjustment,
    required this.originalCloseBalance,
    required this.adjustedBalance,
    required this.reason,
    required this.evidenceReference,
    required this.operatorName,
    required this.registeredAt,
    required this.movementIds,
  });

  factory TreasuryReconciliationModel.fromJson(Map<String, dynamic> json) {
    return TreasuryReconciliationModel(
      id: json['conciliacion_id'] as String? ?? '',
      receiptNumber: json['comprobante_numero'] as String? ?? '',
      closeId: json['cierre_id'] as String? ?? '',
      movementCount: (json['movimientos_cantidad'] as num?)?.toInt() ?? 0,
      entries: _moneyValue(json['total_entradas']),
      exits: _moneyValue(json['total_salidas']),
      netAdjustment: _moneyValue(json['ajuste_neto']),
      originalCloseBalance: _moneyValue(json['saldo_cierre_original']),
      adjustedBalance: _moneyValue(json['saldo_ajustado']),
      reason: json['motivo'] as String? ?? '',
      evidenceReference: json['evidencia_referencia'] as String? ?? '',
      operatorName: json['registrada_por_nombre_snapshot'] as String? ?? '',
      registeredAt: _requiredUtcInstant(json['registrada_at'], 'registrada_at'),
      movementIds: (json['movimiento_ids'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(),
    );
  }
}

class TreasuryManualOperationModel {
  final String id;
  final String receiptNumber;
  final String type;
  final String concept;
  final String? description;
  final String evidenceReference;
  final String? originAccountId;
  final String? destinationAccountId;
  final String currencyId;
  final double amount;
  final String operatorName;
  final DateTime registeredAt;

  const TreasuryManualOperationModel({
    required this.id,
    required this.receiptNumber,
    required this.type,
    required this.concept,
    required this.description,
    required this.evidenceReference,
    required this.originAccountId,
    required this.destinationAccountId,
    required this.currencyId,
    required this.amount,
    required this.operatorName,
    required this.registeredAt,
  });

  factory TreasuryManualOperationModel.fromJson(Map<String, dynamic> json) {
    return TreasuryManualOperationModel(
      id: json['operacion_manual_id'] as String? ?? '',
      receiptNumber: json['comprobante_numero'] as String? ?? '',
      type: json['tipo'] as String? ?? '',
      concept: json['concepto'] as String? ?? '',
      description: json['descripcion'] as String?,
      evidenceReference: json['evidencia_referencia'] as String? ?? '',
      originAccountId: json['cuenta_origen_id'] as String?,
      destinationAccountId: json['cuenta_destino_id'] as String?,
      currencyId: json['moneda_id'] as String? ?? '',
      amount: _moneyValue(json['monto']),
      operatorName: json['registrada_por_nombre_snapshot'] as String? ?? '',
      registeredAt: _requiredUtcInstant(json['registrada_at'], 'registrada_at'),
    );
  }
}

class TreasuryMovementModel {
  final String id;
  final String sourceType;
  final String sourceId;
  final String direction;
  final String concept;
  final String? accountId;
  final String accountName;
  final String currencyId;
  final String currencyCode;
  final String? paymentTypeId;
  final String? paymentTypeName;
  final double amount;
  final DateTime occurredAt;
  final String? description;
  final String? counterMovementId;
  final bool requiresReview;
  final String? reviewReason;
  final bool late;
  final bool reconciled;
  final TreasuryManualOperationModel? manualOperation;
  // R5.6 — quién recibió el dinero y, si el movimiento es un contramovimiento,
  // quién lo anuló. Son responsabilidades distintas y nunca se sustituyen.
  final String? collectorUserId;
  final String? collectorName;
  final String? collectorRole;
  final String? annulledByName;

  const TreasuryMovementModel({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.direction,
    required this.concept,
    required this.accountId,
    required this.accountName,
    required this.currencyId,
    required this.currencyCode,
    required this.paymentTypeId,
    required this.paymentTypeName,
    required this.amount,
    required this.occurredAt,
    required this.description,
    required this.counterMovementId,
    required this.requiresReview,
    required this.reviewReason,
    required this.late,
    this.reconciled = false,
    this.manualOperation,
    this.collectorUserId,
    this.collectorName,
    this.collectorRole,
    this.annulledByName,
  });

  bool get isEntry => direction == 'ENTRADA';

  /// Cobro anterior a R5.6: no se sabe quién lo recibió y se dice así, en vez
  /// de dejar el hueco en blanco o atribuirlo a nadie.
  bool get hasCollector => (collectorUserId ?? '').isNotEmpty;

  factory TreasuryMovementModel.fromJson(Map<String, dynamic> json) {
    return TreasuryMovementModel(
      id: json['movimiento_id'] as String? ?? '',
      sourceType: json['origen_tipo'] as String? ?? '',
      sourceId: json['origen_id'] as String? ?? '',
      direction: json['direccion'] as String? ?? 'ENTRADA',
      concept: json['concepto'] as String? ?? '',
      accountId: json['cuenta_id'] as String?,
      accountName: json['cuenta_nombre'] as String? ?? 'Sin cuenta',
      currencyId: json['moneda_id'] as String? ?? '',
      currencyCode:
          json['moneda_codigo'] as String? ??
          json['moneda_id'] as String? ??
          '',
      paymentTypeId: json['tipo_pago_id'] as String?,
      paymentTypeName: json['tipo_pago_nombre'] as String?,
      amount: _moneyValue(json['monto']),
      occurredAt: _requiredUtcInstant(json['ocurrido_at'], 'ocurrido_at'),
      description: json['descripcion'] as String?,
      counterMovementId: json['contramovimiento_de_id'] as String?,
      requiresReview:
          json['requiere_revision'] == true || json['requiere_revision'] == 1,
      reviewReason: json['revision_motivo'] as String?,
      late: json['es_tardio'] == true || json['es_tardio'] == 1,
      reconciled: json['es_conciliado'] == true || json['es_conciliado'] == 1,
      manualOperation: json['operacion_manual'] is Map
          ? TreasuryManualOperationModel.fromJson(
              Map<String, dynamic>.from(json['operacion_manual'] as Map),
            )
          : null,
      collectorUserId: json['cobrado_por_user_id'] as String?,
      collectorName: json['cobrado_por_nombre_snapshot'] as String?,
      collectorRole: json['cobrado_por_rol_snapshot'] as String?,
      annulledByName: json['anulado_por_nombre_snapshot'] as String?,
    );
  }
}

/// Una fila de «Cobros por recepcionista»: una persona, una cuenta y una
/// moneda (docs/PAYMENT_COLLECTOR_ATTRIBUTION.md §6).
///
/// El servidor calcula los importes y ya los separa por moneda; aquí solo se
/// presentan. Nunca se suman dos monedas en una misma fila ni en un total.
class TreasuryCollectorRowModel {
  final String? userId;
  final String name;
  final String? role;
  final String? origin;
  final bool unattributed;
  final String? accountId;
  final String accountName;
  final String currencyId;
  final String currencyCode;
  final int payments;
  final int clients;
  final double gross;
  final double change;
  final double annulled;
  final double net;

  const TreasuryCollectorRowModel({
    required this.userId,
    required this.name,
    required this.role,
    required this.origin,
    required this.unattributed,
    required this.accountId,
    required this.accountName,
    required this.currencyId,
    required this.currencyCode,
    required this.payments,
    required this.clients,
    required this.gross,
    required this.change,
    required this.annulled,
    required this.net,
  });

  factory TreasuryCollectorRowModel.fromJson(Map<String, dynamic> json) {
    final unattributed = json['historico_sin_atribuir'] == true;
    return TreasuryCollectorRowModel(
      userId: json['cobrado_por_user_id'] as String?,
      name: unattributed
          ? 'Sin atribuir · histórico'
          : (json['cobrado_por_nombre_snapshot'] as String? ??
                json['cobrado_por_user_id'] as String? ??
                'Sin atribuir · histórico'),
      role: json['cobrado_por_rol_snapshot'] as String?,
      origin: json['cobrado_por_origen'] as String?,
      unattributed: unattributed,
      accountId: json['cuenta_id'] as String?,
      // En el rollup mensual no hay una cuenta única: llega cuántas hubo.
      accountName: json['cuenta_nombre'] as String? ??
          (json['cuentas'] == null
              ? 'Sin cuenta'
              : '${json['cuentas']} cuenta(s)'),
      currencyId: json['moneda_id'] as String? ?? '',
      currencyCode:
          json['moneda_codigo'] as String? ?? json['moneda_id'] as String? ?? '',
      payments: (json['pagos'] as num?)?.toInt() ?? 0,
      clients: (json['clientes'] as num?)?.toInt() ?? 0,
      gross: _moneyValue(json['bruto']),
      change: _moneyValue(json['cambio']),
      annulled: _moneyValue(json['anulado']),
      net: _moneyValue(json['neto']),
    );
  }
}

class TreasuryIncidentsModel {
  final int withoutAccount;
  final int requiringReview;
  final int lateMovements;

  const TreasuryIncidentsModel({
    required this.withoutAccount,
    required this.requiringReview,
    required this.lateMovements,
  });

  int get total => withoutAccount + requiringReview + lateMovements;

  factory TreasuryIncidentsModel.fromJson(Map<String, dynamic> json) {
    return TreasuryIncidentsModel(
      withoutAccount: (json['sin_cuenta'] as num?)?.toInt() ?? 0,
      requiringReview: (json['requieren_revision'] as num?)?.toInt() ?? 0,
      lateMovements: (json['movimientos_tardios'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Un recargo por mora perdonado en un cobro (docs/RECARGO_MORA.md §6-bis).
class TreasuryWaivedLateFeeModel {
  final String paymentId;
  final String memberId;
  final String memberName;
  final double amount;
  final String currencyId;
  final String currencyCode;
  final String reason;
  final String authorizedBy;

  const TreasuryWaivedLateFeeModel({
    required this.paymentId,
    required this.memberId,
    required this.memberName,
    required this.amount,
    required this.currencyId,
    required this.currencyCode,
    required this.reason,
    required this.authorizedBy,
  });

  factory TreasuryWaivedLateFeeModel.fromJson(Map<String, dynamic> json) {
    return TreasuryWaivedLateFeeModel(
      paymentId: json['pago_cliente_id'] as String? ?? '',
      memberId: json['ci'] as String? ?? '',
      memberName: json['socio'] as String? ?? json['ci'] as String? ?? '',
      amount: _moneyValue(json['importe']),
      currencyId: json['moneda_id'] as String? ?? '',
      currencyCode:
          json['moneda_codigo'] as String? ?? json['moneda_id'] as String? ?? '',
      reason: json['motivo'] as String? ?? '',
      authorizedBy: json['condonado_por'] as String? ?? 'Sin registrar',
    );
  }
}

/// Total condonado en UNA moneda. El servidor nunca mezcla monedas.
class TreasuryWaivedLateFeeCurrencyModel {
  final String currencyId;
  final String currencyCode;
  final double amount;
  final int count;

  const TreasuryWaivedLateFeeCurrencyModel({
    required this.currencyId,
    required this.currencyCode,
    required this.amount,
    required this.count,
  });

  factory TreasuryWaivedLateFeeCurrencyModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return TreasuryWaivedLateFeeCurrencyModel(
      currencyId: json['moneda_id'] as String? ?? '',
      currencyCode:
          json['moneda_codigo'] as String? ?? json['moneda_id'] as String? ?? '',
      amount: _moneyValue(json['importe']),
      count: (json['condonaciones'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Línea «recargos condonados» del cierre diario.
///
/// El importe lo calcula el servidor; aquí solo se presenta. No es un
/// movimiento de caja: no entra en el arqueo ni en el saldo.
class TreasuryWaivedLateFeesModel {
  final List<TreasuryWaivedLateFeeCurrencyModel> byCurrency;
  final List<TreasuryWaivedLateFeeModel> details;
  final int count;

  const TreasuryWaivedLateFeesModel({
    this.byCurrency = const [],
    this.details = const [],
    this.count = 0,
  });

  bool get isEmpty => count == 0 || byCurrency.isEmpty;

  factory TreasuryWaivedLateFeesModel.fromJson(Map<String, dynamic> json) {
    final details = (json['detalle'] as List? ?? const [])
        .map(
          (item) => TreasuryWaivedLateFeeModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    return TreasuryWaivedLateFeesModel(
      byCurrency: (json['por_moneda'] as List? ?? const [])
          .map(
            (item) => TreasuryWaivedLateFeeCurrencyModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      details: details,
      count: (json['condonaciones'] as num?)?.toInt() ?? details.length,
    );
  }
}

class TreasuryLedgerModel {
  final String businessDate;
  final List<TreasuryCurrencySummaryModel> currencySummaries;
  final List<TreasuryAccountDayModel> accounts;
  final List<TreasuryMovementModel> movements;
  final TreasuryIncidentsModel incidents;
  final TreasuryWaivedLateFeesModel waivedLateFees;
  final List<TreasuryCollectorRowModel> collectorRows;
  final TreasuryClosePolicyModel closePolicy;
  final TreasuryCloseCapabilitiesModel closeCapabilities;
  final List<TreasuryCloseRequestModel> closeRequests;
  final String? closeResultStatus;

  const TreasuryLedgerModel({
    required this.businessDate,
    required this.currencySummaries,
    required this.accounts,
    required this.movements,
    required this.incidents,
    this.waivedLateFees = const TreasuryWaivedLateFeesModel(),
    this.collectorRows = const [],
    this.closePolicy = const TreasuryClosePolicyModel(),
    this.closeCapabilities = const TreasuryCloseCapabilitiesModel(),
    this.closeRequests = const [],
    this.closeResultStatus,
  });

  factory TreasuryLedgerModel.fromJson(Map<String, dynamic> json) {
    return TreasuryLedgerModel(
      businessDate: json['fecha_negocio'] as String? ?? '',
      currencySummaries: (json['resumen_monedas'] as List? ?? const [])
          .map(
            (item) => TreasuryCurrencySummaryModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      accounts: (json['cuentas'] as List? ?? const [])
          .map(
            (item) => TreasuryAccountDayModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      movements: (json['movimientos'] as List? ?? const [])
          .map(
            (item) => TreasuryMovementModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      incidents: TreasuryIncidentsModel.fromJson(
        Map<String, dynamic>.from(
          json['incidencias'] as Map? ?? const <String, dynamic>{},
        ),
      ),
      waivedLateFees: TreasuryWaivedLateFeesModel.fromJson(
        Map<String, dynamic>.from(
          json['recargos_condonados'] as Map? ?? const <String, dynamic>{},
        ),
      ),
      collectorRows: (json['cobros_por_recepcionista'] as List? ?? const [])
          .map(
            (item) => TreasuryCollectorRowModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      closePolicy: TreasuryClosePolicyModel.fromJson(
        Map<String, dynamic>.from(
          json['politica_arqueo'] as Map? ?? const <String, dynamic>{},
        ),
      ),
      closeCapabilities: TreasuryCloseCapabilitiesModel.fromJson(
        Map<String, dynamic>.from(
          json['capacidades_arqueo'] as Map? ?? const <String, dynamic>{},
        ),
      ),
      closeRequests: (json['solicitudes_arqueo'] as List? ?? const [])
          .map(
            (item) => TreasuryCloseRequestModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      closeResultStatus:
          (json['resultado_arqueo'] as Map?)?['estado'] as String?,
    );
  }
}

class TreasuryMonthlySummaryModel {
  final String month;
  final String startDate;
  final String endDate;
  final List<TreasuryMonthlyCurrencyModel> currencies;
  final TreasuryMonthlyCloseStatusModel monthlyClose;
  /// R5.6 — cobros del mes por persona y moneda. En el mes las cuentas se
  /// funden (una recepcionista puede haber cobrado en varias cajas); las
  /// monedas nunca.
  final List<TreasuryCollectorRowModel> collectorRows;

  const TreasuryMonthlySummaryModel({
    required this.month,
    required this.startDate,
    required this.endDate,
    required this.currencies,
    this.monthlyClose = const TreasuryMonthlyCloseStatusModel(),
    this.collectorRows = const [],
  });

  factory TreasuryMonthlySummaryModel.fromJson(Map<String, dynamic> json) {
    return TreasuryMonthlySummaryModel(
      month: json['mes'] as String? ?? '',
      startDate: json['fecha_desde'] as String? ?? '',
      endDate: json['fecha_hasta'] as String? ?? '',
      currencies: (json['monedas'] as List? ?? const [])
          .map(
            (item) => TreasuryMonthlyCurrencyModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      monthlyClose: TreasuryMonthlyCloseStatusModel.fromJson(
        Map<String, dynamic>.from(
          json['cierre_mensual'] as Map? ?? const <String, dynamic>{},
        ),
      ),
      collectorRows: (json['cobros_por_recepcionista'] as List? ?? const [])
          .map(
            (item) => TreasuryCollectorRowModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class TreasuryMonthlyCloseStatusModel {
  final String state;
  final bool monthEnded;
  final bool readyToClose;
  final List<TreasuryMonthlyCloseBlockerModel> blockers;
  final bool canClose;
  final bool canReopen;
  final TreasuryMonthlyCloseCycleModel? currentCycle;
  final TreasuryMonthlyCloseCycleModel? lastCycle;
  final List<TreasuryMonthlyCloseCycleModel> history;

  const TreasuryMonthlyCloseStatusModel({
    this.state = 'ABIERTO',
    this.monthEnded = false,
    this.readyToClose = false,
    this.blockers = const [],
    this.canClose = false,
    this.canReopen = false,
    this.currentCycle,
    this.lastCycle,
    this.history = const [],
  });

  bool get isClosed => state == 'CERRADO';

  factory TreasuryMonthlyCloseStatusModel.fromJson(Map<String, dynamic> json) {
    final capabilities = Map<String, dynamic>.from(
      json['capacidades'] as Map? ?? const <String, dynamic>{},
    );
    TreasuryMonthlyCloseCycleModel? cycle(dynamic value) => value is Map
        ? TreasuryMonthlyCloseCycleModel.fromJson(
            Map<String, dynamic>.from(value),
          )
        : null;
    return TreasuryMonthlyCloseStatusModel(
      state: json['estado'] as String? ?? 'ABIERTO',
      monthEnded: json['mes_terminado'] as bool? ?? false,
      readyToClose: json['listo_para_cerrar'] as bool? ?? false,
      blockers: (json['bloqueadores'] as List? ?? const [])
          .map(
            (item) => TreasuryMonthlyCloseBlockerModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      canClose: capabilities['puede_cerrar'] as bool? ?? false,
      canReopen: capabilities['puede_reabrir'] as bool? ?? false,
      currentCycle: cycle(json['ciclo_actual']),
      lastCycle: cycle(json['ultimo_ciclo']),
      history: (json['historial'] as List? ?? const [])
          .map(
            (item) => TreasuryMonthlyCloseCycleModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class TreasuryMonthlyCloseBlockerModel {
  final String code;
  final String? currencyCode;
  final int count;
  final String message;

  const TreasuryMonthlyCloseBlockerModel({
    required this.code,
    this.currencyCode,
    required this.count,
    required this.message,
  });

  factory TreasuryMonthlyCloseBlockerModel.fromJson(Map<String, dynamic> json) {
    return TreasuryMonthlyCloseBlockerModel(
      code: json['codigo'] as String? ?? '',
      currencyCode: json['moneda_codigo'] as String?,
      count: (json['cantidad'] as num?)?.toInt() ?? 0,
      message: json['mensaje'] as String? ?? '',
    );
  }
}

class TreasuryMonthlyCloseCycleModel {
  final String id;
  final String month;
  final String state;
  final String closeReason;
  final String hash;
  final bool integrityVerified;
  final String closerName;
  final String closerRole;
  final String closedAt;
  final String? reopenReason;
  final String? reopenerName;
  final String? reopenerRole;
  final String? reopenedAt;

  const TreasuryMonthlyCloseCycleModel({
    required this.id,
    required this.month,
    required this.state,
    required this.closeReason,
    required this.hash,
    required this.integrityVerified,
    required this.closerName,
    required this.closerRole,
    required this.closedAt,
    this.reopenReason,
    this.reopenerName,
    this.reopenerRole,
    this.reopenedAt,
  });

  factory TreasuryMonthlyCloseCycleModel.fromJson(Map<String, dynamic> json) {
    return TreasuryMonthlyCloseCycleModel(
      id: json['cierre_mensual_id'] as String? ?? '',
      month: json['mes'] as String? ?? '',
      state: json['estado'] as String? ?? '',
      closeReason: json['motivo_cierre'] as String? ?? '',
      hash: json['resumen_sha256'] as String? ?? '',
      integrityVerified: json['integridad_verificada'] as bool? ?? false,
      closerName: json['cerrado_por_nombre'] as String? ?? '',
      closerRole: json['cerrado_por_rol'] as String? ?? '',
      closedAt: json['cerrado_at']?.toString() ?? '',
      reopenReason: json['reapertura_motivo'] as String?,
      reopenerName: json['reabierto_por_nombre'] as String?,
      reopenerRole: json['reabierto_por_rol'] as String?,
      reopenedAt: json['reabierto_at']?.toString(),
    );
  }
}

class TreasuryMonthlyCurrencyModel {
  final String currencyId;
  final String currencyCode;
  final double entries;
  final double exits;
  final double net;
  final int movementCount;
  final int activeAccountCount;
  final int activityJourneys;
  final int closedJourneys;
  final int openJourneys;
  final double closeCoverage;
  final int closeCount;
  final int approvedCloseCount;
  final int withinToleranceCloseCount;
  final int pendingApprovalCount;
  final int rejectedRequestCount;
  final int obsoleteRequestCount;
  final int reconciliationCount;
  final double monthlyReconciledAdjustments;
  final int reconciledMovementCount;
  final int pendingLateMovementCount;
  final int pendingReviewCount;
  final int unassignedMovementCount;
  final int accountsWithoutClose;
  final double originalCloseBalance;
  final double currentAdjustments;
  final double currentBalance;
  final double pendingCloseNet;
  final List<TreasuryMonthlyTrendModel> trend;
  final List<TreasuryMonthlyAccountModel> accounts;

  const TreasuryMonthlyCurrencyModel({
    required this.currencyId,
    required this.currencyCode,
    required this.entries,
    required this.exits,
    required this.net,
    required this.movementCount,
    required this.activeAccountCount,
    required this.activityJourneys,
    required this.closedJourneys,
    required this.openJourneys,
    required this.closeCoverage,
    required this.closeCount,
    this.approvedCloseCount = 0,
    this.withinToleranceCloseCount = 0,
    this.pendingApprovalCount = 0,
    this.rejectedRequestCount = 0,
    this.obsoleteRequestCount = 0,
    required this.reconciliationCount,
    required this.monthlyReconciledAdjustments,
    required this.reconciledMovementCount,
    required this.pendingLateMovementCount,
    required this.pendingReviewCount,
    this.unassignedMovementCount = 0,
    required this.accountsWithoutClose,
    required this.originalCloseBalance,
    required this.currentAdjustments,
    required this.currentBalance,
    required this.pendingCloseNet,
    required this.trend,
    required this.accounts,
  });

  bool get requiresAttention =>
      openJourneys > 0 ||
      pendingApprovalCount > 0 ||
      pendingLateMovementCount > 0 ||
      pendingReviewCount > 0 ||
      unassignedMovementCount > 0 ||
      accountsWithoutClose > 0;

  factory TreasuryMonthlyCurrencyModel.fromJson(Map<String, dynamic> json) {
    return TreasuryMonthlyCurrencyModel(
      currencyId: json['moneda_id'] as String? ?? '',
      currencyCode:
          json['moneda_codigo'] as String? ??
          json['moneda_id'] as String? ??
          '',
      entries: _moneyValue(json['entradas']),
      exits: _moneyValue(json['salidas']),
      net: _moneyValue(json['neto']),
      movementCount: (json['movimientos'] as num?)?.toInt() ?? 0,
      activeAccountCount: (json['cuentas_con_actividad'] as num?)?.toInt() ?? 0,
      activityJourneys: (json['jornadas_actividad'] as num?)?.toInt() ?? 0,
      closedJourneys: (json['jornadas_cerradas'] as num?)?.toInt() ?? 0,
      openJourneys: (json['jornadas_por_cerrar'] as num?)?.toInt() ?? 0,
      closeCoverage: (json['cobertura_cierre'] as num?)?.toDouble() ?? 0,
      closeCount: (json['cierres'] as num?)?.toInt() ?? 0,
      approvedCloseCount: (json['cierres_aprobados'] as num?)?.toInt() ?? 0,
      withinToleranceCloseCount:
          (json['cierres_dentro_tolerancia'] as num?)?.toInt() ?? 0,
      pendingApprovalCount:
          (json['solicitudes_pendientes'] as num?)?.toInt() ?? 0,
      rejectedRequestCount:
          (json['solicitudes_rechazadas'] as num?)?.toInt() ?? 0,
      obsoleteRequestCount:
          (json['solicitudes_obsoletas'] as num?)?.toInt() ?? 0,
      reconciliationCount: (json['conciliaciones'] as num?)?.toInt() ?? 0,
      monthlyReconciledAdjustments: _moneyValue(
        json['ajustes_conciliados_mes'],
      ),
      reconciledMovementCount:
          (json['movimientos_conciliados'] as num?)?.toInt() ?? 0,
      pendingLateMovementCount:
          (json['movimientos_tardios_pendientes'] as num?)?.toInt() ?? 0,
      pendingReviewCount: (json['revisiones_pendientes'] as num?)?.toInt() ?? 0,
      unassignedMovementCount:
          (json['movimientos_sin_cuenta'] as num?)?.toInt() ?? 0,
      accountsWithoutClose: (json['cuentas_sin_cierre'] as num?)?.toInt() ?? 0,
      originalCloseBalance: _moneyValue(json['saldo_cierre_original']),
      currentAdjustments: _moneyValue(json['ajustes_vigentes']),
      currentBalance: _moneyValue(json['saldo_vigente']),
      pendingCloseNet: _moneyValue(json['neto_pendiente_cierre']),
      trend: (json['tendencia'] as List? ?? const [])
          .map(
            (item) => TreasuryMonthlyTrendModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      accounts: (json['cuentas'] as List? ?? const [])
          .map(
            (item) => TreasuryMonthlyAccountModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class TreasuryMonthlyTrendModel {
  final String businessDate;
  final double entries;
  final double exits;
  final double net;
  final int closeCount;
  final double reconciledAdjustments;

  const TreasuryMonthlyTrendModel({
    required this.businessDate,
    required this.entries,
    required this.exits,
    required this.net,
    required this.closeCount,
    required this.reconciledAdjustments,
  });

  factory TreasuryMonthlyTrendModel.fromJson(Map<String, dynamic> json) {
    return TreasuryMonthlyTrendModel(
      businessDate: json['fecha'] as String? ?? '',
      entries: _moneyValue(json['entradas']),
      exits: _moneyValue(json['salidas']),
      net: _moneyValue(json['neto']),
      closeCount: (json['cierres'] as num?)?.toInt() ?? 0,
      reconciledAdjustments: _moneyValue(json['ajustes_conciliados']),
    );
  }
}

class TreasuryMonthlyAccountModel {
  final String id;
  final String name;
  final String currencyId;
  final String currencyCode;
  final double entries;
  final double exits;
  final double net;
  final int movementCount;
  final int activityDays;
  final int closedJourneys;
  final int openJourneys;
  final int closeCount;
  final int approvedCloseCount;
  final int withinToleranceCloseCount;
  final int pendingApprovalCount;
  final int rejectedRequestCount;
  final int obsoleteRequestCount;
  final int reconciliationCount;
  final double monthlyReconciledAdjustments;
  final int reconciledMovementCount;
  final int pendingLateMovementCount;
  final int pendingReviewCount;
  final String? lastCloseDate;
  final double? originalCloseBalance;
  final double? currentAdjustments;
  final double? currentBalance;
  final double pendingCloseNet;
  final String status;

  const TreasuryMonthlyAccountModel({
    required this.id,
    required this.name,
    required this.currencyId,
    required this.currencyCode,
    required this.entries,
    required this.exits,
    required this.net,
    required this.movementCount,
    required this.activityDays,
    required this.closedJourneys,
    required this.openJourneys,
    required this.closeCount,
    this.approvedCloseCount = 0,
    this.withinToleranceCloseCount = 0,
    this.pendingApprovalCount = 0,
    this.rejectedRequestCount = 0,
    this.obsoleteRequestCount = 0,
    required this.reconciliationCount,
    required this.monthlyReconciledAdjustments,
    required this.reconciledMovementCount,
    required this.pendingLateMovementCount,
    required this.pendingReviewCount,
    required this.lastCloseDate,
    required this.originalCloseBalance,
    required this.currentAdjustments,
    required this.currentBalance,
    required this.pendingCloseNet,
    required this.status,
  });

  bool get requiresAttention =>
      openJourneys > 0 ||
      pendingApprovalCount > 0 ||
      pendingLateMovementCount > 0 ||
      pendingReviewCount > 0 ||
      status == 'SIN_CIERRE' ||
      status == 'PENDIENTE_APROBACION';

  factory TreasuryMonthlyAccountModel.fromJson(Map<String, dynamic> json) {
    return TreasuryMonthlyAccountModel(
      id: json['cuenta_id'] as String? ?? '',
      name: json['cuenta_nombre'] as String? ?? '',
      currencyId: json['moneda_id'] as String? ?? '',
      currencyCode:
          json['moneda_codigo'] as String? ??
          json['moneda_id'] as String? ??
          '',
      entries: _moneyValue(json['entradas']),
      exits: _moneyValue(json['salidas']),
      net: _moneyValue(json['neto']),
      movementCount: (json['movimientos'] as num?)?.toInt() ?? 0,
      activityDays: (json['dias_actividad'] as num?)?.toInt() ?? 0,
      closedJourneys: (json['jornadas_cerradas'] as num?)?.toInt() ?? 0,
      openJourneys: (json['jornadas_por_cerrar'] as num?)?.toInt() ?? 0,
      closeCount: (json['cierres'] as num?)?.toInt() ?? 0,
      approvedCloseCount: (json['cierres_aprobados'] as num?)?.toInt() ?? 0,
      withinToleranceCloseCount:
          (json['cierres_dentro_tolerancia'] as num?)?.toInt() ?? 0,
      pendingApprovalCount:
          (json['solicitudes_pendientes'] as num?)?.toInt() ?? 0,
      rejectedRequestCount:
          (json['solicitudes_rechazadas'] as num?)?.toInt() ?? 0,
      obsoleteRequestCount:
          (json['solicitudes_obsoletas'] as num?)?.toInt() ?? 0,
      reconciliationCount: (json['conciliaciones'] as num?)?.toInt() ?? 0,
      monthlyReconciledAdjustments: _moneyValue(
        json['ajustes_conciliados_mes'],
      ),
      reconciledMovementCount:
          (json['movimientos_conciliados'] as num?)?.toInt() ?? 0,
      pendingLateMovementCount:
          (json['movimientos_tardios_pendientes'] as num?)?.toInt() ?? 0,
      pendingReviewCount: (json['revisiones_pendientes'] as num?)?.toInt() ?? 0,
      lastCloseDate: json['ultimo_cierre_fecha'] as String?,
      originalCloseBalance: json['saldo_cierre_original'] == null
          ? null
          : _moneyValue(json['saldo_cierre_original']),
      currentAdjustments: json['ajustes_vigentes'] == null
          ? null
          : _moneyValue(json['ajustes_vigentes']),
      currentBalance: json['saldo_vigente'] == null
          ? null
          : _moneyValue(json['saldo_vigente']),
      pendingCloseNet: _moneyValue(json['neto_pendiente_cierre']),
      status: json['estado'] as String? ?? 'SIN_CIERRE',
    );
  }
}

class GastoCategoriaModel {
  final String categoriaId;
  final String gymId;
  final String nombre;
  final String naturaleza;
  final bool esSistema;

  GastoCategoriaModel({
    required this.categoriaId,
    required this.gymId,
    required this.nombre,
    required this.naturaleza,
    required this.esSistema,
  });

  factory GastoCategoriaModel.fromJson(Map<String, dynamic> json) {
    return GastoCategoriaModel(
      categoriaId: json['categoria_id']?.toString() ?? '',
      gymId: json['gym_id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      naturaleza: json['naturaleza']?.toString() ?? 'OPERATIVO',
      esSistema: json['es_sistema'] == true,
    );
  }
}

class GastoProveedorModel {
  final String proveedorId;
  final String gymId;
  final String nombre;
  final String? documento;
  final String? cuentaPagoDefaultId;

  GastoProveedorModel({
    required this.proveedorId,
    required this.gymId,
    required this.nombre,
    this.documento,
    this.cuentaPagoDefaultId,
  });

  factory GastoProveedorModel.fromJson(Map<String, dynamic> json) {
    return GastoProveedorModel(
      proveedorId: json['proveedor_id']?.toString() ?? '',
      gymId: json['gym_id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      documento: json['documento']?.toString(),
      cuentaPagoDefaultId: json['cuenta_pago_default_id']?.toString(),
    );
  }
}

class GastoGobernadoAplicacionModel {
  final String aplicacionId;
  final String gastoId;
  final String? movimientoId;
  final String montoAplicado;
  final String estado;
  final DateTime aplicadaAt;

  GastoGobernadoAplicacionModel({
    required this.aplicacionId,
    required this.gastoId,
    this.movimientoId,
    required this.montoAplicado,
    required this.estado,
    required this.aplicadaAt,
  });

  factory GastoGobernadoAplicacionModel.fromJson(Map<String, dynamic> json) {
    return GastoGobernadoAplicacionModel(
      aplicacionId:
          json['aplicacion_id']?.toString() ??
          json['aplicacionId']?.toString() ??
          '',
      gastoId:
          json['gasto_id']?.toString() ?? json['gastoId']?.toString() ?? '',
      movimientoId:
          json['movimiento_id']?.toString() ?? json['movimientoId']?.toString(),
      montoAplicado:
          json['monto_aplicado']?.toString() ??
          json['montoAplicado']?.toString() ??
          json['amount']?.toString() ??
          '0.00',
      estado:
          json['estado']?.toString() ?? json['state']?.toString() ?? 'APLICADA',
      aplicadaAt: _requiredUtcInstant(
        json['aplicada_at'] ?? json['aplicadaAt'] ?? json['paidAt'],
        'aplicada_at',
      ),
    );
  }
}

class GastoGobernadoModel {
  final String gastoId;
  final String categoriaId;
  final String? categoriaNombre;
  final String naturaleza;
  final String? proveedorId;
  final String? proveedorNombre;
  final String monedaId;
  final String? codigoMoneda;
  final String descripcion;
  final String monto;
  final String periodoPertenenciaMes;
  final String? fechaPago;
  final DateTime? fechaProgramada;
  final String estado;
  final String pagadoAcumulado;
  final String? comprobanteReferencia;
  final List<GastoGobernadoAplicacionModel> aplicaciones;

  GastoGobernadoModel({
    required this.gastoId,
    required this.categoriaId,
    this.categoriaNombre,
    required this.naturaleza,
    this.proveedorId,
    this.proveedorNombre,
    required this.monedaId,
    this.codigoMoneda,
    required this.descripcion,
    required this.monto,
    required this.periodoPertenenciaMes,
    this.fechaPago,
    this.fechaProgramada,
    required this.estado,
    required this.pagadoAcumulado,
    this.comprobanteReferencia,
    required this.aplicaciones,
  });

  factory GastoGobernadoModel.fromJson(Map<String, dynamic> json) {
    final rawApps =
        json['aplicaciones'] as List<dynamic>? ??
        json['applications'] as List<dynamic>? ??
        [];
    return GastoGobernadoModel(
      gastoId:
          json['gasto_id']?.toString() ??
          json['gastoId']?.toString() ??
          json['id']?.toString() ??
          '',
      categoriaId:
          json['categoria_id']?.toString() ??
          json['categoriaId']?.toString() ??
          json['categoryId']?.toString() ??
          '',
      categoriaNombre:
          json['categoria_nombre']?.toString() ??
          json['categoriaNombre']?.toString() ??
          json['categoryName']?.toString(),
      naturaleza:
          json['categoria_naturaleza']?.toString() ??
          json['naturaleza']?.toString() ??
          json['nature']?.toString() ??
          'OPERATIVO',
      proveedorId:
          json['proveedor_id']?.toString() ??
          json['proveedorId']?.toString() ??
          json['supplierId']?.toString(),
      proveedorNombre:
          json['proveedor_nombre']?.toString() ??
          json['proveedorNombre']?.toString() ??
          json['supplierName']?.toString(),
      monedaId:
          json['moneda_id']?.toString() ??
          json['monedaId']?.toString() ??
          json['currencyId']?.toString() ??
          '',
      codigoMoneda:
          json['moneda_codigo']?.toString() ??
          json['codigo_moneda']?.toString() ??
          json['codigoMoneda']?.toString() ??
          json['currencyCode']?.toString(),
      descripcion:
          json['descripcion']?.toString() ??
          json['description']?.toString() ??
          '',
      monto:
          json['importe']?.toString() ??
          json['monto']?.toString() ??
          json['amount']?.toString() ??
          '0.00',
      periodoPertenenciaMes:
          json['mes_pertenencia']?.toString() ??
          json['periodo_pertenencia_mes']?.toString() ??
          json['periodoPertenenciaMes']?.toString() ??
          json['accrualMonth']?.toString() ??
          '',
      fechaPago:
          json['fecha_pago']?.toString() ??
          json['fechaPago']?.toString() ??
          json['paidBusinessDate']?.toString(),
      fechaProgramada: json['fecha_programada'] != null
          ? DateTime.tryParse(json['fecha_programada'].toString())?.toUtc()
          : null,
      estado:
          json['estado']?.toString() ??
          json['state']?.toString() ??
          'PENDIENTE',
      pagadoAcumulado:
          json['pagado_acumulado']?.toString() ??
          json['pagadoAcumulado']?.toString() ??
          json['paidAmount']?.toString() ??
          '0.00',
      comprobanteReferencia:
          json['comprobante_referencia']?.toString() ??
          json['comprobanteReferencia']?.toString() ??
          json['reference']?.toString(),
      aplicaciones: rawApps
          .map(
            (a) => GastoGobernadoAplicacionModel.fromJson(
              a as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class GovernedExpenseCurrencyModel {
  final String monedaId;
  final String codigoMoneda;
  final String devengadoMes;
  final String pagadoMes;
  final String pagadoAcumulado;
  final String pagoAnticipado;
  final String pagoAtrasado;
  final String pendientePago;
  final List<GastoGobernadoModel> gastos;

  GovernedExpenseCurrencyModel({
    required this.monedaId,
    required this.codigoMoneda,
    required this.devengadoMes,
    required this.pagadoMes,
    required this.pagadoAcumulado,
    required this.pagoAnticipado,
    required this.pagoAtrasado,
    required this.pendientePago,
    required this.gastos,
  });

  factory GovernedExpenseCurrencyModel.fromJson(Map<String, dynamic> json) {
    final rawExpenses =
        json['gastos'] as List<dynamic>? ??
        json['expenses'] as List<dynamic>? ??
        const [];
    return GovernedExpenseCurrencyModel(
      monedaId:
          json['moneda_id']?.toString() ?? json['currencyId']?.toString() ?? '',
      codigoMoneda:
          json['moneda_codigo']?.toString() ??
          json['codigo_moneda']?.toString() ??
          json['currencyCode']?.toString() ??
          'SIN MONEDA',
      devengadoMes:
          json['devengado_mes']?.toString() ??
          json['total_devengado']?.toString() ??
          json['totalDevengado']?.toString() ??
          '0.00',
      pagadoMes:
          json['pagado_mes']?.toString() ??
          json['total_pagado']?.toString() ??
          json['totalPagado']?.toString() ??
          '0.00',
      pagadoAcumulado:
          json['pagado_acumulado']?.toString() ??
          json['total_pagado']?.toString() ??
          json['totalPagado']?.toString() ??
          '0.00',
      pagoAnticipado: json['pago_anticipado']?.toString() ?? '0.00',
      pagoAtrasado: json['pago_atrasado']?.toString() ?? '0.00',
      pendientePago:
          json['pendiente_pago']?.toString() ??
          json['total_pendiente']?.toString() ??
          json['totalPendiente']?.toString() ??
          '0.00',
      gastos: rawExpenses
          .whereType<Map>()
          .map(
            (expense) => GastoGobernadoModel.fromJson(
              Map<String, dynamic>.from(expense),
            ),
          )
          .toList(growable: false),
    );
  }
}

class GovernedExpensesReportModel {
  final String mes;
  final String fechaNegocio;
  final List<GovernedExpenseCurrencyModel> monedas;
  final Map<String, String> resumenPorCategoria;
  final Map<String, String> resumenPorNaturaleza;

  GovernedExpensesReportModel({
    required this.mes,
    required this.fechaNegocio,
    required this.monedas,
    this.resumenPorCategoria = const {},
    this.resumenPorNaturaleza = const {},
  });

  List<GastoGobernadoModel> get gastos =>
      monedas.expand((currency) => currency.gastos).toList(growable: false);

  factory GovernedExpensesReportModel.fromJson(Map<String, dynamic> json) {
    final rawCurrencies = json['monedas'] as List<dynamic>? ?? const [];
    final currencies = rawCurrencies
        .whereType<Map>()
        .map(
          (currency) => GovernedExpenseCurrencyModel.fromJson(
            Map<String, dynamic>.from(currency),
          ),
        )
        .toList();

    // Compatibilidad con respuestas antiguas de una sola moneda. El bloque se
    // conserva como una moneda explícita; nunca se combina con otra.
    if (currencies.isEmpty &&
        (json['gastos'] is List ||
            json['expenses'] is List ||
            json['total_devengado'] != null ||
            json['totalDevengado'] != null)) {
      currencies.add(GovernedExpenseCurrencyModel.fromJson(json));
    }

    final rawCatSummary =
        json['resumen_por_categoria'] as Map<String, dynamic>? ??
        json['categorySummary'] as Map<String, dynamic>? ??
        {};
    final rawNatSummary =
        json['resumen_por_naturaleza'] as Map<String, dynamic>? ??
        json['natureSummary'] as Map<String, dynamic>? ??
        {};

    return GovernedExpensesReportModel(
      mes: json['mes']?.toString() ?? json['month']?.toString() ?? '',
      fechaNegocio:
          json['fecha_corte']?.toString() ??
          json['fecha_negocio']?.toString() ??
          json['businessDate']?.toString() ??
          '',
      monedas: currencies,
      resumenPorCategoria: rawCatSummary.map(
        (k, v) => MapEntry(k, v.toString()),
      ),
      resumenPorNaturaleza: rawNatSummary.map(
        (k, v) => MapEntry(k, v.toString()),
      ),
    );
  }
}
