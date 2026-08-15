const accountingSectionSummary = 'summary';
const accountingSectionOperationalResults = 'operational-results';
const accountingSectionTreasury = 'treasury';
const accountingSectionExpenses = 'expenses';
const accountingSectionInstallments = 'installments';
const accountingSectionRefunds = 'refunds';
const accountingSectionRules = 'rules';
const accountingSectionPayroll = 'payroll';

Set<String> accountingSectionsFor(Set<String>? permissions) {
  if (permissions == null) {
    return {
      accountingSectionSummary,
      accountingSectionOperationalResults,
      accountingSectionTreasury,
      accountingSectionExpenses,
      accountingSectionInstallments,
      accountingSectionRefunds,
      accountingSectionRules,
      accountingSectionPayroll,
    };
  }

  return {
    accountingSectionSummary,
    if (permissions.contains('estadisticas.leer'))
      accountingSectionOperationalResults,
    if (permissions.contains('tesoreria.cerrar')) accountingSectionTreasury,
    if (permissions.contains('gastos.gobernar')) accountingSectionExpenses,
    if (permissions.contains('configuracion.escribir')) ...{
      accountingSectionInstallments,
      accountingSectionRefunds,
      accountingSectionRules,
      accountingSectionPayroll,
    },
  };
}
