import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_tokens.dart';
import 'package:gym_client/src/core/time/app_clock.dart';
import 'package:gym_client/src/core/utils/datetime_zone.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';
import 'package:gym_client/src/features/clients/presentation/screens/clients_pulso_view.dart';
import 'package:gym_client/src/features/clients/presentation/state/client_notifier.dart';
import 'package:gym_client/src/features/clients/presentation/state/weight_history_notifier.dart';
import 'package:gym_client/src/features/configuration/data/models/nacionalidad_model.dart';
import 'package:gym_client/src/features/configuration/data/models/referencia_model.dart';
import 'package:gym_client/src/features/configuration/presentation/state/nacionalidad_notifier.dart';
import 'package:gym_client/src/features/configuration/presentation/state/referencia_notifier.dart';
import 'package:gym_client/src/features/payments/presentation/state/payment_notifier.dart';
import 'package:gym_client/src/features/products/data/models/payment_plan_model.dart';
import 'package:gym_client/src/features/products/presentation/state/payment_plan_notifier.dart';
import 'package:gym_client/src/features/schedules/data/models/horario_model.dart';
import 'package:gym_client/src/features/schedules/presentation/state/horario_notifier.dart';
import 'package:gym_client/src/features/trainers/data/models/trainer_model.dart';
import 'package:gym_client/src/features/trainers/presentation/providers/trainer_notifier.dart';

void main() {
  const sizes = <String, Size>{
    'compacto': Size(390, 844),
    'mediano': Size(760, 900),
    'escritorio': Size(1280, 900),
    'ventana baja': Size(1024, 650),
  };

  for (final entry in sizes.entries) {
    testWidgets('Clientes PULSO se adapta al ancho ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('CLIENTES.', findRichText: true), findsOneWidget);
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('Luis Gómez'), findsOneWidget);
      expect(find.text('MODO LOCAL'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final row = find.descendant(
        of: find.byKey(const PageStorageKey('pulso-clients-list')),
        matching: find.text('Ana Pérez'),
      );
      if (entry.key == 'mediano') {
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.text('LECTURA OPERATIVA'), findsOneWidget);
      }
      if (entry.key == 'escritorio') {
        await tester.tap(row);
        await tester.pump();
        expect(find.text('LECTURA OPERATIVA'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('integra vigencia, contacto y próxima acción', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Luis Gómez'));
    await tester.pump();

    expect(find.text('Renovar membresía'), findsWidgets);
    expect(find.text('0 de 3 datos disponibles'), findsOneWidget);
    expect(find.text('Sin entrenador'), findsWidgets);
    expect(find.text('Sin horario'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite editar y conserva horario, plan y fechas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notifier = _ClientNotifier(_clients());
    await tester.pumpWidget(_harness(notifier: notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar Ana Pérez'));
    await tester.pumpAndSettle();
    expect(find.text('Editar Cliente'), findsOneWidget);
    expect(find.text('CLIENTES.', findRichText: true), findsOneWidget);
    _expectOriginalFormGeometry(tester);

    await tester.enterText(find.byType(TextFormField).at(1), 'Ana María');
    await tester.tap(find.text('Guardar Cliente'));
    await tester.pumpAndSettle();

    expect(notifier.updates, hasLength(1));
    final updated = notifier.updates.single;
    expect(updated.nombres, 'Ana María');
    expect(updated.planId, 'plan-mensual');
    expect(updated.trainerId, 'trainer-ana');
    expect(updated.scheduleId, 'morning');
    expect(updated.startDate!.isUtc, isTrue);
    expect(updated.endDate!.isUtc, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('alta conserva foto a la izquierda y secciones a la derecha', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('NUEVO SOCIO'));
    await tester.pumpAndSettle();

    expect(find.text('Crear Cliente'), findsOneWidget);
    expect(find.text('Foto del Cliente'), findsOneWidget);
    expect(find.text('Estado de la Cuenta'), findsOneWidget);
    expect(find.text('Información Personal'), findsOneWidget);
    expect(find.text('Membresía y Plan'), findsOneWidget);
    expect(find.text('Guardar Cliente'), findsOneWidget);
    _expectOriginalFormGeometry(tester);

    final photo = tester.getTopLeft(find.text('Foto del Cliente'));
    final personal = tester.getTopLeft(find.text('Información Personal'));
    final membership = tester.getTopLeft(find.text('Membresía y Plan'));
    expect(photo.dx, lessThan(personal.dx));
    expect(personal.dy, lessThan(membership.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtra socios que requieren atención', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Atención').last);
    await tester.pump();
    final list = find.byKey(const PageStorageKey('pulso-clients-list'));
    expect(
      find.descendant(of: list, matching: find.text('Luis Gómez')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: list, matching: find.text('Ana Pérez')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

void _expectOriginalFormGeometry(WidgetTester tester) {
  final shellFinder = find.byKey(const ValueKey('pulso-client-form-shell'));
  final sidebarFinder = find.byKey(const ValueKey('pulso-client-form-sidebar'));
  final gapFinder = find.byKey(const ValueKey('pulso-client-form-main-gap'));

  expect(tester.getSize(shellFinder).width, 1100);
  expect(tester.getSize(sidebarFinder).width, 300);
  expect(tester.getSize(gapFinder).width, 32);

  final shell = tester.widget<Container>(shellFinder);
  final tokens = PulsoTokens.of(tester.element(shellFinder));
  expect((shell.decoration! as BoxDecoration).color, tokens.floor);

  Offset labelPosition(String label) => tester.getTopLeft(
    find
        .byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText().startsWith(label),
        )
        .first,
  );

  final ci = labelPosition('Cédula de Identidad (CI)');
  final sex = labelPosition('Sexo');
  final names = labelPosition('Nombres');
  final surnames = labelPosition('Apellidos');
  final height = labelPosition('Estatura');
  final weight = labelPosition('Peso');

  expect(ci.dy, closeTo(sex.dy, 1));
  expect(names.dy, closeTo(surnames.dy, 1));
  expect(height.dy, closeTo(weight.dy, 1));
  expect(ci.dx, lessThan(sex.dx));
  expect(names.dx, lessThan(surnames.dx));
  expect(ci.dy, lessThan(names.dy));
  expect(names.dy, lessThan(height.dy));
}

List<ClientModel> _clients() {
  final today = todayInZone(appClock.gymTimezone);
  return [
    ClientModel(
      id: '100',
      nombres: 'Ana',
      apellidos: 'Pérez',
      correo: 'ana@gym.test',
      telefono: 5551000,
      direccion: 'Main St 1',
      nacionalidadId: 'nat-us',
      planId: 'plan-mensual',
      trainerId: 'trainer-ana',
      scheduleId: 'morning',
      startDate: calendarDateToUtc(today.subtract(const Duration(days: 5))),
      endDate: calendarDateToUtc(today.add(const Duration(days: 25))),
      estatura_cliente: 165,
      peso: 62,
    ),
    ClientModel(
      id: '200',
      nombres: 'Luis',
      apellidos: 'Gómez',
      nacionalidadId: 'nat-us',
      planId: 'plan-mensual',
      startDate: calendarDateToUtc(today.subtract(const Duration(days: 40))),
      endDate: calendarDateToUtc(today.subtract(const Duration(days: 10))),
    ),
    ClientModel(
      id: '300',
      nombres: 'Eva',
      apellidos: 'Ríos',
      nacionalidadId: 'nat-us',
      activo: false,
    ),
  ];
}

Widget _harness({_ClientNotifier? notifier}) {
  final clients = _clients();
  return ProviderScope(
    overrides: [
      appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
      syncStatusProvider.overrideWith(
        (ref) => Stream.value(
          SyncStatusSnapshot.offline(
            detail: 'API remota no disponible',
            source: 'sync-local',
          ),
        ),
      ),
      clientNotifierProvider.overrideWith(
        () => notifier ?? _ClientNotifier(clients),
      ),
      paymentPlanProvider.overrideWith(() => _PlanNotifier(_plans())),
      trainerProvider.overrideWith(() => _TrainerNotifier(_trainers())),
      horarioNotifierProvider.overrideWith(
        () => _ScheduleNotifier(_schedules()),
      ),
      nacionalidadProvider.overrideWith(
        () => _NationalityNotifier(_nationalities()),
      ),
      referenciaNotifierProvider.overrideWith(
        () => _ReferralNotifier(const []),
      ),
      for (final client in clients) ...[
        clientPaymentHistoryProvider(
          client.id,
        ).overrideWith((ref) async => const []),
        weightHistoryProvider(client.id).overrideWith((ref) async => const []),
      ],
    ],
    child: const MaterialApp(home: Scaffold(body: ClientsPulsoView())),
  );
}

List<PaymentPlanModel> _plans() => [
  PaymentPlanModel(
    id: 'plan-mensual',
    nombre: 'Mensual',
    importe: 50,
    duracion: 30,
    monedaId: 'USD',
  ),
];

List<TrainerModel> _trainers() => [
  TrainerModel(
    id: 'trainer-ana',
    ci: 'T1',
    nombres: 'Ana',
    apellidos: 'Coach',
    activo: true,
    fechaInicio: DateTime.utc(2025),
  ),
];

List<HorarioModel> _schedules() => [
  HorarioModel(id: 'morning', nombre: 'Mañana', horaInicio: 360, horaFin: 720),
];

List<NacionalidadModel> _nationalities() => const [
  NacionalidadModel(id: 'nat-us', name: 'Estadounidense', isoCode: 'US'),
];

class _ClientNotifier extends ClientNotifier {
  _ClientNotifier(this.items);
  final List<ClientModel> items;
  final updates = <ClientModel>[];

  @override
  Future<List<ClientModel>> build() async => items;

  @override
  Future<void> updateClient(ClientModel client) async {
    updates.add(client);
  }
}

class _PlanNotifier extends PaymentPlanNotifier {
  _PlanNotifier(this.items);
  final List<PaymentPlanModel> items;
  @override
  Future<List<PaymentPlanModel>> build() async => items;
}

class _TrainerNotifier extends TrainerNotifier {
  _TrainerNotifier(this.items);
  final List<TrainerModel> items;
  @override
  Future<List<TrainerModel>> build() async => items;
}

class _ScheduleNotifier extends HorarioNotifier {
  _ScheduleNotifier(this.items);
  final List<HorarioModel> items;
  @override
  Future<List<HorarioModel>> build() async => items;
}

class _NationalityNotifier extends NacionalidadNotifier {
  _NationalityNotifier(this.items);
  final List<NacionalidadModel> items;
  @override
  Future<List<NacionalidadModel>> build() async => items;
}

class _ReferralNotifier extends ReferenciaNotifier {
  _ReferralNotifier(this.items);
  final List<ReferenciaModel> items;
  @override
  Future<List<ReferenciaModel>> build() async => items;
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;
  @override
  Future<void> save(AppearancePreference preference) async {}
}
