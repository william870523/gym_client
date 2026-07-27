import '../data/models/client_model.dart';

/// Quién cuenta como **asociado** de un plan o de un entrenador
/// (docs/PLAN_ASOCIADOS.md §5).
///
/// Decisión del dueño (25-07-2026): son asociados las membresías `ACTIVA`,
/// `PENDIENTE_PAGO` y las **vencidas recientemente**. La regla vive aquí, en
/// una sola función, porque los contadores de las vistas de Planes y de
/// Entrenadores y la lista filtrada de Clientes deben responder lo mismo: si el
/// contador dice 11 y la lista enseña 8, el operador deja de creerse los dos.

/// Días naturales que una membresía vencida sigue contando como asociada.
/// Moverlo cambia contador y lista a la vez, que es justo lo que se quiere.
const int kPlanAssociateRecentExpiryDays = 30;

/// Estados con membresía viva. `CANCELADA` no aparece: quien se dio de baja
/// dejó de ser asociado. Una membresía vencida por fecha conserva su estado
/// `ACTIVA` —el vencimiento se calcula por cobertura, no por estado—, así que
/// la ventana de gracia se mide con `fecha_fin`.
const Set<String> _liveMembershipStates = {
  'ACTIVA',
  'PENDIENTE_PAGO',
  'PAUSADA',
};

/// Días transcurridos desde que venció la cobertura. Negativo si aún cubre.
int _daysSinceExpiry(DateTime endDate, DateTime today) {
  final end = DateTime.utc(endDate.year, endDate.month, endDate.day);
  final day = DateTime.utc(today.year, today.month, today.day);
  return day.difference(end).inDays;
}

/// El socio tiene una membresía que cuenta hoy, sea de quien sea.
///
/// [today] es la **fecha de negocio del gimnasio**, no la del dispositivo.
bool hasAssociableMembership(ClientModel client, {required DateTime today}) {
  final status = client.membershipStatus;
  if (status == null || !_liveMembershipStates.contains(status)) return false;

  // Contrató y todavía no pagó: es asociado aunque no tenga cobertura.
  if (status == 'PENDIENTE_PAGO') return true;

  final end = client.endDate;
  if (end == null) return true;
  return _daysSinceExpiry(end, today) <= kPlanAssociateRecentExpiryDays;
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
