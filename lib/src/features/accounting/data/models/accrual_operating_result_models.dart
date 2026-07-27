import 'operational_results_models.dart';

/// R4.6 — Resultado operativo devengado: el margen gerencial ya neto de
/// compensación fija, menos el gasto gobernado que pertenece al mes.
class AccrualOperatingResultModel {
  const AccrualOperatingResultModel({
    required this.month,
    required this.nature,
    required this.periodState,
    required this.cutoffDate,
    required this.certified,
    required this.marginCertified,
    required this.expenseCertified,
    required this.monthlyClose,
    required this.certificationNote,
    required this.coverage,
    required this.currencies,
    required this.note,
    required this.limitations,
  });

  factory AccrualOperatingResultModel.fromJson(Map<String, dynamic> json) {
    return AccrualOperatingResultModel(
      month: _text(json['mes']),
      nature: _text(json['naturaleza']),
      periodState: _text(json['estado_periodo']),
      cutoffDate: _nullableText(json['fecha_corte']),
      certified: json['certificado'] == true,
      marginCertified: json['margen_certificado'] == true,
      expenseCertified: json['gasto_certificado'] == true,
      monthlyClose: json['cierre_tesoreria'] is Map
          ? OperationalMonthlyCloseModel.fromJson(
              Map<String, dynamic>.from(json['cierre_tesoreria'] as Map),
            )
          : null,
      certificationNote: _text(json['nota_certificacion']),
      coverage: AccrualOperatingResultCoverageModel.fromJson(
        _map(json['cobertura']),
      ),
      currencies: _maps(json['monedas'])
          .map(AccrualOperatingResultCurrencyModel.fromJson)
          .toList(growable: false),
      note: _text(json['nota']),
      limitations: (json['limitaciones'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }

  final String month;
  final String nature;
  final String periodState;
  final String? cutoffDate;
  final bool certified;
  final bool marginCertified;
  final bool expenseCertified;
  final OperationalMonthlyCloseModel? monthlyClose;
  final String certificationNote;
  final AccrualOperatingResultCoverageModel coverage;
  final List<AccrualOperatingResultCurrencyModel> currencies;
  final String note;
  final List<String> limitations;
}

class AccrualOperatingResultCoverageModel {
  const AccrualOperatingResultCoverageModel({
    required this.evaluatedMemberships,
    required this.evaluatedCostConcepts,
    required this.evaluatedExpenses,
    required this.expensesPendingPayment,
    required this.crossMonthPayments,
    required this.requiresReview,
    required this.complete,
  });

  factory AccrualOperatingResultCoverageModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AccrualOperatingResultCoverageModel(
      evaluatedMemberships: _integer(json['membresias_evaluadas']),
      evaluatedCostConcepts: _integer(json['conceptos_costo_evaluados']),
      evaluatedExpenses: _integer(json['gastos_evaluados']),
      expensesPendingPayment: _integer(json['gastos_pendientes_pago']),
      crossMonthPayments: _integer(
        json['gastos_de_otro_mes_pagados_en_el_mes'],
      ),
      requiresReview: _integer(json['requieren_revision']),
      complete: json['completa'] == true,
    );
  }

  final int evaluatedMemberships;
  final int evaluatedCostConcepts;
  final int evaluatedExpenses;
  final int expensesPendingPayment;
  final int crossMonthPayments;
  final int requiresReview;
  final bool complete;
}

class AccrualOperatingResultCurrencyModel {
  const AccrualOperatingResultCurrencyModel({
    required this.currencyId,
    required this.currencyCode,
    required this.revenueInMonth,
    required this.directCostInMonth,
    required this.marginInMonth,
    required this.fixedInMonth,
    required this.marginAfterFixedInMonth,
    required this.expenseInMonth,
    required this.expensePaidInMonth,
    required this.expensePendingPayment,
    required this.resultInMonth,
    required this.resultPctOfRevenue,
    required this.natures,
    required this.expenseOnly,
    required this.explanation,
  });

  factory AccrualOperatingResultCurrencyModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AccrualOperatingResultCurrencyModel(
      currencyId: _text(json['moneda_id']),
      currencyCode: _text(json['moneda_codigo'], fallback: '—'),
      revenueInMonth: _money(json['ingreso_devengado_mes']),
      directCostInMonth: _money(json['costo_directo_mes']),
      marginInMonth: _money(json['margen_directo_mes']),
      fixedInMonth: _money(json['fijo_no_distribuido_mes']),
      marginAfterFixedInMonth: _money(json['margen_menos_fijo_mes']),
      expenseInMonth: _money(json['gasto_devengado_mes']),
      expensePaidInMonth: _money(json['gasto_pagado_mes']),
      expensePendingPayment: _money(json['gasto_pendiente_pago']),
      resultInMonth: _money(json['resultado_operativo_devengado_mes']),
      resultPctOfRevenue: _nullableNumber(
        json['resultado_operativo_pct_ingreso_mes'],
      ),
      natures: _maps(
        json['gasto_por_naturaleza'],
      ).map(AccrualExpenseNatureModel.fromJson).toList(growable: false),
      expenseOnly: json['solo_gasto'] == true,
      explanation: _text(json['explicacion']),
    );
  }

  final String currencyId;
  final String currencyCode;
  final String revenueInMonth;
  final String directCostInMonth;
  final String marginInMonth;
  final String fixedInMonth;
  final String marginAfterFixedInMonth;
  final String expenseInMonth;
  final String expensePaidInMonth;
  final String expensePendingPayment;
  final String resultInMonth;
  final double? resultPctOfRevenue;
  final List<AccrualExpenseNatureModel> natures;
  final bool expenseOnly;
  final String explanation;
}

class AccrualExpenseNatureModel {
  const AccrualExpenseNatureModel({
    required this.nature,
    required this.expenses,
    required this.accruedInMonth,
    required this.pctOfRevenue,
  });

  factory AccrualExpenseNatureModel.fromJson(Map<String, dynamic> json) {
    return AccrualExpenseNatureModel(
      nature: _text(json['naturaleza'], fallback: 'SIN_NATURALEZA'),
      expenses: _integer(json['gastos']),
      accruedInMonth: _money(json['devengado_mes']),
      pctOfRevenue: _nullableNumber(json['pct_ingreso_mes']),
    );
  }

  final String nature;
  final int expenses;
  final String accruedInMonth;
  final double? pctOfRevenue;

  /// Etiqueta legible para personal no contador.
  String get label => switch (nature) {
    'OPERATIVO' => 'Operativo',
    'ADMINISTRATIVO' => 'Administrativo',
    'COSTO_VENTAS' => 'Costo de ventas',
    'SIN_NATURALEZA' => 'Sin naturaleza',
    _ => nature,
  };
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

double? _nullableNumber(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
