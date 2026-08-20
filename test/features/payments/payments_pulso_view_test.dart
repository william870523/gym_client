import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/core/widgets/pulso_widgets.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';
import 'package:gym_client/src/features/clients/presentation/state/client_notifier.dart';
import 'package:gym_client/src/features/configuration/data/models/payment_type_model.dart';
import 'package:gym_client/src/features/financials/data/models/account_model.dart';
import 'package:gym_client/src/features/financials/data/models/currency_model.dart';
import 'package:gym_client/src/features/financials/presentation/state/currency_notifier.dart';
import 'package:gym_client/src/features/payments/data/models/payment_model.dart';
import 'package:gym_client/src/features/payments/data/models/payment_reversal_model.dart';
import 'package:gym_client/src/features/payments/presentation/screens/payments_pulso_view.dart';
import 'package:gym_client/src/features/payments/presentation/state/payment_notifier.dart';
import 'package:gym_client/src/features/products/data/models/payment_plan_model.dart';
import 'package:gym_client/src/features/products/presentation/state/payment_plan_notifier.dart';
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
    testWidgets('Libro de pagos PULSO se adapta al ancho ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('LIBRO DE PAGOS.', findRichText: true), findsOneWidget);
      // El socio aparece en la fila y, en escritorio, también en el recibo.
      expect(find.text('Carlos Antonio Millán'), findsWidgets);
      // La banda de métricas compacta es perezosa: la cuarta métrica solo se
      // construye con ancho suficiente.
      if (entry.value.width >= 600) {
        expect(find.text('Con conversión'), findsOneWidget);
      }
      expect(find.text('MODO LOCAL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('la búsqueda vacía muestra el estado sin coincidencias', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('pulso-payments-search')),
      'persona inexistente',
    );
    await tester.pump();
    expect(
      find.text('No hay asientos que coincidan con la consulta.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('el recibo lateral permite anular con confirmación', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final paymentNotifier = _PaymentNotifier(_payments());
    await tester.pumpWidget(_harness(paymentNotifier: paymentNotifier));
    await tester.pumpAndSettle();

    // El primer asiento visible se selecciona solo y muestra su recibo.
    expect(find.text('RECIBO Nº 01'), findsOneWidget);
    expect(find.text('Transferencia'), findsOneWidget);

    await tester.tap(find.text('ANULAR PAGO'));
    await tester.pumpAndSettle();
    expect(find.text('Anular pago'), findsOneWidget); // título del diálogo
    await tester.enterText(
      find.byKey(const ValueKey('payment-reversal-reason')),
      'Cobro duplicado confirmado',
    );
    await tester.pump();
    await tester.tap(find.text('ANULAR PAGO').last);
    await tester.pumpAndSettle();

    expect(paymentNotifier.voided, ['payment-carlos']);
    expect(paymentNotifier.reasons, ['Cobro duplicado confirmado']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el recibo muestra el snapshot R5.3 sin recalcularlo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('payment-discount-snapshot')),
      findsOneWidget,
    );
    expect(find.text('PMV'), findsOneWidget);
    expect(find.text('VIEJO'), findsOneWidget);
    final snapshot = find.byKey(const ValueKey('payment-discount-snapshot'));
    expect(
      find.descendant(of: snapshot, matching: find.textContaining('12')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: snapshot, matching: find.textContaining('-€')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: snapshot, matching: find.textContaining('10')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtra pagos anulados', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Anulados').last);
    await tester.pump();
    final list = find.byKey(const PageStorageKey('pulso-payments-list'));
    expect(
      find.descendant(of: list, matching: find.text('Lucía Roque')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: list, matching: find.text('Carlos Antonio Millán')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('recibo anulado separa cobrador y anulador', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lucía Roque'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Recepción · reception'), findsOneWidget);
    expect(find.text('Carla Supervisión'), findsOneWidget);
    expect(find.text('Pago duplicado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  _pruebasDelCobroCruzado();
}

List<PaymentModel> _payments({bool cruzado = false, bool puedeAnular = true}) => [
  PaymentModel(
    id: 'payment-carlos',
    esCruzado: cruzado,
    sedeDelIngresoNombre: cruzado ? 'Sede Norte' : null,
    sedeDelEfectivoNombre: cruzado ? 'Gym Test' : null,
    sedeQueAnulaNombre: cruzado ? 'Gym Test' : null,
    puedeAnularAqui: puedeAnular,
    ci: '91021547301',
    fecha: DateTime.utc(2026, 7, 10, 15, 30),
    amount: 1,
    planId: 'plan-daily',
    currencyId: 'eur',
    listPriceSnapshot: 12,
    discountAmountSnapshot: 2,
    clientCategorySnapshot: 'VIEJO',
    planCodeSnapshot: 'PMV',
    details: [
      PaymentDetailModel(
        id: 'detail-1',
        paymentId: 'payment-carlos',
        paymentTypeId: 'transfer',
        currencyId: 'mlc',
        accountId: 'account-mlc',
        amount: 1,
        exchangeRateId: 'rate-1',
      ),
    ],
  ),
  PaymentModel(
    id: 'payment-lucia',
    ci: '88021547302',
    fecha: DateTime.utc(2026, 7, 9, 10, 0),
    amount: 1,
    planId: 'plan-daily',
    currencyId: 'eur',
    clientName: 'Lucía Roque',
    isDeleted: true,
    collectorName: 'Ana Recepción',
    collectorRole: 'reception',
    voidedByUserId: 'carla',
    voidedByName: 'Carla Supervisión',
    voidReason: 'Pago duplicado',
  ),
];

Widget _harness({_PaymentNotifier? paymentNotifier}) {
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
      paymentNotifierProvider.overrideWith(
        () => paymentNotifier ?? _PaymentNotifier(_payments()),
      ),
      clientNotifierProvider.overrideWith(
        () => _ClientNotifier([
          ClientModel(
            id: '91021547301',
            nombres: 'Carlos Antonio',
            apellidos: 'Millán',
            planId: 'plan-daily',
          ),
        ]),
      ),
      paymentPlanProvider.overrideWith(
        () => _PaymentPlanNotifier([
          PaymentPlanModel(
            id: 'plan-daily',
            nombre: 'Diario',
            importe: 1,
            duracion: 1,
            monedaId: 'eur',
          ),
        ]),
      ),
      currencyProvider.overrideWith(
        () => _CurrencyNotifier(const [
          CurrencyModel(id: 'eur', name: 'Euro', code: 'EUR', symbol: '€'),
          CurrencyModel(
            id: 'mlc',
            name: 'Moneda libremente convertible',
            code: 'MLC',
            symbol: r'$',
          ),
        ]),
      ),
      trainerProvider.overrideWith(_TrainerNotifier.new),
      paymentTypesProvider.overrideWith(
        (ref) async => [
          PaymentTypeModel(id: 'transfer', name: 'Transferencia'),
        ],
      ),
      accountsProvider.overrideWith(
        (ref) async => [
          AccountModel(
            id: 'account-mlc',
            name: 'Cuenta MLC',
            currencyId: 'mlc',
          ),
        ],
      ),
      exchangeRatesProvider.overrideWith((ref) async => const []),
    ],
    child: const MaterialApp(home: Scaffold(body: PaymentsPulsoView())),
  );
}

class _PaymentNotifier extends PaymentNotifier {
  _PaymentNotifier(this.items);
  final List<PaymentModel> items;
  final voided = <String>[];
  final reasons = <String>[];

  @override
  Future<List<PaymentModel>> build() async => items;

  @override
  Future<void> refresh() async {
    state = AsyncValue.data(items);
  }

  @override
  Future<PaymentReversalResult> voidPayment(
    String id, {
    required String reason,
  }) async {
    voided.add(id);
    reasons.add(reason);
    return PaymentReversalResult(
      reversalId: id,
      paymentId: id,
      reason: reason,
      idempotent: false,
      summary: const {
        'membresias_pendientes': ['membership-1'],
        'devengos_anulados': 1,
      },
    );
  }
}

class _ClientNotifier extends ClientNotifier {
  _ClientNotifier(this.items);
  final List<ClientModel> items;

  @override
  Future<List<ClientModel>> build() async => items;

  @override
  Future<void> refresh() async {
    state = AsyncValue.data(items);
  }
}

class _PaymentPlanNotifier extends PaymentPlanNotifier {
  _PaymentPlanNotifier(this.items);
  final List<PaymentPlanModel> items;

  @override
  Future<List<PaymentPlanModel>> build() async => items;

  @override
  Future<void> refresh() async {
    state = AsyncValue.data(items);
  }
}

class _CurrencyNotifier extends CurrencyNotifier {
  _CurrencyNotifier(this.items);
  final List<CurrencyModel> items;

  @override
  Future<List<CurrencyModel>> build() async => items;

  @override
  Future<void> refresh() async {
    state = AsyncValue.data(items);
  }
}

class _TrainerNotifier extends TrainerNotifier {
  @override
  Future<List<TrainerModel>> build() async => const [];

  @override
  Future<void> refresh() async {
    state = const AsyncValue.data([]);
  }
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}

/// §7.8 — anular un cobro cruzado toca dos cajas y dos contabilidades.
///
/// El diálogo decía exactamente lo mismo para un cobro corriente y para uno
/// cruzado, así que quien anulaba desde aquí movía el saldo entre sedes sin
/// enterarse.
void _pruebasDelCobroCruzado() {
  Future<void> abrirAnulacion(WidgetTester tester, List<PaymentModel> pagos) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_harness(paymentNotifier: _PaymentNotifier(pagos)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ANULAR PAGO'));
    await tester.pumpAndSettle();
  }

  testWidgets('un cobro corriente no habla de sedes', (tester) async {
    // Llenar el diálogo de avisos que no aplican enseña a ignorarlos.
    await abrirAnulacion(tester, _payments());
    expect(find.textContaining('dos cajas'), findsNothing);
    expect(find.text('COBRO ENTRE SEDES'), findsNothing);
  });

  testWidgets('un cobro cruzado avisa de las dos contabilidades', (tester) async {
    await abrirAnulacion(tester, _payments(cruzado: true));
    expect(find.text('COBRO ENTRE SEDES'), findsOneWidget);
    expect(find.textContaining('dos cajas y dos contabilidades'), findsOneWidget);
    // Y nombra el efecto que nadie veía: el saldo entre las dos se deshace.
    expect(find.textContaining('deshace el saldo'), findsOneWidget);
    // Las dos sedes con nombre, no con identificador.
    expect(find.textContaining('Gym Test'), findsOneWidget);
    expect(find.textContaining('Sede Norte'), findsOneWidget);
  });

  testWidgets('sin autoridad no se ofrece anular, y se dice quién puede', (
    tester,
  ) async {
    // El servidor contestaría 403 y el recepcionista se quedaría con un error
    // sin saber a quién llamar.
    await abrirAnulacion(
      tester,
      _payments(cruzado: true, puedeAnular: false),
    );
    expect(find.textContaining('Desde aquí no se puede'), findsOneWidget);
    expect(find.textContaining('en cuya caja entró el efectivo'), findsOneWidget);

    final boton = tester.widget<PulsoSecondaryButton>(
      find.widgetWithText(PulsoSecondaryButton, 'ANULAR PAGO').last,
    );
    expect(boton.onPressed, isNull);
  });
}
