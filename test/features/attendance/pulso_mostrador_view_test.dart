import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/core/time/app_clock.dart';
import 'package:gym_client/src/core/utils/datetime_zone.dart';
import 'package:gym_client/src/features/attendance/data/models/attendance_model.dart';
import 'package:gym_client/src/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:gym_client/src/features/attendance/presentation/state/attendance_notifier.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';
import 'package:gym_client/src/features/clients/presentation/state/client_notifier.dart';
import 'package:gym_client/src/features/payments/data/models/payment_model.dart';
import 'package:gym_client/src/features/payments/presentation/state/payment_notifier.dart';
import 'package:gym_client/src/features/schedules/data/models/horario_model.dart';
import 'package:gym_client/src/features/schedules/presentation/state/horario_notifier.dart';
import 'package:gym_client/src/features/clients/data/models/multisede_access_model.dart';
import 'package:gym_client/src/features/clients/data/repositories/multisede_access_repository.dart';

void main() {
  for (final entry in const {
    'compacto': Size(390, 844),
    'mediano': Size(760, 900),
    'escritorio': Size(1280, 900),
  }.entries) {
    testWidgets('Mostrador PULSO se adapta al ancho ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pump();

      expect(find.text('CONTROL DE PISO', findRichText: true), findsOneWidget);
      expect(find.text('EN SALA'), findsOneWidget);
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('Luis Gómez'), findsOneWidget);
      expect(find.text('DENTRO AHORA'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pulso-memberships-panel')),
        findsOneWidget,
      );
      expect(find.byTooltip('Escanear código (lector físico)'), findsOneWidget);
      expect(find.textContaining('GYMOS · PULSO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('busca un socio y registra su entrada en un toque', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notifier = _AttendanceNotifier(_attendances());
    await tester.pumpWidget(_harness(notifier: notifier));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('pulso-mostrador-search')),
      'Ana',
    );
    await tester.pump();
    await tester.tap(find.text('ENTRADA').last);
    await tester.pump();

    expect(notifier.checkIns, ['100']);
    expect(find.text('Entrada · Ana Pérez'.toUpperCase()), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el aviso repite el motivo que da el servidor, no uno genérico', (
    tester,
  ) async {
    // El mostrador decía «No se pudo registrar la entrada» pasara lo que
    // pasara: pausa, cobro pendiente o cuota vencida. El servidor sí explica y
    // ese texto se perdía en el `catch`, así que el recepcionista veía un fallo
    // sin saber qué hacer. Un rechazo que no se explica obliga a llamar a
    // administración por algo que la pantalla ya sabe.
    //
    // No es alcanzable desde el recorrido en pantalla —la vista ofrece COBRAR
    // en vez de ENTRADA a quien no puede entrar—, y por eso lo fija esta
    // prueba: el 409 llega cuando la vista tiene el estado viejo, cuando entra
    // otra terminal o cuando alguien llama a la API por su cuenta.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const motivo =
        'La membresía está pausada. Reanúdela antes de registrar la entrada.';
    final notifier = _AttendanceNotifier(_attendances())
      ..fallaConMotivo = motivo;
    await tester.pumpWidget(_harness(notifier: notifier));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('pulso-mostrador-search')),
      'Ana',
    );
    await tester.pump();
    await tester.tap(find.text('ENTRADA').last);
    await tester.pump();

    expect(find.text(motivo.toUpperCase()), findsOneWidget);
    expect(
      find.text('No se pudo registrar la entrada'.toUpperCase()),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('si el servidor no explica nada, queda el aviso de siempre', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notifier = _AttendanceNotifier(_attendances())..fallaSinMotivo = true;
    await tester.pumpWidget(_harness(notifier: notifier));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('pulso-mostrador-search')),
      'Ana',
    );
    await tester.pump();
    await tester.tap(find.text('ENTRADA').last);
    await tester.pump();

    expect(
      find.text('No se pudo registrar la entrada'.toUpperCase()),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pausa, reanuda y finaliza una permanencia', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notifier = _AttendanceNotifier(_attendances());
    await tester.pumpWidget(_harness(notifier: notifier));
    await tester.pump();

    await tester.tap(find.text('PAUSAR'));
    await tester.pump();
    expect(notifier.pauses, ['a1']);
    expect(find.text('REANUDAR'), findsOneWidget);

    await tester.tap(find.text('REANUDAR'));
    await tester.pump();
    expect(notifier.resumes, ['a1']);

    await tester.tap(find.text('SALIDA'));
    await tester.pump();
    expect(notifier.checkOuts, ['a1']);
    expect(find.text('HISTORIAL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('encuadra los paneles y no oculta socios sin horario', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = todayInZone(appClock.gymTimezone);
    final libre = ClientModel(
      id: '300',
      nombres: 'Carla',
      apellidos: 'Libre',
      planId: 'mensual',
      endDate: calendarDateToUtc(today.add(const Duration(days: 30))),
    );
    await tester.pumpWidget(
      _harness(clientItems: [libre], attendanceItems: const []),
    );
    await tester.pump();

    final arrivals = find.byKey(const ValueKey('pulso-arrivals-panel'));
    final inside = find.byKey(const ValueKey('pulso-inside-panel'));
    final memberships = find.byKey(const ValueKey('pulso-memberships-panel'));
    expect(arrivals, findsOneWidget);
    expect(inside, findsOneWidget);
    expect(memberships, findsOneWidget);
    expect(find.text('Carla Libre'), findsOneWidget);
    expect(
      find.textContaining('acceso libre · Plan', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('1 de acceso libre'), findsOneWidget);
    expect(
      tester.getTopLeft(arrivals).dx,
      lessThan(tester.getTopLeft(inside).dx),
    );
    expect(
      tester.getTopLeft(memberships).dy,
      greaterThan(tester.getTopLeft(inside).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('una membresía por vencer no registra otra entrada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = todayInZone(appClock.gymTimezone);
    final client = ClientModel(
      id: '400',
      nombres: 'Alfredo',
      apellidos: 'Virgili Perez',
      planId: 'mensual',
      membershipStatus: 'ACTIVA',
      membershipVigencia: 'VIGENTE',
      endDate: calendarDateToUtc(today.add(const Duration(days: 2))),
    );
    final notifier = _AttendanceNotifier([
      AttendanceModel(
        id: 'active-400',
        clientId: client.id,
        checkIn: appClock.nowUtc().subtract(const Duration(minutes: 5)),
      ),
    ]);
    await tester.pumpWidget(
      _harness(clientItems: [client], notifier: notifier),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('membership-due-400')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(notifier.checkIns, isEmpty);
    expect(find.text('Alfredo Virgili Perez'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('una membresía pausada no aparece como vencida en el panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = todayInZone(appClock.gymTimezone);
    final paused = ClientModel(
      id: 'paused',
      nombres: 'Pausa',
      apellidos: 'Vigencia (demo)',
      activo: true,
      planId: 'mensual',
      membershipStatus: 'PAUSADA',
      membershipVigencia: 'PAUSADA',
      endDate: calendarDateToUtc(today.subtract(const Duration(days: 20))),
    );
    await tester.pumpWidget(
      _harness(clientItems: [paused], attendanceItems: const []),
    );
    await tester.pump();

    final memberships = find.byKey(const ValueKey('pulso-memberships-panel'));
    expect(
      find.descendant(
        of: memberships,
        matching: find.text('Pausa Vigencia (demo)'),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('un doble toque rápido solo registra una entrada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notifier = _AttendanceNotifier(const []);
    await tester.pumpWidget(
      _harness(notifier: notifier, attendanceItems: const []),
    );
    await tester.pump();

    final entry = find.text('ENTRADA').first;
    await tester.tap(entry);
    await tester.tap(entry, warnIfMissed: false);
    await tester.pump();

    expect(notifier.checkIns, ['100']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('colapsa duplicados activos del mismo socio', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = appClock.nowUtc();
    await tester.pumpWidget(
      _harness(
        attendanceItems: [
          AttendanceModel(id: 'dup-1', clientId: '200', checkIn: now),
          AttendanceModel(
            id: 'dup-2',
            clientId: '200',
            checkIn: now.subtract(const Duration(minutes: 1)),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Luis Gómez'), findsOneWidget);
    expect(find.text('PAUSAR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  _pruebasDeVisitantes();
  _pruebasDeLaDeclaracion();
}

Widget _harness({
  _AttendanceNotifier? notifier,
  List<ClientModel>? clientItems,
  List<AttendanceModel>? attendanceItems,
  VisitantesDeLaSede? visitantes,
}) {
  final now = toGymWallClock(appClock.nowUtc(), appClock.gymTimezone);
  final nowMinutes = now.hour * 60 + now.minute;
  final clients = clientItems ?? _clients();
  final attendances = attendanceItems ?? _attendances();
  return ProviderScope(
    overrides: [
      appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
      // M4a: el mostrador consulta a los socios de otras sedes al identificar.
      // Sin simularlo, la vista sale a la red y deja un temporizador vivo.
      visitantesProvider.overrideWith(
        (_) async =>
            visitantes ??
            const VisitantesDeLaSede(
              visitantes: <VisitanteModel>[],
              conocimiento: ConocimientoDeLaSede.desconocido,
            ),
      ),
      syncStatusProvider.overrideWith(
        (ref) => Stream.value(
          SyncStatusSnapshot.offline(
            detail: 'Operación local disponible',
            source: 'test',
          ),
        ),
      ),
      clientNotifierProvider.overrideWith(() => _ClientNotifier(clients)),
      paymentNotifierProvider.overrideWith(_PaymentNotifier.new),
      attendanceNotifierProvider.overrideWith(
        () => notifier ?? _AttendanceNotifier(attendances),
      ),
      horarioNotifierProvider.overrideWith(
        () => _ScheduleNotifier([
          HorarioModel(
            id: 'turno',
            nombre: 'Turno actual',
            horaInicio: nowMinutes,
            horaFin: (nowMinutes + 60).clamp(1, 1439),
          ),
        ]),
      ),
    ],
    child: const MaterialApp(home: AttendanceScreen()),
  );
}

List<ClientModel> _clients() {
  final today = todayInZone(appClock.gymTimezone);
  return [
    ClientModel(
      id: '100',
      nombres: 'Ana',
      apellidos: 'Pérez',
      planId: 'mensual',
      scheduleId: 'turno',
      endDate: calendarDateToUtc(today.add(const Duration(days: 30))),
    ),
    ClientModel(
      id: '200',
      nombres: 'Luis',
      apellidos: 'Gómez',
      planId: 'mensual',
      endDate: calendarDateToUtc(today.add(const Duration(days: 30))),
    ),
  ];
}

List<AttendanceModel> _attendances() => [
  AttendanceModel(
    id: 'a1',
    clientId: '200',
    checkIn: appClock.nowUtc().subtract(const Duration(minutes: 10)),
  ),
];

class _AttendanceNotifier extends AttendanceNotifier {
  _AttendanceNotifier(this.items);
  List<AttendanceModel> items;
  final checkIns = <String>[];
  final checkOuts = <String>[];
  final pauses = <String>[];
  final resumes = <String>[];

  @override
  Future<List<AttendanceModel>> build() async => items;

  @override
  Future<void> refresh() async => state = AsyncValue.data(items);

  /// Motivo que devuelve el servidor en un 409, si esta prueba lo simula.
  String? fallaConMotivo;

  /// Fallo sin cuerpo legible: la red se cayó, no hubo rechazo de negocio.
  bool fallaSinMotivo = false;

  /// §5.2 — con qué dato dice el servidor que autorizó la entrada.
  String? decididoCon;
  String? advertencia;

  @override
  Future<EntradaRegistrada?> checkInPorCi(String ci) async {
    checkIns.add(ci);
    return EntradaRegistrada(
      asistencia: items.first,
      decididoCon: decididoCon,
      advertencia: advertencia,
    );
  }

  @override
  Future<void> checkIn(ClientModel client) async {
    if (fallaConMotivo != null) {
      throw DioException(
        requestOptions: RequestOptions(path: '/asistencias'),
        response: Response(
          requestOptions: RequestOptions(path: '/asistencias'),
          statusCode: 409,
          data: {'error': fallaConMotivo},
        ),
      );
    }
    if (fallaSinMotivo) {
      throw DioException(
        requestOptions: RequestOptions(path: '/asistencias'),
        type: DioExceptionType.connectionError,
      );
    }
    checkIns.add(client.id);
    items = [
      ...items,
      AttendanceModel(
        id: 'new-${client.id}',
        clientId: client.id,
        checkIn: appClock.nowUtc(),
      ),
    ];
    state = AsyncValue.data(items);
  }

  @override
  Future<void> checkOut(String attendanceId) async {
    checkOuts.add(attendanceId);
    items = [
      for (final item in items)
        if (item.id == attendanceId)
          _copy(item, checkOut: appClock.nowUtc(), clearPause: true)
        else
          item,
    ];
    state = AsyncValue.data(items);
  }

  @override
  Future<void> checkOutClient(
    String clientId, {
    required String fallbackAttendanceId,
  }) async {
    final ids = items
        .where((item) => item.clientId == clientId && item.checkOut == null)
        .map((item) => item.id)
        .toList();
    for (final id in ids.isEmpty ? [fallbackAttendanceId] : ids) {
      await checkOut(id);
    }
  }

  @override
  Future<void> pause(String attendanceId) async {
    pauses.add(attendanceId);
    items = [
      for (final item in items)
        if (item.id == attendanceId)
          _copy(item, pauseStart: appClock.nowUtc())
        else
          item,
    ];
    state = AsyncValue.data(items);
  }

  @override
  Future<void> resume(String attendanceId) async {
    resumes.add(attendanceId);
    items = [
      for (final item in items)
        if (item.id == attendanceId) _copy(item, clearPause: true) else item,
    ];
    state = AsyncValue.data(items);
  }

  AttendanceModel _copy(
    AttendanceModel item, {
    DateTime? checkOut,
    DateTime? pauseStart,
    bool clearPause = false,
  }) {
    return AttendanceModel(
      id: item.id,
      clientId: item.clientId,
      checkIn: item.checkIn,
      checkOut: checkOut ?? item.checkOut,
      pauseStart: clearPause ? null : pauseStart ?? item.pauseStart,
      pausedMs: item.pausedMs,
      clientName: item.clientName,
      photoUrl: item.photoUrl,
    );
  }
}

class _PaymentNotifier extends PaymentNotifier {
  @override
  Future<List<PaymentModel>> build() async => const [];
}

class _ClientNotifier extends ClientNotifier {
  _ClientNotifier(this.items);
  final List<ClientModel> items;

  @override
  Future<List<ClientModel>> build() async => items;
}

class _ScheduleNotifier extends HorarioNotifier {
  _ScheduleNotifier(this.items);
  final List<HorarioModel> items;

  @override
  Future<List<HorarioModel>> build() async => items;
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}

/// §5.2 — la vigencia del visitante y cuánto vale lo que la sede sabe.
///
/// La copia lleva la fecha desde M4a y **no la enseñaba nadie**: recepción solo
/// se enteraba de que el plan había vencido cuando la puerta rechazaba al socio,
/// con él delante del mostrador.
void _pruebasDeVisitantes() {
  VisitanteModel visitante({
    required String ci,
    required String nombre,
    bool vigente = true,
    DateTime? hasta,
  }) => VisitanteModel(
    ci: ci,
    nombres: nombre,
    apellidos: 'Del Norte',
    gymIdOrigen: 'gym-norte',
    accesoVigente: vigente,
    membresiaEstado: 'ACTIVA',
    membresiaFechaFin: hasta,
  );

  testWidgets('el visitante enseña hasta cuándo le cubre', (tester) async {
    tester.view.physicalSize = const Size(1500, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _harness(
        visitantes: VisitantesDeLaSede(
          visitantes: [
            visitante(
              ci: '99090100009',
              nombre: 'Nadia',
              hasta: DateTime.utc(2026, 9, 15),
            ),
          ],
          conocimiento: ConocimientoDeLaSede.desconocido,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Nadia');
    await tester.pumpAndSettle();

    expect(find.textContaining('hasta 15/09/2026'), findsOneWidget);
  });

  testWidgets('sin noticias, la sede lo dice en vez de afirmar', (tester) async {
    // Es el caso que motiva todo esto: la pantalla afirmaba con la misma
    // seguridad un dato de hace un minuto y uno de hace dos días.
    tester.view.physicalSize = const Size(1500, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _harness(
        visitantes: VisitantesDeLaSede(
          visitantes: [visitante(ci: '99090100009', nombre: 'Nadia')],
          conocimiento: const ConocimientoDeLaSede(
            frescura: 'A_CIEGAS',
            diasSinNoticias: 2,
            advertencia:
                'Esta sede lleva 2 días sin sincronizar: una membresía '
                'cancelada desde entonces seguiría apareciendo vigente.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Nadia');
    await tester.pumpAndSettle();

    expect(find.textContaining('2 días sin sincronizar'), findsOneWidget);
    // Y el visitante sigue en la lista, ofrecido: negar por llevar días sin
    // noticias dejaría a la sede sin atender a nadie el día que se cae la
    // conexión, que es lo contrario de para lo que existe la lectura local.
    expect(find.text('Nadia Del Norte'), findsOneWidget);
  });

  testWidgets('al día no se advierte nada', (tester) async {
    // Llenar la vista de avisos inofensivos enseña a ignorarlos.
    tester.view.physicalSize = const Size(1500, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _harness(
        visitantes: VisitantesDeLaSede(
          visitantes: [visitante(ci: '99090100009', nombre: 'Nadia')],
          conocimiento: const ConocimientoDeLaSede(frescura: 'AL_DIA'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Nadia');
    await tester.pumpAndSettle();

    expect(find.textContaining('sin sincronizar'), findsNothing);
    expect(find.textContaining('desde ayer'), findsNothing);
  });
}

/// §5.2 — el mostrador dice **con qué dato** autorizó la entrada de un visitante.
///
/// El servidor lo devuelve desde que se cerró la ventana de la cancelación
/// anticipada, y el aviso importa justo cuando **deja entrar**: si el
/// concentrador no contestó, esa entrada se autorizó con lo que la sede tenía
/// guardado y puede haber una baja de la que no se ha enterado.
void _pruebasDeLaDeclaracion() {
  VisitantesDeLaSede unVisitante() => VisitantesDeLaSede(
    visitantes: [
      const VisitanteModel(
        ci: '99090100009',
        nombres: 'Nadia',
        apellidos: 'Del Norte',
        gymIdOrigen: 'gym-norte',
        accesoVigente: true,
        membresiaEstado: 'ACTIVA',
      ),
    ],
    conocimiento: ConocimientoDeLaSede.desconocido,
  );

  Future<void> entrar(WidgetTester tester, _AttendanceNotifier notifier) async {
    tester.view.physicalSize = const Size(1500, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _harness(notifier: notifier, visitantes: unVisitante()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pulso-mostrador-search')),
      'Nadia',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nadia Del Norte'));
    await tester.pumpAndSettle();
  }

  testWidgets('decidida por el concentrador: entra y no se advierte nada', (
    tester,
  ) async {
    // El dato era el de origen en ese instante: no hay nada que matizar, y
    // matizarlo enseñaría a ignorar el aviso cuando sí importe.
    final notifier = _AttendanceNotifier(_attendances())
      ..decididoCon = 'CONCENTRADOR';
    await entrar(tester, notifier);

    expect(notifier.checkIns, ['99090100009']);
    expect(find.text('Entrada · Nadia Del Norte'.toUpperCase()), findsOneWidget);
    expect(find.textContaining('no contestó'), findsNothing);
  });

  testWidgets('decidida con la copia: entra, y lo dice', (tester) async {
    // Es el caso peligroso: la entrada se autorizó con datos que pueden haber
    // envejecido. Se registra igual —cerrar el gimnasio porque el concentrador
    // no responde sería peor— pero no en silencio.
    final notifier = _AttendanceNotifier(_attendances())
      ..decididoCon = 'COPIA_LOCAL'
      ..advertencia =
          'El concentrador no contestó: se decidió con lo que esta sede tenía guardado.';
    await entrar(tester, notifier);

    expect(notifier.checkIns, ['99090100009']);
    expect(find.text('Entrada · Nadia Del Norte'.toUpperCase()), findsOneWidget);
    expect(find.textContaining('no contestó'), findsOneWidget);
  });

  testWidgets('sin declaración —socio de la casa— no se inventa un aviso', (
    tester,
  ) async {
    // Para un socio propio la pregunta no existe: su membresía está en esta
    // misma base. Un aviso ahí haría creer que también hay duda.
    final notifier = _AttendanceNotifier(_attendances());
    await entrar(tester, notifier);

    expect(find.textContaining('no contestó'), findsNothing);
    expect(find.textContaining('guardado'), findsNothing);
  });
}
