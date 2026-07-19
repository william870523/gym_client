import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/retention/data/models/retention_models.dart';
import 'package:gym_client/src/features/retention/data/services/retention_report_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la consulta serializa el alcance esperado por la API', () {
    const query = RetentionDashboardQuery(
      from: '2026-01-01',
      to: '2026-07-13',
      planId: 'plan-1',
      trainerId: 'trainer-1',
    );

    expect(query.toQueryParameters(), {
      'desde': '2026-01-01',
      'hasta': '2026-07-13',
      'plan_id': 'plan-1',
      'entrenador_id': 'trainer-1',
    });
  });

  test('el CSV conserva alcance, auditoría UTC y caracteres especiales', () {
    final snapshot = _snapshot();
    final bytes = RetentionReportExportService().buildCsv(snapshot);

    expect(bytes.take(3), [0xef, 0xbb, 0xbf]);
    final csv = utf8.decode(bytes.sublist(3));
    expect(csv, contains('"America/Havana"'));
    expect(csv, contains('"Plan: Mensual · Entrenador: Ana Coach"'));
    expect(csv, contains('"Sonia ""La Fuerte"", Pérez"'));
    expect(csv, contains('"2026-07-05T15:30:00.000Z"'));
    expect(csv, contains('"2026-07-06T14:00:00.000Z"'));
    expect(csv, contains('"plan_casos_maduros"'));
    expect(csv, contains('"entrenador_retencion_pct"'));
    expect(csv, contains('"2","1","50.00","1","1","100.00"'));
    expect(snapshot.generatedAt, '13/07/2026 02:00');
    expect(snapshot.visibleTotal, 1);
  });

  test('el PDF se genera con cohortes y cola filtrada', () async {
    final bytes = await RetentionReportExportService().buildPdf(_snapshot());

    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(5000));
  });
}

RetentionReportSnapshot _snapshot() {
  final dashboard = RetentionDashboardModel.fromJson({
    'generated_at_utc': '2026-07-13T06:00:00.000Z',
    'gym_id': 'gym-1',
    'timezone': 'America/Havana',
    'business_date': '2026-07-13',
    'window': {'from': '2026-01-01', 'to': '2026-07-13'},
    'policy': {
      'grace_days': 5,
      'horizon_days': 7,
      'mature_cohort_cutoff': '2026-07-08',
      'provisional': true,
    },
    'metrics': {
      'total_visible': 2,
      'by_state': {'SALIDA': 1, 'RECUPERADO': 1},
      'mature_eligible': 2,
      'retained': 1,
      'retention_rate_pct': 50,
      'historical_exits': 1,
      'recovered': 1,
      'recovery_rate_pct': 100,
      'management': {'pending': 0, 'promised': 1, 'due_followups': 1},
    },
    'quality': {'missing_activation_evidence': 0, 'caveats': <String>[]},
    'dimensions': {
      'plans': [
        {'id': 'plan-1', 'name': 'Mensual', 'count': 2},
      ],
      'trainers': [
        {'id': 'trainer-1', 'name': 'Ana Coach', 'count': 1},
      ],
    },
    'cohorts': [
      {
        'month': '2026-06',
        'total_due': 2,
        'mature_eligible': 2,
        'retained': 1,
        'historical_exits': 1,
        'recovered': 1,
        'retention_rate_pct': 50,
        'recovery_rate_pct': 100,
        'retention_change_pp': 10,
        'provisional': false,
      },
    ],
    'breakdowns': {
      'plans': [
        {
          'id': 'plan-1',
          'name': 'Mensual',
          'total_due': 2,
          'mature_eligible': 2,
          'open_cases': 0,
          'retained': 1,
          'renewed_on_time': 1,
          'renewed_in_grace': 0,
          'historical_exits': 1,
          'recovered': 1,
          'retention_rate_pct': 50,
          'recovery_rate_pct': 100,
        },
      ],
      'trainers': [
        {
          'id': 'trainer-1',
          'name': 'Ana Coach',
          'total_due': 1,
          'mature_eligible': 1,
          'open_cases': 0,
          'retained': 1,
          'renewed_on_time': 1,
          'renewed_in_grace': 0,
          'historical_exits': 0,
          'recovered': 0,
          'retention_rate_pct': 100,
          'recovery_rate_pct': null,
        },
      ],
      'unattributed_trainer_total': 1,
    },
    'items': [
      {
        'membership_id': 'membership-1',
        'ci': '90123123456',
        'client_name': 'Sonia "La Fuerte", Pérez',
        'phone': '555-0101',
        'email': null,
        'plan': {
          'id': 'plan-1',
          'name': 'Mensual',
          'price': 3000,
          'currency_id': 'CUP',
        },
        'trainer': {'id': 'trainer-1', 'name': 'Ana Coach'},
        'expected_renewal_date': '2026-07-06',
        'grace_end_date': '2026-07-11',
        'exit_date': '2026-07-12',
        'state': 'SALIDA',
        'reason': 'No renovó durante la gracia.',
        'days_from_due': 7,
        'historical_exit': true,
        'renewal': null,
        'last_payment_at_utc': '2026-07-05T15:30:00.000Z',
        'last_attendance_at_utc': '2026-07-06T14:00:00.000Z',
        'management': {
          'status': 'PROMESA_PAGO',
          'channel': 'TELEFONO',
          'note': 'Llamar mañana',
          'promise_date': '2026-07-14',
          'next_management_date': '2026-07-14',
          'registered_at_utc': '2026-07-13T06:10:00.000Z',
          'registered_by': 'admin',
          'history_count': 2,
          'overdue': false,
        },
        'reconstructed': false,
      },
    ],
  });

  return RetentionReportSnapshot.fromDashboard(
    dashboard: dashboard,
    visibleItems: [dashboard.items.single],
    scope: 'Plan: Mensual · Entrenador: Ana Coach',
  );
}
