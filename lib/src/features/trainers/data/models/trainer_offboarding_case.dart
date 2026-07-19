import 'dart:convert';

import 'trainer_offboarding_impact.dart';

DateTime _caseDate(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw const FormatException('Fecha de expediente inválida.');
  }
  return parsed.toUtc();
}

class TrainerOffboardingDecision {
  final String id;
  final String membershipId;
  final String clientId;
  final String clientName;
  final String planName;
  final String membershipStatus;
  final DateTime startDate;
  final DateTime endDate;
  final String type;
  final String? targetTrainerId;
  final String? targetTrainerName;
  final String? reason;
  final String executionState;
  final String? destinationAssignmentId;
  final DateTime? executedAt;
  final Map<String, dynamic>? executionResult;
  final Map<String, dynamic>? financialResolution;

  const TrainerOffboardingDecision({
    required this.id,
    required this.membershipId,
    required this.clientId,
    required this.clientName,
    required this.planName,
    required this.membershipStatus,
    required this.startDate,
    required this.endDate,
    required this.type,
    required this.targetTrainerId,
    required this.targetTrainerName,
    required this.reason,
    this.executionState = 'PENDIENTE',
    this.destinationAssignmentId,
    this.executedAt,
    this.executionResult,
    this.financialResolution,
  });

  factory TrainerOffboardingDecision.fromJson(Map<String, dynamic> json) {
    return TrainerOffboardingDecision(
      id: json['decision_id'] as String? ?? '',
      membershipId: json['membresia_id'] as String? ?? '',
      clientId: json['socio_ci_snapshot'] as String? ?? '',
      clientName: json['socio_nombre_snapshot'] as String? ?? '',
      planName: json['plan_nombre_snapshot'] as String? ?? '',
      membershipStatus: json['membresia_estado_snapshot'] as String? ?? '',
      startDate: _caseDate(json['membresia_fecha_inicio_snapshot']),
      endDate: _caseDate(json['membresia_fecha_fin_snapshot']),
      type: json['tipo'] as String? ?? 'PENDIENTE',
      targetTrainerId: json['id_entrenador_destino'] as String?,
      targetTrainerName: json['entrenador_destino_nombre'] as String?,
      reason: json['motivo'] as String?,
      executionState: json['estado_ejecucion'] as String? ?? 'PENDIENTE',
      destinationAssignmentId: json['asignacion_destino_id'] as String?,
      executedAt: json['ejecutada_at'] == null
          ? null
          : _caseDate(json['ejecutada_at']),
      executionResult: _jsonObject(
        json['ejecucion_resultado'] ?? json['ejecucion_resultado_json'],
      ),
      financialResolution: _jsonObject(json['resolucion_financiera']),
    );
  }

  String? get financialResolutionState =>
      financialResolution?['estado']?.toString();

  bool get awaitingTreasury =>
      type == 'AJUSTAR_CANCELAR' &&
      financialResolutionState == 'PENDIENTE_TESORERIA';
}

class TrainerOffboardingCase {
  final String id;
  final String trainerId;
  final DateTime effectiveDate;
  final String status;
  final String reason;
  final int totalDecisions;
  final int pendingDecisions;
  final String createdBy;
  final DateTime createdAt;
  final TrainerOffboardingImpact impact;
  final List<TrainerOffboardingDecision> decisions;
  final String? executionOperationId;
  final String? executedBy;
  final DateTime? executedAt;
  final Map<String, dynamic>? executionSummary;
  final String? closingOperationId;
  final String? closedBy;
  final DateTime? closedAt;
  final Map<String, dynamic>? closingSummary;

  const TrainerOffboardingCase({
    required this.id,
    required this.trainerId,
    required this.effectiveDate,
    required this.status,
    required this.reason,
    required this.totalDecisions,
    required this.pendingDecisions,
    required this.createdBy,
    required this.createdAt,
    required this.impact,
    required this.decisions,
    this.executionOperationId,
    this.executedBy,
    this.executedAt,
    this.executionSummary,
    this.closingOperationId,
    this.closedBy,
    this.closedAt,
    this.closingSummary,
  });

  bool get membershipsReady => pendingDecisions == 0;
  bool get hasFinancialReview => decisions.any(
    (decision) =>
        decision.type == 'AJUSTAR_CANCELAR' &&
        decision.executionState != 'APLICADA',
  );
  bool get canApplyAssignments =>
      status == 'LISTO_PARA_REVISION' &&
      membershipsReady &&
      !hasFinancialReview;
  bool get isClosed => status == 'EJECUTADO';

  factory TrainerOffboardingCase.fromJson(Map<String, dynamic> json) {
    final impactJson = json['impacto_snapshot'] is Map
        ? Map<String, dynamic>.from(json['impacto_snapshot'] as Map)
        : const <String, dynamic>{};
    return TrainerOffboardingCase(
      id: json['expediente_id'] as String? ?? '',
      trainerId: json['id_entrenador'] as String? ?? '',
      effectiveDate: _caseDate(json['fecha_efectiva']),
      status: json['estado'] as String? ?? 'BORRADOR',
      reason: json['motivo'] as String? ?? '',
      totalDecisions: (json['decisiones_total'] as num?)?.toInt() ?? 0,
      pendingDecisions: (json['decisiones_pendientes'] as num?)?.toInt() ?? 0,
      createdBy: json['creado_por_nombre_snapshot'] as String? ?? '',
      createdAt: _caseDate(json['creado_at']),
      impact: TrainerOffboardingImpact.fromJson(impactJson),
      decisions: (json['decisiones'] as List? ?? const [])
          .map(
            (item) => TrainerOffboardingDecision.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      executionOperationId: json['ejecucion_operacion_id'] as String?,
      executedBy: json['ejecutado_por_nombre_snapshot'] as String?,
      executedAt: json['ejecutado_at'] == null
          ? null
          : _caseDate(json['ejecutado_at']),
      executionSummary: _jsonObject(
        json['ejecucion_resumen'] ?? json['ejecucion_resumen_json'],
      ),
      closingOperationId: json['cierre_operacion_id'] as String?,
      closedBy: json['cerrado_por_nombre_snapshot'] as String?,
      closedAt: json['cerrado_at'] == null
          ? null
          : _caseDate(json['cerrado_at']),
      closingSummary: _jsonObject(
        json['cierre_resumen'] ?? json['cierre_resumen_json'],
      ),
    );
  }
}

Map<String, dynamic>? _jsonObject(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is! String || value.trim().isEmpty) return null;
  final decoded = jsonDecode(value);
  return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
}
