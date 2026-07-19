import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/trainer_service_cost_models.dart';
import '../state/accounting_providers.dart';

class TrainerServiceCostPanel extends ConsumerStatefulWidget {
  const TrainerServiceCostPanel({
    super.key,
    this.initialMonth,
    this.onMonthChanged,
    required this.onBack,
  });

  final String? initialMonth;
  final ValueChanged<String>? onMonthChanged;
  final VoidCallback onBack;

  @override
  ConsumerState<TrainerServiceCostPanel> createState() =>
      _TrainerServiceCostPanelState();
}

class _TrainerServiceCostPanelState
    extends ConsumerState<TrainerServiceCostPanel> {
  final _rowsScroll = ScrollController();
  final _search = TextEditingController();
  late String? _month = widget.initialMonth;
  String? _currencyId;
  String _query = '';

  @override
  void dispose() {
    _rowsScroll.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(trainerServiceCostProvider(_month))
        .when(
          loading: () => const PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.loading,
              message: 'Separando costo ganado, pagado y futuro…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message:
                  'No se pudo calcular el costo del servicio.\n${_costErrorText(error)}',
              onRetry: _refresh,
            ),
          ),
          data: _buildResult,
        );
  }

  Widget _buildResult(TrainerServiceCostModel result) {
    if (result.currencies.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CostToolbar(
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
                message: 'No existen costos de entrenador para este periodo.',
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
    final query = _query.trim().toLowerCase();
    final costs = selected.costs
        .where((row) {
          if (query.isEmpty) return true;
          return [
            row.trainerName,
            row.clientName ?? '',
            row.clientId ?? '',
            row.planName ?? '',
            row.source,
            row.state,
            row.explanation,
          ].any((value) => value.toLowerCase().contains(query));
        })
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wideRows = constraints.maxWidth >= 1080;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CostToolbar(
              result: result,
              onBack: widget.onBack,
              onPrevious: () => _moveMonth(result.month, -1),
              onNext: () => _moveMonth(result.month, 1),
              onCurrent: () => _setMonth(null),
              onRefresh: _refresh,
            ),
            const SizedBox(height: 8),
            _CostCurrencySelector(
              currencies: result.currencies,
              selectedId: selected.currencyId,
              onSelected: (value) {
                if (value == null) return;
                setState(() => _currencyId = value);
                _resetScroll();
              },
            ),
            const SizedBox(height: 8),
            _CostMetrics(currency: selected),
            const SizedBox(height: 8),
            _CostMeaningNotice(result: result, currency: selected),
            const SizedBox(height: 8),
            _CostSearch(
              controller: _search,
              valueCount: costs.length,
              totalCount: selected.costs.length,
              onChanged: (value) {
                setState(() => _query = value);
                _resetScroll();
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: PulsoPanel(
                padding: EdgeInsets.zero,
                child: costs.isEmpty
                    ? const PulsoStateView(
                        kind: PulsoStateKind.empty,
                        message: 'Ningún costo coincide con la búsqueda.',
                      )
                    : Scrollbar(
                        key: const Key('trainer-service-cost-scrollbar'),
                        controller: _rowsScroll,
                        thumbVisibility: true,
                        child: ListView.separated(
                          key: const Key('trainer-service-cost-list'),
                          controller: _rowsScroll,
                          padding: const EdgeInsets.all(8),
                          itemCount: costs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, index) => _CostRow(
                            cost: costs[index],
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

  void _moveMonth(String current, int delta) {
    final parts = current.split('-');
    final year = int.tryParse(parts.first) ?? DateTime.now().year;
    final month = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
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
    ref.invalidate(trainerServiceCostProvider(_month));
    ref.invalidate(operationalResultsProvider(_month));
  }

  void _resetScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_rowsScroll.hasClients) _rowsScroll.jumpTo(0);
    });
  }
}

class _CostToolbar extends StatelessWidget {
  const _CostToolbar({
    required this.result,
    required this.onBack,
    required this.onPrevious,
    required this.onNext,
    required this.onCurrent,
    required this.onRefresh,
  });

  final TrainerServiceCostModel result;
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
                  key: const Key('trainer-service-cost-back-compact'),
                  icon: Icons.arrow_back,
                  tooltip: 'Volver a Resultado de caja',
                  onPressed: onBack,
                )
              else
                TextButton.icon(
                  key: const Key('trainer-service-cost-back'),
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
                TextButton(
                  onPressed: onCurrent,
                  child: const Text('MES ACTUAL'),
                ),
              ],
              PulsoIconButton(
                icon: Icons.refresh,
                tooltip: 'Actualizar costo del servicio',
                onPressed: onRefresh,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CostCurrencySelector extends StatelessWidget {
  const _CostCurrencySelector({
    required this.currencies,
    required this.selectedId,
    required this.onSelected,
  });

  final List<TrainerServiceCostCurrencyModel> currencies;
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
              key: ValueKey('trainer-service-cost-currency-$selectedId'),
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
                          '${item.currencyCode} · ${item.trainers.length} entrenador(es)',
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
                    PulsoLabel('MONEDA DEL COSTO'),
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

class _CostMetrics extends StatelessWidget {
  const _CostMetrics({required this.currency});

  final TrainerServiceCostCurrencyModel currency;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('GANADO ESTE MES', currency.earnedInMonth, 'Trabajo ya prestado'),
      ('PAGADO ESTE MES', currency.paidInMonth, 'Salidas netas registradas'),
      (
        'GANADO SIN PAGAR',
        currency.earnedPending,
        'Deuda actual al entrenador',
      ),
      (
        'TRABAJO FUTURO',
        currency.futureCommitted,
        'Aún no corresponde pagarlo',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return SizedBox(
            height: 84,
            child: ListView.separated(
              key: const Key('trainer-service-cost-metrics-list'),
              scrollDirection: Axis.horizontal,
              itemCount: values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => SizedBox(
                width: 220,
                child: _CostMetricCard(
                  label: values[index].$1,
                  value: values[index].$2,
                  note: values[index].$3,
                  currency: currency.currencyCode,
                  emphasis: index == 2,
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
                  child: _CostMetricCard(
                    label: values[index].$1,
                    value: values[index].$2,
                    note: values[index].$3,
                    currency: currency.currencyCode,
                    emphasis: index == 2,
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

class _CostMetricCard extends StatelessWidget {
  const _CostMetricCard({
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
                color: emphasis ? tokens.accent : tokens.chalk,
                fontFamily: PulsoFonts.display,
                fontSize: 25,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: tokens.chalkDim, fontSize: 10)),
          Text(note, style: TextStyle(color: tokens.muted, fontSize: 9)),
        ],
      ),
    );
  }
}

class _CostMeaningNotice extends StatelessWidget {
  const _CostMeaningNotice({required this.result, required this.currency});

  final TrainerServiceCostModel result;
  final TrainerServiceCostCurrencyModel currency;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final review = result.coverage.requiresReview > 0;
    return PulsoPanel(
      color: review ? tokens.warningSoft : tokens.successSoft,
      borderColor: review ? tokens.warning : tokens.success,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: Text(
        '${result.note} ${currency.trainers.length} entrenador(es), '
        '${currency.costs.length} concepto(s) y ${result.coverage.withPause} con pausa. '
        '${review ? '${result.coverage.requiresReview} requieren revisión.' : 'La cobertura no presenta incidencias.'}',
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

class _CostSearch extends StatelessWidget {
  const _CostSearch({
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
              key: const Key('trainer-service-cost-search'),
              controller: controller,
              onChanged: onChanged,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: 'Entrenador, socio, plan, comisión o fijo…',
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

class _CostRow extends StatelessWidget {
  const _CostRow({
    required this.cost,
    required this.currencyCode,
    required this.expanded,
  });

  final TrainerServiceCostRowModel cost;
  final String currencyCode;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = cost.requiresReview ? tokens.warning : tokens.accent;
    return Container(
      key: ValueKey('trainer-service-cost-row-${cost.costId}'),
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
        Expanded(flex: 6, child: _identity(tokens, color)),
        _amount(tokens, 'GANADO MES', cost.earnedInMonth),
        _amount(tokens, 'PAGADO TOTAL', cost.paidToDate),
        _amount(tokens, 'SIN PAGAR', cost.earnedPending),
        _amount(tokens, 'FUTURO', cost.futureCommitted),
        SizedBox(
          width: 118,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const PulsoLabel('PROGRAMADO'),
              const SizedBox(height: 4),
              Text(
                cost.scheduledDate,
                style: TextStyle(
                  color: tokens.chalk,
                  fontFamily: PulsoFonts.mono,
                  fontSize: 10,
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
            _compactAmount(tokens, 'GANADO MES', cost.earnedInMonth),
            _compactAmount(tokens, 'SIN PAGAR', cost.earnedPending),
            _compactAmount(tokens, 'FUTURO', cost.futureCommitted),
          ],
        ),
      ],
    );
  }

  Widget _identity(PulsoTokens tokens, Color color) {
    final subject = cost.source == 'FIJO'
        ? 'Compensación fija · sin repartir entre socios'
        : '${cost.clientName ?? 'Socio sin identificar'} · ${cost.planName ?? 'Plan sin identificar'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                cost.trainerName,
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
              cost.source,
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
          subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: tokens.chalkDim, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          cost.explanation,
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

String _costErrorText(Object error) {
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
  return 'Revise los conceptos señalados o vuelva a intentarlo.';
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
