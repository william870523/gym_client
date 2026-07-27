import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/accrual_operating_result_models.dart';
import '../state/accounting_providers.dart';

/// R4.6 — Resultado operativo devengado.
///
/// Muestra cómo se arma el resultado del mes: al margen gerencial ya neto de
/// compensación fija se le resta el gasto gobernado que pertenece al período.
/// La cascada es el contenido central: el operador debe ver de dónde sale la
/// cifra, no solo la cifra.
class AccrualOperatingResultPanel extends ConsumerStatefulWidget {
  const AccrualOperatingResultPanel({
    super.key,
    this.initialMonth,
    required this.onBack,
  });

  final String? initialMonth;
  final VoidCallback onBack;

  @override
  ConsumerState<AccrualOperatingResultPanel> createState() =>
      _AccrualOperatingResultPanelState();
}

class _AccrualOperatingResultPanelState
    extends ConsumerState<AccrualOperatingResultPanel> {
  final _scroll = ScrollController();
  late String? _month = widget.initialMonth;
  String? _currencyId;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(accrualOperatingResultProvider(_month))
        .when(
          loading: () => const PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.loading,
              message: 'Restando el gasto del mes al margen ya prestado…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message:
                  'No se pudo calcular el resultado operativo devengado.\n${_errorText(error)}',
              onRetry: _refresh,
            ),
          ),
          data: _buildResult,
        );
  }

  Widget _buildResult(AccrualOperatingResultModel result) {
    if (result.currencies.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ResultToolbar(
            result: result,
            onBack: widget.onBack,
            onPrevious: () => _moveMonth(result.month, -1),
            onNext: () => _moveMonth(result.month, 1),
            onCurrent: () => _setMonth(null),
            onRefresh: _refresh,
          ),
          const SizedBox(height: 10),
          const Expanded(
            child: PulsoPanel(
              child: PulsoStateView(
                kind: PulsoStateKind.empty,
                message:
                    'No hay servicio prestado ni gasto gobernado para este período.',
              ),
            ),
          ),
        ],
      );
    }

    final selected = result.currencies.firstWhere(
      (row) => row.currencyId == _currencyId,
      orElse: () => result.currencies.first,
    );
    if (_currencyId != selected.currencyId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currencyId = selected.currencyId);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResultToolbar(
          result: result,
          onBack: widget.onBack,
          onPrevious: () => _moveMonth(result.month, -1),
          onNext: () => _moveMonth(result.month, 1),
          onCurrent: () => _setMonth(null),
          onRefresh: _refresh,
        ),
        const SizedBox(height: 8),
        if (result.currencies.length > 1) ...[
          _CurrencySelector(
            currencies: result.currencies,
            selectedId: selected.currencyId,
            onSelected: (value) => setState(() => _currencyId = value),
          ),
          const SizedBox(height: 8),
        ],
        PulsoMetricStrip(
          key: const Key('accrual-result-metrics'),
          metrics: [
            PulsoMetricData(
              value:
                  '${_exactMoney(selected.resultInMonth)} ${selected.currencyCode}',
              label: 'RESULTADO OPERATIVO',
              note: 'Margen menos fijo, menos gasto del mes',
              emphasis: !_isNegative(selected.resultInMonth),
              warning: _isNegative(selected.resultInMonth),
            ),
            PulsoMetricData(
              value:
                  '${_exactMoney(selected.marginAfterFixedInMonth)} ${selected.currencyCode}',
              label: 'MARGEN MENOS FIJO',
              note: 'Lo que dejó el servicio prestado',
            ),
            PulsoMetricData(
              value:
                  '${_exactMoney(selected.expenseInMonth)} ${selected.currencyCode}',
              label: 'GASTO DEVENGADO',
              note: 'Pertenece al mes, se pague cuando se pague',
            ),
            PulsoMetricData(
              value:
                  '${_exactMoney(selected.expensePendingPayment)} ${selected.currencyCode}',
              label: 'PENDIENTE DE PAGO',
              note: 'Gasto del mes todavía sin salir de caja',
              warning: !_isZero(selected.expensePendingPayment),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _CertificationNotice(result: result),
        const SizedBox(height: 8),
        Expanded(
          child: PulsoPanel(
            padding: EdgeInsets.zero,
            child: Scrollbar(
              key: const Key('accrual-result-scrollbar'),
              controller: _scroll,
              thumbVisibility: true,
              child: ListView(
                key: const Key('accrual-result-list'),
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                children: [
                  _ResultWaterfall(currency: selected),
                  const SizedBox(height: 12),
                  _NatureBreakdown(currency: selected),
                  const SizedBox(height: 12),
                  _ResultFooter(result: result, currency: selected),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _moveMonth(String current, int delta) {
    final parts = current.split('-');
    final gymNow = toGymWallClock(appClock.nowUtc(), appClock.gymTimezone);
    final year = int.tryParse(parts.first) ?? gymNow.year;
    final month = parts.length > 1
        ? int.tryParse(parts[1]) ?? gymNow.month
        : gymNow.month;
    final moved = DateTime.utc(year, month + delta);
    _setMonth('${moved.year}-${moved.month.toString().padLeft(2, '0')}');
  }

  void _setMonth(String? value) {
    setState(() {
      _month = value;
      _currencyId = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void _refresh() {
    ref.invalidate(accrualOperatingResultProvider(_month));
  }
}

class _ResultToolbar extends StatelessWidget {
  const _ResultToolbar({
    required this.result,
    required this.onBack,
    required this.onPrevious,
    required this.onNext,
    required this.onCurrent,
    required this.onRefresh,
  });

  final AccrualOperatingResultModel result;
  final VoidCallback onBack;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCurrent;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 820;
          final monthBox = Container(
            constraints: BoxConstraints(
              minWidth: compact ? 0 : 142,
              minHeight: 40,
            ),
            alignment: Alignment.center,
            color: tokens.raised,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _monthName(result.month).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.chalk,
                fontFamily: PulsoFonts.mono,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          );
          if (compact) {
            return Row(
              children: [
                PulsoIconButton(
                  key: const Key('accrual-result-back-compact'),
                  icon: Icons.arrow_back,
                  tooltip: 'Volver al margen gerencial',
                  onPressed: onBack,
                ),
                const SizedBox(width: 6),
                Expanded(child: monthBox),
                const SizedBox(width: 6),
                PulsoIconButton(
                  icon: Icons.today_outlined,
                  tooltip: 'Mes en curso',
                  onPressed: onCurrent,
                ),
                PulsoIconButton(
                  icon: Icons.refresh,
                  tooltip: 'Actualizar resultado devengado',
                  onPressed: onRefresh,
                ),
              ],
            );
          }
          return Row(
            children: [
              TextButton.icon(
                key: const Key('accrual-result-back'),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('VOLVER AL MARGEN'),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'RESULTADO DEVENGADO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.chalk,
                    fontFamily: PulsoFonts.display,
                    fontSize: 25,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const Spacer(),
              PulsoIconButton(
                icon: Icons.chevron_left,
                tooltip: 'Mes anterior',
                onPressed: onPrevious,
              ),
              monthBox,
              PulsoIconButton(
                icon: Icons.chevron_right,
                tooltip: 'Mes siguiente',
                onPressed: onNext,
              ),
              const SizedBox(width: 6),
              PulsoSecondaryButton(label: 'MES EN CURSO', onPressed: onCurrent),
              const SizedBox(width: 6),
              PulsoIconButton(
                icon: Icons.refresh,
                tooltip: 'Actualizar resultado devengado',
                onPressed: onRefresh,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CurrencySelector extends StatelessWidget {
  const _CurrencySelector({
    required this.currencies,
    required this.selectedId,
    required this.onSelected,
  });

  final List<AccrualOperatingResultCurrencyModel> currencies;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          const PulsoLabel('MONEDA'),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final currency in currencies)
                  _CurrencyChip(
                    key: Key('accrual-result-currency-${currency.currencyId}'),
                    label: currency.currencyCode,
                    selected: currency.currencyId == selectedId,
                    onTap: () => onSelected(currency.currencyId),
                  ),
              ],
            ),
          ),
          Text(
            '${currencies.length}',
            style: TextStyle(
              color: tokens.accent,
              fontFamily: PulsoFonts.mono,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 30,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? tokens.accentSoft : tokens.raised,
          border: Border.all(
            color: selected ? tokens.accentBorder : tokens.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? tokens.accent : tokens.chalkDim,
            fontFamily: PulsoFonts.mono,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Cascada: cómo se arma el resultado. Es el contenido protagonista del panel.
class _ResultWaterfall extends StatelessWidget {
  const _ResultWaterfall({required this.currency});

  final AccrualOperatingResultCurrencyModel currency;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final steps = <_WaterfallStep>[
      _WaterfallStep(
        label: 'Ingreso devengado del mes',
        note: 'Servicio ya prestado',
        amount: currency.revenueInMonth,
        sign: _StepSign.positive,
      ),
      _WaterfallStep(
        label: 'Costo directo de comisión',
        note: 'Comisión del servicio prestado',
        amount: currency.directCostInMonth,
        sign: _StepSign.negative,
      ),
      _WaterfallStep(
        label: 'Margen directo',
        note: 'Ingreso menos comisión',
        amount: currency.marginInMonth,
        sign: _StepSign.subtotal,
      ),
      _WaterfallStep(
        label: 'Compensación fija',
        note: 'No se reparte entre planes ni socios',
        amount: currency.fixedInMonth,
        sign: _StepSign.negative,
      ),
      _WaterfallStep(
        label: 'Margen menos fijo',
        note: 'Base sobre la que pesa el gasto',
        amount: currency.marginAfterFixedInMonth,
        sign: _StepSign.subtotal,
      ),
      _WaterfallStep(
        label: 'Gasto gobernado del mes',
        note: 'Alquiler, servicios, insumos, proveedores',
        amount: currency.expenseInMonth,
        sign: _StepSign.negative,
      ),
      _WaterfallStep(
        label: 'Resultado operativo devengado',
        note: 'No es la utilidad del gimnasio',
        amount: currency.resultInMonth,
        sign: _StepSign.total,
      ),
    ];

    return Container(
      decoration: BoxDecoration(border: Border.all(color: tokens.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionCap(
            label: 'CÓMO SE ARMA EL RESULTADO',
            trailing: currency.currencyCode,
          ),
          for (var index = 0; index < steps.length; index++)
            _WaterfallRow(
              step: steps[index],
              currencyCode: currency.currencyCode,
              last: index == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

enum _StepSign { positive, negative, subtotal, total }

class _WaterfallStep {
  const _WaterfallStep({
    required this.label,
    required this.note,
    required this.amount,
    required this.sign,
  });

  final String label;
  final String note;
  final String amount;
  final _StepSign sign;
}

class _WaterfallRow extends StatelessWidget {
  const _WaterfallRow({
    required this.step,
    required this.currencyCode,
    required this.last,
  });

  final _WaterfallStep step;
  final String currencyCode;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final isTotal = step.sign == _StepSign.total;
    final isSubtotal = step.sign == _StepSign.subtotal;
    final negativeAmount = _isNegative(step.amount);
    final valueColor = isTotal
        ? (negativeAmount ? tokens.danger : tokens.accent)
        : tokens.chalk;
    final prefix = switch (step.sign) {
      _StepSign.positive => '+',
      _StepSign.negative => '−',
      _StepSign.subtotal => '=',
      _StepSign.total => '=',
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: isTotal ? 12 : 9),
      decoration: BoxDecoration(
        color: isTotal
            ? (negativeAmount ? tokens.dangerSoft : tokens.accentSoft)
            : isSubtotal
            ? tokens.raised
            : null,
        border: last ? null : Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              prefix,
              style: TextStyle(
                color: step.sign == _StepSign.negative
                    ? tokens.muted
                    : tokens.chalkDim,
                fontFamily: PulsoFonts.mono,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.chalk,
                    fontSize: isTotal ? 13 : 12,
                    fontWeight: isTotal || isSubtotal
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
                Text(
                  step.note.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.muted2,
                    fontFamily: PulsoFonts.mono,
                    fontSize: 8,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${_exactMoney(step.amount)} $currencyCode',
            style: TextStyle(
              color: valueColor,
              fontFamily: isTotal ? PulsoFonts.display : PulsoFonts.mono,
              fontSize: isTotal ? 31 : 13,
              height: isTotal ? 1 : null,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
              letterSpacing: isTotal ? -0.9 : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _NatureBreakdown extends StatelessWidget {
  const _NatureBreakdown({required this.currency});

  final AccrualOperatingResultCurrencyModel currency;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final natures = currency.natures;
    final total = _toCents(currency.expenseInMonth);
    return Container(
      decoration: BoxDecoration(border: Border.all(color: tokens.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionCap(
            label: 'GASTO DEL MES POR NATURALEZA',
            trailing: '${natures.length} TIPO(S)',
          ),
          if (natures.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Text(
                'Ningún gasto gobernado pertenece a este mes.',
                style: TextStyle(color: tokens.muted, fontSize: 12),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: tokens.line)),
              ),
              child: Row(
                children: [
                  const Expanded(child: _ColumnHeader('NATURALEZA')),
                  const SizedBox(
                    width: 58,
                    child: _ColumnHeader('GASTOS', end: true),
                  ),
                  const SizedBox(
                    width: 132,
                    child: _ColumnHeader('DEVENGADO', end: true),
                  ),
                  const SizedBox(
                    width: 74,
                    child: _ColumnHeader('% INGRESO', end: true),
                  ),
                ],
              ),
            ),
            for (var index = 0; index < natures.length; index++)
              _NatureRow(
                nature: natures[index],
                currencyCode: currency.currencyCode,
                share: total <= 0
                    ? 0
                    : _toCents(natures[index].accruedInMonth) / total,
                last: index == natures.length - 1,
              ),
          ],
        ],
      ),
    );
  }
}

class _NatureRow extends StatelessWidget {
  const _NatureRow({
    required this.nature,
    required this.currencyCode,
    required this.share,
    required this.last,
  });

  final AccrualExpenseNatureModel nature;
  final String currencyCode;
  final double share;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nature.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.chalk, fontSize: 12),
                ),
              ),
              SizedBox(
                width: 58,
                child: Text(
                  '${nature.expenses}',
                  textAlign: TextAlign.right,
                  style: _dataStyle(tokens.chalkDim),
                ),
              ),
              SizedBox(
                width: 132,
                child: Text(
                  '${_exactMoney(nature.accruedInMonth)} $currencyCode',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _dataStyle(tokens.chalk),
                ),
              ),
              SizedBox(
                width: 74,
                child: Text(
                  nature.pctOfRevenue == null
                      ? '—'
                      : '${nature.pctOfRevenue!.toStringAsFixed(2)} %',
                  textAlign: TextAlign.right,
                  style: _dataStyle(tokens.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          // Proporción del gasto del mes: una barra encuadrada, no un gráfico
          // suelto; deja ver de un vistazo qué naturaleza pesa más.
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: tokens.raised,
              border: Border.all(color: tokens.line),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: share.clamp(0.0, 1.0),
              child: Container(color: tokens.chalkDim),
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificationNotice extends StatelessWidget {
  const _CertificationNotice({required this.result});

  final AccrualOperatingResultModel result;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final partial = result.marginCertified && !result.expenseCertified;
    final status = result.certified
        ? 'CERTIFICADO'
        : partial
        ? 'CERTIFICACIÓN PARCIAL'
        : 'PROVISIONAL';
    final color = result.certified
        ? tokens.success
        : partial
        ? tokens.warning
        : tokens.muted;
    final background = result.certified
        ? tokens.successSoft
        : partial
        ? tokens.warningSoft
        : null;
    final coverage = result.coverage;
    final details = <String>[
      if (coverage.expensesPendingPayment > 0)
        '${coverage.expensesPendingPayment} gasto(s) del mes sin pagar todavía',
      if (coverage.crossMonthPayments > 0)
        '${coverage.crossMonthPayments} pago(s) de otro mes hechos en este mes (mueven caja, no el devengo)',
      if (coverage.requiresReview > 0)
        '${coverage.requiresReview} concepto(s) del margen requieren revisión',
    ];
    return PulsoPanel(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(
                status,
                style: TextStyle(
                  color: color,
                  fontFamily: PulsoFonts.mono,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              if (result.cutoffDate != null)
                Text(
                  'CORTE ${result.cutoffDate}',
                  style: TextStyle(
                    color: tokens.muted2,
                    fontFamily: PulsoFonts.mono,
                    fontSize: 9,
                    letterSpacing: 1.1,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            result.certificationNote,
            style: TextStyle(
              color: tokens.chalkDim,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          for (final detail in details) ...[
            const SizedBox(height: 3),
            Text(
              '— $detail',
              style: TextStyle(color: tokens.muted, fontSize: 11, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultFooter extends StatelessWidget {
  const _ResultFooter({required this.result, required this.currency});

  final AccrualOperatingResultModel result;
  final AccrualOperatingResultCurrencyModel currency;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      decoration: BoxDecoration(border: Border.all(color: tokens.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionCap(
            label: 'QUÉ SIGNIFICA ESTA CIFRA',
            trailing: currency.currencyCode,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currency.explanation,
                  style: TextStyle(
                    color: tokens.chalk,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  result.note,
                  style: TextStyle(
                    color: tokens.chalkDim,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                if (result.limitations.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const PulsoLabel('LÍMITES DECLARADOS'),
                  const SizedBox(height: 5),
                  for (final limitation in result.limitations) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        '— $limitation',
                        style: TextStyle(
                          color: tokens.muted,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCap extends StatelessWidget {
  const _SectionCap({required this.label, this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.muted,
                fontFamily: PulsoFonts.mono,
                fontSize: 9,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.3,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                color: tokens.muted2,
                fontFamily: PulsoFonts.mono,
                fontSize: 9,
                letterSpacing: 1.1,
              ),
            ),
        ],
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader(this.label, {this.end = false});

  final String label;
  final bool end;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Text(
      label,
      textAlign: end ? TextAlign.right : TextAlign.left,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: tokens.muted2,
        fontFamily: PulsoFonts.mono,
        fontSize: 8,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
      ),
    );
  }
}

TextStyle _dataStyle(Color color) => TextStyle(
  color: color,
  fontFamily: PulsoFonts.mono,
  fontSize: 13,
  fontWeight: FontWeight.w500,
  fontFeatures: const [FontFeature.tabularFigures()],
);

bool _isNegative(String value) => value.trim().startsWith('-');

bool _isZero(String value) => _toCents(value) == 0;

int _toCents(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return 0;
  final negative = normalized.startsWith('-');
  final unsigned = negative ? normalized.substring(1) : normalized;
  final parts = unsigned.split('.');
  final integer = int.tryParse(parts.first.isEmpty ? '0' : parts.first) ?? 0;
  final decimal = parts.length > 1
      ? int.tryParse(parts[1].padRight(2, '0').substring(0, 2)) ?? 0
      : 0;
  final total = integer * 100 + decimal;
  return negative ? -total : total;
}

String _exactMoney(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return '0.00';
  final negative = normalized.startsWith('-');
  final unsigned = negative ? normalized.substring(1) : normalized;
  final parts = unsigned.split('.');
  final integer = parts.first.isEmpty ? '0' : parts.first;
  final decimal = parts.length > 1 ? parts[1].padRight(2, '0') : '00';
  final grouped = integer.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${negative ? '-' : ''}$grouped.${decimal.substring(0, 2)}';
}

String _monthName(String month) {
  const names = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  final parts = month.split('-');
  if (parts.length < 2) return month;
  final index = int.tryParse(parts[1]) ?? 0;
  if (index < 1 || index > 12) return month;
  return '${names[index - 1]} ${parts.first}';
}

String _errorText(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final detail = data['error'] ?? data['message'] ?? data['detail'];
      if (detail != null && detail.toString().trim().isNotEmpty) {
        return detail.toString().trim();
      }
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'No hay conexión con el servidor local. Revise el launcher e inténtelo de nuevo.';
    }
  }
  return error.toString();
}
