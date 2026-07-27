import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/client_model.dart';
import '../../domain/plan_associates.dart';

/// De dónde se llegó a Clientes: del contador de un plan o del de un
/// entrenador (docs/PLAN_ASOCIADOS.md, opción A).
enum ClientsFilterKind { plan, trainer }

/// Filtro con el que se entra a Clientes desde Planes o desde Entrenadores.
///
/// Vive fuera de la vista porque el salto es entre pantallas: la vista de
/// origen lo deja puesto y Clientes lo recoge al construirse. Se retira desde
/// el aviso que la propia vista de Clientes dibuja, para que nadie quede
/// filtrado sin saberlo.
class ClientsScopeFilter {
  const ClientsScopeFilter({
    required this.kind,
    required this.id,
    required this.label,
  });

  const ClientsScopeFilter.plan({required String planId, required String name})
    : this(kind: ClientsFilterKind.plan, id: planId, label: name);

  const ClientsScopeFilter.trainer({
    required String trainerId,
    required String name,
  }) : this(kind: ClientsFilterKind.trainer, id: trainerId, label: name);

  final ClientsFilterKind kind;
  final String id;
  final String label;

  /// Encabezado del aviso. Un plan tiene «asociados»; un entrenador
  /// «acompaña» socios: no es lo mismo y el rótulo no debe sugerir que sí.
  String get heading => switch (kind) {
    ClientsFilterKind.plan => 'Asociados de',
    ClientsFilterKind.trainer => 'Socios de',
  };

  /// Alcance que viaja al CSV y al nombre del archivo exportado.
  String get scope => switch (kind) {
    ClientsFilterKind.plan => 'Asociados del plan $label',
    ClientsFilterKind.trainer => 'Socios del entrenador $label',
  };

  bool matches(ClientModel client, {required DateTime today}) =>
      switch (kind) {
        ClientsFilterKind.plan => isPlanAssociate(
          client,
          planId: id,
          today: today,
        ),
        ClientsFilterKind.trainer => isTrainerAssociate(
          client,
          trainerId: id,
          today: today,
        ),
      };
}

class ClientsScopeFilterNotifier extends Notifier<ClientsScopeFilter?> {
  @override
  ClientsScopeFilter? build() => null;

  void showPlan({required String planId, required String planName}) {
    state = ClientsScopeFilter.plan(planId: planId, name: planName);
  }

  void showTrainer({required String trainerId, required String trainerName}) {
    state = ClientsScopeFilter.trainer(trainerId: trainerId, name: trainerName);
  }

  void clear() {
    state = null;
  }
}

final clientsScopeFilterProvider =
    NotifierProvider<ClientsScopeFilterNotifier, ClientsScopeFilter?>(
      ClientsScopeFilterNotifier.new,
    );
