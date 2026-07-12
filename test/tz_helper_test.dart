import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/utils/datetime_zone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initTimeZone();

  test('parseUtc respeta offset y asume UTC sin offset', () {
    expect(
      parseUtc('2026-07-05T10:00:00').toIso8601String(),
      '2026-07-05T10:00:00.000Z',
    );
    expect(
      parseUtc('2026-07-05T10:00:00-05:00').toIso8601String(),
      '2026-07-05T15:00:00.000Z',
    );
    expect(
      parseUtc('2026-07-05T10:00:00Z').toIso8601String(),
      '2026-07-05T10:00:00.000Z',
    );
  });

  test('startOfDayInZone Havana cubre el día natural correcto', () {
    // 2026-07-05 03:00 UTC = 2026-07-04 23:00 Havana (julio, UTC-4 DST)
    final ref = DateTime.parse('2026-07-05T03:00:00Z');
    final start = startOfDayInZone('America/Havana', ref: ref);
    final end = endOfDayInZone('America/Havana', ref: ref);
    // Día natural Havana = 2026-07-04 00:00..23:59 Havana = 04:00..03:59:59 UTC
    expect(start.toIso8601String(), '2026-07-04T04:00:00.000Z');
    expect(end.toIso8601String(), '2026-07-05T03:59:59.999Z');
  });

  test('toGymWallClock devuelve componentes en zona gym', () {
    final ref = DateTime.parse('2026-07-05T15:00:00Z'); // 11:00 Havana
    final wc = toGymWallClock(ref, 'America/Havana');
    expect(wc.hour, 11);
    expect(wc.day, 5);
    // Madrid 17:00
    final wcMad = toGymWallClock(ref, 'Europe/Madrid');
    expect(wcMad.hour, 17);
  });

  test('Etc/UTC y UTC se resuelven como zona neutral', () {
    final ref = DateTime.parse('2026-07-05T15:00:00Z');

    expect(isKnownGymTimezone(defaultGymTimezone), isTrue);
    expect(availableGymTimezones, contains(defaultGymTimezone));
    expect(toGymWallClock(ref, defaultGymTimezone).hour, 15);
    expect(toGymWallClock(ref, 'UTC').hour, 15);
  });

  test('formatInZone aplica zona correcta', () {
    final ref = DateTime.parse('2026-07-05T15:00:00Z');
    expect(formatTimeInZone(ref, 'America/Havana'), '11:00');
    expect(formatTimeInZone(ref, 'Europe/Madrid'), '17:00');
  });

  test('calendarDateToUtc no depende de la zona del dispositivo', () {
    final localDate = DateTime(2026, 7, 6, 18, 45);
    expect(
      calendarDateToUtc(localDate).toIso8601String(),
      '2026-07-06T00:00:00.000Z',
    );
  });
}
