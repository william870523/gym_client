/// Utilidades de zona horaria para el cliente Flutter.
///
/// Principio del sistema: TODA marca de tiempo se almacena y transmite en UTC
/// (instante absoluto, `...Z`). Solo al mostrar o calcular "inicio de día /
/// hoy" se convierte a la zona del gimnasio ([Gym.timezone]).
///
/// El paquete `timezone` trae la tz database embebida; basta llamar a
/// [initTimeZone] una vez en `main()` antes de usar estas funciones.
library;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../time/app_clock.dart';

/// Zona horaria IANA por defecto del sistema.
const String defaultGymTimezone = 'Etc/UTC';

bool _initialized = false;

/// Inicializa la tz database. Llamar en `main()` antes de cualquier conversión.
/// Es idempotente.
void initTimeZone() {
  if (_initialized) return;
  tzdata.initializeTimeZones();
  _initialized = true;
}

List<String> get availableGymTimezones {
  initTimeZone();
  final zones = <String>{
    defaultGymTimezone,
    ...tz.timeZoneDatabase.locations.keys,
  }.toList()..sort();
  return zones;
}

bool isKnownGymTimezone(String value) {
  initTimeZone();
  return value == defaultGymTimezone ||
      value == 'UTC' ||
      tz.timeZoneDatabase.locations.containsKey(value);
}

tz.Location _resolveLocation(String gymTimezone) {
  if (gymTimezone == defaultGymTimezone || gymTimezone == 'UTC') {
    return tz.UTC;
  }
  return tz.timeZoneDatabase.locations[gymTimezone] ?? tz.UTC;
}

/// Devuelve la [DateTime] local del dispositivo en UTC.
DateTime toUtcZone(DateTime d) => d.toUtc();

/// Normaliza una [DateTime] a UTC.
DateTime toUtc(DateTime d) => d.isUtc ? d : d.toUtc();

/// Convierte una fecha de calendario (sin hora) a la convención persistida:
/// medianoche UTC del mismo año/mes/día, sin depender de la zona del equipo.
DateTime calendarDateToUtc(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

/// Interpreta un string como UTC y devuelve un [DateTime] en UTC.
/// - Con offset (`Z`, `+HH:MM`): interpretado correctamente como UTC absoluto.
/// - Sin offset: se asume UTC (contrato del sistema).
DateTime parseUtc(String value) {
  final s = value.trim();
  if (s.isEmpty) return appClock.nowUtc();
  if (s.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s)) {
    return DateTime.parse(s).toUtc();
  }
  // Sin offset: asumimos UTC (añadimos Z).
  return DateTime.parse('${s}Z').toUtc();
}

/// Versión nullable de [parseUtc].
DateTime? tryParseUtc(String? value) {
  if (value == null) return null;
  final s = value.trim();
  if (s.isEmpty) return null;
  try {
    if (s.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s)) {
      return DateTime.parse(s).toUtc();
    }
    return DateTime.parse('${s}Z').toUtc();
  } catch (_) {
    return null;
  }
}

/// Convierte un instante UTC a la zona horaria IANA del gimnasio.
/// Devuelve un [tz.TZDateTime] que refleja la hora local de esa zona.
tz.TZDateTime toGymZone(DateTime instant, String gymTimezone) {
  initTimeZone();
  final loc = _resolveLocation(gymTimezone);
  return tz.TZDateTime.from(instant.toUtc(), loc);
}

/// Convierte un instante UTC a la zona del gym como [DateTime] "wall clock"
/// (sin info de zona, útil para extraer .year/.month/.day consistentes con la
/// zona del gym sin depender del reloj del dispositivo).
DateTime toGymWallClock(DateTime instant, String gymTimezone) {
  final z = toGymZone(instant, gymTimezone);
  return DateTime(
    z.year,
    z.month,
    z.day,
    z.hour,
    z.minute,
    z.second,
    z.millisecond,
    z.microsecond,
  );
}

/// Devuelve el inicio (00:00:00.000) del día natural en la zona del gimnasio,
/// como instante UTC absoluto — para comparaciones y filtros coherentes entre
/// dispositivos con distintas zonas horarias.
DateTime startOfDayInZone(String gymTimezone, {DateTime? ref}) {
  final r = (ref ?? appClock.nowUtc()).toUtc();
  final z = toGymZone(r, gymTimezone);
  // 00:00:00 del día natural en la zona del gym → instante UTC.
  return tz.TZDateTime(z.location, z.year, z.month, z.day, 0, 0, 0, 0).toUtc();
}

/// Fin (23:59:59.999) del día natural en la zona del gym, como UTC.
DateTime endOfDayInZone(String gymTimezone, {DateTime? ref}) {
  final r = (ref ?? appClock.nowUtc()).toUtc();
  final z = toGymZone(r, gymTimezone);
  return tz.TZDateTime(
    z.location,
    z.year,
    z.month,
    z.day,
    23,
    59,
    59,
    999,
  ).toUtc();
}

/// Formatea un instante UTC en la zona del gimnasio usando un [DateFormat].
String formatInZone(DateTime instant, String gymTimezone, DateFormat format) {
  return format.format(toGymWallClock(instant, gymTimezone));
}

/// Conveniente: fecha corta (yyyy-MM-dd) en la zona del gym.
String formatDateInZone(
  DateTime instant,
  String gymTimezone, {
  String pattern = 'yyyy-MM-dd',
}) {
  return formatInZone(instant, gymTimezone, DateFormat(pattern));
}

/// Conveniente: hora corta (HH:mm) en la zona del gym.
String formatTimeInZone(
  DateTime instant,
  String gymTimezone, {
  String pattern = 'HH:mm',
}) {
  return formatInZone(instant, gymTimezone, DateFormat(pattern));
}

/// Fecha "hoy" en la zona del gym (sin hora) — para comparaciones de días
/// naturales (vencimientos, "días hasta vencer", etc.).
DateTime todayInZone(String gymTimezone) {
  final z = toGymZone(appClock.nowUtc(), gymTimezone);
  return DateTime(z.year, z.month, z.day);
}

/// Para debug: la zona del dispositivo (puede diferir de la del gym).
String get deviceTimezoneName {
  final now = DateTime.now().toLocal();
  if (kDebugMode) {
    // ignore: avoid_print
    print('[tz] device offset minutes: ${now.timeZoneOffset.inMinutes}');
  }
  return now.timeZoneName;
}
