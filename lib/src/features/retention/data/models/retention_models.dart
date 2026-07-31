class RetentionDashboardModel {
  const RetentionDashboardModel({
    required this.generatedAtUtc,
    required this.gymId,
    required this.timezone,
    required this.businessDate,
    required this.window,
    required this.policy,
    required this.metrics,
    required this.quality,
    required this.dimensions,
    required this.cohorts,
    required this.breakdowns,
    required this.items,
  });

  factory RetentionDashboardModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    return RetentionDashboardModel(
      generatedAtUtc: DateTime.parse(
        json['generated_at_utc'].toString(),
      ).toUtc(),
      gymId: json['gym_id']?.toString() ?? '',
      timezone: json['timezone']?.toString() ?? 'Etc/UTC',
      businessDate: json['business_date']?.toString() ?? '',
      window: RetentionWindow.fromJson(_map(json['window'])),
      policy: RetentionPolicyModel.fromJson(_map(json['policy'])),
      metrics: RetentionMetricsModel.fromJson(_map(json['metrics'])),
      quality: RetentionQualityModel.fromJson(_map(json['quality'])),
      dimensions: RetentionDimensionsModel.fromJson(_map(json['dimensions'])),
      cohorts: (json['cohorts'] as List? ?? const [])
          .map((item) => RetentionCohortModel.fromJson(_map(item)))
          .toList(growable: false),
      breakdowns: RetentionBreakdownsModel.fromJson(_map(json['breakdowns'])),
      items: rawItems
          .map((item) => RetentionItemModel.fromJson(_map(item)))
          .toList(growable: false),
    );
  }

  final DateTime generatedAtUtc;
  final String gymId;
  final String timezone;
  final String businessDate;
  final RetentionWindow window;
  final RetentionPolicyModel policy;
  final RetentionMetricsModel metrics;
  final RetentionQualityModel quality;
  final RetentionDimensionsModel dimensions;
  final List<RetentionCohortModel> cohorts;
  final RetentionBreakdownsModel breakdowns;
  final List<RetentionItemModel> items;
}

class RetentionDashboardQuery {
  const RetentionDashboardQuery({
    this.from,
    this.to,
    this.planId,
    this.trainerId,
  });

  final String? from;
  final String? to;
  final String? planId;
  final String? trainerId;

  Map<String, dynamic> toQueryParameters() => {
    if (from != null) 'desde': from,
    if (to != null) 'hasta': to,
    if (planId != null) 'plan_id': planId,
    if (trainerId != null) 'entrenador_id': trainerId,
  };

  RetentionDashboardQuery copyWith({
    String? from,
    String? to,
    String? planId,
    String? trainerId,
    bool clearPlan = false,
    bool clearTrainer = false,
  }) => RetentionDashboardQuery(
    from: from ?? this.from,
    to: to ?? this.to,
    planId: clearPlan ? null : planId ?? this.planId,
    trainerId: clearTrainer ? null : trainerId ?? this.trainerId,
  );
}

class RetentionSettingsModel {
  const RetentionSettingsModel({
    required this.gymId,
    required this.graceDays,
    required this.horizonDays,
    required this.exitBeginsDay,
    required this.graceSource,
    required this.horizonSource,
    required this.graceMin,
    required this.graceMax,
    required this.horizonMin,
    required this.horizonMax,
    required this.changedKeys,
    required this.updatedAtUtc,
  });

  factory RetentionSettingsModel.fromJson(Map<String, dynamic> json) {
    final sources = _map(json['sources']);
    final limits = _map(json['limits']);
    final graceLimits = _map(limits['grace']);
    final horizonLimits = _map(limits['horizon']);
    return RetentionSettingsModel(
      gymId: json['gym_id']?.toString() ?? '',
      graceDays: _integer(json['grace_days']),
      horizonDays: _integer(json['horizon_days']),
      exitBeginsDay: _integer(json['exit_begins_day']),
      graceSource: sources['grace']?.toString() ?? 'DEFAULT',
      horizonSource: sources['horizon']?.toString() ?? 'DEFAULT',
      graceMin: _integer(graceLimits['min']),
      graceMax: _integer(graceLimits['max']),
      horizonMin: _integer(horizonLimits['min']),
      horizonMax: _integer(horizonLimits['max']),
      changedKeys: (json['changed_keys'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      updatedAtUtc: _utc(json['updated_at_utc']),
    );
  }

  final String gymId;
  final int graceDays;
  final int horizonDays;
  final int exitBeginsDay;
  final String graceSource;
  final String horizonSource;
  final int graceMin;
  final int graceMax;
  final int horizonMin;
  final int horizonMax;
  final List<String> changedKeys;
  final DateTime? updatedAtUtc;
}

class RetentionWindow {
  const RetentionWindow({required this.from, required this.to});

  factory RetentionWindow.fromJson(Map<String, dynamic> json) =>
      RetentionWindow(
        from: json['from']?.toString() ?? '',
        to: json['to']?.toString() ?? '',
      );

  final String from;
  final String to;
}

class RetentionDimensionsModel {
  const RetentionDimensionsModel({required this.plans, required this.trainers});

  factory RetentionDimensionsModel.fromJson(Map<String, dynamic> json) =>
      RetentionDimensionsModel(
        plans: (json['plans'] as List? ?? const [])
            .map((item) => RetentionDimensionOption.fromJson(_map(item)))
            .toList(growable: false),
        trainers: (json['trainers'] as List? ?? const [])
            .map((item) => RetentionDimensionOption.fromJson(_map(item)))
            .toList(growable: false),
      );

  final List<RetentionDimensionOption> plans;
  final List<RetentionDimensionOption> trainers;
}

class RetentionDimensionOption {
  const RetentionDimensionOption({
    required this.id,
    required this.name,
    required this.count,
  });

  factory RetentionDimensionOption.fromJson(Map<String, dynamic> json) =>
      RetentionDimensionOption(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        count: _integer(json['count']),
      );

  final String id;
  final String name;
  final int count;
}

class RetentionCohortModel {
  const RetentionCohortModel({
    required this.month,
    required this.totalDue,
    required this.matureEligible,
    required this.retained,
    required this.historicalExits,
    required this.recovered,
    required this.retentionRatePct,
    required this.recoveryRatePct,
    required this.retentionChangePp,
    required this.provisional,
  });

  factory RetentionCohortModel.fromJson(Map<String, dynamic> json) =>
      RetentionCohortModel(
        month: json['month']?.toString() ?? '',
        totalDue: _integer(json['total_due']),
        matureEligible: _integer(json['mature_eligible']),
        retained: _integer(json['retained']),
        historicalExits: _integer(json['historical_exits']),
        recovered: _integer(json['recovered']),
        retentionRatePct: _decimal(json['retention_rate_pct']),
        recoveryRatePct: _decimal(json['recovery_rate_pct']),
        retentionChangePp: _decimal(json['retention_change_pp']),
        provisional: json['provisional'] == true,
      );

  final String month;
  final int totalDue;
  final int matureEligible;
  final int retained;
  final int historicalExits;
  final int recovered;
  final double? retentionRatePct;
  final double? recoveryRatePct;
  final double? retentionChangePp;
  final bool provisional;
}

class RetentionBreakdownsModel {
  const RetentionBreakdownsModel({
    required this.plans,
    required this.trainers,
    required this.unattributedTrainerTotal,
  });

  factory RetentionBreakdownsModel.fromJson(Map<String, dynamic> json) =>
      RetentionBreakdownsModel(
        plans: (json['plans'] as List? ?? const [])
            .map((item) => RetentionBreakdownRowModel.fromJson(_map(item)))
            .toList(growable: false),
        trainers: (json['trainers'] as List? ?? const [])
            .map((item) => RetentionBreakdownRowModel.fromJson(_map(item)))
            .toList(growable: false),
        unattributedTrainerTotal: _integer(json['unattributed_trainer_total']),
      );

  final List<RetentionBreakdownRowModel> plans;
  final List<RetentionBreakdownRowModel> trainers;
  final int unattributedTrainerTotal;
}

class RetentionBreakdownRowModel {
  const RetentionBreakdownRowModel({
    required this.id,
    required this.name,
    required this.totalDue,
    required this.matureEligible,
    required this.openCases,
    required this.retained,
    required this.renewedOnTime,
    required this.renewedInGrace,
    required this.historicalExits,
    required this.recovered,
    required this.retentionRatePct,
    required this.recoveryRatePct,
  });

  factory RetentionBreakdownRowModel.fromJson(Map<String, dynamic> json) =>
      RetentionBreakdownRowModel(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        totalDue: _integer(json['total_due']),
        matureEligible: _integer(json['mature_eligible']),
        openCases: _integer(json['open_cases']),
        retained: _integer(json['retained']),
        renewedOnTime: _integer(json['renewed_on_time']),
        renewedInGrace: _integer(json['renewed_in_grace']),
        historicalExits: _integer(json['historical_exits']),
        recovered: _integer(json['recovered']),
        retentionRatePct: _decimal(json['retention_rate_pct']),
        recoveryRatePct: _decimal(json['recovery_rate_pct']),
      );

  final String id;
  final String name;
  final int totalDue;
  final int matureEligible;
  final int openCases;
  final int retained;
  final int renewedOnTime;
  final int renewedInGrace;
  final int historicalExits;
  final int recovered;
  final double? retentionRatePct;
  final double? recoveryRatePct;
}

class RetentionPolicyModel {
  const RetentionPolicyModel({
    required this.graceDays,
    required this.horizonDays,
    required this.matureCohortCutoff,
    required this.provisional,
  });

  factory RetentionPolicyModel.fromJson(Map<String, dynamic> json) =>
      RetentionPolicyModel(
        graceDays: _integer(json['grace_days']),
        horizonDays: _integer(json['horizon_days']),
        matureCohortCutoff: json['mature_cohort_cutoff']?.toString() ?? '',
        provisional: json['provisional'] == true,
      );

  final int graceDays;
  final int horizonDays;
  final String matureCohortCutoff;
  final bool provisional;
}

class RetentionMetricsModel {
  const RetentionMetricsModel({
    required this.totalVisible,
    required this.byState,
    required this.matureEligible,
    required this.retained,
    required this.retentionRatePct,
    required this.historicalExits,
    required this.recovered,
    required this.recoveryRatePct,
    required this.pendingManagement,
    required this.promisedPayments,
    required this.dueFollowups,
  });

  factory RetentionMetricsModel.fromJson(Map<String, dynamic> json) {
    final states = _map(json['by_state']);
    final management = _map(json['management']);
    return RetentionMetricsModel(
      totalVisible: _integer(json['total_visible']),
      byState: states.map((key, value) => MapEntry(key, _integer(value))),
      matureEligible: _integer(json['mature_eligible']),
      retained: _integer(json['retained']),
      retentionRatePct: _decimal(json['retention_rate_pct']),
      historicalExits: _integer(json['historical_exits']),
      recovered: _integer(json['recovered']),
      recoveryRatePct: _decimal(json['recovery_rate_pct']),
      pendingManagement: _integer(management['pending']),
      promisedPayments: _integer(management['promised']),
      dueFollowups: _integer(management['due_followups']),
    );
  }

  final int totalVisible;
  final Map<String, int> byState;
  final int matureEligible;
  final int retained;
  final double? retentionRatePct;
  final int historicalExits;
  final int recovered;
  final double? recoveryRatePct;
  final int pendingManagement;
  final int promisedPayments;
  final int dueFollowups;

  int count(String state) => byState[state] ?? 0;
}

class RetentionQualityModel {
  const RetentionQualityModel({
    required this.missingActivationEvidence,
    required this.caveats,
  });

  factory RetentionQualityModel.fromJson(Map<String, dynamic> json) =>
      RetentionQualityModel(
        missingActivationEvidence: _integer(
          json['missing_activation_evidence'],
        ),
        caveats: (json['caveats'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
      );

  final int missingActivationEvidence;
  final List<String> caveats;
}

class RetentionItemModel {
  const RetentionItemModel({
    required this.membershipId,
    required this.clientId,
    required this.clientName,
    required this.phone,
    required this.email,
    required this.plan,
    required this.trainer,
    required this.expectedRenewalDate,
    required this.graceEndDate,
    required this.exitDate,
    required this.state,
    required this.reason,
    required this.daysFromDue,
    required this.historicalExit,
    required this.renewal,
    required this.lastPaymentAtUtc,
    required this.lastAttendanceAtUtc,
    required this.management,
    required this.reconstructed,
  });

  factory RetentionItemModel.fromJson(Map<String, dynamic> json) =>
      RetentionItemModel(
        membershipId: json['membership_id']?.toString() ?? '',
        clientId: json['ci']?.toString() ?? '',
        clientName: json['client_name']?.toString() ?? '',
        phone: _nullableText(json['phone']),
        email: _nullableText(json['email']),
        plan: RetentionPlanModel.fromJson(_map(json['plan'])),
        trainer: json['trainer'] == null
            ? null
            : RetentionTrainerModel.fromJson(_map(json['trainer'])),
        expectedRenewalDate: json['expected_renewal_date']?.toString() ?? '',
        graceEndDate: json['grace_end_date']?.toString() ?? '',
        exitDate: json['exit_date']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
        reason: json['reason']?.toString() ?? '',
        daysFromDue: _integer(json['days_from_due']),
        historicalExit: json['historical_exit'] == true,
        renewal: json['renewal'] == null
            ? null
            : RetentionRenewalModel.fromJson(_map(json['renewal'])),
        lastPaymentAtUtc: _utc(json['last_payment_at_utc']),
        lastAttendanceAtUtc: _utc(json['last_attendance_at_utc']),
        management: RetentionManagementSummary.fromJson(
          _map(json['management']),
        ),
        reconstructed: json['reconstructed'] == true,
      );

  final String membershipId;
  final String clientId;
  final String clientName;
  final String? phone;
  final String? email;
  final RetentionPlanModel plan;
  final RetentionTrainerModel? trainer;
  final String expectedRenewalDate;
  final String graceEndDate;
  final String exitDate;
  final String state;
  final String reason;
  final int daysFromDue;
  final bool historicalExit;
  final RetentionRenewalModel? renewal;
  final DateTime? lastPaymentAtUtc;
  final DateTime? lastAttendanceAtUtc;
  final RetentionManagementSummary management;
  final bool reconstructed;
}

class RetentionManagementSummary {
  const RetentionManagementSummary({
    required this.status,
    required this.channel,
    required this.note,
    required this.promiseDate,
    required this.nextManagementDate,
    required this.registeredAtUtc,
    required this.registeredBy,
    required this.historyCount,
    required this.overdue,
  });

  factory RetentionManagementSummary.fromJson(Map<String, dynamic> json) =>
      RetentionManagementSummary(
        status: json['status']?.toString() ?? 'PENDIENTE',
        channel: _nullableText(json['channel']),
        note: _nullableText(json['note']),
        promiseDate: _nullableText(json['promise_date']),
        nextManagementDate: _nullableText(json['next_management_date']),
        registeredAtUtc: _utc(json['registered_at_utc']),
        registeredBy: _nullableText(json['registered_by']),
        historyCount: _integer(json['history_count']),
        overdue: json['overdue'] == true,
      );

  final String status;
  final String? channel;
  final String? note;
  final String? promiseDate;
  final String? nextManagementDate;
  final DateTime? registeredAtUtc;
  final String? registeredBy;
  final int historyCount;
  final bool overdue;
}

class RetentionManagementRecord {
  const RetentionManagementRecord({
    required this.id,
    required this.membershipId,
    required this.clientId,
    required this.result,
    required this.channel,
    required this.reasonId,
    required this.reasonName,
    required this.note,
    required this.promiseDate,
    required this.nextManagementDate,
    required this.registeredBy,
    required this.registeredAtUtc,
  });

  factory RetentionManagementRecord.fromJson(Map<String, dynamic> json) =>
      RetentionManagementRecord(
        id: json['management_id']?.toString() ?? '',
        membershipId: json['membership_id']?.toString() ?? '',
        clientId: json['ci']?.toString() ?? '',
        result: json['result']?.toString() ?? '',
        channel: json['channel']?.toString() ?? '',
        reasonId: _nullableText(json['reason_id']),
        // Nombre congelado al registrar: renombrar el motivo después no
        // reescribe lo que decía esta gestión (PLAN_ESTADISTICAS.md §7-ter).
        reasonName: _nullableText(json['reason_name']),
        note: _nullableText(json['note']),
        promiseDate: _nullableText(json['promise_date']),
        nextManagementDate: _nullableText(json['next_management_date']),
        registeredBy: json['registered_by']?.toString() ?? '',
        registeredAtUtc: DateTime.parse(
          json['registered_at_utc'].toString(),
        ).toUtc(),
      );

  final String id;
  final String membershipId;
  final String clientId;
  final String result;
  final String channel;
  final String? reasonId;
  final String? reasonName;
  final String? note;
  final String? promiseDate;
  final String? nextManagementDate;
  final String registeredBy;
  final DateTime registeredAtUtc;
}

/// Motivo de baja del catálogo administrable (`motivo_baja`).
///
/// `gestiones` es el uso real: decide si el motivo se puede borrar y alimenta
/// la métrica de la vista de catálogo. `esSistema` marca los diez sembrados por
/// la migración, que se desactivan pero no se borran.
class DropoutReasonModel {
  const DropoutReasonModel({
    required this.id,
    required this.name,
    required this.code,
    required this.order,
    required this.active,
    required this.isSystem,
    required this.managements,
  });

  factory DropoutReasonModel.fromJson(Map<String, dynamic> json) =>
      DropoutReasonModel(
        id: json['motivo_baja_id']?.toString() ?? '',
        name: json['nombre']?.toString() ?? '',
        code: _nullableText(json['codigo']),
        order: int.tryParse(json['orden']?.toString() ?? '') ?? 0,
        active: json['activo'] == true,
        isSystem: json['es_sistema'] == true,
        managements: int.tryParse(json['gestiones']?.toString() ?? '') ?? 0,
      );

  final String id;
  final String name;
  final String? code;
  final int order;
  final bool active;
  final bool isSystem;
  final int managements;

  /// Un motivo solo se puede borrar si nadie lo usó y no es de sistema.
  bool get canDelete => !isSystem && managements == 0;
}

class RetentionPlanModel {
  const RetentionPlanModel({
    required this.id,
    required this.name,
    required this.price,
    required this.currencyId,
  });

  factory RetentionPlanModel.fromJson(Map<String, dynamic> json) =>
      RetentionPlanModel(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Plan sin nombre',
        price: _decimal(json['price']) ?? 0,
        currencyId: json['currency_id']?.toString() ?? '',
      );

  final String id;
  final String name;
  final double price;
  final String currencyId;
}

class RetentionTrainerModel {
  const RetentionTrainerModel({required this.id, required this.name});

  factory RetentionTrainerModel.fromJson(Map<String, dynamic> json) =>
      RetentionTrainerModel(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Entrenador no disponible',
      );

  final String id;
  final String name;
}

class RetentionRenewalModel {
  const RetentionRenewalModel({
    required this.membershipId,
    required this.effectiveDate,
    required this.delayDays,
    required this.evidence,
  });

  factory RetentionRenewalModel.fromJson(Map<String, dynamic> json) =>
      RetentionRenewalModel(
        membershipId: json['membership_id']?.toString() ?? '',
        effectiveDate: json['effective_date']?.toString() ?? '',
        delayDays: _integer(json['delay_days']),
        evidence: json['evidence']?.toString() ?? '',
      );

  final String membershipId;
  final String effectiveDate;
  final int delayDays;
  final String evidence;
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

int _integer(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
double? _decimal(dynamic value) => value == null
    ? null
    : value is num
    ? value.toDouble()
    : double.tryParse(value.toString());
DateTime? _utc(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toUtc();
String? _nullableText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
