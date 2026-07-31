/// Perfil estadístico de un entrenador, tal como lo devuelve
/// `GET /estadisticas/entrenador/:id` (docs/PLAN_ESTADISTICAS.md §4.1).
///
/// La cartera sale de `MembresiaEntrenadorAsignacion`, no de la proyección
/// vigente en `Cliente.id_entrenador`: la segunda solo dice a quién atiende
/// **hoy**, así que con ella ningún entrenador habría perdido nunca a nadie.
library;

import 'member_statistics.dart' show NamedCount, StatRate;

class TrainerIdentity {
  const TrainerIdentity({
    required this.id,
    required this.nombre,
    required this.sexo,
    required this.activo,
    required this.antiguedadDias,
  });

  factory TrainerIdentity.fromJson(Map<String, dynamic> json) =>
      TrainerIdentity(
        id: json['id']?.toString() ?? '',
        nombre: json['nombre']?.toString() ?? '',
        sexo: json['sexo']?.toString() ?? '',
        activo: json['activo'] == true,
        antiguedadDias: (json['antiguedadDias'] as num?)?.toInt(),
      );

  final String id;
  final String nombre;
  final String sexo;
  final bool activo;
  final int? antiguedadDias;
}

/// Altas y bajas de asignación en un mes. Las dos juntas: solo las altas
/// dibujan un entrenador que nunca pierde a nadie.
class TrainerMonthlyFlow {
  const TrainerMonthlyFlow({
    required this.mes,
    required this.altas,
    required this.bajas,
  });

  factory TrainerMonthlyFlow.fromJson(Map<String, dynamic> json) =>
      TrainerMonthlyFlow(
        mes: json['mes']?.toString() ?? '',
        altas: (json['altas'] as num?)?.toInt() ?? 0,
        bajas: (json['bajas'] as num?)?.toInt() ?? 0,
      );

  final String mes;
  final int altas;
  final int bajas;

  int get neto => altas - bajas;
}

class TrainerPortfolio {
  const TrainerPortfolio({
    required this.activos,
    required this.historicos,
    required this.perdidos,
    required this.movimientos,
    required this.motivosDeCierre,
  });

  factory TrainerPortfolio.fromJson(Map<String, dynamic> json) =>
      TrainerPortfolio(
        activos: (json['activos'] as num?)?.toInt() ?? 0,
        historicos: (json['historicos'] as num?)?.toInt() ?? 0,
        perdidos: (json['perdidos'] as num?)?.toInt() ?? 0,
        movimientos: (json['movimientos'] as List? ?? const [])
            .map(
              (e) => TrainerMonthlyFlow.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(growable: false),
        motivosDeCierre: (json['motivosDeCierre'] as List? ?? const [])
            .map(
              (e) => NamedCount(
                (e as Map)['motivo']?.toString() ?? '',
                (e['total'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList(growable: false),
      );

  final int activos;
  final int historicos;
  final int perdidos;
  final List<TrainerMonthlyFlow> movimientos;
  final List<NamedCount> motivosDeCierre;
}

class TrainerComposition {
  const TrainerComposition({
    required this.porSexo,
    required this.porCategoria,
    required this.porFranja,
    required this.porPlan,
    required this.porNacionalidad,
    required this.planLider,
  });

  factory TrainerComposition.fromJson(Map<String, dynamic> json) =>
      TrainerComposition(
        porSexo: _etiquetados(json['porSexo']),
        porCategoria: _etiquetados(json['porCategoria']),
        porFranja: _etiquetados(json['porFranja']),
        porPlan: _etiquetados(json['porPlan']),
        porNacionalidad: _etiquetados(json['porNacionalidad']),
        planLider: json['planLider'] == null
            ? null
            : _unoEtiquetado(
                Map<String, dynamic>.from(json['planLider'] as Map),
              ),
      );

  final List<NamedCount> porSexo;
  final List<NamedCount> porCategoria;
  final List<NamedCount> porFranja;
  final List<NamedCount> porPlan;
  final List<NamedCount> porNacionalidad;
  final NamedCount? planLider;
}

class TrainerTopMember {
  const TrainerTopMember({
    required this.ci,
    required this.nombre,
    required this.visitas,
  });

  factory TrainerTopMember.fromJson(Map<String, dynamic> json) =>
      TrainerTopMember(
        ci: json['ci']?.toString() ?? '',
        nombre: json['nombre']?.toString() ?? '',
        visitas: (json['visitas'] as num?)?.toInt() ?? 0,
      );

  final String ci;
  final String nombre;
  final int visitas;
}

class TrainerIncome {
  const TrainerIncome({
    required this.monedaId,
    required this.cobros,
    required this.total,
    required this.ticketMedio,
  });

  factory TrainerIncome.fromJson(Map<String, dynamic> json) => TrainerIncome(
    monedaId: json['monedaId']?.toString() ?? '',
    cobros: (json['cobros'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toDouble() ?? 0,
    ticketMedio: (json['ticketMedio'] as num?)?.toDouble() ?? 0,
  );

  final String monedaId;
  final int cobros;
  final double total;
  final double ticketMedio;
}

class TrainerStatistics {
  const TrainerStatistics({
    required this.zona,
    required this.diaNegocio,
    required this.entrenador,
    required this.cartera,
    required this.composicion,
    required this.masConstantes,
    required this.visitasMediasPorSocio,
    required this.retencion,
    required this.ingresos,
  });

  factory TrainerStatistics.fromJson(Map<String, dynamic> json) {
    final constancia = Map<String, dynamic>.from(
      json['constancia'] as Map? ?? const {},
    );
    return TrainerStatistics(
      zona: json['zona']?.toString() ?? '',
      diaNegocio: json['dia_negocio']?.toString() ?? '',
      entrenador: TrainerIdentity.fromJson(
        Map<String, dynamic>.from(json['entrenador'] as Map? ?? const {}),
      ),
      cartera: TrainerPortfolio.fromJson(
        Map<String, dynamic>.from(json['cartera'] as Map? ?? const {}),
      ),
      composicion: TrainerComposition.fromJson(
        Map<String, dynamic>.from(json['composicion'] as Map? ?? const {}),
      ),
      masConstantes: (constancia['masConstantes'] as List? ?? const [])
          .map(
            (e) =>
                TrainerTopMember.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(growable: false),
      visitasMediasPorSocio: (constancia['visitasMediasPorSocio'] as num?)
          ?.toInt(),
      retencion: StatRate.fromJson(
        Map<String, dynamic>.from(json['retencion'] as Map? ?? const {}),
      ),
      ingresos: (json['ingresos'] as List? ?? const [])
          .map(
            (e) => TrainerIncome.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(growable: false),
    );
  }

  /// Zona en que el servidor agrupó meses y franjas. Se enseña al pie: sin ella
  /// «viene por la mañana» no es comprobable.
  final String zona;
  final String diaNegocio;
  final TrainerIdentity entrenador;
  final TrainerPortfolio cartera;
  final TrainerComposition composicion;
  final List<TrainerTopMember> masConstantes;

  /// Media sobre los socios que se muestran, no sobre la cartera entera.
  final int? visitasMediasPorSocio;
  final StatRate retencion;

  /// Ingreso atribuido, **una entrada por moneda**. Nunca hay un total sumado.
  final List<TrainerIncome> ingresos;
}

List<NamedCount> _etiquetados(Object? bruto) {
  return (bruto as List? ?? const [])
      .map((e) => _unoEtiquetado(Map<String, dynamic>.from(e as Map)))
      .toList(growable: false);
}

NamedCount _unoEtiquetado(Map<String, dynamic> json) => NamedCount(
  json['etiqueta']?.toString() ?? '',
  (json['total'] as num?)?.toInt() ?? 0,
);
