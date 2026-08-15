import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/dashboard/domain/dashboard_access_policy.dart';

void main() {
  test(
    'recepción entra a clientes, asistencia y cobros, no a configuración',
    () {
      final permissions = {
        'clientes.leer',
        'clientes.escribir',
        'cobros.registrar',
        'entrenadores.gestionar',
      };

      expect(dashboardIndexAllowed(1, permissions), isTrue);
      expect(dashboardIndexAllowed(7, permissions), isTrue);
      expect(dashboardIndexAllowed(3, permissions), isTrue);
      expect(dashboardIndexAllowed(5, permissions), isFalse);
      expect(dashboardIndexAllowed(20, permissions), isFalse);
    },
  );

  test('contabilidad entra a tesorería y estadísticas, no a cobros', () {
    final permissions = {
      'clientes.leer',
      'tesoreria.cerrar',
      'gastos.gobernar',
      'estadisticas.leer',
    };

    expect(dashboardIndexAllowed(20, permissions), isTrue);
    expect(dashboardIndexAllowed(34, permissions), isTrue);
    expect(dashboardIndexAllowed(3, permissions), isFalse);
    expect(dashboardIndexAllowed(12, permissions), isFalse);
  });

  test(
    'entrenador no hereda vistas financieras por poder leer estadísticas',
    () {
      final permissions = {'clientes.leer', 'estadisticas.leer'};

      expect(dashboardIndexAllowed(1, permissions), isTrue);
      expect(dashboardIndexAllowed(20, permissions), isFalse);
      expect(dashboardIndexAllowed(26, permissions), isFalse);
      expect(dashboardIndexAllowed(35, permissions), isFalse);
    },
  );

  test('un índice desconocido y una sesión sin permisos fallan cerrados', () {
    expect(dashboardIndexAllowed(999, {}), isFalse);
    expect(dashboardIndexAllowed(1, {}), isFalse);
    expect(dashboardIndexAllowed(0, {}), isTrue);
  });
}
