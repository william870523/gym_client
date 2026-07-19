double _money(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}

DateTime _utcDate(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) throw const FormatException('Fecha de baja inválida.');
  return parsed.toUtc();
}

class TrainerOffboardingMembershipImpact {
  final String membershipId;
  final String? assignmentId;
  final String clientId;
  final String clientName;
  final String planName;
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final String assignmentOrigin;
  final String recommendation;

  const TrainerOffboardingMembershipImpact({
    required this.membershipId,
    required this.assignmentId,
    required this.clientId,
    required this.clientName,
    required this.planName,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.assignmentOrigin,
    required this.recommendation,
  });

  factory TrainerOffboardingMembershipImpact.fromJson(
    Map<String, dynamic> json,
  ) {
    return TrainerOffboardingMembershipImpact(
      membershipId: json['membresia_id'] as String? ?? '',
      assignmentId: json['asignacion_id'] as String?,
      clientId: json['ci'] as String? ?? '',
      clientName: json['socio_nombre'] as String? ?? '',
      planName: json['plan_nombre'] as String? ?? '',
      status: json['estado'] as String? ?? '',
      startDate: _utcDate(json['fecha_inicio']),
      endDate: _utcDate(json['fecha_fin']),
      assignmentOrigin: json['origen_asignacion'] as String? ?? '',
      recommendation: json['recomendacion'] as String? ?? 'REASIGNAR',
    );
  }
}

class TrainerOffboardingFinanceImpact {
  final String currencyCode;
  final double earnedCommission;
  final double paidCommission;
  final double pendingCommission;
  final double futureCommission;
  final double earnedFixed;
  final double paidFixed;
  final double pendingFixed;

  const TrainerOffboardingFinanceImpact({
    required this.currencyCode,
    required this.earnedCommission,
    required this.paidCommission,
    required this.pendingCommission,
    required this.futureCommission,
    required this.earnedFixed,
    required this.paidFixed,
    required this.pendingFixed,
  });

  factory TrainerOffboardingFinanceImpact.fromJson(Map<String, dynamic> json) {
    return TrainerOffboardingFinanceImpact(
      currencyCode: json['moneda_codigo'] as String? ?? '',
      earnedCommission: _money(json['comision_ganada']),
      paidCommission: _money(json['comision_pagada']),
      pendingCommission: _money(json['comision_pendiente']),
      futureCommission: _money(json['comision_futura']),
      earnedFixed: _money(json['fijo_ganado']),
      paidFixed: _money(json['fijo_pagado']),
      pendingFixed: _money(json['fijo_pendiente']),
    );
  }
}

class TrainerOffboardingImpact {
  final String trainerName;
  final String trainerId;
  final String businessDate;
  final List<TrainerOffboardingMembershipImpact> memberships;
  final List<TrainerOffboardingFinanceImpact> finances;
  final int activeProfiles;
  final List<String> blockers;
  final bool canDeleteDirectly;

  const TrainerOffboardingImpact({
    required this.trainerName,
    required this.trainerId,
    required this.businessDate,
    required this.memberships,
    required this.finances,
    required this.activeProfiles,
    required this.blockers,
    required this.canDeleteDirectly,
  });

  factory TrainerOffboardingImpact.fromJson(Map<String, dynamic> json) {
    final trainer = json['entrenador'] is Map
        ? Map<String, dynamic>.from(json['entrenador'] as Map)
        : const <String, dynamic>{};
    return TrainerOffboardingImpact(
      trainerName: trainer['nombre'] as String? ?? '',
      trainerId: trainer['id_entrenador'] as String? ?? '',
      businessDate: json['business_date'] as String? ?? '',
      memberships: (json['membresias'] as List? ?? const [])
          .map(
            (item) => TrainerOffboardingMembershipImpact.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      finances: (json['finanzas_por_moneda'] as List? ?? const [])
          .map(
            (item) => TrainerOffboardingFinanceImpact.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      activeProfiles: (json['perfiles_vigentes'] as num?)?.toInt() ?? 0,
      blockers: (json['bloqueos'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      canDeleteDirectly:
          json['puede_baja_directa'] == true || json['puede_baja_directa'] == 1,
    );
  }
}
