class OperationalResultsModel {
  const OperationalResultsModel({
    required this.month,
    required this.periodState,
    required this.nature,
    required this.certified,
    required this.monthlyClose,
    required this.certificationNote,
    required this.currencies,
    required this.limitations,
  });

  factory OperationalResultsModel.fromJson(Map<String, dynamic> json) {
    return OperationalResultsModel(
      month: _string(json['mes']),
      periodState: _string(json['estado_periodo'], fallback: 'PROVISIONAL'),
      nature: _string(json['naturaleza']),
      certified: json['certificado'] == true,
      monthlyClose: json['cierre_tesoreria'] is Map
          ? OperationalMonthlyCloseModel.fromJson(
              Map<String, dynamic>.from(json['cierre_tesoreria'] as Map),
            )
          : null,
      certificationNote: _string(json['nota_certificacion']),
      currencies: _maps(
        json['monedas'],
      ).map(OperationalResultsCurrencyModel.fromJson).toList(growable: false),
      limitations: (json['limitaciones'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }

  final String month;
  final String periodState;
  final String nature;
  final bool certified;
  final OperationalMonthlyCloseModel? monthlyClose;
  final String certificationNote;
  final List<OperationalResultsCurrencyModel> currencies;
  final List<String> limitations;
}

class OperationalMonthlyCloseModel {
  const OperationalMonthlyCloseModel({
    required this.id,
    required this.state,
    required this.sha256,
    required this.closedAt,
    required this.reopenedAt,
    this.integrityVerified = false,
    this.snapshotVersion = 0,
    this.signerName,
    this.signerRole,
    this.reason,
    this.timezone,
    this.generatedAtUtc,
  });

  factory OperationalMonthlyCloseModel.fromJson(Map<String, dynamic> json) {
    return OperationalMonthlyCloseModel(
      id: _string(json['cierre_mensual_id']),
      state: _string(json['estado']),
      sha256: _string(json['resumen_sha256']),
      closedAt: DateTime.tryParse(_string(json['cerrado_at']))?.toUtc(),
      reopenedAt: DateTime.tryParse(_string(json['reabierto_at']))?.toUtc(),
      integrityVerified: json['integridad_verificada'] == true,
      snapshotVersion: _integer(json['snapshot_version']),
      signerName: _nullableString(json['firmado_por_nombre']),
      signerRole: _nullableString(json['firmado_por_rol']),
      reason: _nullableString(json['motivo']),
      timezone: _nullableString(json['timezone']),
      generatedAtUtc: DateTime.tryParse(
        _string(json['generado_at_utc']),
      )?.toUtc(),
    );
  }

  final String id;
  final String state;
  final String sha256;
  final DateTime? closedAt;
  final DateTime? reopenedAt;
  final bool integrityVerified;
  final int snapshotVersion;
  final String? signerName;
  final String? signerRole;
  final String? reason;
  final String? timezone;
  final DateTime? generatedAtUtc;
}

class OperationalResultsCurrencyModel {
  const OperationalResultsCurrencyModel({
    required this.currencyId,
    required this.currencyCode,
    required this.cash,
    required this.obligations,
    required this.concepts,
    required this.accounts,
    required this.quality,
  });

  factory OperationalResultsCurrencyModel.fromJson(Map<String, dynamic> json) {
    return OperationalResultsCurrencyModel(
      currencyId: _string(json['moneda_id']),
      currencyCode: _string(json['moneda_codigo'], fallback: '—'),
      cash: OperationalCashModel.fromJson(_map(json['caja'])),
      obligations: OperationalObligationsModel.fromJson(
        _map(json['obligaciones']),
      ),
      concepts: _maps(
        json['conceptos'],
      ).map(OperationalConceptResultModel.fromJson).toList(growable: false),
      accounts: _maps(
        json['cuentas'],
      ).map(OperationalAccountResultModel.fromJson).toList(growable: false),
      quality: OperationalQualityModel.fromJson(_map(json['calidad'])),
    );
  }

  final String currencyId;
  final String currencyCode;
  final OperationalCashModel cash;
  final OperationalObligationsModel obligations;
  final List<OperationalConceptResultModel> concepts;
  final List<OperationalAccountResultModel> accounts;
  final OperationalQualityModel quality;

  bool get requiresAttention =>
      quality.pendingClassification > 0 ||
      quality.sourceReviews > 0 ||
      quality.movementsWithoutAccount > 0 ||
      obligations.reviewCount > 0;
}

class OperationalCashModel {
  const OperationalCashModel({
    required this.grossCollections,
    required this.changeGivenNet,
    required this.reversalsNet,
    required this.trainerPaymentsNet,
    required this.refundsNet,
    required this.otherOperationalExits,
    required this.operationalFlow,
    required this.nonOperationalFlow,
    required this.pendingClassificationFlow,
    required this.ledgerEntries,
    required this.ledgerExits,
    required this.ledgerNet,
  });

  factory OperationalCashModel.fromJson(Map<String, dynamic> json) {
    return OperationalCashModel(
      grossCollections: _money(json['cobros_brutos']),
      changeGivenNet: _money(json['cambio_entregado_neto']),
      reversalsNet: _money(json['anulaciones_netas']),
      trainerPaymentsNet: _money(json['pagos_entrenadores_netos']),
      refundsNet: _money(json['reembolsos_netos']),
      otherOperationalExits: _money(json['otros_egresos_operativos']),
      operationalFlow: _money(json['flujo_operativo']),
      nonOperationalFlow: _money(json['flujo_no_operativo']),
      pendingClassificationFlow: _money(json['flujo_pendiente_clasificacion']),
      ledgerEntries: _money(json['entradas_libro']),
      ledgerExits: _money(json['salidas_libro']),
      ledgerNet: _money(json['neto_libro']),
    );
  }

  final String grossCollections;
  final String changeGivenNet;
  final String reversalsNet;
  final String trainerPaymentsNet;
  final String refundsNet;
  final String otherOperationalExits;
  final String operationalFlow;
  final String nonOperationalFlow;
  final String pendingClassificationFlow;
  final String ledgerEntries;
  final String ledgerExits;
  final String ledgerNet;
}

class OperationalObligationsModel {
  const OperationalObligationsModel({
    required this.available,
    required this.trainerEarnedPending,
    required this.trainerFuture,
    required this.refundsPending,
    required this.reason,
    this.cutoffDate,
    this.trainerPayableNow,
    this.immediateReserve,
    this.totalCommitment,
    this.pendingTrainerCount = 0,
    this.overdueInstallmentCount = 0,
    this.pendingRefundCount = 0,
    this.reviewCount = 0,
    this.trainers = const [],
    this.refunds = const [],
    this.futureCoverage = '',
  });

  factory OperationalObligationsModel.fromJson(Map<String, dynamic> json) {
    return OperationalObligationsModel(
      available: json['disponible'] == true,
      trainerEarnedPending: _nullableMoney(json['entrenador_ganado_pendiente']),
      trainerFuture: _nullableMoney(json['entrenador_futuro']),
      refundsPending: _nullableMoney(json['reembolsos_pendientes']),
      reason: _string(json['motivo']),
      cutoffDate: _nullableString(json['fecha_corte']),
      trainerPayableNow: _nullableMoney(json['entrenador_pagadero_ahora']),
      immediateReserve: _nullableMoney(json['reserva_inmediata']),
      totalCommitment: _nullableMoney(json['compromiso_total']),
      pendingTrainerCount: _integer(json['entrenadores_pendientes']),
      overdueInstallmentCount: _integer(json['cuotas_vencidas']),
      pendingRefundCount: _integer(json['reembolsos_cantidad']),
      reviewCount: _integer(json['revisiones_pendientes']),
      trainers: _maps(
        json['entrenadores'],
      ).map(OperationalTrainerObligationModel.fromJson).toList(growable: false),
      refunds: _maps(
        json['reembolsos'],
      ).map(OperationalPendingRefundModel.fromJson).toList(growable: false),
      futureCoverage: _string(json['cobertura_futuro']),
    );
  }

  final bool available;
  final String? trainerEarnedPending;
  final String? trainerFuture;
  final String? refundsPending;
  final String reason;
  final String? cutoffDate;
  final String? trainerPayableNow;
  final String? immediateReserve;
  final String? totalCommitment;
  final int pendingTrainerCount;
  final int overdueInstallmentCount;
  final int pendingRefundCount;
  final int reviewCount;
  final List<OperationalTrainerObligationModel> trainers;
  final List<OperationalPendingRefundModel> refunds;
  final String futureCoverage;
}

class OperationalTrainerObligationModel {
  const OperationalTrainerObligationModel({
    required this.trainerId,
    required this.trainerName,
    required this.earnedPending,
    required this.payableNow,
    required this.future,
    required this.conceptCount,
    required this.overdueConceptCount,
    required this.commissionConceptCount,
    required this.fixedConceptCount,
    required this.nextPaymentDate,
    required this.requiresReview,
  });

  factory OperationalTrainerObligationModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return OperationalTrainerObligationModel(
      trainerId: _string(json['entrenador_id']),
      trainerName: _string(json['entrenador_nombre'], fallback: 'Entrenador'),
      earnedPending: _money(json['ganado_pendiente']),
      payableNow: _money(json['pagadero_ahora']),
      future: _money(json['futuro']),
      conceptCount: _integer(json['conceptos']),
      overdueConceptCount: _integer(json['conceptos_vencidos']),
      commissionConceptCount: _integer(json['conceptos_comision']),
      fixedConceptCount: _integer(json['conceptos_fijos']),
      nextPaymentDate: _nullableString(json['proxima_fecha_pago']),
      requiresReview: json['requiere_revision'] == true,
    );
  }

  final String trainerId;
  final String trainerName;
  final String earnedPending;
  final String payableNow;
  final String future;
  final int conceptCount;
  final int overdueConceptCount;
  final int commissionConceptCount;
  final int fixedConceptCount;
  final String? nextPaymentDate;
  final bool requiresReview;
}

class OperationalPendingRefundModel {
  const OperationalPendingRefundModel({
    required this.adjustmentId,
    required this.clientId,
    required this.clientName,
    required this.amount,
    required this.requestedAt,
  });

  factory OperationalPendingRefundModel.fromJson(Map<String, dynamic> json) {
    return OperationalPendingRefundModel(
      adjustmentId: _string(json['ajuste_financiero_id']),
      clientId: _string(json['ci']),
      clientName: _string(json['cliente_nombre'], fallback: 'Cliente'),
      amount: _money(json['monto']),
      requestedAt: DateTime.tryParse(_string(json['solicitado_at']))?.toUtc(),
    );
  }

  final String adjustmentId;
  final String clientId;
  final String clientName;
  final String amount;
  final DateTime? requestedAt;
}

class OperationalConceptResultModel {
  const OperationalConceptResultModel({
    required this.category,
    required this.label,
    required this.scope,
    required this.entries,
    required this.exits,
    required this.cashEffect,
    required this.movementCount,
    required this.requiresReview,
  });

  factory OperationalConceptResultModel.fromJson(Map<String, dynamic> json) {
    return OperationalConceptResultModel(
      category: _string(json['categoria']),
      label: _string(json['etiqueta']),
      scope: _string(json['ambito']),
      entries: _money(json['entradas']),
      exits: _money(json['salidas']),
      cashEffect: _money(json['efecto_flujo']),
      movementCount: _integer(json['movimientos']),
      requiresReview: json['requiere_revision'] == true,
    );
  }

  final String category;
  final String label;
  final String scope;
  final String entries;
  final String exits;
  final String cashEffect;
  final int movementCount;
  final bool requiresReview;
}

class OperationalAccountResultModel {
  const OperationalAccountResultModel({
    required this.id,
    required this.name,
    required this.entries,
    required this.exits,
    required this.ledgerNet,
    required this.operationalFlow,
    required this.movementCount,
    required this.requiresReview,
  });

  factory OperationalAccountResultModel.fromJson(Map<String, dynamic> json) {
    return OperationalAccountResultModel(
      id: json['cuenta_id']?.toString(),
      name: _string(json['cuenta_nombre'], fallback: 'Sin cuenta'),
      entries: _money(json['entradas']),
      exits: _money(json['salidas']),
      ledgerNet: _money(json['neto_libro']),
      operationalFlow: _money(json['flujo_operativo']),
      movementCount: _integer(json['movimientos']),
      requiresReview: json['requiere_revision'] == true,
    );
  }

  final String? id;
  final String name;
  final String entries;
  final String exits;
  final String ledgerNet;
  final String operationalFlow;
  final int movementCount;
  final bool requiresReview;
}

class OperationalQualityModel {
  const OperationalQualityModel({
    required this.movementsWithoutAccount,
    required this.pendingClassification,
    required this.openBusinessDays,
    required this.sourceReviews,
  });

  factory OperationalQualityModel.fromJson(Map<String, dynamic> json) {
    return OperationalQualityModel(
      movementsWithoutAccount: _integer(json['movimientos_sin_cuenta']),
      pendingClassification: _integer(json['clasificacion_pendiente']),
      openBusinessDays: _integer(json['jornadas_por_cerrar']),
      sourceReviews: _integer(json['revisiones_pendientes']),
    );
  }

  final int movementsWithoutAccount;
  final int pendingClassification;
  final int openBusinessDays;
  final int sourceReviews;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

List<Map<String, dynamic>> _maps(Object? value) => (value as List? ?? const [])
    .whereType<Map>()
    .map(Map<String, dynamic>.from)
    .toList(growable: false);

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _money(Object? value) => _string(value, fallback: '0.00');

String? _nullableMoney(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
