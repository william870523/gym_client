import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/core/widgets/pulso_charts.dart';
import 'package:gym_client/src/features/clients/presentation/state/clients_scope_filter_provider.dart';
import 'package:gym_client/src/features/dashboard/presentation/state/dashboard_nav_provider.dart';
import 'package:gym_client/src/features/statistics/data/models/statistics_cohorts.dart';
import 'package:gym_client/src/features/statistics/presentation/screens/statistics_cohorts_pulso_view.dart';
import 'package:gym_client/src/features/statistics/presentation/state/statistics_providers.dart';

Map<String, dynamic> _cohortes({
  bool disponible = true,
  bool horizonteAbierto = false,
  int sinAlta = 0,
}) => {
  'zona': 'America/Los_Angeles',
  'dia_negocio': '2026-07-31',
  'periodo': {'dias': 365, 'desde': '2025-08-01', 'hasta': '2026-07-31'},
  'granularidad': 'mes',
  'horizontes': [30, 60, 90],
  'definicion':
      'Cohorte de alta: los socios se agrupan por el día en que entraron.',
  'disponible': disponible,
  'motivo': disponible
      ? null
      : 'Las cohortes necesitan el motor canónico de retención y esta '
            'instalación no lo tiene conectado.',
  'politica': disponible
      ? {'diasGracia': 5, 'corteMadurez': '2026-07-25'}
      : null,
  'cohortes': disponible
      ? [
          {
            'clave': '2026-02',
            'etiqueta': 'feb 2026',
            'inicio': '2026-02-01',
            'fin': '2026-02-28',
            'altas': 24,
            'horizontes': [
              {
                'dias': 30,
                'maduras': 24,
                'retenidas': 22,
                'bajas': 2,
                'abiertas': 0,
                'tasaPct': 91.67,
                'muestraBaja': false,
              },
              {
                'dias': 60,
                'maduras': 24,
                'retenidas': 20,
                'bajas': 4,
                'abiertas': 0,
                'tasaPct': 83.33,
                'muestraBaja': false,
              },
              {
                'dias': 90,
                'maduras': horizonteAbierto ? 0 : 24,
                'retenidas': horizonteAbierto ? 0 : 19,
                'bajas': horizonteAbierto ? 0 : 5,
                'abiertas': horizonteAbierto ? 24 : 0,
                'tasaPct': horizonteAbierto ? null : 79.17,
                'muestraBaja': false,
              },
            ],
            'primeraRenovacion': {
              'socios': 20,
              'base': 24,
              'medianaDias': 30,
            },
            'tiempoHastaBaja': {'socios': 5, 'base': 24, 'medianaDias': 68},
          },
          {
            'clave': '2026-03',
            'etiqueta': 'mar 2026',
            'inicio': '2026-03-01',
            'fin': '2026-03-31',
            'altas': 3,
            'horizontes': [
              {
                'dias': 30,
                'maduras': 3,
                'retenidas': 3,
                'bajas': 0,
                'abiertas': 0,
                'tasaPct': 100,
                'muestraBaja': true,
              },
              {
                'dias': 60,
                'maduras': 3,
                'retenidas': 2,
                'bajas': 1,
                'abiertas': 0,
                'tasaPct': 66.67,
                'muestraBaja': true,
              },
              {
                'dias': 90,
                'maduras': 3,
                'retenidas': 2,
                'bajas': 1,
                'abiertas': 0,
                'tasaPct': 66.67,
                'muestraBaja': true,
              },
            ],
            'primeraRenovacion': {'socios': 0, 'base': 3, 'medianaDias': null},
            'tiempoHastaBaja': {'socios': 1, 'base': 3, 'medianaDias': 45},
          },
        ]
      : const [],
  'totales': disponible
      ? {
          'altas': 27,
          'horizontes': [
            {
              'dias': 30,
              'maduras': 27,
              'retenidas': 25,
              'bajas': 2,
              'abiertas': 0,
              'tasaPct': 92.59,
              'muestraBaja': false,
            },
            {
              'dias': 60,
              'maduras': 27,
              'retenidas': 22,
              'bajas': 5,
              'abiertas': 0,
              'tasaPct': 81.48,
              'muestraBaja': false,
            },
            {
              'dias': 90,
              'maduras': horizonteAbierto ? 0 : 27,
              'retenidas': horizonteAbierto ? 0 : 21,
              'bajas': horizonteAbierto ? 0 : 6,
              'abiertas': horizonteAbierto ? 27 : 0,
              'tasaPct': horizonteAbierto ? null : 77.78,
              'muestraBaja': false,
            },
          ],
        }
      : null,
  'cobertura': disponible
      ? {'altasEnPeriodo': 27, 'sociosSinAltaIdentificable': sinAlta}
      : null,
  'advertencias': disponible ? ['aviso del motor'] : const [],
};

Map<String, dynamic> _demanda({bool conDiscrepancia = true, bool vacio = false}) => {
  'zona': 'America/Los_Angeles',
  'dia_negocio': '2026-07-31',
  'periodo': {'dias': 365, 'desde': '2025-08-01', 'hasta': '2026-07-31'},
  'medida': 'demanda observada',
  'definicion':
      'Entradas registradas, agrupadas por día de la semana y hora local de la '
      'sede. Es demanda observada, no ocupación.',
  'resumen': {
    'visitas': vacio ? 0 : 2262,
    'socios': vacio ? 0 : 101,
    'visitasPorSocio': vacio ? null : 22.4,
    'mediaDiaria': vacio ? 0 : 25.13,
  },
  'mapa': {
    'dias': [
      {'diaSemana': 1, 'etiqueta': 'Lunes', 'corto': 'LUN'},
      {'diaSemana': 2, 'etiqueta': 'Martes', 'corto': 'MAR'},
      {'diaSemana': 3, 'etiqueta': 'Miércoles', 'corto': 'MIÉ'},
      {'diaSemana': 4, 'etiqueta': 'Jueves', 'corto': 'JUE'},
      {'diaSemana': 5, 'etiqueta': 'Viernes', 'corto': 'VIE'},
      {'diaSemana': 6, 'etiqueta': 'Sábado', 'corto': 'SÁB'},
      {'diaSemana': 0, 'etiqueta': 'Domingo', 'corto': 'DOM'},
    ],
    'horaDesde': vacio ? null : 6,
    'horaHasta': vacio ? null : 7,
    'filas': vacio
        ? const []
        : [
            {
              'hora': 6,
              'etiqueta': '06:00',
              'celdas': [
                for (final v in [50, 86, 87, 94, 56, 71, 0])
                  {'diaSemana': 1, 'visitas': v, 'socios': v},
              ],
            },
            {
              'hora': 7,
              'etiqueta': '07:00',
              'celdas': [
                for (final v in [106, 62, 68, 71, 84, 69, 2])
                  {'diaSemana': 1, 'visitas': v, 'socios': v},
              ],
            },
          ],
  },
  'picos': vacio
      ? const []
      : [
          {
            'diaSemana': 1,
            'dia': 'Lunes',
            'hora': 7,
            'etiquetaHora': '07:00',
            'visitas': 106,
            'socios': 32,
            'participacionPct': 4.69,
          },
        ],
  'porDiaSemana': const [],
  'porFranjaObservada': vacio
      ? const []
      : [
          {'franja': 'Mañana', 'visitas': 906, 'participacionPct': 40.05},
          {'franja': 'Tarde', 'visitas': 737, 'participacionPct': 32.58},
        ],
  'porFranjaDeclarada': vacio
      ? const []
      : [
          {'franja': 'Mañana', 'socios': 43, 'participacionPct': 41.35},
          {'franja': 'Tarde', 'socios': 32, 'participacionPct': 30.77},
        ],
  'declaradaVsObservada': {
    'comparables': vacio ? 0 : 98,
    'coinciden': vacio ? 0 : 97,
    'coincidenciaPct': vacio ? null : 98.98,
    'sinDeclarar': 3,
    'sinVisitas': 6,
    'discrepan': conDiscrepancia && !vacio
        ? [
            {
              'ci': '99073100101',
              'nombre': 'Rosa Madrugadora',
              'declarada': 'Mañana',
              'horarioNombre': 'Turno mañana',
              'observada': 'Noche',
              'visitas': 11,
            },
          ]
        : const [],
    'discrepanTotal': conDiscrepancia && !vacio ? 1 : 0,
  },
  'calidad': {'sinInstante': 0, 'abiertas': 0, 'truncado': false},
  'advertencias': [
    'Demanda observada, no ocupación: falta el aforo por sede o franja para '
        'poder hablar de porcentaje (§5.2).',
  ],
};

Map<String, dynamic> _calidad({bool bajasEvaluadas = true}) => {
  'zona': 'America/Los_Angeles',
  'dia_negocio': '2026-07-31',
  'periodo': {
    'dias': 365,
    'desde': '2025-08-01',
    'hasta': '2026-07-31',
    'aplicaA': 'bajas',
  },
  'controles': [
    {
      'id': 'bajas-sin-gestion',
      'familia': 'bajas',
      'titulo': 'Bajas que nadie gestionó',
      'detalle': '21 de 21 salidas no tienen ninguna gestión registrada.',
      'regla': 'Cobertura: aviso por debajo del 95 %.',
      'afectados': 21,
      'base': 21,
      'coberturaPct': 0,
      'severidad': 'peligro',
      'destino': {'tipo': 'retencion'},
    },
    {
      'id': 'socios-referencia',
      'familia': 'socios',
      'titulo': 'Socios sin canal de captación',
      'detalle': '3 socios sin referencia.',
      'regla': 'Cobertura: aviso por debajo del 95 %.',
      'afectados': 3,
      'base': 107,
      'coberturaPct': 97.2,
      'severidad': 'ok',
      'destino': {
        'tipo': 'clientes',
        'atributo': 'referencia',
        'valor': 'SIN DATO',
      },
    },
    {
      'id': 'socios-sexo-vocabulario',
      'familia': 'socios',
      'titulo': 'El sexo escrito de varias formas',
      'detalle': 'Vocabulario correcto: Femenino, Masculino.',
      'regla': 'Incoherencia estructural: cualquier caso es peligro.',
      'afectados': 0,
      'base': 2,
      'coberturaPct': null,
      'severidad': 'ok',
      'destino': null,
    },
  ],
  'resumen': {'total': 3, 'peligro': 1, 'aviso': 0, 'ok': 2},
  'bases': {
    'padron': 107,
    'membresias': 586,
    'asistencias': 3194,
    'cobros': 596,
    'bajas': 21,
  },
  'bajas': {
    'evaluada': bajasEvaluadas,
    'motivo': bajasEvaluadas
        ? null
        : 'La familia «bajas» necesita el motor canónico de retención y esta '
              'instalación no lo tiene conectado.',
    'total': bajasEvaluadas ? 21 : 0,
    'corteMadurez': bajasEvaluadas ? '2026-07-25' : null,
  },
  'advertencias': const [
    'La calidad no corrige nada: enseña el hueco y lleva al flujo donde se '
        'resuelve.',
  ],
};

ProviderContainer _contenedor({
  Map<String, dynamic>? cohortes,
  Map<String, dynamic>? demanda,
  Map<String, dynamic>? calidad,
}) => ProviderContainer(
  overrides: [
    appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
    cohortsProvider.overrideWith(
      (ref, query) async => CohortsReport.fromJson(cohortes ?? _cohortes()),
    ),
    demandProvider.overrideWith(
      (ref, days) async => DemandReport.fromJson(demanda ?? _demanda()),
    ),
    dataQualityProvider.overrideWith(
      (ref, days) async => QualityReport.fromJson(calidad ?? _calidad()),
    ),
  ],
);

Future<void> _montar(WidgetTester tester, ProviderContainer container) async {
  tester.view.physicalSize = const Size(1280, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: StatisticsCohortsPulsoView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la cohorte enseña su tasa con el denominador al lado', (
    tester,
  ) async {
    final container = _contenedor();
    addTearDown(container.dispose);
    await _montar(tester, container);

    expect(find.text('Cohortes de alta'), findsOneWidget);
    expect(find.byKey(const ValueKey('cohorte-2026-02')), findsOneWidget);
    // La tasa nunca viaja sola: 22 de 24 está a la vista (regla 7).
    expect(find.textContaining('22/24'), findsOneWidget);
    expect(find.text('91.7 %'), findsOneWidget);
    // Y el total del período, con su denominador propio.
    expect(find.textContaining('Retención a 30 días · 25 de 27'), findsOneWidget);
  });

  testWidgets('un horizonte que aún no cerró se declara en curso, no en cero', (
    tester,
  ) async {
    final container = _contenedor(cohortes: _cohortes(horizonteAbierto: true));
    addTearDown(container.dispose);
    await _montar(tester, container);

    expect(find.textContaining('en curso (24)'), findsOneWidget);
    expect(
      find.textContaining('Retención a 90 días · sin cohortes maduras'),
      findsOneWidget,
    );
    // Lo que no puede aparecer es un 0 % que se lea como «se fueron todos».
    expect(find.text('0.0 %'), findsNothing);
  });

  testWidgets('marca la muestra baja y el corte de madurez del motor', (
    tester,
  ) async {
    final container = _contenedor();
    addTearDown(container.dispose);
    await _montar(tester, container);

    expect(find.text('muestra baja'), findsWidgets);
    expect(
      find.textContaining('Corte de madurez 2026-07-25'),
      findsOneWidget,
    );
  });

  testWidgets('sin motor canónico no dibuja una cohorte inventada', (
    tester,
  ) async {
    final container = _contenedor(cohortes: _cohortes(disponible: false));
    addTearDown(container.dispose);
    await _montar(tester, container);

    expect(
      find.textContaining('necesitan el motor canónico de retención'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('cohorte-2026-02')), findsNothing);
  });

  testWidgets('el mapa habla de demanda observada y nunca de ocupación', (
    tester,
  ) async {
    final container = _contenedor();
    addTearDown(container.dispose);
    await _montar(tester, container);

    expect(find.byKey(const ValueKey('demanda-medida')), findsOneWidget);
    expect(find.text('DEMANDA OBSERVADA'), findsOneWidget);
    expect(find.byKey(const ValueKey('demanda-mapa')), findsOneWidget);
    expect(find.byType(PulsoMapaCalor), findsOneWidget);
    expect(find.textContaining('ocupación'), findsWidgets);
    // Y lo que no puede haber es un porcentaje de ocupación.
    expect(find.textContaining('% de ocupación'), findsNothing);
    expect(find.textContaining('Lunes 07:00 · 106 visitas'), findsOneWidget);
  });

  testWidgets('separa franja declarada de observada sin mezclar unidades', (
    tester,
  ) async {
    final container = _contenedor();
    addTearDown(container.dispose);
    await _montar(tester, container);

    // Una cuenta socios, la otra visitas, y cada rótulo lo dice.
    expect(find.text('DECLARADA · SOCIOS'), findsOneWidget);
    expect(find.text('OBSERVADA · VISITAS'), findsOneWidget);
    expect(
      find.textContaining('97 de 98 socios vienen en la franja que declararon'),
      findsOneWidget,
    );
  });

  testWidgets('la discrepancia declarada/observada abre el perfil del socio', (
    tester,
  ) async {
    final container = _contenedor();
    addTearDown(container.dispose);
    await _montar(tester, container);

    final fila = find.byKey(const ValueKey('discrepancia-99073100101'));
    expect(fila, findsOneWidget);
    expect(find.textContaining('dice Mañana · viene Noche'), findsOneWidget);

    await tester.tap(fila);
    await tester.pump();
    expect(container.read(selectedMemberProvider), '99073100101');
    expect(container.read(dashboardNavProvider), 31);
  });

  testWidgets('sin discrepancias lo dice en vez de dejar el hueco en blanco', (
    tester,
  ) async {
    final container = _contenedor(demanda: _demanda(conDiscrepancia: false));
    addTearDown(container.dispose);
    await _montar(tester, container);

    expect(
      find.byKey(const ValueKey('demanda-sin-discrepancias')),
      findsOneWidget,
    );
  });

  testWidgets('un período sin entradas deja el mapa vacío y explicado', (
    tester,
  ) async {
    final container = _contenedor(demanda: _demanda(vacio: true));
    addTearDown(container.dispose);
    await _montar(tester, container);

    expect(find.byKey(const ValueKey('demanda-mapa')), findsNothing);
    expect(
      find.textContaining('No hubo ninguna entrada registrada en el período'),
      findsOneWidget,
    );
  });

  testWidgets('cada control de calidad publica su regla y su denominador', (
    tester,
  ) async {
    final container = _contenedor();
    addTearDown(container.dispose);
    await _montar(tester, container);

    expect(find.text('Calidad de datos'), findsOneWidget);
    expect(find.text('21 / 21'), findsOneWidget);
    expect(find.text('cobertura 97.2 %'), findsOneWidget);
    expect(find.textContaining('Cobertura: aviso por debajo del 95 %'),
        findsWidgets);
    // Donde la cobertura no aplica se dice, en vez de calcular una que no
    // significaría nada.
    expect(find.text('sin cobertura aplicable'), findsOneWidget);
  });

  testWidgets('un control con destino lleva a Clientes ya filtrado', (
    tester,
  ) async {
    final container = _contenedor();
    addTearDown(container.dispose);
    await _montar(tester, container);

    await tester.tap(find.byKey(const ValueKey('calidad-socios-referencia')));
    await tester.pump();

    final filtro = container.read(clientsScopeFilterProvider);
    expect(filtro, isNotNull);
    expect(filtro!.attribute, ClientsAttribute.referencia);
    expect(filtro.id, kSinDatoKey);
    expect(container.read(dashboardNavProvider), 1);
  });

  testWidgets('un control de bajas lleva a Control y Calidad', (tester) async {
    final container = _contenedor();
    addTearDown(container.dispose);
    await _montar(tester, container);

    await tester.tap(find.byKey(const ValueKey('calidad-bajas-sin-gestion')));
    await tester.pump();
    expect(container.read(dashboardNavProvider), 23);
  });

  testWidgets('sin motor canónico la familia bajas se declara sin evaluar', (
    tester,
  ) async {
    final container = _contenedor(calidad: _calidad(bajasEvaluadas: false));
    addTearDown(container.dispose);
    await _montar(tester, container);

    expect(
      find.byKey(const ValueKey('calidad-bajas-sin-evaluar')),
      findsOneWidget,
    );
  });

  testWidgets('el selector cambia período y granularidad de la consulta', (
    tester,
  ) async {
    final container = _contenedor();
    addTearDown(container.dispose);
    await _montar(tester, container);

    expect(container.read(cohortsQueryProvider).days, 365);
    expect(container.read(cohortsQueryProvider).granularity, 'mes');

    await tester.tap(find.byKey(const ValueKey('permanencia-periodo-90')));
    await tester.pumpAndSettle();
    expect(container.read(cohortsQueryProvider).days, 90);

    await tester.tap(find.byKey(const ValueKey('permanencia-cohorte-semana')));
    await tester.pumpAndSettle();
    expect(container.read(cohortsQueryProvider).granularity, 'semana');
    expect(tester.takeException(), isNull);
  });
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;
  @override
  Future<void> save(AppearancePreference preference) async {}
}
