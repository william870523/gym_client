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

/// El panel del plus multi-sede en el expediente (M4a).
///
/// Lo que se fija aquí es lo que un operador necesita distinguir de un vistazo:
/// **si tiene el plus, si todavía cubre y si él puede venderlo**. Los tres se
/// comunican con texto, no solo con color, que es el principio 5 de PULSO y la
/// diferencia entre una vista usable y una bonita.
void main() {
  const ci = '91021020015';

  MultisedeAccessModel acceso({required bool vigente, bool activo = true}) =>
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
      );

  Widget app({
    MultisedeAccessModel? fila,
    MultisedePriceModel? precio = const MultisedePriceModel(
      precio: 150,
      monedaId: 'cup',
    ),
    List<String> permisos = const ['clientes.leer', 'clientes.escribir'],
  }) => ProviderScope(
    overrides: [
      authProvider.overrideWith(() => _Auth(permisos)),
      multisedeAccesoProvider(ci).overrideWith((_) async => fila),
      multisedePrecioProvider.overrideWith((_) async => precio),
    ],
    child: const MaterialApp(
      home: PulsoThemeScope(
        child: Scaffold(body: MultisedeAccessPanel(ci: ci)),
      ),
    ),
  );

  testWidgets('sin acceso ofrece activarlo y dice cuánto cuesta', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('SIN ACCESO'), findsOneWidget);
    expect(find.text('Este socio solo entrena en su sede.'), findsOneWidget);
    expect(find.text('Tarifa de cadena: 150.00'), findsOneWidget);
    expect(find.text('ACTIVAR ACCESO'), findsOneWidget);
    // Retirar no se ofrece cuando no hay nada que retirar.
    expect(find.text('RETIRAR'), findsNothing);
  });

  testWidgets('con el plus vigente enseña hasta cuándo y ofrece renovar', (
    tester,
  ) async {
    await tester.pumpWidget(app(fila: acceso(vigente: true)));
    await tester.pumpAndSettle();

    expect(find.text('VIGENTE'), findsOneWidget);
    expect(find.text('15/09/2026'), findsOneWidget);
    // `vigente_hasta` es exclusiva y la vista lo dice con todas las letras:
    // el día que figura ya no cubre.
    expect(find.textContaining('SIN INCLUIRLO'), findsOneWidget);
    expect(find.text('RENOVAR UN MES'), findsOneWidget);
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
      find.widgetWithText(FilledButton, 'ACTIVAR ACCESO'),
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
