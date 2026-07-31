library;

import 'statistics_comparison.dart';

enum StatisticsRankingType {
  plans('planes'),
  trainers('entrenadores'),
  memberVisits('socios-visitas'),
  memberInactivity('socios-inactividad'),
  memberTrainerChanges('socios-cambios-entrenador'),
  memberValue('socios-valor');

  const StatisticsRankingType(this.apiValue);
  final String apiValue;
}

class StatisticsRankingQuery {
  const StatisticsRankingQuery({
    required this.type,
    required this.days,
    required this.page,
    required this.pageSize,
    required this.search,
    required this.order,
    required this.direction,
    this.currencyId,
  });

  factory StatisticsRankingQuery.initial({
    required StatisticsRankingType type,
    required int days,
    String? currencyId,
  }) => StatisticsRankingQuery(
    type: type,
    days: days,
    page: 1,
    pageSize: 25,
    search: '',
    order: defaultRankingOrder(type),
    direction: 'desc',
    currencyId: currencyId,
  );

  final StatisticsRankingType type;
  final int days;
  final int page;
  final int pageSize;
  final String search;
  final String order;
  final String direction;
  final String? currencyId;

  StatisticsRankingQuery copyWith({
    int? days,
    int? page,
    int? pageSize,
    String? search,
    String? order,
    String? direction,
  }) => StatisticsRankingQuery(
    type: type,
    days: days ?? this.days,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
    search: search ?? this.search,
    order: order ?? this.order,
    direction: direction ?? this.direction,
    currencyId: currencyId,
  );

  @override
  bool operator ==(Object other) =>
      other is StatisticsRankingQuery &&
      other.type == type &&
      other.days == days &&
      other.page == page &&
      other.pageSize == pageSize &&
      other.search == search &&
      other.order == order &&
      other.direction == direction &&
      other.currencyId == currencyId;

  @override
  int get hashCode => Object.hash(
    type,
    days,
    page,
    pageSize,
    search,
    order,
    direction,
    currencyId,
  );
}

String defaultRankingOrder(StatisticsRankingType type) => switch (type) {
  StatisticsRankingType.plans => 'vendidos',
  StatisticsRankingType.trainers => 'carteraActiva',
  StatisticsRankingType.memberVisits => 'visitas',
  StatisticsRankingType.memberInactivity => 'diasSinVisita',
  StatisticsRankingType.memberTrainerChanges => 'cambios',
  StatisticsRankingType.memberValue => 'total',
};

class StatisticsRankingPagination {
  const StatisticsRankingPagination({
    required this.number,
    required this.size,
    required this.total,
    required this.totalPages,
  });

  factory StatisticsRankingPagination.fromJson(Map<dynamic, dynamic> json) =>
      StatisticsRankingPagination(
        number: (json['numero'] as num?)?.toInt() ?? 1,
        size: (json['tamano'] as num?)?.toInt() ?? 25,
        total: (json['total'] as num?)?.toInt() ?? 0,
        totalPages: (json['totalPaginas'] as num?)?.toInt() ?? 0,
      );

  final int number;
  final int size;
  final int total;
  final int totalPages;
}

class StatisticsRankingRow {
  const StatisticsRankingRow({
    required this.id,
    required this.name,
    required this.values,
    this.comparison = StatisticsMetricComparison.empty,
  });

  factory StatisticsRankingRow.fromJson(Map<dynamic, dynamic> json) {
    final values = <String, num>{};
    for (final entry in json.entries) {
      if (entry.value is num) values[entry.key.toString()] = entry.value as num;
    }
    return StatisticsRankingRow(
      id: (json['id'] ?? json['ci'] ?? '').toString(),
      name: (json['nombre'] ?? '').toString(),
      values: Map.unmodifiable(values),
      comparison: StatisticsMetricComparison.fromJson(
        json['comparacion'] as Map? ?? const {},
      ),
    );
  }

  final String id;
  final String name;
  final Map<String, num> values;
  final StatisticsMetricComparison comparison;

  num value(String key) => values[key] ?? 0;
}

class StatisticsRankingPage {
  const StatisticsRankingPage({
    required this.zone,
    required this.businessDay,
    this.period = StatisticsRankingPeriod.empty,
    this.previousPeriod = StatisticsRankingPeriod.empty,
    required this.pagination,
    required this.rows,
  });

  factory StatisticsRankingPage.fromJson(Map<String, dynamic> json) =>
      StatisticsRankingPage(
        zone: json['zona']?.toString() ?? '',
        businessDay: json['dia_negocio']?.toString() ?? '',
        period: StatisticsRankingPeriod.fromJson(
          json['periodo'] as Map? ?? const {},
        ),
        previousPeriod: StatisticsRankingPeriod.fromJson(
          json['periodoAnterior'] as Map? ?? const {},
        ),
        pagination: StatisticsRankingPagination.fromJson(
          json['pagina'] as Map? ?? const {},
        ),
        rows: (json['filas'] as List? ?? const [])
            .map((item) => StatisticsRankingRow.fromJson(item as Map))
            .toList(growable: false),
      );

  final String zone;
  final String businessDay;
  final StatisticsRankingPeriod period;
  final StatisticsRankingPeriod previousPeriod;
  final StatisticsRankingPagination pagination;
  final List<StatisticsRankingRow> rows;
}

class StatisticsRankingPeriod {
  const StatisticsRankingPeriod({
    required this.days,
    required this.from,
    required this.to,
  });

  factory StatisticsRankingPeriod.fromJson(Map<dynamic, dynamic> json) =>
      StatisticsRankingPeriod(
        days: (json['dias'] as num?)?.toInt() ?? 0,
        from: json['desde']?.toString() ?? '',
        to: json['hasta']?.toString() ?? '',
      );

  static const empty = StatisticsRankingPeriod(days: 0, from: '', to: '');

  final int days;
  final String from;
  final String to;
}

const rankingOrders = <StatisticsRankingType, List<(String, String)>>{
  StatisticsRankingType.plans: [
    ('vendidos', 'Ventas'),
    ('sociosConCobertura', 'Cobertura'),
    ('renovaciones', 'Renovaciones'),
    ('nombre', 'Nombre'),
  ],
  StatisticsRankingType.trainers: [
    ('carteraActiva', 'Cartera activa'),
    ('ganados', 'Ganados'),
    ('perdidos', 'Perdidos'),
    ('nombre', 'Nombre'),
  ],
  StatisticsRankingType.memberVisits: [
    ('visitas', 'Visitas'),
    ('diasSinVisita', 'Días sin visita'),
    ('nombre', 'Nombre'),
  ],
  StatisticsRankingType.memberInactivity: [
    ('diasSinVisita', 'Días sin visita'),
    ('visitas', 'Visitas'),
    ('nombre', 'Nombre'),
  ],
  StatisticsRankingType.memberTrainerChanges: [
    ('cambios', 'Cambios'),
    ('nombre', 'Nombre'),
  ],
  StatisticsRankingType.memberValue: [
    ('total', 'Valor aportado'),
    ('nombre', 'Nombre'),
  ],
};
