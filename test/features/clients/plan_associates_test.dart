import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';
import 'package:gym_client/src/features/clients/domain/plan_associates.dart';

/// Criterio de «asociado» decidido por el dueño el 25-07-2026
/// (docs/PLAN_ASOCIADOS.md §5). Se fija aquí porque de él dependen dos cosas
/// que deben coincidir siempre: el contador de la vista de Planes y la lista
/// filtrada de Clientes.
void main() {
  final today = DateTime.utc(2026, 7, 25);

  ClientModel client({
    String id = '1',
    String? planId = 'plan-a',
    String? trainerId,
    String? status,
    DateTime? endDate,
  }) => ClientModel(
    id: id,
    planId: planId,
    trainerId: trainerId,
    membershipStatus: status,
    endDate: endDate,
  );

  test('la membresía vigente es asociada', () {
    expect(
      isPlanAssociate(
        client(status: 'ACTIVA', endDate: DateTime.utc(2026, 8, 10)),
        planId: 'plan-a',
        today: today,
      ),
      isTrue,
    );
  });

  test('quien contrató y no ha pagado también es asociado', () {
    expect(
      isPlanAssociate(
        client(status: 'PENDIENTE_PAGO'),
        planId: 'plan-a',
        today: today,
      ),
      isTrue,
    );
  });

  test('la pausada sigue ligada al plan', () {
    expect(
      isPlanAssociate(
        client(status: 'PAUSADA', endDate: DateTime.utc(2026, 8, 1)),
        planId: 'plan-a',
        today: today,
      ),
      isTrue,
    );
  });

  test('vencida dentro de la ventana cuenta; fuera, no', () {
    final borde = today.subtract(
      const Duration(days: kPlanAssociateRecentExpiryDays),
    );
    expect(
      isPlanAssociate(
        client(status: 'ACTIVA', endDate: borde),
        planId: 'plan-a',
        today: today,
      ),
      isTrue,
      reason: 'el último día de la ventana todavía cuenta',
    );
    expect(
      isPlanAssociate(
        client(
          status: 'ACTIVA',
          endDate: borde.subtract(const Duration(days: 1)),
        ),
        planId: 'plan-a',
        today: today,
      ),
      isFalse,
    );
  });

  test('sin membresía viva (baja) no es asociado', () {
    expect(
      isPlanAssociate(
        client(status: null, endDate: DateTime.utc(2026, 8, 10)),
        planId: 'plan-a',
        today: today,
      ),
      isFalse,
    );
  });

  test('la membresía de otro plan no cuenta', () {
    expect(
      isPlanAssociate(
        client(planId: 'plan-b', status: 'ACTIVA'),
        planId: 'plan-a',
        today: today,
      ),
      isFalse,
    );
  });

  test('el conteo por plan usa el mismo criterio que la lista', () {
    final clients = [
      client(id: '1', status: 'ACTIVA', endDate: DateTime.utc(2026, 8, 10)),
      client(id: '2', status: 'PENDIENTE_PAGO'),
      client(id: '3', status: 'ACTIVA', endDate: DateTime.utc(2026, 7, 15)),
      client(id: '4', status: 'ACTIVA', endDate: DateTime.utc(2026, 1, 15)),
      client(id: '5', status: null),
      client(id: '6', planId: 'plan-b', status: 'ACTIVA'),
      client(id: '7', planId: null, status: 'ACTIVA'),
    ];

    final counts = countAssociatesByPlan(
      clients,
      planIds: {'plan-a', 'plan-b'},
      today: today,
    );
    final list = planAssociates(clients, planId: 'plan-a', today: today);

    expect(counts['plan-a'], 3);
    expect(counts['plan-b'], 1);
    // Enseñar 3 y encontrar 2 al pulsar es justo lo que este criterio evita.
    expect(list.map((item) => item.id), ['1', '2', '3']);
    expect(list, hasLength(counts['plan-a']));
  });

  test('el entrenador usa el mismo criterio de membresía que el plan', () {
    final vigente = client(
      id: '1',
      trainerId: 'tr-ana',
      status: 'ACTIVA',
      endDate: DateTime.utc(2026, 8, 10),
    );
    final vencidoHaceMucho = client(
      id: '2',
      trainerId: 'tr-ana',
      status: 'ACTIVA',
      endDate: DateTime.utc(2026, 1, 15),
    );
    final deBaja = client(id: '3', trainerId: 'tr-ana', status: null);
    final deOtroEntrenador = client(
      id: '4',
      trainerId: 'tr-luis',
      status: 'ACTIVA',
      endDate: DateTime.utc(2026, 8, 10),
    );

    expect(
      isTrainerAssociate(vigente, trainerId: 'tr-ana', today: today),
      isTrue,
    );
    expect(
      isTrainerAssociate(vencidoHaceMucho, trainerId: 'tr-ana', today: today),
      isFalse,
      reason: 'un socio ido hace meses no es carga de trabajo de nadie',
    );
    expect(
      isTrainerAssociate(deBaja, trainerId: 'tr-ana', today: today),
      isFalse,
    );
    expect(
      isTrainerAssociate(deOtroEntrenador, trainerId: 'tr-ana', today: today),
      isFalse,
    );

    final clients = [vigente, vencidoHaceMucho, deBaja, deOtroEntrenador];
    final counts = countAssociatesByTrainer(
      clients,
      trainerIds: {'tr-ana', 'tr-luis'},
      today: today,
    );
    expect(counts['tr-ana'], 1);
    expect(counts['tr-luis'], 1);
    // Contador y lista no pueden discrepar: es la razón de que exista esto.
    expect(
      trainerAssociates(clients, trainerId: 'tr-ana', today: today),
      hasLength(counts['tr-ana']),
    );
  });

  test('un plan borrado no infla ningún contador', () {
    final counts = countAssociatesByPlan(
      [client(planId: 'plan-borrado', status: 'ACTIVA')],
      planIds: {'plan-a'},
      today: today,
    );
    expect(counts, isEmpty);
  });
}
