/// M5 — la solicitud de cierre de la cadena y su semáforo
/// (docs/MULTI_SEDE.md §6.2).
///
/// Contabilidad central **pide** el cierre de un período; cada sede lo
/// **ejecuta y lo firma** con su arqueo, porque el dinero está allí. Aquí viven
/// las dos caras: lo que la sede recibe (`SolicitudCierreModel`) y lo que el
/// Dueño mira para saber si puede consolidar (`SemaforoCadenaModel`).
library;

String? _texto(Object? valor) {
  final resultado = valor?.toString().trim();
  return resultado == null || resultado.isEmpty ? null : resultado;
}

/// Un **instante**: pasa a la zona de quien mira, que es lo que se quiere para
/// «cuándo se supo de esta sede» o «cuándo firmó».
DateTime? _instante(Object? valor) {
  final texto = _texto(valor);
  return texto == null ? null : DateTime.tryParse(texto)?.toLocal();
}

/// Una **fecha comercial**: se queda como viene, sin pasar por la zona local.
///
/// El servidor guarda los días de negocio como medianoche UTC
/// (`docs/TIME_CONTRACT.md`), así que `2026-08-01T00:00:00Z` **es** el 1 de
/// agosto y no un instante que haya que traducir. Convertirlo a local le resta
/// las horas del huso —en `America/Los_Angeles`, siete— y el día retrocede: el
/// aviso enseñaba «2026-07-31 → 2026-08-03» un período que se pidió del 1 al 4,
/// y cargarlo así habría hecho firmar el cierre de otros días. Visto en el
/// recorrido de escritorio del 18-08-2026.
DateTime? _fechaComercial(Object? valor) {
  final texto = _texto(valor);
  final fecha = texto == null ? null : DateTime.tryParse(texto);
  return fecha == null
      ? null
      : DateTime(fecha.toUtc().year, fecha.toUtc().month, fecha.toUtc().day);
}

/// Lo que administración pide a esta sede.
class SolicitudCierreModel {
  const SolicitudCierreModel({
    required this.solicitudId,
    required this.tipoPeriodo,
    required this.fechaInicio,
    required this.fechaFinExclusiva,
    required this.estado,
    this.nota,
    this.fechaLimite,
    this.solicitadaPor,
    this.solicitadaAt,
  });

  final String solicitudId;
  final String tipoPeriodo;
  final DateTime fechaInicio;

  /// Fin **exclusivo**, como lo guarda el servidor. La vista enseña el último
  /// día incluido, que es lo que el operador entiende por «hasta».
  final DateTime fechaFinExclusiva;
  final String estado;
  final String? nota;
  final DateTime? fechaLimite;
  final String? solicitadaPor;
  final DateTime? solicitadaAt;

  /// Último día que entra en el período, para enseñarlo sin restar de cabeza.
  DateTime get ultimoDiaIncluido =>
      fechaFinExclusiva.subtract(const Duration(days: 1));

  static SolicitudCierreModel? fromJson(Map<String, dynamic> json) {
    final inicio = _fechaComercial(json['fecha_inicio']);
    final fin = _fechaComercial(json['fecha_fin_exclusiva']);
    final id = _texto(json['solicitud_id']);
    // Una solicitud sin identidad o sin período no se puede ni enseñar ni
    // cargar: se descarta en vez de pintar una fila que no lleva a ninguna
    // parte.
    if (id == null || inicio == null || fin == null) return null;
    return SolicitudCierreModel(
      solicitudId: id,
      tipoPeriodo: _texto(json['tipo_periodo']) ?? 'RANGO',
      fechaInicio: inicio,
      fechaFinExclusiva: fin,
      estado: _texto(json['estado']) ?? 'ABIERTA',
      nota: _texto(json['nota']),
      fechaLimite: _fechaComercial(json['fecha_limite']),
      solicitadaPor: _texto(json['solicitada_por']),
      solicitadaAt: _instante(json['solicitada_at']),
    );
  }
}

/// Diferencia de arqueo **de una moneda**, en unidades menores.
///
/// Va por moneda y nunca en un total porque las monedas no se suman: mezclarlas
/// da una cifra sin significado y además puede cancelarse —+350 en una y −350
/// en otra dan cero— y pintar de verde una sede con dos cajas descuadradas.
class DescuadreMonedaModel {
  const DescuadreMonedaModel({required this.monedaId, required this.menor});

  final String monedaId;
  final int menor;

  /// El importe con sus dos decimales. El servidor manda unidades menores para
  /// que ningún redondeo ocurra por el camino.
  String get importe => (menor / 100).toStringAsFixed(2);

  factory DescuadreMonedaModel.fromJson(Map<String, dynamic> json) =>
      DescuadreMonedaModel(
        monedaId: _texto(json['moneda_id']) ?? '—',
        menor: (json['menor'] as num?)?.toInt() ?? 0,
      );
}

/// El cierre que la sede firmó para ese período, si consta.
class CierreDeSedeModel {
  const CierreDeSedeModel({
    required this.origen,
    required this.estado,
    this.cerradoAt,
    this.cerradoPor,
    this.reabiertoAt,
  });

  /// `MENSUAL` si el período es un mes natural —que se firma en el cierre
  /// mensual formal— y `PERIODO` en los demás casos.
  final String origen;
  final String estado;
  final DateTime? cerradoAt;
  final String? cerradoPor;
  final DateTime? reabiertoAt;

  static CierreDeSedeModel? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return CierreDeSedeModel(
      origen: _texto(json['origen']) ?? 'PERIODO',
      estado: _texto(json['estado']) ?? '—',
      cerradoAt: _instante(json['cerrado_at']),
      cerradoPor: _texto(json['cerrado_por']),
      reabiertoAt: _instante(json['reabierto_at']),
    );
  }
}

/// Los cuatro estados que el central puede **demostrar**, no suponer.
enum EstadoSemaforo {
  cerradaYSincronizada,
  conIncidencias,
  sinCerrar,
  sinNoticias;

  static EstadoSemaforo desdeTexto(String? valor) =>
      switch ((valor ?? '').toUpperCase()) {
        'CERRADA_Y_SINCRONIZADA' => EstadoSemaforo.cerradaYSincronizada,
        'CON_INCIDENCIAS' => EstadoSemaforo.conIncidencias,
        'SIN_CERRAR' => EstadoSemaforo.sinCerrar,
        _ => EstadoSemaforo.sinNoticias,
      };

  String get rotulo => switch (this) {
    EstadoSemaforo.cerradaYSincronizada => 'CERRADA',
    EstadoSemaforo.conIncidencias => 'CON INCIDENCIAS',
    EstadoSemaforo.sinCerrar => 'SIN CERRAR',
    EstadoSemaforo.sinNoticias => 'SIN NOTICIAS',
  };

  /// Qué hay que hacer con esa sede. `SIN_CERRAR` y `SIN_NOTICIAS` piden cosas
  /// distintas y por eso son estados distintos: a una se le reclama el cierre;
  /// a la otra se le mira la conexión, porque puede haber cerrado sin que
  /// conste aquí.
  String get accion => switch (this) {
    EstadoSemaforo.cerradaYSincronizada => 'Lista para consolidar',
    EstadoSemaforo.conIncidencias => 'Revisar antes de sumarla',
    EstadoSemaforo.sinCerrar => 'Reclamar el cierre',
    EstadoSemaforo.sinNoticias => 'Revisar la conexión, no reclamar',
  };
}

class SemaforoFilaModel {
  const SemaforoFilaModel({
    required this.gymId,
    required this.nombre,
    required this.estado,
    required this.consolidable,
    required this.motivo,
    required this.descuadres,
    required this.movimientosPendientes,
    this.cierre,
    this.ultimaNoticia,
  });

  final String gymId;
  final String nombre;
  final EstadoSemaforo estado;
  final bool consolidable;
  final String motivo;
  final List<DescuadreMonedaModel> descuadres;
  final int movimientosPendientes;
  final CierreDeSedeModel? cierre;
  final DateTime? ultimaNoticia;

  factory SemaforoFilaModel.fromJson(Map<String, dynamic> json) =>
      SemaforoFilaModel(
        gymId: _texto(json['gym_id']) ?? '',
        nombre: _texto(json['nombre']) ?? _texto(json['gym_id']) ?? '—',
        estado: EstadoSemaforo.desdeTexto(_texto(json['estado'])),
        consolidable: json['consolidable'] == true,
        motivo: _texto(json['motivo']) ?? '',
        descuadres: [
          for (final fila in (json['descuadres'] as List? ?? const []))
            DescuadreMonedaModel.fromJson((fila as Map).cast<String, dynamic>()),
        ],
        movimientosPendientes:
            (json['movimientos_pendientes'] as num?)?.toInt() ?? 0,
        cierre: CierreDeSedeModel.fromJson(
          (json['cierre'] as Map?)?.cast<String, dynamic>(),
        ),
        ultimaNoticia: _instante(json['ultima_noticia']),
      );
}

/// Una sede que quedaría fuera del consolidado, **con su nombre**.
///
/// §6.2 lo exige así: si el dueño firma igual, firma un cierre parcial
/// declarado, y para declararlo hay que poder nombrar a quién falta. Un total
/// silencioso e incompleto es peor que no tener total.
class SedeAusenteModel {
  const SedeAusenteModel({required this.gymId, required this.nombre});

  final String gymId;
  final String nombre;

  factory SedeAusenteModel.fromJson(Map<String, dynamic> json) =>
      SedeAusenteModel(
        gymId: _texto(json['gym_id']) ?? '',
        nombre: _texto(json['nombre']) ?? _texto(json['gym_id']) ?? '—',
      );
}

class SemaforoCadenaModel {
  const SemaforoCadenaModel({
    required this.fechaInicio,
    required this.fechaFinExclusiva,
    required this.filas,
    required this.puedeFirmarse,
    required this.ausentes,
  });

  final DateTime? fechaInicio;
  final DateTime? fechaFinExclusiva;
  final List<SemaforoFilaModel> filas;
  final bool puedeFirmarse;
  final List<SedeAusenteModel> ausentes;

  int get verdes => filas
      .where((f) => f.estado == EstadoSemaforo.cerradaYSincronizada)
      .length;
  int get conIncidencias =>
      filas.where((f) => f.estado == EstadoSemaforo.conIncidencias).length;
  int get sinCerrar =>
      filas.where((f) => f.estado == EstadoSemaforo.sinCerrar).length;
  int get sinNoticias =>
      filas.where((f) => f.estado == EstadoSemaforo.sinNoticias).length;

  factory SemaforoCadenaModel.fromJson(Map<String, dynamic> json) {
    final periodo = (json['periodo'] as Map?)?.cast<String, dynamic>();
    return SemaforoCadenaModel(
      fechaInicio: _fechaComercial(periodo?['fecha_inicio']),
      fechaFinExclusiva: _fechaComercial(periodo?['fecha_fin_exclusiva']),
      filas: [
        for (final fila in (json['filas'] as List? ?? const []))
          SemaforoFilaModel.fromJson((fila as Map).cast<String, dynamic>()),
      ],
      puedeFirmarse: json['puede_firmarse'] == true,
      ausentes: [
        for (final fila in (json['ausentes'] as List? ?? const []))
          SedeAusenteModel.fromJson((fila as Map).cast<String, dynamic>()),
      ],
    );
  }
}
