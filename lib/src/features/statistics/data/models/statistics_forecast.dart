class StatisticsForecastQuery {
  const StatisticsForecastQuery({
    this.historyDays = 180,
    this.horizonDays = 28,
  });

  final int historyDays;
  final int horizonDays;

  StatisticsForecastQuery copyWith({int? historyDays, int? horizonDays}) =>
      StatisticsForecastQuery(
        historyDays: historyDays ?? this.historyDays,
        horizonDays: horizonDays ?? this.horizonDays,
      );

  @override
  bool operator ==(Object other) =>
      other is StatisticsForecastQuery &&
      other.historyDays == historyDays &&
      other.horizonDays == horizonDays;

  @override
  int get hashCode => Object.hash(historyDays, horizonDays);
}

class ForecastBand {
  const ForecastBand({
    required this.lower,
    required this.central,
    required this.upper,
  });

  final double lower;
  final double central;
  final double upper;

  factory ForecastBand.fromJson(Map<String, dynamic> json) => ForecastBand(
    lower: (json['inferior'] as num?)?.toDouble() ?? 0,
    central: (json['central'] as num?)?.toDouble() ?? 0,
    upper: (json['superior'] as num?)?.toDouble() ?? 0,
  );
}

class ForecastWeekday extends ForecastBand {
  const ForecastWeekday({
    required this.weekday,
    required this.label,
    required this.samples,
    required super.lower,
    required super.central,
    required super.upper,
  });

  final int weekday;
  final String label;
  final int samples;

  factory ForecastWeekday.fromJson(Map<String, dynamic> json) =>
      ForecastWeekday(
        weekday: (json['diaSemana'] as num?)?.toInt() ?? 0,
        label: json['etiqueta']?.toString() ?? '',
        samples: (json['muestras'] as num?)?.toInt() ?? 0,
        lower: (json['inferior'] as num?)?.toDouble() ?? 0,
        central: (json['central'] as num?)?.toDouble() ?? 0,
        upper: (json['superior'] as num?)?.toDouble() ?? 0,
      );
}

class ForecastDay extends ForecastBand {
  const ForecastDay({
    required this.date,
    required this.weekday,
    required this.label,
    required super.lower,
    required super.central,
    required super.upper,
  });

  final String date;
  final int weekday;
  final String label;

  factory ForecastDay.fromJson(Map<String, dynamic> json) => ForecastDay(
    date: json['dia']?.toString() ?? '',
    weekday: (json['diaSemana'] as num?)?.toInt() ?? 0,
    label: json['etiqueta']?.toString() ?? '',
    lower: (json['inferior'] as num?)?.toDouble() ?? 0,
    central: (json['central'] as num?)?.toDouble() ?? 0,
    upper: (json['superior'] as num?)?.toDouble() ?? 0,
  );
}

class ForecastWeek extends ForecastBand {
  const ForecastWeek({
    required this.week,
    required this.from,
    required this.to,
    required super.lower,
    required super.central,
    required super.upper,
  });

  final int week;
  final String from;
  final String to;

  factory ForecastWeek.fromJson(Map<String, dynamic> json) => ForecastWeek(
    week: (json['semana'] as num?)?.toInt() ?? 0,
    from: json['desde']?.toString() ?? '',
    to: json['hasta']?.toString() ?? '',
    lower: (json['inferior'] as num?)?.toDouble() ?? 0,
    central: (json['central'] as num?)?.toDouble() ?? 0,
    upper: (json['superior'] as num?)?.toDouble() ?? 0,
  );
}

class ForecastHistoryPoint {
  const ForecastHistoryPoint({required this.date, required this.visits});
  final String date;
  final double visits;

  factory ForecastHistoryPoint.fromJson(Map<String, dynamic> json) =>
      ForecastHistoryPoint(
        date: json['dia']?.toString() ?? '',
        visits: (json['visitas'] as num?)?.toDouble() ?? 0,
      );
}

class StatisticsForecast {
  const StatisticsForecast({
    required this.zone,
    required this.businessDate,
    required this.available,
    required this.unavailableReason,
    required this.historyDays,
    required this.historyFrom,
    required this.historyTo,
    required this.usefulDays,
    required this.minimumSamples,
    required this.horizonDays,
    required this.horizonFrom,
    required this.horizonTo,
    required this.methodName,
    required this.methodEstimate,
    required this.methodInterval,
    required this.methodMinimum,
    required this.methodGuarantee,
    required this.trendState,
    required this.recentVisits,
    required this.previousVisits,
    required this.trendPercentage,
    required this.trendRule,
    required this.weekdays,
    required this.days,
    required this.weeks,
    required this.total,
    required this.history,
    required this.warnings,
  });

  final String zone;
  final String businessDate;
  final bool available;
  final String? unavailableReason;
  final int historyDays;
  final String historyFrom;
  final String historyTo;
  final int usefulDays;
  final int minimumSamples;
  final int horizonDays;
  final String horizonFrom;
  final String horizonTo;
  final String methodName;
  final String methodEstimate;
  final String methodInterval;
  final String methodMinimum;
  final String methodGuarantee;
  final String trendState;
  final double recentVisits;
  final double previousVisits;
  final double? trendPercentage;
  final String trendRule;
  final List<ForecastWeekday> weekdays;
  final List<ForecastDay> days;
  final List<ForecastWeek> weeks;
  final ForecastBand? total;
  final List<ForecastHistoryPoint> history;
  final List<String> warnings;

  factory StatisticsForecast.fromJson(Map<String, dynamic> json) {
    final history = Map<String, dynamic>.from(
      json['historia'] as Map? ?? const {},
    );
    final horizon = Map<String, dynamic>.from(
      json['horizonte'] as Map? ?? const {},
    );
    final method = Map<String, dynamic>.from(
      json['metodo'] as Map? ?? const {},
    );
    final trend = Map<String, dynamic>.from(
      json['tendenciaReciente'] as Map? ?? const {},
    );
    final total = json['totalHorizonte'];
    List<Map<String, dynamic>> list(String key) => [
      for (final item in (json[key] as List? ?? const []))
        Map<String, dynamic>.from(item as Map),
    ];
    return StatisticsForecast(
      zone: json['zona']?.toString() ?? '',
      businessDate: json['dia_negocio']?.toString() ?? '',
      available: json['disponible'] == true,
      unavailableReason: json['motivoNoDisponible']?.toString(),
      historyDays: (history['diasSolicitados'] as num?)?.toInt() ?? 0,
      historyFrom: history['desde']?.toString() ?? '',
      historyTo: history['hasta']?.toString() ?? '',
      usefulDays: (history['diasUtiles'] as num?)?.toInt() ?? 0,
      minimumSamples:
          (history['muestrasMinimasPorDiaSemana'] as num?)?.toInt() ?? 0,
      horizonDays: (horizon['dias'] as num?)?.toInt() ?? 0,
      horizonFrom: horizon['desde']?.toString() ?? '',
      horizonTo: horizon['hasta']?.toString() ?? '',
      methodName: method['nombre']?.toString() ?? '',
      methodEstimate: method['estimacion']?.toString() ?? '',
      methodInterval: method['intervalo']?.toString() ?? '',
      methodMinimum: method['minimo']?.toString() ?? '',
      methodGuarantee: method['garantia']?.toString() ?? '',
      trendState: trend['estado']?.toString() ?? 'SIN_BASE',
      recentVisits: (trend['actual28Dias'] as num?)?.toDouble() ?? 0,
      previousVisits: (trend['anterior28Dias'] as num?)?.toDouble() ?? 0,
      trendPercentage: (trend['variacionPorcentual'] as num?)?.toDouble(),
      trendRule: trend['regla']?.toString() ?? '',
      weekdays: list('porDiaSemana').map(ForecastWeekday.fromJson).toList(),
      days: list('proyeccionDiaria').map(ForecastDay.fromJson).toList(),
      weeks: list('proyeccionSemanal').map(ForecastWeek.fromJson).toList(),
      total: total is Map
          ? ForecastBand.fromJson(Map<String, dynamic>.from(total))
          : null,
      history: list(
        'historiaReciente',
      ).map(ForecastHistoryPoint.fromJson).toList(),
      warnings: [
        for (final item in (json['advertencias'] as List? ?? const []))
          item.toString(),
      ],
    );
  }
}
