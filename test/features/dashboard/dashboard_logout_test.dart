import 'dart:async';

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/attendance/data/models/attendance_model.dart';
import 'package:gym_client/src/features/attendance/presentation/state/attendance_notifier.dart';
import 'package:gym_client/src/features/auth/domain/models/sede_session.dart';
import 'package:gym_client/src/features/auth/domain/models/user.dart';
import 'package:gym_client/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:gym_client/src/features/auth/infrastructure/repositories/auth_repository_impl.dart';
import 'package:gym_client/src/features/auth/presentation/screens/login_screen.dart';
import 'package:gym_client/src/features/auth/presentation/state/auth_notifier.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';
import 'package:gym_client/src/features/clients/presentation/state/client_notifier.dart';
import 'package:gym_client/src/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:gym_client/src/features/dashboard/presentation/state/dashboard_nav_provider.dart';
import 'package:gym_client/src/features/financials/data/models/currency_model.dart';
import 'package:gym_client/src/features/financials/presentation/state/currency_notifier.dart';
import 'package:gym_client/src/features/payments/data/models/payment_model.dart';
import 'package:gym_client/src/features/payments/presentation/state/payment_notifier.dart';
import 'package:gym_client/src/l10n/app_localizations.dart';

void main() {
  for (final entry in const {
    'cabecera': 'Salir',
    'barra lateral': 'CERRAR SESIÓN',
  }.entries) {
    testWidgets(
      'logout desde ${entry.key} espera al repositorio, limpia estado y navega',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repository = _BlockingAuthRepository();
        await tester.pumpWidget(_harness(repository));
        await tester.pump();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(DashboardScreen)),
        );
        expect(container.read(authProvider).value, isNotNull);
        expect(container.read(dashboardNavProvider), 2);

        await tester.tap(find.text(entry.value));
        await repository.logoutStarted.future;
        await tester.pump();

        expect(repository.logoutCalls, 1);
        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
        expect(container.read(authProvider).value, isNotNull);
        expect(container.read(dashboardNavProvider), 2);

        repository.releaseLogout.complete();
        await tester.pumpAndSettle();

        expect(repository.logoutCalls, 1);
        expect(container.read(authProvider).value, isNull);
        expect(container.read(dashboardNavProvider), 0);
        expect(find.byType(DashboardScreen), findsNothing);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _harness(_BlockingAuthRepository repository) {
  return ProviderScope(
    overrides: [
      appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
      authRepositoryProvider.overrideWithValue(repository),
      authProvider.overrideWith(_LoggedInAuthNotifier.new),
      dashboardNavProvider.overrideWith(_SelectedDashboardNavNotifier.new),
      attendanceNotifierProvider.overrideWith(_EmptyAttendanceNotifier.new),
      clientNotifierProvider.overrideWith(_EmptyClientNotifier.new),
      currencyProvider.overrideWith(_EmptyCurrencyNotifier.new),
      paymentNotifierProvider.overrideWith(_EmptyPaymentNotifier.new),
      syncStatusProvider.overrideWith(
        (ref) => Stream.value(
          SyncStatusSnapshot(
            level: SyncStatusLevel.synced,
            label: 'Sincronizado',
            detail: 'Prueba',
            checkedAt: DateTime.utc(2026, 7, 21),
          ),
        ),
      ),
    ],
    child: NeumorphicApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const DashboardScreen(),
    ),
  );
}

class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  FutureOr<User?> build() => const User(
    id: 'admin-1',
    name: 'Administración',
    email: 'admin@gym.test',
    role: 'admin',
  );
}

class _SelectedDashboardNavNotifier extends DashboardNavNotifier {
  @override
  int build() => 2;
}

class _EmptyAttendanceNotifier extends AttendanceNotifier {
  @override
  Future<List<AttendanceModel>> build() async => const [];
}

class _EmptyClientNotifier extends ClientNotifier {
  @override
  Future<List<ClientModel>> build() async => const [];
}

class _EmptyCurrencyNotifier extends CurrencyNotifier {
  @override
  Future<List<CurrencyModel>> build() async => const [];
}

class _EmptyPaymentNotifier extends PaymentNotifier {
  @override
  Future<List<PaymentModel>> build() async => const [];
}

class _BlockingAuthRepository implements AuthRepository {
  final logoutStarted = Completer<void>();
  final releaseLogout = Completer<void>();
  int logoutCalls = 0;

  @override
  Future<User> login(String email, String password) {
    throw UnsupportedError('login no participa en esta prueba');
  }

  @override
  Future<void> logout() async {
    logoutCalls += 1;
    if (!logoutStarted.isCompleted) logoutStarted.complete();
    await releaseLogout.future;
  }

  @override
  Future<User?> getCurrentUser() async => null;

  @override
  Future<SedeSession?> fetchSession() async => null;
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
