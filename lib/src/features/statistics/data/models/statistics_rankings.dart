library;

import 'member_statistics.dart' show NamedCount;
import 'statistics_comparison.dart';
import 'statistics_ranking_page.dart' show StatisticsRankingType;

int _int(Map<dynamic, dynamic> json, String key) =>
    (json[key] as num?)?.toInt() ?? 0;
double _double(Map<dynamic, dynamic> json, String key) =>
    (json[key] as num?)?.toDouble() ?? 0;
String _text(Map<dynamic, dynamic> json, String key) =>
    json[key]?.toString() ?? '';

class RankingsPeriod {
  const RankingsPeriod({
    required this.days,
    required this.from,
    required this.to,
  });
  factory RankingsPeriod.fromJson(Map<dynamic, dynamic> json) => RankingsPeriod(
    days: _int(json, 'dias'),
    from: _text(json, 'desde'),
    to: _text(json, 'hasta'),
  );
  final int days;
  final String from;
  final String to;
}

class RankingsSummary {
  const RankingsSummary({
    required this.registered,
    required this.active,
    required this.covered,
    required this.under18,
    required this.missingBirthDate,
    required this.bySex,
  });
  factory RankingsSummary.fromJson(Map<dynamic, dynamic> json) =>
      RankingsSummary(
        registered: _int(json, 'sociosRegistrados'),
        active: _int(json, 'sociosActivos'),
        covered: _int(json, 'sociosConCobertura'),
        under18: _int(json, 'menores18'),
        missingBirthDate: _int(json, 'sinFechaNacimiento'),
        bySex: (json['porSexo'] as List? ?? const [])
            .map(
              (item) => NamedCount(
                _text(item as Map, 'etiqueta'),
                _int(item, 'total'),
              ),
            )
            .toList(growable: false),
      );
  final int registered;
  final int active;
  final int covered;
  final int under18;
  final int missingBirthDate;
  final List<NamedCount> bySex;
}

class PlanRankingRow {
  const PlanRankingRow({
    required this.id,
    required this.name,
    required this.sold,
    required this.covered,
    required this.renewals,
    this.comparison = StatisticsMetricComparison.empty,
  });
  factory PlanRankingRow.fromJson(Map<dynamic, dynamic> json) => PlanRankingRow(
    id: _text(json, 'id'),
    name: _text(json, 'nombre'),
    sold: _int(json, 'vendidos'),
    covered: _int(json, 'sociosConCobertura'),
    renewals: _int(json, 'renovaciones'),
    comparison: StatisticsMetricComparison.fromJson(
      json['comparacion'] as Map? ?? const {},
    ),
  );
  final String id;
  final String name;
  final int sold;
  final int covered;
  final int renewals;
  final StatisticsMetricComparison comparison;
}

class TrainerRankingRow {
  const TrainerRankingRow({
    required this.id,
    required this.name,
    required this.activePortfolio,
    required this.gained,
    required this.lost,
    this.comparison = StatisticsMetricComparison.empty,
  });
  factory TrainerRankingRow.fromJson(Map<dynamic, dynamic> json) =>
      TrainerRankingRow(
        id: _text(json, 'id'),
        name: _text(json, 'nombre'),
        activePortfolio: _int(json, 'carteraActiva'),
        gained: _int(json, 'ganados'),
        lost: _int(json, 'perdidos'),
        comparison: StatisticsMetricComparison.fromJson(
          json['comparacion'] as Map? ?? const {},
        ),
      );
  final String id;
  final String name;
  final int activePortfolio;
  final int gained;
  final int lost;
  final StatisticsMetricComparison comparison;
}

class MemberAttendanceRankingRow {
  const MemberAttendanceRankingRow({
    required this.ci,
    required this.name,
    required this.visits,
    required this.daysWithoutVisit,
    required this.lastVisit,
    this.comparison = StatisticsMetricComparison.empty,
  });
  factory MemberAttendanceRankingRow.fromJson(Map<dynamic, dynamic> json) =>
      MemberAttendanceRankingRow(
        ci: _text(json, 'ci'),
        name: _text(json, 'nombre'),
        visits: _int(json, 'visitas'),
        daysWithoutVisit: _int(json, 'diasSinVisita'),
        lastVisit: json['ultimaVisita']?.toString(),
        comparison: StatisticsMetricComparison.fromJson(
          json['comparacion'] as Map? ?? const {},
        ),
      );
  final String ci;
  final String name;
  final int visits;
  final int daysWithoutVisit;
  final String? lastVisit;
  final StatisticsMetricComparison comparison;
}

class MemberTrainerChangeRankingRow {
  const MemberTrainerChangeRankingRow({
    required this.ci,
    required this.name,
    required this.changes,
    this.comparison = StatisticsMetricComparison.empty,
  });
  factory MemberTrainerChangeRankingRow.fromJson(Map<dynamic, dynamic> json) =>
      MemberTrainerChangeRankingRow(
        ci: _text(json, 'ci'),
        name: _text(json, 'nombre'),
        changes: _int(json, 'cambios'),
        comparison: StatisticsMetricComparison.fromJson(
          json['comparacion'] as Map? ?? const {},
        ),
      );
  final String ci;
  final String name;
  final int changes;
  final StatisticsMetricComparison comparison;
}

class MemberValueRankingRow {
  const MemberValueRankingRow({
    required this.ci,
    required this.name,
    required this.currencyId,
    required this.total,
    this.comparison = StatisticsMetricComparison.empty,
  });
  factory MemberValueRankingRow.fromJson(Map<dynamic, dynamic> json) =>
      MemberValueRankingRow(
        ci: _text(json, 'ci'),
        name: _text(json, 'nombre'),
        currencyId: _text(json, 'monedaId'),
        total: _double(json, 'total'),
        comparison: StatisticsMetricComparison.fromJson(
          json['comparacion'] as Map? ?? const {},
        ),
      );
  final String ci;
  final String name;
  final String currencyId;
  final double total;
  final StatisticsMetricComparison comparison;
}

class MemberValueRanking {
  const MemberValueRanking({required this.currencyId, required this.ranking});
  factory MemberValueRanking.fromJson(Map<dynamic, dynamic> json) =>
      MemberValueRanking(
        currencyId: _text(json, 'monedaId'),
        ranking: (json['ranking'] as List? ?? const [])
            .map((item) => MemberValueRankingRow.fromJson(item as Map))
            .toList(growable: false),
      );
  final String currencyId;
  final List<MemberValueRankingRow> ranking;
}

enum StatisticsAlertSeverity {
  warning('aviso'),
  danger('peligro');

  const StatisticsAlertSeverity(this.apiValue);
  final String apiValue;

  static StatisticsAlertSeverity parse(String value) =>
      StatisticsAlertSeverity.values.firstWhere(
        (severity) => severity.apiValue == value,
        orElse: () => StatisticsAlertSeverity.warning,
      );
}

/// Adónde lleva la tarjeta que explica el aviso.
///
/// Puede no existir: hoy no hay ranking de mora ni lista filtrada por hueco de
/// datos. Antes que un destino que no explica la cifra, ninguno.
class StatisticsAlertTarget {
  const StatisticsAlertTarget({required this.kind, this.ranking, this.id});

  static StatisticsAlertTarget? fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return null;
    final kind = _text(json, 'tipo');
    if (kind.isEmpty) return null;
    final rankingValue = json['ranking']?.toString();
    return StatisticsAlertTarget(
      kind: kind,
      ranking: rankingValue == null
          ? null
          : StatisticsRankingType.values
                .where((type) => type.apiValue == rankingValue)
                .firstOrNull,
      id: json['id']?.toString(),
    );
  }

  /// `ranking`, `plan` o `entrenador`.
  final String kind;
  final StatisticsRankingType? ranking;
  final String? id;
}

/// Denominador visible de la tasa que dispara el aviso (regla 7 del plan).
class StatisticsAlertSample {
  const StatisticsAlertSample({
    required this.value,
    required this.base,
    required this.label,
  });

  static StatisticsAlertSample? fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return null;
    return StatisticsAlertSample(
      value: _int(json, 'valor'),
      base: _int(json, 'base'),
      label: _text(json, 'etiqueta'),
    );
  }

  final int value;
  final int base;
  final String label;
}

class StatisticsAlert {
  const StatisticsAlert({
    required this.id,
    required this.family,
    required this.severity,
    required this.title,
    required this.detail,
    required this.rule,
    this.comparison,
    this.sample,
    this.magnitude,
    this.currencyId,
    this.target,
  });

  factory StatisticsAlert.fromJson(Map<dynamic, dynamic> json) =>
      StatisticsAlert(
        id: _text(json, 'id'),
        family: _text(json, 'familia'),
        severity: StatisticsAlertSeverity.parse(_text(json, 'severidad')),
        title: _text(json, 'titulo'),
        detail: _text(json, 'detalle'),
        rule: _text(json, 'regla'),
        comparison: json['comparacion'] == null
            ? null
            : StatisticsMetricComparison.fromJson(json['comparacion'] as Map),
        sample: StatisticsAlertSample.fromJson(json['muestra'] as Map?),
        magnitude: (json['magnitud'] as num?)?.toDouble(),
        currencyId: json['monedaId']?.toString(),
        target: StatisticsAlertTarget.fromJson(json['destino'] as Map?),
      );

  final String id;
  final String family;
  final StatisticsAlertSeverity severity;
  final String title;
  final String detail;
  final String rule;
  final StatisticsMetricComparison? comparison;
  final StatisticsAlertSample? sample;

  /// Cuánto se pasó del umbral, en la unidad de su regla. No todas las reglas
  /// comparan contra un período anterior: el churn se compara contra el propio
  /// gimnasio, y sin este campo su gravedad no se podría ordenar.
  final double? magnitude;
  final String? currencyId;
  final StatisticsAlertTarget? target;
}

class StatisticsAlertRule {
  const StatisticsAlertRule({
    required this.family,
    required this.text,
    this.evaluated = true,
  });
  factory StatisticsAlertRule.fromJson(Map<dynamic, dynamic> json) =>
      StatisticsAlertRule(
        family: _text(json, 'familia'),
        text: _text(json, 'texto'),
        // Ausente = evaluada, para no romper con un servidor anterior al campo.
        evaluated: json['evaluada'] != false,
      );
  final String family;
  final String text;

  /// `false` cuando la regla no llegó a mirarse por faltarle su fuente. No es
  /// lo mismo que «todo en orden», y la vista tiene que distinguirlo.
  final bool evaluated;
}

class StatisticsRankings {
  const StatisticsRankings({
    required this.zone,
    required this.businessDay,
    required this.period,
    this.previousPeriod = const RankingsPeriod(days: 0, from: '', to: ''),
    required this.summary,
    required this.plans,
    required this.trainers,
    required this.byVisits,
    required this.byInactivity,
    required this.byTrainerChanges,
    required this.byValue,
    this.alerts = const [],
    this.omittedAlerts = 0,
    this.alertRules = const [],
  });

  factory StatisticsRankings.fromJson(Map<String, dynamic> json) {
    final members = json['socios'] as Map? ?? const {};
    return StatisticsRankings(
      zone: _text(json, 'zona'),
      businessDay: _text(json, 'dia_negocio'),
      period: RankingsPeriod.fromJson(json['periodo'] as Map? ?? const {}),
      previousPeriod: RankingsPeriod.fromJson(
        json['periodoAnterior'] as Map? ?? const {},
      ),
      summary: RankingsSummary.fromJson(json['resumen'] as Map? ?? const {}),
      plans: (json['planes'] as List? ?? const [])
          .map((item) => PlanRankingRow.fromJson(item as Map))
          .toList(growable: false),
      trainers: (json['entrenadores'] as List? ?? const [])
          .map((item) => TrainerRankingRow.fromJson(item as Map))
          .toList(growable: false),
      byVisits: (members['porVisitas'] as List? ?? const [])
          .map((item) => MemberAttendanceRankingRow.fromJson(item as Map))
          .toList(growable: false),
      byInactivity: (members['porInactividad'] as List? ?? const [])
          .map((item) => MemberAttendanceRankingRow.fromJson(item as Map))
          .toList(growable: false),
      byTrainerChanges: (members['porCambiosEntrenador'] as List? ?? const [])
          .map((item) => MemberTrainerChangeRankingRow.fromJson(item as Map))
          .toList(growable: false),
      byValue: (members['porValor'] as List? ?? const [])
          .map((item) => MemberValueRanking.fromJson(item as Map))
          .toList(growable: false),
      alerts: (json['alertas'] as List? ?? const [])
          .map((item) => StatisticsAlert.fromJson(item as Map))
          .toList(growable: false),
      omittedAlerts: _int(json, 'alertasOmitidas'),
      alertRules: (json['reglasAlerta'] as List? ?? const [])
          .map((item) => StatisticsAlertRule.fromJson(item as Map))
          .toList(growable: false),
    );
  }

  final String zone;
  final String businessDay;
  final RankingsPeriod period;
  final RankingsPeriod previousPeriod;
  final RankingsSummary summary;
  final List<PlanRankingRow> plans;
  final List<TrainerRankingRow> trainers;
  final List<MemberAttendanceRankingRow> byVisits;
  final List<MemberAttendanceRankingRow> byInactivity;
  final List<MemberTrainerChangeRankingRow> byTrainerChanges;
  final List<MemberValueRanking> byValue;
  final List<StatisticsAlert> alerts;

  /// Avisos de la misma familia que no caben en el panel, ya contados.
  final int omittedAlerts;

  /// Las reglas evaluadas, se hayan disparado o no: el panel vacío tiene que
  /// poder decir qué llegó a mirar.
  final List<StatisticsAlertRule> alertRules;
}
