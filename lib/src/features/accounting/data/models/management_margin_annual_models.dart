class ManagementMarginAnnualResultsModel {
  const ManagementMarginAnnualResultsModel({
    required this.year,
    required this.nature,
    required this.currentBusinessMonth,
    required this.coverage,
    required this.months,
    required this.currencies,
    required this.coverageNote,
    required this.limitations,
  });

  factory ManagementMarginAnnualResultsModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ManagementMarginAnnualResultsModel(
      year: _text(json['anio']),
      nature: _text(json['naturaleza']),
      currentBusinessMonth: _text(json['mes_comercial_actual']),
      coverage: ManagementMarginAnnualCoverageModel.fromJson(
        _map(json['cobertura']),
      ),
      months: _maps(
        json['meses'],
      ).map(ManagementMarginAnnualMonthModel.fromJson).toList(growable: false),
      currencies: _maps(json['monedas'])
          .map(ManagementMarginAnnualCurrencyModel.fromJson)
          .toList(growable: false),
      coverageNote: _text(json['nota_cobertura']),
      limitations: (json['limitaciones'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }

  final String year;
  final String nature;
  final String currentBusinessMonth;
  final ManagementMarginAnnualCoverageModel coverage;
  final List<ManagementMarginAnnualMonthModel> months;
  final List<ManagementMarginAnnualCurrencyModel> currencies;
  final String coverageNote;
  final List<String> limitations;
}

class ManagementMarginAnnualCoverageModel {
  const ManagementMarginAnnualCoverageModel({
    required this.eligibleMonths,
    required this.certifiedMonths,
    required this.certifiedEligibleMonths,
    required this.pendingMonths,
    required this.eligiblePercentage,
    required this.complete,
  });

  factory ManagementMarginAnnualCoverageModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ManagementMarginAnnualCoverageModel(
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

class ManagementMarginAnnualMonthModel {
  const ManagementMarginAnnualMonthModel({
    required this.month,
    required this.state,
    required this.reason,
    required this.monthlyCloseId,
    required this.sha256,
    required this.closedAt,
  });

  factory ManagementMarginAnnualMonthModel.fromJson(Map<String, dynamic> json) {
    return ManagementMarginAnnualMonthModel(
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

class ManagementMarginAnnualCurrencyModel {
  const ManagementMarginAnnualCurrencyModel({
    required this.currencyId,
    required this.currencyCode,
    required this.monthCount,
    required this.accrualTotals,
    required this.latestCut,
    required this.highestMargin,
    required this.lowestMargin,
    required this.months,
  });

  factory ManagementMarginAnnualCurrencyModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ManagementMarginAnnualCurrencyModel(
      currencyId: _text(json['moneda_id']),
      currencyCode: _text(json['moneda_codigo'], fallback: '—'),
      monthCount: _integer(json['meses_con_datos']),
      accrualTotals: ManagementMarginAnnualTotalsModel.fromJson(
        _map(json['totales_devengo']),
      ),
      latestCut: json['ultimo_corte'] is Map
          ? ManagementMarginAnnualLatestCutModel.fromJson(
              Map<String, dynamic>.from(json['ultimo_corte'] as Map),
            )
          : null,
      highestMargin: json['mayor_margen'] is Map
          ? ManagementMarginAnnualExtremeModel.fromJson(
              Map<String, dynamic>.from(json['mayor_margen'] as Map),
            )
          : null,
      lowestMargin: json['menor_margen'] is Map
          ? ManagementMarginAnnualExtremeModel.fromJson(
              Map<String, dynamic>.from(json['menor_margen'] as Map),
            )
          : null,
      months: _maps(json['meses'])
          .map(ManagementMarginAnnualCurrencyMonthModel.fromJson)
          .toList(growable: false),
    );
  }

  final String currencyId;
  final String currencyCode;
  final int monthCount;
  final ManagementMarginAnnualTotalsModel accrualTotals;
  final ManagementMarginAnnualLatestCutModel? latestCut;
  final ManagementMarginAnnualExtremeModel? highestMargin;
  final ManagementMarginAnnualExtremeModel? lowestMargin;
  final List<ManagementMarginAnnualCurrencyMonthModel> months;
}

class ManagementMarginAnnualTotalsModel {
  const ManagementMarginAnnualTotalsModel({
    required this.revenue,
    required this.directCost,
    required this.directMargin,
    required this.fixed,
    required this.marginAfterFixed,
    required this.marginPct,
  });

  factory ManagementMarginAnnualTotalsModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ManagementMarginAnnualTotalsModel(
      revenue: _money(json['ingreso_devengado']),
      directCost: _money(json['costo_directo']),
      directMargin: _money(json['margen_directo']),
      fixed: _money(json['fijo_no_distribuido']),
      marginAfterFixed: _money(json['margen_menos_fijo']),
      marginPct: _nullableText(json['margen_directo_pct']),
    );
  }

  final String revenue;
  final String directCost;
  final String directMargin;
  final String fixed;
  final String marginAfterFixed;
  final String? marginPct;
}

class ManagementMarginAnnualLatestCutModel {
  const ManagementMarginAnnualLatestCutModel({
    required this.month,
    required this.revenueToDate,
    required this.directCostToDate,
    required this.directMarginToDate,
    required this.fixedToDate,
    required this.marginAfterFixedToDate,
    required this.marginPctToDate,
  });

  factory ManagementMarginAnnualLatestCutModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ManagementMarginAnnualLatestCutModel(
      month: _text(json['mes']),
      revenueToDate: _money(json['ingreso_devengado_acumulado']),
      directCostToDate: _money(json['costo_directo_acumulado']),
      directMarginToDate: _money(json['margen_directo_acumulado']),
      fixedToDate: _money(json['fijo_no_distribuido_acumulado']),
      marginAfterFixedToDate: _money(json['margen_menos_fijo_acumulado']),
      marginPctToDate: _nullableText(json['margen_directo_pct_acumulado']),
    );
  }

  final String month;
  final String revenueToDate;
  final String directCostToDate;
  final String directMarginToDate;
  final String fixedToDate;
  final String marginAfterFixedToDate;
  final String? marginPctToDate;
}

class ManagementMarginAnnualExtremeModel {
  const ManagementMarginAnnualExtremeModel({
    required this.month,
    required this.amount,
  });

  factory ManagementMarginAnnualExtremeModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ManagementMarginAnnualExtremeModel(
      month: _text(json['mes']),
      amount: _money(json['monto']),
    );
  }

  final String month;
  final String amount;
}

class ManagementMarginAnnualCurrencyMonthModel {
  const ManagementMarginAnnualCurrencyMonthModel({
    required this.month,
    required this.revenue,
    required this.directCost,
    required this.directMargin,
    required this.fixed,
    required this.marginAfterFixed,
    required this.marginPct,
    required this.revenueToDate,
    required this.directCostToDate,
    required this.directMarginToDate,
    required this.fixedToDate,
    required this.marginAfterFixedToDate,
    required this.marginPctToDate,
  });

  factory ManagementMarginAnnualCurrencyMonthModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ManagementMarginAnnualCurrencyMonthModel(
      month: _text(json['mes']),
      revenue: _money(json['ingreso_devengado']),
      directCost: _money(json['costo_directo']),
      directMargin: _money(json['margen_directo']),
      fixed: _money(json['fijo_no_distribuido']),
      marginAfterFixed: _money(json['margen_menos_fijo']),
      marginPct: _nullableText(json['margen_directo_pct']),
      revenueToDate: _money(json['ingreso_devengado_acumulado']),
      directCostToDate: _money(json['costo_directo_acumulado']),
      directMarginToDate: _money(json['margen_directo_acumulado']),
      fixedToDate: _money(json['fijo_no_distribuido_acumulado']),
      marginAfterFixedToDate: _money(json['margen_menos_fijo_acumulado']),
      marginPctToDate: _nullableText(json['margen_directo_pct_acumulado']),
    );
  }

  final String month;
  final String revenue;
  final String directCost;
  final String directMargin;
  final String fixed;
  final String marginAfterFixed;
  final String? marginPct;
  final String revenueToDate;
  final String directCostToDate;
  final String directMarginToDate;
  final String fixedToDate;
  final String marginAfterFixedToDate;
  final String? marginPctToDate;
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

double? _nullableDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
