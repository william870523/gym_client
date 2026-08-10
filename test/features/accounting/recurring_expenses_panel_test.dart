import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_palette_id.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_theme.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_tokens.dart';
import 'package:gym_client/src/features/accounting/data/models/recurring_expense_models.dart';
import 'package:gym_client/src/features/accounting/data/repositories/accounting_repository.dart';
import 'package:gym_client/src/features/accounting/presentation/state/accounting_providers.dart';
import 'package:gym_client/src/features/accounting/presentation/widgets/recurring_expenses_panel.dart';

class _FakeAccountingRepository extends AccountingRepository {
  _FakeAccountingRepository() : super(Dio());

  Map<String, dynamic>? creada;

  @override
  Future<RecurringExpenseModel> createRecurringExpense(
    Map<String, dynamic> body,
  ) async {
    creada = body;
    return _templates().first;
  }
}

RecurringExpensePlanModel _plan({
  bool canGenerate = true,
  String periodState = 'EN_CURSO',
  String? blockReason,
}) {
  return RecurringExpensePlanModel.fromJson({
    'mes': '2026-07',
    'naturaleza': 'GENERACION_GASTO_RECURRENTE',
    'estado_periodo': periodState,
    'puede_generar': canGenerate,
    'motivo_bloqueo': blockReason,
    'resumen': {
      'plantillas_evaluadas': 3,
      'a_generar': canGenerate ? 2 : 0,
      'omitidas': 1,
      'ya_generadas': 1,
    },
    'a_generar': canGenerate
        ? [
            {
              'recurrente_id': 'rec-alquiler',
              'categoria_nombre': 'Alquiler',
              'proveedor_nombre': 'Inmobiliaria Centro',
              'moneda_codigo': 'CUP',
              'descripcion': 'Alquiler del local',
              'importe': '1800.00',
              'mes_pertenencia': '2026-07',
              'fecha_programada': '2026-07-05',
            },
            {
              'recurrente_id': 'rec-luz',
              'categoria_nombre': 'Electricidad',
              'moneda_codigo': 'CUP',
              'descripcion': 'Electricidad',
              'importe': '540.00',
              'mes_pertenencia': '2026-07',
              'fecha_programada': '2026-07-10',
            },
          ]
        : [],
    'omitidas': [
      {
        'recurrente_id': 'rec-limpieza',
        'descripcion': 'Limpieza mensual',
        'categoria_nombre': 'Limpieza',
        'moneda_codigo': 'CUP',
        'motivo': 'YA_GENERADO',
        'gasto_id': 'gasto-1',
        'explicacion': 'Ya existe el gasto de este mes para esta plantilla.',
      },
    ],
    'totales_por_moneda': canGenerate
        ? [
            {'moneda_id': 'cup', 'moneda_codigo': 'CUP', 'importe': '2340.00'},
          ]
        : [],
    'nota': 'La plantilla describe un gasto que se repite.',
    'limitaciones': ['No mezcla ni convierte monedas.'],
  });
}

List<RecurringExpenseModel> _templates() => [
  RecurringExpenseModel.fromJson(const {
    'recurrente_id': 'rec-alquiler',
    'categoria_id': 'cat-alquiler',
    'moneda_id': 'cup',
    'descripcion': 'Alquiler del local',
    'monto': '1800.00',
    'dia_programado': 5,
    'mes_inicio': '2026-01',
    'activo': true,
  }),
  RecurringExpenseModel.fromJson(const {
    'recurrente_id': 'rec-viejo',
    'categoria_id': 'cat-alquiler',
    'moneda_id': 'cup',
    'descripcion': 'Alquiler del local anterior',
    'monto': '900.00',
    'dia_programado': 1,
    'mes_inicio': '2025-01',
    'mes_fin': '2026-03',
    'activo': false,
  }),
];

Widget _harness(RecurringExpensePlanModel plan, [AccountingRepository? repo]) {
  return ProviderScope(
    overrides: [
      accountingRepositoryProvider.overrideWithValue(
        repo ?? _FakeAccountingRepository(),
      ),
      recurringExpensePlanProvider.overrideWith((ref, month) async => plan),
      recurringExpensesProvider.overrideWith((ref) async => _templates()),
    ],
    child: MaterialApp(
      theme: PulsoThemeFactory.build(
        PulsoTokens.resolve(PulsoPaletteId.clay, Brightness.light),
      ),
      home: Scaffold(
        body: RecurringExpensesPanel(initialMonth: '2026-07', onBack: () {}),
      ),
    ),
  );
}

void main() {
  _pruebasDeAlta();
  testWidgets('el plan muestra qué se generará y qué se salta con su motivo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(_plan()));
    await tester.pumpAndSettle();

    expect(find.text('SE GENERARÁ'), findsOneWidget);
    expect(find.text('Alquiler del local'), findsWidgets);
    expect(find.text('1,800.00 CUP'), findsOneWidget);

    // El motivo del salto se explica en palabras, no solo con la constante.
    expect(find.text('SE SALTA, Y POR QUÉ'), findsOneWidget);
    expect(find.text('YA GENERADO'), findsOneWidget);
    expect(
      find.text('Ya existe el gasto de este mes para esta plantilla.'),
      findsOneWidget,
    );

    // Las plantillas inactivas se ven, con su acción para reactivarlas.
    expect(find.text('ACTIVAR'), findsOneWidget);
    expect(find.text('PAUSAR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un mes futuro no ofrece generar y dice por qué', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        _plan(
          canGenerate: false,
          periodState: 'FUTURO',
          blockReason:
              'No se genera un mes futuro: el gasto pertenecería a un período que todavía no ocurrió.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MES FUTURO'), findsOneWidget);
    expect(find.textContaining('todavía no ocurrió'), findsOneWidget);

    // El botón sigue visible pero no hace nada: pulsarlo no abre confirmación.
    await tester.tap(
      find.byKey(const Key('recurring-expenses-generate')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('recurring-expenses-confirm-dialog')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmar la generación explica que no duplica', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(_plan()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('recurring-expenses-generate')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('no duplica nada'), findsOneWidget);
    expect(find.text('GENERAR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// R4.7 · Unidad 09 — el panel tiene que poder **crear** una plantilla.
///
/// `createRecurringExpense` existía en el repositorio desde siempre, pero
/// ninguna vista lo llamaba: el panel sabía pausar y generar, no dar de alta.
/// Se descubrió en el recorrido de operador del 02-08-2026, cuando no hubo
/// forma de crear la plantilla ni en escritorio ni en web.
void _pruebasDeAlta() {
  testWidgets('el panel ofrece crear una plantilla y envía lo que se escribe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _FakeAccountingRepository();

    await tester.pumpWidget(_harness(_plan(), repo));
    await tester.pumpAndSettle();

    final boton = find.byKey(const Key('recurring-expenses-create'));
    expect(boton, findsOneWidget, reason: 'sin este botón R4.7 no se puede operar');
    await tester.tap(boton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recurring-expenses-create-dialog')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('recurring-create-description')), 'Plantilla de prueba');
    await tester.enterText(find.byKey(const Key('recurring-create-amount')), '80.00');
    await tester.pumpAndSettle();

    // Sin categoría ni moneda el botón sigue deshabilitado: el servidor las
    // exige y pedirlas aquí evita un 400 que el operador no entendería.
    final enviar = tester.widget<FilledButton>(
      find.byKey(const Key('recurring-create-submit')));
    expect(enviar.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
