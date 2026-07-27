import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_theme.dart';
import 'package:gym_client/src/features/configuration/data/models/payment_type_model.dart';
import 'package:gym_client/src/features/configuration/presentation/state/payment_type_notifier.dart';
import 'package:gym_client/src/features/financials/data/models/account_model.dart';
import 'package:gym_client/src/features/financials/data/models/currency_model.dart';
import 'package:gym_client/src/features/financials/data/models/exchange_rate_model.dart';
import 'package:gym_client/src/features/financials/presentation/providers/exchange_rate_notifier.dart';
import 'package:gym_client/src/features/financials/presentation/state/account_notifier.dart';
import 'package:gym_client/src/features/financials/presentation/state/currency_notifier.dart';
import 'package:gym_client/src/features/payments/presentation/widgets/payment_row_item.dart';

/// La tasa se enuncia como en la calle: «1 EUR = 450 CUP», con la moneda
/// fuerte de base. Estas pruebas fijan que el cobro convierta en el sentido
/// correcto en ambas direcciones y que elija la tasa vigente por fecha.
void main() {
  const cup = 'cur-cup';
  const eur = 'cur-eur';

  const currencies = [
    CurrencyModel(id: cup, code: 'CUP', name: 'Peso cubano'),
    CurrencyModel(id: eur, code: 'EUR', name: 'Euro'),
  ];

  final cashType = PaymentTypeModel(id: 'tp-cash', name: 'Efectivo');
  final eurAccount = AccountModel(
    id: 'acc-eur',
    name: 'Caja euros',
    currencyId: eur,
    currencyCode: 'EUR',
    paymentTypeId: 'tp-cash',
  );
  final cupAccount = AccountModel(
    id: 'acc-cup',
    name: 'Caja pesos',
    currencyId: cup,
    currencyCode: 'CUP',
    paymentTypeId: 'tp-cash',
  );

  ExchangeRateModel eurToCup({
    required String id,
    required double rate,
    required DateTime since,
    DateTime? until,
  }) => ExchangeRateModel(
    id: id,
    monedaIdBase: eur,
    monedaIdTarget: cup,
    exchangeRate: rate,
    fechaInicio: since,
    fechaExpiracion: until,
  );

  Future<Map<String, dynamic>> lastEmitted(
    WidgetTester tester, {
    required String planCurrencyId,
    required AccountModel account,
    required List<ExchangeRateModel> rates,
    required String amount,
  }) async {
    Map<String, dynamic>? emitted;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
          currencyProvider.overrideWith(() => _CurrencyNotifier(currencies)),
          accountProvider.overrideWith(() => _AccountNotifier([account])),
          paymentTypeNotifierProvider.overrideWith(
            () => _PaymentTypeNotifier([cashType]),
          ),
          exchangeRateProvider.overrideWith(() => _RateNotifier(rates)),
        ],
        child: MaterialApp(
          home: PulsoThemeScope(
            child: Scaffold(
              body: PaymentRowItem(
                planCurrencyId: planCurrencyId,
                onChanged: (data) => emitted = data,
                onDelete: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownMenu<PaymentTypeModel>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Efectivo').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownMenu<AccountModel>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(account.name).last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, amount);
    await tester.pumpAndSettle();

    expect(emitted, isNotNull);
    return emitted!;
  }

  testWidgets('plan en CUP pagado en EUR: 2 EUR cubren 900 CUP', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final data = await lastEmitted(
      tester,
      planCurrencyId: cup,
      account: eurAccount,
      rates: [
        eurToCup(id: 'r-450', rate: 450, since: DateTime.utc(2026, 1, 1)),
      ],
      amount: '2',
    );

    // La cuenta es la base de la tasa: se multiplica, no se divide.
    expect(data['rateOperation'], 'multiply');
    expect(data['equivalent'], closeTo(900.0, 0.001));
    expect(data['exchangeRateId'], 'r-450');
    expect(data['isValid'], isTrue);

    // La fila enuncia la tasa entera: es lo que delata una carga invertida.
    expect(find.textContaining('1 EUR = 450 CUP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plan en EUR pagado en CUP: 900 CUP cubren 2 EUR', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final data = await lastEmitted(
      tester,
      planCurrencyId: eur,
      account: cupAccount,
      rates: [
        eurToCup(id: 'r-450', rate: 450, since: DateTime.utc(2026, 1, 1)),
      ],
      amount: '900',
    );

    // Misma fila de tasa leída al revés: aquí sí toca dividir.
    expect(data['rateOperation'], 'divide');
    expect(data['equivalent'], closeTo(2.0, 0.001));
    expect(data['exchangeRateId'], 'r-450');
  });

  testWidgets('con dos tasas activas del par gana la de vigencia más reciente', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final data = await lastEmitted(
      tester,
      planCurrencyId: cup,
      account: eurAccount,
      // La vieja va primero en la lista: antes ganaba por orden de llegada.
      rates: [
        eurToCup(id: 'r-450', rate: 450, since: DateTime.utc(2026, 5, 31)),
        eurToCup(id: 'r-500', rate: 500, since: DateTime.utc(2026, 6, 1)),
      ],
      amount: '1',
    );

    expect(data['exchangeRateId'], 'r-500');
    expect(data['equivalent'], closeTo(500.0, 0.001));
  });

  testWidgets('una tasa vencida no se usa para cobrar', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final data = await lastEmitted(
      tester,
      planCurrencyId: cup,
      account: eurAccount,
      rates: [
        eurToCup(
          id: 'r-vencida',
          rate: 450,
          since: DateTime.utc(2025, 1, 1),
          until: DateTime.utc(2025, 12, 31),
        ),
      ],
      amount: '1',
    );

    expect(data['isValid'], isFalse);
    expect(data['equivalent'], 0.0);
    expect(find.textContaining('Falta tasa'), findsOneWidget);
  });

  testWidgets('el aviso propone el par con la moneda fuerte de base', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Plan en EUR y cobro en CUP, sin tasa del par: la orientación se deduce
    // de que CUP ya es el destino en otra tasa, no de quién paga.
    await lastEmitted(
      tester,
      planCurrencyId: eur,
      account: cupAccount,
      rates: [
        ExchangeRateModel(
          id: 'r-usd-cup',
          monedaIdBase: 'cur-usd',
          monedaIdTarget: cup,
          exchangeRate: 450,
          fechaInicio: DateTime.utc(2026, 1, 1),
        ),
      ],
      amount: '900',
    );

    expect(find.text('Falta tasa EUR → CUP'), findsOneWidget);
  });
}

class _RateNotifier extends ExchangeRateNotifier {
  _RateNotifier(this.items);
  final List<ExchangeRateModel> items;

  @override
  Future<List<ExchangeRateModel>> build() async => items;
}

class _CurrencyNotifier extends CurrencyNotifier {
  _CurrencyNotifier(this.items);
  final List<CurrencyModel> items;

  @override
  Future<List<CurrencyModel>> build() async => items;
}

class _AccountNotifier extends AccountNotifier {
  _AccountNotifier(this.items);
  final List<AccountModel> items;

  @override
  Future<List<AccountModel>> build() async => items;
}

class _PaymentTypeNotifier extends PaymentTypeNotifier {
  _PaymentTypeNotifier(this.items);
  final List<PaymentTypeModel> items;

  @override
  Future<List<PaymentTypeModel>> build() async => items;
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
