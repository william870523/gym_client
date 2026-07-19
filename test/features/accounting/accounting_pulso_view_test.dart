import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/core/widgets/pulso_widgets.dart';
import 'package:gym_client/src/features/accounting/data/models/accounting_models.dart';
import 'package:gym_client/src/features/accounting/data/models/management_margin_annual_models.dart';
import 'package:gym_client/src/features/accounting/data/models/management_margin_models.dart';
import 'package:gym_client/src/features/accounting/data/models/membership_revenue_models.dart';
import 'package:gym_client/src/features/accounting/data/models/operational_annual_results_models.dart';
import 'package:gym_client/src/features/accounting/data/models/operational_results_models.dart';
import 'package:gym_client/src/features/accounting/data/models/trainer_service_cost_models.dart';
import 'package:gym_client/src/features/accounting/presentation/screens/accounting_view.dart';
import 'package:gym_client/src/features/accounting/presentation/state/accounting_providers.dart';
import 'package:gym_client/src/features/accounting/presentation/widgets/operational_cash_results_panel.dart';
import 'package:gym_client/src/features/accounting/presentation/widgets/operational_annual_results_panel.dart';
import 'package:gym_client/src/features/accounting/presentation/widgets/membership_revenue_panel.dart';
import 'package:gym_client/src/features/accounting/presentation/widgets/management_margin_panel.dart';
import 'package:gym_client/src/features/accounting/presentation/widgets/management_margin_annual_panel.dart';
import 'package:gym_client/src/features/accounting/presentation/widgets/trainer_service_cost_panel.dart';
import 'package:gym_client/src/features/products/data/models/payment_plan_model.dart';
import 'package:gym_client/src/features/products/presentation/state/payment_plan_notifier.dart';
import 'package:gym_client/src/features/trainers/data/models/trainer_model.dart';
import 'package:gym_client/src/features/trainers/presentation/providers/trainer_notifier.dart';

void main() {
  testWidgets(
    'ingreso ya ganado presenta el error del servidor sin texto técnico',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final request = RequestOptions(path: '/contabilidad/membership-revenue');
      final error = DioException.badResponse(
        statusCode: 400,
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 400,
          data: {'error': 'Una membresía histórica requiere revisión.'},
        ),
      );

      await tester.pumpWidget(_harness(membershipRevenueError: error));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('RESULTADO DE CAJA'));
      await tester.tap(find.text('RESULTADO DE CAJA'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('membership-revenue-action-compact')),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Una membresía histórica requiere revisión.'),
        findsOneWidget,
      );
      expect(find.textContaining('DioException'), findsNothing);
      expect(find.textContaining('bad response'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final entry in const {
    'compacto': Size(390, 844),
    'escritorio': Size(1280, 900),
  }.entries) {
    testWidgets(
      'ingreso ya ganado separa caja, servicio y scroll interno ${entry.key}',
      (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _harness(membershipRevenue: _membershipRevenue()),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('RESULTADO DE CAJA'));
        await tester.tap(find.text('RESULTADO DE CAJA'));
        await tester.pumpAndSettle();
        final expanded = find.byKey(const Key('membership-revenue-action'));
        final compact = find.byKey(
          const Key('membership-revenue-action-compact'),
        );
        await tester.tap(expanded.evaluate().isNotEmpty ? expanded : compact);
        await tester.pumpAndSettle();

        expect(find.text('Dinero cobrado'), findsOneWidget);
        expect(find.text('Servicio ya prestado'), findsOneWidget);
        if (entry.value.width < 900) {
          await tester.drag(
            find.byKey(const Key('membership-revenue-metrics-list')),
            const Offset(-300, 0),
          );
          await tester.pumpAndSettle();
        }
        expect(find.text('Pendiente de prestar'), findsOneWidget);
        expect(find.text('9,007,199,254,740,993.10'), findsAtLeastNWidgets(1));
        expect(
          find.byKey(const Key('membership-revenue-memberships-scrollbar')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('membership-revenue-row-membership-00')),
          findsOneWidget,
        );
        final list = tester.widget<ListView>(
          find.byKey(const Key('membership-revenue-memberships-list')),
        );
        list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('membership-revenue-row-membership-17')),
          findsOneWidget,
        );
        expect(
          find.ancestor(
            of: find.byType(MembershipRevenuePanel),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is SingleChildScrollView &&
                  widget.scrollDirection == Axis.vertical,
            ),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('margen gerencial muestra certificacion R4.4', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(managementMargin: _managementMargin(certified: true)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('RESULTADO DE CAJA'));
    await tester.tap(find.text('RESULTADO DE CAJA'));
    await tester.pumpAndSettle();
    final expanded = find.byKey(const Key('management-margin-action'));
    final compact = find.byKey(const Key('management-margin-action-compact'));
    await tester.tap(expanded.evaluate().isNotEmpty ? expanded : compact);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('management-margin-certification-state')),
      findsOneWidget,
    );
    expect(find.text('CERTIFICADO'), findsOneWidget);
    expect(find.textContaining('snapshot firmado'), findsOneWidget);
    expect(
      find.byKey(const Key('management-margin-scrollbar')),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byType(ManagementMarginPanel),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.vertical,
        ),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('devengado anual certificado usa scroll interno R4.5', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        managementMargin: _managementMargin(certified: true),
        managementAnnualResults: _managementAnnualResults(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('RESULTADO DE CAJA'));
    await tester.tap(find.text('RESULTADO DE CAJA'));
    await tester.pumpAndSettle();
    final expanded = find.byKey(const Key('management-margin-action'));
    final compact = find.byKey(const Key('management-margin-action-compact'));
    await tester.tap(expanded.evaluate().isNotEmpty ? expanded : compact);
    await tester.pumpAndSettle();
    final annualExpanded = find.byKey(
      const Key('management-margin-annual-action'),
    );
    final annualCompact = find.byKey(
      const Key('management-margin-annual-action-compact'),
    );
    await tester.tap(
      annualExpanded.evaluate().isNotEmpty ? annualExpanded : annualCompact,
    );
    await tester.pumpAndSettle();

    expect(find.text('Margen certificado'), findsOneWidget);
    expect(
      find.byKey(const Key('management-margin-annual-months-scrollbar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('management-margin-annual-month-2026-01')),
      findsOneWidget,
    );
    final list = tester.widget<ListView>(
      find.byKey(const Key('management-margin-annual-months-list')),
    );
    list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('management-margin-annual-month-2026-12')),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byType(ManagementMarginAnnualPanel),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.vertical,
        ),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'devengado anual permite cambiar de año en tamaño compacto R4.5.1', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _harness(
          managementMargin: _managementMargin(certified: true),
          managementAnnualResults: _managementAnnualResults(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('RESULTADO DE CAJA'));
      await tester.tap(find.text('RESULTADO DE CAJA'));
      await tester.pumpAndSettle();
      final expanded = find.byKey(const Key('management-margin-action'));
      final compact = find.byKey(const Key('management-margin-action-compact'));
      await tester.tap(expanded.evaluate().isNotEmpty ? expanded : compact);
      await tester.pumpAndSettle();
      final annualExpanded = find.byKey(
        const Key('management-margin-annual-action'),
      );
      final annualCompact = find.byKey(
        const Key('management-margin-annual-action-compact'),
      );
      await tester.tap(
        annualExpanded.evaluate().isNotEmpty ? annualExpanded : annualCompact,
      );
      await tester.pumpAndSettle();

      // R4.5.1: en compacto deben existir ambas flechas de año (antes solo
      // había back, exportar y actualizar). Verificamos existencia y que están
      // habilitadas; la navegación real de año depende del provider remoto y
      // se prueba en el flujo expandido existente.
      final previous = find.byKey(
        const Key('management-margin-annual-previous-compact'),
      );
      final next = find.byKey(
        const Key('management-margin-annual-next-compact'),
      );
      expect(previous, findsOneWidget);
      expect(next, findsOneWidget);
      expect(
        tester.widget<PulsoIconButton>(previous).onPressed,
        isNotNull,
      );
      expect(tester.widget<PulsoIconButton>(next).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'devengado anual muestra BLOQUEO_INVALIDO como aviso R4.5.1', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _harness(
          managementMargin: _managementMargin(certified: true),
          managementAnnualResults: _managementAnnualResults(
            blockedMonth: '2026-02',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('RESULTADO DE CAJA'));
      await tester.tap(find.text('RESULTADO DE CAJA'));
      await tester.pumpAndSettle();
      final expanded = find.byKey(const Key('management-margin-action'));
      final compact = find.byKey(const Key('management-margin-action-compact'));
      await tester.tap(expanded.evaluate().isNotEmpty ? expanded : compact);
      await tester.pumpAndSettle();
      final annualExpanded = find.byKey(
        const Key('management-margin-annual-action'),
      );
      final annualCompact = find.byKey(
        const Key('management-margin-annual-action-compact'),
      );
      await tester.tap(
        annualExpanded.evaluate().isNotEmpty ? annualExpanded : annualCompact,
      );
      await tester.pumpAndSettle();

      // R4.5.1: febrero tiene un cierre CERRADO sin bloqueo y debe mostrarse
      // como "BLOQUEO INVÁLIDO", no como "SIN CIERRE". La lista es lazy, así
      // que avanzamos su controlador por pasos hasta construir febrero, igual
      // que el test de scroll existente hace con diciembre.
      final list = tester.widget<ListView>(
        find.byKey(const Key('management-margin-annual-months-list')),
      );
      var februaryFound = false;
      for (var attempt = 0; attempt < 12 && !februaryFound; attempt++) {
        list.controller!.jumpTo((attempt + 1) * 60.0);
        await tester.pumpAndSettle();
        februaryFound = find
            .byKey(const Key('management-margin-annual-month-2026-02'))
            .evaluate()
            .isNotEmpty;
      }
      expect(februaryFound, isTrue);
      expect(find.text('BLOQUEO INVÁLIDO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('exportación anual del devengado mantiene diálogo con scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        managementMargin: _managementMargin(certified: true),
        managementAnnualResults: _managementAnnualResults(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('RESULTADO DE CAJA'));
    await tester.tap(find.text('RESULTADO DE CAJA'));
    await tester.pumpAndSettle();
    final marginAction = find.byKey(
      const Key('management-margin-action-compact'),
    );
    await tester.tap(marginAction);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('management-margin-annual-action-compact')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('management-margin-annual-export-compact')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('management-margin-annual-export-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('management-margin-annual-export-scrollbar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('management-margin-annual-export-csv')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('management-margin-annual-export-print')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('management-margin-annual-export-pdf')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final entry in const {
    'compacto': Size(390, 844),
    'escritorio': Size(1280, 900),
  }.entries) {
    testWidgets(
      'costo del servicio separa ganado pagado futuro y scroll interno ${entry.key}',
      (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _harness(trainerServiceCost: _trainerServiceCost()),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('RESULTADO DE CAJA'));
        await tester.tap(find.text('RESULTADO DE CAJA'));
        await tester.pumpAndSettle();
        final expanded = find.byKey(const Key('trainer-service-cost-action'));
        final compact = find.byKey(
          const Key('trainer-service-cost-action-compact'),
        );
        await tester.tap(expanded.evaluate().isNotEmpty ? expanded : compact);
        await tester.pumpAndSettle();

        expect(find.text('GANADO ESTE MES'), findsOneWidget);
        if (entry.value.width < 900) {
          await tester.drag(
            find.byKey(const Key('trainer-service-cost-metrics-list')),
            const Offset(-300, 0),
          );
          await tester.pumpAndSettle();
        }
        expect(find.text('GANADO SIN PAGAR'), findsOneWidget);
        expect(
          find.byKey(const Key('trainer-service-cost-scrollbar')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('trainer-service-cost-row-cost-00')),
          findsOneWidget,
        );
        final list = tester.widget<ListView>(
          find.byKey(const Key('trainer-service-cost-list')),
        );
        list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('trainer-service-cost-row-cost-17')),
          findsOneWidget,
        );
        expect(
          find.ancestor(
            of: find.byType(TrainerServiceCostPanel),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is SingleChildScrollView &&
                  widget.scrollDirection == Axis.vertical,
            ),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final entry in const {
    'compacto': Size(390, 844),
    'escritorio': Size(1280, 900),
  }.entries) {
    testWidgets(
      'margen gerencial separa plan entrenador y socio con scroll interno ${entry.key}',
      (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _harness(managementMargin: _managementMargin()),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('RESULTADO DE CAJA'));
        await tester.tap(find.text('RESULTADO DE CAJA'));
        await tester.pumpAndSettle();
        final expanded = find.byKey(const Key('management-margin-action'));
        final compact = find.byKey(
          const Key('management-margin-action-compact'),
        );
        await tester.tap(expanded.evaluate().isNotEmpty ? expanded : compact);
        await tester.pumpAndSettle();

        expect(find.text('MARGEN DIRECTO MES'), findsOneWidget);
        if (entry.value.width < 900) {
          await tester.drag(
            find.byKey(const Key('management-margin-metrics-list')),
            const Offset(-300, 0),
          );
          await tester.pumpAndSettle();
        }
        expect(find.text('COSTO DIRECTO MES'), findsOneWidget);
        expect(
          find.byKey(const Key('management-margin-scrollbar')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('management-margin-row-plan-plan-00')),
          findsOneWidget,
        );
        final list = tester.widget<ListView>(
          find.byKey(const Key('management-margin-list')),
        );
        list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('management-margin-row-plan-plan-17')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('management-margin-section-trainer')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('management-margin-row-trainer-trainer-1')),
          findsOneWidget,
        );
        expect(find.textContaining('Atribución parcial'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('management-margin-section-client')),
        );
        await tester.pumpAndSettle();
        final clientList = tester.widget<ListView>(
          find.byKey(const Key('management-margin-list')),
        );
        clientList.controller!.jumpTo(
          clientList.controller!.position.maxScrollExtent,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('management-margin-row-client-CI-01')),
          findsOneWidget,
        );
        expect(find.textContaining('-50.00'), findsAtLeastNWidgets(1));

        expect(
          find.ancestor(
            of: find.byType(ManagementMarginPanel),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is SingleChildScrollView &&
                  widget.scrollDirection == Axis.vertical,
            ),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final entry in const {
    'compacto': Size(390, 844),
    'escritorio': Size(1280, 900),
  }.entries) {
    testWidgets(
      'comparativa anual conserva evidencia y scroll interno ${entry.key}',
      (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_harness(annualResults: _annualResults()));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('RESULTADO DE CAJA'));
        await tester.tap(find.text('RESULTADO DE CAJA'));
        await tester.pumpAndSettle();
        final expanded = find.byKey(const Key('operational-annual-action'));
        final compact = find.byKey(
          const Key('operational-annual-action-compact'),
        );
        await tester.tap(expanded.evaluate().isNotEmpty ? expanded : compact);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('operational-annual-months-scrollbar')),
          findsOneWidget,
        );
        expect(
          entry.value.width < 600
              ? find.text('CERTIFICADOS')
              : find.text('Meses exigibles certificados'),
          findsOneWidget,
        );
        expect(find.text('1/6'), findsOneWidget);
        expect(find.text('9,007,199,254,740,993.10'), findsAtLeastNWidgets(1));
        expect(
          find.byKey(const Key('operational-annual-month-2026-01')),
          findsOneWidget,
        );
        final monthsList = tester.widget<ListView>(
          find.byKey(const Key('operational-annual-months-list')),
        );
        monthsList.controller!.jumpTo(
          monthsList.controller!.position.maxScrollExtent,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('operational-annual-month-2026-12')),
          findsOneWidget,
        );
        expect(
          find.ancestor(
            of: find.byType(OperationalAnnualResultsPanel),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is SingleChildScrollView &&
                  widget.scrollDirection == Axis.vertical,
            ),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final entry in const {
    'compacto': Size(390, 844),
    'mediano': Size(760, 900),
    'escritorio': Size(1280, 900),
  }.entries) {
    testWidgets('resultado de caja conserva scroll interno ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _harness(operationalResults: _operationalResults()),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('RESULTADO DE CAJA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RESULTADO DE CAJA'));
      await tester.pumpAndSettle();

      expect(find.text('Dinero cobrado'), findsOneWidget);
      expect(find.textContaining('CAJA, NO GANANCIA'), findsOneWidget);
      expect(
        find.byKey(const Key('operational-concepts-scrollbar')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(
        find.ancestor(
          of: find.byType(OperationalCashResultsPanel),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SingleChildScrollView &&
                widget.scrollDirection == Axis.vertical,
          ),
        ),
        findsNothing,
      );

      if (entry.value.width < 1180) {
        await tester.tap(find.text('RESERVAS'));
        await tester.pumpAndSettle();
      }
      expect(
        find.byKey(const Key('operational-obligations-scrollbar')),
        findsOneWidget,
      );
      expect(find.textContaining('RESERVA'), findsAtLeastNWidgets(1));
      expect(find.text('Entrenadora Demo'), findsOneWidget);

      if (entry.value.width < 840) {
        await tester.tap(find.text('CUENTAS'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(
        find.byKey(const Key('operational-accounts-scrollbar')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('operational-account-search')),
        'Cuenta CUP 099',
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('operational-account-cup-account-099')),
          matching: find.text('Cuenta CUP 099'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('exportación R3 conserva evidencia y scroll dentro del diálogo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(operationalResults: _certifiedOperationalResults()),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('RESULTADO DE CAJA'));
    await tester.tap(find.text('RESULTADO DE CAJA'));
    await tester.pumpAndSettle();

    expect(find.text('CERTIFICADO'), findsOneWidget);
    expect(find.text('CORTE CERTIFICADO'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(
      find.byKey(const Key('operational-export-action-compact')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Exportar Resultado de caja'), findsOneWidget);
    expect(
      find.byKey(const Key('operational-export-dialog-scrollbar')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('operational-export-pdf')), findsOneWidget);
    expect(find.byKey(const Key('operational-export-csv')), findsOneWidget);
    expect(find.byKey(const Key('operational-export-print')), findsOneWidget);
    expect(find.text('Una moneda específica'), findsOneWidget);
    final currencySelector = tester.widget<DropdownMenu<String>>(
      find.byKey(const Key('operational-export-currency-selector')),
    );
    expect(currencySelector.initialSelection, 'cup');
    await tester.ensureVisible(
      find.byKey(const Key('operational-export-currency-selector')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('operational-export-currency-selector')),
    );
    await tester.pumpAndSettle();
    final currencyInput = find.descendant(
      of: find.byKey(const Key('operational-export-currency-selector')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(currencyInput, 'M01');
    await tester.pumpAndSettle();
    expect(find.text('M01 · 100 cuenta(s)'), findsOneWidget);
    await tester.tap(find.text('M01 · 100 cuenta(s)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ahora: M01'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selector de moneda de exportación se adapta en escritorio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(operationalResults: _certifiedOperationalResults()),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('RESULTADO DE CAJA'));
    await tester.tap(find.text('RESULTADO DE CAJA'));
    await tester.pumpAndSettle();
    final expandedAction = find.byKey(const Key('operational-export-action'));
    final compactAction = find.byKey(
      const Key('operational-export-action-compact'),
    );
    await tester.tap(
      expandedAction.evaluate().isNotEmpty ? expandedAction : compactAction,
    );
    await tester.pumpAndSettle();

    expect(find.text('Una moneda específica'), findsOneWidget);
    expect(
      find.byKey(const Key('operational-export-currency-selector')),
      findsOneWidget,
    );
    expect(find.text('Todas las monedas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final entry in const {
    'compacto': Size(390, 844),
    'mediano': Size(760, 900),
    'escritorio': Size(1280, 900),
  }.entries) {
    testWidgets('Contabilidad PULSO se adapta al ancho ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('CONTABILIDAD.', findRichText: true), findsOneWidget);
      expect(find.text('Conceptos pendientes'), findsOneWidget);
      expect(find.text('2 comisión · 1 fijo'), findsOneWidget);
      expect(find.text('USD 225.00'), findsOneWidget);
      expect(find.text('PYG 200.00'), findsOneWidget);
      expect(find.textContaining('sin mezclar monedas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cierre mensual conserva formularios con scroll interno', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        monthlySummary: _largeMonthlySummary(
          closeStatus: const TreasuryMonthlyCloseStatusModel(
            monthEnded: true,
            readyToClose: true,
            canClose: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('TESORERÍA · CIERRE'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('treasury-range-monthly')));
    await tester.pumpAndSettle();

    expect(find.text('LISTO PARA CIERRE MENSUAL'), findsOneWidget);
    await tester.tap(find.byKey(const Key('treasury-monthly-close-action')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('treasury-monthly-close-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('treasury-monthly-close-dialog-scroll')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();
  });

  testWidgets('mes firmado expone integridad y reapertura auditada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const cycle = TreasuryMonthlyCloseCycleModel(
      id: 'close-01',
      month: '2026-07',
      state: 'CERRADO',
      closeReason: 'Revisión integral del período demostrativo.',
      hash: '1234567890abcdef',
      integrityVerified: true,
      closerName: 'Administración Demo',
      closerRole: 'admin',
      closedAt: '2026-08-01T12:00:00.000Z',
    );
    await tester.pumpWidget(
      _harness(
        monthlySummary: _largeMonthlySummary(
          closeStatus: const TreasuryMonthlyCloseStatusModel(
            state: 'CERRADO',
            monthEnded: true,
            canReopen: true,
            currentCycle: cycle,
            lastCycle: cycle,
            history: [cycle],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('TESORERÍA · CIERRE'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('treasury-range-monthly')));
    await tester.pumpAndSettle();

    expect(find.text('PERÍODO CERRADO Y FIRMADO'), findsOneWidget);
    expect(find.textContaining('integridad verificada'), findsOneWidget);
    await tester.tap(find.byKey(const Key('treasury-monthly-inspect-history')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('treasury-monthly-history-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('treasury-monthly-history-scroll')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Cerrar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('treasury-monthly-reopen-action')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('treasury-monthly-reopen-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('treasury-monthly-reopen-dialog-scroll')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('resumen mensual escala a muchas monedas y cuentas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(monthlySummary: _largeMonthlySummary()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TESORERÍA · CIERRE'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('treasury-range-monthly')));
    await tester.pumpAndSettle();

    final currencySelector = find.byKey(
      const Key('treasury-monthly-currency-selector'),
    );
    expect(currencySelector, findsOneWidget);
    expect(
      find.text('25 moneda(s) disponible(s) · escribe para buscar'),
      findsOneWidget,
    );
    expect(find.text('DESGLOSE POR CUENTA · M00'), findsOneWidget);

    await tester.tap(currencySelector);
    await tester.pumpAndSettle();
    final currencyInput = find.descendant(
      of: currencySelector,
      matching: find.byType(EditableText),
    );
    await tester.enterText(currencyInput, 'M17');
    await tester.pumpAndSettle();
    await tester.tap(find.text('M17 · 100 cuenta(s)').last);
    await tester.pumpAndSettle();

    expect(find.text('DESGLOSE POR CUENTA · M17'), findsOneWidget);
    expect(find.textContaining('100 de 100 cuenta(s)'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('treasury-monthly-account-search')),
      'Cuenta M17 099',
    );
    await tester.pumpAndSettle();
    expect(find.text('Cuenta M17 099'), findsWidgets);
    expect(find.textContaining('1 de 100 cuenta(s)'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('treasury-monthly-account-m17-account-099')),
    );
    await tester.pumpAndSettle();
    expect(find.text('DETALLE MENSUAL DE CUENTA'), findsOneWidget);
    expect(
      find.byKey(const Key('treasury-monthly-account-detail-scroll')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('exportación mensual filtra sin mezclar monedas ni cuentas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(monthlySummary: _largeMonthlySummary()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TESORERÍA · CIERRE'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('treasury-range-monthly')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('treasury-monthly-export')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('treasury-monthly-export-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('treasury-monthly-export-dialog-scroll')),
      findsOneWidget,
    );
    expect(find.text('Todas las cuentas'), findsOneWidget);
    expect(find.text('GUARDAR PDF'), findsOneWidget);
    expect(find.text('GUARDAR CSV'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('treasury-monthly-export-all-currencies')),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('sección independiente por moneda'),
      findsOneWidget,
    );
    final accountDropdown = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(const Key('treasury-monthly-export-account')),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    expect(accountDropdown.onChanged, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final entry in const {
    'compacto': Size(390, 844),
    'mediano': Size(760, 900),
    'escritorio': Size(1280, 900),
  }.entries) {
    testWidgets('consolidado mensual mantiene scroll interno ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      await tester.tap(find.text('TESORERÍA · CIERRE'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('treasury-range-monthly')));
      await tester.pumpAndSettle();

      expect(find.text('TESORERÍA · CONSOLIDADO MENSUAL'), findsOneWidget);
      expect(
        find.byKey(const Key('treasury-monthly-trend-scrollbar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('treasury-monthly-accounts-scrollbar')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('conecta cuotas, reglas y nómina desde las pestañas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('TESORERÍA · CIERRE'));
    await tester.pumpAndSettle();
    expect(find.text('TESORERÍA · LIBRO Y CIERRE DIARIO'), findsOneWidget);
    expect(find.text('Cuenta USD'), findsWidgets);
    expect(find.text('+ USD 500.00'), findsOneWidget);
    expect(
      find.byKey(const Key('treasury-accounts-scrollbar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('treasury-ledger-table-scrollbar')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('Caja USD por conciliar').first).dy,
      lessThan(tester.getTopLeft(find.text('Cuenta USD').first).dy),
    );
    await tester.tap(find.byKey(const Key('treasury-manual-operation-button')));
    await tester.pumpAndSettle();
    expect(find.text('Registrar movimiento'), findsOneWidget);
    expect(
      find.byKey(const Key('treasury-manual-dialog-scroll')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(LayoutBuilder),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CERRAR').first);
    await tester.pumpAndSettle();
    expect(find.text('Cerrar cuenta del día'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(LayoutBuilder),
      ),
      findsNothing,
    );
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();
    final reconcileButton = find.byKey(
      const ValueKey('treasury-reconcile-account-reconcile'),
    );
    await tester.ensureVisible(reconcileButton);
    await tester.tap(reconcileButton);
    await tester.pumpAndSettle();
    expect(find.text('Conciliar movimientos tardíos'), findsOneWidget);
    expect(
      find.byKey(const Key('treasury-reconciliation-dialog-scroll')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(LayoutBuilder),
      ),
      findsNothing,
    );
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('treasury-range-monthly')));
    await tester.pumpAndSettle();
    expect(find.text('TESORERÍA · CONSOLIDADO MENSUAL'), findsOneWidget);
    expect(find.text('CUP 1,895.00'), findsWidgets);
    expect(find.text('85.7%'), findsOneWidget);
    expect(find.text('Caja CUP demostrativa'), findsOneWidget);
    expect(
      find.byKey(const Key('treasury-monthly-trend-scrollbar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('treasury-monthly-accounts-scrollbar')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('CUOTAS ENTRENADORES'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Coach'), findsWidgets);
    expect(find.text('USD 100.00'), findsWidgets);
    expect(find.text('FIJO'), findsOneWidget);
    expect(
      find.byKey(const Key('trainer-payables-table-scrollbar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('trainer-liquidations-table-scrollbar')),
      findsOneWidget,
    );

    await tester.tap(find.text('TESORERÍA · REEMBOLSOS'));
    await tester.pumpAndSettle();
    expect(find.text('TESORERÍA · REEMBOLSOS'), findsWidgets);
    expect(find.text('Diego Cambio DEMO'), findsOneWidget);
    expect(find.text('USD 60.00'), findsWidgets);
    expect(
      find.byKey(const Key('treasury-refunds-table-scrollbar')),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('REGLAS DE COMISIÓN'));
    await tester.tap(find.text('REGLAS DE COMISIÓN'));
    await tester.pumpAndSettle();
    expect(find.text('Mensual'), findsOneWidget);
    expect(find.text('10.00%'), findsOneWidget);
    expect(find.text('VIGENTE'), findsOneWidget);
    expect(find.text('01/01/2026 → sin fin'), findsOneWidget);
    expect(find.textContaining('Excepción individual primero'), findsOneWidget);
    expect(find.text('NUEVA REGLA'), findsOneWidget);

    await tester.ensureVisible(find.text('PERFILES Y NÓMINA'));
    await tester.tap(find.text('PERFILES Y NÓMINA'));
    await tester.pumpAndSettle();
    expect(find.text('PERFILES DE COMPENSACIÓN'), findsOneWidget);
    expect(find.text('Ana Coach'), findsWidgets);
    expect(find.text('Comisión'), findsOneWidget);
    expect(find.text('Semanal · corte 5'), findsOneWidget);
    expect(find.text('VIGENTE'), findsOneWidget);
    expect(find.text('OBLIGACIONES FIJAS VENCIDAS'), findsOneWidget);
    expect(find.text('USD 125.00'), findsOneWidget);

    await tester.tap(find.text('NUEVO PERFIL'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo perfil'), findsOneWidget);
    expect(find.text('Frecuencia de desembolso'), findsOneWidget);
    expect(find.text('Cuenta preferida (opcional)'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(LayoutBuilder),
      ),
      findsNothing,
    );
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'arqueo fuera de tolerancia y aprobación conservan scroll interno',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      await tester.tap(find.text('TESORERÍA · CIERRE'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('treasury-close-policy-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('treasury-close-policy-dialog-scroll')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(LayoutBuilder),
        ),
        findsNothing,
      );
      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();

      final review = find.byKey(
        const ValueKey('treasury-review-account-pending'),
      );
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(find.text('Revisar diferencia de arqueo'), findsOneWidget);
      expect(
        find.byKey(const Key('treasury-close-approval-dialog-scroll')),
        findsOneWidget,
      );
      expect(find.text('APROBAR Y CERRAR', findRichText: true), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('CERRAR'),
        ),
      );
      await tester.pumpAndSettle();

      final closeButton = find.byKey(
        const ValueKey('treasury-close-account-usd'),
      );
      await tester.ensureVisible(closeButton);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Saldo contado (USD)'),
        '481',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('SOLICITAR APROBACIÓN', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('treasury-close-variance-reason')),
        findsOneWidget,
      );
      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rechaza porcentajes mayores de cien', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('REGLAS DE COMISIÓN'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar Mensual'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '120');
    await tester.tap(find.text('GUARDAR'));
    await tester.pump();

    expect(find.text('Ingrese un porcentaje entre 0 y 100.'), findsOneWidget);
    expect(find.text('Editar regla'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('combina comisión y fijo y abre la liquidación', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('CUOTAS ENTRENADORES'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.textContaining('1 concepto(s)'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    expect(find.textContaining('2 concepto(s)'), findsOneWidget);
    expect(
      find.textContaining('comisión 100.00 · fijo 125.00'),
      findsOneWidget,
    );
    await tester.tap(find.text('LIQUIDAR SELECCIÓN'));
    await tester.pumpAndSettle();

    expect(find.text('Liquidar entrenador'), findsOneWidget);
    expect(
      find.textContaining('Comisión 100.00 · fijo 125.00'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('trainer-liquidation-editor-scrollbar')),
      findsOneWidget,
    );
    expect(find.text('Cuenta USD · USD'), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.text('CONFIRMAR PAGO'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(LayoutBuilder),
      ),
      findsNothing,
    );
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

TreasuryMonthlySummaryModel _largeMonthlySummary({
  TreasuryMonthlyCloseStatusModel closeStatus =
      const TreasuryMonthlyCloseStatusModel(),
}) {
  final currencies = List.generate(25, (currencyIndex) {
    final suffix = currencyIndex.toString().padLeft(2, '0');
    final id = 'm$suffix';
    final code = 'M$suffix';
    final accountCount = currencyIndex == 17 ? 100 : 1;
    final accounts = List.generate(accountCount, (accountIndex) {
      final accountSuffix = accountIndex.toString().padLeft(3, '0');
      final requiresAttention = accountIndex % 10 == 0;
      return TreasuryMonthlyAccountModel(
        id: '$id-account-$accountSuffix',
        name: 'Cuenta $code $accountSuffix',
        currencyId: id,
        currencyCode: code,
        entries: 1000.0 + accountIndex,
        exits: 250.0 + accountIndex,
        net: 750,
        movementCount: 8,
        activityDays: 4,
        closedJourneys: requiresAttention ? 3 : 4,
        openJourneys: requiresAttention ? 1 : 0,
        closeCount: 4,
        reconciliationCount: 1,
        monthlyReconciledAdjustments: 5,
        reconciledMovementCount: 1,
        pendingLateMovementCount: requiresAttention ? 1 : 0,
        pendingReviewCount: 0,
        lastCloseDate: '2026-07-16',
        originalCloseBalance: 1200,
        currentAdjustments: 5,
        currentBalance: 1205,
        pendingCloseNet: requiresAttention ? 25 : 0,
        status: requiresAttention ? 'POR_CERRAR' : 'CONCILIADO',
      );
    });
    return TreasuryMonthlyCurrencyModel(
      currencyId: id,
      currencyCode: code,
      entries: accountCount * 1000,
      exits: accountCount * 250,
      net: accountCount * 750,
      movementCount: accountCount * 8,
      activeAccountCount: accountCount,
      activityJourneys: accountCount * 4,
      closedJourneys: accountCount * 4 - (currencyIndex == 17 ? 10 : 1),
      openJourneys: currencyIndex == 17 ? 10 : 1,
      closeCoverage: currencyIndex == 17 ? 97.5 : 75,
      closeCount: accountCount * 4,
      reconciliationCount: accountCount,
      monthlyReconciledAdjustments: accountCount * 5,
      reconciledMovementCount: accountCount,
      pendingLateMovementCount: currencyIndex == 17 ? 10 : 1,
      pendingReviewCount: 0,
      accountsWithoutClose: 0,
      originalCloseBalance: accountCount * 1200,
      currentAdjustments: accountCount * 5,
      currentBalance: accountCount * 1205,
      pendingCloseNet: currencyIndex == 17 ? 250 : 25,
      trend: const [
        TreasuryMonthlyTrendModel(
          businessDate: '2026-07-16',
          entries: 1000,
          exits: 250,
          net: 750,
          closeCount: 1,
          reconciledAdjustments: 5,
        ),
      ],
      accounts: accounts,
    );
  });
  return TreasuryMonthlySummaryModel(
    month: '2026-07',
    startDate: '2026-07-01',
    endDate: '2026-07-31',
    currencies: currencies,
    monthlyClose: closeStatus,
  );
}

OperationalResultsModel _operationalResults() {
  final currencies = List.generate(25, (currencyIndex) {
    final suffix = currencyIndex.toString().padLeft(2, '0');
    final id = currencyIndex == 0 ? 'cup' : 'm$suffix';
    final code = currencyIndex == 0 ? 'CUP' : 'M$suffix';
    final accounts = List.generate(100, (accountIndex) {
      final accountSuffix = accountIndex.toString().padLeft(3, '0');
      return OperationalAccountResultModel(
        id: '$id-account-$accountSuffix',
        name: 'Cuenta $code $accountSuffix',
        entries: '${1000 + accountIndex}.00',
        exits: '${250 + accountIndex}.00',
        ledgerNet: '750.00',
        operationalFlow: '725.00',
        movementCount: 8,
        requiresReview: accountIndex % 20 == 0,
      );
    });
    return OperationalResultsCurrencyModel(
      currencyId: id,
      currencyCode: code,
      cash: const OperationalCashModel(
        grossCollections: '3000.00',
        changeGivenNet: '50.00',
        reversalsNet: '100.00',
        trainerPaymentsNet: '500.00',
        refundsNet: '125.00',
        otherOperationalExits: '75.00',
        operationalFlow: '2150.00',
        nonOperationalFlow: '-20.00',
        pendingClassificationFlow: '10.00',
        ledgerEntries: '3040.00',
        ledgerExits: '900.00',
        ledgerNet: '2140.00',
      ),
      obligations: OperationalObligationsModel(
        available: true,
        trainerEarnedPending: '500.00',
        trainerPayableNow: '400.00',
        trainerFuture: '300.00',
        refundsPending: '125.00',
        immediateReserve: '625.00',
        totalCommitment: '925.00',
        cutoffDate: '2026-07-17',
        pendingTrainerCount: 1,
        overdueInstallmentCount: 2,
        pendingRefundCount: 1,
        reviewCount: 0,
        futureCoverage: 'Comisiones futuras cubiertas.',
        reason: 'La reserva no equivale a saldo libre de caja.',
        trainers: const [
          OperationalTrainerObligationModel(
            trainerId: 'trainer-demo',
            trainerName: 'Entrenadora Demo',
            earnedPending: '500.00',
            payableNow: '400.00',
            future: '300.00',
            conceptCount: 4,
            overdueConceptCount: 2,
            commissionConceptCount: 3,
            fixedConceptCount: 1,
            nextPaymentDate: '2026-07-18',
            requiresReview: false,
          ),
        ],
        refunds: const [
          OperationalPendingRefundModel(
            adjustmentId: 'refund-demo',
            clientId: 'CI-DEMO',
            clientName: 'Cliente Demo',
            amount: '125.00',
            requestedAt: null,
          ),
        ],
      ),
      concepts: const [
        OperationalConceptResultModel(
          category: 'COBROS_PLANES',
          label: 'Cobros de planes',
          scope: 'OPERATIVO',
          entries: '3000.00',
          exits: '0.00',
          cashEffect: '3000.00',
          movementCount: 12,
          requiresReview: false,
        ),
        OperationalConceptResultModel(
          category: 'PAGOS_ENTRENADORES',
          label: 'Pagos a entrenadores',
          scope: 'OPERATIVO',
          entries: '0.00',
          exits: '500.00',
          cashEffect: '-500.00',
          movementCount: 3,
          requiresReview: false,
        ),
        OperationalConceptResultModel(
          category: 'GASTOS_MANUALES',
          label: 'Gastos manuales',
          scope: 'OPERATIVO',
          entries: '0.00',
          exits: '75.00',
          cashEffect: '-75.00',
          movementCount: 1,
          requiresReview: true,
        ),
      ],
      accounts: accounts,
      quality: const OperationalQualityModel(
        movementsWithoutAccount: 0,
        pendingClassification: 1,
        openBusinessDays: 2,
        sourceReviews: 0,
      ),
    );
  });
  return OperationalResultsModel(
    month: '2026-07',
    periodState: 'REQUIERE_REVISION',
    nature: 'RESULTADO_OPERATIVO_DE_CAJA',
    certified: false,
    monthlyClose: null,
    certificationNote: 'El resultado es provisional.',
    currencies: currencies,
    limitations: const [
      'No representa utilidad ni ingreso devengado.',
      'No convierte ni suma monedas diferentes.',
    ],
  );
}

OperationalResultsModel _certifiedOperationalResults() {
  final result = _operationalResults();
  return OperationalResultsModel(
    month: result.month,
    periodState: 'CERTIFICADO',
    nature: result.nature,
    certified: true,
    monthlyClose: OperationalMonthlyCloseModel(
      id: 'close-r3',
      state: 'CERRADO',
      sha256: 'abc123',
      closedAt: DateTime.utc(2026, 8, 1, 14),
      reopenedAt: null,
      integrityVerified: true,
      snapshotVersion: 2,
      signerName: 'Administración Demo',
      signerRole: 'admin',
      reason: 'Resultado mensual revisado.',
      timezone: 'America/Havana',
    ),
    certificationNote: 'Resultado congelado y verificado.',
    currencies: result.currencies,
    limitations: result.limitations,
  );
}

OperationalAnnualResultsModel _annualResults() {
  final months = <Map<String, Object?>>[];
  for (var number = 1; number <= 12; number++) {
    final value = '2026-${number.toString().padLeft(2, '0')}';
    months.add({
      'mes': value,
      'estado': number == 1
          ? 'CERTIFICADO'
          : number <= 6
          ? 'SIN_CIERRE'
          : number == 7
          ? 'EN_CURSO'
          : 'FUTURO',
      'motivo': number == 1
          ? 'Cierre R3 íntegro.'
          : number <= 6
          ? 'El mes exigible no tiene cierre certificado.'
          : number == 7
          ? 'El mes comercial sigue en curso.'
          : 'El mes aún no ha comenzado.',
      'cierre_mensual_id': number == 1 ? 'close-jan' : null,
      'resumen_sha256': number == 1 ? 'abcdef1234567890' : null,
      'cerrado_at': number == 1 ? '2026-02-01T05:00:00.000Z' : null,
    });
  }
  return OperationalAnnualResultsModel.fromJson({
    'anio': '2026',
    'naturaleza': 'COMPARATIVA_ANUAL_RESULTADO_OPERATIVO_CERTIFICADO',
    'mes_comercial_actual': '2026-07',
    'cobertura': {
      'meses_exigibles': 6,
      'meses_certificados': 1,
      'meses_certificados_exigibles': 1,
      'meses_pendientes': 5,
      'porcentaje_exigible': 16.6667,
      'completa': false,
    },
    'meses': months,
    'monedas': [
      {
        'moneda_id': 'cup',
        'moneda_codigo': 'CUP',
        'meses_con_datos': 1,
        'totales_flujo': {
          'cobros_brutos': '9007199254740993.10',
          'salidas_libro': '100.00',
          'flujo_operativo': '9007199254740893.10',
          'pagos_entrenadores_netos': '40.00',
          'reembolsos_netos': '10.00',
          'otros_egresos_operativos': '50.00',
        },
        'ultimo_corte': {
          'mes': '2026-01',
          'reserva_inmediata': '125.25',
          'pagadero_ahora': '50.00',
          'fondo_futuro': '75.25',
          'devoluciones_pendientes': '5.00',
          'compromiso_total': '130.25',
        },
        'mayor_flujo': {'mes': '2026-01', 'monto': '9007199254740893.10'},
        'menor_flujo': {'mes': '2026-01', 'monto': '9007199254740893.10'},
        'meses': [
          {
            'mes': '2026-01',
            'cobros_brutos': '9007199254740993.10',
            'salidas_libro': '100.00',
            'flujo_operativo': '9007199254740893.10',
            'pagos_entrenadores_netos': '40.00',
            'reembolsos_netos': '10.00',
            'otros_egresos_operativos': '50.00',
            'reserva_inmediata': '125.25',
            'pagadero_ahora': '50.00',
            'fondo_futuro': '75.25',
            'devoluciones_pendientes': '5.00',
            'compromiso_total': '130.25',
          },
        ],
      },
    ],
    'nota_cobertura':
        'La comparación incluye 1 de 6 meses exigibles certificados.',
    'limitaciones': [
      'Los meses sin cierre no se interpretan como meses en cero.',
    ],
  });
}

ManagementMarginAnnualResultsModel _managementAnnualResults({
  String? blockedMonth,
}) {
  final months = <Map<String, Object?>>[];
  for (var number = 1; number <= 12; number++) {
    final value = '2026-${number.toString().padLeft(2, '0')}';
    final isBlocked = blockedMonth != null && value == blockedMonth;
    months.add({
      'mes': value,
      'estado': number == 1
          ? 'CERTIFICADO'
          : isBlocked
          ? 'BLOQUEO_INVALIDO'
          : number <= 6
          ? 'SIN_CIERRE'
          : number == 7
          ? 'EN_CURSO'
          : 'FUTURO',
      'motivo': number == 1
          ? 'Cierre R4.4 íntegro.'
          : isBlocked
          ? 'El cierre está CERRADO pero perdió su bloqueo activo.'
          : number <= 6
          ? 'El mes exigible no tiene cierre R4.4.'
          : number == 7
          ? 'El mes comercial sigue en curso.'
          : 'El mes aún no ha comenzado.',
      'cierre_mensual_id': number == 1
          ? 'close-jan-r44'
          : isBlocked
          ? 'close-blocked'
          : null,
      'resumen_sha256': number == 1
          ? 'abcdef1234567890'
          : isBlocked
          ? 'deadbeefdeadbeef'
          : null,
      'cerrado_at': (number == 1 || isBlocked)
          ? '2026-02-01T05:00:00.000Z'
          : null,
    });
  }
  return ManagementMarginAnnualResultsModel.fromJson({
    'anio': '2026',
    'naturaleza': 'COMPARATIVA_ANUAL_RESULTADO_DEVENGADO_CERTIFICADO',
    'mes_comercial_actual': '2026-07',
    'cobertura': {
      'meses_exigibles': 6,
      'meses_certificados': 1,
      'meses_certificados_exigibles': 1,
      'meses_pendientes': 5,
      'porcentaje_exigible': 16.6667,
      'completa': false,
    },
    'meses': months,
    'monedas': [
      {
        'moneda_id': 'cup',
        'moneda_codigo': 'CUP',
        'meses_con_datos': 1,
        'totales_devengo': {
          'ingreso_devengado': '1000.00',
          'costo_directo': '250.00',
          'margen_directo': '750.00',
          'fijo_no_distribuido': '100.00',
          'margen_menos_fijo': '650.00',
          'margen_directo_pct': '75.0',
        },
        'ultimo_corte': {
          'mes': '2026-01',
          'ingreso_devengado_acumulado': '1000.00',
          'costo_directo_acumulado': '250.00',
          'margen_directo_acumulado': '750.00',
          'fijo_no_distribuido_acumulado': '100.00',
          'margen_menos_fijo_acumulado': '650.00',
          'margen_directo_pct_acumulado': '75.0',
        },
        'mayor_margen': {'mes': '2026-01', 'monto': '750.00'},
        'menor_margen': {'mes': '2026-01', 'monto': '750.00'},
        'meses': [
          {
            'mes': '2026-01',
            'ingreso_devengado': '1000.00',
            'costo_directo': '250.00',
            'margen_directo': '750.00',
            'fijo_no_distribuido': '100.00',
            'margen_menos_fijo': '650.00',
            'margen_directo_pct': '75.0',
            'ingreso_devengado_acumulado': '1000.00',
            'costo_directo_acumulado': '250.00',
            'margen_directo_acumulado': '750.00',
            'fijo_no_distribuido_acumulado': '100.00',
            'margen_menos_fijo_acumulado': '650.00',
            'margen_directo_pct_acumulado': '75.0',
          },
        ],
      },
    ],
    'nota_cobertura':
        'La comparación usa solo meses con snapshot v3 certificado.',
    'limitaciones': ['No suma ni convierte monedas diferentes.'],
  });
}

MembershipRevenueModel _membershipRevenue() {
  return MembershipRevenueModel.fromJson({
    'mes': '2026-07',
    'naturaleza': 'INGRESO_DEVENGADO_MEMBRESIAS',
    'estado_periodo': 'PROVISIONAL',
    'fecha_corte': '2026-07-18',
    'cobertura': {
      'membresias_evaluadas': 18,
      'sin_evidencia_financiera': 0,
      'requieren_revision': 0,
      'completa': true,
    },
    'monedas': [
      {
        'moneda_id': 'cup',
        'moneda_codigo': 'CUP',
        'financiacion_mes': {
          'efectivo_aplicado': '12000.00',
          'credito_aplicado': '125.00',
          'total_aplicado': '12125.00',
        },
        'ingreso_devengado_mes': '9007199254740993.10',
        'ingreso_devengado_acumulado': '9007199254741993.10',
        'saldo_servicio_pendiente': '4500.00',
        'valor_no_consumido_reclasificado': '0.00',
        'ajuste_cancelacion_mes': '0.00',
        'membresias': List.generate(18, (index) {
          final suffix = index.toString().padLeft(2, '0');
          return {
            'membresia_id': 'membership-$suffix',
            'ci': 'CI-$suffix',
            'cliente_nombre': 'Cliente demostrativo $suffix',
            'plan_id': 'plan-quarterly',
            'plan_nombre': 'Plan trimestral con entrenador',
            'estado': 'ACTIVA',
            'origen': 'PAGO',
            'precio': '900.00',
            'financiado': '900.00',
            'devengado_mes': index == 0 ? '9007199254740993.10' : '100.00',
            'devengado_acumulado': '400.00',
            'pendiente_servicio': '500.00',
            'valor_no_consumido_reclasificado': '0.00',
            'ajuste_cancelacion_mes': '0.00',
            'dias_servicio_mes': 18,
            'dias_servicio_acumulados': 40,
            'dias_contratados': 90,
            'cobertura_estado': 'COMPLETA',
            'requiere_revision': false,
            'explicacion':
                'El servicio se reconoce por día efectivo y se detiene durante pausas.',
          };
        }),
      },
    ],
    'nota':
        'Este informe reconoce el servicio prestado; no representa utilidad.',
    'limitaciones': [
      'Los costos de entrenadores se mostrarán en una etapa posterior.',
    ],
  });
}

TrainerServiceCostModel _trainerServiceCost() {
  return TrainerServiceCostModel.fromJson({
    'mes': '2026-07',
    'naturaleza': 'COSTO_DEVENGADO_ENTRENADORES',
    'estado_periodo': 'PROVISIONAL',
    'fecha_corte': '2026-07-18',
    'cobertura': {
      'conceptos_evaluados': 18,
      'requieren_revision': 0,
      'conceptos_con_pausa': 2,
      'completa': true,
    },
    'monedas': [
      {
        'moneda_id': 'cup',
        'moneda_codigo': 'CUP',
        'costo_devengado_mes': '2481.43',
        'costo_devengado_acumulado': '8481.43',
        'pagado_mes_neto': '906.43',
        'pagado_acumulado': '906.43',
        'ganado_pendiente_pago': '7575.00',
        'costo_futuro_comprometido': '2145.00',
        'pago_anticipado': '0.00',
        'entrenadores': [
          {
            'entrenador_id': 'trainer-1',
            'entrenador_nombre': 'Ana Fuerza DEMO',
            'costo_devengado_mes': '2481.43',
            'costo_devengado_acumulado': '8481.43',
            'pagado_acumulado': '906.43',
            'ganado_pendiente_pago': '7575.00',
            'costo_futuro_comprometido': '2145.00',
            'conceptos': 18,
            'clientes': 17,
            'planes': 2,
            'requiere_revision': false,
          },
        ],
        'costos': List.generate(18, (index) {
          final suffix = index.toString().padLeft(2, '0');
          final fixed = index == 1;
          return {
            'costo_id': 'cost-$suffix',
            'grupo_id': fixed ? 'fixed-$suffix' : 'accrual-$suffix',
            'fuente': fixed ? 'FIJO' : 'COMISION',
            'entrenador_id': 'trainer-1',
            'entrenador_nombre': 'Ana Fuerza DEMO',
            'membresia_id': fixed ? null : 'membership-$suffix',
            'ci': fixed ? null : 'CI-$suffix',
            'cliente_nombre': fixed ? null : 'Cliente demostrativo $suffix',
            'plan_id': fixed ? null : 'plan-quarterly',
            'plan_nombre': fixed ? null : 'Plan trimestral con entrenador',
            'metodo_devengo': index.isEven
                ? 'DIAS_SERVICIO'
                : 'PERIODOS_IGUALES',
            'estado': 'PENDIENTE',
            'periodo_inicio': '2026-07-01',
            'periodo_fin': '2026-08-01',
            'fecha_programada': '2026-08-01',
            'costo_total': '300.00',
            'costo_devengado_mes': '180.00',
            'costo_devengado_acumulado': '180.00',
            'pagado_mes_neto': index == 0 ? '40.00' : '0.00',
            'pagado_acumulado': index == 0 ? '40.00' : '0.00',
            'ganado_pendiente_pago': index == 0 ? '140.00' : '180.00',
            'costo_futuro_comprometido': '120.00',
            'pago_anticipado': '0.00',
            'dias_servicio_mes': 18,
            'dias_servicio_acumulados': 18,
            'dias_contratados': 31,
            'atribucion': fixed ? 'FIJO_NO_DISTRIBUIDO' : 'MEMBRESIA',
            'requiere_revision': false,
            'explicacion': fixed
                ? 'Es compensación fija y no se reparte entre socios.'
                : 'La comisión conserva el plan y el socio del cobro.',
          };
        }),
      },
    ],
    'nota':
        'Separa el costo que el entrenador ya ganó, lo pagado y el compromiso futuro.',
    'limitaciones': [
      'La compensación fija no se distribuye artificialmente entre socios.',
    ],
  });
}

ManagementMarginModel _managementMargin({bool certified = false}) {
  final json = <String, dynamic>{
    'mes': '2026-07',
    'naturaleza': 'MARGEN_GERENCIAL',
    'estado_periodo': certified ? 'CERTIFICADO' : 'PROVISIONAL',
    'certificado': certified,
    'nota_certificacion': certified
        ? 'Resultado devengado congelado dentro del snapshot firmado.'
        : 'El resultado devengado es una proyección viva.',
    if (certified)
      'cierre_tesoreria': {
        'cierre_mensual_id': 'close-r44',
        'estado': 'CERRADO',
        'resumen_sha256': 'abc123',
        'integridad_verificada': true,
        'snapshot_version': 3,
        'cerrado_at': '2026-08-01T00:00:00.000Z',
        'firmado_por_nombre': 'Administración',
        'firmado_por_rol': 'admin',
        'motivo': 'Cierre mensual R4.4 de prueba.',
        'timezone': 'America/Havana',
        'generado_at_utc': '2026-08-01T00:00:00.000Z',
      },
    'fecha_corte': '2026-07-18',
    'cobertura': {
      'membresias_evaluadas': 18,
      'conceptos_costo_evaluados': 18,
      'requieren_revision': 0,
      'membresias_compartidas': 1,
      'membresias_sin_entrenador': 1,
      'conceptos_costo_sin_ingreso': 0,
      'completa': true,
    },
    'monedas': [
      {
        'moneda_id': 'cup',
        'moneda_codigo': 'CUP',
        'ingreso_devengado_mes': '9950.05',
        'ingreso_devengado_acumulado': '9950.05',
        'costo_directo_mes': '2481.43',
        'costo_directo_acumulado': '2481.43',
        'margen_directo_mes': '7468.62',
        'margen_directo_acumulado': '7468.62',
        'margen_directo_pct_acumulado': '75.1',
        'fijo_no_distribuido_mes': '300.00',
        'fijo_no_distribuido_acumulado': '300.00',
        'margen_menos_fijo_mes': '7168.62',
        'margen_menos_fijo_acumulado': '7168.62',
        'planes': List.generate(18, (index) {
          final suffix = index.toString().padLeft(2, '0');
          return {
            'plan_id': 'plan-$suffix',
            'plan_nombre': 'Plan demostrativo $suffix',
            'membresias': 1,
            'clientes': 1,
            'ingreso_devengado_mes': '552.78',
            'ingreso_devengado_acumulado': '552.78',
            'costo_directo_mes': '137.86',
            'costo_directo_acumulado': '137.86',
            'margen_directo_mes': '414.92',
            'margen_directo_acumulado': '414.92',
            'margen_directo_pct_acumulado': '75.1',
            'requiere_revision': false,
          };
        }),
        'entrenadores': [
          {
            'entrenador_id': 'trainer-1',
            'entrenador_nombre': 'Ana Fuerza DEMO',
            'membresias_vinculadas': 16,
            'membresias_compartidas': 1,
            'clientes': 16,
            'planes': 2,
            'ingreso_devengado_mes': '8600.05',
            'ingreso_devengado_acumulado': '8600.05',
            'costo_directo_mes': '2331.43',
            'costo_directo_acumulado': '2331.43',
            'margen_directo_mes': '6268.62',
            'margen_directo_acumulado': '6268.62',
            'margen_directo_pct_acumulado': '72.9',
            'fijo_no_distribuido_mes': '300.00',
            'fijo_no_distribuido_acumulado': '300.00',
            'costo_compartido_acumulado': '150.00',
            'costo_sin_ingreso_acumulado': '0.00',
            'atribucion_completa': false,
            'requiere_revision': false,
          },
        ],
        'clientes': [
          {
            'ci': 'CI-00',
            'cliente_nombre': 'Cliente demostrativo 00',
            'membresias': 1,
            'planes': 1,
            'ingreso_devengado_mes': '552.78',
            'ingreso_devengado_acumulado': '552.78',
            'costo_directo_mes': '137.86',
            'costo_directo_acumulado': '137.86',
            'margen_directo_mes': '414.92',
            'margen_directo_acumulado': '414.92',
            'margen_directo_pct_acumulado': '75.1',
            'requiere_revision': false,
          },
          {
            'ci': 'CI-01',
            'cliente_nombre': 'Cliente deficitario 01',
            'membresias': 1,
            'planes': 1,
            'ingreso_devengado_mes': '100.00',
            'ingreso_devengado_acumulado': '100.00',
            'costo_directo_mes': '150.00',
            'costo_directo_acumulado': '150.00',
            'margen_directo_mes': '-50.00',
            'margen_directo_acumulado': '-50.00',
            'margen_directo_pct_acumulado': '-50.0',
            'requiere_revision': false,
          },
        ],
        'atribucion': {
          'membresias_compartidas': 1,
          'ingreso_compartido_mes': '800.00',
          'ingreso_compartido_acumulado': '800.00',
          'costo_compartido_mes': '150.00',
          'costo_compartido_acumulado': '150.00',
          'membresias_sin_entrenador': 1,
          'ingreso_sin_entrenador_mes': '550.00',
          'ingreso_sin_entrenador_acumulado': '550.00',
          'conceptos_costo_sin_ingreso': 0,
          'costo_sin_ingreso_mes': '0.00',
          'costo_sin_ingreso_acumulado': '0.00',
          'costo_sin_plan': true,
          'costo_sin_socio': true,
        },
      },
    ],
    'nota':
        'Resta del servicio ya prestado el costo directo de comisión que ese servicio generó.',
    'limitaciones': [
      'La compensación fija se muestra separada como FIJO_NO_DISTRIBUIDO.',
    ],
  };
  return ManagementMarginModel.fromJson(json);
}

Widget _harness({
  TreasuryMonthlySummaryModel? monthlySummary,
  OperationalResultsModel? operationalResults,
  OperationalAnnualResultsModel? annualResults,
  ManagementMarginAnnualResultsModel? managementAnnualResults,
  MembershipRevenueModel? membershipRevenue,
  Object? membershipRevenueError,
  TrainerServiceCostModel? trainerServiceCost,
  ManagementMarginModel? managementMargin,
}) {
  final summary = AccountingSummaryModel(
    pendingTrainerAmount: 300,
    pendingTrainerCount: 2,
    overdueTrainerCount: 1,
    paidTrainerCount: 5,
    activeRuleCount: 1,
    defaultRuleCount: 1,
    individualRuleCount: 0,
    fixedPayrollProfiles: 0,
    fixedPayrollPending: 0,
  );
  final installments = [
    TrainerCommissionInstallmentModel(
      id: 'i1',
      trainerId: 't1',
      trainerName: 'Ana Coach',
      currencyId: 'usd',
      currencyCode: 'USD',
      amount: 100,
      status: 'PENDIENTE',
      payable: true,
      scheduledDate: DateTime.utc(2026, 7, 10),
      periodStart: DateTime.utc(2026, 7, 1),
      periodEnd: DateTime.utc(2026, 7, 15),
    ),
    TrainerCommissionInstallmentModel(
      id: 'i2',
      trainerId: 't2',
      trainerName: 'Luis Coach',
      currencyId: 'pyg',
      currencyCode: 'PYG',
      amount: 200,
      status: 'PENDIENTE',
      payable: true,
      scheduledDate: DateTime.utc(2026, 7, 12),
      periodStart: DateTime.utc(2026, 7, 1),
      periodEnd: DateTime.utc(2026, 7, 15),
    ),
  ];
  final payables = [
    TrainerPayableModel(
      id: 'i1',
      sourceType: 'COMISION',
      trainerId: 't1',
      trainerName: 'Ana Coach',
      currencyId: 'usd',
      currencyCode: 'USD',
      amount: 100,
      appliedAmount: 0,
      remainingAmount: 100,
      status: 'PENDIENTE',
      payable: true,
      scheduledDate: DateTime.utc(2026, 7, 10),
      periodStart: DateTime.utc(2026, 7, 1),
      periodEnd: DateTime.utc(2026, 7, 15),
    ),
    TrainerPayableModel(
      id: 'fixed-1',
      sourceType: 'FIJO',
      trainerId: 't1',
      trainerName: 'Ana Coach',
      currencyId: 'usd',
      currencyCode: 'USD',
      amount: 125,
      appliedAmount: 0,
      remainingAmount: 125,
      status: 'PENDIENTE',
      payable: true,
      scheduledDate: DateTime.utc(2026, 7, 10),
      periodStart: DateTime.utc(2026, 7, 1),
      periodEnd: DateTime.utc(2026, 7, 15),
    ),
    TrainerPayableModel(
      id: 'i2',
      sourceType: 'COMISION',
      trainerId: 't2',
      trainerName: 'Luis Coach',
      currencyId: 'pyg',
      currencyCode: 'PYG',
      amount: 200,
      appliedAmount: 0,
      remainingAmount: 200,
      status: 'PENDIENTE',
      payable: true,
      scheduledDate: DateTime.utc(2026, 7, 12),
      periodStart: DateTime.utc(2026, 7, 1),
      periodEnd: DateTime.utc(2026, 7, 15),
    ),
  ];
  final rules = [
    TrainerCommissionRuleModel(
      id: 'r1',
      trainerId: null,
      planId: 'p1',
      type: 'PERCENTAGE',
      value: 10,
      active: true,
      startDate: DateTime.utc(2026, 1, 1),
      endDate: null,
      planName: 'Mensual',
      trainerName: 'Regla general del plan',
    ),
  ];
  final plans = [
    PaymentPlanModel(
      id: 'p1',
      nombre: 'Mensual',
      importe: 50,
      duracion: 30,
      monedaId: 'USD',
      incluyeEntrenador: true,
    ),
  ];
  final trainers = [
    TrainerModel(
      id: 't1',
      ci: 'T1',
      nombres: 'Ana',
      apellidos: 'Coach',
      activo: true,
      fechaInicio: DateTime.utc(2025),
    ),
  ];
  final profiles = [
    TrainerCompensationProfileModel(
      id: 'cp1',
      trainerId: 't1',
      trainerName: 'Ana Coach',
      trainerActive: true,
      modality: 'COMISION',
      earningMethod: 'DIAS_SERVICIO',
      payoutFrequency: 'SEMANAL',
      cutoffDay: 5,
      fixedAmount: null,
      currencyId: null,
      currencyCode: null,
      preferredAccountId: 'account-usd',
      preferredAccountName: 'Cuenta USD',
      startDate: DateTime.utc(2026, 1, 1),
      endDate: null,
      notes: 'Perfil de demostración',
      validityStatus: 'VIGENTE',
      hasConflict: false,
    ),
  ];
  final fixedObligations = [
    TrainerFixedObligationModel(
      id: 'fixed-1',
      profileId: 'cp1',
      trainerId: 't1',
      trainerName: 'Ana Coach',
      currencyId: 'usd',
      currencyCode: 'USD',
      amount: 125,
      status: 'PENDIENTE',
      prorationMethod: 'DIAS_SERVICIO',
      coveredDays: 5,
      periodDays: 7,
      periodStart: DateTime.utc(2026, 7, 1),
      periodEnd: DateTime.utc(2026, 7, 6),
      scheduledDate: DateTime.utc(2026, 7, 6),
    ),
  ];
  final refunds = [
    TreasuryRefundModel(
      adjustmentId: 'refund-adjustment-1',
      caseId: 'case-1',
      refundId: null,
      receiptNumber: null,
      status: 'PENDIENTE',
      lastReceiptStatus: null,
      clientId: 'DEMO-001',
      clientName: 'Diego Cambio DEMO',
      planName: 'Plan trimestral',
      membershipId: 'membership-1',
      currencyId: 'usd',
      currencyCode: 'USD',
      amount: 60,
      effectiveDate: DateTime.utc(2026, 7, 15),
      requestedAt: DateTime.utc(2026, 7, 15, 16),
      requestedBy: 'Administración',
      requestReason: 'Baja del entrenador asignado',
      accountId: null,
      paymentTypeId: null,
      treasuryReason: null,
      resolvedAt: null,
      resolvedBy: null,
    ),
  ];
  final treasuryLedger = TreasuryLedgerModel(
    businessDate: '2026-07-15',
    currencySummaries: const [
      TreasuryCurrencySummaryModel(
        currencyId: 'usd',
        currencyCode: 'USD',
        entries: 500,
        exits: 125,
        net: 375,
        movementCount: 2,
      ),
    ],
    accounts: [
      const TreasuryAccountDayModel(
        id: 'account-usd',
        name: 'Cuenta USD',
        currencyId: 'usd',
        currencyCode: 'USD',
        entries: 500,
        exits: 125,
        net: 375,
        movementCount: 2,
        reviewCount: 0,
        suggestedOpeningBalance: 100,
        status: 'ABIERTO',
        lateMovementCount: 0,
        close: null,
      ),
      TreasuryAccountDayModel(
        id: 'account-pending',
        name: 'Caja USD por aprobar',
        currencyId: 'usd',
        currencyCode: 'USD',
        entries: 300,
        exits: 25,
        net: 275,
        movementCount: 3,
        reviewCount: 0,
        suggestedOpeningBalance: 100,
        status: 'PENDIENTE_APROBACION',
        lateMovementCount: 0,
        close: null,
        pendingApproval: TreasuryCloseRequestModel(
          id: 'request-pending',
          businessDate: '2026-07-15',
          accountId: 'account-pending',
          currencyId: 'usd',
          openingBalance: 100,
          entries: 300,
          exits: 25,
          expectedBalance: 375,
          countedBalance: 360,
          difference: -15,
          appliedTolerance: 5,
          movementCount: 3,
          reason: 'Faltante pendiente de verificar con recepción.',
          status: 'PENDIENTE',
          requesterId: 'cashier-user',
          requesterName: 'Recepción Demo',
          requesterRole: 'reception',
          requestedAt: DateTime.utc(2026, 7, 15, 23, 10),
        ),
      ),
      TreasuryAccountDayModel(
        id: 'account-closed',
        name: 'Caja USD cerrada',
        currencyId: 'usd',
        currencyCode: 'USD',
        entries: 0,
        exits: 0,
        net: 0,
        movementCount: 0,
        reviewCount: 0,
        suggestedOpeningBalance: 475,
        status: 'CERRADO',
        lateMovementCount: 0,
        close: TreasuryCloseModel(
          id: 'close-1',
          operationId: 'operation-close-1',
          receiptNumber: 'CIE-20260715-DEMO',
          businessDate: '2026-07-15',
          accountId: 'account-closed',
          currencyId: 'usd',
          openingBalance: 475,
          entries: 0,
          exits: 0,
          expectedBalance: 475,
          countedBalance: 475,
          difference: 0,
          movementCount: 0,
          movementsThrough: null,
          operatorName: 'Operador',
          closedAt: DateTime.utc(2026, 7, 15, 23),
        ),
      ),
      TreasuryAccountDayModel(
        id: 'account-reconcile',
        name: 'Caja USD por conciliar',
        currencyId: 'usd',
        currencyCode: 'USD',
        entries: 25,
        exits: 0,
        net: 25,
        movementCount: 1,
        reviewCount: 0,
        suggestedOpeningBalance: 475,
        status: 'REQUIERE_CONCILIACION',
        lateMovementCount: 1,
        adjustedBalance: 475,
        close: TreasuryCloseModel(
          id: 'close-reconcile',
          operationId: 'operation-close-reconcile',
          receiptNumber: 'CIE-20260715-LATE',
          businessDate: '2026-07-15',
          accountId: 'account-reconcile',
          currencyId: 'usd',
          openingBalance: 475,
          entries: 0,
          exits: 0,
          expectedBalance: 475,
          countedBalance: 475,
          difference: 0,
          movementCount: 0,
          movementsThrough: null,
          operatorName: 'Operador',
          closedAt: DateTime.utc(2026, 7, 15, 22),
        ),
      ),
    ],
    movements: [
      TreasuryMovementModel(
        id: 'movement-1',
        sourceType: 'PAGO_CLIENTE',
        sourceId: 'payment-1',
        direction: 'ENTRADA',
        concept: 'PLAN_CLIENTE',
        accountId: 'account-usd',
        accountName: 'Cuenta USD',
        currencyId: 'usd',
        currencyCode: 'USD',
        paymentTypeId: 'cash',
        paymentTypeName: 'Efectivo',
        amount: 500,
        occurredAt: DateTime.utc(2026, 7, 15, 14),
        description: 'Cobro del plan',
        counterMovementId: null,
        requiresReview: false,
        reviewReason: null,
        late: false,
      ),
      TreasuryMovementModel(
        id: 'movement-late',
        sourceType: 'PAGO_CLIENTE',
        sourceId: 'payment-late',
        direction: 'ENTRADA',
        concept: 'PLAN_CLIENTE',
        accountId: 'account-reconcile',
        accountName: 'Caja USD por conciliar',
        currencyId: 'usd',
        currencyCode: 'USD',
        paymentTypeId: 'cash',
        paymentTypeName: 'Efectivo',
        amount: 25,
        occurredAt: DateTime.utc(2026, 7, 15, 23),
        description: 'Cobro sincronizado después del cierre',
        counterMovementId: null,
        requiresReview: false,
        reviewReason: null,
        late: true,
      ),
      TreasuryMovementModel(
        id: 'movement-2',
        sourceType: 'LIQUIDACION_ENTRENADOR',
        sourceId: 'settlement-1',
        direction: 'SALIDA',
        concept: 'PAGO_ENTRENADOR',
        accountId: 'account-usd',
        accountName: 'Cuenta USD',
        currencyId: 'usd',
        currencyCode: 'USD',
        paymentTypeId: 'cash',
        paymentTypeName: 'Efectivo',
        amount: 125,
        occurredAt: DateTime.utc(2026, 7, 15, 18),
        description: 'Pago al entrenador',
        counterMovementId: null,
        requiresReview: false,
        reviewReason: null,
        late: false,
      ),
    ],
    incidents: const TreasuryIncidentsModel(
      withoutAccount: 0,
      requiringReview: 0,
      lateMovements: 0,
    ),
    closePolicy: const TreasuryClosePolicyModel(
      defaultTolerance: 2,
      currencyTolerances: {'usd': 5},
      submitterRoles: ['admin', 'accounting', 'reception'],
      approverRoles: ['admin', 'accounting'],
    ),
    closeCapabilities: const TreasuryCloseCapabilitiesModel(
      canSubmit: true,
      canApprove: true,
      userId: 'admin-user',
      role: 'admin',
    ),
  );
  const treasuryMonthly = TreasuryMonthlySummaryModel(
    month: '2026-07',
    startDate: '2026-07-01',
    endDate: '2026-07-31',
    currencies: [
      TreasuryMonthlyCurrencyModel(
        currencyId: 'cup',
        currencyCode: 'CUP',
        entries: 3200,
        exits: 1588.43,
        net: 1611.57,
        movementCount: 18,
        activeAccountCount: 2,
        activityJourneys: 7,
        closedJourneys: 6,
        openJourneys: 1,
        closeCoverage: 85.7,
        closeCount: 6,
        reconciliationCount: 1,
        monthlyReconciledAdjustments: 170,
        reconciledMovementCount: 2,
        pendingLateMovementCount: 1,
        pendingReviewCount: 0,
        accountsWithoutClose: 0,
        originalCloseBalance: 1895,
        currentAdjustments: 170,
        currentBalance: 2065,
        pendingCloseNet: -42,
        trend: [
          TreasuryMonthlyTrendModel(
            businessDate: '2026-07-15',
            entries: 900,
            exits: 175,
            net: 725,
            closeCount: 1,
            reconciledAdjustments: 0,
          ),
          TreasuryMonthlyTrendModel(
            businessDate: '2026-07-16',
            entries: 1760,
            exits: 237,
            net: 1523,
            closeCount: 1,
            reconciledAdjustments: 170,
          ),
        ],
        accounts: [
          TreasuryMonthlyAccountModel(
            id: 'demo-cup',
            name: 'Caja CUP demostrativa',
            currencyId: 'cup',
            currencyCode: 'CUP',
            entries: 1760,
            exits: 237,
            net: 1523,
            movementCount: 7,
            activityDays: 2,
            closedJourneys: 1,
            openJourneys: 1,
            closeCount: 1,
            reconciliationCount: 1,
            monthlyReconciledAdjustments: 170,
            reconciledMovementCount: 2,
            pendingLateMovementCount: 1,
            pendingReviewCount: 0,
            lastCloseDate: '2026-07-16',
            originalCloseBalance: 1895,
            currentAdjustments: 170,
            currentBalance: 2065,
            pendingCloseNet: -42,
            status: 'POR_CERRAR',
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
      syncStatusProvider.overrideWith(
        (ref) => Stream.value(
          SyncStatusSnapshot.offline(
            detail: 'Sin cambios pendientes',
            source: 'test',
          ),
        ),
      ),
      accountingSummaryProvider.overrideWith((ref) async => summary),
      trainerCommissionInstallmentsProvider.overrideWith(
        (ref) async => installments,
      ),
      trainerPayablesProvider.overrideWith((ref) async => payables),
      trainerCommissionRulesProvider.overrideWith((ref) async => rules),
      trainerLiquidationsProvider.overrideWith(
        (ref) async => [
          TrainerLiquidationModel(
            id: 'liq-1',
            receiptNumber: 'LQ-0001',
            trainerId: 't1',
            trainerName: 'Ana Coach',
            currencyId: 'usd',
            currencyCode: 'USD',
            accountId: 'account-usd',
            accountName: 'Cuenta USD',
            paymentTypeId: 'cash',
            paymentTypeName: 'Efectivo',
            total: 225,
            commissionTotal: 100,
            fixedTotal: 125,
            commissionConcepts: 1,
            fixedConcepts: 1,
            status: 'PAGADA',
            operatorName: 'Operador',
            paidAt: DateTime.utc(2026, 7, 14, 16),
          ),
        ],
      ),
      trainerCompensationProfilesProvider.overrideWith((ref) async => profiles),
      trainerFixedObligationsProvider.overrideWith(
        (ref) async => fixedObligations,
      ),
      treasuryRefundsProvider.overrideWith((ref) async => refunds),
      treasuryRefundOptionsProvider.overrideWith(
        (ref) async => const TreasuryRefundOptionsModel(
          accounts: [
            TrainerPayoutAccountModel(
              id: 'account-usd',
              name: 'Cuenta USD',
              currencyId: 'usd',
              currencyCode: 'USD',
              paymentTypeId: 'cash',
            ),
          ],
          methods: [TrainerPayoutMethodModel(id: 'cash', name: 'Efectivo')],
        ),
      ),
      treasuryManualOptionsProvider.overrideWith(
        (ref) async => const TreasuryRefundOptionsModel(
          accounts: [
            TrainerPayoutAccountModel(
              id: 'account-usd',
              name: 'Cuenta USD',
              currencyId: 'usd',
              currencyCode: 'USD',
              paymentTypeId: 'cash',
            ),
          ],
          methods: [TrainerPayoutMethodModel(id: 'cash', name: 'Efectivo')],
        ),
      ),
      treasuryLedgerProvider.overrideWith((ref, _) async => treasuryLedger),
      treasuryMonthlySummaryProvider.overrideWith(
        (ref, _) async => monthlySummary ?? treasuryMonthly,
      ),
      operationalResultsProvider.overrideWith(
        (ref, _) async => operationalResults ?? _operationalResults(),
      ),
      operationalAnnualResultsProvider.overrideWith(
        (ref, _) async => annualResults ?? _annualResults(),
      ),
      managementMarginAnnualResultsProvider.overrideWith(
        (ref, _) async => managementAnnualResults ?? _managementAnnualResults(),
      ),
      membershipRevenueProvider.overrideWith((ref, _) async {
        if (membershipRevenueError != null) throw membershipRevenueError;
        return membershipRevenue ?? _membershipRevenue();
      }),
      trainerServiceCostProvider.overrideWith(
        (ref, _) async => trainerServiceCost ?? _trainerServiceCost(),
      ),
      managementMarginProvider.overrideWith(
        (ref, _) async => managementMargin ?? _managementMargin(),
      ),
      trainerPayoutOptionsProvider.overrideWith(
        (ref) async => const TrainerPayoutOptionsModel(
          accounts: [
            TrainerPayoutAccountModel(
              id: 'account-usd',
              name: 'Cuenta USD',
              currencyId: 'usd',
              currencyCode: 'USD',
              paymentTypeId: 'cash',
            ),
          ],
          methods: [TrainerPayoutMethodModel(id: 'cash', name: 'Efectivo')],
        ),
      ),
      paymentPlanProvider.overrideWith(() => _PlanNotifier(plans)),
      trainerProvider.overrideWith(() => _TrainerNotifier(trainers)),
    ],
    child: const MaterialApp(home: Scaffold(body: AccountingView())),
  );
}

class _PlanNotifier extends PaymentPlanNotifier {
  _PlanNotifier(this.items);
  final List<PaymentPlanModel> items;

  @override
  Future<List<PaymentPlanModel>> build() async => items;
}

class _TrainerNotifier extends TrainerNotifier {
  _TrainerNotifier(this.items);
  final List<TrainerModel> items;

  @override
  Future<List<TrainerModel>> build() async => items;
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
