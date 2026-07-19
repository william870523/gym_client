import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_palette_id.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_theme.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_tokens.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';
import 'package:gym_client/src/features/configuration/data/models/payment_type_model.dart';
import 'package:gym_client/src/features/configuration/presentation/state/payment_type_notifier.dart';
import 'package:gym_client/src/features/financials/data/models/account_model.dart';
import 'package:gym_client/src/features/financials/data/models/currency_model.dart';
import 'package:gym_client/src/features/financials/data/models/exchange_rate_model.dart';
import 'package:gym_client/src/features/financials/presentation/providers/exchange_rate_notifier.dart';
import 'package:gym_client/src/features/financials/presentation/state/account_notifier.dart';
import 'package:gym_client/src/features/financials/presentation/state/currency_notifier.dart';
import 'package:gym_client/src/features/payments/presentation/widgets/process_payment_dialog.dart';
import 'package:gym_client/src/features/products/data/models/membresia_cuota_models.dart';
import 'package:gym_client/src/features/products/data/models/payment_plan_model.dart';
import 'package:gym_client/src/features/products/data/repositories/payment_plan_repository.dart';
import 'package:gym_client/src/features/products/presentation/state/payment_plan_notifier.dart';

void main() {
  testWidgets(
    'el cobro ofrece PRIMERA CUOTA y al elegirla el objetivo baja a la cuota 1',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      // Con el plan completo seleccionado se exigen los 30.00.
      expect(find.text('PLAN COMPLETO'), findsOneWidget);
      expect(find.text('PRIMERA CUOTA'), findsOneWidget);
      expect(
        find.textContaining('Faltan 30.00 en la moneda del plan'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('pay-mode-installments')));
      await tester.pumpAndSettle();

      // Elegida la cuota 1, el objetivo pasa a 15.00.
      expect(
        find.textContaining('Faltan 15.00 en la moneda del plan'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _harness() {
  return ProviderScope(
    overrides: [
      appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
      syncStatusProvider.overrideWith(
        (ref) => Stream.value(
          SyncStatusSnapshot.offline(detail: 'test', source: 'test'),
        ),
      ),
      currencyProvider.overrideWith(
        () => _CurrencyNotifier(const [
          CurrencyModel(id: 'cur-eur', name: 'Euro', code: 'EUR', symbol: '€'),
        ]),
      ),
      paymentTypeNotifierProvider.overrideWith(
        () => _PaymentTypeNotifier([
          PaymentTypeModel(id: 'tp-cash', name: 'Efectivo'),
        ]),
      ),
      accountProvider.overrideWith(() => _AccountNotifier([])),
      exchangeRateProvider.overrideWith(() => _RateNotifier([])),
      paymentPlanProvider.overrideWith(
        () => _PlanNotifier([
          PaymentPlanModel(
            id: 'plan-cuotas',
            nombre: 'Trimestral cuota',
            importe: 30,
            duracion: 90,
            monedaId: 'cur-eur',
            aceptaCuotas: true,
          ),
        ]),
      ),
      paymentPlanRepositoryProvider.overrideWith(
        (ref) => _FakePlanRepository(),
      ),
    ],
    child: MaterialApp(
      // El diálogo asume un tema PULSO ambiental (como en la app real).
      theme: PulsoThemeFactory.build(
        PulsoTokens.resolve(PulsoPaletteId.clay, Brightness.light),
      ),
      home: Scaffold(
        body: ProcessPaymentDialog(
          client: ClientModel(id: 'CI-1', nombres: 'Abel'),
          planId: 'plan-cuotas',
        ),
      ),
    ),
  );
}

class _FakePlanRepository extends PaymentPlanRepository {
  _FakePlanRepository() : super(Dio());

  @override
  Future<List<Map<String, dynamic>>> getPlanCuotasScheme(String planId) async =>
      [
        {'numeroCuota': 1, 'importe': '15', 'diasCobertura': 30},
        {'numeroCuota': 2, 'importe': '15', 'diasCobertura': 60},
      ];

  @override
  Future<List<MembresiaCuotaModel>> getMembresiaCuotas(
    String membershipId,
  ) async => [];
}

class _PlanNotifier extends PaymentPlanNotifier {
  _PlanNotifier(this.items);
  final List<PaymentPlanModel> items;

  @override
  Future<List<PaymentPlanModel>> build() async => items;
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

class _AccountNotifier extends AccountNotifier {
  _AccountNotifier(this.items);
  final List<AccountModel> items;

  @override
  Future<List<AccountModel>> build() async => items;
}

class _RateNotifier extends ExchangeRateNotifier {
  _RateNotifier(this.items);
  final List<ExchangeRateModel> items;

  @override
  Future<List<ExchangeRateModel>> build() async => items;
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
