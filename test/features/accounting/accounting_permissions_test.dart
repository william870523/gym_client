import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/accounting/domain/accounting_access_policy.dart';

void main() {
  test('contabilidad solo recibe secciones cubiertas por su sesión', () {
    final sections = accountingSectionsFor({
      'clientes.leer',
      'tesoreria.cerrar',
      'gastos.gobernar',
      'estadisticas.leer',
    });

    expect(sections, contains(accountingSectionSummary));
    expect(sections, contains(accountingSectionTreasury));
    expect(sections, contains(accountingSectionExpenses));
    expect(sections, contains(accountingSectionOperationalResults));
    expect(sections, isNot(contains(accountingSectionInstallments)));
    expect(sections, isNot(contains(accountingSectionRefunds)));
    expect(sections, isNot(contains(accountingSectionRules)));
    expect(sections, isNot(contains(accountingSectionPayroll)));
  });

  test('modo administrador conserva todas las secciones', () {
    expect(accountingSectionsFor(null), hasLength(8));
  });
}
