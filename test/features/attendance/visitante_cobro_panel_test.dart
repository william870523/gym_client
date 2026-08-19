import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_theme.dart';
import 'package:gym_client/src/features/attendance/presentation/widgets/visitante_cobro_panel.dart';
import 'package:gym_client/src/features/clients/data/models/multisede_access_model.dart';
import 'package:gym_client/src/features/clients/data/repositories/multisede_access_repository.dart';
import 'package:gym_client/src/features/configuration/data/models/payment_type_model.dart';
import 'package:gym_client/src/features/financials/data/models/account_model.dart';
import 'package:gym_client/src/features/payments/presentation/state/payment_notifier.dart';

/// Cobrar el plan de un visitante desde el mostrador (M4c).
///
/// Lo que se fija aquí es lo que quien atiende necesita saber **antes** de
/// cobrar: de dónde sale el total, de cuándo es el precio, y de quién será el
/// ingreso. Las tres se comunican con texto; ninguna depende del color.
void main() {
  const ci = '99090100009';

  CotizacionVisitaModel cotizacion({
    double recargo = 0,
    int diasAtraso = 0,
    int antiguedad = 0,
    int? cuota,
  }) => CotizacionVisitaModel(
    ci: ci,
    gymIdOrigen: 'gym-oeste',
    planCodigo: 'MEN',
    planNombre: 'Mensual',
    monedaId: 'cup',
    precioLista: 300,
    base: 300,
    recargoMora: recargo,
    total: 300 + recargo,
    diasAtraso: diasAtraso,
    categoriaCliente: 'NUEVO',
    antiguedadDias: antiguedad,
    cuotaNumero: cuota,
  );

  Widget app({
    CotizacionVisitaRespuesta? respuesta,
    MultisedeAccessRepository? repositorio,
  }) => ProviderScope(
    overrides: [
      cotizacionVisitaProvider(ci).overrideWith(
        (_) async =>
            respuesta ?? CotizacionVisitaRespuesta(cotizacion: cotizacion(), motivo: null),
      ),
      accountsProvider.overrideWith((_) async => [
        AccountModel(id: 'caja', name: 'Efectivo caja CUP', currencyId: 'cup'),
      ]),
      paymentTypesProvider.overrideWith((_) async => [
        PaymentTypeModel(id: 'tp-1', name: 'Efectivo', active: true, isDeleted: false),
      ]),
      if (repositorio != null)
        multisedeAccessRepositoryProvider.overrideWithValue(repositorio),
    ],
    child: MaterialApp(
      home: PulsoThemeScope(
        child: Scaffold(
          body: VisitanteCobroPanel(ci: ci, nombre: 'Adela Sede Ajena', onCerrar: () {}),
        ),
      ),
    ),
  );

  testWidgets('enseña de dónde sale el total antes de cobrarlo', (tester) async {
    // Un importe sin desglose obliga a quien atiende a defenderlo de memoria
    // cuando el socio pregunta por qué no paga lo mismo que en su sede.
    await tester.pumpWidget(app(
      respuesta: CotizacionVisitaRespuesta(
        cotizacion: cotizacion(recargo: 25, diasAtraso: 7),
        motivo: null,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('325.00'), findsOneWidget);
    expect(find.text('300.00'), findsOneWidget);
    expect(find.textContaining('7 d de atraso'), findsOneWidget);
  });

  testWidgets('dice de cuándo es el precio, sin disimularlo', (tester) async {
    // La cotización es una foto tomada por su sede y puede estar vieja. No se
    // puede impedir sin conexión; lo que sí se puede es decirlo.
    await tester.pumpWidget(app(
      respuesta: CotizacionVisitaRespuesta(
        cotizacion: cotizacion(antiguedad: 45),
        motivo: null,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('PRECIO DE SU SEDE, DE HACE 45 D'), findsOneWidget);
  });

  testWidgets('avisa de que el ingreso es de la otra sede antes de cobrar', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('el ingreso es de gym-oeste'), findsOneWidget);
  });

  testWidgets('sin método de pago el botón no deja cobrar', (tester) async {
    // El servidor lo exige —el detalle dice CÓMO se pagó— y bloquearlo aquí
    // evita mandar una petición que ya se sabe que va a fallar.
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final boton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'COBRAR'),
    );
    expect(boton.onPressed, isNull);
  });

  testWidgets('cuando no se le puede cobrar, enseña el motivo del servidor', (
    tester,
  ) async {
    await tester.pumpWidget(app(
      respuesta: const CotizacionVisitaRespuesta(
        cotizacion: null,
        motivo: 'No hay cotización de visita para este socio: solo puede pagar en su sede.',
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No hay cotización de visita para este socio: solo puede pagar en su sede.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'COBRAR'), findsNothing);
  });

  testWidgets('al cobrar deja el comprobante con las dos sedes', (tester) async {
    // El comprobante dice dónde entró el dinero Y de quién es el ingreso: es lo
    // que el operador lee en voz alta y lo que evita la discusión de fin de mes.
    final repo = _RepoEspia();
    await tester.pumpWidget(app(repositorio: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Efectivo').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'COBRAR'));
    await tester.pumpAndSettle();

    expect(repo.cobros, 1);
    expect(find.text('Cobrado 300.00 · MEN'), findsOneWidget);
    expect(
      find.text('INGRESO DE GYM-OESTE · EFECTIVO EN GYM-TEST'),
      findsOneWidget,
    );
  });
}

/// Repositorio de mentira: cuenta los cobros y no toca la red.
class _RepoEspia implements MultisedeAccessRepository {
  int cobros = 0;

  @override
  Future<CobroCruzadoModel?> cobrarVisitante(
    String ci, {
    required String tipoPagoId,
    String? cuentaId,
  }) async {
    cobros += 1;
    return CobroCruzadoModel(
      pagoClienteId: 'pago-1',
      ci: ci,
      total: 300,
      recargoMora: 0,
      ingresoDe: 'gym-oeste',
      cobradoEnGymId: 'gym-test',
      planCodigo: 'MEN',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('El panel no debería llamar a $invocation.');
}
