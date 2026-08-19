import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_theme.dart';
import 'package:gym_client/src/features/accounting/data/models/cierre_cadena_models.dart';
import 'package:gym_client/src/features/accounting/presentation/state/cierre_cadena_providers.dart';
import 'package:gym_client/src/features/accounting/presentation/widgets/solicitud_cierre_aviso.dart';

/// M5 — el aviso de cierre en el mostrador de la sede (docs/MULTI_SEDE.md §6.2).
///
/// Lo que se fija aquí es que el aviso **lleve a la acción**: enseñar unas
/// fechas que después hay que teclear a mano en el selector es donde se
/// equivoca uno de día, y un cierre firmado con el período equivocado no se
/// deshace, se reabre.
void main() {
  SolicitudCierreModel solicitud({DateTime? limite, String? nota}) =>
      SolicitudCierreModel(
        solicitudId: 'ccs-1',
        tipoPeriodo: 'MES',
        fechaInicio: DateTime(2026, 7, 1),
        // Fin **exclusivo**, como lo guarda el servidor.
        fechaFinExclusiva: DateTime(2026, 8, 1),
        estado: 'ABIERTA',
        nota: nota,
        fechaLimite: limite,
        solicitadaPor: 'Ana Cadena',
        solicitadaAt: DateTime(2026, 8, 2),
      );

  Widget app({
    required List<SolicitudCierreModel> solicitudes,
    void Function(DateTime, DateTime)? onCargar,
  }) => ProviderScope(
    overrides: [
      solicitudesCierreProvider.overrideWith((_) async => solicitudes),
    ],
    child: MaterialApp(
      home: PulsoThemeScope(
        child: Scaffold(
          body: SizedBox(
            width: 900,
            child: SolicitudCierreAviso(
              onCargarPeriodo: onCargar ?? (_, _) {},
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('sin nada pedido no ocupa sitio', (tester) async {
    // Un panel permanente que dijera «no hay solicitudes» sería ruido fijo en
    // la vista donde se firma el cierre.
    await tester.pumpWidget(app(solicitudes: const []));
    await tester.pumpAndSettle();

    expect(find.textContaining('SOLICITA CERRAR'), findsNothing);
    expect(tester.getSize(find.byType(SolicitudCierreAviso)).height, 0);
  });

  testWidgets('dice quién lo pide y qué período', (tester) async {
    await tester.pumpWidget(app(solicitudes: [solicitud()]));
    await tester.pumpAndSettle();

    expect(find.textContaining('SOLICITA CERRAR'), findsOneWidget);
    // El último día **incluido**, no el fin exclusivo: nadie cierra «hasta el
    // 1 de agosto» un período de julio.
    expect(find.text('2026-07-01 → 2026-07-31'), findsOneWidget);
    expect(find.textContaining('Ana Cadena'), findsOneWidget);
  });

  testWidgets('cargar el período entrega el rango incluido, no el exclusivo', (
    tester,
  ) async {
    DateTime? desde;
    DateTime? hasta;
    await tester.pumpWidget(
      app(
        solicitudes: [solicitud()],
        onCargar: (a, b) {
          desde = a;
          hasta = b;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('CARGAR EL PERÍODO'));
    await tester.pumpAndSettle();

    expect(desde, DateTime(2026, 7, 1));
    expect(hasta, DateTime(2026, 7, 31));
  });

  testWidgets('la fecha comercial no retrocede un día por el huso', (
    tester,
  ) async {
    // El servidor guarda el día de negocio como medianoche UTC. Pasarlo a la
    // zona local le resta las horas del huso y el día retrocede: el aviso
    // enseñaba «2026-07-31 → 2026-08-03» un período pedido del 1 al 4, y
    // cargarlo así habría hecho firmar el cierre de otros días. Visto en el
    // recorrido de escritorio del 18-08-2026, con la sede en
    // `America/Los_Angeles`.
    final desdeElServidor = SolicitudCierreModel.fromJson({
      'solicitud_id': 'ccs-1',
      'tipo_periodo': 'RANGO',
      'fecha_inicio': '2026-08-01T00:00:00.000Z',
      'fecha_fin_exclusiva': '2026-08-05T00:00:00.000Z',
      'estado': 'ABIERTA',
      'solicitada_por': 'Ana Cadena',
    })!;
    DateTime? desde;
    DateTime? hasta;
    await tester.pumpWidget(
      app(
        solicitudes: [desdeElServidor],
        onCargar: (a, b) {
          desde = a;
          hasta = b;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2026-08-01 → 2026-08-04'), findsOneWidget);

    await tester.tap(find.text('CARGAR EL PERÍODO'));
    await tester.pumpAndSettle();

    expect(desde, DateTime(2026, 8, 1));
    expect(hasta, DateTime(2026, 8, 4));
  });

  testWidgets('un plazo vencido se dice con palabras', (tester) async {
    // El color solo no vale: la regla del sistema es punto/guion + texto.
    await tester.pumpWidget(
      app(solicitudes: [solicitud(limite: DateTime(2020, 1, 1))]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Plazo vencido'), findsOneWidget);
  });

  testWidgets('con varias peticiones se puede pasar de una a otra', (
    tester,
  ) async {
    final segunda = SolicitudCierreModel(
      solicitudId: 'ccs-2',
      tipoPeriodo: 'RANGO',
      fechaInicio: DateTime(2026, 8, 1),
      fechaFinExclusiva: DateTime(2026, 8, 5),
      estado: 'ABIERTA',
      solicitadaPor: 'Ana Cadena',
    );
    await tester.pumpWidget(app(solicitudes: [solicitud(), segunda]));
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('2026-07-01 → 2026-07-31'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('2026-08-01 → 2026-08-04'), findsOneWidget);
  });
}
