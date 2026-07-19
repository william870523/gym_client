class OperationalAnnualResultsModel {
  const OperationalAnnualResultsModel({
    required this.year,
    required this.nature,
    required this.currentBusinessMonth,
    required this.coverage,
    required this.months,
    required this.currencies,
    required this.coverageNote,
    required this.limitations,
  });

  factory OperationalAnnualResultsModel.fromJson(Map<String, dynamic> json) {
    return OperationalAnnualResultsModel(
      year: _text(json['anio']),
      nature: _text(json['naturaleza']),
      currentBusinessMonth: _text(json['mes_comercial_actual']),
      coverage: OperationalAnnualCoverageModel.fromJson(
        _map(json['cobertura']),
      ),
      months: _maps(
        json['meses'],
      ).map(OperationalAnnualMonthModel.fromJson).toList(growable: false),
      currencies: _maps(
        json['monedas'],
      ).map(OperationalAnnualCurrencyModel.fromJson).toList(growable: false),
      coverageNote: _text(json['nota_cobertura']),
      limitations: (json['limitaciones'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }

  final String year;
  final String nature;
  final String currentBusinessMonth;
  final OperationalAnnualCoverageModel coverage;
  final List<OperationalAnnualMonthModel> months;
  final List<OperationalAnnualCurrencyModel> currencies;
  final String coverageNote;
  final List<String> limitations;
}

class OperationalAnnualCoverageModel {
  const OperationalAnnualCoverageModel({
    required this.eligibleMonths,
    required this.certifiedMonths,
    required this.certifiedEligibleMonths,
    required this.pendingMonths,
    required this.eligiblePercentage,
    required this.complete,
  });

  factory OperationalAnnualCoverageModel.fromJson(Map<String, dynamic> json) {
    return OperationalAnnualCoverageModel(
      eligibleMonths: _integer(json['meses_exigibles']),
      certifiedMonths: _integer(json['meses_certificados']),
      certifiedEligibleMonths: _integer(json['meses_certificados_exigibles']),
      pendingMonths: _integer(json['meses_pendientes']),
      eligiblePercentage: _nullableDouble(json['porcentaje_exigible']),
      complete: json['completa'] == true,
    );
  }

  final int eligibleMonths;
  final int certifiedMonths;
  final int certifiedEligibleMonths;
  final int pendingMonths;
  final double? eligiblePercentage;
  final bool complete;
}

class OperationalAnnualMonthModel {
  const OperationalAnnualMonthModel({
    required this.month,
    required this.state,
    required this.reason,
    required this.monthlyCloseId,
    required this.sha256,
    required this.closedAt,
  });

  factory OperationalAnnualMonthModel.fromJson(Map<String, dynamic> json) {
    return OperationalAnnualMonthModel(
      month: _text(json['mes']),
      state: _text(json['estado']),
      reason: _text(json['motivo']),
      monthlyCloseId: _nullableText(json['cierre_mensual_id']),
      sha256: _nullableText(json['resumen_sha256']),
      closedAt: DateTime.tryParse(_text(json['cerrado_at']))?.toUtc(),
    );
  }

  final String month;
  final String state;
  final String reason;
  final String? monthlyCloseId;
  final String? sha256;
  final DateTime? closedAt;

  bool get certified => state == 'CERTIFICADO';
}

class OperationalAnnualCurrencyModel {
  const OperationalAnnualCurrencyModel({
    required this.currencyId,
    required this.currencyCode,
    required this.monthCount,
    required this.flowTotals,
    required this.latestCut,
    required this.highestFlow,
    required this.lowestFlow,
    required this.months,
  });

  factory OperationalAnnualCurrencyModel.fromJson(Map<String, dynamic> json) {
    return OperationalAnnualCurrencyModel(
      currencyId: _text(json['moneda_id']),
      currencyCode: _text(json['moneda_codigo'], fallback: '—'),
      monthCount: _integer(json['meses_con_datos']),
      flowTotals: OperationalAnnualFlowTotalsModel.fromJson(
        _map(json['totales_flujo']),
      ),
      latestCut: json['ultimo_corte'] is Map
          ? OperationalAnnualLatestCutModel.fromJson(
              Map<String, dynamic>.from(json['ultimo_corte'] as Map),
            )
          : null,
      highestFlow: json['mayor_flujo'] is Map
          ? OperationalAnnualFlowExtremeModel.fromJson(
              Map<String, dynamic>.from(json['mayor_flujo'] as Map),
            )
          : null,
      lowestFlow: json['menor_flujo'] is Map
          ? OperationalAnnualFlowExtremeModel.fromJson(
              Map<String, dynamic>.from(json['menor_flujo'] as Map),
            )
          : null,
      months: _maps(json['meses'])
          .map(OperationalAnnualCurrencyMonthModel.fromJson)
          .toList(growable: false),
    );
  }

  final String currencyId;
  final String currencyCode;
  final int monthCount;
  final OperationalAnnualFlowTotalsModel flowTotals;
  final OperationalAnnualLatestCutModel? latestCut;
  final OperationalAnnualFlowExtremeModel? highestFlow;
  final OperationalAnnualFlowExtremeModel? lowestFlow;
  final List<OperationalAnnualCurrencyMonthModel> months;
}

class OperationalAnnualFlowTotalsModel {
  const OperationalAnnualFlowTotalsModel({
    required this.grossCollections,
    required this.ledgerExits,
    required this.operationalFlow,
    required this.trainerPayments,
    required this.refunds,
    required this.otherOperationalExits,
  });

  factory OperationalAnnualFlowTotalsModel.fromJson(Map<String, dynamic> json) {
    return OperationalAnnualFlowTotalsModel(
      grossCollections: _money(json['cobros_brutos']),
      ledgerExits: _money(json['salidas_libro']),
      operationalFlow: _money(json['flujo_operativo']),
      trainerPayments: _money(json['pagos_entrenadores_netos']),
      refunds: _money(json['reembolsos_netos']),
      otherOperationalExits: _money(json['otros_egresos_operativos']),
    );
  }

  final String grossCollections;
  final String ledgerExits;
  final String operationalFlow;
  final String trainerPayments;
  final String refunds;
  final String otherOperationalExits;
}

class OperationalAnnualLatestCutModel {
  const OperationalAnnualLatestCutModel({
    required this.month,
    required this.immediateReserve,
    required this.payableNow,
    required this.futureFund,
    required this.pendingRefunds,
    required this.totalCommitment,
  });

  factory OperationalAnnualLatestCutModel.fromJson(Map<String, dynamic> json) {
    return OperationalAnnualLatestCutModel(
      month: _text(json['mes']),
      immediateReserve: _nullableMoney(json['reserva_inmediata']),
      payableNow: _nullableMoney(json['pagadero_ahora']),
      futureFund: _nullableMoney(json['fondo_futuro']),
      pendingRefunds: _nullableMoney(json['devoluciones_pendientes']),
      totalCommitment: _nullableMoney(json['compromiso_total']),
    );
  }

  final String month;
  final String? immediateReserve;
  final String? payableNow;
  final String? futureFund;
  final String? pendingRefunds;
  final String? totalCommitment;
}

class OperationalAnnualFlowExtremeModel {
  const OperationalAnnualFlowExtremeModel({
    required this.month,
    required this.amount,
  });

  factory OperationalAnnualFlowExtremeModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return OperationalAnnualFlowExtremeModel(
      month: _text(json['mes']),
      amount: _money(json['monto']),
    );
  }

  final String month;
  final String amount;
}

class OperationalAnnualCurrencyMonthModel {
  const OperationalAnnualCurrencyMonthModel({
    required this.month,
    required this.grossCollections,
    required this.ledgerExits,
    required this.operationalFlow,
    required this.trainerPayments,
    required this.refunds,
    required this.otherOperationalExits,
    required this.immediateReserve,
    required this.payableNow,
    required this.futureFund,
    required this.pendingRefunds,
    required this.totalCommitment,
  });

  factory OperationalAnnualCurrencyMonthModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return OperationalAnnualCurrencyMonthModel(
      month: _text(json['mes']),
      grossCollections: _money(json['cobros_brutos']),
      ledgerExits: _money(json['salidas_libro']),
      operationalFlow: _money(json['flujo_operativo']),
      trainerPayments: _money(json['pagos_entrenadores_netos']),
      refunds: _money(json['reembolsos_netos']),
      otherOperationalExits: _money(json['otros_egresos_operativos']),
      immediateReserve: _nullableMoney(json['reserva_inmediata']),
      payableNow: _nullableMoney(json['pagadero_ahora']),
      futureFund: _nullableMoney(json['fondo_futuro']),
      pendingRefunds: _nullableMoney(json['devoluciones_pendientes']),
      totalCommitment: _nullableMoney(json['compromiso_total']),
    );
  }

  final String month;
  final String grossCollections;
  final String ledgerExits;
  final String operationalFlow;
  final String trainerPayments;
  final String refunds;
  final String otherOperationalExits;
  final String? immediateReserve;
  final String? payableNow;
  final String? futureFund;
  final String? pendingRefunds;
  final String? totalCommitment;
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

String? _nullableMoney(Object? value) => value == null
    ? null
    : _text(value).isEmpty
    ? null
    : _text(value);

int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

double? _nullableDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
