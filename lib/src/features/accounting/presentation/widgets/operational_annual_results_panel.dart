import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/operational_annual_results_models.dart';
import '../state/accounting_providers.dart';

class OperationalAnnualResultsPanel extends ConsumerStatefulWidget {
  const OperationalAnnualResultsPanel({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<OperationalAnnualResultsPanel> createState() =>
      _OperationalAnnualResultsPanelState();
}

class _OperationalAnnualResultsPanelState
    extends ConsumerState<OperationalAnnualResultsPanel> {
  final _monthsScroll = ScrollController();
  String? _year;
  String? _currencyId;

  @override
  void dispose() {
    _monthsScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(operationalAnnualResultsProvider(_year));
    return state.when(
      loading: () => const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.loading,
          message: 'Revisando los cierres mensuales certificados…',
        ),
      ),
      error: (error, _) => PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.error,
          message: 'No se pudo preparar la comparativa anual.\n$error',
          onRetry: _refresh,
        ),
      ),
      data: _buildResult,
    );
  }

  Widget _buildResult(OperationalAnnualResultsModel result) {
    final selected =
        result.currencies
            .where((item) => item.currencyId == _currencyId)
            .firstOrNull ??
        result.currencies.firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded = constraints.maxWidth >= 900;
        final dense = constraints.maxWidth < 600 || constraints.maxHeight < 650;
        final gap = dense ? 8.0 : 10.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AnnualToolbar(
              result: result,
              onBack: widget.onBack,
              onPrevious: () => _moveYear(result.year, -1),
              onNext: () => _moveYear(result.year, 1),
              onCurrent: () => setState(() {
                _year = null;
                _currencyId = null;
              }),
              onRefresh: _refresh,
            ),
            SizedBox(height: gap),
            if (dense)
              _CompactCoverageBand(result: result)
            else
              _CoverageStrip(result: result),
            SizedBox(height: gap),
            if (selected != null) ...[
              _AnnualCurrencyToolbar(
                currencies: result.currencies,
                selectedId: selected.currencyId,
                onSelected: (value) {
                  if (value == null || value == _currencyId) return;
                  setState(() => _currencyId = value);
                  _resetScroll();
                },
              ),
              SizedBox(height: gap),
              _AnnualMetricStrip(
                metrics: [
                  PulsoMetricData(
                    value: _exactMoney(selected.flowTotals.grossCollections),
                    label: 'Cobrado certificado',
                    note:
                        '${selected.currencyCode} · ${selected.monthCount} mes(es)',
                    emphasis: true,
                  ),
                  PulsoMetricData(
                    value: _exactMoney(selected.flowTotals.ledgerExits),
                    label: 'Dinero que salió',
                    note: '${selected.currencyCode} · flujo sumable',
                  ),
                  PulsoMetricData(
                    value: _exactMoney(selected.flowTotals.operationalFlow),
                    label: 'Flujo operativo',
                    note: '${selected.currencyCode} · no es ganancia',
                    warning: selected.flowTotals.operationalFlow.startsWith(
                      '-',
                    ),
                  ),
                  PulsoMetricData(
                    value: selected.latestCut?.immediateReserve == null
                        ? '—'
                        : _exactMoney(selected.latestCut!.immediateReserve!),
                    label: 'Reserva al último corte',
                    note: selected.latestCut == null
                        ? 'Sin corte certificado'
                        : '${selected.currencyCode} · ${_monthName(selected.latestCut!.month)}',
                  ),
                ],
              ),
              SizedBox(height: gap),
            ],
            _AnnualMeaningNotice(
              result: result,
              currency: selected,
              compact: dense,
            ),
            SizedBox(height: gap),
            Expanded(
              child: PulsoPanel(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
                child: Scrollbar(
                  key: const Key('operational-annual-months-scrollbar'),
                  controller: _monthsScroll,
                  thumbVisibility: true,
                  child: ListView.separated(
                    key: const Key('operational-annual-months-list'),
                    controller: _monthsScroll,
                    padding: const EdgeInsets.only(right: 8, bottom: 4),
                    itemCount: result.months.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 7),
                    itemBuilder: (context, index) {
                      final month = result.months[index];
                      final currencyMonth = selected?.months
                          .where((item) => item.month == month.month)
                          .firstOrNull;
                      return _AnnualMonthRow(
                        month: month,
                        currency: selected,
                        currencyMonth: currencyMonth,
                        expanded: expanded,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _moveYear(String value, int delta) {
    final parsed = int.tryParse(value);
    if (parsed == null) return;
    setState(() {
      _year = (parsed + delta).toString();
      _currencyId = null;
    });
    _resetScroll();
  }

  void _refresh() => ref.invalidate(operationalAnnualResultsProvider(_year));

  void _resetScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_monthsScroll.hasClients) _monthsScroll.jumpTo(0);
    });
  }
}

class _AnnualToolbar extends StatelessWidget {
  const _AnnualToolbar({
    required this.result,
    required this.onBack,
    required this.onPrevious,
    required this.onNext,
    required this.onCurrent,
    required this.onRefresh,
  });

  final OperationalAnnualResultsModel result;
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
          final compact = constraints.maxWidth < 760;
          return Row(
            children: [
              if (compact)
                PulsoIconButton(
                  key: const Key('operational-annual-back-compact'),
                  icon: Icons.arrow_back,
                  tooltip: 'Volver al mes',
                  onPressed: onBack,
                )
              else
                TextButton.icon(
                  key: const Key('operational-annual-back'),
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('VOLVER AL MES'),
                ),
              if (!compact) const Spacer(),
              PulsoIconButton(
                icon: Icons.chevron_left,
                tooltip: 'Año anterior',
                onPressed: onPrevious,
              ),
              Container(
                constraints: BoxConstraints(
                  minWidth: compact ? 82 : 112,
                  minHeight: 40,
                ),
                alignment: Alignment.center,
                color: tokens.raised,
                child: Text(
                  result.year,
                  style: TextStyle(
                    color: tokens.chalk,
                    fontFamily: PulsoFonts.mono,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PulsoIconButton(
                icon: Icons.chevron_right,
                tooltip: 'Año siguiente',
                onPressed: onNext,
              ),
              if (!compact) ...[
                const Spacer(),
                TextButton(
                  onPressed: onCurrent,
                  child: const Text('AÑO ACTUAL'),
                ),
              ] else
                PulsoIconButton(
                  icon: Icons.today_outlined,
                  tooltip: 'Año actual',
                  onPressed: onCurrent,
                ),
              PulsoIconButton(
                icon: Icons.refresh,
                tooltip: 'Actualizar comparativa',
                onPressed: onRefresh,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CoverageStrip extends StatelessWidget {
  const _CoverageStrip({required this.result});

  final OperationalAnnualResultsModel result;

  @override
  Widget build(BuildContext context) {
    final coverage = result.coverage;
    final percentage = coverage.eligiblePercentage == null
        ? '—'
        : '${coverage.eligiblePercentage!.toStringAsFixed(0)}%';
    return _AnnualMetricStrip(
      metrics: [
        PulsoMetricData(
          value:
              '${coverage.certifiedEligibleMonths}/${coverage.eligibleMonths}',
          label: 'Meses exigibles certificados',
          note: coverage.complete ? 'Cobertura completa' : 'Faltan cierres',
          emphasis: coverage.complete,
        ),
        PulsoMetricData(
          value: percentage,
          label: 'Cobertura verificable',
          note: 'Nunca completa vacíos con cero',
        ),
        PulsoMetricData(
          value: coverage.pendingMonths.toString(),
          label: 'Meses pendientes',
          note: 'Sin cierre R3 válido',
          warning: coverage.pendingMonths > 0,
        ),
        PulsoMetricData(
          value: result.currencies.length.toString(),
          label: 'Monedas con evidencia',
          note: 'Se comparan por separado',
        ),
      ],
    );
  }
}

class _CompactCoverageBand extends StatelessWidget {
  const _CompactCoverageBand({required this.result});

  final OperationalAnnualResultsModel result;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final coverage = result.coverage;
    return PulsoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _compactCoverageValue(
            tokens,
            '${coverage.certifiedEligibleMonths}/${coverage.eligibleMonths}',
            'CERTIFICADOS',
          ),
          const SizedBox(width: 18),
          _compactCoverageValue(
            tokens,
            coverage.pendingMonths.toString(),
            'PENDIENTES',
            warning: coverage.pendingMonths > 0,
          ),
          const SizedBox(width: 18),
          _compactCoverageValue(
            tokens,
            result.currencies.length.toString(),
            'MONEDAS',
          ),
        ],
      ),
    );
  }

  Widget _compactCoverageValue(
    PulsoTokens tokens,
    String value,
    String label, {
    bool warning = false,
  }) {
    return Expanded(
      child: Row(
        children: [
          Text(
            value,
            style: TextStyle(
              color: warning ? tokens.warning : tokens.chalk,
              fontFamily: PulsoFonts.display,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: PulsoLabel(label)),
        ],
      ),
    );
  }
}

class _AnnualMetricStrip extends StatelessWidget {
  const _AnnualMetricStrip({required this.metrics});

  final List<PulsoMetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: metrics.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => SizedBox(
                width: 216,
                child: _AnnualMetricCard(data: metrics[index]),
              ),
            ),
          );
        }
        return SizedBox(
          height: 82,
          child: Row(
            children: [
              for (var index = 0; index < metrics.length; index++) ...[
                Expanded(child: _AnnualMetricCard(data: metrics[index])),
                if (index != metrics.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AnnualMetricCard extends StatelessWidget {
  const _AnnualMetricCard({required this.data});

  final PulsoMetricData data;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = data.warning
        ? tokens.warning
        : data.emphasis
        ? tokens.accent
        : tokens.chalk;
    return PulsoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 25,
            width: double.infinity,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  data.value,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontFamily: PulsoFonts.display,
                    fontSize: 27,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.chalkDim,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            data.note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.muted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _AnnualCurrencyToolbar extends StatelessWidget {
  const _AnnualCurrencyToolbar({
    required this.currencies,
    required this.selectedId,
    required this.onSelected,
  });

  final List<OperationalAnnualCurrencyModel> currencies;
  final String selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            if (constraints.maxWidth >= 520) ...[
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PulsoLabel('MONEDA DE LA COMPARATIVA'),
                    SizedBox(height: 3),
                    Text('La lista crece sin convertir monedas en botones.'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
            SizedBox(
              width: constraints.maxWidth < 520 ? constraints.maxWidth : 360,
              child: DropdownMenu<String>(
                key: ValueKey('operational-annual-currency-$selectedId'),
                initialSelection: selectedId,
                enableFilter: true,
                enableSearch: true,
                requestFocusOnTap: true,
                menuHeight: 300,
                expandedInsets: EdgeInsets.zero,
                leadingIcon: Icon(
                  Icons.currency_exchange,
                  size: 17,
                  color: tokens.muted,
                ),
                onSelected: onSelected,
                dropdownMenuEntries: currencies
                    .map(
                      (item) => DropdownMenuEntry(
                        value: item.currencyId,
                        label:
                            '${item.currencyCode} · ${item.monthCount} mes(es) certificados',
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnualMeaningNotice extends StatelessWidget {
  const _AnnualMeaningNotice({
    required this.result,
    required this.currency,
    required this.compact,
  });

  final OperationalAnnualResultsModel result;
  final OperationalAnnualCurrencyModel? currency;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final incomplete = !result.coverage.complete;
    final highest = currency?.highestFlow;
    final lowest = currency?.lowestFlow;
    if (compact) {
      return PulsoPanel(
        color: incomplete ? tokens.warningSoft : tokens.successSoft,
        borderColor: incomplete ? tokens.warning : tokens.success,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '${result.coverageNote} Los flujos se suman; la reserva corresponde solo al último corte.',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.chalk,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return PulsoPanel(
      color: incomplete ? tokens.warningSoft : tokens.successSoft,
      borderColor: incomplete ? tokens.warning : tokens.success,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Wrap(
        spacing: 18,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            result.coverageNote,
            style: TextStyle(color: tokens.chalk, fontWeight: FontWeight.w700),
          ),
          const Text(
            'Los cobros y salidas se suman; las reservas solo muestran el último corte certificado.',
          ),
          if (highest != null)
            Text(
              'Mayor flujo: ${_monthName(highest.month)} · ${_exactMoney(highest.amount)} ${currency!.currencyCode}',
            ),
          if (lowest != null)
            Text(
              'Menor flujo: ${_monthName(lowest.month)} · ${_exactMoney(lowest.amount)} ${currency!.currencyCode}',
            ),
        ],
      ),
    );
  }
}

class _AnnualMonthRow extends StatelessWidget {
  const _AnnualMonthRow({
    required this.month,
    required this.currency,
    required this.currencyMonth,
    required this.expanded,
  });

  final OperationalAnnualMonthModel month;
  final OperationalAnnualCurrencyModel? currency;
  final OperationalAnnualCurrencyMonthModel? currencyMonth;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final stateColor = _stateColor(tokens, month.state);
    return Container(
      key: ValueKey('operational-annual-month-${month.month}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border(left: BorderSide(color: stateColor, width: 3)),
      ),
      child: expanded
          ? _wide(tokens, stateColor)
          : _compact(tokens, stateColor),
    );
  }

  Widget _wide(PulsoTokens tokens, Color stateColor) {
    return Row(
      children: [
        SizedBox(width: 120, child: _monthIdentity(tokens, stateColor)),
        Expanded(child: _monthBody(tokens)),
        if (currencyMonth != null) ...[
          _amountColumn(tokens, 'COBRADO', currencyMonth!.grossCollections),
          _amountColumn(tokens, 'SALIDAS', currencyMonth!.ledgerExits),
          _amountColumn(
            tokens,
            'FLUJO',
            currencyMonth!.operationalFlow,
            warning: currencyMonth!.operationalFlow.startsWith('-'),
          ),
          _amountColumn(tokens, 'RESERVA', currencyMonth!.immediateReserve),
        ],
      ],
    );
  }

  Widget _compact(PulsoTokens tokens, Color stateColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _monthIdentity(tokens, stateColor),
        const SizedBox(height: 7),
        _monthBody(tokens),
        if (currencyMonth != null) ...[
          const SizedBox(height: 9),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _compactAmount(
                tokens,
                'COBRADO',
                currencyMonth!.grossCollections,
              ),
              _compactAmount(tokens, 'SALIDAS', currencyMonth!.ledgerExits),
              _compactAmount(tokens, 'FLUJO', currencyMonth!.operationalFlow),
              _compactAmount(
                tokens,
                'RESERVA',
                currencyMonth!.immediateReserve,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _monthIdentity(PulsoTokens tokens, Color stateColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _monthName(month.month).toUpperCase(),
          style: TextStyle(color: tokens.chalk, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          _stateLabel(month.state),
          style: TextStyle(
            color: stateColor,
            fontFamily: PulsoFonts.mono,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _monthBody(PulsoTokens tokens) {
    final message = month.certified
        ? currency == null
              ? 'Cierre válido; elija una moneda para ver sus importes.'
              : currencyMonth == null
              ? 'Cierre válido sin movimientos en ${currency!.currencyCode}.'
              : 'Cierre R3 íntegro · evidencia ${_shortHash(month.sha256)}'
        : month.reason;
    return Text(
      message,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: tokens.chalkDim, fontSize: 12),
    );
  }

  Widget _amountColumn(
    PulsoTokens tokens,
    String label,
    String? value, {
    bool warning = false,
  }) {
    return SizedBox(
      width: 128,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          PulsoLabel(label),
          const SizedBox(height: 4),
          Text(
            value == null ? '—' : _exactMoney(value),
            style: TextStyle(
              color: warning ? tokens.warning : tokens.chalk,
              fontFamily: PulsoFonts.mono,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactAmount(PulsoTokens tokens, String label, String? value) {
    return SizedBox(
      width: 124,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PulsoLabel(label),
          const SizedBox(height: 2),
          Text(
            value == null ? '—' : _exactMoney(value),
            style: TextStyle(
              color: tokens.chalk,
              fontFamily: PulsoFonts.mono,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Color _stateColor(PulsoTokens tokens, String state) => switch (state) {
  'CERTIFICADO' => tokens.success,
  'EN_CURSO' || 'FUTURO' => tokens.muted,
  'SNAPSHOT_ANTERIOR' => tokens.warning,
  _ => tokens.danger,
};

String _stateLabel(String state) => switch (state) {
  'CERTIFICADO' => 'CERTIFICADO',
  'SIN_CIERRE' => 'SIN CIERRE',
  'REABIERTO' => 'REABIERTO',
  'SNAPSHOT_ANTERIOR' => 'CIERRE ANTERIOR A R3',
  'INTEGRIDAD_INVALIDA' => 'INTEGRIDAD INVÁLIDA',
  'SNAPSHOT_INCOMPATIBLE' => 'SNAPSHOT INCOMPATIBLE',
  'EN_CURSO' => 'MES EN CURSO',
  'FUTURO' => 'MES FUTURO',
  _ => state.replaceAll('_', ' '),
};

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
  final index = int.tryParse(month.split('-').last);
  if (index == null || index < 1 || index > 12) return month;
  return names[index - 1];
}

String _shortHash(String? value) {
  if (value == null || value.isEmpty) return '—';
  return value.length <= 10 ? value : value.substring(0, 10);
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
