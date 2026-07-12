import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/financials/data/models/currency_model.dart';
import 'package:gym_client/src/features/financials/data/models/exchange_rate_model.dart';
import 'package:gym_client/src/features/financials/presentation/providers/exchange_rate_notifier.dart';
import 'package:gym_client/src/features/financials/presentation/screens/exchange_rates_pulso_view.dart';
import 'package:gym_client/src/features/financials/presentation/state/currency_notifier.dart';

void main() {
  const sizes = <String, Size>{
    'compacto': Size(390, 844),
    'mediano': Size(760, 900),
    'escritorio': Size(1280, 900),
    'ventana baja': Size(1024, 650),
  };

  for (final entry in sizes.entries) {
    testWidgets('Tipos de cambio PULSO se adapta al ancho ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(
        find.text('TIPOS DE CAMBIO.', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('BOB → USD', findRichText: true), findsOneWidget);
      expect(find.text('USD → BOB', findRichText: true), findsOneWidget);
      expect(find.text('MODO LOCAL'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final pairRow = find.descendant(
        of: find.byKey(const PageStorageKey('pulso-rates-list')),
        matching: find.text('BOB → USD', findRichText: true),
      );
      if (entry.key == 'mediano') {
        await tester.tap(pairRow);
        await tester.pumpAndSettle();
        expect(find.text('DETALLE SELECCIONADO'), findsOneWidget);
      }
      if (entry.key == 'escritorio') {
        await tester.tap(pairRow);
        await tester.pump();
        expect(find.text('DETALLE SELECCIONADO'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('distingue tasas activas y vencidas con el reloj calibrado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('ACTIVO'), findsOneWidget);
    expect(find.text('VENCIDO'), findsOneWidget);
    expect(find.text('Tasas activas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite editar una tasa y guarda los cambios', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final rateNotifier = _RateNotifier([
      ExchangeRateModel(
        id: 'rate-activa',
        monedaIdBase: 'cur-bob',
        monedaIdTarget: 'cur-usd',
        exchangeRate: 6.96,
        fechaInicio: DateTime.utc(2026, 1, 1),
      ),
    ]);
    await tester.pumpWidget(_harness(rateNotifier: rateNotifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar BOB → USD'));
    await tester.pumpAndSettle();
    expect(find.text('EDITAR TIPO DE CAMBIO'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('pulso-rate-value')),
      '7.05',
    );
    await tester.tap(find.text('GUARDAR CAMBIOS'));
    await tester.pumpAndSettle();

    expect(rateNotifier.updates, hasLength(1));
    final (id, data) = rateNotifier.updates.single;
    expect(id, 'rate-activa');
    expect(data['exchange_rate'], 7.05);
    expect(data['moneda_id_base'], 'cur-bob');
    expect(data['moneda_id_target'], 'cur-usd');
    expect(find.text('EDITAR TIPO DE CAMBIO'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renueva una tasa vencida con alta precargada', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final rateNotifier = _RateNotifier([
      ExchangeRateModel(
        id: 'rate-vencida',
        monedaIdBase: 'cur-usd',
        monedaIdTarget: 'cur-bob',
        exchangeRate: 0.14,
        fechaInicio: DateTime.utc(2025, 1, 1),
        fechaExpiracion: DateTime.utc(2025, 12, 31),
      ),
    ]);
    await tester.pumpWidget(_harness(rateNotifier: rateNotifier));
    await tester.pumpAndSettle();

    // Seleccionar la tasa vencida muestra la acción de renovar en el detalle.
    await tester.tap(
      find.descendant(
        of: find.byKey(const PageStorageKey('pulso-rates-list')),
        matching: find.text('USD → BOB', findRichText: true),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('RENOVAR TASA'));
    await tester.pumpAndSettle();

    // Alta precargada con el par y la última tasa conocida.
    expect(find.text('NUEVO TIPO DE CAMBIO'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pulso-rate-value')),
        matching: find.text('0.14'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('CREAR'));
    await tester.pumpAndSettle();

    expect(rateNotifier.creates, hasLength(1));
    final data = rateNotifier.creates.single;
    expect(data['moneda_id_base'], 'cur-usd');
    expect(data['moneda_id_target'], 'cur-bob');
    expect(data['exchange_rate'], 0.14);
    expect(data['fecha_expiracion'], isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtra tasas vencidas', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vencidas').last);
    await tester.pump();
    final list = find.byKey(const PageStorageKey('pulso-rates-list'));
    expect(
      find.descendant(
        of: list,
        matching: find.text('USD → BOB', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: list,
        matching: find.text('BOB → USD', findRichText: true),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

const _bob = CurrencyModel(
  id: 'cur-bob',
  name: 'Boliviano',
  code: 'BOB',
  symbol: 'Bs',
);
const _usd = CurrencyModel(
  id: 'cur-usd',
  name: 'Dólar',
  code: 'USD',
  symbol: r'$',
);

Widget _harness({_RateNotifier? rateNotifier}) {
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
      currencyProvider.overrideWith(() => _CurrencyNotifier([_bob, _usd])),
      exchangeRateProvider.overrideWith(
        () =>
            rateNotifier ??
            _RateNotifier([
          ExchangeRateModel(
            id: 'rate-activa',
            monedaIdBase: 'cur-bob',
            monedaIdTarget: 'cur-usd',
            exchangeRate: 6.96,
            fechaInicio: DateTime.utc(2026, 1, 1),
          ),
          ExchangeRateModel(
            id: 'rate-vencida',
            monedaIdBase: 'cur-usd',
            monedaIdTarget: 'cur-bob',
            exchangeRate: 0.14,
            fechaInicio: DateTime.utc(2025, 1, 1),
            fechaExpiracion: DateTime.utc(2025, 12, 31),
          ),
        ]),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: ExchangeRatesPulsoView())),
  );
}

class _RateNotifier extends ExchangeRateNotifier {
  _RateNotifier(this.items);
  final List<ExchangeRateModel> items;
  final updates = <(String, Map<String, dynamic>)>[];
  final creates = <Map<String, dynamic>>[];

  @override
  Future<List<ExchangeRateModel>> build() async => items;

  @override
  Future<void> updateExchangeRate(String id, Map<String, dynamic> data) async {
    updates.add((id, data));
  }

  @override
  Future<void> create(Map<String, dynamic> data) async {
    creates.add(data);
  }
}

class _CurrencyNotifier extends CurrencyNotifier {
  _CurrencyNotifier(this.items);
  final List<CurrencyModel> items;

  @override
  Future<List<CurrencyModel>> build() async => items;
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
