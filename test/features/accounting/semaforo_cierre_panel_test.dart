import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_theme.dart';
import 'package:gym_client/src/features/accounting/data/models/cierre_cadena_models.dart';
import 'package:gym_client/src/features/accounting/data/repositories/cierre_cadena_repository.dart';
import 'package:gym_client/src/features/accounting/presentation/state/cierre_cadena_providers.dart';
import 'package:gym_client/src/features/accounting/presentation/widgets/semaforo_cierre_panel.dart';
import 'package:gym_client/src/features/auth/domain/models/sede_session.dart';
import 'package:gym_client/src/features/auth/presentation/state/sede_session_provider.dart';

/// M5 — el semáforo de cierre de la cadena (docs/MULTI_SEDE.md §6.2).
///
/// Lo que se fija aquí es lo que el Dueño necesita para **decidir**: quién
/// falta, con su nombre, y qué hacer con cada sede. Las dos ausencias se
/// parecen y piden cosas opuestas —reclamar un cierre o mirar una conexión—, y
/// confundirlas es lo que hace que se firme un consolidado creyendo que una
/// sede no cerró cuando nadie ha hablado con ella.
void main() {
  final periodoInicial = PeriodoSemaforo.mesDe(
    DateTime(DateTime.now().year, DateTime.now().month - 1),
  );

  SemaforoFilaModel fila({
    required String nombre,
    required EstadoSemaforo estado,
    bool consolidable = false,
    List<DescuadreMonedaModel> descuadres = const [],
    int pendientes = 0,
    CierreDeSedeModel? cierre,
    DateTime? noticia,
  }) => SemaforoFilaModel(
    gymId: nombre.toLowerCase().replaceAll(' ', '-'),
    nombre: nombre,
    estado: estado,
    consolidable: consolidable,
    motivo: '',
    descuadres: descuadres,
    movimientosPendientes: pendientes,
    cierre: cierre,
    ultimaNoticia: noticia,
  );

  SemaforoCadenaModel datos({
    required List<SemaforoFilaModel> filas,
    bool puedeFirmarse = false,
    List<SedeAusenteModel> ausentes = const [],
  }) => SemaforoCadenaModel(
    fechaInicio: periodoInicial.desde,
    fechaFinExclusiva: periodoInicial.hastaExclusivo,
    filas: filas,
    puedeFirmarse: puedeFirmarse,
    ausentes: ausentes,
  );

  Widget app({
    SemaforoCadenaModel? semaforo,
    Object? error,
    double width = 1100,
  }) => ProviderScope(
    overrides: [
      solicitudesCierreProvider.overrideWith(
        (_) async => const <SolicitudCierreModel>[],
      ),
      semaforoCadenaProvider(periodoInicial).overrideWith((_) async {
        if (error != null) throw error;
        return semaforo!;
      }),
    ],
    child: MaterialApp(
      home: PulsoThemeScope(
        child: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: width,
              child: const SemaforoCierrePanel(abierto: true),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('cada sede lleva su estado y qué hacer con ella', (tester) async {
    await tester.pumpWidget(
      app(
        semaforo: datos(
          filas: [
            fila(
              nombre: 'Gym Test',
              estado: EstadoSemaforo.cerradaYSincronizada,
              consolidable: true,
              cierre: CierreDeSedeModel(
                origen: 'PERIODO',
                estado: 'CERRADO',
                cerradoAt: DateTime(2026, 8, 8),
                cerradoPor: 'Carla',
              ),
              noticia: DateTime(2026, 8, 18, 1, 47),
            ),
            fila(nombre: 'Sede Oeste', estado: EstadoSemaforo.sinCerrar),
            fila(nombre: 'Sede Norte', estado: EstadoSemaforo.sinNoticias),
          ],
          ausentes: const [
            SedeAusenteModel(gymId: 'sede-oeste', nombre: 'Sede Oeste'),
            SedeAusenteModel(gymId: 'sede-norte', nombre: 'Sede Norte'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CERRADA'), findsOneWidget);
    // «SIN CERRAR» y «SIN NOTICIAS» salen dos veces a propósito: como contador
    // arriba y como estado de la fila.
    expect(find.text('SIN CERRAR'), findsNWidgets(2));
    expect(find.text('SIN NOTICIAS'), findsNWidgets(2));
    // Las dos ausencias piden cosas opuestas, y la fila lo dice con palabras.
    expect(find.text('Reclamar el cierre'), findsOneWidget);
    expect(find.text('Revisar la conexión, no reclamar'), findsOneWidget);
  });

  testWidgets('las ausentes salen nombradas, no contadas', (tester) async {
    // §6.2: nunca un total silencioso e incompleto. Para declarar un cierre
    // parcial hace falta poder nombrar a quién falta.
    await tester.pumpWidget(
      app(
        semaforo: datos(
          filas: [fila(nombre: 'Sede Oeste', estado: EstadoSemaforo.sinCerrar)],
          ausentes: const [
            SedeAusenteModel(gymId: 'sede-oeste', nombre: 'Sede Oeste'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Quedarían fuera: Sede Oeste'), findsOneWidget);
    expect(find.textContaining('CONSOLIDADO INCOMPLETO'), findsOneWidget);
  });

  testWidgets('con todas en verde el consolidado se puede firmar', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        semaforo: datos(
          filas: [
            fila(
              nombre: 'Gym Test',
              estado: EstadoSemaforo.cerradaYSincronizada,
              consolidable: true,
            ),
          ],
          puedeFirmarse: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('SE PUEDE FIRMAR'), findsOneWidget);
    expect(find.textContaining('Ninguna sede queda fuera'), findsOneWidget);
  });

  testWidgets('el descuadre se enseña con su moneda delante', (tester) async {
    // Sin la moneda, «-3.50» no dice de qué caja habla, y sumar monedas
    // distintas las cancelaría.
    await tester.pumpWidget(
      app(
        semaforo: datos(
          filas: [
            fila(
              nombre: 'Gym Test',
              estado: EstadoSemaforo.conIncidencias,
              descuadres: const [
                DescuadreMonedaModel(monedaId: 'CUP', menor: 350),
                DescuadreMonedaModel(monedaId: 'USD', menor: -350),
              ],
              pendientes: 2,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CUP 3.50 · USD -3.50'), findsOneWidget);
    expect(find.text('2 MOV. SIN CONCILIAR'), findsOneWidget);
  });

  testWidgets('desde el escritorio explica dónde vive el dato', (tester) async {
    // Un «sin datos» aquí se leería como «ninguna sede ha cerrado», que es la
    // conclusión contraria a la verdad.
    await tester.pumpWidget(
      app(
        error: const SemaforoSoloEnElConcentrador(
          'El semáforo de la cadena vive en el concentrador: esta sede solo ve sus cierres',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('vive en el concentrador'), findsOneWidget);
    expect(find.textContaining('Ábralo desde la web'), findsOneWidget);
  });

  testWidgets('se puede saltar al período que se pidió, aunque no sea un mes', (
    tester,
  ) async {
    // Las flechas caminan meses naturales y una solicitud puede pedir una
    // semana o un rango suelto: sin este atajo no había manera de mirar el
    // estado de lo que se acababa de pedir.
    final pedida = SolicitudCierreModel(
      solicitudId: 'ccs-rango',
      tipoPeriodo: 'RANGO',
      fechaInicio: DateTime(2026, 8, 1),
      fechaFinExclusiva: DateTime(2026, 8, 5),
      estado: 'ABIERTA',
      solicitadaPor: 'Ana Cadena',
    );
    final periodoPedido = PeriodoSemaforo(
      desde: pedida.fechaInicio,
      hastaExclusivo: pedida.fechaFinExclusiva,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          solicitudesCierreProvider.overrideWith((_) async => [pedida]),
          semaforoCadenaProvider.overrideWith(
            (ref, periodo) async => datos(
              filas: [
                fila(
                  nombre: 'Gym Test',
                  estado: periodo == periodoPedido
                      ? EstadoSemaforo.cerradaYSincronizada
                      : EstadoSemaforo.sinCerrar,
                  consolidable: periodo == periodoPedido,
                ),
              ],
            ),
          ),
        ],
        child: const MaterialApp(
          home: PulsoThemeScope(
            child: Scaffold(body: SemaforoCierrePanel(abierto: true)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SIN CERRAR'), findsNWidgets(2));

    await tester.tap(find.text('VER LO PEDIDO →'));
    await tester.pumpAndSettle();

    // El rótulo pasa a enseñar el rango, no un mes que no se está mirando.
    expect(find.text('2026-08-01 → 2026-08-04'), findsOneWidget);
    expect(find.text('CERRADA'), findsOneWidget);
  });

  testWidgets('una sesión de sede no ve el semáforo de la cadena', (
    tester,
  ) async {
    // El servidor lo rechaza con 403 a quien no es dueño de la cadena, así que
    // enseñarlo sería ofrecer una pantalla que solo puede acabar en error.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sedeSessionProvider.overrideWith(_SesionDeSede.new),
        ],
        child: const MaterialApp(
          home: PulsoThemeScope(
            child: Scaffold(body: SemaforoCierrePanel(abierto: true)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CIERRE DE LA CADENA'), findsNothing);
  });

  testWidgets('la tabla se desplaza por dentro y la cabecera no se mueve', (
    tester,
  ) async {
    // Recetario §4-bis: la tabla scrollea, no la vista.
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        semaforo: datos(
          filas: [
            for (var i = 0; i < 9; i++)
              fila(nombre: 'Sede $i', estado: EstadoSemaforo.sinCerrar),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cabecera = find.text('CIERRE DE LA CADENA');
    final antes = tester.getTopLeft(cabecera);
    expect(find.text('Sede 8'), findsNothing);

    await tester.drag(find.text('Sede 1'), const Offset(0, -240));
    await tester.pumpAndSettle();

    // El mando se queda quieto…
    expect(tester.getTopLeft(cabecera), antes);
    // …y lo que se movió fue la tabla: las primeras salieron por arriba y las
    // últimas entraron. Si scrollease la vista entera, la cabecera se habría
    // ido con ellas y volver a los mandos obligaría a subir del todo.
    expect(find.text('Sede 0'), findsNothing);
    expect(find.text('Sede 8'), findsOneWidget);
  });
  // §6.2 — «SIN NOTICIAS» sin fecha obliga a las dos preguntas que deciden y no
  // contesta ninguna: ¿desde cuándo, y es de hoy o lleva semanas?
  testWidgets('la sede callada dice desde cuándo, y la que habla también', (
    tester,
  ) async {
    final ahora = DateTime.now().toUtc();
    await tester.pumpWidget(
      app(
        semaforo: datos(
          filas: [
            fila(
              nombre: 'Sede Muda',
              estado: EstadoSemaforo.sinNoticias,
              noticia: ahora.subtract(const Duration(days: 3, hours: 2)),
            ),
            fila(
              nombre: 'Sede Al Habla',
              estado: EstadoSemaforo.sinCerrar,
              noticia: ahora.subtract(const Duration(minutes: 12)),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // La fecha ya la daba la columna; lo que faltaba es cuánto hace, y va en el
    // sitio que ocupaba la etiqueta «última sync», que repetía el encabezado.
    // La nota de `_Dato` se pinta en mayúsculas, y por eso se busca así.
    expect(find.text('HACE 3 D'), findsOneWidget);
    expect(find.text('ÚLTIMA SYNC'), findsNothing);
    // También en la que sí habla: es un dato, no un aviso, y saber que la verde
    // habló hace un rato es lo que hace creíble el resto de la tabla.
    expect(find.text('HACE 12 MIN'), findsOneWidget);
    // Y el contador pone cifra al montón: «2 sin noticias» no dice si es de esta
    // mañana o de hace tres semanas.
    expect(find.text('la más callada: 3 d'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('en compacto la noticia no se pierde con las columnas', (
    tester,
  ) async {
    // Por debajo de 780 la tabla se queda con sede y estado, y con eso se iba lo
    // único que distingue una sede callada esta mañana de una callada hace tres
    // semanas. Ahí sí va bajo la acción: la columna no existe, no se duplica.
    await tester.pumpWidget(
      app(
        width: 700,
        semaforo: datos(
          filas: [
            fila(
              nombre: 'Sede Muda',
              estado: EstadoSemaforo.sinNoticias,
              noticia: DateTime.now().toUtc().subtract(const Duration(days: 3)),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('hace 3 d'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la sede de la que no consta nada no finge un silencio largo', (
    tester,
  ) async {
    // Una sede recién dada de alta no ha callado: es que nunca habló. Pintarlo
    // como un silencio mandaría a alguien a revisar una conexión que no existe.
    await tester.pumpWidget(
      app(
        semaforo: datos(
          filas: [
            fila(nombre: 'Sede Nueva', estado: EstadoSemaforo.sinNoticias),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // En la fila y en el contador, que tampoco puede inventar días. La nota de
    // la fila va en mayúsculas; el pie del contador, en texto corriente.
    expect(find.text('SIN NOTICIA REGISTRADA'), findsOneWidget);
    expect(find.text('sin noticia registrada'), findsOneWidget);
    // Y la fecha sigue diciendo «nunca», que no es una fecha vieja.
    expect(find.text('nunca'), findsOneWidget);
    expect(find.textContaining('HACE'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un reloj atrasado no dice «hace -2 h»', (tester) async {
    // La última noticia puede quedar en el futuro respecto a este equipo; restar
    // sin más daría un negativo y la tabla diría un disparate.
    await tester.pumpWidget(
      app(
        semaforo: datos(
          filas: [
            fila(
              nombre: 'Sede Futura',
              estado: EstadoSemaforo.sinCerrar,
              noticia: DateTime.now().toUtc().add(const Duration(hours: 2)),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HACE 0 MIN'), findsOneWidget);
    expect(find.textContaining('HACE -'), findsNothing);
    expect(tester.takeException(), isNull);
  });

}

/// Una sesión de sede corriente: administra su gimnasio y no la cadena.
class _SesionDeSede extends SedeSessionNotifier {
  @override
  SedeSession? build() => const SedeSession(
    userId: 'u-1',
    gymId: 'local-gym-001',
    role: 'admin',
    esPlataforma: false,
  );
}
