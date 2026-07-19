import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/management_margin_annual_models.dart';
import '../../data/services/management_margin_annual_report_service.dart';
import '../state/accounting_providers.dart';

class ManagementMarginAnnualPanel extends ConsumerStatefulWidget {
  const ManagementMarginAnnualPanel({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<ManagementMarginAnnualPanel> createState() =>
      _ManagementMarginAnnualPanelState();
}

class _ManagementMarginAnnualPanelState
    extends ConsumerState<ManagementMarginAnnualPanel> {
  final _monthsScroll = ScrollController();
  final _reports = const ManagementMarginAnnualReportService();
  String? _year;
  String? _currencyId;
  bool _exporting = false;

  @override
  void dispose() {
    _monthsScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(managementMarginAnnualResultsProvider(_year));
    return state.when(
      loading: () => const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.loading,
          message: 'Leyendo snapshots R4.4 certificados…',
        ),
      ),
      error: (error, _) => PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.error,
          message: 'No se pudo preparar el devengado anual.\n$error',
          onRetry: _refresh,
        ),
      ),
      data: _buildResult,
    );
  }

  Widget _buildResult(ManagementMarginAnnualResultsModel result) {
    final selected =
        result.currencies
            .where((item) => item.currencyId == _currencyId)
            .firstOrNull ??
        result.currencies.firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded = constraints.maxWidth >= 1080;
        final dense = constraints.maxWidth < 620 || constraints.maxHeight < 680;
        final gap = dense ? 8.0 : 10.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AnnualToolbar(
              result: result,
              exporting: _exporting,
              onBack: widget.onBack,
              onPrevious: () => _moveYear(result.year, -1),
              onNext: () => _moveYear(result.year, 1),
              onCurrent: () => setState(() {
                _year = null;
                _currencyId = null;
              }),
              onRefresh: _refresh,
              onExport: selected == null
                  ? null
                  : () => _showExport(result, selected),
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
                    value: _moneyWithCurrency(
                      selected.accrualTotals.directMargin,
                      selected.currencyCode,
                    ),
                    label: 'Margen certificado',
                    note:
                        '${selected.monthCount} mes(es) · ${selected.accrualTotals.marginPct ?? '—'}%',
                    emphasis: true,
                    warning: selected.accrualTotals.directMargin.startsWith(
                      '-',
                    ),
                  ),
                  PulsoMetricData(
                    value: _moneyWithCurrency(
                      selected.accrualTotals.revenue,
                      selected.currencyCode,
                    ),
                    label: 'Ingreso devengado',
                    note: 'Servicio prestado certificado',
                  ),
                  PulsoMetricData(
                    value: _moneyWithCurrency(
                      selected.accrualTotals.directCost,
                      selected.currencyCode,
                    ),
                    label: 'Costo directo',
                    note: 'Comisión devengada',
                  ),
                  PulsoMetricData(
                    value: _moneyWithCurrency(
                      selected.accrualTotals.marginAfterFixed,
                      selected.currencyCode,
                    ),
                    label: 'Margen menos fijo',
                    note: 'Fijo separado por diseño',
                    warning: selected.accrualTotals.marginAfterFixed.startsWith(
                      '-',
                    ),
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
                  key: const Key('management-margin-annual-months-scrollbar'),
                  controller: _monthsScroll,
                  thumbVisibility: true,
                  child: ListView.separated(
                    key: const Key('management-margin-annual-months-list'),
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

  Future<void> _showExport(
    ManagementMarginAnnualResultsModel result,
    ManagementMarginAnnualCurrencyModel selected,
  ) async {
    final action = await showDialog<_ExportAction>(
      context: context,
      builder: (context) => _ExportDialog(result: result, selected: selected),
    );
    if (action == null || !mounted) return;
    setState(() => _exporting = true);
    try {
      final snapshot = _reports.snapshot(
        result: result,
        allCurrencies: action.allCurrencies,
        selectedCurrencyId: selected.currencyId,
      );
      final saved = switch (action.kind) {
        _ExportKind.csv => await _reports.saveCsv(snapshot) != null,
        _ExportKind.pdf => await _reports.savePdf(snapshot) != null,
        _ExportKind.print => await _reports.printPdf(snapshot),
      };
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Devengado certificado exportado.'
                : 'Exportación cancelada.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar el devengado: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
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

  void _refresh() =>
      ref.invalidate(managementMarginAnnualResultsProvider(_year));

  void _resetScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_monthsScroll.hasClients) _monthsScroll.jumpTo(0);
    });
  }
}

class _AnnualToolbar extends StatelessWidget {
  const _AnnualToolbar({
    required this.result,
    required this.exporting,
    required this.onBack,
    required this.onPrevious,
    required this.onNext,
    required this.onCurrent,
    required this.onRefresh,
    required this.onExport,
  });

  final ManagementMarginAnnualResultsModel result;
  final bool exporting;
  final VoidCallback onBack;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCurrent;
  final VoidCallback onRefresh;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 820;
          if (compact) {
            return Row(
              children: [
                PulsoIconButton(
                  key: const Key('management-margin-annual-back-compact'),
                  icon: Icons.arrow_back,
                  tooltip: 'Volver al margen mensual',
                  onPressed: onBack,
                ),
                const SizedBox(width: 6),
                PulsoIconButton(
                  key: const Key('management-margin-annual-previous-compact'),
                  icon: Icons.chevron_left,
                  tooltip: 'Año anterior',
                  onPressed: onPrevious,
                ),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 40),
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
                ),
                PulsoIconButton(
                  key: const Key('management-margin-annual-next-compact'),
                  icon: Icons.chevron_right,
                  tooltip: 'Año siguiente',
                  onPressed: onNext,
                ),
                const SizedBox(width: 6),
                PulsoIconButton(
                  key: const Key('management-margin-annual-export-compact'),
                  icon: Icons.file_download_outlined,
                  tooltip: exporting ? 'Exportando…' : 'Exportar',
                  onPressed: exporting ? null : onExport,
                ),
                PulsoIconButton(
                  icon: Icons.refresh,
                  tooltip: 'Actualizar comparativa',
                  onPressed: onRefresh,
                ),
              ],
            );
          }
          return Row(
            children: [
              TextButton.icon(
                key: const Key('management-margin-annual-back'),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('VOLVER AL MES'),
              ),
              const Spacer(),
              PulsoIconButton(
                icon: Icons.chevron_left,
                tooltip: 'Año anterior',
                onPressed: onPrevious,
              ),
              Container(
                constraints: BoxConstraints(minWidth: 112, minHeight: 40),
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
              const Spacer(),
              TextButton(onPressed: onCurrent, child: const Text('AÑO ACTUAL')),
              TextButton.icon(
                key: const Key('management-margin-annual-export'),
                onPressed: exporting ? null : onExport,
                icon: exporting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('EXPORTAR'),
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

  final ManagementMarginAnnualResultsModel result;

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
          note: coverage.complete ? 'Cobertura completa' : 'Faltan cierres v3',
          emphasis: coverage.complete,
        ),
        PulsoMetricData(
          value: percentage,
          label: 'Cobertura verificable',
          note: 'Sin rellenar vacíos con cero',
        ),
        PulsoMetricData(
          value: coverage.pendingMonths.toString(),
          label: 'Meses pendientes',
          note: 'Sin snapshot R4.4 válido',
          warning: coverage.pendingMonths > 0,
        ),
        PulsoMetricData(
          value: result.currencies.length.toString(),
          label: 'Monedas con evidencia',
          note: 'Siempre separadas',
        ),
      ],
    );
  }
}

class _CompactCoverageBand extends StatelessWidget {
  const _CompactCoverageBand({required this.result});

  final ManagementMarginAnnualResultsModel result;

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
                width: 230,
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
                    fontSize: 26,
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

  final List<ManagementMarginAnnualCurrencyModel> currencies;
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
            if (constraints.maxWidth >= 560) ...[
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PulsoLabel('MONEDA DEL DEVENGADO'),
                    SizedBox(height: 3),
                    Text('Selector buscable; no convierte monedas a botones.'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
            SizedBox(
              width: constraints.maxWidth < 560 ? constraints.maxWidth : 380,
              child: DropdownMenu<String>(
                key: ValueKey('management-margin-annual-currency-$selectedId'),
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

  final ManagementMarginAnnualResultsModel result;
  final ManagementMarginAnnualCurrencyModel? currency;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final incomplete = !result.coverage.complete;
    final highest = currency?.highestMargin;
    final lowest = currency?.lowestMargin;
    final text =
        '${result.coverageNote} Los totales suman devengo mensual; los acumulados pertenecen solo al último corte.';
    if (compact) {
      return PulsoPanel(
        color: incomplete ? tokens.warningSoft : tokens.successSoft,
        borderColor: incomplete ? tokens.warning : tokens.success,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          text,
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
          const Text('Los meses ausentes no aportan cero ni proyección viva.'),
          if (highest != null && currency != null)
            Text(
              'Mayor margen: ${_monthName(highest.month)} · ${_moneyWithCurrency(highest.amount, currency!.currencyCode)}',
            ),
          if (lowest != null && currency != null)
            Text(
              'Menor margen: ${_monthName(lowest.month)} · ${_moneyWithCurrency(lowest.amount, currency!.currencyCode)}',
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

  final ManagementMarginAnnualMonthModel month;
  final ManagementMarginAnnualCurrencyModel? currency;
  final ManagementMarginAnnualCurrencyMonthModel? currencyMonth;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final stateColor = _stateColor(tokens, month.state);
    return Container(
      key: ValueKey('management-margin-annual-month-${month.month}'),
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
        SizedBox(width: 130, child: _monthIdentity(tokens, stateColor)),
        Expanded(child: _monthBody(tokens)),
        if (currencyMonth != null) ...[
          _amountColumn(tokens, 'INGRESO', currencyMonth!.revenue),
          _amountColumn(tokens, 'COSTO', currencyMonth!.directCost),
          _amountColumn(
            tokens,
            'MARGEN',
            currencyMonth!.directMargin,
            warning: currencyMonth!.directMargin.startsWith('-'),
          ),
          _amountColumn(
            tokens,
            'MARGEN - FIJO',
            currencyMonth!.marginAfterFixed,
          ),
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
              _compactAmount(tokens, 'INGRESO', currencyMonth!.revenue),
              _compactAmount(tokens, 'COSTO', currencyMonth!.directCost),
              _compactAmount(tokens, 'MARGEN', currencyMonth!.directMargin),
              _compactAmount(
                tokens,
                'MARGEN - FIJO',
                currencyMonth!.marginAfterFixed,
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
              ? 'Cierre válido; elija una moneda para ver el devengo.'
              : currencyMonth == null
              ? 'Cierre válido sin devengo en ${currency!.currencyCode}.'
              : 'Cierre R4.4 íntegro · evidencia ${_shortHash(month.sha256)}'
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
    String value, {
    bool warning = false,
  }) {
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          PulsoLabel(label),
          const SizedBox(height: 4),
          Text(
            _exactMoney(value),
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

  Widget _compactAmount(PulsoTokens tokens, String label, String value) {
    return SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PulsoLabel(label),
          const SizedBox(height: 2),
          Text(
            _exactMoney(value),
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

enum _ExportKind { csv, pdf, print }

class _ExportAction {
  const _ExportAction({required this.kind, required this.allCurrencies});

  final _ExportKind kind;
  final bool allCurrencies;
}

class _ExportDialog extends StatefulWidget {
  const _ExportDialog({required this.result, required this.selected});

  final ManagementMarginAnnualResultsModel result;
  final ManagementMarginAnnualCurrencyModel selected;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  final _scroll = ScrollController();
  bool _allCurrencies = true;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return AlertDialog(
      key: const Key('management-margin-annual-export-dialog'),
      title: const Text('Exportar devengado certificado'),
      content: SizedBox(
        width: 560,
        height: 360,
        child: Scrollbar(
          key: const Key('management-margin-annual-export-scrollbar'),
          controller: _scroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            key: const PageStorageKey('management-margin-annual-export-scroll'),
            controller: _scroll,
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Año ${widget.result.year}. Solo se exportan meses con evidencia certificada; los meses sin R4.4 quedan rotulados.',
                ),
                const SizedBox(height: 14),
                PulsoPanel(
                  padding: const EdgeInsets.all(10),
                  color: tokens.raised,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PulsoLabel('ALCANCE'),
                      _ScopeChoice(
                        selected: _allCurrencies,
                        label: 'Todas las monedas por secciones',
                        onTap: () => setState(() => _allCurrencies = true),
                      ),
                      _ScopeChoice(
                        selected: !_allCurrencies,
                        label: 'Solo ${widget.selected.currencyCode}',
                        onTap: () => setState(() => _allCurrencies = false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'PDF: lectura e impresión. CSV: conciliación externa con estado del mes, ID del cierre y SHA-256.',
                  style: TextStyle(color: tokens.chalkDim),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCELAR'),
        ),
        OutlinedButton.icon(
          key: const Key('management-margin-annual-export-csv'),
          onPressed: () => Navigator.of(context).pop(
            _ExportAction(kind: _ExportKind.csv, allCurrencies: _allCurrencies),
          ),
          icon: const Icon(Icons.table_chart_outlined, size: 16),
          label: const Text('CSV'),
        ),
        OutlinedButton.icon(
          key: const Key('management-margin-annual-export-print'),
          onPressed: () => Navigator.of(context).pop(
            _ExportAction(
              kind: _ExportKind.print,
              allCurrencies: _allCurrencies,
            ),
          ),
          icon: const Icon(Icons.print_outlined, size: 16),
          label: const Text('IMPRIMIR'),
        ),
        FilledButton.icon(
          key: const Key('management-margin-annual-export-pdf'),
          onPressed: () => Navigator.of(context).pop(
            _ExportAction(kind: _ExportKind.pdf, allCurrencies: _allCurrencies),
          ),
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
          label: const Text('PDF'),
        ),
      ],
    );
  }
}

class _ScopeChoice extends StatelessWidget {
  const _ScopeChoice({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        size: 18,
        color: selected ? tokens.accent : tokens.muted,
      ),
      title: Text(label),
      onTap: onTap,
    );
  }
}

Color _stateColor(PulsoTokens tokens, String state) => switch (state) {
  'CERTIFICADO' => tokens.success,
  'EN_CURSO' || 'FUTURO' => tokens.muted,
  'SNAPSHOT_ANTERIOR' || 'BLOQUEO_INVALIDO' => tokens.warning,
  _ => tokens.danger,
};

String _stateLabel(String state) => switch (state) {
  'CERTIFICADO' => 'CERTIFICADO',
  'SIN_CIERRE' => 'SIN CIERRE',
  'REABIERTO' => 'REABIERTO',
  'SNAPSHOT_ANTERIOR' => 'CIERRE PRE-R4.4',
  'BLOQUEO_INVALIDO' => 'BLOQUEO INVÁLIDO',
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

String _moneyWithCurrency(String value, String currency) =>
    '${_exactMoney(value)} $currency';

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
