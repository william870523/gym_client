/// Modelos de la fase E3-b (docs/PLAN_ESTADISTICAS.md §4.3, §5.2 y §5.3):
/// cohortes de alta con retención a 30/60/90 días, mapa de demanda observada
/// día × hora y panel de calidad de datos.
///
/// Los tres comparten una disciplina: **el servidor manda las cifras y también
/// las definiciones**. La vista no reconstruye una tasa, no decide un umbral y
/// no inventa una etiqueta; si el servidor no manda un dato, la vista dice que
/// falta en vez de dibujar un cero.
library;

int _int(Map<dynamic, dynamic> json, String key) =>
    (json[key] as num?)?.toInt() ?? 0;
double? _doubleOrNull(Map<dynamic, dynamic> json, String key) =>
    (json[key] as num?)?.toDouble();
String _text(Map<dynamic, dynamic> json, String key) =>
    json[key]?.toString() ?? '';
List<String> _texts(Map<dynamic, dynamic> json, String key) =>
    (json[key] as List? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false);

/// Período consultado, tal como lo resolvió el servidor en la zona de la sede.
class StatsPeriod {
  const StatsPeriod({required this.days, required this.from, required this.to});

  factory StatsPeriod.fromJson(Map<dynamic, dynamic> json) => StatsPeriod(
    days: _int(json, 'dias'),
    from: _text(json, 'desde'),
    to: _text(json, 'hasta'),
  );

  final int days;
  final String from;
  final String to;
}

// --- Cohortes de alta --------------------------------------------------------

/// Un horizonte de una cohorte: cuántos seguían siendo socios a los N días.
///
/// `mature` es el denominador y viaja siempre (regla 7). `open` son los socios
/// cuya ventana el motor todavía no ha podido decidir: ni cuentan a favor ni en
/// contra, y por eso `ratePct` puede ser nulo sin que eso signifique cero.
class CohortHorizon {
  const CohortHorizon({
    required this.days,
    required this.mature,
    required this.retained,
    required this.lost,
    required this.open,
    required this.ratePct,
    required this.lowSample,
  });

  factory CohortHorizon.fromJson(Map<dynamic, dynamic> json) => CohortHorizon(
    days: _int(json, 'dias'),
    mature: _int(json, 'maduras'),
    retained: _int(json, 'retenidas'),
    lost: _int(json, 'bajas'),
    open: _int(json, 'abiertas'),
    ratePct: _doubleOrNull(json, 'tasaPct'),
    lowSample: json['muestraBaja'] == true,
  );

  final int days;
  final int mature;
  final int retained;
  final int lost;
  final int open;
  final double? ratePct;
  final bool lowSample;

  /// `true` cuando el horizonte aún no ha podido cerrarse para nadie.
  bool get fullyOpen => mature == 0 && open > 0;
}

/// Mediana con su denominador al lado. Sin la base, «60 días» no dice de
/// cuántos socios se está hablando.
class CohortMedian {
  const CohortMedian({
    required this.members,
    required this.base,
    required this.medianDays,
  });

  factory CohortMedian.fromJson(Map<dynamic, dynamic>? json) => CohortMedian(
    members: json == null ? 0 : _int(json, 'socios'),
    base: json == null ? 0 : _int(json, 'base'),
    medianDays: json == null ? null : _doubleOrNull(json, 'medianaDias'),
  );

  final int members;
  final int base;
  final double? medianDays;
}

class Cohort {
  const Cohort({
    required this.key,
    required this.label,
    required this.start,
    required this.end,
    required this.entries,
    required this.horizons,
    required this.firstRenewal,
    required this.timeToLeave,
  });

  factory Cohort.fromJson(Map<dynamic, dynamic> json) => Cohort(
    key: _text(json, 'clave'),
    label: _text(json, 'etiqueta'),
    start: _text(json, 'inicio'),
    end: _text(json, 'fin'),
    entries: _int(json, 'altas'),
    horizons: (json['horizontes'] as List? ?? const [])
        .map((item) => CohortHorizon.fromJson(item as Map))
        .toList(growable: false),
    firstRenewal: CohortMedian.fromJson(json['primeraRenovacion'] as Map?),
    timeToLeave: CohortMedian.fromJson(json['tiempoHastaBaja'] as Map?),
  );

  final String key;
  final String label;
  final String start;
  final String end;
  final int entries;
  final List<CohortHorizon> horizons;
  final CohortMedian firstRenewal;
  final CohortMedian timeToLeave;

  CohortHorizon? horizonOf(int days) {
    for (final horizon in horizons) {
      if (horizon.days == days) return horizon;
    }
    return null;
  }
}

class CohortsReport {
  const CohortsReport({
    required this.zone,
    required this.businessDay,
    required this.period,
    required this.granularity,
    required this.horizons,
    required this.definition,
    required this.available,
    required this.reason,
    required this.graceDays,
    required this.maturityCutoff,
    required this.cohorts,
    required this.totalEntries,
    required this.totalHorizons,
    required this.membersWithoutEntry,
    required this.warnings,
  });

  factory CohortsReport.fromJson(Map<String, dynamic> json) {
    final policy = json['politica'] as Map?;
    final totals = json['totales'] as Map?;
    final coverage = json['cobertura'] as Map?;
    return CohortsReport(
      zone: _text(json, 'zona'),
      businessDay: _text(json, 'dia_negocio'),
      period: StatsPeriod.fromJson((json['periodo'] as Map?) ?? const {}),
      granularity: _text(json, 'granularidad'),
      horizons: (json['horizontes'] as List? ?? const [])
          .map((item) => (item as num).toInt())
          .toList(growable: false),
      definition: _text(json, 'definicion'),
      available: json['disponible'] == true,
      reason: json['motivo']?.toString(),
      graceDays: policy == null ? null : _int(policy, 'diasGracia'),
      maturityCutoff: policy == null ? null : _text(policy, 'corteMadurez'),
      cohorts: (json['cohortes'] as List? ?? const [])
          .map((item) => Cohort.fromJson(item as Map))
          .toList(growable: false),
      totalEntries: totals == null ? 0 : _int(totals, 'altas'),
      totalHorizons: ((totals?['horizontes'] as List?) ?? const [])
          .map((item) => CohortHorizon.fromJson(item as Map))
          .toList(growable: false),
      membersWithoutEntry: coverage == null
          ? 0
          : _int(coverage, 'sociosSinAltaIdentificable'),
      warnings: _texts(json, 'advertencias'),
    );
  }

  final String zone;
  final String businessDay;
  final StatsPeriod period;
  final String granularity;
  final List<int> horizons;
  final String definition;

  /// `false` cuando el motor canónico de retención no está conectado. Sin él no
  /// hay cohorte: la supervivencia no se calcula por segunda vía.
  final bool available;
  final String? reason;
  final int? graceDays;
  final String? maturityCutoff;
  final List<Cohort> cohorts;
  final int totalEntries;
  final List<CohortHorizon> totalHorizons;
  final int membersWithoutEntry;
  final List<String> warnings;

  CohortHorizon? totalHorizonOf(int days) {
    for (final horizon in totalHorizons) {
      if (horizon.days == days) return horizon;
    }
    return null;
  }
}

// --- Mapa de demanda ---------------------------------------------------------

class DemandCell {
  const DemandCell({
    required this.weekday,
    required this.visits,
    required this.members,
  });

  factory DemandCell.fromJson(Map<dynamic, dynamic> json) => DemandCell(
    weekday: _int(json, 'diaSemana'),
    visits: _int(json, 'visitas'),
    members: _int(json, 'socios'),
  );

  final int weekday;
  final int visits;
  final int members;
}

class DemandRow {
  const DemandRow({
    required this.hour,
    required this.label,
    required this.cells,
  });

  factory DemandRow.fromJson(Map<dynamic, dynamic> json) => DemandRow(
    hour: _int(json, 'hora'),
    label: _text(json, 'etiqueta'),
    cells: (json['celdas'] as List? ?? const [])
        .map((item) => DemandCell.fromJson(item as Map))
        .toList(growable: false),
  );

  final int hour;
  final String label;
  final List<DemandCell> cells;
}

class DemandPeak {
  const DemandPeak({
    required this.day,
    required this.hourLabel,
    required this.visits,
    required this.members,
    required this.sharePct,
  });

  factory DemandPeak.fromJson(Map<dynamic, dynamic> json) => DemandPeak(
    day: _text(json, 'dia'),
    hourLabel: _text(json, 'etiquetaHora'),
    visits: _int(json, 'visitas'),
    members: _int(json, 'socios'),
    sharePct: _doubleOrNull(json, 'participacionPct'),
  );

  final String day;
  final String hourLabel;
  final int visits;
  final int members;
  final double? sharePct;
}

/// Un socio que declaró una franja y viene en otra. Es el dato que nadie pide
/// hasta que lo ve (regla 9 del plan).
class FranjaMismatch {
  const FranjaMismatch({
    required this.ci,
    required this.name,
    required this.declared,
    required this.scheduleName,
    required this.observed,
    required this.visits,
  });

  factory FranjaMismatch.fromJson(Map<dynamic, dynamic> json) => FranjaMismatch(
    ci: _text(json, 'ci'),
    name: _text(json, 'nombre'),
    declared: _text(json, 'declarada'),
    scheduleName: json['horarioNombre']?.toString(),
    observed: _text(json, 'observada'),
    visits: _int(json, 'visitas'),
  );

  final String ci;
  final String name;
  final String declared;
  final String? scheduleName;
  final String observed;
  final int visits;
}

class DemandReport {
  const DemandReport({
    required this.zone,
    required this.businessDay,
    required this.period,
    required this.measure,
    required this.definition,
    required this.visits,
    required this.members,
    required this.visitsPerMember,
    required this.dailyAverage,
    required this.dayLabels,
    required this.rows,
    required this.peaks,
    required this.observedFranjas,
    required this.declaredFranjas,
    required this.comparable,
    required this.matching,
    required this.matchPct,
    required this.withoutDeclared,
    required this.withoutVisits,
    required this.mismatches,
    required this.mismatchTotal,
    required this.withoutInstant,
    required this.openVisits,
    required this.truncated,
    required this.warnings,
  });

  factory DemandReport.fromJson(Map<String, dynamic> json) {
    final summary = (json['resumen'] as Map?) ?? const {};
    final map = (json['mapa'] as Map?) ?? const {};
    final comparison = (json['declaradaVsObservada'] as Map?) ?? const {};
    final quality = (json['calidad'] as Map?) ?? const {};
    return DemandReport(
      zone: _text(json, 'zona'),
      businessDay: _text(json, 'dia_negocio'),
      period: StatsPeriod.fromJson((json['periodo'] as Map?) ?? const {}),
      measure: _text(json, 'medida'),
      definition: _text(json, 'definicion'),
      visits: _int(summary, 'visitas'),
      members: _int(summary, 'socios'),
      visitsPerMember: _doubleOrNull(summary, 'visitasPorSocio'),
      dailyAverage: _doubleOrNull(summary, 'mediaDiaria'),
      dayLabels: ((map['dias'] as List?) ?? const [])
          .map((item) => _text(item as Map, 'corto'))
          .toList(growable: false),
      rows: ((map['filas'] as List?) ?? const [])
          .map((item) => DemandRow.fromJson(item as Map))
          .toList(growable: false),
      peaks: (json['picos'] as List? ?? const [])
          .map((item) => DemandPeak.fromJson(item as Map))
          .toList(growable: false),
      observedFranjas: (json['porFranjaObservada'] as List? ?? const [])
          .map(
            (item) => (
              franja: _text(item as Map, 'franja'),
              value: _int(item, 'visitas'),
              sharePct: _doubleOrNull(item, 'participacionPct'),
            ),
          )
          .toList(growable: false),
      declaredFranjas: (json['porFranjaDeclarada'] as List? ?? const [])
          .map(
            (item) => (
              franja: _text(item as Map, 'franja'),
              value: _int(item, 'socios'),
              sharePct: _doubleOrNull(item, 'participacionPct'),
            ),
          )
          .toList(growable: false),
      comparable: _int(comparison, 'comparables'),
      matching: _int(comparison, 'coinciden'),
      matchPct: _doubleOrNull(comparison, 'coincidenciaPct'),
      withoutDeclared: _int(comparison, 'sinDeclarar'),
      withoutVisits: _int(comparison, 'sinVisitas'),
      mismatches: ((comparison['discrepan'] as List?) ?? const [])
          .map((item) => FranjaMismatch.fromJson(item as Map))
          .toList(growable: false),
      mismatchTotal: _int(comparison, 'discrepanTotal'),
      withoutInstant: _int(quality, 'sinInstante'),
      openVisits: _int(quality, 'abiertas'),
      truncated: quality['truncado'] == true,
      warnings: _texts(json, 'advertencias'),
    );
  }

  final String zone;
  final String businessDay;
  final StatsPeriod period;

  /// Siempre «demanda observada». No hay porcentaje de ocupación mientras no
  /// exista aforo por sede o franja (§5.2).
  final String measure;
  final String definition;
  final int visits;
  final int members;
  final double? visitsPerMember;
  final double? dailyAverage;
  final List<String> dayLabels;
  final List<DemandRow> rows;
  final List<DemandPeak> peaks;
  final List<({String franja, int value, double? sharePct})> observedFranjas;
  final List<({String franja, int value, double? sharePct})> declaredFranjas;
  final int comparable;
  final int matching;
  final double? matchPct;
  final int withoutDeclared;
  final int withoutVisits;
  final List<FranjaMismatch> mismatches;
  final int mismatchTotal;
  final int withoutInstant;
  final int openVisits;
  final bool truncated;
  final List<String> warnings;

  bool get isEmpty => rows.isEmpty;
}

// --- Calidad de datos --------------------------------------------------------

enum QualitySeverity {
  danger,
  warning,
  ok;

  static QualitySeverity parse(String value) => switch (value) {
    'peligro' => QualitySeverity.danger,
    'aviso' => QualitySeverity.warning,
    _ => QualitySeverity.ok,
  };
}

/// A dónde lleva un control cuando existe un sitio donde arreglarlo. Puede no
/// existir, y entonces no se finge uno.
class QualityTarget {
  const QualityTarget({required this.kind, this.attribute, this.value});

  static QualityTarget? fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return null;
    final kind = _text(json, 'tipo');
    if (kind.isEmpty) return null;
    return QualityTarget(
      kind: kind,
      attribute: json['atributo']?.toString(),
      value: json['valor']?.toString(),
    );
  }

  /// `clientes` o `retencion`.
  final String kind;
  final String? attribute;
  final String? value;
}

class QualityControl {
  const QualityControl({
    required this.id,
    required this.family,
    required this.title,
    required this.detail,
    required this.rule,
    required this.affected,
    required this.base,
    required this.coveragePct,
    required this.severity,
    required this.target,
  });

  factory QualityControl.fromJson(Map<dynamic, dynamic> json) => QualityControl(
    id: _text(json, 'id'),
    family: _text(json, 'familia'),
    title: _text(json, 'titulo'),
    detail: _text(json, 'detalle'),
    rule: _text(json, 'regla'),
    affected: _int(json, 'afectados'),
    base: _int(json, 'base'),
    coveragePct: _doubleOrNull(json, 'coberturaPct'),
    severity: QualitySeverity.parse(_text(json, 'severidad')),
    target: QualityTarget.fromJson(json['destino'] as Map?),
  );

  final String id;
  final String family;
  final String title;
  final String detail;

  /// El criterio con el que se juzgó. Un aviso sin su regla es una opinión.
  final String rule;
  final int affected;
  final int base;
  final double? coveragePct;
  final QualitySeverity severity;
  final QualityTarget? target;
}

class QualityReport {
  const QualityReport({
    required this.zone,
    required this.businessDay,
    required this.period,
    required this.controls,
    required this.danger,
    required this.warning,
    required this.ok,
    required this.dropoutsEvaluated,
    required this.dropoutsReason,
    required this.dropoutsTotal,
    required this.warnings,
  });

  factory QualityReport.fromJson(Map<String, dynamic> json) {
    final summary = (json['resumen'] as Map?) ?? const {};
    final dropouts = (json['bajas'] as Map?) ?? const {};
    return QualityReport(
      zone: _text(json, 'zona'),
      businessDay: _text(json, 'dia_negocio'),
      period: StatsPeriod.fromJson((json['periodo'] as Map?) ?? const {}),
      controls: (json['controles'] as List? ?? const [])
          .map((item) => QualityControl.fromJson(item as Map))
          .toList(growable: false),
      danger: _int(summary, 'peligro'),
      warning: _int(summary, 'aviso'),
      ok: _int(summary, 'ok'),
      dropoutsEvaluated: dropouts['evaluada'] == true,
      dropoutsReason: dropouts['motivo']?.toString(),
      dropoutsTotal: _int(dropouts, 'total'),
      warnings: _texts(json, 'advertencias'),
    );
  }

  final String zone;
  final String businessDay;
  final StatsPeriod period;
  final List<QualityControl> controls;
  final int danger;
  final int warning;
  final int ok;

  /// `false` cuando el motor canónico no respondió: la familia «bajas» no se
  /// enseña en cero, se declara sin evaluar (regla 11).
  final bool dropoutsEvaluated;
  final String? dropoutsReason;
  final int dropoutsTotal;
  final List<String> warnings;
}
