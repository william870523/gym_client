import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/configuration/data/models/payment_type_model.dart';
import 'package:gym_client/src/features/configuration/presentation/state/payment_type_notifier.dart';
import 'package:gym_client/src/features/financials/presentation/widgets/exchange_rate_surcharge_scope_form.dart';

void main() {
  testWidgets('la excepción de sede cabe a 360 px y conserva cero explícito', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, String>? saved;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentTypeNotifierProvider.overrideWith(
            () => _PaymentTypes(),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => ExchangeRateSurchargeScopeForm(
                      rateLabel: 'EUR → CUP',
                      initial: const {'transfer': '8.00'},
                      globalValues: const {'transfer': '5.00'},
                      isGlobal: false,
                      onSubmit: (values) async => saved = values,
                      onReset: () async {},
                    ),
                  ),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('EXCEPCIÓN · SEDE ACTIVA'), findsOneWidget);
    expect(find.text('Global: 5.00'), findsOneWidget);
    expect(find.byKey(const ValueKey('rate-surcharge-reset-site')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byKey(const ValueKey('rate-surcharge-transfer')),
      '0',
    );
    await tester.tap(find.byKey(const ValueKey('rate-surcharge-save')));
    await tester.pumpAndSettle();
    expect(saved, {'transfer': '0'});
    expect(tester.takeException(), isNull);
  });
}

class _PaymentTypes extends PaymentTypeNotifier {
  @override
  Future<List<PaymentTypeModel>> build() async => [
    PaymentTypeModel(id: 'cash', name: 'Efectivo'),
    PaymentTypeModel(id: 'transfer', name: 'Transferencia'),
  ];
}
