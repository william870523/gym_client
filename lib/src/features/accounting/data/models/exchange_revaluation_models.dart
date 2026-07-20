/// R5.5 — Modelos del informe de revaluación cambiaria (pérdida/ganancia por
/// devaluación). Solo lectura: valúa cobros en moneda débil vivos al corte.
library;

class ExchangeRevaluationModel {
  const ExchangeRevaluationModel({
    required this.month,
    required this.cutoffDate,
    required this.state,
    required this.baseCurrencyId,
    required this.baseCurrencyCode,
    required this.totalRevaluation,
    required this.totalEffect,
    required this.currencies,
    required this.collections,
    required this.collectionsWithoutCutoffRate,
    required this.note,
    required this.limitations,
  });

  factory ExchangeRevaluationModel.fromJson(Map<String, dynamic> json) {
    return ExchangeRevaluationModel(
      month: _text(json['mes']),
      cutoffDate: _nullableText(json['fecha_corte']),
      state: _text(json['estado']),
      baseCurrencyId: _nullableText(json['moneda_base_id']),
      baseCurrencyCode: _nullableText(json['moneda_base_codigo']),
      totalRevaluation: _text(json['total_revaluacion'], fallback: '0.00'),
      totalEffect: _text(json['efecto_total'], fallback: 'NEUTRO'),
      currencies: (json['monedas'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => ExchangeRevaluationCurrencyModel.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(growable: false),
      collections: _integer(json['cobros']),
      collectionsWithoutCutoffRate: _integer(json['cobros_sin_tasa_corte']),
      note: _text(json['nota']),
      limitations: (json['limitaciones'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }

  final String month;
  final String? cutoffDate;
  final String state; // PROVISIONAL | SIN_MONEDA_BASE
  final String? baseCurrencyId;
  final String? baseCurrencyCode;
  final String totalRevaluation;
  final String totalEffect; // PERDIDA | GANANCIA | NEUTRO
  final List<ExchangeRevaluationCurrencyModel> currencies;
  final int collections;
  final int collectionsWithoutCutoffRate;
  final String note;
  final List<String> limitations;

  bool get hasBaseCurrency => state != 'SIN_MONEDA_BASE';
  bool get isLoss => totalEffect == 'PERDIDA';
  bool get isGain => totalEffect == 'GANANCIA';
  double get totalRevaluationValue => double.tryParse(totalRevaluation) ?? 0;
}

class ExchangeRevaluationCurrencyModel {
  const ExchangeRevaluationCurrencyModel({
    required this.currencyId,
    required this.currencyCode,
    required this.collections,
    required this.amountWeak,
    required this.valueAtCollection,
    required this.valueAtCutoff,
    required this.revaluation,
    required this.effect,
    required this.collectionsWithoutCutoffRate,
  });

  factory ExchangeRevaluationCurrencyModel.fromJson(Map<String, dynamic> json) {
    return ExchangeRevaluationCurrencyModel(
      currencyId: _text(json['moneda_id']),
      currencyCode: _text(json['moneda_codigo']),
      collections: _integer(json['cobros']),
      amountWeak: _text(json['importe_debil'], fallback: '0.00'),
      valueAtCollection: _text(json['valor_al_cobro'], fallback: '0.00'),
      valueAtCutoff: _text(json['valor_al_corte'], fallback: '0.00'),
      revaluation: _text(json['revaluacion'], fallback: '0.00'),
      effect: _text(json['efecto'], fallback: 'NEUTRO'),
      collectionsWithoutCutoffRate: _integer(json['cobros_sin_tasa_corte']),
    );
  }

  final String currencyId;
  final String currencyCode;
  final int collections;
  final String amountWeak;
  final String valueAtCollection;
  final String valueAtCutoff;
  final String revaluation;
  final String effect; // PERDIDA | GANANCIA | NEUTRO
  final int collectionsWithoutCutoffRate;

  bool get isLoss => effect == 'PERDIDA';
  bool get isGain => effect == 'GANANCIA';
  double get revaluationValue => double.tryParse(revaluation) ?? 0;
}

String _text(dynamic value, {String fallback = ''}) =>
    value == null ? fallback : value.toString();

String? _nullableText(dynamic value) => value?.toString();

int _integer(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
