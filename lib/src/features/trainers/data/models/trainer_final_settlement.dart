import 'trainer_offboarding_case.dart';

double _money(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

DateTime _instant(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw const FormatException('Instante de liquidación inválido.');
  }
  return parsed.toUtc();
}

class TrainerFinalSettlementConcept {
  const TrainerFinalSettlementConcept({
    required this.id,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.scheduledDate,
    required this.balance,
  });

  final String id;
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime scheduledDate;
  final double balance;

  factory TrainerFinalSettlementConcept.fromJson(Map<String, dynamic> json) {
    return TrainerFinalSettlementConcept(
      id: json['referencia_id'] as String? ?? '',
      type: json['origen_tipo'] as String? ?? '',
      startDate: _instant(json['periodo_inicio']),
      endDate: _instant(json['periodo_fin']),
      scheduledDate: _instant(json['fecha_programada']),
      balance: _money(json['saldo_pendiente']),
    );
  }
}

class TrainerFinalSettlementCurrency {
  const TrainerFinalSettlementCurrency({
    required this.currencyId,
    required this.currencyCode,
    required this.commissionTotal,
    required this.fixedTotal,
    required this.total,
    required this.concepts,
    required this.items,
  });

  final String currencyId;
  final String currencyCode;
  final double commissionTotal;
  final double fixedTotal;
  final double total;
  final int concepts;
  final List<TrainerFinalSettlementConcept> items;

  factory TrainerFinalSettlementCurrency.fromJson(Map<String, dynamic> json) {
    final commission = (json['aplicaciones'] as List? ?? const [])
        .map(
          (item) => TrainerFinalSettlementConcept.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    final fixed = (json['aplicaciones_fijas'] as List? ?? const [])
        .map(
          (item) => TrainerFinalSettlementConcept.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    return TrainerFinalSettlementCurrency(
      currencyId: json['moneda_id'] as String? ?? '',
      currencyCode:
          json['moneda_codigo'] as String? ??
          json['moneda_id'] as String? ??
          '',
      commissionTotal: _money(json['monto_comision']),
      fixedTotal: _money(json['monto_fijo']),
      total: _money(json['monto_total']),
      concepts: (json['conceptos'] as num?)?.toInt() ?? 0,
      items: [...commission, ...fixed],
    );
  }
}

class TrainerFinalSettlementAccount {
  const TrainerFinalSettlementAccount({
    required this.id,
    required this.name,
    required this.currencyId,
    required this.currencyCode,
    this.paymentTypeId,
  });

  final String id;
  final String name;
  final String currencyId;
  final String currencyCode;
  final String? paymentTypeId;

  factory TrainerFinalSettlementAccount.fromJson(Map<String, dynamic> json) {
    return TrainerFinalSettlementAccount(
      id: json['cuenta_id'] as String? ?? '',
      name: json['nombre_cuenta'] as String? ?? '',
      currencyId: json['moneda_id'] as String? ?? '',
      currencyCode:
          json['moneda_codigo'] as String? ??
          json['moneda_id'] as String? ??
          '',
      paymentTypeId: json['tipo_pago_id'] as String?,
    );
  }
}

class TrainerFinalSettlementPaymentType {
  const TrainerFinalSettlementPaymentType({
    required this.id,
    required this.name,
    required this.code,
  });

  final String id;
  final String name;
  final String code;

  factory TrainerFinalSettlementPaymentType.fromJson(
    Map<String, dynamic> json,
  ) {
    return TrainerFinalSettlementPaymentType(
      id: json['tipo_pago_id'] as String? ?? '',
      name: json['nombre_tipo_pago'] as String? ?? '',
      code: json['codigo'] as String? ?? '',
    );
  }
}

class TrainerFinalSettlementHistory {
  const TrainerFinalSettlementHistory({
    required this.id,
    required this.receiptNumber,
    required this.currencyId,
    required this.total,
    required this.status,
    required this.paidAt,
  });

  final String id;
  final String receiptNumber;
  final String currencyId;
  final double total;
  final String status;
  final DateTime paidAt;

  factory TrainerFinalSettlementHistory.fromJson(Map<String, dynamic> json) {
    return TrainerFinalSettlementHistory(
      id: json['liquidacion_id'] as String? ?? '',
      receiptNumber: json['comprobante_numero'] as String? ?? '',
      currencyId: json['moneda_id'] as String? ?? '',
      total: _money(json['monto_total']),
      status: json['estado'] as String? ?? '',
      paidAt: _instant(json['pagada_at']),
    );
  }
}

class TrainerFinalSettlementPreview {
  const TrainerFinalSettlementPreview({
    required this.caseId,
    required this.trainerId,
    required this.trainerName,
    required this.effectiveDate,
    required this.status,
    required this.currencies,
    required this.accounts,
    required this.paymentTypes,
    required this.history,
    this.closedAt,
  });

  final String caseId;
  final String trainerId;
  final String trainerName;
  final DateTime effectiveDate;
  final String status;
  final DateTime? closedAt;
  final List<TrainerFinalSettlementCurrency> currencies;
  final List<TrainerFinalSettlementAccount> accounts;
  final List<TrainerFinalSettlementPaymentType> paymentTypes;
  final List<TrainerFinalSettlementHistory> history;

  bool get closed => status == 'EJECUTADO';
  bool get hasBalances => currencies.isNotEmpty;

  factory TrainerFinalSettlementPreview.fromJson(Map<String, dynamic> json) {
    return TrainerFinalSettlementPreview(
      caseId: json['expediente_id'] as String? ?? '',
      trainerId: json['id_entrenador'] as String? ?? '',
      trainerName: json['entrenador_nombre'] as String? ?? '',
      effectiveDate: _instant(json['fecha_efectiva']),
      status: json['estado'] as String? ?? 'EN_EJECUCION',
      closedAt: json['cerrado_at'] == null
          ? null
          : _instant(json['cerrado_at']),
      currencies: (json['monedas'] as List? ?? const [])
          .map(
            (item) => TrainerFinalSettlementCurrency.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      accounts: (json['cuentas'] as List? ?? const [])
          .map(
            (item) => TrainerFinalSettlementAccount.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      paymentTypes: (json['tipos_pago'] as List? ?? const [])
          .map(
            (item) => TrainerFinalSettlementPaymentType.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      history: (json['liquidaciones'] as List? ?? const [])
          .map(
            (item) => TrainerFinalSettlementHistory.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class TrainerFinalSettlementResult {
  const TrainerFinalSettlementResult({
    required this.offboardingCase,
    required this.preview,
    this.receiptNumber,
  });

  final TrainerOffboardingCase offboardingCase;
  final TrainerFinalSettlementPreview preview;
  final String? receiptNumber;

  factory TrainerFinalSettlementResult.fromJson(Map<String, dynamic> json) {
    final liquidation = json['liquidacion'];
    return TrainerFinalSettlementResult(
      offboardingCase: TrainerOffboardingCase.fromJson(
        Map<String, dynamic>.from(json['expediente'] as Map),
      ),
      preview: TrainerFinalSettlementPreview.fromJson(
        Map<String, dynamic>.from(json['resumen_final'] as Map),
      ),
      receiptNumber: liquidation is Map
          ? liquidation['comprobante_numero'] as String?
          : null,
    );
  }
}
