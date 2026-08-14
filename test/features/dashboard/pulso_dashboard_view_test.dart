import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/core/time/app_clock.dart';
import 'package:gym_client/src/core/utils/datetime_zone.dart';
import 'package:gym_client/src/features/attendance/data/models/attendance_model.dart';
import 'package:gym_client/src/features/attendance/presentation/state/attendance_notifier.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';
import 'package:gym_client/src/features/clients/presentation/state/client_notifier.dart';
import 'package:gym_client/src/features/dashboard/presentation/screens/pulso_dashboard_view.dart';
import 'package:gym_client/src/features/financials/data/models/currency_model.dart';
import 'package:gym_client/src/features/financials/presentation/state/currency_notifier.dart';
import 'package:gym_client/src/features/payments/data/models/payment_model.dart';
import 'package:gym_client/src/features/payments/presentation/state/payment_notifier.dart';

void main() {
  for (final entry in const {
    'compacto': Size(390, 844),
    'mediano': Size(760, 900),
    'expandido': Size(1280, 900),
  }.entries) {
    testWidgets('dashboard PULSO se adapta al ancho ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(const PulsoAdminDashboardView()));
      await tester.pump();

      expect(find.text('PARTE DEL DÍA.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pulso-dashboard-hourly')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pulso-dashboard-income')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pulso-dashboard-attention')),
        findsOneWidget,
      );
      expect(find.text('Sonia Ruiz Vega'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('separa ingresos por moneda y conserva sus símbolos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(const PulsoAdminDashboardView()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('income-eur')), findsOneWidget);
    expect(find.byKey(const ValueKey('income-usd')), findsOneWidget);
    expect(find.text('€25'), findsWidgets);
    expect(find.text(r'$40'), findsWidgets);
    expect(find.textContaining('€65'), findsNothing);
    expect(find.textContaining(r'$65'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la variante recepción conserva el acceso al mostrador', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(760, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(const PulsoReceptionDashboardView()));
    await tester.pump();

    expect(find.text('PARTE DEL TURNO.'), findsOneWidget);
    expect(find.text('PASAR ASISTENCIA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('una membresía pausada no aparece como vencida en atención', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(const PulsoAdminDashboardView()));
    await tester.pumpAndSettle();

    final attention = find.byKey(const ValueKey('pulso-dashboard-attention'));
    expect(
      find.descendant(of: attention, matching: find.text('Pausa Vigencia')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _harness(Widget child) {
  final now = appClock.nowUtc();
  final today = todayInZone(appClock.gymTimezone);

  /// «Hace un rato, pero hoy».
  ///
  /// El parte del día solo cuenta lo de **hoy** (`sameDay`), así que restarle
  /// minutos a `now` manda la fixture a ayer durante los primeros minutos tras
  /// la medianoche del gimnasio, y el panel de ingresos se queda sin tarjetas.
  /// Falló de verdad a las 00:06 UTC del 14-08-2026. Es el mismo tropiezo que
  /// ya costó la fixture de vigencia: una prueba que depende de la hora a la
  /// que se ejecute no está midiendo lo que dice medir.
  DateTime haceUnRato(Duration antes) {
    final momento = now.subtract(antes);
    final inicioDelDia = calendarDateToUtc(today);
    return momento.isBefore(inicioDelDia) ? now : momento;
  }

  final clients = [
    ClientModel(
      id: '100',
      nombres: 'Sonia',
      apellidos: 'Ruiz Vega',
      activo: true,
      membershipStatus: 'ACTIVA',
      membershipVigencia: 'VIGENTE',
      endDate: calendarDateToUtc(today.add(const Duration(days: 2))),
    ),
    ClientModel(
      id: '200',
      nombres: 'Mario',
      apellidos: 'López',
      activo: true,
      membershipStatus: 'ACTIVA',
      membershipVigencia: 'VENCIDA_RECIENTE',
      endDate: calendarDateToUtc(today.subtract(const Duration(days: 1))),
    ),
    ClientModel(
      id: 'paused',
      nombres: 'Pausa',
      apellidos: 'Vigencia',
      activo: true,
      planId: 'plan',
      membershipStatus: 'PAUSADA',
      membershipVigencia: 'PAUSADA',
      endDate: calendarDateToUtc(today.subtract(const Duration(days: 20))),
    ),
  ];
  final attendance = [
    AttendanceModel(
      id: 'a1',
      clientId: '100',
      clientName: 'Sonia Ruiz Vega',
      checkIn: haceUnRato(const Duration(minutes: 12)),
    ),
  ];
  final payments = [
    PaymentModel(
      id: 'p1',
      ci: '100',
      clientName: 'Sonia Ruiz Vega',
      fecha: haceUnRato(const Duration(minutes: 8)),
      amount: 25,
      planId: 'plan',
      currencyId: 'eur',
    ),
    PaymentModel(
      id: 'p2',
      ci: '200',
      clientName: 'Mario López',
      fecha: haceUnRato(const Duration(minutes: 4)),
      amount: 40,
      planId: 'plan',
      currencyId: 'usd',
    ),
  ];
  return ProviderScope(
    overrides: [
      appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
      attendanceNotifierProvider.overrideWith(
        () => _AttendanceNotifier(attendance),
      ),
      paymentNotifierProvider.overrideWith(() => _PaymentNotifier(payments)),
      clientNotifierProvider.overrideWith(() => _ClientNotifier(clients)),
      currencyProvider.overrideWith(
        () => _CurrencyNotifier(const [
          CurrencyModel(id: 'eur', name: 'Euro', code: 'EUR', symbol: '€'),
          CurrencyModel(
            id: 'usd',
            name: 'Dólar estadounidense',
            code: 'USD',
            symbol: r'$',
          ),
        ]),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

class _AttendanceNotifier extends AttendanceNotifier {
  _AttendanceNotifier(this.items);
  final List<AttendanceModel> items;

  @override
  Future<List<AttendanceModel>> build() async => items;

  @override
  Future<void> refresh() async => state = AsyncValue.data(items);
}

class _PaymentNotifier extends PaymentNotifier {
  _PaymentNotifier(this.items);
  final List<PaymentModel> items;

  @override
  Future<List<PaymentModel>> build() async => items;

  @override
  Future<void> refresh() async => state = AsyncValue.data(items);
}

class _ClientNotifier extends ClientNotifier {
  _ClientNotifier(this.items);
  final List<ClientModel> items;

  @override
  Future<List<ClientModel>> build() async => items;

  @override
  Future<void> refresh() async => state = AsyncValue.data(items);
}

class _CurrencyNotifier extends CurrencyNotifier {
  _CurrencyNotifier(this.items);
  final List<CurrencyModel> items;

  @override
  Future<List<CurrencyModel>> build() async => items;

  @override
  Future<void> refresh() async => state = AsyncValue.data(items);
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
