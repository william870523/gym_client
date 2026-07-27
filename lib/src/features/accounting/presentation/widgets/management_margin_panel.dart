import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/management_margin_models.dart';
import '../state/accounting_providers.dart';
import 'accrual_operating_result_panel.dart';
import 'management_margin_annual_panel.dart';

enum _MarginSection { plans, trainers, clients }

class ManagementMarginPanel extends ConsumerStatefulWidget {
  const ManagementMarginPanel({
    super.key,
    this.initialMonth,
    this.onMonthChanged,
    required this.onBack,
  });

  final String? initialMonth;
  final ValueChanged<String>? onMonthChanged;
  final VoidCallback onBack;

  @override
  ConsumerState<ManagementMarginPanel> createState() =>
      _ManagementMarginPanelState();
}

class _ManagementMarginPanelState extends ConsumerState<ManagementMarginPanel> {
  final _rowsScroll = ScrollController();
  final _search = TextEditingController();
  late String? _month = widget.initialMonth;
  String? _currencyId;
  String _query = '';
  _MarginSection _section = _MarginSection.plans;
  bool _annualView = false;
  bool _accrualResultView = false;

  @override
  void dispose() {
    _rowsScroll.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_annualView) {
      return ManagementMarginAnnualPanel(
        onBack: () => setState(() => _annualView = false),
      );
    }
    if (_accrualResultView) {
      return AccrualOperatingResultPanel(
        initialMonth: _month,
        onBack: () => setState(() => _accrualResultView = false),
      );
    }
    return ref
        .watch(managementMarginProvider(_month))
        .when(
          loading: () => const PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.loading,
              message: 'Restando el costo directo del servicio ya prestado…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message:
                  'No se pudo calcular el margen gerencial.\n${_marginErrorText(error)}',
              onRetry: _refresh,
            ),
          ),
          data: _buildResult,
        );
  }

  Widget _buildResult(ManagementMarginModel result) {
    if (result.currencies.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MarginToolbar(
            result: result,
            onBack: widget.onBack,
            onPrevious: () => _moveMonth(result.month, -1),
            onNext: () => _moveMonth(result.month, 1),
            onCurrent: () => _setMonth(null),
            onAnnual: () => setState(() => _annualView = true),
            onAccrualResult: () => setState(() => _accrualResultView = true),
            onRefresh: _refresh,
          ),
          const SizedBox(height: 10),
          const Expanded(
            child: PulsoPanel(
              child: PulsoStateView(
                kind: PulsoStateKind.empty,
                message:
                    'No existe servicio prestado ni costo directo para este periodo.',
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
    final rows = _sectionRows(selected);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wideRows = constraints.maxWidth >= 1080;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MarginToolbar(
              result: result,
              onBack: widget.onBack,
              onPrevious: () => _moveMonth(result.month, -1),
              onNext: () => _moveMonth(result.month, 1),
              onCurrent: () => _setMonth(null),
              onAnnual: () => setState(() => _annualView = true),
              onAccrualResult: () => setState(() => _accrualResultView = true),
              onRefresh: _refresh,
            ),
            const SizedBox(height: 8),
            _MarginCurrencySelector(
              currencies: result.currencies,
              selectedId: selected.currencyId,
              onSelected: (value) {
                if (value == null) return;
                setState(() => _currencyId = value);
                _resetScroll();
              },
            ),
            const SizedBox(height: 8),
            _MarginMetrics(currency: selected),
            const SizedBox(height: 8),
            _MarginMeaningNotice(result: result, currency: selected),
            const SizedBox(height: 8),
            _MarginSectionTabs(
              section: _section,
              currency: selected,
              onSelected: (value) {
                setState(() => _section = value);
                _resetScroll();
              },
            ),
            const SizedBox(height: 8),
            _MarginSearch(
              controller: _search,
              valueCount: rows.length,
              totalCount: _sectionTotal(selected),
              hint: switch (_section) {
                _MarginSection.plans => 'Plan…',
                _MarginSection.trainers => 'Entrenador…',
                _MarginSection.clients => 'Socio o CI…',
              },
              onChanged: (value) {
                setState(() => _query = value);
                _resetScroll();
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: PulsoPanel(
                padding: EdgeInsets.zero,
                child: rows.isEmpty
                    ? const PulsoStateView(
                        kind: PulsoStateKind.empty,
                        message: 'Ninguna fila coincide con la búsqueda.',
                      )
                    : Scrollbar(
                        key: const Key('management-margin-scrollbar'),
                        controller: _rowsScroll,
                        thumbVisibility: true,
                        child: ListView.separated(
                          key: const Key('management-margin-list'),
                          controller: _rowsScroll,
                          padding: const EdgeInsets.all(8),
                          itemCount: rows.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, index) => _MarginRow(
                            row: rows[index],
                            currencyCode: selected.currencyCode,
                            expanded: wideRows,
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

  List<_MarginRowData> _sectionRows(ManagementMarginCurrencyModel currency) {
    final query = _query.trim().toLowerCase();
    bool matches(List<String> values) =>
        query.isEmpty ||
        values.any((value) => value.toLowerCase().contains(query));
    switch (_section) {
      case _MarginSection.plans:
        return currency.plans
            .where((row) => matches([row.planName]))
            .map(_MarginRowData.plan)
            .toList(growable: false);
      case _MarginSection.trainers:
        return currency.trainers
            .where((row) => matches([row.trainerName]))
            .map((row) => _MarginRowData.trainer(row, currency.currencyCode))
            .toList(growable: false);
      case _MarginSection.clients:
        return currency.clients
            .where((row) => matches([row.clientName, row.clientId]))
            .map(_MarginRowData.client)
            .toList(growable: false);
    }
  }

  int _sectionTotal(ManagementMarginCurrencyModel currency) =>
      switch (_section) {
        _MarginSection.plans => currency.plans.length,
        _MarginSection.trainers => currency.trainers.length,
        _MarginSection.clients => currency.clients.length,
      };

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
      _query = '';
      _search.clear();
    });
    widget.onMonthChanged?.call(value ?? '');
    _resetScroll();
  }

  void _refresh() {
    ref.invalidate(managementMarginProvider(_month));
    ref.invalidate(membershipRevenueProvider(_month));
    ref.invalidate(trainerServiceCostProvider(_month));
  }

  void _resetScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_rowsScroll.hasClients) _rowsScroll.jumpTo(0);
    });
  }
}

class _MarginToolbar extends StatelessWidget {
  const _MarginToolbar({
    required this.result,
    required this.onBack,
    required this.onPrevious,
    required this.onNext,
    required this.onCurrent,
    required this.onAnnual,
    required this.onAccrualResult,
    required this.onRefresh,
  });

  final ManagementMarginModel result;
  final VoidCallback onBack;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCurrent;
  final VoidCallback onAnnual;
  final VoidCallback onAccrualResult;
  final VoidCallback onRefresh;

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
                  key: const Key('management-margin-back-compact'),
                  icon: Icons.arrow_back,
                  tooltip: 'Volver a Resultado de caja',
                  onPressed: onBack,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 40),
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
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                PulsoIconButton(
                  key: const Key('management-margin-annual-action-compact'),
                  icon: Icons.insights_outlined,
                  tooltip: 'Ver año certificado',
                  onPressed: onAnnual,
                ),
                PulsoIconButton(
                  key: const Key(
                    'management-margin-accrual-result-action-compact',
                  ),
                  icon: Icons.receipt_long_outlined,
                  tooltip: 'Restar el gasto del mes (resultado devengado)',
                  onPressed: onAccrualResult,
                ),
                PulsoIconButton(
                  icon: Icons.refresh,
                  tooltip: 'Actualizar margen gerencial',
                  onPressed: onRefresh,
                ),
              ],
            );
          }
          return Row(
            children: [
              TextButton.icon(
                key: const Key('management-margin-back'),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('VOLVER A CAJA'),
              ),
              const Spacer(),
              PulsoIconButton(
                icon: Icons.chevron_left,
                tooltip: 'Mes anterior',
                onPressed: onPrevious,
              ),
              Container(
                constraints: BoxConstraints(minWidth: 142, minHeight: 40),
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
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PulsoIconButton(
                icon: Icons.chevron_right,
                tooltip: 'Mes siguiente',
                onPressed: onNext,
              ),
              const Spacer(),
              TextButton(onPressed: onCurrent, child: const Text('MES ACTUAL')),
              TextButton.icon(
                key: const Key('management-margin-annual-action'),
                onPressed: onAnnual,
                icon: const Icon(Icons.insights_outlined, size: 16),
                label: const Text('VER AÑO'),
              ),
              TextButton.icon(
                key: const Key('management-margin-accrual-result-action'),
                onPressed: onAccrualResult,
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: const Text('RESTAR GASTOS'),
              ),
              PulsoIconButton(
                icon: Icons.refresh,
                tooltip: 'Actualizar margen gerencial',
                onPressed: onRefresh,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MarginCurrencySelector extends StatelessWidget {
  const _MarginCurrencySelector({
    required this.currencies,
    required this.selectedId,
    required this.onSelected,
  });

  final List<ManagementMarginCurrencyModel> currencies;
  final String selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          final selector = SizedBox(
            width: compact ? constraints.maxWidth : 360,
            child: DropdownMenu<String>(
              key: ValueKey('management-margin-currency-$selectedId'),
              initialSelection: selectedId,
              enableFilter: true,
              enableSearch: true,
              requestFocusOnTap: true,
              menuHeight: 300,
              expandedInsets: EdgeInsets.zero,
              leadingIcon: Icon(Icons.currency_exchange, color: tokens.muted),
              onSelected: onSelected,
              dropdownMenuEntries: currencies
                  .map(
                    (item) => DropdownMenuEntry(
                      value: item.currencyId,
                      label:
                          '${item.currencyCode} · ${item.plans.length} plan(es)',
                    ),
                  )
                  .toList(growable: false),
            ),
          );
          if (compact) return selector;
          return Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PulsoLabel('MONEDA DEL MARGEN'),
                    SizedBox(height: 3),
                    Text(
                      'No se suman monedas ni se asume una moneda principal.',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              selector,
            ],
          );
        },
      ),
    );
  }
}

class _MarginMetrics extends StatelessWidget {
  const _MarginMetrics({required this.currency});

  final ManagementMarginCurrencyModel currency;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('MARGEN DIRECTO MES', currency.marginInMonth, 'Ingreso menos comisión'),
      ('INGRESO GANADO MES', currency.revenueInMonth, 'Servicio ya prestado'),
      (
        'COSTO DIRECTO MES',
        currency.directCostInMonth,
        'Comisión del servicio prestado',
      ),
      (
        'FIJO NO DISTRIBUIDO',
        currency.fixedInMonth,
        'Solo resta en el total por moneda',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return SizedBox(
            height: 84,
            child: ListView.separated(
              key: const Key('management-margin-metrics-list'),
              scrollDirection: Axis.horizontal,
              itemCount: values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => SizedBox(
                width: 220,
                child: _MarginMetricCard(
                  label: values[index].$1,
                  value: values[index].$2,
                  note: values[index].$3,
                  currency: currency.currencyCode,
                  emphasis: index == 0,
                ),
              ),
            ),
          );
        }
        return SizedBox(
          height: 82,
          child: Row(
            children: [
              for (var index = 0; index < values.length; index++) ...[
                Expanded(
                  child: _MarginMetricCard(
                    label: values[index].$1,
                    value: values[index].$2,
                    note: values[index].$3,
                    currency: currency.currencyCode,
                    emphasis: index == 0,
                  ),
                ),
                if (index != values.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MarginMetricCard extends StatelessWidget {
  const _MarginMetricCard({
    required this.label,
    required this.value,
    required this.note,
    required this.currency,
    required this.emphasis,
  });

  final String label;
  final String value;
  final String note;
  final String currency;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final negative = value.trim().startsWith('-');
    final color = emphasis
        ? (negative ? tokens.danger : tokens.accent)
        : tokens.chalk;
    return PulsoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_exactMoney(value)} $currency',
              style: TextStyle(
                color: color,
                fontFamily: PulsoFonts.display,
                fontSize: 25,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.chalkDim, fontSize: 10),
          ),
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.muted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _MarginMeaningNotice extends StatelessWidget {
  const _MarginMeaningNotice({required this.result, required this.currency});

  final ManagementMarginModel result;
  final ManagementMarginCurrencyModel currency;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final attribution = currency.attribution;
    final incidents = <String>[
      if (attribution.sharedMemberships > 0)
        '${attribution.sharedMemberships} membresía(s) con más de un entrenador sin repartir',
      if (attribution.withoutTrainerMemberships > 0)
        '${attribution.withoutTrainerMemberships} membresía(s) sin entrenador',
      if (attribution.orphanCostConcepts > 0)
        '${attribution.orphanCostConcepts} costo(s) sin ingreso verificable',
    ];
    final review = !result.coverage.complete && !result.certified;
    final pct = currency.marginPctToDate;
    final status = result.certified
        ? 'CERTIFICADO'
        : result.monthlyClose != null
        ? 'CIERRE PRE-R4.4'
        : 'PROVISIONAL';
    final certification = result.certificationNote.trim();
    return PulsoPanel(
      color: result.certified
          ? tokens.successSoft
          : review
          ? tokens.warningSoft
          : tokens.raised,
      borderColor: result.certified
          ? tokens.success
          : review
          ? tokens.warning
          : tokens.line,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: const Key('management-margin-certification-state'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: result.certified ? tokens.success : tokens.raised,
            child: Text(
              status,
              style: TextStyle(
                color: result.certified ? tokens.surface : tokens.chalkDim,
                fontFamily: PulsoFonts.mono,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${certification.isEmpty ? result.note : certification} '
              'Margen acumulado ${_exactMoney(currency.marginToDate)} '
              '${currency.currencyCode}${pct == null ? '' : ' ($pct% del ingreso)'}; '
              'después del fijo ${_exactMoney(currency.marginAfterFixedToDate)} ${currency.currencyCode}. '
              '${incidents.isEmpty ? 'La atribución no presenta incidencias.' : '${incidents.join('; ')}.'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.chalk,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarginSectionTabs extends StatelessWidget {
  const _MarginSectionTabs({
    required this.section,
    required this.currency,
    required this.onSelected,
  });

  final _MarginSection section;
  final ManagementMarginCurrencyModel currency;
  final ValueChanged<_MarginSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final entries = [
      (_MarginSection.plans, 'POR PLAN', currency.plans.length, 'plan'),
      (
        _MarginSection.trainers,
        'POR ENTRENADOR',
        currency.trainers.length,
        'trainer',
      ),
      (_MarginSection.clients, 'POR SOCIO', currency.clients.length, 'client'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.line),
      ),
      child: Row(
        children: [
          for (final entry in entries)
            Expanded(
              child: _MarginSectionTab(
                key: Key('management-margin-section-${entry.$4}'),
                label: '${entry.$2} · ${entry.$3}',
                active: section == entry.$1,
                onTap: () => onSelected(entry.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _MarginSectionTab extends StatelessWidget {
  const _MarginSectionTab({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? tokens.accentSoft : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: active ? tokens.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? tokens.accent : tokens.muted,
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _MarginSearch extends StatelessWidget {
  const _MarginSearch({
    required this.controller,
    required this.valueCount,
    required this.totalCount,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final int valueCount;
  final int totalCount;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PulsoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('management-margin-search'),
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: hint,
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

class _MarginRowData {
  const _MarginRowData({
    required this.rowKey,
    required this.title,
    required this.subject,
    required this.detail,
    required this.revenueInMonth,
    required this.costInMonth,
    required this.marginInMonth,
    required this.marginToDate,
    required this.marginPctToDate,
    required this.requiresReview,
  });

  factory _MarginRowData.plan(ManagementMarginPlanModel row) {
    return _MarginRowData(
      rowKey: 'plan-${row.planId}',
      title: row.planName,
      subject: '${row.memberships} membresía(s) · ${row.clients} socio(s)',
      detail: row.requiresReview
          ? 'Alguna membresía o comisión de este plan requiere revisión.'
          : 'Ingreso y comisión del plan coinciden con R4.1 y R4.2.',
      revenueInMonth: row.revenueInMonth,
      costInMonth: row.costInMonth,
      marginInMonth: row.marginInMonth,
      marginToDate: row.marginToDate,
      marginPctToDate: row.marginPctToDate,
      requiresReview: row.requiresReview,
    );
  }

  factory _MarginRowData.trainer(
    ManagementMarginTrainerModel row,
    String currencyCode,
  ) {
    final fixed = row.fixedToDate != '0.00'
        ? ' · fijo ${_exactMoney(row.fixedToDate)} $currencyCode aparte'
        : '';
    return _MarginRowData(
      rowKey: 'trainer-${row.trainerId}',
      title: row.trainerName,
      subject:
          '${row.linkedMemberships} membresía(s) · ${row.clients} socio(s)$fixed',
      detail: row.fullyAttributed
          ? 'Margen sobre membresías atribuidas en exclusiva al entrenador.'
          : 'Atribución parcial: hay membresías compartidas o costo sin ingreso verificable fuera de este margen.',
      revenueInMonth: row.revenueInMonth,
      costInMonth: row.costInMonth,
      marginInMonth: row.marginInMonth,
      marginToDate: row.marginToDate,
      marginPctToDate: row.marginPctToDate,
      requiresReview: row.requiresReview || !row.fullyAttributed,
    );
  }

  factory _MarginRowData.client(ManagementMarginClientModel row) {
    return _MarginRowData(
      rowKey: 'client-${row.clientId}',
      title: row.clientName,
      subject:
          'CI ${row.clientId} · ${row.memberships} membresía(s) · ${row.plans} plan(es)',
      detail: row.requiresReview
          ? 'Alguna membresía o comisión de este socio requiere revisión.'
          : 'Ingreso y comisión del socio coinciden con R4.1 y R4.2.',
      revenueInMonth: row.revenueInMonth,
      costInMonth: row.costInMonth,
      marginInMonth: row.marginInMonth,
      marginToDate: row.marginToDate,
      marginPctToDate: row.marginPctToDate,
      requiresReview: row.requiresReview,
    );
  }

  final String rowKey;
  final String title;
  final String subject;
  final String detail;
  final String revenueInMonth;
  final String costInMonth;
  final String marginInMonth;
  final String marginToDate;
  final String? marginPctToDate;
  final bool requiresReview;
}

class _MarginRow extends StatelessWidget {
  const _MarginRow({
    required this.row,
    required this.currencyCode,
    required this.expanded,
  });

  final _MarginRowData row;
  final String currencyCode;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final negative = row.marginToDate.trim().startsWith('-');
    final color = row.requiresReview
        ? tokens.warning
        : negative
        ? tokens.danger
        : tokens.accent;
    return Container(
      key: ValueKey('management-margin-row-${row.rowKey}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: expanded ? _wide(tokens) : _compact(tokens),
    );
  }

  Widget _wide(PulsoTokens tokens) {
    return Row(
      children: [
        Expanded(flex: 6, child: _identity(tokens)),
        _amount(tokens, 'INGRESO MES', row.revenueInMonth),
        _amount(tokens, 'COSTO MES', row.costInMonth),
        _amount(tokens, 'MARGEN MES', row.marginInMonth),
        SizedBox(
          width: 132,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const PulsoLabel('MARGEN ACUM'),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '${_exactMoney(row.marginToDate)} $currencyCode',
                  style: TextStyle(
                    color: tokens.chalk,
                    fontFamily: PulsoFonts.mono,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (row.marginPctToDate != null)
                Text(
                  '${row.marginPctToDate}% DEL INGRESO',
                  style: TextStyle(
                    color: tokens.muted,
                    fontFamily: PulsoFonts.mono,
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _compact(PulsoTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _identity(tokens),
        const SizedBox(height: 9),
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            _compactAmount(tokens, 'MARGEN MES', row.marginInMonth),
            _compactAmount(tokens, 'MARGEN ACUM', row.marginToDate),
            if (row.marginPctToDate != null)
              _compactAmount(tokens, '% INGRESO', '${row.marginPctToDate}%'),
          ],
        ),
      ],
    );
  }

  Widget _identity(PulsoTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: tokens.chalk, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          row.subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: tokens.chalkDim, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          row.detail,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: tokens.muted, fontSize: 10),
        ),
      ],
    );
  }

  Widget _amount(PulsoTokens tokens, String label, String value) {
    return SizedBox(
      width: 120,
      child: Column(
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
      ),
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
            label == '% INGRESO' ? value : _exactMoney(value),
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

String _marginErrorText(Object error) {
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
  return 'Revise las filas señaladas o vuelva a intentarlo.';
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
