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
import 'package:gym_client/src/features/financials/presentation/screens/currencies_pulso_view.dart';
import 'package:gym_client/src/features/financials/presentation/state/currency_notifier.dart';

void main() {
  const sizes = <String, Size>{
    'estrecho': Size(320, 700),
    'compacto': Size(390, 844),
    'mediano': Size(760, 900),
    '1024 × 768': Size(1024, 768),
    'expandido': Size(1280, 900),
    'monitor ancho': Size(1920, 1080),
  };

  for (final entry in sizes.entries) {
    testWidgets('Monedas PULSO se adapta al ancho ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = _MemoryAppearanceStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appearanceStoreProvider.overrideWithValue(store),
            syncStatusProvider.overrideWith(
              (ref) => Stream.value(
                SyncStatusSnapshot.offline(
                  detail: 'API remota no disponible',
                  source: 'sync-local',
                  pendingEvents: 2,
                ),
              ),
            ),
            currencyProvider.overrideWith(
              () => _CurrencyNotifier(const [
                CurrencyModel(
                  id: 'dop',
                  name: 'Peso dominicano',
                  code: 'DOP',
                  symbol: r'RD$',
                ),
                CurrencyModel(
                  id: 'usd',
                  name: 'Dólar estadounidense',
                  code: 'USD',
                  symbol: r'US$',
                ),
                CurrencyModel(
                  id: 'eur',
                  name: 'Euro',
                  code: 'EUR',
                  symbol: '€',
                ),
              ]),
            ),
            exchangeRateProvider.overrideWith(
              () => _ExchangeRateNotifier([
                ExchangeRateModel(
                  id: 'rate-1',
                  monedaIdBase: 'usd',
                  monedaIdTarget: 'dop',
                  exchangeRate: 60,
                  fechaInicio: DateTime.utc(2026, 1, 1),
                ),
              ]),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: CurrenciesPulsoView())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MONEDAS.', findRichText: true), findsOneWidget);
      expect(find.text('Peso dominicano'), findsOneWidget);
      expect(find.text('PULSO · Monedas'), findsNothing);
      expect(find.text('MODO LOCAL'), findsOneWidget);
      expect(tester.takeException(), isNull);

      if (entry.key == 'mediano') {
        await tester.tap(find.text('Peso dominicano'));
        await tester.pumpAndSettle();
        expect(find.text('DETALLE SELECCIONADO'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      if (entry.key == 'expandido') {
        await tester.tap(find.text('Peso dominicano'));
        await tester.pump();
        expect(find.text('DETALLE SELECCIONADO'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      if (entry.key == 'monitor ancho') {
        expect(find.text('COMO BASE'), findsOneWidget);
        expect(find.text('COMO DESTINO'), findsOneWidget);

        await tester.tap(find.text('Peso dominicano'));
        await tester.pump();
        await tester.tap(find.text('VER TIPOS DE CAMBIO (1)'));
        await tester.pump();

        expect(find.text('TIPOS DE CAMBIO / DOP'), findsOneWidget);
        expect(find.text('USD  →  DOP'), findsOneWidget);
        expect(find.text('1 USD = 60 DOP'), findsOneWidget);

        await tester.tap(find.text('VOLVER A MONEDA'));
        await tester.pump();
        expect(find.text('DETALLE SELECCIONADO'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('Monedas PULSO presenta el estado vacío', (tester) async {
    await tester.pumpWidget(_stateHarness(() => _CurrencyNotifier(const [])));
    await tester.pumpAndSettle();

    expect(find.text('Todavía no hay monedas registradas.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Monedas PULSO presenta el error y permite reintentar', (
    tester,
  ) async {
    await tester.pumpWidget(_stateHarness(_ErrorCurrencyNotifier.new));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('No se pudo cargar el catálogo.'),
      findsOneWidget,
    );
    expect(find.text('REINTENTAR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _stateHarness(CurrencyNotifier Function() currencies) {
  return ProviderScope(
    overrides: [
      appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
      syncStatusProvider.overrideWith(
        (ref) => Stream.value(
          SyncStatusSnapshot(
            level: SyncStatusLevel.synced,
            label: 'Sincronizado',
            detail: 'Base local al día',
            checkedAt: DateTime.utc(2026, 7, 10),
          ),
        ),
      ),
      currencyProvider.overrideWith(currencies),
      exchangeRateProvider.overrideWith(() => _ExchangeRateNotifier(const [])),
    ],
    child: const MaterialApp(home: Scaffold(body: CurrenciesPulsoView())),
  );
}

class _CurrencyNotifier extends CurrencyNotifier {
  _CurrencyNotifier(this.currencies);

  final List<CurrencyModel> currencies;

  @override
  Future<List<CurrencyModel>> build() async => currencies;

  @override
  Future<void> refresh() async {
    state = AsyncData(currencies);
  }
}

class _ExchangeRateNotifier extends ExchangeRateNotifier {
  _ExchangeRateNotifier(this.rates);

  final List<ExchangeRateModel> rates;

  @override
  Future<List<ExchangeRateModel>> build() async => rates;
}

class _ErrorCurrencyNotifier extends CurrencyNotifier {
  @override
  Future<List<CurrencyModel>> build() async {
    throw StateError('API local no disponible');
  }

  @override
  Future<void> refresh() async {
    state = AsyncError(
      StateError('API local no disponible'),
      StackTrace.current,
    );
  }
}

class _MemoryAppearanceStore implements AppearanceStore {
  AppearancePreference? saved;

  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {
    saved = preference;
  }
}
