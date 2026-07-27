import '../data/models/client_model.dart';
import 'membership_vigencia.dart';

/// Quién cuenta como **asociado** de un plan o de un entrenador
/// (docs/PLAN_ASOCIADOS.md §5).
///
/// Decisión del dueño (25-07-2026): son asociados las membresías `ACTIVA`,
/// `PENDIENTE_PAGO` y las **vencidas recientemente**. La regla vive aquí, en
/// una sola función, porque los contadores de las vistas de Planes y de
/// Entrenadores y la lista filtrada de Clientes deben responder lo mismo: si el
/// contador dice 11 y la lista enseña 8, el operador deja de creerse los dos.

/// Días naturales que una membresía vencida sigue contando como asociada.
///
/// Es el mismo número que la vigencia derivada, y no una copia: si fueran dos
/// constantes, moverlas por separado haría que el contador de un plan y la
/// ficha del socio se contradijeran.
const int kPlanAssociateRecentExpiryDays = kMembershipRecentExpiryDays;

/// El socio tiene una membresía que cuenta hoy, sea de quien sea.
///
/// Se apoya en la vigencia derivada (`membership_vigencia.dart`), que es la
/// misma regla que aplica el servidor. Cuentan como asociados quien está
/// vigente, quien venció hace poco, quien está en pausa y quien contrató y aún
/// no pagó. `CANCELADA` no: quien se dio de baja dejó de ser asociado.
///
/// [today] es la **fecha de negocio del gimnasio**, no la del dispositivo.
bool hasAssociableMembership(ClientModel client, {required DateTime today}) {
  // Cuando el servidor manda la vigencia ya derivada, manda el servidor: su
  // reloj es el confiable y su fecha de negocio la de la sede.
  final vigencia =
      membershipVigenciaFromServer(client.membershipVigencia) ??
      resolveMembershipVigencia(
        status: client.membershipStatus,
        endDate: client.endDate,
        today: today,
      );
  return switch (vigencia) {
    MembershipVigencia.current ||
    MembershipVigencia.recentlyExpired ||
    MembershipVigencia.paused ||
    MembershipVigencia.pendingPayment => true,
    MembershipVigencia.expired ||
    MembershipVigencia.cancelled ||
    MembershipVigencia.none => false,
  };
}

/// `true` si [client] cuenta como asociado del plan [planId].
bool isPlanAssociate(
  ClientModel client, {
  required String planId,
  required DateTime today,
}) {
  if (planId.isEmpty || client.planId != planId) return false;
  return hasAssociableMembership(client, today: today);
}

/// `true` si [client] cuenta como socio acompañado por el entrenador
/// [trainerId]. Mismo criterio de membresía que en los planes: un socio dado de
/// baja hace medio año no es carga de trabajo de nadie.
bool isTrainerAssociate(
  ClientModel client, {
  required String trainerId,
  required DateTime today,
}) {
  if (trainerId.isEmpty || client.trainerId != trainerId) return false;
  return hasAssociableMembership(client, today: today);
}

/// Asociados de cada plan, con el mismo criterio que [isPlanAssociate].
///
/// Solo se recorren los planes de [planIds]; un socio apuntando a un plan
/// borrado no infla ningún contador.
Map<String, int> countAssociatesByPlan(
  Iterable<ClientModel> clients, {
  required Set<String> planIds,
  required DateTime today,
}) => _countBy(
  clients,
  ids: planIds,
  today: today,
  keyOf: (client) => client.planId,
);

/// Socios por entrenador, con el mismo criterio que [isTrainerAssociate].
Map<String, int> countAssociatesByTrainer(
  Iterable<ClientModel> clients, {
  required Set<String> trainerIds,
  required DateTime today,
}) => _countBy(
  clients,
  ids: trainerIds,
  today: today,
  keyOf: (client) => client.trainerId,
);

Map<String, int> _countBy(
  Iterable<ClientModel> clients, {
  required Set<String> ids,
  required DateTime today,
  required String? Function(ClientModel) keyOf,
}) {
  final counts = <String, int>{};
  for (final client in clients) {
    final key = keyOf(client);
    if (key == null || !ids.contains(key)) continue;
    if (!hasAssociableMembership(client, today: today)) continue;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
}

/// Los asociados de un plan concreto, en el orden recibido.
List<ClientModel> planAssociates(
  Iterable<ClientModel> clients, {
  required String planId,
  required DateTime today,
}) => [
  for (final client in clients)
    if (isPlanAssociate(client, planId: planId, today: today)) client,
];

/// Los socios de un entrenador concreto, en el orden recibido.
List<ClientModel> trainerAssociates(
  Iterable<ClientModel> clients, {
  required String trainerId,
  required DateTime today,
}) => [
  for (final client in clients)
    if (isTrainerAssociate(client, trainerId: trainerId, today: today)) client,
];
