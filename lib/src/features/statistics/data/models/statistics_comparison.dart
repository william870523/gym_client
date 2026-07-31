library;

class StatisticsMetricComparison {
  const StatisticsMetricComparison({
    required this.metric,
    required this.current,
    required this.previous,
    required this.delta,
    required this.percentageChange,
  });

  factory StatisticsMetricComparison.fromJson(Map<dynamic, dynamic> json) =>
      StatisticsMetricComparison(
        metric: json['metrica']?.toString() ?? '',
        current: (json['actual'] as num?) ?? 0,
        previous: (json['anterior'] as num?) ?? 0,
        delta: (json['delta'] as num?) ?? 0,
        percentageChange: json['variacionPorcentual'] as num?,
      );

  static const empty = StatisticsMetricComparison(
    metric: '',
    current: 0,
    previous: 0,
    delta: 0,
    percentageChange: null,
  );

  final String metric;
  final num current;
  final num previous;
  final num delta;

  /// Es `null` cuando el período anterior vale cero y no existe una base
  /// matemática válida para calcular el porcentaje.
  final num? percentageChange;
}
