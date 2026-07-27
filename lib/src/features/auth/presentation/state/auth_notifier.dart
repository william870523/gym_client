import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/models/user.dart';
import '../../infrastructure/repositories/auth_repository_impl.dart';
import '../../../../core/config/env.dart';
import '../../../../core/theme/pulso/appearance_provider.dart';
import '../../../../core/time/app_clock.dart';
import 'sede_session_provider.dart';

part 'auth_notifier.g.dart';

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  @override
  FutureOr<User?> build() {
    return null; // Initial state: Not logged in
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.login(email, password);
      // La sede activa y el nivel los resuelve el servidor, no el login: el
      // nivel de Dueño de la cadena llega y se revoca por sincronización
      // (docs/MULTI_SEDE.md §3).
      final session = await repository.fetchSession();
      ref.read(sedeSessionProvider.notifier).set(session);
      try {
        await appClock.synchronize(
          Env.baseUrl,
          gymId: session?.gymId ?? user.gymId,
        );
      } catch (_) {
        // El login local no depende de tener conexión con la autoridad horaria.
      }
      // La apariencia pasa al scope del usuario (gymos.ui.<user_id>.*).
      ref.read(appearanceUserProvider.notifier).set(user.id);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    final repository = ref.read(authRepositoryProvider);
    await repository.logout();
    ref.read(sedeSessionProvider.notifier).clear();
    ref.read(appearanceUserProvider.notifier).set(null);
    state = const AsyncValue.data(null);
  }
}
