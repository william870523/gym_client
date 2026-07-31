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
import 'package:gym_client/src/features/clients/presentation/state/clients_scope_filter_provider.dart';
import 'package:gym_client/src/features/clients/presentation/state/weight_history_notifier.dart';
import 'package:gym_client/src/features/dashboard/presentation/state/dashboard_nav_provider.dart';
import 'package:gym_client/src/features/statistics/presentation/state/statistics_providers.dart';
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

  testWidgets('abre la estadística del socio elegido desde Clientes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ClientsPulsoView)),
    );

    await tester.tap(find.text('Ana Pérez'));
    await tester.pump();
    final statisticsButton = find.byKey(
      const ValueKey('cliente-ver-estadistica'),
    );
    await tester.ensureVisible(statisticsButton);
    await tester.pump();
    await tester.tap(statisticsButton);
    await tester.pump();

    expect(container.read(selectedMemberProvider), '100');
    expect(container.read(dashboardNavProvider), 31);
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
    await tester.tap(find.text('Guardar cambios'));
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
    expect(find.text('Guardar'), findsOneWidget);
    _expectOriginalFormGeometry(tester);

    final photo = tester.getTopLeft(find.text('Foto del Cliente'));
    final personal = tester.getTopLeft(find.text('Información Personal'));
    final membership = tester.getTopLeft(find.text('Membresía y Plan'));
    expect(photo.dx, lessThan(personal.dx));
    expect(personal.dy, lessThan(membership.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('CI válido autodetecta sexo y respeta la selección manual', (
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

    await tester.enterText(
      find.byKey(const ValueKey('pulso-client-ci')),
      '91021020015',
    );
    await tester.pump();

    var sex = tester.widget<DropdownButtonFormField>(
      find.byKey(const ValueKey('pulso-client-sex')),
    );
    expect(sex.initialValue, 'F');
    expect(find.text('Sexo · desde CI'), findsOneWidget);
    expect(find.textContaining('CI cubano válido'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pulso-client-sex')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masculino').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pulso-client-ci')),
      '85020290015',
    );
    await tester.pump();

    sex = tester.widget<DropdownButtonFormField>(
      find.byKey(const ValueKey('pulso-client-sex')),
    );
    expect(sex.initialValue, 'M');
    expect(find.text('Sexo · desde CI'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // --- E0: fecha de nacimiento (docs/PLAN_ESTADISTICAS.md §7-bis) ---

  testWidgets('con carné cubano la fecha se deriva y no se deja teclear', (
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

    // Sin carné completo no se inventa una fecha.
    expect(
      find.byKey(const ValueKey('pulso-client-birthdate-derived')),
      findsOneWidget,
    );
    expect(find.textContaining('Se calculará del carné'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('pulso-client-ci')),
      '91021020015',
    );
    await tester.pump();

    expect(find.textContaining('Derivada del carné'), findsOneWidget);
    // No hay selector de fecha: el dato no se teclea con carné cubano.
    expect(
      find.byKey(const ValueKey('pulso-client-birthdate-picker')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('con pasaporte la fecha se captura en vez de derivarse', (
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

    await tester.tap(find.byKey(const ValueKey('document-type-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pasaporte').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('pulso-client-birthdate-picker')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('pulso-client-birthdate-derived')),
      findsNothing,
    );
    expect(find.text('Seleccionar fecha'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('avisa cuando el sexo declarado contradice al carné', (
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

    // Este carné codifica femenino en su dígito 10.
    await tester.enterText(
      find.byKey(const ValueKey('pulso-client-ci')),
      '91021020015',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('pulso-client-sex-mismatch')),
      findsNothing,
    );

    // Al forzar masculino, los dos datos se contradicen: se avisa, no se
    // corrige — cuál está mal es una decisión humana.
    await tester.tap(find.byKey(const ValueKey('pulso-client-sex')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masculino').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('pulso-client-sex-mismatch')),
      findsOneWidget,
    );
    expect(find.textContaining('dígito 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('documento heredado se puede editar sin bloqueo de CI cubano', (
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

    expect(
      find.textContaining('Documento heredado sin clasificar'),
      findsOneWidget,
    );
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(notifier.updates, hasLength(1));
    expect(notifier.updates.single.id, '100');
    expect(notifier.updates.single.documentType, 'DESCONOCIDO');
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

  testWidgets('acota la lista a los asociados del plan y deja quitarlo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = _container();
    await tester.pumpWidget(_harness(container: container));
    await tester.pumpAndSettle();

    // Llega el filtro desde la vista de Planes.
    container
        .read(clientsScopeFilterProvider.notifier)
        .showPlan(planId: 'plan-mensual', planName: 'Mensual');
    await tester.pumpAndSettle();

    final list = find.byKey(const PageStorageKey('pulso-clients-list'));
    // Vigente y vencida reciente sí; vencida hace 90 días y quien no tiene
    // plan, no. El aviso dice el mismo número que la lista enseña.
    expect(
      find.descendant(of: list, matching: find.text('Ana Pérez')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: list, matching: find.text('Luis Gómez')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: list, matching: find.text('Tomás Vega')),
      findsNothing,
    );
    expect(
      find.descendant(of: list, matching: find.text('Eva Ríos')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('clients-scope-filter-notice')),
      findsOneWidget,
    );
    expect(find.textContaining('2 socios'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('clients-scope-filter-clear')));
    await tester.pumpAndSettle();

    expect(container.read(clientsScopeFilterProvider), isNull);
    expect(
      find.byKey(const ValueKey('clients-scope-filter-notice')),
      findsNothing,
    );
    expect(
      find.descendant(of: list, matching: find.text('Tomás Vega')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('también acota por entrenador, con su propio rótulo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = _container();
    await tester.pumpWidget(_harness(container: container));
    await tester.pumpAndSettle();

    // Llega el filtro desde la vista de Entrenadores.
    container
        .read(clientsScopeFilterProvider.notifier)
        .showTrainer(trainerId: 'trainer-ana', trainerName: 'Ana Coach');
    await tester.pumpAndSettle();

    final list = find.byKey(const PageStorageKey('pulso-clients-list'));
    expect(
      find.descendant(of: list, matching: find.text('Ana Pérez')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: list, matching: find.text('Luis Gómez')),
      findsNothing,
    );
    // Un entrenador «acompaña» socios; no los tiene «asociados» como un plan.
    expect(find.textContaining('Socios de'), findsWidgets);
    expect(
      find.byKey(const ValueKey('clients-scope-filter-notice')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('el filtro de plan limpia búsqueda y filtro de estado previos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = _container();
    await tester.pumpWidget(_harness(container: container));
    await tester.pumpAndSettle();

    // El operador venía filtrando por «Inactivos» y buscando otra cosa. Si eso
    // sobreviviera, entraría a ver los asociados y encontraría la lista vacía.
    await tester.tap(find.text('Inactivos').last);
    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Ningún socio coincide con la consulta.'), findsOneWidget);

    container
        .read(clientsScopeFilterProvider.notifier)
        .showPlan(planId: 'plan-mensual', planName: 'Mensual');
    await tester.pumpAndSettle();

    final list = find.byKey(const PageStorageKey('pulso-clients-list'));
    expect(
      find.descendant(of: list, matching: find.text('Ana Pérez')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('exportar en CSV solo se ofrece si hay algo a la vista', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    IconButton exportButton() => tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const ValueKey('clients-export-csv')),
        matching: find.byType(IconButton),
      ),
    );

    expect(exportButton().onPressed, isNotNull);

    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pumpAndSettle();
    // Sin filas visibles no hay nada que exportar: el botón se apaga en vez de
    // producir un archivo con solo la cabecera.
    expect(exportButton().onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un cobro confirmado actualiza la vigencia sin botón manual', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final active = _clients();
    final pending = [
      active.first.copyWith(membershipStatus: 'PENDIENTE_PAGO'),
      ...active.skip(1),
    ];
    final notifier = _RefreshClientNotifier(pending, active);

    await tester.pumpWidget(
      _harness(
        notifier: notifier,
        view: ClientsPulsoView(paymentFlow: (_, _, _) async => true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pendiente de pago'), findsOneWidget);
    final anaRow = find.descendant(
      of: find.byKey(const PageStorageKey('pulso-clients-list')),
      matching: find.text('Ana Pérez'),
    );
    await tester.tap(anaRow);
    await tester.pumpAndSettle();
    expect(find.text('LECTURA OPERATIVA'), findsOneWidget);
    await tester.ensureVisible(find.text('COBRAR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('COBRAR'));
    await tester.pumpAndSettle();

    expect(notifier.refreshCount, 1);
    expect(find.text('Pendiente de pago'), findsNothing);
    expect(find.text('Vigente'), findsWidgets);
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

  final ci = tester.getTopLeft(find.byKey(const ValueKey('pulso-client-ci')));
  final sex = labelPosition('Sexo');
  final names = labelPosition('Nombres');
  final surnames = labelPosition('Apellidos');
  final height = labelPosition('Estatura');
  final weight = labelPosition('Peso');

  expect(names.dy, closeTo(surnames.dy, 1));
  expect(height.dy, closeTo(weight.dy, 1));
  expect(ci.dx, lessThan(sex.dx));
  expect(find.byKey(const ValueKey('document-type-selector')), findsOneWidget);
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
      membershipStatus: 'ACTIVA',
      trainerId: 'trainer-ana',
      scheduleId: 'morning',
      startDate: calendarDateToUtc(today.subtract(const Duration(days: 5))),
      endDate: calendarDateToUtc(today.add(const Duration(days: 25))),
      estatura_cliente: 165,
      peso: 62,
    ),
    // Venció hace 10 días: sigue siendo asociado del plan (ventana de 30).
    ClientModel(
      id: '200',
      nombres: 'Luis',
      apellidos: 'Gómez',
      nacionalidadId: 'nat-us',
      planId: 'plan-mensual',
      membershipStatus: 'ACTIVA',
      startDate: calendarDateToUtc(today.subtract(const Duration(days: 40))),
      endDate: calendarDateToUtc(today.subtract(const Duration(days: 10))),
    ),
    // Venció hace 90 días: ya no cuenta como asociado del plan.
    ClientModel(
      id: '250',
      nombres: 'Tomás',
      apellidos: 'Vega',
      nacionalidadId: 'nat-us',
      planId: 'plan-mensual',
      membershipStatus: 'ACTIVA',
      startDate: calendarDateToUtc(today.subtract(const Duration(days: 120))),
      endDate: calendarDateToUtc(today.subtract(const Duration(days: 90))),
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

Widget _harness({
  _ClientNotifier? notifier,
  Widget? view,
  ProviderContainer? container,
}) {
  return UncontrolledProviderScope(
    container: container ?? _container(notifier: notifier),
    child: MaterialApp(home: Scaffold(body: view ?? const ClientsPulsoView())),
  );
}

ProviderContainer _container({_ClientNotifier? notifier}) {
  final clients = _clients();
  final container = ProviderContainer(
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
  );
  addTearDown(container.dispose);
  return container;
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
  Future<ClientModel> updateClient(ClientModel client) async {
    updates.add(client);
    return client;
  }
}

class _RefreshClientNotifier extends _ClientNotifier {
  _RefreshClientNotifier(super.items, this.refreshedItems);

  final List<ClientModel> refreshedItems;
  int refreshCount = 0;

  @override
  Future<void> refresh() async {
    refreshCount++;
    state = AsyncValue.data(refreshedItems);
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
