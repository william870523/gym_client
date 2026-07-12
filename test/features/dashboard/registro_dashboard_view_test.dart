import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gym_client/src/features/attendance/data/models/attendance_model.dart';
import 'package:gym_client/src/features/attendance/presentation/state/attendance_notifier.dart';
import 'package:gym_client/src/features/clients/data/models/client_model.dart';
import 'package:gym_client/src/features/clients/presentation/state/client_notifier.dart';
import 'package:gym_client/src/features/configuration/data/models/payment_type_model.dart';
import 'package:gym_client/src/features/dashboard/presentation/screens/registro_dashboard_view.dart';
import 'package:gym_client/src/features/financials/data/models/currency_model.dart';
import 'package:gym_client/src/features/financials/presentation/state/currency_notifier.dart';
import 'package:gym_client/src/features/payments/data/models/payment_model.dart';
import 'package:gym_client/src/features/payments/presentation/state/payment_notifier.dart';
import 'package:gym_client/src/features/products/data/models/payment_plan_model.dart';
import 'package:gym_client/src/features/products/presentation/state/payment_plan_notifier.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('describe el pago y diferencia los movimientos por color', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final client = ClientModel(
      id: '00010482254',
      nombres: 'Sonia',
      apellidos: 'Ruiz Vega',
      activo: true,
    );
    final payment = PaymentModel(
      id: 'payment-1',
      ci: client.id,
      fecha: now.toUtc(),
      amount: 1,
      planId: 'plan-1',
      currencyId: 'eur',
      details: [
        PaymentDetailModel(
          id: 'detail-1',
          paymentId: 'payment-1',
          paymentTypeId: 'cash',
          currencyId: 'eur',
          amount: 1,
        ),
      ],
    );
    final attendance = AttendanceModel(
      id: 'attendance-1',
      clientId: client.id,
      clientName: 'Sonia Ruiz Vega',
      checkIn: now.subtract(const Duration(minutes: 5)),
      checkOut: now.subtract(const Duration(minutes: 1)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attendanceNotifierProvider.overrideWith(
            () => _AttendanceNotifier([attendance]),
          ),
          paymentNotifierProvider.overrideWith(
            () => _PaymentNotifier([payment]),
          ),
          clientNotifierProvider.overrideWith(() => _ClientNotifier([client])),
          paymentTypesProvider.overrideWith(
            (ref) async => [PaymentTypeModel(id: 'cash', name: 'Efectivo')],
          ),
          paymentPlanProvider.overrideWith(
            () => _PaymentPlanNotifier([
              PaymentPlanModel(
                id: 'plan-1',
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
            ]),
          ),
        ],
        child: const MaterialApp(home: RegistroDashboardView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PAGO · DIARIO'), findsOneWidget);
    expect(find.text('EFECTIVO'), findsOneWidget);
    expect(find.text('PAGO · DIARIO · EFECTIVO'), findsNothing);
    expect(find.text('Sonia Ruiz Vega'), findsNWidgets(3));
    expect(find.text('€1'), findsWidgets);
    expect(
      tester.getTopLeft(find.text('EFECTIVO')).dx,
      greaterThan(tester.getTopLeft(find.text('PAGO · DIARIO')).dx + 200),
    );

    final amountFinder = find.byKey(const ValueKey('movement-amount-ocre'));
    final timeFinder = find.byKey(const ValueKey('movement-time-ocre'));
    final amountText = tester.widget<Text>(amountFinder);
    expect(amountText.style?.fontWeight, FontWeight.w600);
    expect(
      tester.getRect(timeFinder).left - tester.getRect(amountFinder).right,
      greaterThanOrEqualTo(80),
    );

    final paymentInk = tester.widget<Container>(
      find.byKey(const ValueKey('movement-ink-ocre')),
    );
    final entryInk = tester.widget<Container>(
      find.byKey(const ValueKey('movement-ink-verde')),
    );
    final exitInk = tester.widget<Container>(
      find.byKey(const ValueKey('movement-ink-azul')),
    );
    expect({paymentInk.color, entryInk.color, exitInk.color}.length, 3);
  });
}

class _AttendanceNotifier extends AttendanceNotifier {
  _AttendanceNotifier(this.items);

  final List<AttendanceModel> items;

  @override
  Future<List<AttendanceModel>> build() async => items;
}

class _PaymentNotifier extends PaymentNotifier {
  _PaymentNotifier(this.items);

  final List<PaymentModel> items;

  @override
  Future<List<PaymentModel>> build() async => items;
}

class _ClientNotifier extends ClientNotifier {
  _ClientNotifier(this.items);

  final List<ClientModel> items;

  @override
  Future<List<ClientModel>> build() async => items;
}

class _PaymentPlanNotifier extends PaymentPlanNotifier {
  _PaymentPlanNotifier(this.items);

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
