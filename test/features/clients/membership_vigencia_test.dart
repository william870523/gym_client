import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/clients/domain/membership_vigencia.dart';

void main() {
  final hoy = DateTime.utc(2026, 7, 27); // fecha de negocio del gimnasio
  DateTime dia(int offset) => hoy.add(Duration(days: offset));

  MembershipVigencia vigencia(String? estado, DateTime? fin) =>
      resolveMembershipVigencia(status: estado, endDate: fin, today: hoy);

  group('vigencia derivada, espejo de la del servidor', () {
    test('la fecha de fin es exclusiva: ese día ya no cubre', () {
      // La fija el servidor como `endExclusive`. Un plan Diario contratado el
      // 27 guarda fin = 28 y cubre solo el 27.
      expect(vigencia('ACTIVA', hoy), MembershipVigencia.recentlyExpired);
      expect(vigencia('ACTIVA', dia(1)), MembershipVigencia.current);
    });

    test('una ACTIVA con la cobertura terminada no está vigente', () {
      // El caso que lo motivó: la ficha daba por vigente a quien venció.
      expect(vigencia('ACTIVA', dia(-8)), MembershipVigencia.recentlyExpired);
      expect(coversToday(vigencia('ACTIVA', dia(-8))), isFalse);
    });

    test('separa la ventana de cortesía de la caducidad definitiva', () {
      expect(
        vigencia('ACTIVA', dia(-kMembershipRecentExpiryDays)),
        MembershipVigencia.recentlyExpired,
      );
      expect(
        vigencia('ACTIVA', dia(-kMembershipRecentExpiryDays - 1)),
        MembershipVigencia.expired,
      );
    });

    test('la baja y la pausa mandan sobre la fecha', () {
      expect(vigencia('CANCELADA', dia(30)), MembershipVigencia.cancelled);
      expect(vigencia('PAUSADA', dia(-100)), MembershipVigencia.paused);
    });

    test('un estado desconocido falla cerrado', () {
      expect(vigencia('LO_QUE_SEA', dia(30)), MembershipVigencia.none);
      expect(vigencia(null, null), MembershipVigencia.none);
    });

    test('cuenta los días que faltan en negativo', () {
      expect(daysSinceExpiry(dia(3), hoy), -3);
      expect(daysSinceExpiry(dia(-3), hoy), 3);
    });
  });

  group('valor derivado por el servidor', () {
    test('traduce cada nombre del contrato', () {
      expect(
        membershipVigenciaFromServer('VIGENTE'),
        MembershipVigencia.current,
      );
      expect(
        membershipVigenciaFromServer('VENCIDA_RECIENTE'),
        MembershipVigencia.recentlyExpired,
      );
      expect(membershipVigenciaFromServer('VENCIDA'), MembershipVigencia.expired);
      expect(
        membershipVigenciaFromServer('SIN_MEMBRESIA'),
        MembershipVigencia.none,
      );
    });

    test('devuelve null con un servidor que aún no la manda', () {
      // Quien llama cae entonces a la derivación local, en vez de enseñar nada.
      expect(membershipVigenciaFromServer(null), isNull);
      expect(membershipVigenciaFromServer('  '), isNull);
      expect(membershipVigenciaFromServer('ALGO_NUEVO'), isNull);
    });
  });
}
