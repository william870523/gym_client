import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/sede_session.dart';

/// Sede activa y nivel de la sesión (docs/MULTI_SEDE.md §3).
///
/// Es un simple depósito de estado, **sin dependencias**, a propósito: el
/// interceptor de red lo lee para poner la cabecera `X-Gym-Id`, y si este
/// proveedor dependiera del cliente HTTP se formaría un ciclo. Lo llena la
/// sesión al entrar y lo vacía al salir.
class SedeSessionNotifier extends Notifier<SedeSession?> {
  @override
  SedeSession? build() => null;

  void set(SedeSession? session) => state = session;

  void clear() => state = null;

  /// Cambia la sede activa (docs/MULTI_SEDE.md §3.4).
  ///
  /// Solo mueve el estado; **la invalidación la produce la cascada**:
  /// `apiClientProvider` observa esta sede, cada repositorio observa el cliente
  /// y cada vista observa su repositorio, así que al cambiarla se reconstruye
  /// todo y no sobrevive nada de la sede anterior.
  ///
  /// No se comprueba aquí si la persona puede abrir esa sede: eso lo decide el
  /// servidor en cada petición y responde `404` si no. El cliente solo declara
  /// dónde cree estar.
  void cambiarSede(String gymId) {
    final actual = state;
    if (actual == null || actual.gymId == gymId) return;
    state = SedeSession(
      userId: actual.userId,
      gymId: gymId,
      role: actual.role,
      esPlataforma: actual.esPlataforma,
      origen: actual.origen,
      permissions: actual.permissions,
    );
  }
}

final sedeSessionProvider = NotifierProvider<SedeSessionNotifier, SedeSession?>(
  SedeSessionNotifier.new,
);

/// Nivel de Dueño de la cadena: crear y dar de baja sedes. Solo decide qué se
/// enseña; el servidor lo vuelve a comprobar en cada petición.
final esDuenoDeCadenaProvider = Provider<bool>(
  (ref) => ref.watch(sedeSessionProvider)?.esPlataforma ?? false,
);
