import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../dashboard/presentation/state/dashboard_nav_provider.dart';
import '../../../financials/data/models/currency_model.dart';
import '../../../financials/presentation/state/currency_notifier.dart';
import '../../data/models/statistics_ranking_page.dart';
import '../../data/services/statistics_ranking_export_service.dart';
import '../state/statistics_providers.dart';
import 'statistics_shared.dart';

class StatisticsRankingExplorerPulsoView extends ConsumerStatefulWidget {
  const StatisticsRankingExplorerPulsoView({super.key});

  @override
  ConsumerState<StatisticsRankingExplorerPulsoView> createState() =>
      _StatisticsRankingExplorerPulsoViewState();
}

class _StatisticsRankingExplorerPulsoViewState
    extends ConsumerState<StatisticsRankingExplorerPulsoView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  bool _exporting = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(statisticsRankingQueryProvider.notifier).setSearch(value);
    });
  }

  void _openRow(StatisticsRankingType type, String id) {
    switch (type) {
      case StatisticsRankingType.plans:
        ref.read(selectedPlanProvider.notifier).select(id);
        ref.read(dashboardNavProvider.notifier).setIndex(30);
        return;
      case StatisticsRankingType.trainers:
        ref.read(selectedTrainerProvider.notifier).select(id);
        ref.read(dashboardNavProvider.notifier).setIndex(29);
        return;
      case StatisticsRankingType.memberVisits:
      case StatisticsRankingType.memberInactivity:
      case StatisticsRankingType.memberTrainerChanges:
      case StatisticsRankingType.memberValue:
        ref.read(selectedMemberProvider.notifier).select(id);
        ref.read(dashboardNavProvider.notifier).setIndex(31);
        return;
    }
  }

  Future<void> _export(StatisticsRankingQuery query) async {
    setState(() => _exporting = true);
    try {
      final result = await ref.read(statisticsRankingExporterProvider)(query);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.saved
                ? 'CSV guardado: ${result.rows} registros exportados.'
                : 'Exportación cancelada.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo exportar el ranking. '
            '${statisticsErrorMessage(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(statisticsRankingQueryProvider);
    final state = ref.watch(statisticsRankingPageProvider(query));
    final currencies =
        ref.watch(currencyProvider).value ?? const <CurrencyModel>[];
    if (!_searchFocus.hasFocus && _searchController.text != query.search) {
      _searchController.value = TextEditingValue(
        text: query.search,
        selection: TextSelection.collapsed(offset: query.search.length),
      );
    }

    return PulsoThemeScope(
      child: Builder(
        builder: (context) => ColoredBox(
          color: PulsoTokens.of(context).floor,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              return SingleChildScrollView(
                padding: EdgeInsets.all(compact ? 16 : 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StatsHeader(
                      etiqueta: 'Estadística · ranking completo',
                      titulo: _title(query.type),
                      descripcion:
                          '${_description(query.type)} La búsqueda, el orden '
                          'y la paginación se resuelven en el servidor.',
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: PulsoSecondaryButton(
                        label: 'Volver al resumen',
                        icon: Icons.arrow_back,
                        onPressed: () => ref
                            .read(dashboardNavProvider.notifier)
                            .setIndex(28),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _RankingFilters(
                      query: query,
                      searchController: _searchController,
                      searchFocus: _searchFocus,
                      onSearch: _search,
                    ),
                    const SizedBox(height: 14),
                    state.when(
                      loading: () => const PulsoPanel(
                        child: PulsoStateView(
                          kind: PulsoStateKind.loading,
                          message: 'Consultando esta página del ranking…',
                        ),
                      ),
                      error: (error, _) => PulsoPanel(
                        child: PulsoStateView(
                          kind: PulsoStateKind.error,
                          message:
                              'No se pudo consultar el ranking.\n'
                              '${statisticsErrorMessage(error)}',
                          onRetry: () => ref.invalidate(
                            statisticsRankingPageProvider(query),
                          ),
                        ),
                      ),
                      data: (page) => _RankingResults(
                        query: query,
                        page: page,
                        currencies: currencies,
                        onOpen: (id) => _openRow(query.type, id),
                        exporting: _exporting,
                        onExport: () => _export(query),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RankingFilters extends ConsumerWidget {
  const _RankingFilters({
    required this.query,
    required this.searchController,
    required this.searchFocus,
    required this.onSearch,
  });

  final StatisticsRankingQuery query;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(statisticsRankingQueryProvider.notifier);
    final orders = rankingOrders[query.type] ?? const <(String, String)>[];
    return PulsoPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const PulsoLabel('PERÍODO'),
              for (final period in const [
                (30, '30 días'),
                (90, '90 días'),
                (365, '12 meses'),
              ])
                if (query.days == period.$1)
                  PulsoPrimaryButton(
                    label: period.$2,
                    onPressed: () => notifier.setDays(period.$1),
                  )
                else
                  PulsoSecondaryButton(
                    label: period.$2,
                    onPressed: () => notifier.setDays(period.$1),
                  ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final search = TextField(
                key: const ValueKey('ranking-search'),
                controller: searchController,
                focusNode: searchFocus,
                onChanged: onSearch,
                onSubmitted: notifier.setSearch,
                decoration: const InputDecoration(
                  hintText: 'Buscar por nombre o identificación…',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
              );
              final controls = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey('ranking-order'),
                      isExpanded: true,
                      initialValue: query.order,
                      decoration: const InputDecoration(
                        labelText: 'Ordenar por',
                      ),
                      items: [
                        for (final order in orders)
                          DropdownMenuItem(
                            value: order.$1,
                            child: Text(order.$2),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) notifier.setOrder(value);
                      },
                    ),
                  ),
                  PulsoSecondaryButton(
                    label: query.direction == 'desc'
                        ? 'Mayor primero'
                        : 'Menor primero',
                    icon: query.direction == 'desc' ? Icons.south : Icons.north,
                    onPressed: notifier.toggleDirection,
                  ),
                  SizedBox(
                    width: 130,
                    child: DropdownButtonFormField<int>(
                      key: const ValueKey('ranking-page-size'),
                      isExpanded: true,
                      initialValue: query.pageSize,
                      decoration: const InputDecoration(
                        labelText: 'Por página',
                      ),
                      items: [
                        for (final size in const [25, 50, 100])
                          DropdownMenuItem(value: size, child: Text('$size')),
                      ],
                      onChanged: (value) {
                        if (value != null) notifier.setPageSize(value);
                      },
                    ),
                  ),
                ],
              );
              if (constraints.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [search, const SizedBox(height: 10), controls],
                );
              }
              return Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 10),
                  Flexible(flex: 2, child: controls),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RankingResults extends ConsumerWidget {
  const _RankingResults({
    required this.query,
    required this.page,
    required this.currencies,
    required this.onOpen,
    required this.exporting,
    required this.onExport,
  });

  final StatisticsRankingQuery query;
  final StatisticsRankingPage page;
  final List<CurrencyModel> currencies;
  final ValueChanged<String> onOpen;
  final bool exporting;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    final pagination = page.pagination;
    final columns = _columns(query.type, currencies, query.currencyId);
    final currentPage = pagination.totalPages == 0 ? 0 : pagination.number;
    return PulsoPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              StatsPanelTitle(_title(query.type)),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${pagination.total} registros',
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 11,
                      color: tokens.muted,
                    ),
                  ),
                  PulsoSecondaryButton(
                    key: const ValueKey('ranking-export-csv'),
                    label: exporting ? 'Exportando…' : 'Guardar CSV',
                    icon: Icons.download,
                    onPressed: exporting ? null : onExport,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'El CSV incluye todos los registros filtrados, no solo esta página.',
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              color: tokens.muted,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Actual ${page.period.from} → ${page.period.to} · '
            'anterior ${page.previousPeriod.from} → '
            '${page.previousPeriod.to}',
            key: const ValueKey('ranking-comparison-periods'),
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              color: tokens.muted,
            ),
          ),
          const SizedBox(height: 12),
          if (page.rows.isEmpty)
            const SizedBox(
              height: 180,
              child: PulsoStateView(
                kind: PulsoStateKind.empty,
                message: 'No hay filas que coincidan con estos filtros.',
              ),
            )
          else
            _RankingTable(
              rows: page.rows,
              columns: columns,
              comparisonCurrency:
                  query.type == StatisticsRankingType.memberValue,
              onOpen: onOpen,
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                'Página $currentPage de ${pagination.totalPages} · '
                '${pagination.size} por página',
                key: const ValueKey('ranking-pagination-label'),
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 10,
                  color: tokens.muted,
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  PulsoSecondaryButton(
                    label: 'Anterior',
                    icon: Icons.chevron_left,
                    onPressed: pagination.number > 1
                        ? () => ref
                              .read(statisticsRankingQueryProvider.notifier)
                              .setPage(pagination.number - 1)
                        : null,
                  ),
                  PulsoSecondaryButton(
                    label: 'Siguiente',
                    icon: Icons.chevron_right,
                    onPressed: pagination.number < pagination.totalPages
                        ? () => ref
                              .read(statisticsRankingQueryProvider.notifier)
                              .setPage(pagination.number + 1)
                        : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          StatsPie(
            zona: page.zone,
            diaNegocio: page.businessDay,
            tokens: tokens,
          ),
        ],
      ),
    );
  }
}

class _RankingColumn {
  const _RankingColumn(this.key, this.label, {this.currency = false});
  final String key;
  final String label;
  final bool currency;
}

class _RankingTable extends StatelessWidget {
  const _RankingTable({
    required this.rows,
    required this.columns,
    required this.comparisonCurrency,
    required this.onOpen,
  });

  final List<StatisticsRankingRow> rows;
  final List<_RankingColumn> columns;
  final bool comparisonCurrency;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final tableWidth = 300.0 + (columns.length + 3) * 140;
    final height = (rows.length * 48.0 + 45).clamp(180.0, 560.0).toDouble();
    Widget cell(
      String text, {
      required bool header,
      VoidCallback? onTap,
      bool numeric = false,
      Key? key,
    }) {
      final content = Container(
        key: key,
        alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.line)),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: header || numeric ? PulsoFonts.mono : null,
            fontSize: header ? 9 : 11,
            fontWeight: header ? FontWeight.w700 : FontWeight.w500,
            color: header ? tokens.muted : tokens.chalk,
          ),
        ),
      );
      return onTap == null ? content : InkWell(onTap: onTap, child: content);
    }

    return SizedBox(
      height: height,
      child: Scrollbar(
        thumbVisibility: rows.length > 10,
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Table(
                columnWidths: {
                  0: const FlexColumnWidth(2.2),
                  for (var index = 0; index < columns.length + 3; index++)
                    index + 1: const FlexColumnWidth(1),
                  columns.length + 4: const FixedColumnWidth(70),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: tokens.raised),
                    children: [
                      cell('NOMBRE / IDENTIFICACIÓN', header: true),
                      for (final column in columns)
                        cell(
                          column.label.toUpperCase(),
                          header: true,
                          numeric: true,
                        ),
                      cell('PERÍODO ANTERIOR', header: true, numeric: true),
                      cell('CAMBIO', header: true, numeric: true),
                      cell('VARIACIÓN', header: true, numeric: true),
                      cell('', header: true),
                    ],
                  ),
                  for (final row in rows)
                    TableRow(
                      key: ValueKey('ranking-explorer-${row.id}'),
                      children: [
                        cell(
                          '${row.name}\n${row.id}',
                          header: false,
                          key: ValueKey('ranking-explorer-${row.id}'),
                          onTap: () => onOpen(row.id),
                        ),
                        for (final column in columns)
                          cell(
                            _format(row.value(column.key), column.currency),
                            header: false,
                            numeric: true,
                            onTap: () => onOpen(row.id),
                          ),
                        cell(
                          _format(row.comparison.previous, comparisonCurrency),
                          header: false,
                          numeric: true,
                          onTap: () => onOpen(row.id),
                        ),
                        cell(
                          _formatSigned(
                            row.comparison.delta,
                            comparisonCurrency,
                          ),
                          header: false,
                          numeric: true,
                          onTap: () => onOpen(row.id),
                        ),
                        cell(
                          _formatPercentage(row.comparison.percentageChange),
                          header: false,
                          numeric: true,
                          onTap: () => onOpen(row.id),
                        ),
                        cell(
                          'VER',
                          header: true,
                          numeric: true,
                          onTap: () => onOpen(row.id),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _format(num value, bool currency) => currency
    ? NumberFormat('#,##0.00').format(value)
    : NumberFormat('#,##0').format(value);

String _formatSigned(num value, bool currency) {
  final formatted = _format(value.abs(), currency);
  if (value > 0) return '+$formatted';
  if (value < 0) return '−$formatted';
  return formatted;
}

String _formatPercentage(num? value) {
  if (value == null) return 'SIN BASE';
  final formatted = NumberFormat('#,##0.##').format(value.abs());
  if (value > 0) return '+$formatted%';
  if (value < 0) return '−$formatted%';
  return '0%';
}

String _title(StatisticsRankingType type) => switch (type) {
  StatisticsRankingType.plans => 'PLANES CONTRATADOS',
  StatisticsRankingType.trainers => 'CARTERA POR ENTRENADOR',
  StatisticsRankingType.memberVisits => 'SOCIOS CONSTANTES',
  StatisticsRankingType.memberInactivity => 'INACTIVIDAD OBSERVADA',
  StatisticsRankingType.memberTrainerChanges => 'CAMBIOS DE ENTRENADOR',
  StatisticsRankingType.memberValue => 'VALOR POR SOCIO',
};

String _description(StatisticsRankingType type) => switch (type) {
  StatisticsRankingType.plans =>
    'Compara contratos iniciados, cobertura vigente y renovaciones.',
  StatisticsRankingType.trainers =>
    'Compara cartera activa, socios ganados y socios perdidos.',
  StatisticsRankingType.memberVisits =>
    'Ordena socios activos por visitas registradas en el período.',
  StatisticsRankingType.memberInactivity =>
    'Muestra días desde la última visita, sin inventar faltas obligatorias.',
  StatisticsRankingType.memberTrainerChanges =>
    'Cuenta cambios reales de persona entrenadora.',
  StatisticsRankingType.memberValue =>
    'Compara cobros netos dentro de una sola moneda.',
};

List<_RankingColumn> _columns(
  StatisticsRankingType type,
  List<CurrencyModel> currencies,
  String? currencyId,
) => switch (type) {
  StatisticsRankingType.plans => const [
    _RankingColumn('vendidos', 'Ventas'),
    _RankingColumn('sociosConCobertura', 'Cobertura'),
    _RankingColumn('renovaciones', 'Renovaciones'),
  ],
  StatisticsRankingType.trainers => const [
    _RankingColumn('carteraActiva', 'Cartera'),
    _RankingColumn('ganados', 'Ganados'),
    _RankingColumn('perdidos', 'Perdidos'),
  ],
  StatisticsRankingType.memberVisits ||
  StatisticsRankingType.memberInactivity => const [
    _RankingColumn('visitas', 'Visitas'),
    _RankingColumn('diasSinVisita', 'Días sin visita'),
  ],
  StatisticsRankingType.memberTrainerChanges => const [
    _RankingColumn('cambios', 'Cambios'),
  ],
  StatisticsRankingType.memberValue => [
    _RankingColumn(
      'total',
      nombreMoneda(currencies, currencyId ?? ''),
      currency: true,
    ),
  ],
};
