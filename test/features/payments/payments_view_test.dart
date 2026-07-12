import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';
import 'package:gym_client/src/features/clients/presentation/state/client_notifier.dart';
import 'package:gym_client/src/features/configuration/data/models/payment_type_model.dart';
import 'package:gym_client/src/features/dashboard/presentation/state/dashboard_nav_provider.dart';
import 'package:gym_client/src/features/financials/data/models/account_model.dart';
import 'package:gym_client/src/features/financials/data/models/currency_model.dart';
import 'package:gym_client/src/features/financials/presentation/state/currency_notifier.dart';
import 'package:gym_client/src/features/payments/data/models/payment_model.dart';
import 'package:gym_client/src/features/payments/presentation/screens/payments_view.dart';
import 'package:gym_client/src/features/payments/presentation/state/payment_notifier.dart';
import 'package:gym_client/src/features/products/data/models/payment_plan_model.dart';
import 'package:gym_client/src/features/products/presentation/state/payment_plan_notifier.dart';
import 'package:gym_client/src/features/trainers/data/models/trainer_model.dart';
import 'package:gym_client/src/features/trainers/presentation/providers/trainer_notifier.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('muestra pagos reales, recibo marginal y búsqueda', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = ClientModel(
      id: '91021547301',
      nombres: 'Carlos Antonio',
      apellidos: 'Millán',
      activo: true,
      planId: 'plan-daily',
    );
    final payment = PaymentModel(
      id: 'payment-carlos',
      ci: client.id,
      fecha: DateTime.now().toUtc(),
      amount: 1,
      planId: 'plan-daily',
      currencyId: 'eur',
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
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardNavProvider.overrideWith(() => DashboardNavNotifier()),
          paymentNotifierProvider.overrideWith(
            () => _PaymentNotifier([payment]),
          ),
          clientNotifierProvider.overrideWith(() => _ClientNotifier([client])),
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
            () => _CurrencyNotifier([
              const CurrencyModel(
                id: 'eur',
                name: 'Euro',
                code: 'EUR',
                symbol: '€',
              ),
              const CurrencyModel(
                id: 'mlc',
                name: 'Moneda libremente convertible',
                code: 'MLC',
                symbol: r'$',
              ),
            ]),
          ),
          trainerProvider.overrideWith(() => _TrainerNotifier()),
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
        child: const MaterialApp(home: PaymentsView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LIBRO\nDE PAGOS.'), findsOneWidget);
    expect(find.text('Carlos Antonio Millán'), findsWidgets);
    expect(find.text('Diario'), findsWidgets);
    expect(find.text('TRANSFERENCIA'), findsWidgets);
    expect(find.text('€1'), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey('payments-search')),
      'persona inexistente',
    );
    await tester.pump();

    expect(
      find.text('No hay asientos que coincidan con la consulta.'),
      findsOneWidget,
    );
  });
}

class _PaymentNotifier extends PaymentNotifier {
  _PaymentNotifier(this.items);

  final List<PaymentModel> items;

  @override
  Future<List<PaymentModel>> build() async => items;

  @override
  Future<void> refresh() async {
    state = AsyncValue.data(items);
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
