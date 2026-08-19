import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/dashboard/presentation/widgets/dashboard_sidebar.dart';

/// El sidebar lee la sesión desde M6: el nivel de Dueño de la cadena no es un
/// permiso de sede, así que no puede salir de la lista de permisos. Sin sesión
/// montada —este arnés— no es Dueño, que es lo que estas pruebas comprueban.
Widget _sidebar(Set<String> permissions) => ProviderScope(
  child: MaterialApp(
    home: Scaffold(
      body: DashboardSidebar(
        isDark: false,
        surfaceColor: Colors.white,
        borderColor: Colors.grey,
        selectedIndex: 0,
        onNavigate: (_) {},
        role: 'rol-del-operador',
        permissions: permissions,
        onLogout: () {},
      ),
    ),
  ),
);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('recepción ve su operación y no ve administración', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _sidebar({
        'clientes.leer',
        'clientes.escribir',
        'cobros.registrar',
        'entrenadores.gestionar',
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('CLIENTES'), findsOneWidget);
    expect(find.text('ASISTENCIA'), findsOneWidget);
    expect(find.text('FINANZAS'), findsOneWidget);
    expect(find.text('USUARIOS'), findsNothing);
    expect(find.text('GIMNASIOS'), findsNothing);
    expect(find.text('CONTROL Y CALIDAD'), findsNothing);

    await tester.tap(find.text('FINANZAS'));
    await tester.pumpAndSettle();
    expect(find.text('TRANSACCIONES'), findsOneWidget);
    expect(find.text('CONTABILIDAD'), findsNothing);
  });

  testWidgets('contabilidad ve tesorería y estadística, pero no cobros', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _sidebar({
        'clientes.leer',
        'tesoreria.cerrar',
        'gastos.gobernar',
        'estadisticas.leer',
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('CONTROL Y CALIDAD'), findsOneWidget);
    expect(find.text('FINANZAS'), findsOneWidget);
    expect(find.text('ASISTENCIA'), findsNothing);
    expect(find.text('USUARIOS'), findsNothing);

    await tester.tap(find.text('FINANZAS'));
    await tester.pumpAndSettle();
    expect(find.text('CONTABILIDAD'), findsOneWidget);
    expect(find.text('REVALUACIÓN'), findsOneWidget);
    expect(find.text('TRANSACCIONES'), findsNothing);
  });
}
