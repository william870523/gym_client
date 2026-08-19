import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_theme.dart';
import 'package:gym_client/src/features/accounting/data/models/saldo_enlace_models.dart';
import 'package:gym_client/src/features/accounting/presentation/state/saldo_enlace_providers.dart';
import 'package:gym_client/src/features/accounting/presentation/widgets/saldo_enlace_panel.dart';

/// M8 — el contrato con el servidor, contra respuestas **reales**.
///
/// Las otras pruebas de este panel usan fixtures escritas a mano, y esas no
/// pueden detectar el fallo que más caro sale: que el servidor publique una
/// clave con otro nombre —`saldo_antes` frente a `saldoAntes`, `acreedor.nombre`
/// frente a `acreedor_nombre`— y el cliente enseñe ceros sin dar ningún error.
/// Ya pasó en M6: el detalle publicaba el período en camelCase y el cliente lo
/// leía en snake_case, así que la pantalla mostraba un período vacío y nadie se
/// enteró hasta caminarlo.
///
/// Los ficheros de `fixtures/` son la respuesta literal del concentrador,
/// capturada el 19-08-2026 contra las deudas reales de `local-gym-001`: las tres
/// liquidaciones del recorrido —una de ellas anulada— más las tres que siembra
/// la fixture paritaria `demo:liquidacion-saldo-m8`.
void main() {
  Map<String, dynamic> leer(String nombre) {
    final ruta = File(
      'test/features/accounting/fixtures/saldo_enlace_$nombre.json',
    );
    return (jsonDecode(ruta.readAsStringSync()) as Map).cast<String, dynamic>();
  }

  test('el saldo real se lee entero, sin ceros de relleno', () {
    final saldo = SaldoSedeModel.fromJson(leer('pendientes'));

    expect(saldo.gymId, 'local-gym-001');
    expect(saldo.nombre, 'Gym Test');
    expect(saldo.lineas, hasLength(2));

    final cadena = saldo.lineas.firstWhere((l) => l.acreedor.esCadena);
    expect(cadena.acreedor.nombre, 'La cadena');
    expect(cadena.acreedor.gymId, isNull);
    expect(cadena.aFavor, isTrue, reason: 'pagó de más: no está en paz');
    expect(cadena.saldado, isFalse);

    // La deuda que la anulación devolvió: estaba saldada y volvió a estar viva.
    final sede = saldo.lineas.firstWhere((l) => !l.acreedor.esCadena);
    expect(sede.acreedor.gymId, 'dtc-gym-ajeno');
    expect(sede.acreedor.nombre, 'Sede Ajena DEMO (R5.4)');
    expect(sede.saldo, '200.00');
    expect(sede.saldado, isFalse);
    expect(sede.aFavor, isFalse);
    expect(saldo.pendientes.map((p) => p.saldo), ['200.00']);
  });

  test('la anulada llega marcada, con su motivo y con quién la anuló', () {
    // Es el caso que ninguna fixture escrita a mano prueba de verdad: quien
    // registró y quien anuló son personas distintas, y las dos tienen que
    // sobrevivir al viaje.
    final filas = [
      for (final fila in leer('liquidaciones')['liquidaciones'] as List)
        LiquidacionModel.fromJson((fila as Map).cast<String, dynamic>()),
    ];
    final anuladas = filas.where((f) => f.anulada).toList();
    expect(anuladas, isNotEmpty);
    for (final fila in anuladas) {
      expect(fila.estado, 'ANULADA');
      expect(fila.anuladaMotivo, isNotNull);
      expect(fila.anuladaMotivo, isNotEmpty);
      expect(fila.anuladaPor, isNotNull);
    }
    // Y las vigentes no traen rastro de anulación: el estado no se contagia.
    for (final fila in filas.where((f) => !f.anulada)) {
      expect(fila.anuladaMotivo, isNull);
      expect(fila.anuladaPor, isNull);
    }
  });

  test('las liquidaciones reales conservan referencia, actor y foto del saldo', () {
    final filas = [
      for (final fila in leer('liquidaciones')['liquidaciones'] as List)
        LiquidacionModel.fromJson((fila as Map).cast<String, dynamic>()),
    ];

    expect(filas, hasLength(6));
    // De la más reciente a la más antigua: quien abre esto busca la última.
    expect(filas.first.liquidacionId, 'liq-m8-recorrido-3');

    final deMas = filas.firstWhere((f) => f.dejoSaldoAFavor);
    expect(deMas.acreedor.esCadena, isTrue);
    expect(deMas.monto, '1000.00');
    expect(deMas.saldoAntes, '900.00');
    expect(deMas.saldoDespues, '-100.00');

    final conReferencia = filas.firstWhere((f) => f.referencia != null);
    expect(conReferencia.referencia, startsWith('TRF-'));
    // El actor va congelado: la cuenta que las firmó ya está dada de baja, y
    // el nombre tiene que seguir ahí.
    expect(conReferencia.registradaPor, 'Verificación remota');
    expect(conReferencia.ocurridoAt, isNotNull);
  });

  test('los importes llegan con sus dos decimales, también al reintentar', () {
    // El reintento devolvía «550» donde la primera respuesta decía «550.00»:
    // Prisma entrega el Decimal sin decimales. Se arregló en el servidor, y
    // esta fixture es la prueba de que sigue arreglado.
    final filas = [
      for (final fila in leer('liquidaciones')['liquidaciones'] as List)
        LiquidacionModel.fromJson((fila as Map).cast<String, dynamic>()),
    ];
    for (final fila in filas) {
      for (final importe in [fila.monto, fila.saldoAntes, fila.saldoDespues]) {
        expect(
          importe,
          matches(RegExp(r'^-?\d+\.\d{2}$')),
          reason: '«$importe» no trae los dos decimales',
        );
      }
    }
  });

  testWidgets('el panel pintado con la respuesta real dice lo que dice la base', (
    tester,
  ) async {
    // Lo más cerca de un recorrido que se puede fijar en una prueba: los mismos
    // bytes que devolvió el concentrador, atravesando el modelo y llegando a la
    // pantalla. Si el servidor renombra una clave, esto se cae aquí y no en la
    // cara de quien está a punto de transferir dinero.
    const gymId = 'local-gym-001';
    final saldo = SaldoSedeModel.fromJson(leer('pendientes'));
    final liquidaciones = [
      for (final fila in leer('liquidaciones')['liquidaciones'] as List)
        LiquidacionModel.fromJson((fila as Map).cast<String, dynamic>()),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saldoDeSedeProvider(gymId).overrideWith((_) async => saldo),
          liquidacionesDeSedeProvider(gymId).overrideWith((_) async => liquidaciones),
        ],
        child: MaterialApp(
          home: PulsoThemeScope(
            child: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 1200,
                  child: SaldoEnlacePanel(gymId: gymId, nombreSede: 'Gym Test'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SALDO ENTRE SEDES'), findsOneWidget);
    expect(find.text('La cadena'), findsWidgets);
    expect(find.text('Sede Ajena DEMO (R5.4)'), findsWidgets);
    // Pagado de más: la línea que se parece a una saldada y pide lo contrario.
    expect(find.textContaining('PAGADO DE MÁS'), findsOneWidget);
    // Y la deuda que la anulación devolvió a la vida: sí se puede liquidar.
    expect(find.byTooltip('Registrar la transferencia'), findsOneWidget);
    // El historial, con la referencia y el actor congelado.
    expect(find.textContaining('TRF-20260819-0042'), findsOneWidget);
    expect(find.text('900.00 → -100.00'), findsOneWidget);
    // Las anuladas siguen ahí, marcadas y con su motivo.
    expect(find.text('ANULADA'), findsNWidgets(2));
    expect(find.textContaining('Destino equivocado'), findsWidgets);
  });
}
