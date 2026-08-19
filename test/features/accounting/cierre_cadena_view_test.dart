import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_theme.dart';
import 'package:gym_client/src/features/accounting/data/models/cierre_cadena_m6_models.dart';
import 'package:gym_client/src/features/accounting/data/models/cierre_cadena_models.dart';
import 'package:gym_client/src/features/accounting/presentation/screens/cierre_cadena_view.dart';
import 'package:gym_client/src/features/accounting/presentation/state/cierre_cadena_m6_providers.dart';
import 'package:gym_client/src/features/accounting/presentation/state/cierre_cadena_providers.dart';
import 'package:gym_client/src/features/auth/domain/models/sede_session.dart';
import 'package:gym_client/src/features/auth/presentation/state/sede_session_provider.dart';

/// M6 — la pantalla de contabilidad de la cadena (docs/MULTI_SEDE.md §6.3, §6.4).
///
/// Lo que se fija aquí es lo que hace útil la vista: que el ingreso y el dinero
/// cobrado por cuenta ajena **no se mezclen**, que las ausentes se nombren, que
/// el certificado diga si su sello cuadra y que el detalle diga de dónde salen
/// sus cifras. Todo con un solo período mandando sobre las cuatro secciones.
void main() {
  final periodo = PeriodoSemaforo.mesDe(
    DateTime(DateTime.now().year, DateTime.now().month - 1),
  );

  SemaforoCadenaModel semaforo() => SemaforoCadenaModel(
    fechaInicio: periodo.desde,
    fechaFinExclusiva: periodo.hastaExclusivo,
    filas: [
      SemaforoFilaModel(
        gymId: 'gym-centro',
        nombre: 'Sede Centro',
        estado: EstadoSemaforo.cerradaYSincronizada,
        consolidable: true,
        motivo: '',
        descuadres: const [],
        movimientosPendientes: 0,
      ),
      SemaforoFilaModel(
        gymId: 'gym-oeste',
        nombre: 'Sede Oeste',
        estado: EstadoSemaforo.sinCerrar,
        consolidable: false,
        motivo: 'Está al habla y su cierre no consta.',
        descuadres: const [],
        movimientosPendientes: 0,
      ),
    ],
    puedeFirmarse: false,
    ausentes: const [SedeAusenteModel(gymId: 'gym-oeste', nombre: 'Sede Oeste')],
  );

  ConsolidadoModel consolidado({
    List<String> avisos = const [],
    String? motivoParaNoFirmar,
  }) => ConsolidadoModel(
    clase: 'PARCIAL_DECLARADO',
    monedas: const [
      BloqueMonedaModel(
        monedaId: 'cup',
        monedaCodigo: 'CUP',
        ingreso: '7858.70',
        cobradoCuentaAjena: '300.00',
        sedes: [
          AporteSedeModel(
            gymId: 'gym-centro',
            nombre: 'Sede Centro',
            ingreso: '7858.70',
            cobradoCuentaAjena: '300.00',
            origenCierre: 'PERIODO',
          ),
        ],
      ),
    ],
    ausentes: const [SedeAusenteModel(gymId: 'gym-oeste', nombre: 'Sede Oeste')],
    sedesIncluidas: 1,
    avisos: avisos,
    motivoParaNoFirmar: motivoParaNoFirmar,
  );

  Widget app({
    ConsolidadoModel? informe,
    List<CertificadoModel> certificados = const [],
    DetalleSedeModel? detalle,
    bool esPlataforma = true,
  }) => ProviderScope(
    overrides: [
      sedeSessionProvider.overrideWith(() => _Sesion(esPlataforma)),
      solicitudesCierreProvider.overrideWith(
        (_) async => const <SolicitudCierreModel>[],
      ),
      semaforoCadenaProvider.overrideWith((ref, _) async => semaforo()),
      consolidadoProvider.overrideWith((ref, _) async => informe ?? consolidado()),
      certificadosProvider.overrideWith((_) async => certificados),
      if (detalle != null)
        detalleDeSedeProvider.overrideWith((ref, _) async => detalle),
    ],
    child: const MaterialApp(
      home: PulsoThemeScope(child: Scaffold(body: CierreCadenaView())),
    ),
  );

  testWidgets('el ingreso y el dinero ajeno se enseñan separados', (tester) async {
    // La trampa de §6.3: mezclarlos cuenta dos veces el mismo dinero.
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('7858.70'), findsWidgets);
    expect(find.text('300.00'), findsOneWidget);
    expect(find.text('no suma en el ingreso'), findsOneWidget);
  });

  testWidgets('las ausentes se nombran una vez, en el semáforo', (tester) async {
    // §6.2 exige nombrarlas; enseñarlas dos veces —en el semáforo y en el
    // informe— es ruido. El informe dice lo que el semáforo no: que su total
    // está incompleto por eso.
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.textContaining('Quedarían fuera: Sede Oeste'), findsOneWidget);
    expect(find.textContaining('deja fuera 1 sede(s)'), findsOneWidget);
  });

  testWidgets('los avisos de los cierres viejos se ven antes de firmar', (
    tester,
  ) async {
    // Quien firma tiene que ver lo que esos cierres no pueden afirmar; en un log
    // no lo vería nadie.
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        informe: consolidado(
          avisos: ['gym-centro: este cierre es anterior a la separación del ajeno.'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('anterior a la separación'), findsOneWidget);
    expect(
      find.textContaining('LO QUE ESTOS CIERRES NO PUEDEN AFIRMAR'),
      findsOneWidget,
    );
  });

  testWidgets('sin certificado ofrece firmar el parcial, diciéndolo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Este período no está certificado.'), findsOneWidget);
    expect(find.textContaining('nombrará dentro a las sedes'), findsOneWidget);
    expect(find.text('FIRMAR PARCIAL'), findsOneWidget);
  });

  testWidgets('un consolidado vacío no ofrece firmar', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        informe: ConsolidadoModel(
          clase: 'PARCIAL_DECLARADO',
          monedas: const [],
          ausentes: const [],
          sedesIncluidas: 0,
          avisos: const [],
          motivoParaNoFirmar: 'Ninguna sede ha firmado su cierre.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Ninguna sede ha firmado'), findsWidgets);
    final boton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('FIRMAR PARCIAL'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(boton.onPressed, isNull);
  });

  testWidgets('el certificado enseña su sello y si cuadra', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        certificados: [
          CertificadoModel(
            certificadoId: 'ccc-1',
            cicloNumero: 2,
            clase: 'PARCIAL_DECLARADO',
            estado: 'VIGENTE',
            sedesIncluidas: 1,
            sha256: 'bf69eb2b3564699d0000000000000000000000000000000000000000000000ff',
            fechaInicio: periodo.desde,
            fechaFinExclusiva: periodo.hastaExclusivo,
            firmadoPor: 'Ana Cadena',
            firmadoAt: DateTime(2026, 8, 19, 6, 30),
            integro: true,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Certificado · sello verificado'), findsOneWidget);
    expect(find.textContaining('Ciclo 2'), findsOneWidget);
    expect(find.textContaining('bf69eb2b'), findsOneWidget);
    expect(find.text('REHACER CON MOTIVO'), findsOneWidget);
  });

  testWidgets('un sello que no cuadra se dice con palabras, no con color', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        certificados: [
          CertificadoModel(
            certificadoId: 'ccc-1',
            cicloNumero: 1,
            clase: 'COMPLETO',
            estado: 'VIGENTE',
            sedesIncluidas: 1,
            sha256: 'aaa',
            fechaInicio: periodo.desde,
            fechaFinExclusiva: periodo.hastaExclusivo,
            integro: false,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('EL SELLO NO CUADRA'), findsOneWidget);
  });

  testWidgets('el detalle de una sede dice qué es cada cobro para ella', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        detalle: DetalleSedeModel(
          gymId: 'gym-oeste',
          nombre: 'Sede Oeste',
          origen: 'CIERRE_FIRMADO',
          nota: 'Sale del cierre que la sede firmó: no cambia.',
          totales: const [
            TotalDetalleModel(
              monedaId: 'cup',
              ingreso: '800.00',
              efectivo: '1100.00',
              cobradoCuentaAjena: '300.00',
              cobros: 2,
              anulados: 0,
            ),
          ],
          cobros: const [
            CobroDetalleModel(
              pagoClienteId: 'p-1',
              monedaId: 'cup',
              monto: '800.00',
              clase: 'INGRESO_Y_EFECTIVO',
              anulado: false,
              ci: '99090100009',
            ),
            CobroDetalleModel(
              pagoClienteId: 'p-2',
              monedaId: 'cup',
              monto: '300.00',
              clase: 'SOLO_EFECTIVO',
              anulado: false,
              ci: '11223344556',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sede Oeste').last);
    await tester.pumpAndSettle();

    // Ingreso y caja, separados y con nombre.
    expect(find.text('800.00'), findsWidgets);
    expect(find.text('1100.00'), findsOneWidget);
    expect(find.textContaining('PASÓ POR SU CAJA'), findsOneWidget);
    // Y cada cobro dicho con palabras, no con un código del esquema.
    expect(find.text('En su caja · el ingreso es de otra sede'), findsOneWidget);
    expect(find.text('Suyo y en su caja'), findsOneWidget);
    // El origen del listado, siempre.
    expect(find.textContaining('no cambia'), findsOneWidget);
  });

  testWidgets('el período se manda desde un solo sitio', (tester) async {
    // Dos selectores en la misma pantalla —el de la vista y el del panel del
    // semáforo— hacen dudar de cuál manda, y es como se acaba mirando agosto en
    // uno y julio en el otro. Con el período impuesto, el panel no repite el suyo.
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('una sesión de sede no ve esta pantalla', (tester) async {
    // El servidor la rechaza con 403; ofrecerla solo llevaría a un error.
    await tester.pumpWidget(app(esPlataforma: false));
    await tester.pumpAndSettle();

    expect(find.text('CIERRE DE LA CADENA.'), findsNothing);
    expect(find.textContaining('es del dueño de la cadena'), findsOneWidget);
  });
}

class _Sesion extends SedeSessionNotifier {
  _Sesion(this.esPlataforma);

  final bool esPlataforma;

  @override
  SedeSession? build() => SedeSession(
    userId: 'u-1',
    gymId: 'gym-centro',
    role: 'admin',
    esPlataforma: esPlataforma,
  );
}
