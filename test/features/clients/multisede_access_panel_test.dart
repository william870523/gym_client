import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_theme.dart';
import 'package:gym_client/src/features/auth/domain/models/user.dart';
import 'package:gym_client/src/features/auth/presentation/state/auth_notifier.dart';
import 'package:gym_client/src/features/clients/data/models/multisede_access_model.dart';
import 'package:gym_client/src/features/clients/data/repositories/multisede_access_repository.dart';
import 'package:gym_client/src/features/clients/presentation/widgets/multisede_access_panel.dart';
import 'package:gym_client/src/features/financials/data/models/account_model.dart';
import 'package:gym_client/src/features/payments/presentation/state/payment_notifier.dart';

/// El panel del plus multi-sede en el expediente (M4a).
///
/// Lo que se fija aquí es lo que un operador necesita distinguir de un vistazo:
/// **si tiene el plus, si todavía cubre y si él puede venderlo**. Los tres se
/// comunican con texto, no solo con color, que es el principio 5 de PULSO y la
/// diferencia entre una vista usable y una bonita.
void main() {
  const ci = '91021020015';

  MultisedeAccessModel acceso({
    required bool vigente,
    bool activo = true,
    // La fecha de negocio la manda el servidor; la vista no la deduce del
    // reloj del equipo. Fijarla aquí es lo que hace la prueba determinista.
    DateTime? fechaNegocio,
  }) =>
      MultisedeAccessModel(
        id: 'cam-1',
        ci: ci,
        gymIdOrigen: 'gym-test',
        activo: activo,
        vigenteHasta: DateTime.utc(2026, 9, 15),
        vigente: vigente,
        precioSnapshot: 150,
        monedaId: 'cup',
        marcadoPorUserId: 'user-rosa',
        marcadoEnGymId: 'gym-test',
        version: 1,
        fechaNegocio: fechaNegocio ?? DateTime.utc(2026, 8, 17),
      );

  Widget app({
    MultisedeAccessModel? fila,
    MultisedePriceModel? precio = const MultisedePriceModel(
      precio: 150,
      monedaId: 'cup',
    ),
    List<String> permisos = const ['clientes.leer', 'clientes.escribir'],
    MultisedeAccessRepository? repositorio,
  }) => ProviderScope(
    overrides: [
      authProvider.overrideWith(() => _Auth(permisos)),
      multisedeAccesoProvider(ci).overrideWith((_) async => fila),
      multisedePrecioProvider.overrideWith((_) async => precio),
      accountsProvider.overrideWith((_) async => [
        AccountModel(id: 'caja-cup', name: 'Efectivo caja CUP', currencyId: 'cup'),
      ]),
      if (repositorio != null)
        multisedeAccessRepositoryProvider.overrideWithValue(repositorio),
    ],
    child: const MaterialApp(
      home: PulsoThemeScope(
        child: Scaffold(body: MultisedeAccessPanel(ci: ci)),
      ),
    ),
  );

  testWidgets('sin acceso ofrece venderlo y dice cuánto cuesta', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('SIN ACCESO'), findsOneWidget);
    expect(find.text('Este socio solo entrena en su sede.'), findsOneWidget);
    expect(find.text('Tarifa de cadena: 150.00'), findsOneWidget);
    expect(find.text('VENDER ACCESO'), findsOneWidget);
    // Retirar no se ofrece cuando no hay nada que retirar.
    expect(find.text('RETIRAR'), findsNothing);
  });

  testWidgets('con el plus vigente enseña hasta cuándo y ofrece cobrar el mes', (
    tester,
  ) async {
    await tester.pumpWidget(app(fila: acceso(vigente: true)));
    await tester.pumpAndSettle();

    expect(find.text('VIGENTE'), findsOneWidget);
    expect(find.text('15/09/2026'), findsOneWidget);
    // `vigente_hasta` es exclusiva y la vista lo dice con todas las letras:
    // el día que figura ya no cubre.
    expect(find.textContaining('SIN INCLUIRLO'), findsOneWidget);
    expect(find.text('COBRAR UN MES'), findsOneWidget);
    expect(find.text('RETIRAR'), findsOneWidget);
  });

  testWidgets('el plus vencido se distingue del vigente, no solo por color', (
    tester,
  ) async {
    await tester.pumpWidget(app(fila: acceso(vigente: false)));
    await tester.pumpAndSettle();

    expect(find.text('VENCIDO'), findsOneWidget);
    expect(find.text('YA NO CUBRE'), findsOneWidget);
  });

  testWidgets('sin precio de cadena avisa de que no se puede vender', (
    tester,
  ) async {
    await tester.pumpWidget(app(precio: null));
    await tester.pumpAndSettle();

    expect(
      find.text('Sin precio de cadena configurado: no se puede vender todavía.'),
      findsOneWidget,
    );
  });

  testWidgets('quien no puede escribir socios no puede venderlo', (
    tester,
  ) async {
    await tester.pumpWidget(app(permisos: const ['clientes.leer']));
    await tester.pumpAndSettle();

    final boton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'VENDER ACCESO'),
    );
    expect(boton.onPressed, isNull);
    expect(
      find.text('SOLO RECEPCIÓN Y ADMINISTRACIÓN LO VENDEN'),
      findsOneWidget,
    );
  });

  testWidgets('lo que pagó y la tarifa de hoy se enseñan juntos si cambiaron', (
    tester,
  ) async {
    // Congelar el precio al vender es inútil si la vista no deja ver los dos
    // números: la discusión en el mostrador es exactamente esa.
    await tester.pumpWidget(
      app(
        fila: acceso(vigente: true),
        precio: const MultisedePriceModel(precio: 180, monedaId: 'cup'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pagó 150.00 · tarifa hoy 180.00'), findsOneWidget);
  });

  // ===== M4b: el botón mueve dinero =====

  testWidgets('cobrar pide confirmación y dice qué periodo compra', (
    tester,
  ) async {
    // El paso intermedio existe porque este botón mueve dinero y el resto del
    // panel no. Sin él, un clic de más vende un mes.
    await tester.pumpWidget(app(fila: acceso(vigente: true)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('COBRAR UN MES'));
    await tester.pumpAndSettle();

    expect(find.text('CONFIRMAR COBRO'), findsOneWidget);
    expect(find.text('150.00'), findsOneWidget);
    // Encadena desde el fin vigente, no desde hoy: es la duda del mostrador.
    expect(find.text('cubre 15/09/2026 → 15/10/2026'), findsOneWidget);
    expect(find.text('COBRAR'), findsOneWidget);
  });

  testWidgets('con el plus caducado cobra desde la fecha de negocio del servidor', (
    tester,
  ) async {
    // Regresión del recorrido web del 17-08-2026: la confirmación prometía
    // 17/08 → 17/09 y el servidor cobró 16/08 → 16/09, porque la vista deducía
    // «hoy» del reloj del equipo en UTC mientras la sede vivía en
    // America/Los_Angeles. Un día de diferencia en un comprobante de dinero no
    // es un detalle: es una fecha que el socio lee y que no coincide.
    await tester.pumpWidget(
      app(
        fila: acceso(vigente: false, fechaNegocio: DateTime.utc(2026, 8, 16)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('COBRAR UN MES'));
    await tester.pumpAndSettle();

    expect(find.text('cubre 16/08/2026 → 16/09/2026'), findsOneWidget);
  });

  testWidgets('la confirmación avisa de que el ingreso no es de esta sede', (
    tester,
  ) async {
    // El aviso que impide el error contable más caro (§7.10), dicho ANTES de
    // cobrar y no en un informe de fin de mes donde ya no se puede hacer nada.
    await tester.pumpWidget(app(fila: acceso(vigente: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('COBRAR UN MES'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('el ingreso es de la cadena'),
      findsOneWidget,
    );
    expect(find.text('CAJA DONDE ENTRA EL EFECTIVO'), findsOneWidget);
  });

  // El cobro es la única acción del panel que abre un formulario, así que es la
  // que puede desbordar. Se comprueba en los cuatro anchos de referencia,
  // incluida la ventana baja de 1024×650 en la que trabajan las recepciones con
  // monitor pequeño. Un desbordamiento en Flutter falla la prueba solo.
  for (final entry in const <String, Size>{
    'compacto': Size(390, 844),
    'mediano': Size(760, 900),
    'ventana baja': Size(1024, 650),
    'escritorio': Size(1280, 900),
  }.entries) {
    testWidgets('la confirmación del cobro cabe en ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(app(fila: acceso(vigente: true)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('COBRAR UN MES'));
      await tester.pumpAndSettle();

      expect(find.text('CONFIRMAR COBRO'), findsOneWidget);
      expect(find.text('COBRAR'), findsOneWidget);
      expect(find.textContaining('el ingreso es de la cadena'), findsOneWidget);
    });
  }

  testWidgets('cancelar no cobra nada', (tester) async {
    final repo = _RepoEspia();
    await tester.pumpWidget(
      app(fila: acceso(vigente: true), repositorio: repo),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('COBRAR UN MES'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();

    expect(repo.cobros, 0);
    expect(find.text('COBRAR UN MES'), findsOneWidget);
  });

  testWidgets('al cobrar deja el comprobante a la vista, no un aviso que se va', (
    tester,
  ) async {
    // Es lo que el operador lee en voz alta al socio, y lo que mira si el
    // socio pregunta «¿hasta cuándo me cubre?» treinta segundos después.
    final repo = _RepoEspia();
    await tester.pumpWidget(
      app(fila: acceso(vigente: true), repositorio: repo),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('COBRAR UN MES'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('COBRAR'));
    await tester.pumpAndSettle();

    expect(repo.cobros, 1);
    expect(
      find.text('Cobrado 150.00 · cubre 15/09/2026 → 15/10/2026'),
      findsOneWidget,
    );
    expect(find.text('INGRESO DE CADENA · EFECTIVO EN GYM-TEST'), findsOneWidget);
  });

  testWidgets('el motivo del rechazo se queda fijado en el panel', (
    tester,
  ) async {
    final repo = _RepoEspia(
      falla: 'El acceso multi-sede no tiene precio configurado.',
    );
    await tester.pumpWidget(
      app(fila: acceso(vigente: true), repositorio: repo),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('COBRAR UN MES'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('COBRAR'));
    await tester.pumpAndSettle();

    expect(
      find.text('El acceso multi-sede no tiene precio configurado.'),
      findsOneWidget,
    );
  });
}

/// Repositorio de mentira: cuenta los cobros y puede fallar a voluntad.
class _RepoEspia implements MultisedeAccessRepository {
  _RepoEspia({this.falla});

  final String? falla;
  int cobros = 0;

  @override
  Future<({MultisedeAccessModel? acceso, MultisedeCobroModel? cobro})> cobrar(
    String ci, {
    String? cuentaId,
    String? tipoPagoId,
  }) async {
    cobros += 1;
    if (falla != null) throw Exception(falla);
    return (
      acceso: null,
      cobro: MultisedeCobroModel(
        cobroId: 'cob-1',
        ci: ci,
        importe: 150,
        monedaId: 'cup',
        cubreDesde: DateTime.utc(2026, 9, 15),
        cubreHasta: DateTime.utc(2026, 10, 15),
        cobradoEnGymId: 'gym-test',
        ingresoDe: 'CADENA',
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('El panel no debería llamar a $invocation.');
}

class _Auth extends AuthNotifier {
  _Auth(this.permisos);

  final List<String> permisos;

  @override
  FutureOr<User?> build() => User(
    id: 'user-rosa',
    name: 'Rosa Recepción',
    email: 'rosa@gym.test',
    role: 'reception',
    permissions: permisos,
  );
}
