import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/client_model.dart';
import '../../domain/plan_associates.dart';

/// De dónde se llegó a Clientes: del contador de un plan, del de un entrenador
/// (docs/PLAN_ASOCIADOS.md, opción A) o de una fila del cruzador de
/// segmentación (docs/PLAN_ESTADISTICAS.md §5).
enum ClientsFilterKind { plan, trainer, attribute }

/// Atributo del socio por el que agrupa el cruzador y, por tanto, por el que
/// se puede filtrar la lista.
///
/// Son los ejes **del socio**: se leen de su ficha con el valor que tiene hoy,
/// que es exactamente lo que agrupa el cruzador. Las dimensiones del cobro
/// —moneda, cobrador, medio de pago, cuenta— no están aquí a propósito: un
/// socio no tiene medio de pago, lo tienen sus cobros, así que no hay conjunto
/// de socios que enseñar. Tampoco está `estado`: su corte de tres valores lo
/// calcula el servidor en SQL y reproducirlo aquí sería una segunda
/// implementación de la misma regla. Y tampoco `sede`: `ClientModel` no trae
/// `gym_id`, así que no hay con qué casarla —y en el escritorio, que es de una
/// sola sede, filtrar por ella no separaría a nadie—.
enum ClientsAttribute {
  sexo,
  nacionalidad,
  categoria,
  referencia,
  horario,
  entrenador,
  plan;

  /// Nombre del eje tal como lo llama el cruzador.
  static ClientsAttribute? fromDimension(String dimension) =>
      switch (dimension) {
        'sexo' => ClientsAttribute.sexo,
        'nacionalidad' => ClientsAttribute.nacionalidad,
        'categoria' => ClientsAttribute.categoria,
        'referencia' => ClientsAttribute.referencia,
        'horario' => ClientsAttribute.horario,
        'entrenador' => ClientsAttribute.entrenador,
        'plan' => ClientsAttribute.plan,
        _ => null,
      };

  String get titulo => switch (this) {
    ClientsAttribute.sexo => 'sexo',
    ClientsAttribute.nacionalidad => 'nacionalidad',
    ClientsAttribute.categoria => 'categoría',
    ClientsAttribute.referencia => 'canal de captación',
    ClientsAttribute.horario => 'franja declarada',
    ClientsAttribute.entrenador => 'entrenador',
    ClientsAttribute.plan => 'plan',
  };

  String? valorDe(ClientModel client) => switch (this) {
    ClientsAttribute.sexo => client.sexo,
    ClientsAttribute.nacionalidad => client.nacionalidadId,
    ClientsAttribute.categoria => client.categoria,
    ClientsAttribute.referencia => client.referralId,
    ClientsAttribute.horario => client.scheduleId,
    ClientsAttribute.entrenador => client.trainerId,
    ClientsAttribute.plan => client.planId,
  };
}

/// Clave con la que el cruzador agrupa lo que no tiene valor. Filtrar por ella
/// devuelve justamente a esos socios, que es la única forma de que el hueco se
/// pueda mirar en vez de quedar como una barra sin destino.
const String kSinDatoKey = 'SIN DATO';

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
    this.attribute,
  });

  /// Fila del cruzador: los socios cuyo [attribute] vale [id].
  ///
  /// A diferencia del filtro de plan y de entrenador, aquí **no** se aplica la
  /// regla de asociado: el cruzador agrupa el padrón vivo por el valor que el
  /// socio tiene hoy, y la lista tiene que enseñar exactamente ese conjunto. Si
  /// filtrase por asociados, la barra diría 25 y la lista 18, que es la manera
  /// segura de que el operador deje de creerse las dos.
  const ClientsScopeFilter.attribute({
    required ClientsAttribute attribute,
    required String value,
    required String name,
  }) : this(
         kind: ClientsFilterKind.attribute,
         id: value,
         label: name,
         attribute: attribute,
       );

  const ClientsScopeFilter.plan({required String planId, required String name})
    : this(kind: ClientsFilterKind.plan, id: planId, label: name);

  const ClientsScopeFilter.trainer({
    required String trainerId,
    required String name,
  }) : this(kind: ClientsFilterKind.trainer, id: trainerId, label: name);

  final ClientsFilterKind kind;
  final String id;
  final String label;

  /// Solo cuando `kind` es `attribute`.
  final ClientsAttribute? attribute;

  /// Encabezado del aviso. Un plan tiene «asociados»; un entrenador
  /// «acompaña» socios: no es lo mismo y el rótulo no debe sugerir que sí. Y
  /// una fila del cruzador no es ninguna de las dos: es un corte del padrón.
  String get heading => switch (kind) {
    ClientsFilterKind.plan => 'Asociados de',
    ClientsFilterKind.trainer => 'Socios de',
    ClientsFilterKind.attribute =>
      'Socios por ${attribute?.titulo ?? "atributo"}:',
  };

  /// Alcance que viaja al CSV y al nombre del archivo exportado.
  String get scope => switch (kind) {
    ClientsFilterKind.plan => 'Asociados del plan $label',
    ClientsFilterKind.trainer => 'Socios del entrenador $label',
    ClientsFilterKind.attribute =>
      'Socios con ${attribute?.titulo ?? "atributo"} $label',
  };

  bool matches(ClientModel client, {required DateTime today}) => switch (kind) {
    ClientsFilterKind.plan => isPlanAssociate(client, planId: id, today: today),
    ClientsFilterKind.trainer => isTrainerAssociate(
      client,
      trainerId: id,
      today: today,
    ),
    ClientsFilterKind.attribute => _matchesAttribute(client),
  };

  bool _matchesAttribute(ClientModel client) {
    final atributo = attribute;
    if (atributo == null) return true;
    final valor = atributo.valorDe(client)?.trim() ?? '';
    // El cruzador agrupa lo vacío bajo «SIN DATO»; filtrar por esa clave tiene
    // que devolver justamente a esos socios.
    if (id == kSinDatoKey) return valor.isEmpty;
    return valor == id;
  }
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

  /// Entrada desde una fila del cruzador de segmentación.
  void showAttribute({
    required ClientsAttribute attribute,
    required String value,
    required String label,
  }) {
    state = ClientsScopeFilter.attribute(
      attribute: attribute,
      value: value,
      name: label,
    );
  }

  void clear() {
    state = null;
  }
}

final clientsScopeFilterProvider =
    NotifierProvider<ClientsScopeFilterNotifier, ClientsScopeFilter?>(
      ClientsScopeFilterNotifier.new,
    );
