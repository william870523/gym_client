import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';
import 'package:gym_client/src/features/clients/presentation/state/clients_scope_filter_provider.dart';

/// El filtro que deja puesto una fila del cruzador
/// (docs/PLAN_ESTADISTICAS.md §5).
///
/// Lo que estas pruebas protegen es una sola cosa: **la lista tiene que enseñar
/// exactamente el conjunto que la barra contó**. Si el cruce dice «Mensual: 25»
/// y la lista trae 18, el operador deja de creerse las dos cifras, que es
/// justo el problema que `plan_associates.dart` documenta para los contadores.
ClientModel _socio({
  required String id,
  String? sexo,
  String? planId,
  String? trainerId,
  String? referralId,
  String? scheduleId,
  String? nacionalidadId,
  String? categoria,
  String? membershipStatus,
  DateTime? endDate,
}) => ClientModel(
  id: id,
  nombres: 'Socio',
  apellidos: id,
  sexo: sexo,
  planId: planId,
  trainerId: trainerId,
  referralId: referralId,
  scheduleId: scheduleId,
  nacionalidadId: nacionalidadId,
  categoria: categoria,
  activo: true,
  membershipStatus: membershipStatus,
  endDate: endDate,
);

final _hoy = DateTime.utc(2026, 7, 31);

void main() {
  group('filtro por atributo del socio', () {
    test('casa el valor exacto del eje elegido', () {
      const filtro = ClientsScopeFilter.attribute(
        attribute: ClientsAttribute.plan,
        value: 'plan-1',
        name: 'Mensual',
      );
      expect(
        filtro.matches(_socio(id: 'a', planId: 'plan-1'), today: _hoy),
        isTrue,
      );
      expect(
        filtro.matches(_socio(id: 'b', planId: 'plan-2'), today: _hoy),
        isFalse,
      );
    });

    test('«SIN DATO» devuelve justamente a los que no tienen valor', () {
      const filtro = ClientsScopeFilter.attribute(
        attribute: ClientsAttribute.referencia,
        value: kSinDatoKey,
        name: 'SIN DATO',
      );
      expect(filtro.matches(_socio(id: 'a'), today: _hoy), isTrue);
      expect(
        filtro.matches(_socio(id: 'b', referralId: '  '), today: _hoy),
        isTrue,
      );
      expect(
        filtro.matches(_socio(id: 'c', referralId: 'ref-1'), today: _hoy),
        isFalse,
      );
    });

    test(
      'NO aplica la regla de asociado: enseña el mismo padrón que contó la barra',
      () {
        // Un socio con la membresía cancelada sigue teniendo su plan en la
        // ficha, y el cruzador lo contó ahí. El filtro de plan «asociado» lo
        // dejaría fuera; el del cruzador no, y esa es la diferencia.
        final cancelado = _socio(
          id: 'cancelado',
          planId: 'plan-1',
          membershipStatus: 'CANCELADA',
          endDate: DateTime.utc(2025, 1, 1),
        );

        const delCruzador = ClientsScopeFilter.attribute(
          attribute: ClientsAttribute.plan,
          value: 'plan-1',
          name: 'Mensual',
        );
        const deAsociados = ClientsScopeFilter.plan(
          planId: 'plan-1',
          name: 'Mensual',
        );

        expect(delCruzador.matches(cancelado, today: _hoy), isTrue);
        expect(deAsociados.matches(cancelado, today: _hoy), isFalse);
      },
    );

    test('cada eje mira su propio campo', () {
      final socio = _socio(
        id: 'a',
        sexo: 'Femenino',
        nacionalidadId: 'nac-1',
        categoria: 'VIEJO',
        scheduleId: 'hor-1',
        trainerId: 'ent-1',
      );
      for (final caso in <(ClientsAttribute, String, bool)>[
        (ClientsAttribute.sexo, 'Femenino', true),
        (ClientsAttribute.sexo, 'Masculino', false),
        (ClientsAttribute.nacionalidad, 'nac-1', true),
        (ClientsAttribute.categoria, 'VIEJO', true),
        (ClientsAttribute.categoria, 'NUEVO', false),
        (ClientsAttribute.horario, 'hor-1', true),
        (ClientsAttribute.entrenador, 'ent-1', true),
        (ClientsAttribute.entrenador, 'ent-9', false),
      ]) {
        final filtro = ClientsScopeFilter.attribute(
          attribute: caso.$1,
          value: caso.$2,
          name: caso.$2,
        );
        expect(
          filtro.matches(socio, today: _hoy),
          caso.$3,
          reason: '${caso.$1.name} = ${caso.$2}',
        );
      }
    });

    test('el rótulo dice por qué está filtrada la lista', () {
      const filtro = ClientsScopeFilter.attribute(
        attribute: ClientsAttribute.referencia,
        value: 'ref-1',
        name: 'Redes sociales',
      );
      expect(filtro.heading, 'Socios por canal de captación:');
      expect(filtro.scope, 'Socios con canal de captación Redes sociales');
      expect(filtro.label, 'Redes sociales');
    });
  });

  group('qué ejes del cruzador tienen destino', () {
    test('los del socio, sí', () {
      for (final dimension in const [
        'sexo',
        'nacionalidad',
        'categoria',
        'referencia',
        'horario',
        'entrenador',
        'plan',
      ]) {
        expect(
          ClientsAttribute.fromDimension(dimension),
          isNotNull,
          reason: dimension,
        );
      }
    });

    test('los del cobro, no: un socio no tiene medio de pago', () {
      for (final dimension in const [
        'moneda',
        'cobrador',
        'tipo_pago',
        'cuenta',
        // `estado` queda fuera para no reimplementar en Dart el corte del SQL,
        // y `sede` porque el modelo de cliente no trae `gym_id`.
        'estado',
        'sede',
      ]) {
        expect(
          ClientsAttribute.fromDimension(dimension),
          isNull,
          reason: dimension,
        );
      }
    });
  });
}
