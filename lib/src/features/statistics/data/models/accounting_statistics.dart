class AccountingStatistics {
  const AccountingStatistics({
    required this.zone,
    required this.cutoffDate,
    required this.period,
    required this.currencies,
    required this.warnings,
  });

  final String zone;
  final String cutoffDate;
  final AccountingPeriod period;
  final List<AccountingCurrencySeries> currencies;
  final List<String> warnings;

  factory AccountingStatistics.fromJson(Map<String, dynamic> json) {
    return AccountingStatistics(
      zone: '${json['zona'] ?? 'Etc/UTC'}',
      cutoffDate: '${json['fecha_corte'] ?? ''}',
      period: AccountingPeriod.fromJson(_map(json['periodo'])),
      currencies: _list(
        json['monedas'],
      ).map(AccountingCurrencySeries.fromJson).toList(growable: false),
      warnings: _strings(json['advertencias']),
    );
  }
}

class AccountingPeriod {
  const AccountingPeriod({
    required this.from,
    required this.to,
    required this.months,
  });
  final String from;
  final String to;
  final List<String> months;

  factory AccountingPeriod.fromJson(Map<String, dynamic> json) =>
      AccountingPeriod(
        from: '${json['desde'] ?? ''}',
        to: '${json['hasta'] ?? ''}',
        months: _strings(json['meses']),
      );
}

class AccountingCurrencySeries {
  const AccountingCurrencySeries({
    required this.id,
    required this.code,
    required this.rows,
  });
  final String id;
  final String code;
  final List<AccountingMonthRow> rows;

  factory AccountingCurrencySeries.fromJson(Map<String, dynamic> json) =>
      AccountingCurrencySeries(
        id: '${json['moneda_id'] ?? ''}',
        code: '${json['moneda_codigo'] ?? '—'}',
        rows: _list(
          json['serie'],
        ).map(AccountingMonthRow.fromJson).toList(growable: false),
      );
}

class AccountingMonthRow {
  const AccountingMonthRow({
    required this.month,
    required this.cashIncome,
    required this.cashExpense,
    required this.cashNet,
    required this.paymentTypes,
    required this.accounts,
    required this.accruedExpense,
    required this.expenseCategories,
    required this.recurringCategories,
    required this.directMargin,
    required this.fixedCompensation,
    required this.marginAfterFixed,
    required this.accrualResult,
    required this.resultSign,
    required this.revaluation,
    required this.closures,
    required this.collectors,
    required this.state,
  });

  final String month;
  final String cashIncome;
  final String cashExpense;
  final String cashNet;
  final List<NamedAmount> paymentTypes;
  final List<NamedAmount> accounts;
  final String accruedExpense;
  final List<NamedAmount> expenseCategories;
  final List<RecurringAmount> recurringCategories;
  final String directMargin;
  final String fixedCompensation;
  final String marginAfterFixed;
  final String accrualResult;
  final String resultSign;
  final String revaluation;
  final AccountingClosures closures;
  final List<AccountingCollector> collectors;
  final AccountingState state;

  factory AccountingMonthRow.fromJson(Map<String, dynamic> json) =>
      AccountingMonthRow(
        month: '${json['mes'] ?? ''}',
        cashIncome: _money(json['ingresos_caja']),
        cashExpense: _money(json['egresos_caja']),
        cashNet: _money(json['neto_caja']),
        paymentTypes: _list(
          json['ingresos_por_tipo_pago'],
        ).map(NamedAmount.fromJson).toList(growable: false),
        accounts: _list(json['ingresos_por_cuenta'])
            .map(
              (row) => NamedAmount(
                id: '${row['cuenta_id'] ?? ''}',
                name: '${row['cuenta_nombre'] ?? 'Sin cuenta'}',
                amount: _money(row['importe']),
              ),
            )
            .toList(growable: false),
        accruedExpense: _money(json['gasto_devengado']),
        expenseCategories: _list(
          json['gasto_por_categoria'],
        ).map(NamedAmount.fromJson).toList(growable: false),
        recurringCategories: _list(
          json['gasto_recurrente_previsto'],
        ).map(RecurringAmount.fromJson).toList(growable: false),
        directMargin: _money(json['margen_directo']),
        fixedCompensation: _money(json['fijo_no_distribuido']),
        marginAfterFixed: _money(json['margen_menos_fijo']),
        accrualResult: _money(json['resultado_operativo_devengado']),
        resultSign: '${json['resultado_signo'] ?? 'NEUTRO'}',
        revaluation: _money(json['revaluacion_cambiaria']),
        closures: AccountingClosures.fromJson(_map(json['cierres'])),
        collectors: _list(
          json['cobros_por_recepcionista'],
        ).map(AccountingCollector.fromJson).toList(growable: false),
        state: AccountingState.fromJson(_map(json['estado'])),
      );
}

class NamedAmount {
  const NamedAmount({
    required this.id,
    required this.name,
    required this.amount,
  });
  final String id;
  final String name;
  final String amount;
  double get value => double.tryParse(amount) ?? 0;

  factory NamedAmount.fromJson(Map<String, dynamic> json) => NamedAmount(
    id: '${json['id'] ?? ''}',
    name: '${json['nombre'] ?? 'Sin nombre'}',
    amount: _money(json['importe']),
  );
}

class RecurringAmount extends NamedAmount {
  const RecurringAmount({
    required super.id,
    required super.name,
    required super.amount,
    required this.templates,
  });
  final int templates;
  factory RecurringAmount.fromJson(Map<String, dynamic> json) =>
      RecurringAmount(
        id: '${json['id'] ?? ''}',
        name: '${json['nombre'] ?? 'Sin nombre'}',
        amount: _money(json['importe']),
        templates: _integer(json['plantillas']),
      );
}

class AccountingClosures {
  const AccountingClosures({
    required this.count,
    required this.expected,
    required this.counted,
    required this.difference,
  });
  final int count;
  final String expected;
  final String counted;
  final String difference;
  factory AccountingClosures.fromJson(Map<String, dynamic> json) =>
      AccountingClosures(
        count: _integer(json['cantidad']),
        expected: _money(json['saldo_esperado']),
        counted: _money(json['saldo_contado']),
        difference: _money(json['diferencia']),
      );
}

class AccountingCollector {
  const AccountingCollector({
    required this.name,
    required this.payments,
    required this.clients,
    required this.net,
    required this.historical,
  });
  final String name;
  final int payments;
  final int clients;
  final String net;
  final bool historical;
  factory AccountingCollector.fromJson(Map<String, dynamic> json) =>
      AccountingCollector(
        name: '${json['nombre'] ?? 'Sin atribuir · histórico'}',
        payments: _integer(json['pagos']),
        clients: _integer(json['clientes']),
        net: _money(json['neto']),
        historical: json['historico_sin_atribuir'] == true,
      );
}

class AccountingState {
  const AccountingState({
    required this.accrual,
    required this.certified,
    required this.revaluation,
  });
  final String accrual;
  final bool certified;
  final String revaluation;
  factory AccountingState.fromJson(Map<String, dynamic> json) =>
      AccountingState(
        accrual: '${json['devengo'] ?? ''}',
        certified: json['certificado'] == true,
        revaluation: '${json['revaluacion'] ?? ''}',
      );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};
List<Map<String, dynamic>> _list(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
    : const [];
List<String> _strings(Object? value) => value is List
    ? value.map((item) => '$item').toList(growable: false)
    : const [];
String _money(Object? value) => '${value ?? '0.00'}';
int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
