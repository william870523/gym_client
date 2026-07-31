/// Perfil estadístico de un socio, tal como lo devuelve
/// `GET /estadisticas/socio/:ci` (docs/PLAN_ESTADISTICAS.md §3).
///
/// Dos decisiones de modelado que vienen del plan y no se negocian:
///
///  - [MemberMoneyByCurrency] es una **lista**, no un total: los importes
///    llegan separados por moneda y no existe ningún campo que los sume;
///  - [StatRate] siempre lleva su denominador, para que la vista pueda enseñar
///    «68 % · 17 de 25» en lugar de un porcentaje huérfano.
library;

/// Tasa con su denominador a cuestas.
class StatRate {
  const StatRate({
    required this.casos,
    required this.base,
    required this.porcentaje,
  });

  factory StatRate.fromJson(Map<String, dynamic> json) => StatRate(
    casos: (json['casos'] as num?)?.toInt() ?? 0,
    base: (json['base'] as num?)?.toInt() ?? 0,
    porcentaje: (json['porcentaje'] as num?)?.toDouble(),
  );

  final int casos;
  final int base;

  /// `null` cuando la base es cero: no hay porcentaje que inventar.
  final double? porcentaje;

  /// Texto listo para mostrar, con la muestra visible.
  String get etiqueta =>
      porcentaje == null ? '—' : '${porcentaje!.toStringAsFixed(1)} %';

  String get detalle => '$casos de $base';

  /// Una tasa sobre poquísimos casos no merece leerse como tendencia.
  bool get muestraBaja => base > 0 && base < 5;
}

class MemberIdentity {
  const MemberIdentity({
    required this.ci,
    required this.nombre,
    required this.sexo,
    required this.edad,
    required this.categoria,
    required this.objetivo,
    required this.antiguedadDias,
  });

  factory MemberIdentity.fromJson(Map<String, dynamic> json) => MemberIdentity(
    ci: json['ci']?.toString() ?? '',
    nombre: json['nombre']?.toString() ?? '',
    sexo: json['sexo']?.toString() ?? '',
    edad: (json['edad'] as num?)?.toInt(),
    categoria: json['categoria']?.toString(),
    objetivo: json['objetivo']?.toString(),
    antiguedadDias: (json['antiguedadDias'] as num?)?.toInt(),
  );

  final String ci;
  final String nombre;
  final String sexo;
  final int? edad;
  final String? categoria;
  final String? objetivo;
  final int? antiguedadDias;
}

class NamedCount {
  const NamedCount(this.etiqueta, this.total);

  final String etiqueta;
  final int total;
}

class MemberConstancy {
  const MemberConstancy({
    required this.visitas,
    required this.visitasPorMes,
    required this.rachaActual,
    required this.rachaMaxima,
    required this.diasDesdeUltima,
    required this.permanenciaMediaMin,
    required this.porFranja,
    required this.porDiaSemana,
    required this.aprovechamiento,
  });

  factory MemberConstancy.fromJson(Map<String, dynamic> json) =>
      MemberConstancy(
        visitas: (json['visitas'] as num?)?.toInt() ?? 0,
        visitasPorMes: _conteos(json['visitasPorMes'], 'mes'),
        rachaActual: (json['rachaActual'] as num?)?.toInt() ?? 0,
        rachaMaxima: (json['rachaMaxima'] as num?)?.toInt() ?? 0,
        diasDesdeUltima: (json['diasDesdeUltima'] as num?)?.toInt(),
        permanenciaMediaMin: (json['permanenciaMediaMin'] as num?)?.toInt(),
        porFranja: _conteos(json['porFranja'], 'franja'),
        porDiaSemana: _conteos(json['porDiaSemana'], 'dia'),
        aprovechamiento: StatRate.fromJson(
          Map<String, dynamic>.from(
            json['aprovechamiento'] as Map? ?? const {},
          ),
        ),
      );

  final int visitas;
  final List<NamedCount> visitasPorMes;
  final int rachaActual;
  final int rachaMaxima;
  final int? diasDesdeUltima;
  final int? permanenciaMediaMin;
  final List<NamedCount> porFranja;
  final List<NamedCount> porDiaSemana;
  final StatRate aprovechamiento;
}

class MemberMoneyByCurrency {
  const MemberMoneyByCurrency({
    required this.monedaId,
    required this.cobros,
    required this.total,
    required this.ticketMedio,
    required this.primero,
    required this.ultimo,
  });

  factory MemberMoneyByCurrency.fromJson(Map<String, dynamic> json) =>
      MemberMoneyByCurrency(
        monedaId: json['monedaId']?.toString() ?? '',
        cobros: (json['cobros'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toDouble() ?? 0,
        ticketMedio: (json['ticketMedio'] as num?)?.toDouble() ?? 0,
        primero: _fecha(json['primero']),
        ultimo: _fecha(json['ultimo']),
      );

  final String monedaId;
  final int cobros;
  final double total;
  final double ticketMedio;
  final DateTime? primero;
  final DateTime? ultimo;
}

class MemberArrears {
  const MemberArrears({
    required this.cobrosConRecargo,
    required this.recargoTotal,
    required this.diasAtrasoPromedio,
    required this.condonadoTotal,
    required this.puntualidad,
  });

  factory MemberArrears.fromJson(Map<String, dynamic> json) => MemberArrears(
    cobrosConRecargo: (json['cobrosConRecargo'] as num?)?.toInt() ?? 0,
    recargoTotal: (json['recargoTotal'] as num?)?.toDouble() ?? 0,
    diasAtrasoPromedio: (json['diasAtrasoPromedio'] as num?)?.toDouble(),
    condonadoTotal: (json['condonadoTotal'] as num?)?.toDouble() ?? 0,
    puntualidad: StatRate.fromJson(
      Map<String, dynamic>.from(json['puntualidad'] as Map? ?? const {}),
    ),
  );

  final int cobrosConRecargo;
  final double recargoTotal;
  final double? diasAtrasoPromedio;
  final double condonadoTotal;
  final StatRate puntualidad;
}

class MemberMoney {
  const MemberMoney({
    required this.porMoneda,
    required this.porMedio,
    required this.mora,
  });

  factory MemberMoney.fromJson(Map<String, dynamic> json) => MemberMoney(
    porMoneda: (json['porMoneda'] as List? ?? const [])
        .map(
          (e) => MemberMoneyByCurrency.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList(growable: false),
    porMedio: _conteos(json['porMedio'], 'medio'),
    mora: MemberArrears.fromJson(
      Map<String, dynamic>.from(json['mora'] as Map? ?? const {}),
    ),
  );

  final List<MemberMoneyByCurrency> porMoneda;
  final List<NamedCount> porMedio;
  final MemberArrears mora;
}

class MembershipEntry {
  const MembershipEntry({
    required this.id,
    required this.plan,
    required this.precio,
    required this.monedaId,
    required this.desde,
    required this.hasta,
    required this.estado,
    required this.origen,
  });

  factory MembershipEntry.fromJson(Map<String, dynamic> json) =>
      MembershipEntry(
        id: json['id']?.toString() ?? '',
        plan: json['plan']?.toString() ?? '',
        precio: (json['precio'] as num?)?.toDouble() ?? 0,
        monedaId: json['monedaId']?.toString() ?? '',
        desde: json['desde']?.toString() ?? '',
        hasta: json['hasta']?.toString() ?? '',
        estado: json['estado']?.toString() ?? '',
        origen: json['origen']?.toString() ?? '',
      );

  final String id;
  final String plan;
  final double precio;
  final String monedaId;
  final String desde;
  final String hasta;
  final String estado;
  final String origen;
}

class MemberContract {
  const MemberContract({
    required this.membresias,
    required this.altas,
    required this.renovaciones,
    required this.cambiosDePlan,
    required this.reactivaciones,
    required this.diasPausados,
    required this.tasaRenovacion,
    required this.planesRecorridos,
  });

  factory MemberContract.fromJson(Map<String, dynamic> json) => MemberContract(
    membresias: (json['membresias'] as List? ?? const [])
        .map(
          (e) => MembershipEntry.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(growable: false),
    altas: (json['altas'] as num?)?.toInt() ?? 0,
    renovaciones: (json['renovaciones'] as num?)?.toInt() ?? 0,
    cambiosDePlan: (json['cambiosDePlan'] as num?)?.toInt() ?? 0,
    reactivaciones: (json['reactivaciones'] as num?)?.toInt() ?? 0,
    diasPausados: (json['diasPausados'] as num?)?.toInt() ?? 0,
    tasaRenovacion: StatRate.fromJson(
      Map<String, dynamic>.from(json['tasaRenovacion'] as Map? ?? const {}),
    ),
    planesRecorridos: (json['planesRecorridos'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(growable: false),
  );

  final List<MembershipEntry> membresias;
  final int altas;
  final int renovaciones;
  final int cambiosDePlan;
  final int reactivaciones;
  final int diasPausados;
  final StatRate tasaRenovacion;
  final List<String> planesRecorridos;
}

class WeightPoint {
  const WeightPoint(this.fecha, this.peso);

  final String fecha;
  final double peso;
}

class MemberBody {
  const MemberBody({
    required this.serie,
    required this.pesoInicial,
    required this.pesoActual,
    required this.delta,
    required this.estaturaCm,
    required this.imc,
  });

  factory MemberBody.fromJson(Map<String, dynamic> json) => MemberBody(
    serie: (json['serie'] as List? ?? const [])
        .map(
          (e) => WeightPoint(
            (e as Map)['fecha']?.toString() ?? '',
            ((e)['peso'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList(growable: false),
    pesoInicial: (json['pesoInicial'] as num?)?.toDouble(),
    pesoActual: (json['pesoActual'] as num?)?.toDouble(),
    delta: (json['delta'] as num?)?.toDouble(),
    estaturaCm: (json['estaturaCm'] as num?)?.toDouble(),
    imc: (json['imc'] as num?)?.toDouble(),
  );

  final List<WeightPoint> serie;
  final double? pesoInicial;
  final double? pesoActual;
  final double? delta;
  final double? estaturaCm;
  final double? imc;
}

class MemberStatistics {
  const MemberStatistics({
    required this.zona,
    required this.diaNegocio,
    required this.socio,
    required this.constancia,
    required this.dinero,
    required this.contrato,
    required this.cuerpo,
  });

  factory MemberStatistics.fromJson(Map<String, dynamic> json) =>
      MemberStatistics(
        zona: json['zona']?.toString() ?? '',
        diaNegocio: json['dia_negocio']?.toString() ?? '',
        socio: MemberIdentity.fromJson(
          Map<String, dynamic>.from(json['socio'] as Map? ?? const {}),
        ),
        constancia: MemberConstancy.fromJson(
          Map<String, dynamic>.from(json['constancia'] as Map? ?? const {}),
        ),
        dinero: MemberMoney.fromJson(
          Map<String, dynamic>.from(json['dinero'] as Map? ?? const {}),
        ),
        contrato: MemberContract.fromJson(
          Map<String, dynamic>.from(json['contrato'] as Map? ?? const {}),
        ),
        cuerpo: MemberBody.fromJson(
          Map<String, dynamic>.from(json['cuerpo'] as Map? ?? const {}),
        ),
      );

  /// Zona en la que el servidor agrupó días y horas. Se muestra al pie: sin
  /// ella, «viene por la mañana» no tiene un significado comprobable.
  final String zona;
  final String diaNegocio;
  final MemberIdentity socio;
  final MemberConstancy constancia;
  final MemberMoney dinero;
  final MemberContract contrato;
  final MemberBody cuerpo;
}

List<NamedCount> _conteos(Object? bruto, String clave) {
  return (bruto as List? ?? const [])
      .map(
        (e) => NamedCount(
          (e as Map)[clave]?.toString() ?? '',
          ((e)['total'] as num?)?.toInt() ?? 0,
        ),
      )
      .toList(growable: false);
}

DateTime? _fecha(Object? valor) {
  if (valor == null) return null;
  return DateTime.tryParse(valor.toString());
}
