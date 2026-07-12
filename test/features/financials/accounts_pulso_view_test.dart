import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/configuration/data/models/payment_type_model.dart';
import 'package:gym_client/src/features/configuration/presentation/state/payment_type_notifier.dart';
import 'package:gym_client/src/features/financials/data/models/account_model.dart';
import 'package:gym_client/src/features/financials/data/models/currency_model.dart';
import 'package:gym_client/src/features/financials/presentation/screens/accounts_pulso_view.dart';
import 'package:gym_client/src/features/financials/presentation/state/account_notifier.dart';
import 'package:gym_client/src/features/financials/presentation/state/currency_notifier.dart';

void main() {
  const sizes = <String, Size>{
    'compacto': Size(390, 844),
    'mediano': Size(760, 900),
    'escritorio': Size(1280, 900),
    'ventana baja': Size(1024, 650),
  };

  for (final entry in sizes.entries) {
    testWidgets('Plan de cuentas PULSO se adapta al ancho ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('PLAN DE CUENTAS.', findRichText: true), findsOneWidget);
      expect(find.text('Caja principal'), findsOneWidget);
      expect(find.text('Banco dólares'), findsOneWidget);
      expect(find.text('MODO LOCAL'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final row = find.descendant(
        of: find.byKey(const PageStorageKey('pulso-accounts-list')),
        matching: find.text('Caja principal'),
      );
      if (entry.key == 'mediano') {
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.text('DETALLE SELECCIONADO'), findsOneWidget);
      }
      if (entry.key == 'escritorio') {
        await tester.tap(row);
        await tester.pump();
        expect(find.text('DETALLE SELECCIONADO'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('resuelve el tipo de pago por su nombre', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.text('Divisa principal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite editar una cuenta y guarda los cambios', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final accountNotifier = _AccountNotifier([
      AccountModel(
        id: 'acc-caja',
        name: 'Caja principal',
        currencyId: 'cur-bob',
        currencyCode: 'BOB',
        currencySymbol: 'Bs',
        paymentTypeId: 'pt-cash',
      ),
    ]);
    await tester.pumpWidget(_harness(accountNotifier: accountNotifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar Caja principal'));
    await tester.pumpAndSettle();
    expect(find.text('EDITAR CUENTA'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('pulso-account-name')),
      'Caja recepción',
    );
    await tester.tap(find.text('GUARDAR CAMBIOS'));
    await tester.pumpAndSettle();

    expect(accountNotifier.updates, hasLength(1));
    final (id, name, currencyId, paymentTypeId) =
        accountNotifier.updates.single;
    expect(id, 'acc-caja');
    expect(name, 'Caja recepción');
    expect(currencyId, 'cur-bob');
    expect(paymentTypeId, 'pt-cash');
    expect(find.text('EDITAR CUENTA'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtra cuentas sin tipo de pago', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sin tipo').last);
    await tester.pump();
    final list = find.byKey(const PageStorageKey('pulso-accounts-list'));
    expect(
      find.descendant(of: list, matching: find.text('Banco dólares')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: list, matching: find.text('Caja principal')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _harness({_AccountNotifier? accountNotifier}) {
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
      currencyProvider.overrideWith(
        () => _CurrencyNotifier(const [
          CurrencyModel(
            id: 'cur-bob',
            name: 'Boliviano',
            code: 'BOB',
            symbol: 'Bs',
          ),
          CurrencyModel(id: 'cur-usd', name: 'Dólar', code: 'USD', symbol: r'$'),
        ]),
      ),
      accountProvider.overrideWith(
        () =>
            accountNotifier ??
            _AccountNotifier([
          AccountModel(
            id: 'acc-caja',
            name: 'Caja principal',
            currencyId: 'cur-bob',
            currencyCode: 'BOB',
            currencyName: 'Boliviano',
            currencySymbol: 'Bs',
            paymentTypeId: 'pt-cash',
          ),
          AccountModel(
            id: 'acc-usd',
            name: 'Banco dólares',
            currencyId: 'cur-usd',
            currencyCode: 'USD',
            currencyName: 'Dólar',
            currencySymbol: r'$',
          ),
        ]),
      ),
      paymentTypeNotifierProvider.overrideWith(
        () => _PaymentTypeNotifier([
          PaymentTypeModel(id: 'pt-cash', name: 'Efectivo', code: 'CASH'),
        ]),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: AccountsPulsoView())),
  );
}

class _AccountNotifier extends AccountNotifier {
  _AccountNotifier(this.items);
  final List<AccountModel> items;
  final updates = <(String, String, String, String?)>[];

  @override
  Future<List<AccountModel>> build() async => items;

  @override
  Future<void> updateAccount(
    String id,
    String name,
    String currencyId, {
    String? paymentTypeId,
  }) async {
    updates.add((id, name, currencyId, paymentTypeId));
  }
}

class _CurrencyNotifier extends CurrencyNotifier {
  _CurrencyNotifier(this.items);
  final List<CurrencyModel> items;

  @override
  Future<List<CurrencyModel>> build() async => items;
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
