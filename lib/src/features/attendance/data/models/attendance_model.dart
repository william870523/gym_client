import 'package:json_annotation/json_annotation.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';

part 'attendance_model.g.dart';

@JsonSerializable(createFactory: false)
class AttendanceModel {
  @JsonKey(name: 'asistencia_id')
  final String id;
  @JsonKey(name: 'ci')
  final String clientId;

  @JsonKey(name: 'created_at')
  final DateTime checkIn;

  @JsonKey(name: 'fecha_salida')
  final DateTime? checkOut;

  // Pausa de permanencia (persistida): instante UTC de la pausa vigente
  // (null = no pausado) y milisegundos acumulados de pausas ya cerradas.
  @JsonKey(name: 'pausa_inicio')
  final DateTime? pauseStart;

  @JsonKey(name: 'pausa_ms')
  final int pausedMs;

  // 'status' is not in DB, so we derive it or ignore it from JSON
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String status;

  // Optional: Expanded client data if API returns joined data
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? clientName;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? photoUrl;

  /// M4a — socio de otra sede entrenando aquí con su acceso multi-sede. El
  /// servidor lo marca al rellenar la fila con la copia de solo lectura: sin
  /// esta distinción, el mostrador contaría al visitante como socio propio.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool visitante;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? sedeDeOrigen;

  AttendanceModel({
    required this.id,
    required this.clientId,
    required this.checkIn,
    this.checkOut,
    this.pauseStart,
    this.pausedMs = 0,
    String? status,
    this.clientName,
    this.photoUrl,
    this.visitante = false,
    this.sedeDeOrigen,
  }) : status = status ?? (checkOut == null ? 'activo' : 'finalizado');

  bool get isPaused => checkOut == null && pauseStart != null;

  /// Tiempo activo dentro del gimnasio (descuenta pausas), respecto a [nowUtc].
  Duration activeElapsed(DateTime nowUtc) {
    final end = checkOut?.toUtc() ?? nowUtc;
    var elapsed = end.difference(checkIn.toUtc());
    elapsed -= Duration(milliseconds: pausedMs);
    if (checkOut == null && pauseStart != null) {
      elapsed -= nowUtc.difference(pauseStart!.toUtc());
    }
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    // Safely extract fields that might be wrong types
    final id = json['asistencia_id']?.toString() ?? '';
    final clientId = json['ci']?.toString() ?? '';

    final checkInStr = json['created_at'] as String?;
    final checkIn = checkInStr != null
        ? parseUtc(checkInStr)
        : appClock.nowUtc();

    final checkOutStr = json['fecha_salida'] as String?;
    final checkOut = checkOutStr != null ? parseUtc(checkOutStr) : null;

    final pauseStartStr = json['pausa_inicio'] as String?;
    final pauseStart = pauseStartStr != null ? parseUtc(pauseStartStr) : null;
    final pausedMs = switch (json['pausa_ms']) {
      final num v => v.toInt(),
      final String v => int.tryParse(v) ?? 0,
      _ => 0,
    };

    // Handle nested 'cliente' data
    String? name;
    String? photo;

    if (json['cliente'] != null && json['cliente'] is Map) {
      final c = json['cliente'];
      final n = c['nombres']?.toString() ?? '';
      final a = c['apellidos']?.toString() ?? '';
      name = '$n $a'.trim();

      // Check if photo is actually a string (Base64)
      if (c['foto_cliente'] is String) {
        photo = c['foto_cliente'];
      }
    }

    return AttendanceModel(
      id: id,
      clientId: clientId,
      checkIn: checkIn,
      checkOut: checkOut,
      pauseStart: pauseStart,
      pausedMs: pausedMs,
      status: checkOut == null ? 'activo' : 'finalizado',
      clientName: name,
      photoUrl: photo,
      visitante: json['visitante'] == true,
      sedeDeOrigen: json['gym_id_origen'] as String?,
    );
  }

  Map<String, dynamic> toJson() => _$AttendanceModelToJson(this);
}

/// Una entrada recién registrada, con **cómo se decidió** (§5.2).
///
/// La declaración va aparte de `AttendanceModel` a propósito: no es una
/// propiedad de la asistencia —esa fila es la misma se haya decidido como se
/// haya decidido— sino del acto de autorizarla. Meterla dentro obligaría a
/// arrastrarla por todas las listas y los informes, donde no significa nada.
///
/// Solo llega en la entrada de un **visitante**: para un socio de la casa la
/// pregunta no existe, porque su membresía está en esta misma base.
class EntradaRegistrada {
  const EntradaRegistrada({
    required this.asistencia,
    this.decididoCon,
    this.advertencia,
  });

  final AttendanceModel asistencia;

  /// `CONCENTRADOR` cuando el dato era de origen en ese instante;
  /// `COPIA_LOCAL` cuando el concentrador no contestó y decidió esta sede.
  final String? decididoCon;

  /// Lo que la sede no puede afirmar. Nulo cuando decidió el concentrador.
  final String? advertencia;

  /// La entrada se autorizó con datos que pueden haber envejecido.
  bool get conDudaRazonable => decididoCon == 'COPIA_LOCAL' && advertencia != null;

  static EntradaRegistrada fromJson(Map<String, dynamic> json) => EntradaRegistrada(
    asistencia: AttendanceModel.fromJson(json),
    decididoCon: json['decidido_con'] as String?,
    advertencia: (json['advertencia'] as String?)?.trim().isEmpty ?? true
        ? null
        : (json['advertencia'] as String).trim(),
  );
}
