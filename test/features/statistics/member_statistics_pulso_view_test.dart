import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/statistics/data/models/member_statistics.dart';
import 'package:gym_client/src/features/statistics/presentation/screens/member_statistics_pulso_view.dart';
import 'package:gym_client/src/features/statistics/presentation/state/statistics_providers.dart';

/// Perfil con las dos monedas separadas y una tasa de muestra pequeña, que son
/// las dos cosas que el plan exige que la vista no esconda.
final _perfil = MemberStatistics.fromJson({
  'zona': 'America/Los_Angeles',
  'dia_negocio': '2026-07-30',
  'socio': {
    'ci': '85042012345',
    'nombre': 'Leonardo Valdés Reyes',
    'sexo': 'Masculino',
    'edad': 21,
    'categoria': 'NUEVO',
    'objetivo': 'Ganar masa muscular',
    'antiguedadDias': 167,
  },
  'constancia': {
    'visitas': 104,
    'visitasPorMes': [
      {'mes': '2026-06', 'total': 20},
      {'mes': '2026-07', 'total': 17},
    ],
    'rachaActual': 3,
    'rachaMaxima': 6,
    'diasDesdeUltima': 0,
    'permanenciaMediaMin': 65,
    'porFranja': [
      {'franja': 'Noche', 'total': 103},
      {'franja': 'Tarde', 'total': 1},
    ],
    'porDiaSemana': [
      {'dia': 'Domingo', 'total': 0},
      {'dia': 'Lunes', 'total': 18},
    ],
    'aprovechamiento': {'casos': 104, 'base': 187, 'porcentaje': 55.6},
  },
  'dinero': {
    'porMoneda': [
      {
        'monedaId': 'eur-0001',
        'cobros': 6,
        'total': 150.0,
        'ticketMedio': 25.0,
        'primero': '2026-02-01T00:00:00.000Z',
        'ultimo': '2026-07-01T00:00:00.000Z',
      },
      {
        'monedaId': 'cup-0001',
        'cobros': 1,
        'total': 700.0,
        'ticketMedio': 700.0,
        'primero': '2026-03-01T00:00:00.000Z',
        'ultimo': '2026-03-01T00:00:00.000Z',
      },
    ],
    'porMedio': [
      {'medio': 'Efectivo', 'total': 6},
      {'medio': 'Transferencia', 'total': 1},
    ],
    'mora': {
      'cobrosConRecargo': 0,
      'recargoTotal': 0.0,
      'diasAtrasoPromedio': null,
      'condonadoTotal': 0.0,
      'puntualidad': {'casos': 7, 'base': 7, 'porcentaje': 100.0},
    },
  },
  'contrato': {
    'membresias': [
      {
        'id': 'm1',
        'plan': 'Semanal',
        'precio': 700.0,
        'monedaId': 'cup-0001',
        'desde': '2026-02-14',
        'hasta': '2026-02-21',
        'estado': 'VENCIDA',
        'origen': 'ALTA',
      },
    ],
    'altas': 1,
    'renovaciones': 6,
    'cambiosDePlan': 0,
    'reactivaciones': 0,
    'diasPausados': 0,
    'tasaRenovacion': {'casos': 3, 'base': 3, 'porcentaje': 100.0},
    'planesRecorridos': ['Mensual en euros', 'Semanal'],
  },
  'cuerpo': {
    'serie': [
      {'fecha': '2026-05-15', 'peso': 74.4},
      {'fecha': '2026-07-15', 'peso': 72.1},
    ],
    'pesoInicial': 74.4,
    'pesoActual': 72.1,
    'delta': -2.3,
    'estaturaCm': 178.0,
    'imc': 22.8,
  },
});

void main() {
  testWidgets('sin socio elegido invita a buscar en vez de mostrar ceros', (
    tester,
  ) async {
    await _pump(tester, const Size(1280, 900), seleccionado: null);

    expect(find.text('PERFIL DEL\nSOCIO.', findRichText: true), findsOneWidget);
    expect(find.textContaining('Busca un socio arriba'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nunca suma monedas distintas: cada divisa lleva su tarjeta', (
    tester,
  ) async {
    await _pump(tester, const Size(1280, 900));

    expect(find.text('150.00'), findsOneWidget);
    expect(find.text('700.00'), findsOneWidget);
    // 850 sería la suma prohibida.
    expect(find.textContaining('850'), findsNothing);
    expect(find.text('ticket 25.00'), findsOneWidget);
    expect(find.text('ticket 700.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toda tasa enseña su denominador', (tester) async {
    await _pump(tester, const Size(1280, 900));

    expect(find.textContaining('de 187 días cubiertos'), findsOneWidget);
    expect(find.textContaining('7 de 7'), findsOneWidget);
    expect(find.textContaining('renovación · 3 de 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('una tasa sobre poquísimos casos se marca como muestra baja', (
    tester,
  ) async {
    await _pump(tester, const Size(1280, 900));

    // La renovación es 3 de 3: por debajo del umbral de cinco.
    expect(find.text('muestra baja'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cada panel responde una pregunta concreta', (tester) async {
    await _pump(tester, const Size(1280, 900));

    expect(find.text('¿Viene, y cuándo?'), findsOneWidget);
    expect(find.text('¿Cuánto deja, y en qué moneda?'), findsOneWidget);
    expect(find.text('¿Renueva, o se está yendo?'), findsOneWidget);
    expect(find.text('¿Está cambiando su cuerpo?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('declara la zona en que agrupó días y horas', (tester) async {
    await _pump(tester, const Size(1280, 900));

    expect(
      find.textContaining('agrupados en America/Los_Angeles'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('se apila sin desbordar en una ventana compacta', (tester) async {
    await _pump(tester, const Size(560, 900));

    expect(find.text('¿Viene, y cuándo?'), findsOneWidget);
    expect(find.text('¿Está cambiando su cuerpo?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un fallo del servidor se explica y se puede reintentar', (
    tester,
  ) async {
    await _pump(tester, const Size(1280, 900), fallar: true);

    expect(
      find.textContaining('No se pudo calcular la estadística'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  String? seleccionado = '85042012345',
  bool fallar = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
        selectedMemberProvider.overrideWith(() => _SelectedFijo(seleccionado)),
        memberStatisticsProvider.overrideWith((ref, ci) async {
          if (fallar) throw Exception('la base no respondió');
          return _perfil;
        }),
      ],
      child: const MaterialApp(
        home: Scaffold(body: MemberStatisticsPulsoView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _SelectedFijo extends SelectedMemberNotifier {
  _SelectedFijo(this._inicial);

  final String? _inicial;

  @override
  String? build() => _inicial;
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
