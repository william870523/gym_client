/// Perfil estadístico de un plan, tal como lo devuelve
/// `GET /estadisticas/plan/:id` (docs/PLAN_ESTADISTICAS.md §4.2).
///
/// La pieza que no existía en ningún sitio antes es [PlanMobility]: a qué plan
/// se van los que dejan éste y de cuál vienen los que llegan. Un plan puede
/// parecer sano y estar viviendo de canibalizar a otro.
library;

import 'member_statistics.dart' show NamedCount, StatRate;

class PlanIdentity {
  const PlanIdentity({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.importe,
    required this.monedaId,
    required this.duracionDias,
    required this.activo,
    required this.incluyeEntrenador,
    required this.aceptaCuotas,
  });

  factory PlanIdentity.fromJson(Map<String, dynamic> json) => PlanIdentity(
    id: json['id']?.toString() ?? '',
    nombre: json['nombre']?.toString() ?? '',
    codigo: json['codigo']?.toString(),
    importe: (json['importe'] as num?)?.toDouble() ?? 0,
    monedaId: json['monedaId']?.toString() ?? '',
    duracionDias: (json['duracionDias'] as num?)?.toInt() ?? 0,
    activo: json['activo'] == true,
    incluyeEntrenador: json['incluyeEntrenador'] == true,
    aceptaCuotas: json['aceptaCuotas'] == true,
  );

  final String id;
  final String nombre;
  final String? codigo;
  final double importe;
  final String monedaId;
  final int duracionDias;
  final bool activo;
  final bool incluyeEntrenador;
  final bool aceptaCuotas;
}

class PlanContracting {
  const PlanContracting({
    required this.socios,
    required this.vigentes,
    required this.pendientes,
    required this.pausadas,
    required this.terminadas,
    required this.porMes,
    required this.tasaRenovacion,
  });

  factory PlanContracting.fromJson(Map<String, dynamic> json) =>
      PlanContracting(
        socios: (json['socios'] as num?)?.toInt() ?? 0,
        vigentes: (json['vigentes'] as num?)?.toInt() ?? 0,
        pendientes: (json['pendientes'] as num?)?.toInt() ?? 0,
        pausadas: (json['pausadas'] as num?)?.toInt() ?? 0,
        terminadas: (json['terminadas'] as num?)?.toInt() ?? 0,
        porMes: _etiquetados(json['porMes']),
        tasaRenovacion: StatRate.fromJson(
          Map<String, dynamic>.from(json['tasaRenovacion'] as Map? ?? const {}),
        ),
      );

  final int socios;
  final int vigentes;
  final int pendientes;
  final int pausadas;
  final int terminadas;
  final List<NamedCount> porMes;
  final StatRate tasaRenovacion;
}

class PlanComposition {
  const PlanComposition({
    required this.porSexo,
    required this.porCategoria,
    required this.porFranja,
    required this.porEntrenador,
  });

  factory PlanComposition.fromJson(Map<String, dynamic> json) =>
      PlanComposition(
        porSexo: _etiquetados(json['porSexo']),
        porCategoria: _etiquetados(json['porCategoria']),
        porFranja: _etiquetados(json['porFranja']),
        porEntrenador: _etiquetados(json['porEntrenador']),
      );

  final List<NamedCount> porSexo;
  final List<NamedCount> porCategoria;
  final List<NamedCount> porFranja;
  final List<NamedCount> porEntrenador;
}

/// Movilidad entre planes. El dato que revela si un plan capta o alimenta.
class PlanMobility {
  const PlanMobility({
    required this.vienenDe,
    required this.seVanA,
    required this.saldo,
  });

  factory PlanMobility.fromJson(Map<String, dynamic> json) => PlanMobility(
    vienenDe: _etiquetados(json['vienenDe']),
    seVanA: _etiquetados(json['seVanA']),
    saldo: (json['saldo'] as num?)?.toInt() ?? 0,
  );

  /// Planes desde los que llegaron socios a éste.
  final List<NamedCount> vienenDe;

  /// Planes a los que se fueron los que lo dejaron.
  final List<NamedCount> seVanA;

  /// Entradas menos salidas. Positivo = capta socios de otros planes.
  final int saldo;

  int get entran => vienenDe.fold(0, (suma, x) => suma + x.total);
  int get salen => seVanA.fold(0, (suma, x) => suma + x.total);

  /// Sin un solo cambio en ninguna dirección no hay matriz que enseñar.
  bool get vacia => vienenDe.isEmpty && seVanA.isEmpty;
}

class PlanMoney {
  const PlanMoney({
    required this.monedaId,
    required this.cobros,
    required this.total,
    required this.ticketMedio,
    required this.descuentoTotal,
    required this.recargoTotal,
  });

  factory PlanMoney.fromJson(Map<String, dynamic> json) => PlanMoney(
    monedaId: json['monedaId']?.toString() ?? '',
    cobros: (json['cobros'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toDouble() ?? 0,
    ticketMedio: (json['ticketMedio'] as num?)?.toDouble() ?? 0,
    descuentoTotal: (json['descuentoTotal'] as num?)?.toDouble() ?? 0,
    recargoTotal: (json['recargoTotal'] as num?)?.toDouble() ?? 0,
  );

  final String monedaId;
  final int cobros;
  final double total;
  final double ticketMedio;
  final double descuentoTotal;
  final double recargoTotal;
}

class PlanDuration {
  const PlanDuration({
    required this.contratadaDias,
    required this.realMediaDias,
    required this.desviacionDias,
  });

  factory PlanDuration.fromJson(Map<String, dynamic> json) => PlanDuration(
    contratadaDias: (json['contratadaDias'] as num?)?.toInt() ?? 0,
    realMediaDias: (json['realMediaDias'] as num?)?.toDouble(),
    desviacionDias: (json['desviacionDias'] as num?)?.toDouble(),
  );

  final int contratadaDias;

  /// `null` cuando no hay ningún contrato del que medirla.
  final double? realMediaDias;
  final double? desviacionDias;
}

class PlanUsage {
  const PlanUsage({
    required this.visitas,
    required this.sociosConCobertura,
    required this.visitasPorSocio,
  });

  factory PlanUsage.fromJson(Map<String, dynamic> json) => PlanUsage(
    visitas: (json['visitas'] as num?)?.toInt() ?? 0,
    sociosConCobertura:
        (json['sociosConCobertura'] as num?)?.toInt() ??
        (json['sociosVigentes'] as num?)?.toInt() ??
        0,
    visitasPorSocio: (json['visitasPorSocio'] as num?)?.toDouble(),
  );

  final int visitas;
  final int sociosConCobertura;

  /// `null` sin socios cubiertos: no se divide entre cero ni se finge un cero.
  final double? visitasPorSocio;
}

class PlanStatistics {
  const PlanStatistics({
    required this.zona,
    required this.diaNegocio,
    required this.plan,
    required this.contratacion,
    required this.composicion,
    required this.movilidad,
    required this.dinero,
    required this.duracion,
    required this.uso,
    required this.membresiasFraccionadas,
    required this.cuotasEmitidas,
  });

  factory PlanStatistics.fromJson(Map<String, dynamic> json) {
    final cuotas = Map<String, dynamic>.from(
      json['cuotas'] as Map? ?? const {},
    );
    return PlanStatistics(
      zona: json['zona']?.toString() ?? '',
      diaNegocio: json['dia_negocio']?.toString() ?? '',
      plan: PlanIdentity.fromJson(
        Map<String, dynamic>.from(json['plan'] as Map? ?? const {}),
      ),
      contratacion: PlanContracting.fromJson(
        Map<String, dynamic>.from(json['contratacion'] as Map? ?? const {}),
      ),
      composicion: PlanComposition.fromJson(
        Map<String, dynamic>.from(json['composicion'] as Map? ?? const {}),
      ),
      movilidad: PlanMobility.fromJson(
        Map<String, dynamic>.from(json['movilidad'] as Map? ?? const {}),
      ),
      dinero: (json['dinero'] as List? ?? const [])
          .map((e) => PlanMoney.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
      duracion: PlanDuration.fromJson(
        Map<String, dynamic>.from(json['duracion'] as Map? ?? const {}),
      ),
      uso: PlanUsage.fromJson(
        Map<String, dynamic>.from(json['uso'] as Map? ?? const {}),
      ),
      membresiasFraccionadas:
          (cuotas['membresiasFraccionadas'] as num?)?.toInt() ?? 0,
      cuotasEmitidas: (cuotas['cuotasEmitidas'] as num?)?.toInt() ?? 0,
    );
  }

  final String zona;
  final String diaNegocio;
  final PlanIdentity plan;
  final PlanContracting contratacion;
  final PlanComposition composicion;
  final PlanMobility movilidad;

  /// **Una entrada por moneda.** No existe campo que las sume.
  final List<PlanMoney> dinero;
  final PlanDuration duracion;
  final PlanUsage uso;
  final int membresiasFraccionadas;
  final int cuotasEmitidas;
}

List<NamedCount> _etiquetados(Object? bruto) {
  return (bruto as List? ?? const [])
      .map(
        (e) => NamedCount(
          (e as Map)['etiqueta']?.toString() ?? '',
          (e['total'] as num?)?.toInt() ?? 0,
        ),
      )
      .toList(growable: false);
}
