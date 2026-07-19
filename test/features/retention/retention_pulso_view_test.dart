import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/retention/data/models/retention_models.dart';
import 'package:gym_client/src/features/retention/presentation/screens/retention_pulso_view.dart';
import 'package:gym_client/src/features/retention/presentation/state/retention_providers.dart';

void main() {
  testWidgets('muestra la cola explicada en escritorio', (tester) async {
    await _pump(tester, const Size(1280, 900));

    expect(find.text('CONTROL Y\nCALIDAD.'), findsOneWidget);
    expect(find.text('Sonia Salida'), findsOneWidget);
    expect(find.text('Carlos Hoy'), findsOneWidget);
    expect(find.textContaining('5 días de gracia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('se adapta a una ventana compacta sin desbordar', (tester) async {
    await _pump(tester, const Size(500, 800));

    expect(find.text('CONTROL Y\nCALIDAD.'), findsOneWidget);
    expect(find.text('Sonia Salida'), findsOneWidget);
    expect(find.textContaining('No renovó durante la gracia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('redistribuye la cola en ancho mediano', (tester) async {
    await _pump(tester, const Size(760, 840));

    expect(find.text('Sonia Salida'), findsOneWidget);
    expect(find.text('Carlos Hoy'), findsOneWidget);
    expect(find.textContaining('cohorte consolidada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'abre gestión e historial sin mezclarlo con el estado financiero',
    (tester) async {
      await _pump(tester, const Size(1280, 900));

      await tester.tap(find.byTooltip('Registrar gestión').first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('retention-management-dialog')),
        findsOneWidget,
      );
      expect(find.text('RETENCIÓN · GESTIÓN OPERATIVA'), findsOneWidget);
      expect(find.text('Historial de contactos'.toUpperCase()), findsOneWidget);
      expect(
        find.textContaining('no cambia por sí sola el pago'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('el formulario de gestión conserva aire en ancho compacto', (
    tester,
  ) async {
    await _pump(tester, const Size(500, 800));

    final manage = find.text('GESTIONAR').first;
    await tester.drag(
      find.byKey(const PageStorageKey('retention-queue')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(manage);
    await tester.tap(manage);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('retention-management-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('retention-result-field')),
      findsOneWidget,
    );
    expect(find.text('REGISTRAR GESTIÓN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('presenta cohortes, dimensiones y emisión del informe', (
    tester,
  ) async {
    await _pump(
      tester,
      const Size(1280, 900),
      dashboard: _dashboard(includeAnalytics: true),
    );

    expect(find.text('COMPARACIÓN POR COHORTES'), findsOneWidget);
    expect(find.byKey(const ValueKey('retention-plan-filter')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('retention-trainer-filter')),
      findsOneWidget,
    );
    await tester.tap(find.text('COMPARAR'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('retention-breakdown-dialog')),
      findsOneWidget,
    );
    expect(find.text('LUPA COMPARATIVA.'), findsOneWidget);
    expect(find.text('POR PLAN'), findsOneWidget);
    expect(find.text('POR ENTRENADOR'), findsOneWidget);
    expect(find.text('Ana Coach'), findsWidgets);
    expect(find.text('MUESTRA BAJA'), findsWidgets);
    await tester.tap(find.text('CERRAR'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('EXPORTAR'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('retention-export-dialog')),
      findsOneWidget,
    );
    expect(find.text('GUARDAR PDF'), findsOneWidget);
    expect(find.text('GUARDAR CSV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'resume el alcance y abre filtros sin saturar el ancho compacto',
    (tester) async {
      await _pump(
        tester,
        const Size(500, 800),
        dashboard: _dashboard(includeAnalytics: true),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Cambiar filtros'));
      await tester.pumpAndSettle();

      expect(find.text('ALCANCE DEL ANÁLISIS'), findsWidgets);
      expect(find.text('APLICAR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('apila la lupa comparativa en una ventana compacta', (
    tester,
  ) async {
    await _pump(
      tester,
      const Size(500, 800),
      dashboard: _dashboard(includeAnalytics: true),
    );

    await tester.tap(find.byTooltip('Comparar planes y entrenadores'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('retention-breakdown-dialog')),
      findsOneWidget,
    );
    expect(find.text('POR PLAN'), findsOneWidget);
    expect(find.textContaining('1 caso(s) sin entrenador'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  RetentionDashboardModel? dashboard,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
        retentionDashboardProvider.overrideWith(
          (ref) async => dashboard ?? _dashboard(),
        ),
        retentionManagementHistoryProvider.overrideWith(
          (ref, membershipId) async => const [],
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: RetentionPulsoView())),
    ),
  );
  await tester.pumpAndSettle();
}

RetentionDashboardModel _dashboard({bool includeAnalytics = false}) =>
    RetentionDashboardModel.fromJson({
      'generated_at_utc': '2026-07-13T06:00:00.000Z',
      'gym_id': 'gym-1',
      'timezone': 'America/Havana',
      'business_date': '2026-07-12',
      'window': {'from': '2026-06-12', 'to': '2026-07-19'},
      'policy': {
        'grace_days': 5,
        'horizon_days': 7,
        'mature_cohort_cutoff': '2026-07-07',
        'provisional': true,
      },
      'metrics': {
        'total_visible': 2,
        'by_state': {
          'PROXIMO': 0,
          'VENCE_HOY': 1,
          'EN_GRACIA': 0,
          'SALIDA': 1,
          'RECUPERADO': 0,
          'RENOVADO_PUNTUAL': 0,
          'RENOVADO_EN_GRACIA': 0,
        },
        'mature_eligible': 1,
        'retained': 0,
        'retention_rate_pct': 0,
        'historical_exits': 1,
        'recovered': 0,
        'recovery_rate_pct': 0,
      },
      'quality': {'missing_activation_evidence': 0, 'caveats': <String>[]},
      if (includeAnalytics) ...{
        'dimensions': {
          'plans': [
            {'id': 'p-1', 'name': 'Mensual', 'count': 1},
            {'id': 'p-2', 'name': 'Trimestral', 'count': 1},
          ],
          'trainers': [
            {'id': 't-1', 'name': 'Ana Coach', 'count': 1},
          ],
        },
        'cohorts': [
          {
            'month': '2026-06',
            'total_due': 1,
            'mature_eligible': 1,
            'retained': 1,
            'historical_exits': 0,
            'recovered': 0,
            'retention_rate_pct': 100,
            'recovery_rate_pct': null,
            'retention_change_pp': null,
            'provisional': false,
          },
          {
            'month': '2026-07',
            'total_due': 2,
            'mature_eligible': 1,
            'retained': 0,
            'historical_exits': 1,
            'recovered': 0,
            'retention_rate_pct': 0,
            'recovery_rate_pct': 0,
            'retention_change_pp': -100,
            'provisional': true,
          },
        ],
        'breakdowns': {
          'plans': [
            {
              'id': 'p-1',
              'name': 'Mensual',
              'total_due': 1,
              'mature_eligible': 1,
              'open_cases': 0,
              'retained': 0,
              'renewed_on_time': 0,
              'renewed_in_grace': 0,
              'historical_exits': 1,
              'recovered': 0,
              'retention_rate_pct': 0,
              'recovery_rate_pct': 0,
            },
            {
              'id': 'p-2',
              'name': 'Trimestral',
              'total_due': 1,
              'mature_eligible': 0,
              'open_cases': 1,
              'retained': 0,
              'renewed_on_time': 0,
              'renewed_in_grace': 0,
              'historical_exits': 0,
              'recovered': 0,
              'retention_rate_pct': null,
              'recovery_rate_pct': null,
            },
          ],
          'trainers': [
            {
              'id': 't-1',
              'name': 'Ana Coach',
              'total_due': 1,
              'mature_eligible': 1,
              'open_cases': 0,
              'retained': 0,
              'renewed_on_time': 0,
              'renewed_in_grace': 0,
              'historical_exits': 1,
              'recovered': 0,
              'retention_rate_pct': 0,
              'recovery_rate_pct': 0,
            },
          ],
          'unattributed_trainer_total': 1,
        },
      },
      'items': [
        _item(
          id: 'm-1',
          ci: '0001',
          name: 'Sonia Salida',
          state: 'SALIDA',
          due: '2026-07-06',
          days: 6,
          reason:
              'No renovó durante la gracia; causa salida desde el 12/07/2026.',
        ),
        _item(
          id: 'm-2',
          ci: '0002',
          name: 'Carlos Hoy',
          state: 'VENCE_HOY',
          due: '2026-07-12',
          days: 0,
          reason: 'La renovación corresponde al día de hoy.',
        ),
      ],
    });

Map<String, dynamic> _item({
  required String id,
  required String ci,
  required String name,
  required String state,
  required String due,
  required int days,
  required String reason,
}) => {
  'membership_id': id,
  'ci': ci,
  'client_name': name,
  'phone': '555$ci',
  'email': null,
  'plan': {'id': 'p-1', 'name': 'Mensual', 'price': 3000, 'currency_id': 'CUP'},
  'trainer': null,
  'expected_renewal_date': due,
  'grace_end_date': '2026-07-11',
  'exit_date': '2026-07-12',
  'state': state,
  'reason': reason,
  'days_from_due': days,
  'historical_exit': state == 'SALIDA',
  'renewal': null,
  'last_payment_at_utc': '2026-07-05T15:30:00.000Z',
  'last_attendance_at_utc': '2026-07-06T14:00:00.000Z',
  'reconstructed': false,
};

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
