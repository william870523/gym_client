library;

int _int(Map<dynamic, dynamic> json, String key) =>
    (json[key] as num?)?.toInt() ?? 0;
double _double(Map<dynamic, dynamic> json, String key) =>
    (json[key] as num?)?.toDouble() ?? 0;
String _text(Map<dynamic, dynamic> json, String key) =>
    json[key]?.toString() ?? '';

/// Un eje por el que agrupar. La lista la manda el servidor: la vista no puede
/// inventarse dimensiones que el cálculo no sepa resolver.
class SegmentationDimension {
  const SegmentationDimension({required this.id, required this.title});
  factory SegmentationDimension.fromJson(Map<dynamic, dynamic> json) =>
      SegmentationDimension(
        id: _text(json, 'dimension'),
        title: _text(json, 'titulo'),
      );
  final String id;
  final String title;
}

/// Una medida, con su definición exacta. La definición viaja con el dato
/// porque es parte del contrato semántico, no un adorno.
class SegmentationMeasure {
  const SegmentationMeasure({
    required this.id,
    required this.title,
    required this.money,
    required this.rate,
    required this.ignoresPeriod,
    required this.definition,
  });
  factory SegmentationMeasure.fromJson(Map<dynamic, dynamic> json) =>
      SegmentationMeasure(
        id: _text(json, 'medida'),
        title: _text(json, 'titulo'),
        money: json['dinero'] == true,
        rate: json['tasa'] == true,
        ignoresPeriod: json['ignoraPeriodo'] == true,
        definition: _text(json, 'definicion'),
      );
  final String id;
  final String title;
  final bool money;
  final bool rate;
  final bool ignoresPeriod;
  final String definition;
}

class SegmentationCatalog {
  const SegmentationCatalog({
    required this.dimensions,
    required this.measures,
  });
  factory SegmentationCatalog.fromJson(Map<String, dynamic> json) =>
      SegmentationCatalog(
        dimensions: (json['dimensiones'] as List? ?? const [])
            .map((item) => SegmentationDimension.fromJson(item as Map))
            .toList(growable: false),
        measures: (json['medidas'] as List? ?? const [])
            .map((item) => SegmentationMeasure.fromJson(item as Map))
            .toList(growable: false),
      );
  final List<SegmentationDimension> dimensions;
  final List<SegmentationMeasure> measures;

  SegmentationMeasure? measureById(String id) {
    for (final measure in measures) {
      if (measure.id == id) return measure;
    }
    return null;
  }
}

class SegmentationRow {
  const SegmentationRow({
    required this.key,
    required this.label,
    required this.value,
    this.numerator,
    this.denominator,
    this.share,
    this.lowSample = false,
  });
  factory SegmentationRow.fromJson(Map<dynamic, dynamic> json) =>
      SegmentationRow(
        key: _text(json, 'clave'),
        label: _text(json, 'etiqueta'),
        value: _double(json, 'valor'),
        numerator: (json['numerador'] as num?)?.toDouble(),
        denominator: (json['denominador'] as num?)?.toDouble(),
        share: (json['participacion'] as num?)?.toDouble(),
        lowSample: json['muestraBaja'] == true,
      );
  final String key;
  final String label;
  final double value;

  /// Solo en las tasas: sin denominador un porcentaje no se puede leer.
  final double? numerator;
  final double? denominator;
  final double? share;
  final bool lowSample;
}

class SegmentationPeriod {
  const SegmentationPeriod({
    required this.days,
    required this.from,
    required this.to,
    required this.applies,
  });
  factory SegmentationPeriod.fromJson(Map<dynamic, dynamic> json) =>
      SegmentationPeriod(
        days: _int(json, 'dias'),
        from: _text(json, 'desde'),
        to: _text(json, 'hasta'),
        applies: json['aplica'] != false,
      );
  final int days;
  final String from;
  final String to;

  /// El padrón es un stock: el período no lo recorta y hay que decirlo.
  final bool applies;
}

class SegmentationResult {
  const SegmentationResult({
    required this.zone,
    required this.businessDay,
    required this.period,
    required this.dimension,
    required this.dimensionTitle,
    required this.measure,
    required this.measureTitle,
    required this.definition,
    required this.money,
    required this.rate,
    required this.compatible,
    required this.rows,
    this.currencyId,
    this.reason,
    this.total,
  });

  factory SegmentationResult.fromJson(Map<String, dynamic> json) =>
      SegmentationResult(
        zone: _text(json, 'zona'),
        businessDay: _text(json, 'dia_negocio'),
        period: SegmentationPeriod.fromJson(
          json['periodo'] as Map? ?? const {},
        ),
        dimension: _text(json, 'dimension'),
        dimensionTitle: _text(json, 'dimensionTitulo'),
        measure: _text(json, 'medida'),
        measureTitle: _text(json, 'medidaTitulo'),
        definition: _text(json, 'definicion'),
        money: json['dinero'] == true,
        rate: json['tasa'] == true,
        compatible: json['compatible'] == true,
        currencyId: json['monedaId']?.toString(),
        reason: json['motivo']?.toString(),
        total: (json['total'] as num?)?.toDouble(),
        rows: (json['filas'] as List? ?? const [])
            .map((item) => SegmentationRow.fromJson(item as Map))
            .toList(growable: false),
      );

  final String zone;
  final String businessDay;
  final SegmentationPeriod period;
  final String dimension;
  final String dimensionTitle;
  final String measure;
  final String measureTitle;
  final String definition;
  final bool money;
  final bool rate;

  /// `false` cuando el cruce no tiene sentido; entonces `reason` lo explica.
  final bool compatible;
  final String? currencyId;
  final String? reason;

  /// `null` en las tasas: sumar medias no da nada.
  final double? total;
  final List<SegmentationRow> rows;
}

/// Lo que la vista tiene seleccionado. Se guarda entero para que el CSV salga
/// con exactamente el mismo filtro que se está mirando.
class SegmentationQuery {
  const SegmentationQuery({
    required this.dimension,
    required this.measure,
    required this.days,
    this.currencyId,
  });

  final String dimension;
  final String measure;
  final int days;
  final String? currencyId;

  SegmentationQuery copyWith({
    String? dimension,
    String? measure,
    int? days,
    String? currencyId,
    bool clearCurrency = false,
  }) => SegmentationQuery(
    dimension: dimension ?? this.dimension,
    measure: measure ?? this.measure,
    days: days ?? this.days,
    currencyId: clearCurrency ? null : (currencyId ?? this.currencyId),
  );

  @override
  bool operator ==(Object other) =>
      other is SegmentationQuery &&
      other.dimension == dimension &&
      other.measure == measure &&
      other.days == days &&
      other.currencyId == currencyId;

  @override
  int get hashCode => Object.hash(dimension, measure, days, currencyId);
}
