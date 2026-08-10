import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_charts.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/accounting_statistics.dart';
import '../state/statistics_providers.dart';
import 'statistics_shared.dart';

/// E4: la superficie visual de los informes contables canónicos.
///
/// Flutter solo selecciona y dibuja. Todos los importes, signos, agrupaciones
/// y estados de certificación llegan ya resueltos desde la API.
class StatisticsAccountingPulsoView extends ConsumerStatefulWidget {
  const StatisticsAccountingPulsoView({super.key});

  @override
  ConsumerState<StatisticsAccountingPulsoView> createState() =>
      _StatisticsAccountingPulsoViewState();
}

class _StatisticsAccountingPulsoViewState
    extends ConsumerState<StatisticsAccountingPulsoView> {
  String? _currencyId;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountingStatisticsProvider);
    return PulsoThemeScope(
      child: Builder(
        builder: (context) => ColoredBox(
          color: PulsoTokens.of(context).floor,
          child: state.when(
            loading: () => const PulsoStateView(
              kind: PulsoStateKind.loading,
              message: 'Leyendo Tesorería, devengo y revaluación canónicos…',
            ),
            error: (error, _) => PulsoStateView(
              kind: PulsoStateKind.error,
              message:
                  'No se pudo abrir la contabilidad gráfica.\n'
                  '${statisticsErrorMessage(error)}',
              onRetry: () => ref.invalidate(accountingStatisticsProvider),
            ),
            data: (data) => _body(context, data),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AccountingStatistics data) {
    if (data.currencies.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: PulsoStateView(
          kind: PulsoStateKind.empty,
          message:
              'No hay movimientos ni datos devengados en los últimos seis meses.',
        ),
      );
    }
    final selected = data.currencies.firstWhere(
      (currency) => currency.id == _currencyId,
      orElse: () => data.currencies.first,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final medium =
            constraints.maxWidth >= 600 && constraints.maxWidth < 840;
        final padding = compact
            ? 16.0
            : medium
            ? 20.0
            : 28.0;
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StatsHeader(
                etiqueta: 'Finanzas · E4',
                titulo: 'CONTABILIDAD GRÁFICA',
                descripcion:
                    'Caja, margen, gasto gobernado, arqueos y revaluación en una '
                    'sola lectura. Cada cifra conserva su moneda y el estado del '
                    'informe canónico que la produjo.',
              ),
              const SizedBox(height: 14),
              _controls(data, selected),
              const SizedBox(height: 14),
              _summary(selected),
              const SizedBox(height: 14),
              _responsivePair(
                compact: compact || medium,
                left: _incomePanel(selected),
                right: _resultPanel(selected),
              ),
              const SizedBox(height: 14),
              _responsivePair(
                compact: compact,
                left: _paymentPanel(selected),
                right: _accountPanel(selected),
              ),
              const SizedBox(height: 14),
              _responsivePair(
                compact: compact || medium,
                left: _expensePanel(selected),
                right: _closurePanel(selected),
              ),
              const SizedBox(height: 14),
              _collectorPanel(selected),
              const SizedBox(height: 14),
              _tablePanel(context, data, selected),
              const SizedBox(height: 10),
              Text(
                'Zona ${data.zone} · corte ${data.cutoffDate}. '
                '${data.warnings.join(' ')}',
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 9,
                  height: 1.5,
                  color: PulsoTokens.of(context).muted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _controls(
    AccountingStatistics data,
    AccountingCurrencySeries selected,
  ) {
    return PulsoPanel(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const PulsoLabel('MONEDA'),
          for (final currency in data.currencies)
            if (currency.id == selected.id)
              PulsoPrimaryButton(
                key: ValueKey('contabilidad-moneda-${currency.id}'),
                label: currency.code,
                onPressed: () => setState(() => _currencyId = currency.id),
              )
            else
              PulsoSecondaryButton(
                key: ValueKey('contabilidad-moneda-${currency.id}'),
                label: currency.code,
                onPressed: () => setState(() => _currencyId = currency.id),
              ),
          const SizedBox(width: 8),
          PulsoLabel('${data.period.from} → ${data.period.to}'),
        ],
      ),
    );
  }

  Widget _summary(AccountingCurrencySeries currency) {
    final latest = currency.rows.last;
    return PulsoPanel(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 30,
        runSpacing: 14,
        children: [
          StatsFact('Entradas de caja · ${currency.code}', latest.cashIncome),
          StatsFact('Neto de caja · ${currency.code}', latest.cashNet),
          StatsFact(
            'Margen menos fijo · ${currency.code}',
            latest.marginAfterFixed,
          ),
          StatsFact(
            'Resultado devengado · ${currency.code}',
            latest.accrualResult,
            alerta: latest.resultSign == 'NEGATIVO',
          ),
          StatsFact(
            'Revaluación en base · ${currency.code}',
            latest.revaluation,
          ),
          StatsFact(
            latest.state.certified
                ? 'Cierre certificado'
                : 'Lectura provisional',
            latest.month,
            alerta: !latest.state.certified,
          ),
        ],
      ),
    );
  }

  Widget _incomePanel(AccountingCurrencySeries currency) => _chartPanel(
    title: 'Entradas por medio de pago',
    detail:
        'Barras apiladas mensuales · ${currency.code}. La suma coincide con Tesorería.',
    chart: _StackedMonths(
      rows: currency.rows,
      parts: (row) => row.paymentTypes,
    ),
    table: _amountTable(
      headers: const ['Mes', 'Entradas', 'Medios'],
      rows: [
        for (final row in currency.rows)
          [
            row.month,
            row.cashIncome,
            row.paymentTypes
                .map((item) => '${item.name}: ${item.amount}')
                .join(' · '),
          ],
      ],
    ),
  );

  Widget _resultPanel(AccountingCurrencySeries currency) => _chartPanel(
    title: 'Margen y resultado devengado',
    detail:
        'El signo se conserva; la longitud usa el valor absoluto solo para dibujar.',
    chart: _SignedMonths(rows: currency.rows),
    table: _amountTable(
      headers: const ['Mes', 'Margen − fijo', 'Gasto', 'Resultado'],
      rows: [
        for (final row in currency.rows)
          [
            row.month,
            row.marginAfterFixed,
            row.accruedExpense,
            '${row.accrualResult} · ${row.resultSign}',
          ],
      ],
    ),
  );

  Widget _paymentPanel(AccountingCurrencySeries currency) {
    final latest = currency.rows.last;
    return _chartPanel(
      title: 'Composición por medio',
      detail: '${latest.month} · ${currency.code}',
      chart: PulsoDona(
        datos: _topSix(latest.paymentTypes)
            .map((row) => PulsoChartDato(etiqueta: row.name, valor: row.value))
            .toList(),
        centroTitulo: 'entradas',
        centroValor: latest.cashIncome,
      ),
      table: _amountTable(
        headers: const ['Medio', 'Importe'],
        rows: [
          for (final row in latest.paymentTypes) [row.name, row.amount],
        ],
      ),
    );
  }

  Widget _accountPanel(AccountingCurrencySeries currency) {
    final latest = currency.rows.last;
    return _chartPanel(
      title: 'Composición por cuenta',
      detail:
          '${latest.month} · entradas de caja por cuenta en ${currency.code}',
      chart: latest.accounts.length <= 6
          ? PulsoDona(
              datos: latest.accounts
                  .map(
                    (row) =>
                        PulsoChartDato(etiqueta: row.name, valor: row.value),
                  )
                  .toList(),
              centroTitulo: 'cuentas',
              centroValor: latest.cashIncome,
            )
          : PulsoBarras(
              datos: latest.accounts
                  .map(
                    (row) =>
                        PulsoChartDato(etiqueta: row.name, valor: row.value),
                  )
                  .toList(),
            ),
      table: _amountTable(
        headers: const ['Cuenta', 'Entradas'],
        rows: [
          for (final row in latest.accounts) [row.name, row.amount],
        ],
      ),
    );
  }

  Widget _expensePanel(AccountingCurrencySeries currency) {
    final latest = currency.rows.last;
    return _chartPanel(
      title: 'Gasto por categoría',
      detail:
          'Devengado real y plantillas recurrentes vigentes · ${latest.month}.',
      chart: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PulsoBarras(
            datos: latest.expenseCategories
                .map(
                  (row) => PulsoChartDato(etiqueta: row.name, valor: row.value),
                )
                .toList(),
            mensajeVacio: 'Sin gasto devengado en el mes.',
          ),
          const SizedBox(height: 12),
          const PulsoLabel('PLANTILLAS RECURRENTES'),
          const SizedBox(height: 6),
          PulsoBarras(
            datos: latest.recurringCategories
                .map(
                  (row) => PulsoChartDato(
                    etiqueta: row.name,
                    valor: row.value,
                    nota: '${row.templates} plant.',
                  ),
                )
                .toList(),
            mensajeVacio: 'Sin plantillas recurrentes vigentes.',
            resaltarPrimero: false,
          ),
        ],
      ),
      table: _amountTable(
        headers: const ['Categoría', 'Devengado', 'Recurrente previsto'],
        rows: _expenseRows(latest),
      ),
    );
  }

  Widget _closurePanel(AccountingCurrencySeries currency) => _chartPanel(
    title: 'Arqueos: esperado contra contado',
    detail:
        'Cada barra usa únicamente cierres firmados del mes · ${currency.code}.',
    chart: _ClosureMonths(rows: currency.rows),
    table: _amountTable(
      headers: const ['Mes', 'Cierres', 'Esperado', 'Contado', 'Diferencia'],
      rows: [
        for (final row in currency.rows)
          [
            row.month,
            '${row.closures.count}',
            row.closures.expected,
            row.closures.counted,
            row.closures.difference,
          ],
      ],
    ),
  );

  Widget _collectorPanel(AccountingCurrencySeries currency) {
    final latest = currency.rows.last;
    return _chartPanel(
      title: 'Cobros por recepcionista',
      detail:
          '${latest.month} · neto de cambio y anulaciones, sin mezclar monedas.',
      chart: PulsoBarras(
        datos: latest.collectors
            .map(
              (row) => PulsoChartDato(
                etiqueta: row.name,
                valor: (double.tryParse(row.net) ?? 0).abs(),
                nota:
                    '${row.payments} pagos${row.historical ? ' · histórico' : ''}',
              ),
            )
            .toList(),
        mensajeVacio: 'Sin cobros atribuidos en el mes.',
      ),
      table: _amountTable(
        headers: const ['Responsable', 'Pagos', 'Clientes', 'Neto'],
        rows: [
          for (final row in latest.collectors)
            [row.name, '${row.payments}', '${row.clients}', row.net],
        ],
      ),
    );
  }

  Widget _tablePanel(
    BuildContext context,
    AccountingStatistics report,
    AccountingCurrencySeries currency,
  ) {
    return _chartPanel(
      title: 'Libro visual verificable',
      detail:
          'La tabla contiene las cifras exactas que alimentan las gráficas.',
      chart: const SizedBox.shrink(),
      table: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: PulsoSecondaryButton(
              key: const ValueKey('contabilidad-exportar-csv'),
              label: 'Copiar CSV',
              icon: Icons.copy_all_outlined,
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: _csv(report, currency)),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSV copiado al portapapeles.')),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          _amountTable(
            headers: const [
              'Mes',
              'Entradas',
              'Salidas',
              'Neto caja',
              'Margen − fijo',
              'Gasto',
              'Resultado',
              'Revaluación',
            ],
            rows: [
              for (final row in currency.rows)
                [
                  row.month,
                  row.cashIncome,
                  row.cashExpense,
                  row.cashNet,
                  row.marginAfterFixed,
                  row.accruedExpense,
                  row.accrualResult,
                  row.revaluation,
                ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _chartPanel({
    required String title,
    required String detail,
    required Widget chart,
    required Widget table,
  }) {
    return PulsoPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatsPanelTitle(title),
          const SizedBox(height: 3),
          Builder(
            builder: (context) => Text(
              detail,
              style: TextStyle(
                fontSize: 10,
                height: 1.4,
                color: PulsoTokens.of(context).muted,
              ),
            ),
          ),
          if (chart is! SizedBox) ...[const SizedBox(height: 14), chart],
          const SizedBox(height: 14),
          table,
        ],
      ),
    );
  }

  Widget _responsivePair({
    required bool compact,
    required Widget left,
    required Widget right,
  }) {
    if (compact) {
      return Column(children: [left, const SizedBox(height: 14), right]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 14),
        Expanded(child: right),
      ],
    );
  }
}

class _StackedMonths extends StatelessWidget {
  const _StackedMonths({required this.rows, required this.parts});
  final List<AccountingMonthRow> rows;
  final List<NamedAmount> Function(AccountingMonthRow) parts;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final names = <String>[];
    for (final row in rows) {
      for (final part in parts(row)) {
        if (!names.contains(part.name)) {
          names.add(part.name);
        }
      }
    }
    final colors = pulsoSerieColores(tokens, names.length);
    if (names.isEmpty) {
      return const PulsoChartVacio(mensaje: 'Sin entradas en el período.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  child: Text(
                    row.month,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 9,
                      color: tokens.muted,
                    ),
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: 18,
                    child: Row(
                      children: [
                        for (var i = 0; i < names.length; i++)
                          if (_value(parts(row), names[i]) > 0)
                            Expanded(
                              flex: (_value(parts(row), names[i]) * 100)
                                  .round()
                                  .clamp(1, 1000000)
                                  .toInt(),
                              child: ColoredBox(color: colors[i]),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: Text(
                    row.cashIncome,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 10,
                      color: tokens.chalk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 5,
          children: [
            for (var i = 0; i < names.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, color: colors[i]),
                  const SizedBox(width: 5),
                  Text(
                    names[i],
                    style: TextStyle(fontSize: 9, color: tokens.muted),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _SignedMonths extends StatelessWidget {
  const _SignedMonths({required this.rows});
  final List<AccountingMonthRow> rows;
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final maxValue = rows.fold<double>(0, (max, row) {
      final value = (double.tryParse(row.accrualResult) ?? 0).abs();
      return value > max ? value : max;
    });
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  child: Text(
                    row.month,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 9,
                      color: tokens.muted,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 14,
                    alignment: Alignment.centerLeft,
                    color: tokens.line,
                    child: FractionallySizedBox(
                      widthFactor: maxValue == 0
                          ? 0
                          : ((double.tryParse(row.accrualResult) ?? 0).abs() /
                                maxValue),
                      child: ColoredBox(
                        color: row.resultSign == 'NEGATIVO'
                            ? tokens.danger
                            : row.resultSign == 'POSITIVO'
                            ? tokens.accent
                            : tokens.muted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 84,
                  child: Text(
                    row.accrualResult,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 10,
                      color: row.resultSign == 'NEGATIVO'
                          ? tokens.danger
                          : tokens.chalk,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ClosureMonths extends StatelessWidget {
  const _ClosureMonths({required this.rows});
  final List<AccountingMonthRow> rows;
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final maxValue = rows.fold<double>(0, (max, row) {
      final value = [row.closures.expected, row.closures.counted]
          .map((v) => (double.tryParse(v) ?? 0).abs())
          .fold<double>(0, (a, b) => b > a ? b : a);
      return value > max ? value : max;
    });
    if (rows.every((row) => row.closures.count == 0)) {
      return const PulsoChartVacio(
        mensaje: 'Sin arqueos firmados en el período.',
      );
    }
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  child: Text(
                    row.month,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 9,
                      color: tokens.muted,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _thinBar(
                        tokens.line,
                        tokens.accent,
                        double.tryParse(row.closures.expected) ?? 0,
                        maxValue,
                      ),
                      const SizedBox(height: 3),
                      _thinBar(
                        tokens.line,
                        tokens.chalkDim,
                        double.tryParse(row.closures.counted) ?? 0,
                        maxValue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: Text(
                    row.closures.difference,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 10,
                      color: row.closures.difference.startsWith('-')
                          ? tokens.danger
                          : tokens.chalk,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Widget _thinBar(Color background, Color color, double value, double maxValue) =>
    Container(
      height: 6,
      alignment: Alignment.centerLeft,
      color: background,
      child: FractionallySizedBox(
        widthFactor: maxValue == 0 ? 0 : value.abs() / maxValue,
        child: ColoredBox(color: color),
      ),
    );

double _value(List<NamedAmount> rows, String name) => rows
    .where((row) => row.name == name)
    .fold(0, (sum, row) => sum + row.value);

List<NamedAmount> _topSix(List<NamedAmount> rows) {
  if (rows.length <= 6) return rows;
  final sorted = [...rows]..sort((a, b) => b.value.compareTo(a.value));
  final other = sorted.skip(5).fold<double>(0, (sum, row) => sum + row.value);
  return [
    ...sorted.take(5),
    NamedAmount(id: 'OTROS', name: 'Otros', amount: other.toStringAsFixed(2)),
  ];
}

List<List<String>> _expenseRows(AccountingMonthRow row) {
  final names = <String>{
    ...row.expenseCategories.map((item) => item.name),
    ...row.recurringCategories.map((item) => item.name),
  };
  String amount(List<NamedAmount> rows, String name) {
    for (final item in rows) {
      if (item.name == name) return item.amount;
    }
    return '0.00';
  }

  return [
    for (final name in names)
      [
        name,
        amount(row.expenseCategories, name),
        amount(row.recurringCategories, name),
      ],
  ];
}

Widget _amountTable({
  required List<String> headers,
  required List<List<String>> rows,
}) {
  if (rows.isEmpty) {
    return const PulsoChartVacio(mensaje: 'Sin filas para mostrar.', alto: 60);
  }
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      headingRowHeight: 34,
      dataRowMinHeight: 34,
      dataRowMaxHeight: 54,
      columns: [for (final header in headers) DataColumn(label: Text(header))],
      rows: [
        for (final row in rows)
          DataRow(
            cells: [
              for (final value in row)
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(value),
                  ),
                ),
            ],
          ),
      ],
    ),
  );
}

String _csv(AccountingStatistics report, AccountingCurrencySeries currency) {
  final lines = <String>[
    'zona,moneda,mes,entradas,salidas,neto_caja,margen_menos_fijo,gasto_devengado,resultado_devengado,revaluacion,estado,certificado',
  ];
  for (final row in currency.rows) {
    lines.add(
      [
        report.zone,
        currency.code,
        row.month,
        row.cashIncome,
        row.cashExpense,
        row.cashNet,
        row.marginAfterFixed,
        row.accruedExpense,
        row.accrualResult,
        row.revaluation,
        row.state.accrual,
        row.state.certified,
      ].map(_csvCell).join(','),
    );
  }
  return lines.join('\r\n');
}

String _csvCell(Object value) => '"${value.toString().replaceAll('"', '""')}"';
