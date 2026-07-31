import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/financials/data/models/currency_model.dart';
import 'package:gym_client/src/features/financials/presentation/state/currency_notifier.dart';
import 'package:gym_client/src/features/statistics/data/models/trainer_statistics.dart';
import 'package:gym_client/src/features/statistics/presentation/screens/trainer_statistics_pulso_view.dart';
import 'package:gym_client/src/features/statistics/presentation/state/statistics_providers.dart';
import 'package:gym_client/src/features/trainers/data/models/trainer_model.dart';
import 'package:gym_client/src/features/trainers/presentation/providers/trainer_notifier.dart';

/// Perfil tomado de la respuesta real de `GET /estadisticas/entrenador/:id`
/// sobre los seis meses regenerados el 31-07-2026.
///
/// Trae dos monedas separadas y una retención por debajo del 50 %, que es
/// justo el caso que la vista tiene que saber señalar sin dramatizar.
final _perfil = TrainerStatistics.fromJson({
  'zona': 'America/Los_Angeles',
  'dia_negocio': '2026-07-30',
  'entrenador': {
    'id': '2a778e5c',
    'nombre': 'Yoandry Pérez Silva',
    'sexo': 'Masculino',
    'activo': true,
    'antiguedadDias': 0,
  },
  'cartera': {
    'activos': 18,
    'historicos': 21,
    'perdidos': 3,
    'movimientos': [
      {'mes': '2026-02', 'altas': 10, 'bajas': 0},
      {'mes': '2026-03', 'altas': 8, 'bajas': 1},
      {'mes': '2026-04', 'altas': 6, 'bajas': 0},
    ],
    'motivosDeCierre': [
      {'motivo': 'Reparto de carga entre entrenadores', 'total': 2},
      {'motivo': 'El socio pidió otro horario de atención', 'total': 1},
    ],
  },
  'composicion': {
    'porSexo': [
      {'etiqueta': 'Masculino', 'total': 10},
      {'etiqueta': 'Femenino', 'total': 8},
    ],
    'porCategoria': [
      {'etiqueta': 'NUEVO', 'total': 15},
      {'etiqueta': 'VIEJO', 'total': 3},
    ],
    'porFranja': [
      {'etiqueta': 'Mañana', 'total': 9},
      {'etiqueta': 'Tarde', 'total': 6},
    ],
    'porPlan': [
      {'etiqueta': 'Mensual', 'total': 8},
      {'etiqueta': 'Semanal', 'total': 5},
    ],
    'porNacionalidad': [
      {'etiqueta': 'Cuba', 'total': 18},
    ],
    'planLider': {'etiqueta': 'Mensual', 'total': 8},
  },
  'constancia': {
    'masConstantes': [
      {'ci': '76120323785', 'nombre': 'Luis Martínez Suárez', 'visitas': 93},
      {'ci': '88060138877', 'nombre': 'Rosa Peña Valdés', 'visitas': 90},
    ],
    'visitasMediasPorSocio': 73,
  },
  'retencion': {'casos': 66, 'base': 146, 'porcentaje': 45.2},
  'ingresos': [
    {
      'monedaId': 'cup-0001',
      'cobros': 62,
      'total': 128195.0,
      'ticketMedio': 2067.66,
    },
    {'monedaId': 'eur-0001', 'cobros': 6, 'total': 150.0, 'ticketMedio': 25.0},
  ],
});

void main() {
  testWidgets('sin entrenador elegido invita a elegir', (tester) async {
    await _pump(tester, const Size(1280, 1200), seleccionado: null);

    expect(
      find.text('PERFIL DEL\nENTRENADOR.', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Elige un entrenador arriba'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enseña altas y bajas juntas, no solo las altas', (tester) async {
    await _pump(tester, const Size(1280, 1200));

    expect(find.text('¿Gana socios, o los pierde?'), findsOneWidget);
    // feb: 10 altas, 0 bajas · mar: 8 altas, 1 baja · abr: 6 altas, 0 bajas.
    expect(find.text('+10'), findsOneWidget);
    expect(find.text('+7'), findsOneWidget);
    expect(find.text('+6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'la retención lleva su denominador, que es lo que la hace leíble',
    (tester) async {
      await _pump(tester, const Size(1280, 1200));

      expect(find.textContaining('66 de 146'), findsWidgets);
      // Con 146 casos la muestra no es baja: el aviso no debe aparecer.
      expect(find.text('muestra baja'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('nunca suma monedas distintas: una tarjeta por divisa', (
    tester,
  ) async {
    await _pump(tester, const Size(1280, 1200));

    expect(find.text('128195.00'), findsOneWidget);
    expect(find.text('150.00'), findsOneWidget);
    // 128345 sería la suma prohibida.
    expect(find.textContaining('128345'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la cartera distingue activos de históricos', (tester) async {
    await _pump(tester, const Size(1280, 1200));

    // Contar asignaciones en vez de socios ya infló la cartera 3,5 veces una
    // vez: activos nunca puede superar a históricos.
    expect(
      find.textContaining('de 21 que ha atendido alguna vez'),
      findsOneWidget,
    );
    expect(find.text('¿Con qué cartera trabaja?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el plan que más atiende aparece en la banda superior', (
    tester,
  ) async {
    await _pump(tester, const Size(1280, 1200));

    expect(find.text('Plan que más atiende'), findsOneWidget);
    expect(find.text('Mensual'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('declara la zona en que agrupó meses y franjas', (tester) async {
    await _pump(tester, const Size(1280, 1200));

    expect(
      find.textContaining('agrupados en America/Los_Angeles'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('se apila sin desbordar en una ventana compacta', (tester) async {
    await _pump(tester, const Size(560, 1400));

    expect(find.text('¿Gana socios, o los pierde?'), findsOneWidget);
    expect(find.text('¿Sus socios vienen?'), findsOneWidget);
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

  testWidgets('un 404 no vuelca la excepción técnica de Dio al operador', (
    tester,
  ) async {
    final error = DioException.badResponse(
      statusCode: 404,
      requestOptions: RequestOptions(path: '/estadisticas/entrenador/2a778e5c'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(
          path: '/estadisticas/entrenador/2a778e5c',
        ),
        statusCode: 404,
      ),
    );
    await _pump(tester, const Size(1280, 1200), error: error);

    expect(
      find.textContaining('no está disponible en el servidor'),
      findsOneWidget,
    );
    expect(find.textContaining('DioException'), findsNothing);
    expect(find.textContaining('developer.mozilla.org'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  String? seleccionado = '2a778e5c',
  bool fallar = false,
  Object? error,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
        selectedTrainerProvider.overrideWith(() => _TrainerFijo(seleccionado)),
        trainerProvider.overrideWith(
          () => _EntrenadoresFijos([
            TrainerModel(
              id: '2a778e5c',
              ci: '85042012345',
              nombres: 'Yoandry',
              apellidos: 'Pérez Silva',
              activo: true,
              fechaInicio: DateTime.utc(2026, 2, 1),
            ),
          ]),
        ),
        currencyProvider.overrideWith(
          () => _MonedasFijas(const [
            CurrencyModel(id: 'cup-0001', name: 'Peso cubano', code: 'CUP'),
            CurrencyModel(id: 'eur-0001', name: 'Euro', code: 'EUR'),
          ]),
        ),
        trainerStatisticsProvider.overrideWith((ref, id) async {
          if (error != null) throw error;
          if (fallar) throw Exception('la base no respondió');
          return _perfil;
        }),
      ],
      child: const MaterialApp(
        home: Scaffold(body: TrainerStatisticsPulsoView(showSelector: true)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _TrainerFijo extends SelectedTrainerNotifier {
  _TrainerFijo(this._inicial);

  final String? _inicial;

  @override
  String? build() => _inicial;
}

class _EntrenadoresFijos extends TrainerNotifier {
  _EntrenadoresFijos(this._entrenadores);

  final List<TrainerModel> _entrenadores;

  @override
  Future<List<TrainerModel>> build() async => _entrenadores;
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
