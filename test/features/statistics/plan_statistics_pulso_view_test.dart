import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/financials/data/models/currency_model.dart';
import 'package:gym_client/src/features/financials/presentation/state/currency_notifier.dart';
import 'package:gym_client/src/features/products/data/models/payment_plan_model.dart';
import 'package:gym_client/src/features/products/presentation/state/payment_plan_notifier.dart';
import 'package:gym_client/src/features/statistics/data/models/plan_statistics.dart';
import 'package:gym_client/src/features/statistics/presentation/screens/plan_statistics_pulso_view.dart';
import 'package:gym_client/src/features/statistics/presentation/state/statistics_providers.dart';

/// Perfil tomado de la respuesta real de `GET /estadisticas/plan/:id` sobre los
/// seis meses regenerados el 31-07-2026, recortado a lo que la vista usa.
///
/// Lleva a propósito las dos cosas que el plan exige que no se escondan: **dos
/// monedas separadas** y una tasa con **muestra pequeña**.
final _perfil = PlanStatistics.fromJson({
  'zona': 'America/Los_Angeles',
  'dia_negocio': '2026-07-30',
  'plan': {
    'id': 'db881bdc',
    'nombre': 'Trimestral',
    'codigo': 'TRI',
    'importe': 5400.0,
    'monedaId': 'cup-0001',
    'duracionDias': 90,
    'activo': true,
    'incluyeEntrenador': false,
    'aceptaCuotas': true,
  },
  'contratacion': {
    'socios': 26,
    'vigentes': 21,
    'pendientes': 2,
    'pausadas': 1,
    'terminadas': 11,
    'porMes': [
      {'etiqueta': '2026-06', 'total': 9},
      {'etiqueta': '2026-07', 'total': 14},
    ],
    'tasaRenovacion': {'casos': 3, 'base': 4, 'porcentaje': 75.0},
  },
  'composicion': {
    'porSexo': [
      {'etiqueta': 'Femenino', 'total': 12},
      {'etiqueta': 'Masculino', 'total': 9},
    ],
    'porCategoria': [
      {'etiqueta': 'NUEVO', 'total': 16},
      {'etiqueta': 'VIEJO', 'total': 5},
    ],
    'porFranja': [
      {'etiqueta': 'Mañana', 'total': 11},
      {'etiqueta': 'Noche', 'total': 6},
    ],
    'porEntrenador': [
      {'etiqueta': 'Sin entrenador', 'total': 13},
      {'etiqueta': 'Reinier Castillo Mora', 'total': 4},
    ],
  },
  'movilidad': {
    'vienenDe': [
      {'etiqueta': 'Semanal', 'total': 3},
      {'etiqueta': 'Mensual en euros', 'total': 2},
      {'etiqueta': 'Diario', 'total': 1},
    ],
    'seVanA': [
      {'etiqueta': 'Semanal', 'total': 1},
    ],
    'saldo': 5,
  },
  'dinero': [
    {
      'monedaId': 'cup-0001',
      'cobros': 40,
      'total': 151200.0,
      'ticketMedio': 3780.0,
      'descuentoTotal': 5400.0,
      'recargoTotal': 0.0,
    },
    {
      'monedaId': 'eur-0001',
      'cobros': 2,
      'total': 50.0,
      'ticketMedio': 25.0,
      'descuentoTotal': 0.0,
      'recargoTotal': 0.0,
    },
  ],
  'duracion': {
    'contratadaDias': 90,
    'realMediaDias': 88.2,
    'desviacionDias': -1.8,
  },
  'uso': {'visitas': 609, 'sociosConCobertura': 21, 'visitasPorSocio': 29.0},
  'cuotas': {'membresiasFraccionadas': 8, 'cuotasEmitidas': 24},
});

void main() {
  testWidgets('sin plan elegido invita a elegir en vez de enseñar ceros', (
    tester,
  ) async {
    await _pump(tester, const Size(1280, 1200), seleccionado: null);

    expect(find.text('PERFIL DEL\nPLAN.', findRichText: true), findsOneWidget);
    expect(find.textContaining('Elige un plan arriba'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la movilidad va primero y con su saldo, que es el dato nuevo', (
    tester,
  ) async {
    await _pump(tester, const Size(1280, 1200));

    expect(
      find.text('¿Capta socios, o alimenta a otros planes?'),
      findsOneWidget,
    );
    // Dos filas dan +2: Semanal (3 entran − 1 sale) y Mensual en euros (2 − 0).
    expect(find.text('+2'), findsNWidgets(2));
    // Diario: 1 entra, ninguno sale.
    expect(find.text('+1'), findsOneWidget);
    // El saldo del plan entero, en la banda de métricas y en el pie del panel.
    expect(find.text('+5'), findsWidgets);
    expect(find.textContaining('6 entran · 1 salen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la lectura del saldo se deduce del dato, no está escrita', (
    tester,
  ) async {
    await _pump(tester, const Size(1280, 1200));

    expect(
      find.textContaining('Trimestral capta socios de otros planes'),
      findsOneWidget,
    );
    expect(
      find.textContaining('La mayoría llega desde Semanal'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('un plan que alimenta a otros lo dice al revés', (tester) async {
    await _pump(tester, const Size(1280, 1200), perfil: _perfilQueAlimenta());

    expect(find.textContaining('es puerta de entrada'), findsOneWidget);
    expect(
      find.textContaining('La mayoría se va a Trimestral'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('nunca suma monedas distintas: una tarjeta por divisa', (
    tester,
  ) async {
    await _pump(tester, const Size(1280, 1200));

    expect(find.text('151200.00'), findsOneWidget);
    expect(find.text('50.00'), findsOneWidget);
    // 151250 sería la suma prohibida.
    expect(find.textContaining('151250'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la moneda se nombra, no se enseña el identificador crudo', (
    tester,
  ) async {
    await _pump(tester, const Size(1280, 1200));

    expect(find.textContaining('CUP'), findsWidgets);
    expect(find.textContaining('cup-0001'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toda tasa lleva su denominador y avisa si la muestra es baja', (
    tester,
  ) async {
    await _pump(tester, const Size(1280, 1200));

    expect(find.textContaining('renovación · 3 de 4'), findsOneWidget);
    expect(find.text('muestra baja'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('declara la zona en que agrupó días y horas', (tester) async {
    await _pump(tester, const Size(1280, 1200));

    expect(
      find.textContaining('agrupados en America/Los_Angeles'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('se apila sin desbordar en una ventana compacta', (tester) async {
    await _pump(tester, const Size(560, 1400));

    expect(
      find.text('¿Capta socios, o alimenta a otros planes?'),
      findsOneWidget,
    );
    expect(find.text('¿Se usa, o solo se paga?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un fallo del servidor se explica y se puede reintentar', (
    tester,
  ) async {
    await _pump(tester, const Size(1280, 1200), fallar: true);

    expect(
      find.textContaining('No se pudo calcular la estadística'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

/// El mismo plan visto desde el otro lado del cambio: pierde más de lo que capta.
PlanStatistics _perfilQueAlimenta() => PlanStatistics.fromJson({
  'zona': 'America/Los_Angeles',
  'dia_negocio': '2026-07-30',
  'plan': {'id': 'p-dia', 'nombre': 'Diario', 'duracionDias': 1},
  'contratacion': {
    'socios': 30,
    'vigentes': 4,
    'porMes': [],
    'tasaRenovacion': {'casos': 2, 'base': 20, 'porcentaje': 10.0},
  },
  'composicion': {},
  'movilidad': {
    'vienenDe': [
      {'etiqueta': 'Semanal', 'total': 1},
    ],
    'seVanA': [
      {'etiqueta': 'Trimestral', 'total': 6},
      {'etiqueta': 'Mensual', 'total': 2},
    ],
    'saldo': -7,
  },
  'dinero': [],
  'duracion': {'contratadaDias': 1, 'realMediaDias': null},
  'uso': {'visitas': 0, 'sociosVigentes': 0, 'visitasPorSocio': null},
  'cuotas': {'membresiasFraccionadas': 0, 'cuotasEmitidas': 0},
});

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  String? seleccionado = 'db881bdc',
  bool fallar = false,
  PlanStatistics? perfil,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
        selectedPlanProvider.overrideWith(() => _PlanFijo(seleccionado)),
        paymentPlanProvider.overrideWith(
          () => _PlanesFijos([
            PaymentPlanModel(
              id: 'db881bdc',
              nombre: 'Trimestral',
              importe: 5400,
              duracion: 90,
              monedaId: 'cup-0001',
              codigo: 'TRI',
            ),
          ]),
        ),
        currencyProvider.overrideWith(
          () => _MonedasFijas(const [
            CurrencyModel(id: 'cup-0001', name: 'Peso cubano', code: 'CUP'),
            CurrencyModel(id: 'eur-0001', name: 'Euro', code: 'EUR'),
          ]),
        ),
        planStatisticsProvider.overrideWith((ref, id) async {
          if (fallar) throw Exception('la base no respondió');
          return perfil ?? _perfil;
        }),
      ],
      child: const MaterialApp(
        home: Scaffold(body: PlanStatisticsPulsoView(showSelector: true)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _PlanFijo extends SelectedPlanNotifier {
  _PlanFijo(this._inicial);

  final String? _inicial;

  @override
  String? build() => _inicial;
}

class _PlanesFijos extends PaymentPlanNotifier {
  _PlanesFijos(this._planes);

  final List<PaymentPlanModel> _planes;

  @override
  Future<List<PaymentPlanModel>> build() async => _planes;
}

class _MonedasFijas extends CurrencyNotifier {
  _MonedasFijas(this._monedas);

  final List<CurrencyModel> _monedas;

  @override
  Future<List<CurrencyModel>> build() async => _monedas;
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
