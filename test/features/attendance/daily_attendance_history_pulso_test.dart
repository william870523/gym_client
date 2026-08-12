import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/time/app_clock.dart';
import 'package:gym_client/src/features/attendance/data/models/attendance_model.dart';
import 'package:gym_client/src/features/attendance/presentation/screens/daily_attendance_history_screen.dart';
import 'package:gym_client/src/features/attendance/presentation/state/attendance_history_provider.dart';
import 'package:gym_client/src/features/attendance/presentation/state/attendance_notifier.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';
import 'package:gym_client/src/features/clients/presentation/state/client_notifier.dart';
import 'package:gym_client/src/features/products/data/models/payment_plan_model.dart';
import 'package:gym_client/src/features/products/presentation/state/payment_plan_notifier.dart';

void main() {
  for (final entry in const {
    'compacto': Size(390, 844),
    'mediano': Size(760, 900),
    'escritorio': Size(1280, 900),
  }.entries) {
    testWidgets('historial PULSO se adapta al ancho ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('ASISTENCIA.', findRichText: true), findsOneWidget);
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('Luis Gómez'), findsOneWidget);
      expect(find.text('Eva Ríos'), findsNothing);
      expect(find.text('Entradas hoy'), findsOneWidget);
      expect(find.text('COPIAR CSV'), findsOneWidget);
      final layoutError = tester.takeException();
      if (layoutError is FlutterError) fail(layoutError.toStringDeep());
      expect(layoutError, isNull);
    });
  }

  testWidgets('busca y filtra por estado sin perder datos relacionados', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('attendance-history-search')),
      'Luis',
    );
    await tester.pump();
    expect(find.text('Ana Pérez'), findsNothing);
    expect(find.text('Luis Gómez'), findsOneWidget);
    expect(find.text('Mensual'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('attendance-history-search')),
      '',
    );
    await tester.tap(find.text('FINALIZADAS'));
    await tester.pump();
    expect(find.text('Ana Pérez'), findsNothing);
    expect(find.text('Luis Gómez'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('copia un CSV real de la vista filtrada', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? clipboardText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('COPIAR CSV'));
    await tester.pumpAndSettle();

    expect(clipboardText, contains('Socio,CI,Plan,Entrada'));
    expect(clipboardText, contains('Ana Pérez'));
    expect(clipboardText, contains('Luis Gómez'));
    expect(tester.takeException(), isNull);
  });
}

Widget _harness() {
  final now = appClock.nowUtc();
  final attendances = [
    AttendanceModel(
      id: 'a1',
      clientId: '100',
      checkIn: now,
      clientName: 'Ana Pérez',
    ),
    AttendanceModel(
      id: 'a2',
      clientId: '200',
      checkIn: now,
      checkOut: now,
      clientName: 'Luis Gómez',
    ),
    AttendanceModel(
      id: 'a3',
      clientId: '300',
      checkIn: now.subtract(const Duration(days: 2)),
      checkOut: now.subtract(const Duration(days: 2)),
      clientName: 'Eva Ríos',
    ),
  ];
  final clients = [
    ClientModel(id: '100', nombres: 'Ana', apellidos: 'Pérez', planId: 'p1'),
    ClientModel(id: '200', nombres: 'Luis', apellidos: 'Gómez', planId: 'p1'),
    ClientModel(id: '300', nombres: 'Eva', apellidos: 'Ríos', planId: 'p1'),
  ];
  final plans = [
    PaymentPlanModel(
      id: 'p1',
      nombre: 'Mensual',
      importe: 50,
      duracion: 30,
      monedaId: 'USD',
    ),
  ];

  return ProviderScope(
    overrides: [
      appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
      attendanceHistoryProvider.overrideWith(
        () => _HistoryNotifier(attendances),
      ),
      attendanceNotifierProvider.overrideWith(
        () => _TodayNotifier(attendances.take(2).toList()),
      ),
      clientNotifierProvider.overrideWith(() => _ClientNotifier(clients)),
      paymentPlanProvider.overrideWith(() => _PlanNotifier(plans)),
    ],
    child: const MaterialApp(
      home: Scaffold(body: DailyAttendanceHistoryScreen()),
    ),
  );
}

class _HistoryNotifier extends AttendanceHistoryNotifier {
  _HistoryNotifier(this.items);
  final List<AttendanceModel> items;

  @override
  AttendanceHistoryState build() =>
      AttendanceHistoryState(page: 1, limit: 15, attendances: items);

  @override
  Future<void> loadPage(int page, {String? calendarDate}) async {}

  @override
  Future<List<AttendanceModel>> loadAllForSelectedDate() async => items;
}

class _TodayNotifier extends AttendanceNotifier {
  _TodayNotifier(this.items);
  final List<AttendanceModel> items;

  @override
  Future<List<AttendanceModel>> build() async => items;

  @override
  Future<void> refresh() async => state = AsyncValue.data(items);
}

class _ClientNotifier extends ClientNotifier {
  _ClientNotifier(this.items);
  final List<ClientModel> items;

  @override
  Future<List<ClientModel>> build() async => items;
}

class _PlanNotifier extends PaymentPlanNotifier {
  _PlanNotifier(this.items);
  final List<PaymentPlanModel> items;

  @override
  Future<List<PaymentPlanModel>> build() async => items;
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
