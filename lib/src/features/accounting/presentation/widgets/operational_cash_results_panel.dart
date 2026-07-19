import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/operational_results_models.dart';
import '../../data/services/operational_results_report_service.dart';
import '../state/accounting_providers.dart';
import 'management_margin_panel.dart';
import 'membership_revenue_panel.dart';
import 'operational_annual_results_panel.dart';
import 'trainer_service_cost_panel.dart';

final _resultMoney = NumberFormat('#,##0.00');

enum _ResultsSection { obligations, concepts, accounts, issues }

class OperationalCashResultsPanel extends ConsumerStatefulWidget {
  const OperationalCashResultsPanel({
    super.key,
    this.onOpenTrainerPayments,
    this.onOpenRefunds,
    this.onOpenTreasury,
  });

  final VoidCallback? onOpenTrainerPayments;
  final VoidCallback? onOpenRefunds;
  final VoidCallback? onOpenTreasury;

  @override
  ConsumerState<OperationalCashResultsPanel> createState() =>
      _OperationalCashResultsPanelState();
}

class _OperationalCashResultsPanelState
    extends ConsumerState<OperationalCashResultsPanel> {
  static const _reports = OperationalResultsReportService();
  final _conceptScroll = ScrollController();
  final _accountScroll = ScrollController();
  final _issueScroll = ScrollController();
  final _obligationScroll = ScrollController();
  final _accountSearch = TextEditingController();
  String? _month;
  String? _currencyId;
  String _accountQuery = '';
  _ResultsSection _compactSection = _ResultsSection.concepts;
  bool _exporting = false;
  bool _annualView = false;
  bool _revenueView = false;
  bool _costView = false;
  bool _marginView = false;

  @override
  void dispose() {
    _conceptScroll.dispose();
    _accountScroll.dispose();
    _issueScroll.dispose();
    _obligationScroll.dispose();
    _accountSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_marginView) {
      return ManagementMarginPanel(
        initialMonth: _month,
        onMonthChanged: (month) => setState(() => _month = month),
        onBack: () => setState(() => _marginView = false),
      );
    }
    if (_costView) {
      return TrainerServiceCostPanel(
        initialMonth: _month,
        onMonthChanged: (month) => setState(() => _month = month),
        onBack: () => setState(() => _costView = false),
      );
    }
    if (_revenueView) {
      return MembershipRevenuePanel(
        initialMonth: _month,
        onMonthChanged: (month) => setState(() => _month = month),
        onBack: () => setState(() => _revenueView = false),
      );
    }
    if (_annualView) {
      return OperationalAnnualResultsPanel(
        onBack: () => setState(() => _annualView = false),
      );
    }
    final state = ref.watch(operationalResultsProvider(_month));
    return state.when(
      loading: () => const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.loading,
          message: 'Separando cobros, salidas y movimientos por moneda…',
        ),
      ),
      error: (error, _) => PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.error,
          message: 'No se pudo calcular el resultado operativo.\n$error',
          onRetry: _refresh,
        ),
      ),
      data: _buildResult,
    );
  }

  Widget _buildResult(OperationalResultsModel result) {
    if (result.currencies.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PeriodToolbar(
            result: result,
            onPrevious: () => _moveMonth(result.month, -1),
            onNext: () => _moveMonth(result.month, 1),
            onCurrent: () => setState(() => _month = null),
            onRefresh: _refresh,
            onRevenue: () => setState(() => _revenueView = true),
            onCost: () => setState(() => _costView = true),
            onMargin: () => setState(() => _marginView = true),
            onAnnual: () => setState(() => _annualView = true),
            onExport: null,
            exporting: _exporting,
          ),
          const SizedBox(height: 10),
          const Expanded(
            child: PulsoPanel(
              child: PulsoStateView(
                kind: PulsoStateKind.empty,
                message: 'No hay movimientos de caja en este mes.',
              ),
            ),
          ),
        ],
      );
    }

    final selected =
        result.currencies
            .where((item) => item.currencyId == _currencyId)
            .firstOrNull ??
        result.currencies.first;
    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded = constraints.maxWidth >= 840;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PeriodToolbar(
              result: result,
              onPrevious: () => _moveMonth(result.month, -1),
              onNext: () => _moveMonth(result.month, 1),
              onCurrent: () => setState(() => _month = null),
              onRefresh: _refresh,
              onRevenue: () => setState(() => _revenueView = true),
              onCost: () => setState(() => _costView = true),
              onMargin: () => setState(() => _marginView = true),
              onAnnual: () => setState(() => _annualView = true),
              onExport: () => _openExport(result, selected.currencyId),
              exporting: _exporting,
            ),
            const SizedBox(height: 10),
            _CurrencyToolbar(
              currencies: result.currencies,
              selectedId: selected.currencyId,
              onSelected: _selectCurrency,
            ),
            const SizedBox(height: 10),
            _OperationalMetricArea(
              currency: selected,
              cashMetrics: [
                _CashMetricData(
                  value: _money(selected.cash.grossCollections),
                  label: 'Dinero cobrado',
                  note: '${selected.currencyCode} · planes',
                  emphasis: true,
                ),
                _CashMetricData(
                  value: _money(selected.cash.ledgerExits),
                  label: 'Dinero que salió',
                  note: '${selected.currencyCode} · libro de caja',
                ),
                _CashMetricData(
                  value: _money(selected.cash.operationalFlow),
                  label: 'Flujo operativo',
                  note: '${selected.currencyCode} · no es ganancia',
                  warning: _numeric(selected.cash.operationalFlow) < 0,
                ),
                _CashMetricData(
                  value: _money(selected.cash.ledgerNet),
                  label: 'Neto del libro',
                  note: '${selected.currencyCode} · todas las fuentes',
                ),
              ],
            ),
            const SizedBox(height: 10),
            _QualityNotice(result: result, currency: selected),
            const SizedBox(height: 10),
            Expanded(
              child: constraints.maxWidth >= 1180
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 4,
                          child: _ObligationsPanel(
                            currency: selected,
                            scrollController: _obligationScroll,
                            onOpenTrainerPayments: widget.onOpenTrainerPayments,
                            onOpenRefunds: widget.onOpenRefunds,
                            onOpenTreasury: widget.onOpenTreasury,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 4,
                          child: _ConceptsPanel(
                            currency: selected,
                            scrollController: _conceptScroll,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 6,
                          child: _AccountsPanel(
                            currency: selected,
                            query: _accountQuery,
                            searchController: _accountSearch,
                            scrollController: _accountScroll,
                            onQueryChanged: _updateAccountQuery,
                          ),
                        ),
                      ],
                    )
                  : expanded
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 4,
                          child: _ConceptsPanel(
                            currency: selected,
                            scrollController: _conceptScroll,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 6,
                          child: _AccountsPanel(
                            currency: selected,
                            query: _accountQuery,
                            searchController: _accountSearch,
                            scrollController: _accountScroll,
                            onQueryChanged: _updateAccountQuery,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionSelector(
                          selected: _compactSection,
                          onSelected: (value) =>
                              setState(() => _compactSection = value),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: switch (_compactSection) {
                            _ResultsSection.obligations => _ObligationsPanel(
                              currency: selected,
                              scrollController: _obligationScroll,
                              onOpenTrainerPayments:
                                  widget.onOpenTrainerPayments,
                              onOpenRefunds: widget.onOpenRefunds,
                              onOpenTreasury: widget.onOpenTreasury,
                            ),
                            _ResultsSection.concepts => _ConceptsPanel(
                              currency: selected,
                              scrollController: _conceptScroll,
                            ),
                            _ResultsSection.accounts => _AccountsPanel(
                              currency: selected,
                              query: _accountQuery,
                              searchController: _accountSearch,
                              scrollController: _accountScroll,
                              onQueryChanged: _updateAccountQuery,
                            ),
                            _ResultsSection.issues => _IssuesPanel(
                              result: result,
                              currency: selected,
                              scrollController: _issueScroll,
                            ),
                          },
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openExport(
    OperationalResultsModel result,
    String selectedCurrencyId,
  ) async {
    final request = await showDialog<_OperationalExportRequest>(
      context: context,
      builder: (_) => _OperationalExportDialog(
        result: result,
        selectedCurrencyId: selectedCurrencyId,
      ),
    );
    if (request == null || !mounted) return;
    setState(() => _exporting = true);
    try {
      final snapshot = _reports.snapshot(
        result: result,
        allCurrencies: request.allCurrencies,
        selectedCurrencyId: request.selectedCurrencyId,
      );
      final message = switch (request.action) {
        _OperationalExportAction.pdf =>
          await _reports.savePdf(snapshot) == null
              ? null
              : 'Informe PDF guardado.',
        _OperationalExportAction.csv =>
          await _reports.saveCsv(snapshot) == null
              ? null
              : 'Archivo CSV guardado.',
        _OperationalExportAction.print =>
          await _reports.printPdf(snapshot)
              ? 'Informe enviado a impresión.'
              : null,
      };
      if (mounted && message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo exportar el informe: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _refresh() => ref.invalidate(operationalResultsProvider(_month));

  void _selectCurrency(String? id) {
    if (id == null || id == _currencyId) return;
    _accountSearch.clear();
    setState(() {
      _currencyId = id;
      _accountQuery = '';
    });
    _resetScrolls();
  }

  void _updateAccountQuery(String value) {
    setState(() => _accountQuery = value.trim().toLowerCase());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_accountScroll.hasClients) _accountScroll.jumpTo(0);
    });
  }

  void _moveMonth(String value, int delta) {
    final parts = value.split('-');
    if (parts.length != 2) return;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) return;
    final target = DateTime.utc(year, month + delta);
    setState(() {
      _month =
          '${target.year.toString().padLeft(4, '0')}-'
          '${target.month.toString().padLeft(2, '0')}';
      _currencyId = null;
      _accountQuery = '';
      _accountSearch.clear();
    });
    _resetScrolls();
  }

  void _resetScrolls() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in [
        _obligationScroll,
        _conceptScroll,
        _accountScroll,
        _issueScroll,
      ]) {
        if (controller.hasClients) controller.jumpTo(0);
      }
    });
  }
}

class _PeriodToolbar extends StatelessWidget {
  const _PeriodToolbar({
    required this.result,
    required this.onPrevious,
    required this.onNext,
    required this.onCurrent,
    required this.onRefresh,
    required this.onRevenue,
    required this.onCost,
    required this.onMargin,
    required this.onAnnual,
    required this.onExport,
    required this.exporting,
  });

  final OperationalResultsModel result;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCurrent;
  final VoidCallback onRefresh;
  final VoidCallback onRevenue;
  final VoidCallback onCost;
  final VoidCallback onMargin;
  final VoidCallback onAnnual;
  final VoidCallback? onExport;
  final bool exporting;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final period = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PulsoIconButton(
                icon: Icons.chevron_left,
                tooltip: 'Mes anterior',
                onPressed: onPrevious,
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 142, minHeight: 40),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: tokens.raised,
                  border: Border.symmetric(
                    horizontal: BorderSide(color: tokens.line),
                  ),
                ),
                child: Text(
                  _monthLabel(result.month).toUpperCase(),
                  style: TextStyle(
                    color: tokens.chalk,
                    fontFamily: PulsoFonts.mono,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              PulsoIconButton(
                icon: Icons.chevron_right,
                tooltip: 'Mes siguiente',
                onPressed: onNext,
              ),
            ],
          );
          final status = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusBadge(state: result.periodState),
              const SizedBox(width: 8),
              TextButton(onPressed: onCurrent, child: const Text('MES ACTUAL')),
              TextButton.icon(
                key: const Key('membership-revenue-action'),
                onPressed: onRevenue,
                icon: const Icon(Icons.timelapse_outlined, size: 16),
                label: const Text('YA GANADO'),
              ),
              TextButton.icon(
                key: const Key('trainer-service-cost-action'),
                onPressed: onCost,
                icon: const Icon(Icons.fitness_center_outlined, size: 16),
                label: const Text('COSTO SERVICIO'),
              ),
              TextButton.icon(
                key: const Key('management-margin-action'),
                onPressed: onMargin,
                icon: const Icon(Icons.stacked_line_chart_outlined, size: 16),
                label: const Text('MARGEN'),
              ),
              TextButton.icon(
                key: const Key('operational-annual-action'),
                onPressed: onAnnual,
                icon: const Icon(Icons.calendar_view_month_outlined, size: 16),
                label: const Text('VER AÑO'),
              ),
              TextButton.icon(
                key: const Key('operational-export-action'),
                onPressed: exporting ? null : onExport,
                icon: exporting
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share_outlined, size: 16),
                label: const Text('EXPORTAR'),
              ),
              PulsoIconButton(
                icon: Icons.refresh,
                tooltip: 'Actualizar resultado',
                onPressed: onRefresh,
              ),
            ],
          );
          if (constraints.maxWidth < 1500) {
            final tight = constraints.maxWidth < 480;
            Widget action(Widget button) => tight
                ? SizedBox.square(
                    dimension: 38,
                    child: FittedBox(child: button),
                  )
                : button;
            return Row(
              children: [
                PulsoIconButton(
                  icon: Icons.chevron_left,
                  tooltip: 'Mes anterior',
                  onPressed: onPrevious,
                ),
                Expanded(
                  child: InkWell(
                    onTap: onCurrent,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 40),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      color: tokens.raised,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _monthLabel(result.month).toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.chalk,
                              fontFamily: PulsoFonts.mono,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            result.periodState.replaceAll('_', ' '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.accent,
                              fontFamily: PulsoFonts.mono,
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                PulsoIconButton(
                  icon: Icons.chevron_right,
                  tooltip: 'Mes siguiente',
                  onPressed: onNext,
                ),
                const SizedBox(width: 3),
                action(
                  PulsoIconButton(
                    key: const Key('membership-revenue-action-compact'),
                    icon: Icons.timelapse_outlined,
                    tooltip: 'Ver ingreso ya ganado',
                    onPressed: onRevenue,
                  ),
                ),
                action(
                  PulsoIconButton(
                    key: const Key('trainer-service-cost-action-compact'),
                    icon: Icons.fitness_center_outlined,
                    tooltip: 'Ver costo del servicio del entrenador',
                    onPressed: onCost,
                  ),
                ),
                action(
                  PulsoIconButton(
                    key: const Key('management-margin-action-compact'),
                    icon: Icons.stacked_line_chart_outlined,
                    tooltip: 'Ver margen gerencial',
                    onPressed: onMargin,
                  ),
                ),
                action(
                  PulsoIconButton(
                    key: const Key('operational-annual-action-compact'),
                    icon: Icons.calendar_view_month_outlined,
                    tooltip: 'Ver comparativa anual',
                    onPressed: onAnnual,
                  ),
                ),
                action(
                  PulsoIconButton(
                    key: const Key('operational-export-action-compact'),
                    icon: Icons.ios_share_outlined,
                    tooltip: exporting
                        ? 'Generando informe'
                        : 'Exportar informe',
                    onPressed: exporting ? null : onExport,
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: period),
              const SizedBox(width: 12),
              status,
            ],
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final review = state == 'REQUIERE_REVISION';
    final reopened = state == 'REABIERTO';
    final certified = state == 'CERTIFICADO';
    final color = review
        ? tokens.warning
        : reopened
        ? tokens.danger
        : certified
        ? tokens.success
        : tokens.muted;
    final label = switch (state) {
      'REQUIERE_REVISION' => 'REQUIERE REVISIÓN',
      'REABIERTO' => 'REABIERTO',
      'CERTIFICADO' => 'CERTIFICADO',
      _ => 'PROVISIONAL',
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: PulsoFonts.mono,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CurrencyToolbar extends StatelessWidget {
  const _CurrencyToolbar({
    required this.currencies,
    required this.selectedId,
    required this.onSelected,
  });

  final List<OperationalResultsCurrencyModel> currencies;
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
                    PulsoLabel('MONEDA DEL INFORME'),
                    SizedBox(height: 3),
                    Text('Cada moneda conserva sus propios totales.'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
            SizedBox(
              width: constraints.maxWidth < 520 ? constraints.maxWidth : 340,
              child: DropdownMenu<String>(
                key: ValueKey('operational-currency-$selectedId'),
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
                textStyle: TextStyle(
                  color: tokens.chalk,
                  fontFamily: PulsoFonts.mono,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                onSelected: onSelected,
                dropdownMenuEntries: currencies
                    .map(
                      (item) => DropdownMenuEntry(
                        value: item.currencyId,
                        label:
                            '${item.currencyCode} · ${item.accounts.length} cuenta(s)',
                        leadingIcon: Icon(
                          item.requiresAttention
                              ? Icons.error_outline
                              : Icons.account_balance_wallet_outlined,
                          size: 16,
                          color: item.requiresAttention
                              ? tokens.warning
                              : tokens.muted,
                        ),
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

class _CashMetricData {
  const _CashMetricData({
    required this.value,
    required this.label,
    required this.note,
    this.emphasis = false,
    this.warning = false,
  });

  final String value;
  final String label;
  final String note;
  final bool emphasis;
  final bool warning;
}

class _CashMetricStrip extends StatelessWidget {
  const _CashMetricStrip({required this.metrics});

  final List<_CashMetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        if (constraints.maxWidth < 840) {
          return SizedBox(
            height: 82,
            child: ListView.separated(
              key: const PageStorageKey('operational-metrics'),
              scrollDirection: Axis.horizontal,
              itemCount: metrics.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) => SizedBox(
                width: 190,
                child: _CashMetric(data: metrics[index]),
              ),
            ),
          );
        }
        return SizedBox(
          height: 82,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < metrics.length; index++) ...[
                Expanded(child: _CashMetric(data: metrics[index])),
                if (index != metrics.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CashMetric extends StatelessWidget {
  const _CashMetric({required this.data});

  final _CashMetricData data;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = data.warning
        ? tokens.warning
        : data.emphasis
        ? tokens.accent
        : tokens.chalk;
    return PulsoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.chalkDim,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 2,
                child: Text(
                  data.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: tokens.muted,
                    fontFamily: PulsoFonts.mono,
                    fontSize: 7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              data.value,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontFamily: PulsoFonts.display,
                fontSize: 23,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationalMetricArea extends StatelessWidget {
  const _OperationalMetricArea({
    required this.currency,
    required this.cashMetrics,
  });

  final OperationalResultsCurrencyModel currency;
  final List<_CashMetricData> cashMetrics;

  @override
  Widget build(BuildContext context) {
    final obligationMetrics = _obligationMetrics(currency);
    return LayoutBuilder(
      builder: (_, constraints) {
        if (constraints.maxWidth < 840) {
          return _CashMetricStrip(
            metrics: [...cashMetrics, ...obligationMetrics],
          );
        }
        return Column(
          children: [
            _CashMetricStrip(metrics: cashMetrics),
            const SizedBox(height: 10),
            _CashMetricStrip(metrics: obligationMetrics),
          ],
        );
      },
    );
  }
}

List<_CashMetricData> _obligationMetrics(
  OperationalResultsCurrencyModel currency,
) {
  final obligations = currency.obligations;
  final unavailable = !obligations.available;
  String value(String? amount) =>
      unavailable || amount == null ? '—' : _money(amount);
  return [
    _CashMetricData(
      value: value(obligations.immediateReserve),
      label: 'Reserva inmediata',
      note: '${currency.currencyCode} · ganado + devoluciones',
      emphasis: true,
    ),
    _CashMetricData(
      value: value(obligations.trainerPayableNow),
      label: 'Pagadero ahora',
      note: '${obligations.overdueInstallmentCount} concepto(s)',
      warning: obligations.overdueInstallmentCount > 0,
    ),
    _CashMetricData(
      value: value(obligations.trainerFuture),
      label: 'Fondo futuro',
      note: '${currency.currencyCode} · aún no ganado',
    ),
    _CashMetricData(
      value: value(obligations.refundsPending),
      label: 'Por devolver',
      note: '${obligations.pendingRefundCount} solicitud(es)',
      warning: obligations.pendingRefundCount > 0,
    ),
  ];
}

class _ObligationsPanel extends StatelessWidget {
  const _ObligationsPanel({
    required this.currency,
    required this.scrollController,
    required this.onOpenTrainerPayments,
    required this.onOpenRefunds,
    required this.onOpenTreasury,
  });

  final OperationalResultsCurrencyModel currency;
  final ScrollController scrollController;
  final VoidCallback? onOpenTrainerPayments;
  final VoidCallback? onOpenRefunds;
  final VoidCallback? onOpenTreasury;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final obligations = currency.obligations;
    final itemCount = obligations.trainers.length + obligations.refunds.length;
    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, panelConstraints) {
          final compressed = panelConstraints.maxHeight < 180;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compressed)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: PulsoLabel('RESERVA · ${currency.currencyCode}'),
                      ),
                      PulsoIconButton(
                        key: const Key('operational-action-pay-trainers'),
                        icon: Icons.payments_outlined,
                        tooltip: 'Pagar entrenadores',
                        onPressed:
                            obligations.available &&
                                obligations.pendingTrainerCount > 0
                            ? onOpenTrainerPayments
                            : null,
                      ),
                      const SizedBox(width: 4),
                      PulsoIconButton(
                        key: const Key('operational-action-refunds'),
                        icon: Icons.assignment_return_outlined,
                        tooltip: 'Resolver devoluciones',
                        danger: true,
                        onPressed:
                            obligations.available &&
                                obligations.pendingRefundCount > 0
                            ? onOpenRefunds
                            : null,
                      ),
                      const SizedBox(width: 4),
                      PulsoIconButton(
                        key: const Key('operational-action-treasury'),
                        icon: Icons.fact_check_outlined,
                        tooltip: 'Cerrar caja',
                        onPressed: onOpenTreasury,
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: PulsoLabel(
                              'RESERVAS Y ACCIONES · ${currency.currencyCode}',
                            ),
                          ),
                          Text(
                            obligations.cutoffDate == null
                                ? 'SIN CORTE'
                                : 'CORTE ${_displayCalendarDate(obligations.cutoffDate!)}',
                            style: TextStyle(
                              color: tokens.muted,
                              fontFamily: PulsoFonts.mono,
                              fontSize: 7,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              key: const Key('operational-action-pay-trainers'),
                              icon: Icons.payments_outlined,
                              label: 'Pagar',
                              onPressed:
                                  obligations.available &&
                                      obligations.pendingTrainerCount > 0
                                  ? onOpenTrainerPayments
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: _ActionButton(
                              key: const Key('operational-action-refunds'),
                              icon: Icons.assignment_return_outlined,
                              label: 'Devolver',
                              onPressed:
                                  obligations.available &&
                                      obligations.pendingRefundCount > 0
                                  ? onOpenRefunds
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: _ActionButton(
                              key: const Key('operational-action-treasury'),
                              icon: Icons.fact_check_outlined,
                              label: 'Cerrar',
                              onPressed: onOpenTreasury,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              Divider(height: 1, color: tokens.line),
              Expanded(
                child: !obligations.available
                    ? PulsoStateView(
                        kind: PulsoStateKind.empty,
                        message: obligations.reason,
                      )
                    : itemCount == 0
                    ? const PulsoStateView(
                        kind: PulsoStateKind.empty,
                        message: 'No hay reservas ni devoluciones pendientes.',
                      )
                    : Scrollbar(
                        key: const Key('operational-obligations-scrollbar'),
                        controller: scrollController,
                        thumbVisibility: true,
                        child: ListView.separated(
                          key: PageStorageKey(
                            'operational-obligations-${currency.currencyId}',
                          ),
                          controller: scrollController,
                          primary: false,
                          itemCount: itemCount,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: tokens.line),
                          itemBuilder: (_, index) {
                            if (index < obligations.trainers.length) {
                              return _TrainerObligationRow(
                                item: obligations.trainers[index],
                                currencyCode: currency.currencyCode,
                              );
                            }
                            return _PendingRefundRow(
                              item: obligations
                                  .refunds[index - obligations.trainers.length],
                              currencyCode: currency.currencyCode,
                            );
                          },
                        ),
                      ),
              ),
              if (!compressed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  color: tokens.raised,
                  child: Text(
                    obligations.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tokens.muted, fontSize: 8),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        textStyle: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TrainerObligationRow extends StatelessWidget {
  const _TrainerObligationRow({required this.item, required this.currencyCode});

  final OperationalTrainerObligationModel item;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final warning = item.overdueConceptCount > 0 || item.requiresReview;
    return Padding(
      key: ValueKey('operational-trainer-obligation-${item.trainerId}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                warning ? Icons.warning_amber_rounded : Icons.person_outline,
                size: 17,
                color: warning ? tokens.warning : tokens.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.trainerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.chalk,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$currencyCode ${_money(item.payableNow)}',
                style: TextStyle(
                  color: warning ? tokens.warning : tokens.chalkDim,
                  fontFamily: PulsoFonts.mono,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Ganado ${_money(item.earnedPending)} · futuro ${_money(item.future)} · '
            '${item.commissionConceptCount} comisión / ${item.fixedConceptCount} fijo',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.muted,
              fontFamily: PulsoFonts.mono,
              fontSize: 8,
            ),
          ),
          if (item.nextPaymentDate != null) ...[
            const SizedBox(height: 3),
            Text(
              'Próximo corte: ${_displayCalendarDate(item.nextPaymentDate!)}',
              style: TextStyle(color: tokens.muted2, fontSize: 8),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingRefundRow extends StatelessWidget {
  const _PendingRefundRow({required this.item, required this.currencyCode});

  final OperationalPendingRefundModel item;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Padding(
      key: ValueKey('operational-refund-${item.adjustmentId}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Icon(
            Icons.assignment_return_outlined,
            size: 17,
            color: tokens.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.chalk,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${item.clientId} · solicitud ${_displayInstantDate(item.requestedAt)}',
                  style: TextStyle(
                    color: tokens.muted,
                    fontFamily: PulsoFonts.mono,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$currencyCode ${_money(item.amount)}',
            style: TextStyle(
              color: tokens.danger,
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityNotice extends StatelessWidget {
  const _QualityNotice({required this.result, required this.currency});

  final OperationalResultsModel result;
  final OperationalResultsCurrencyModel currency;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final quality = currency.quality;
    final attention = currency.requiresAttention;
    final color = attention ? tokens.warning : tokens.success;
    final text = result.certified
        ? 'Corte firmado · SHA-256 verificado · cifras congeladas'
        : attention
        ? '${quality.pendingClassification} por clasificar · '
              '${quality.sourceReviews} revisiones · '
              '${quality.movementsWithoutAccount} sin cuenta · '
              '${currency.obligations.reviewCount} obligaciones por revisar'
        : 'Movimientos clasificados y vinculados a cuenta';
    return PulsoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderColor: color.withValues(alpha: 0.5),
      child: Row(
        children: [
          Icon(
            attention ? Icons.warning_amber_rounded : Icons.verified_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '$text · ${quality.openBusinessDays} jornada(s) por cerrar',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.chalkDim, fontSize: 11),
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: result.certificationNote,
            child: Text(
              result.certified ? 'CORTE CERTIFICADO' : 'CAJA, NO GANANCIA',
              style: TextStyle(
                color: tokens.accent,
                fontFamily: PulsoFonts.mono,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionSelector extends StatelessWidget {
  const _SectionSelector({required this.selected, required this.onSelected});

  final _ResultsSection selected;
  final ValueChanged<_ResultsSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return PulsoPanel(
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          for (final item in _ResultsSection.values)
            Expanded(
              child: _SectionButton(
                label: switch (item) {
                  _ResultsSection.obligations => 'Reservas',
                  _ResultsSection.concepts => 'Conceptos',
                  _ResultsSection.accounts => 'Cuentas',
                  _ResultsSection.issues => 'Incidencias',
                },
                selected: selected == item,
                onTap: () => onSelected(item),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
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
    return Material(
      color: selected ? tokens.accentSoft : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: 38),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: selected ? tokens.accent : tokens.muted,
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConceptsPanel extends StatelessWidget {
  const _ConceptsPanel({
    required this.currency,
    required this.scrollController,
  });

  final OperationalResultsCurrencyModel currency;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final maximum = currency.concepts.fold<double>(
      0,
      (value, item) => math.max(value, _numeric(item.cashEffect).abs()),
    );
    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PulsoLabel(
                  'ENTRADAS Y SALIDAS POR CONCEPTO · ${currency.currencyCode}',
                ),
                const SizedBox(height: 4),
                Text(
                  'El efecto muestra cuánto suma o resta al flujo.',
                  style: TextStyle(color: tokens.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.line),
          Expanded(
            child: currency.concepts.isEmpty
                ? const PulsoStateView(
                    kind: PulsoStateKind.empty,
                    message: 'No hay conceptos en esta moneda.',
                  )
                : Scrollbar(
                    key: const Key('operational-concepts-scrollbar'),
                    controller: scrollController,
                    thumbVisibility: true,
                    child: ListView.separated(
                      key: PageStorageKey(
                        'operational-concepts-${currency.currencyId}',
                      ),
                      controller: scrollController,
                      primary: false,
                      itemCount: currency.concepts.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: tokens.line),
                      itemBuilder: (_, index) => _ConceptRow(
                        item: currency.concepts[index],
                        currencyCode: currency.currencyCode,
                        maximum: maximum,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ConceptRow extends StatelessWidget {
  const _ConceptRow({
    required this.item,
    required this.currencyCode,
    required this.maximum,
  });

  final OperationalConceptResultModel item;
  final String currencyCode;
  final double maximum;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final effect = _numeric(item.cashEffect);
    final color = item.requiresReview
        ? tokens.warning
        : effect < 0
        ? tokens.danger
        : tokens.success;
    final ratio = maximum <= 0 ? 0.0 : (effect.abs() / maximum).clamp(0.0, 1.0);
    return Padding(
      key: ValueKey('operational-concept-${item.category}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.chalk,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$currencyCode ${_money(item.cashEffect)}',
                style: TextStyle(
                  color: color,
                  fontFamily: PulsoFonts.mono,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          LayoutBuilder(
            builder: (_, constraints) => Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 3,
                width: math.max(2.0, constraints.maxWidth * ratio),
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '+${_money(item.entries)} · −${_money(item.exits)} · '
            '${item.movementCount} movimiento(s) · ${item.scope.toLowerCase()}',
            style: TextStyle(
              color: tokens.muted,
              fontFamily: PulsoFonts.mono,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountsPanel extends StatelessWidget {
  const _AccountsPanel({
    required this.currency,
    required this.query,
    required this.searchController,
    required this.scrollController,
    required this.onQueryChanged,
  });

  final OperationalResultsCurrencyModel currency;
  final String query;
  final TextEditingController searchController;
  final ScrollController scrollController;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final accounts = currency.accounts
        .where((item) {
          if (query.isEmpty) return true;
          return item.name.toLowerCase().contains(query) ||
              (item.id?.toLowerCase().contains(query) ?? false);
        })
        .toList(growable: false);
    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PulsoLabel(
                        'DESGLOSE POR CUENTA · ${currency.currencyCode}',
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${accounts.length} de ${currency.accounts.length} cuenta(s)',
                        style: TextStyle(color: tokens.muted, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 220,
                  height: 36,
                  child: TextField(
                    key: const Key('operational-account-search'),
                    controller: searchController,
                    onChanged: onQueryChanged,
                    style: TextStyle(
                      color: tokens.chalk,
                      fontFamily: PulsoFonts.mono,
                      fontSize: 10,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar cuenta…',
                      prefixIcon: Icon(
                        Icons.search,
                        size: 16,
                        color: tokens.muted,
                      ),
                      filled: true,
                      fillColor: tokens.raised,
                      isDense: true,
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.line),
          LayoutBuilder(
            builder: (_, constraints) =>
                _AccountHeader(compact: constraints.maxWidth < 620),
          ),
          Expanded(
            child: accounts.isEmpty
                ? const PulsoStateView(
                    kind: PulsoStateKind.empty,
                    message: 'No hay cuentas que coincidan con la búsqueda.',
                  )
                : Scrollbar(
                    key: const Key('operational-accounts-scrollbar'),
                    controller: scrollController,
                    thumbVisibility: true,
                    child: ListView.separated(
                      key: PageStorageKey(
                        'operational-accounts-${currency.currencyId}',
                      ),
                      controller: scrollController,
                      primary: false,
                      itemCount: accounts.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: tokens.line),
                      itemBuilder: (_, index) => _AccountRow(
                        account: accounts[index],
                        currencyCode: currency.currencyCode,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    Widget label(String value) => Text(
      value,
      style: TextStyle(
        color: tokens.muted,
        fontFamily: PulsoFonts.mono,
        fontSize: 7,
      ),
    );
    return Container(
      color: tokens.raised,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(
        children: compact
            ? [
                Expanded(flex: 5, child: label('CUENTA')),
                Expanded(flex: 3, child: label('FLUJO')),
                Expanded(flex: 3, child: label('NETO')),
              ]
            : [
                Expanded(flex: 5, child: label('CUENTA')),
                Expanded(flex: 2, child: label('ENTRADAS')),
                Expanded(flex: 2, child: label('SALIDAS')),
                Expanded(flex: 2, child: label('FLUJO')),
                Expanded(flex: 2, child: label('NETO')),
              ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.currencyCode});

  final OperationalAccountResultModel account;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return LayoutBuilder(
      builder: (_, constraints) {
        final compact = constraints.maxWidth < 620;
        Widget amount(String value) => Text(
          _money(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.chalkDim,
            fontFamily: PulsoFonts.mono,
            fontSize: 9,
          ),
        );
        final identity = Row(
          children: [
            Container(
              width: 4,
              height: 34,
              color: account.requiresReview ? tokens.warning : tokens.accent,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.chalk,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$currencyCode · ${account.movementCount} movimiento(s)',
                    style: TextStyle(
                      color: tokens.muted,
                      fontFamily: PulsoFonts.mono,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        return Container(
          key: ValueKey('operational-account-${account.id ?? 'none'}'),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: compact
                ? [
                    Expanded(flex: 5, child: identity),
                    Expanded(flex: 3, child: amount(account.operationalFlow)),
                    Expanded(flex: 3, child: amount(account.ledgerNet)),
                  ]
                : [
                    Expanded(flex: 5, child: identity),
                    Expanded(flex: 2, child: amount(account.entries)),
                    Expanded(flex: 2, child: amount(account.exits)),
                    Expanded(flex: 2, child: amount(account.operationalFlow)),
                    Expanded(flex: 2, child: amount(account.ledgerNet)),
                  ],
          ),
        );
      },
    );
  }
}

class _IssuesPanel extends StatelessWidget {
  const _IssuesPanel({
    required this.result,
    required this.currency,
    required this.scrollController,
  });

  final OperationalResultsModel result;
  final OperationalResultsCurrencyModel currency;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final items = <(String, String, bool)>[
      (
        'Clasificación pendiente',
        '${currency.quality.pendingClassification} movimiento(s)',
        currency.quality.pendingClassification > 0,
      ),
      (
        'Movimientos sin cuenta',
        '${currency.quality.movementsWithoutAccount} movimiento(s)',
        currency.quality.movementsWithoutAccount > 0,
      ),
      (
        'Revisión de origen',
        '${currency.quality.sourceReviews} movimiento(s)',
        currency.quality.sourceReviews > 0,
      ),
      (
        'Jornadas por cerrar',
        '${currency.quality.openBusinessDays} jornada(s)',
        currency.quality.openBusinessDays > 0,
      ),
      (
        'Reserva inmediata',
        currency.obligations.available
            ? '${currency.currencyCode} ${_money(currency.obligations.immediateReserve ?? '0.00')} · '
                  '${currency.obligations.pendingTrainerCount} entrenador(es) y '
                  '${currency.obligations.pendingRefundCount} devolución(es)'
            : currency.obligations.reason,
        !currency.obligations.available,
      ),
      (
        'Pagos a entrenadores vencidos',
        '${currency.obligations.overdueInstallmentCount} concepto(s) · '
            '${currency.currencyCode} ${_money(currency.obligations.trainerPayableNow ?? '0.00')}',
        currency.obligations.overdueInstallmentCount > 0,
      ),
      for (final limitation in result.limitations)
        ('Límite del informe', limitation, false),
    ];
    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 11, 14, 10),
            child: PulsoLabel('INCIDENCIAS Y LÍMITES DEL INFORME'),
          ),
          Divider(height: 1, color: tokens.line),
          Expanded(
            child: Scrollbar(
              key: const Key('operational-issues-scrollbar'),
              controller: scrollController,
              thumbVisibility: true,
              child: ListView.separated(
                controller: scrollController,
                primary: false,
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: tokens.line),
                itemBuilder: (_, index) {
                  final item = items[index];
                  return ListTile(
                    leading: Icon(
                      item.$3
                          ? Icons.warning_amber_rounded
                          : Icons.info_outline,
                      size: 19,
                      color: item.$3 ? tokens.warning : tokens.muted,
                    ),
                    title: Text(item.$1),
                    subtitle: Text(item.$2),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _OperationalExportAction { pdf, csv, print }

class _OperationalExportRequest {
  const _OperationalExportRequest({
    required this.action,
    required this.allCurrencies,
    required this.selectedCurrencyId,
  });

  final _OperationalExportAction action;
  final bool allCurrencies;
  final String selectedCurrencyId;
}

class _OperationalExportDialog extends StatefulWidget {
  const _OperationalExportDialog({
    required this.result,
    required this.selectedCurrencyId,
  });

  final OperationalResultsModel result;
  final String selectedCurrencyId;

  @override
  State<_OperationalExportDialog> createState() =>
      _OperationalExportDialogState();
}

class _OperationalExportDialogState extends State<_OperationalExportDialog> {
  final _scroll = ScrollController();
  late String _selectedCurrencyId;
  bool _allCurrencies = false;

  @override
  void initState() {
    super.initState();
    final requestedExists = widget.result.currencies.any(
      (item) => item.currencyId == widget.selectedCurrencyId,
    );
    _selectedCurrencyId = requestedExists
        ? widget.selectedCurrencyId
        : widget.result.currencies.first.currencyId;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final size = MediaQuery.sizeOf(context);
    final close = widget.result.monthlyClose;
    final selected = widget.result.currencies
        .where((item) => item.currencyId == _selectedCurrencyId)
        .firstOrNull;
    return Dialog(
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tokens.line),
        borderRadius: BorderRadius.circular(2),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: math.min(660, size.height - 40),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 15, 10, 13),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PulsoLabel('DOCUMENTO DE DIRECCIÓN'),
                        const SizedBox(height: 4),
                        Text(
                          'Exportar Resultado de caja',
                          style: TextStyle(
                            color: tokens.chalk,
                            fontFamily: PulsoFonts.display,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PulsoIconButton(
                    icon: Icons.close,
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: tokens.line),
            Expanded(
              child: Scrollbar(
                key: const Key('operational-export-dialog-scrollbar'),
                controller: _scroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  key: const PageStorageKey('operational-export-dialog-scroll'),
                  controller: _scroll,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color:
                              (widget.result.certified
                                      ? tokens.success
                                      : tokens.warning)
                                  .withValues(alpha: 0.08),
                          border: Border.all(
                            color:
                                (widget.result.certified
                                        ? tokens.success
                                        : tokens.warning)
                                    .withValues(alpha: 0.55),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              widget.result.certified
                                  ? Icons.verified_outlined
                                  : Icons.edit_note_outlined,
                              color: widget.result.certified
                                  ? tokens.success
                                  : tokens.warning,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.result.certified
                                        ? 'CORTE CERTIFICADO'
                                        : 'BORRADOR OPERATIVO',
                                    style: TextStyle(
                                      color: widget.result.certified
                                          ? tokens.success
                                          : tokens.warning,
                                      fontFamily: PulsoFonts.mono,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.result.certificationNote,
                                    style: TextStyle(
                                      color: tokens.chalkDim,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const PulsoLabel('ALCANCE DEL INFORME'),
                      const SizedBox(height: 7),
                      RadioGroup<bool>(
                        groupValue: _allCurrencies,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _allCurrencies = value);
                          }
                        },
                        child: Column(
                          children: [
                            RadioListTile<bool>(
                              value: false,
                              title: const Text('Una moneda específica'),
                              subtitle: Text(
                                'Ahora: ${selected?.currencyCode ?? 'seleccione una moneda'}. '
                                'Puede cambiarla antes de exportar.',
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: DropdownMenu<String>(
                                key: const Key(
                                  'operational-export-currency-selector',
                                ),
                                initialSelection: _selectedCurrencyId,
                                enabled: !_allCurrencies,
                                enableFilter: true,
                                enableSearch: true,
                                requestFocusOnTap: true,
                                expandedInsets: EdgeInsets.zero,
                                menuHeight: math.min(
                                  320.0,
                                  math.max(180.0, size.height * 0.38),
                                ),
                                label: const Text('Moneda a exportar'),
                                leadingIcon: const Icon(
                                  Icons.currency_exchange,
                                ),
                                dropdownMenuEntries: widget.result.currencies
                                    .map(
                                      (currency) => DropdownMenuEntry<String>(
                                        value: currency.currencyId,
                                        label:
                                            '${currency.currencyCode} · '
                                            '${currency.accounts.length} cuenta(s)',
                                      ),
                                    )
                                    .toList(growable: false),
                                onSelected: (value) {
                                  if (value != null) {
                                    setState(() => _selectedCurrencyId = value);
                                  }
                                },
                              ),
                            ),
                            RadioListTile<bool>(
                              value: true,
                              enabled: widget.result.currencies.length > 1,
                              title: const Text('Todas las monedas'),
                              subtitle: const Text(
                                'Cada moneda comienza en su propia sección; no se crea un total general.',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const PulsoLabel('TRAZABILIDAD INCLUIDA'),
                      const SizedBox(height: 7),
                      Text(
                        'Resumen por moneda, conceptos, cuentas, obligaciones por entrenador, devoluciones pendientes, fecha de corte y estado de revisión.',
                        style: TextStyle(color: tokens.chalkDim, height: 1.45),
                      ),
                      if (close != null) ...[
                        const SizedBox(height: 14),
                        const PulsoLabel('EVIDENCIA DEL CIERRE'),
                        const SizedBox(height: 7),
                        Text(
                          'ID ${close.id} · snapshot v${close.snapshotVersion} · '
                          '${close.signerName ?? 'firmante no disponible'}',
                          style: TextStyle(
                            color: tokens.chalkDim,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 5),
                        SelectableText(
                          close.sha256,
                          style: TextStyle(
                            color: tokens.muted,
                            fontFamily: PulsoFonts.mono,
                            fontSize: 8,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        'El PDF está pensado para lectura e impresión. El CSV conserva filas MONEDA, CONCEPTO, CUENTA, ENTRENADOR y REEMBOLSO para revisión externa.',
                        style: TextStyle(color: tokens.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: tokens.line),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCELAR'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('operational-export-csv'),
                    onPressed: () => _finish(_OperationalExportAction.csv),
                    icon: const Icon(Icons.table_view_outlined, size: 17),
                    label: const Text('GUARDAR CSV'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('operational-export-print'),
                    onPressed: () => _finish(_OperationalExportAction.print),
                    icon: const Icon(Icons.print_outlined, size: 17),
                    label: const Text('IMPRIMIR'),
                  ),
                  FilledButton.icon(
                    key: const Key('operational-export-pdf'),
                    onPressed: () => _finish(_OperationalExportAction.pdf),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                    label: const Text('GUARDAR PDF'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _finish(_OperationalExportAction action) {
    Navigator.pop(
      context,
      _OperationalExportRequest(
        action: action,
        allCurrencies: _allCurrencies,
        selectedCurrencyId: _selectedCurrencyId,
      ),
    );
  }
}

double _numeric(String value) => double.tryParse(value) ?? 0;

String _money(String value) => _resultMoney.format(_numeric(value));

String _displayCalendarDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return value;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

String _displayInstantDate(DateTime? value) {
  if (value == null) return '—';
  final utc = value.toUtc();
  return '${utc.day.toString().padLeft(2, '0')}/'
      '${utc.month.toString().padLeft(2, '0')}/${utc.year}';
}

String _monthLabel(String value) {
  const months = [
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
  final parts = value.split('-');
  final month = parts.length == 2 ? int.tryParse(parts[1]) : null;
  if (month == null || month < 1 || month > 12) return value;
  return '${months[month - 1]} ${parts[0]}';
}
