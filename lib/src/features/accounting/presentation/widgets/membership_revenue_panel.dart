import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/membership_revenue_models.dart';
import '../../data/models/operational_results_models.dart';
import '../state/accounting_providers.dart';

class MembershipRevenuePanel extends ConsumerStatefulWidget {
  const MembershipRevenuePanel({
    super.key,
    required this.onBack,
    this.initialMonth,
    this.onMonthChanged,
  });

  final VoidCallback onBack;
  final String? initialMonth;
  final ValueChanged<String?>? onMonthChanged;

  @override
  ConsumerState<MembershipRevenuePanel> createState() =>
      _MembershipRevenuePanelState();
}

class _MembershipRevenuePanelState
    extends ConsumerState<MembershipRevenuePanel> {
  final _rowsScroll = ScrollController();
  final _search = TextEditingController();
  String? _month;
  String? _currencyId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
  }

  @override
  void dispose() {
    _rowsScroll.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final revenue = ref.watch(membershipRevenueProvider(_month));
    final cash = ref.watch(operationalResultsProvider(_month)).asData?.value;
    return revenue.when(
      loading: () => const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.loading,
          message: 'Separando el cobro del servicio ya prestado…',
        ),
      ),
      error: (error, _) => PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.error,
          message:
              'No se pudo calcular el ingreso ya ganado.\n'
              '${_membershipRevenueErrorText(error)}',
          onRetry: _refresh,
        ),
      ),
      data: (result) => _buildResult(result, cash),
    );
  }

  Widget _buildResult(
    MembershipRevenueModel result,
    OperationalResultsModel? cash,
  ) {
    final selected =
        result.currencies
            .where((item) => item.currencyId == _currencyId)
            .firstOrNull ??
        result.currencies.firstOrNull;
    final cashCurrency = selected == null
        ? null
        : cash?.currencies
              .where((item) => item.currencyId == selected.currencyId)
              .firstOrNull;
    final rows = selected == null
        ? const <MembershipRevenueMembershipModel>[]
        : selected.memberships.where(_matchesQuery).toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final expandedRows = constraints.maxWidth >= 1100;
        final gap = constraints.maxHeight < 650 ? 8.0 : 10.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RevenueToolbar(
              result: result,
              onBack: widget.onBack,
              onPrevious: () => _moveMonth(result.month, -1),
              onNext: () => _moveMonth(result.month, 1),
              onCurrent: _goToCurrentMonth,
              onRefresh: _refresh,
            ),
            SizedBox(height: gap),
            if (selected != null)
              _RevenueCurrencySelector(
                currencies: result.currencies,
                selectedId: selected.currencyId,
                onSelected: _selectCurrency,
              ),
            if (selected != null) SizedBox(height: gap),
            if (selected != null)
              _RevenueMetricStrip(
                metrics: [
                  _RevenueMetricData(
                    value: cashCurrency == null
                        ? '—'
                        : _exactMoney(cashCurrency.cash.grossCollections),
                    label: 'Dinero cobrado',
                    note: cashCurrency == null
                        ? 'Caja no disponible'
                        : '${selected.currencyCode} · Resultado de caja',
                    emphasis: true,
                  ),
                  _RevenueMetricData(
                    value: _exactMoney(selected.earnedInMonth),
                    label: 'Servicio ya prestado',
                    note: '${selected.currencyCode} · este mes',
                  ),
                  _RevenueMetricData(
                    value: _exactMoney(selected.deferredService),
                    label: 'Pendiente de prestar',
                    note: '${selected.currencyCode} · al corte',
                  ),
                  _RevenueMetricData(
                    value: _exactMoney(selected.funding.creditApplied),
                    label: 'Crédito utilizado',
                    note: '${selected.currencyCode} · no es efectivo nuevo',
                  ),
                ],
              ),
            if (selected != null) SizedBox(height: gap),
            _RevenueMeaningNotice(result: result),
            SizedBox(height: gap),
            _RevenueSearch(
              controller: _search,
              valueCount: rows.length,
              totalCount: selected?.memberships.length ?? 0,
              onChanged: (value) {
                setState(() => _query = value.trim().toLowerCase());
                _resetScroll();
              },
            ),
            SizedBox(height: gap),
            Expanded(
              child: PulsoPanel(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
                child: rows.isEmpty
                    ? const PulsoStateView(
                        kind: PulsoStateKind.empty,
                        message:
                            'No hay membresías con ese filtro en esta moneda.',
                      )
                    : Scrollbar(
                        key: const Key(
                          'membership-revenue-memberships-scrollbar',
                        ),
                        controller: _rowsScroll,
                        thumbVisibility: true,
                        child: ListView.separated(
                          key: const Key('membership-revenue-memberships-list'),
                          controller: _rowsScroll,
                          padding: const EdgeInsets.only(right: 8, bottom: 4),
                          itemCount: rows.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 7),
                          itemBuilder: (context, index) => _RevenueRow(
                            membership: rows[index],
                            currencyCode: selected!.currencyCode,
                            expanded: expandedRows,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _matchesQuery(MembershipRevenueMembershipModel membership) {
    if (_query.isEmpty) return true;
    return membership.clientName.toLowerCase().contains(_query) ||
        membership.clientId.toLowerCase().contains(_query) ||
        membership.planName.toLowerCase().contains(_query) ||
        membership.coverageState.toLowerCase().contains(_query);
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
      _query = '';
      _search.clear();
    });
    widget.onMonthChanged?.call(_month);
    _resetScroll();
  }

  void _selectCurrency(String? value) {
    if (value == null || value == _currencyId) return;
    setState(() {
      _currencyId = value;
      _query = '';
      _search.clear();
    });
    _resetScroll();
  }

  void _goToCurrentMonth() {
    setState(() {
      _month = null;
      _currencyId = null;
    });
    widget.onMonthChanged?.call(null);
  }

  void _refresh() {
    ref.invalidate(membershipRevenueProvider(_month));
    ref.invalidate(operationalResultsProvider(_month));
  }

  void _resetScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_rowsScroll.hasClients) _rowsScroll.jumpTo(0);
    });
  }
}

String _membershipRevenueErrorText(Object error) {
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
  return 'Revise las membresías señaladas o vuelva a intentarlo.';
}

class _RevenueToolbar extends StatelessWidget {
  const _RevenueToolbar({
    required this.result,
    required this.onBack,
    required this.onPrevious,
    required this.onNext,
    required this.onCurrent,
    required this.onRefresh,
  });

  final MembershipRevenueModel result;
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
          return Row(
            children: [
              if (compact)
                PulsoIconButton(
                  key: const Key('membership-revenue-back-compact'),
                  icon: Icons.arrow_back,
                  tooltip: 'Volver a Resultado de caja',
                  onPressed: onBack,
                )
              else
                TextButton.icon(
                  key: const Key('membership-revenue-back'),
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('VOLVER A CAJA'),
                ),
              if (!compact) const Spacer(),
              PulsoIconButton(
                icon: Icons.chevron_left,
                tooltip: 'Mes anterior',
                onPressed: onPrevious,
              ),
              Container(
                constraints: BoxConstraints(
                  minWidth: compact ? 98 : 142,
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
                    fontSize: compact ? 9 : 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PulsoIconButton(
                icon: Icons.chevron_right,
                tooltip: 'Mes siguiente',
                onPressed: onNext,
              ),
              if (!compact) ...[
                const Spacer(),
                _RevenuePeriodBadge(state: result.periodState),
                TextButton(
                  onPressed: onCurrent,
                  child: const Text('MES ACTUAL'),
                ),
              ],
              PulsoIconButton(
                icon: Icons.refresh,
                tooltip: 'Actualizar ingreso ya ganado',
                onPressed: onRefresh,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RevenuePeriodBadge extends StatelessWidget {
  const _RevenuePeriodBadge({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final future = state == 'FUTURO';
    final historical = state == 'HISTORICO_RECALCULADO';
    final color = future
        ? tokens.muted
        : historical
        ? tokens.warning
        : tokens.accent;
    final label = future
        ? 'FUTURO'
        : historical
        ? 'HISTÓRICO RECALCULADO'
        : 'PROVISIONAL';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: PulsoFonts.mono,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RevenueCurrencySelector extends StatelessWidget {
  const _RevenueCurrencySelector({
    required this.currencies,
    required this.selectedId,
    required this.onSelected,
  });

  final List<MembershipRevenueCurrencyModel> currencies;
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
                    PulsoLabel('MONEDA DEL DEVENGO'),
                    SizedBox(height: 3),
                    Text('Cada moneda conserva su propio calendario.'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
            SizedBox(
              width: constraints.maxWidth < 520 ? constraints.maxWidth : 360,
              child: DropdownMenu<String>(
                key: ValueKey('membership-revenue-currency-$selectedId'),
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
                            '${item.currencyCode} · ${item.memberships.length} membresía(s)',
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

class _RevenueMeaningNotice extends StatelessWidget {
  const _RevenueMeaningNotice({required this.result});

  final MembershipRevenueModel result;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final review =
        result.coverage.requiresReview > 0 ||
        result.coverage.withoutFinancialEvidence > 0;
    return PulsoPanel(
      color: review ? tokens.warningSoft : tokens.successSoft,
      borderColor: review ? tokens.warning : tokens.success,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: Text(
        review
            ? '${result.note} ${result.coverage.requiresReview} membresía(s) requieren revisión y ${result.coverage.withoutFinancialEvidence} no tienen evidencia financiera verificable.'
            : '${result.note} El dinero cobrado y el servicio prestado se muestran por separado.',
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
}

class _RevenueSearch extends StatelessWidget {
  const _RevenueSearch({
    required this.controller,
    required this.valueCount,
    required this.totalCount,
    required this.onChanged,
  });

  final TextEditingController controller;
  final int valueCount;
  final int totalCount;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PulsoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('membership-revenue-search'),
              controller: controller,
              onChanged: onChanged,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: 'Socio, CI, plan o estado de revisión…',
              ),
            ),
          ),
          const SizedBox(width: 10),
          PulsoLabel('$valueCount DE $totalCount'),
        ],
      ),
    );
  }
}

class _RevenueRow extends StatelessWidget {
  const _RevenueRow({
    required this.membership,
    required this.currencyCode,
    required this.expanded,
  });

  final MembershipRevenueMembershipModel membership;
  final String currencyCode;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = membership.requiresReview ? tokens.warning : tokens.success;
    return Container(
      key: ValueKey('membership-revenue-row-${membership.membershipId}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: expanded ? _wide(tokens, color) : _compact(tokens, color),
    );
  }

  Widget _wide(PulsoTokens tokens, Color color) {
    return Row(
      children: [
        Expanded(flex: 5, child: _identity(tokens, color)),
        SizedBox(
          width: 125,
          child: _amount(tokens, 'FINANCIADO', membership.funded),
        ),
        SizedBox(
          width: 125,
          child: _amount(tokens, 'YA GANADO MES', membership.earnedInMonth),
        ),
        SizedBox(
          width: 125,
          child: _amount(tokens, 'YA GANADO TOTAL', membership.earnedToDate),
        ),
        SizedBox(
          width: 125,
          child: _amount(tokens, 'POR PRESTAR', membership.deferredService),
        ),
        SizedBox(
          width: 115,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const PulsoLabel('DÍAS SERVICIO'),
              const SizedBox(height: 4),
              Text(
                '${membership.serviceDaysToDate}/${membership.contractedDays}',
                style: TextStyle(
                  color: tokens.chalk,
                  fontFamily: PulsoFonts.mono,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _compact(PulsoTokens tokens, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _identity(tokens, color),
        const SizedBox(height: 9),
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            _compactAmount(tokens, 'YA GANADO MES', membership.earnedInMonth),
            _compactAmount(tokens, 'POR PRESTAR', membership.deferredService),
            SizedBox(
              width: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PulsoLabel('DÍAS SERVICIO'),
                  const SizedBox(height: 2),
                  Text(
                    '${membership.serviceDaysToDate}/${membership.contractedDays}',
                    style: TextStyle(
                      color: tokens.chalk,
                      fontFamily: PulsoFonts.mono,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _identity(PulsoTokens tokens, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                membership.clientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.chalk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              membership.coverageState.replaceAll('_', ' '),
              style: TextStyle(
                color: color,
                fontFamily: PulsoFonts.mono,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '${membership.planName} · CI ${membership.clientId}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: tokens.chalkDim, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          membership.explanation,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: tokens.muted, fontSize: 10),
        ),
      ],
    );
  }

  Widget _amount(PulsoTokens tokens, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        PulsoLabel(label),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            '${_exactMoney(value)} $currencyCode',
            style: TextStyle(
              color: tokens.chalk,
              fontFamily: PulsoFonts.mono,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _compactAmount(PulsoTokens tokens, String label, String value) {
    return SizedBox(
      width: 130,
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

class _RevenueMetricData {
  const _RevenueMetricData({
    required this.value,
    required this.label,
    required this.note,
    this.emphasis = false,
  });

  final String value;
  final String label;
  final String note;
  final bool emphasis;
}

class _RevenueMetricStrip extends StatelessWidget {
  const _RevenueMetricStrip({required this.metrics});

  final List<_RevenueMetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return SizedBox(
            height: 76,
            child: ListView.separated(
              key: const Key('membership-revenue-metrics-list'),
              scrollDirection: Axis.horizontal,
              itemCount: metrics.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => SizedBox(
                width: 216,
                child: _RevenueMetricCard(data: metrics[index]),
              ),
            ),
          );
        }
        return SizedBox(
          height: 82,
          child: Row(
            children: [
              for (var index = 0; index < metrics.length; index++) ...[
                Expanded(child: _RevenueMetricCard(data: metrics[index])),
                if (index != metrics.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RevenueMetricCard extends StatelessWidget {
  const _RevenueMetricCard({required this.data});

  final _RevenueMetricData data;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
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
                  style: TextStyle(
                    color: data.emphasis ? tokens.accent : tokens.chalk,
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
  final value = parts.length == 2 ? int.tryParse(parts[1]) : null;
  if (value == null || value < 1 || value > 12) return month;
  return '${names[value - 1]} ${parts[0]}';
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
