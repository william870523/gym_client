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
}

final sedeSessionProvider =
    NotifierProvider<SedeSessionNotifier, SedeSession?>(
      SedeSessionNotifier.new,
    );

/// Nivel de Dueño de la cadena: crear y dar de baja sedes. Solo decide qué se
/// enseña; el servidor lo vuelve a comprobar en cada petición.
final esDuenoDeCadenaProvider = Provider<bool>(
  (ref) => ref.watch(sedeSessionProvider)?.esPlataforma ?? false,
);
