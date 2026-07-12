import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../dashboard/presentation/state/dashboard_nav_provider.dart';
import '../../data/models/currency_model.dart';
import '../../data/models/exchange_rate_model.dart';
import '../providers/exchange_rate_notifier.dart';
import '../state/currency_notifier.dart';
import '../widgets/exchange_rate_pulso_form.dart';

enum _RateFilter { all, active, expired }

enum _RateSort { pair, rate, since }

enum _RateStatus { active, expired, inactive }

final _rateFmt = NumberFormat('#,##0.####');
final _invFmt = NumberFormat('#,##0.######');
final _dateFmt = DateFormat('yyyy-MM-dd');

// Las fechas de vigencia son fechas de calendario guardadas como medianoche
// UTC (TIME_CONTRACT §4); se muestran por componentes, sin conversión de zona.
String _fmtDate(DateTime? date) =>
    date == null ? '—' : _dateFmt.format(date.toUtc());

String _shortRateId(String id) {
  if (id.length <= 8) return id;
  return '${id.substring(0, 4)}…${id.substring(id.length - 4)}';
}

// El vencimiento se decide con el reloj calibrado, no con el del dispositivo.
_RateStatus _statusOf(ExchangeRateModel rate) {
  if (!rate.activo) return _RateStatus.inactive;
  final expiration = rate.fechaExpiracion;
  if (expiration != null && expiration.isBefore(appClock.nowUtc())) {
    return _RateStatus.expired;
  }
  return _RateStatus.active;
}

String _statusLabel(_RateStatus status) => switch (status) {
  _RateStatus.active => 'ACTIVO',
  _RateStatus.expired => 'VENCIDO',
  _RateStatus.inactive => 'INACTIVO',
};

class ExchangeRatesPulsoView extends ConsumerStatefulWidget {
  const ExchangeRatesPulsoView({super.key});

  @override
  ConsumerState<ExchangeRatesPulsoView> createState() =>
      _ExchangeRatesPulsoViewState();
}

class _ExchangeRatesPulsoViewState
    extends ConsumerState<ExchangeRatesPulsoView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  String? _selectedId;
  _RateFilter _filter = _RateFilter.all;
  _RateSort _sort = _RateSort.pair;
  bool _ascending = true;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  CurrencyModel? _base(ExchangeRateModel r, Map<String, CurrencyModel> map) =>
      r.monedaBase ?? map[r.monedaIdBase];

  CurrencyModel? _target(ExchangeRateModel r, Map<String, CurrencyModel> map) =>
      r.monedaTarget ?? map[r.monedaIdTarget];

  String _pairLabel(ExchangeRateModel r, Map<String, CurrencyModel> map) {
    final base = _base(r, map)?.code ?? _shortRateId(r.monedaIdBase);
    final target = _target(r, map)?.code ?? _shortRateId(r.monedaIdTarget);
    return '${base.toUpperCase()} → ${target.toUpperCase()}';
  }

  List<ExchangeRateModel> _visible(
    List<ExchangeRateModel> all,
    Map<String, CurrencyModel> currencyMap,
  ) {
    final query = _query.trim().toLowerCase();
    final result = all.where((item) {
      final base = _base(item, currencyMap);
      final target = _target(item, currencyMap);
      final haystack = [
        base?.name,
        base?.code,
        target?.name,
        target?.code,
        item.exchangeRate.toString(),
        _statusLabel(_statusOf(item)),
      ].whereType<String>().join(' ').toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      final matchesFilter = switch (_filter) {
        _RateFilter.all => true,
        _RateFilter.active => _statusOf(item) == _RateStatus.active,
        _RateFilter.expired => _statusOf(item) == _RateStatus.expired,
      };
      return matchesQuery && matchesFilter;
    }).toList();
    int compare(ExchangeRateModel a, ExchangeRateModel b) {
      final value = switch (_sort) {
        _RateSort.pair => _pairLabel(
          a,
          currencyMap,
        ).compareTo(_pairLabel(b, currencyMap)),
        _RateSort.rate => a.exchangeRate.compareTo(b.exchangeRate),
        _RateSort.since => a.fechaInicio.compareTo(b.fechaInicio),
      };
      return _ascending ? value : -value;
    }

    result.sort(compare);
    return result;
  }

  void _setSort(_RateSort sort) {
    setState(() {
      if (_sort == sort) {
        _ascending = !_ascending;
      } else {
        _sort = sort;
        // Por vigencia interesa primero la tasa más reciente.
        _ascending = sort != _RateSort.since;
      }
    });
  }

  Future<void> _openForm([ExchangeRateModel? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ExchangeRatePulsoForm(
        initialData: item,
        onSubmit: (data) async {
          final notifier = ref.read(exchangeRateProvider.notifier);
          if (item == null) {
            await notifier.create(data);
          } else {
            await notifier.updateExchangeRate(item.id, data);
          }
        },
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          item == null
              ? 'Nuevo tipo de cambio creado.'
              : 'El tipo de cambio fue actualizado.',
        ),
      ),
    );
  }

  /// Renovar una tasa vencida: alta nueva precargada con el par y la última
  /// tasa conocida, vigente desde hoy. La tasa vencida queda como historial.
  Future<void> _renewRate(
    ExchangeRateModel item,
    Map<String, CurrencyModel> currencyMap,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ExchangeRatePulsoForm(
        initialBaseCurrencyId: item.monedaIdBase,
        initialTargetCurrencyId: item.monedaIdTarget,
        initialRate: item.exchangeRate,
        onSubmit: (data) =>
            ref.read(exchangeRateProvider.notifier).create(data),
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'La tasa ${_pairLabel(item, currencyMap)} fue renovada.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    ExchangeRateModel item,
    Map<String, CurrencyModel> currencyMap,
  ) async {
    final tokens = PulsoTokens.of(context);
    final pair = _pairLabel(item, currencyMap);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PulsoThemeScope(
        child: AlertDialog(
          title: const Text('Eliminar tipo de cambio'),
          content: Text(
            'Se eliminará la tasa $pair de la pizarra. '
            'Los pagos ya convertidos no se modifican.',
          ),
          actions: [
            PulsoSecondaryButton(
              label: 'Cancelar',
              onPressed: () => Navigator.of(context).pop(false),
            ),
            PulsoSecondaryButton(
              label: 'Eliminar',
              danger: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(exchangeRateProvider.notifier).delete(item.id);
      if (!mounted) return;
      if (_selectedId == item.id) setState(() => _selectedId = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('La tasa $pair fue eliminada.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: tokens.danger,
          content: Text('No se pudo eliminar: $error'),
        ),
      );
    }
  }

  void _goToCurrencies() {
    ref.read(dashboardNavProvider.notifier).setIndex(18);
  }

  void _showDetail(
    BuildContext context,
    ExchangeRateModel item,
    Map<String, CurrencyModel> currencyMap,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => PulsoThemeScope(
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 40,
          ),
          child: SizedBox(
            width: 340,
            height: 560,
            child: _RateDetail(
              item: item,
              currencyMap: currencyMap,
              onEdit: () {
                Navigator.of(dialogContext).pop();
                _openForm(item);
              },
              onRenew: () {
                Navigator.of(dialogContext).pop();
                _renewRate(item, currencyMap);
              },
              onDelete: () {
                Navigator.of(dialogContext).pop();
                _confirmDelete(item, currencyMap);
              },
              onCurrencies: () {
                Navigator.of(dialogContext).pop();
                _goToCurrencies();
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PulsoThemeScope(
      child: Builder(
        builder: (context) => ColoredBox(
          color: PulsoTokens.of(context).floor,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                  _searchFocus.requestFocus,
              const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                  _searchFocus.requestFocus,
            },
            child: Focus(autofocus: true, child: _buildPage(context)),
          ),
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context) {
    final state = ref.watch(exchangeRateProvider);
    final all = state.value ?? const <ExchangeRateModel>[];
    final currencyMap = <String, CurrencyModel>{
      for (final currency
          in ref.watch(currencyProvider).value ?? const <CurrencyModel>[])
        currency.id: currency,
    };
    final visible = _visible(all, currencyMap);
    var active = 0;
    var expired = 0;
    final coveredCurrencies = <String>{};
    for (final item in all) {
      switch (_statusOf(item)) {
        case _RateStatus.active:
          active++;
          coveredCurrencies.add(item.monedaIdBase);
          coveredCurrencies.add(item.monedaIdTarget);
        case _RateStatus.expired:
          expired++;
        case _RateStatus.inactive:
          break;
      }
    }
    ExchangeRateModel? selected;
    for (final item in all) {
      if (item.id == _selectedId) selected = item;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final scrollPage = compact || constraints.maxHeight < 760;
        final padding = compact
            ? 16.0
            : constraints.maxWidth < 840
            ? 24.0
            : 32.0;
        final workspaceWide = constraints.maxWidth - (padding * 2) >= 1040;
        final catalog = state.when(
          loading: () => const PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.loading,
              message: 'Cargando la pizarra cambiaria…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message: 'No se pudo cargar la pizarra.\n$error',
              onRetry: () => ref.invalidate(exchangeRateProvider),
            ),
          ),
          data: (_) => visible.isEmpty
              ? PulsoPanel(
                  child: PulsoStateView(
                    kind: PulsoStateKind.empty,
                    message: all.isEmpty
                        ? 'Aún no rige ningún tipo de cambio.'
                        : 'Ninguna tasa coincide con la búsqueda.',
                  ),
                )
              : _RateWorkspace(
                  items: visible,
                  currencyMap: currencyMap,
                  selected: workspaceWide ? selected : null,
                  sort: _sort,
                  ascending: _ascending,
                  pairLabel: (item) => _pairLabel(item, currencyMap),
                  onSort: _setSort,
                  onSelect: (item) {
                    if (workspaceWide) {
                      setState(() => _selectedId = item.id);
                    } else {
                      _showDetail(context, item, currencyMap);
                    }
                  },
                  onEdit: _openForm,
                  onRenew: (item) => _renewRate(item, currencyMap),
                  onDelete: (item) => _confirmDelete(item, currencyMap),
                  onCurrencies: _goToCurrencies,
                ),
        );
        final page = Column(
          mainAxisSize: scrollPage ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RateHeader(onCreate: () => _openForm()),
            const SizedBox(height: 14),
            PulsoMetricStrip(
              metrics: [
                PulsoMetricData(
                  value: '$active',
                  label: 'Tasas activas',
                  note: 'rigen ahora',
                  emphasis: true,
                ),
                PulsoMetricData(
                  value: '${coveredCurrencies.length}',
                  label: 'Divisas',
                  note: 'cubiertas por tasas activas',
                ),
                PulsoMetricData(
                  value: '$expired',
                  label: 'Vencidas',
                  note: 'requieren renovación',
                  warning: expired > 0,
                ),
                PulsoMetricData(
                  value: '${all.length - active - expired}',
                  label: 'Inactivas',
                  note: 'apagadas manualmente',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RateCommand(
              controller: _searchController,
              focusNode: _searchFocus,
              filter: _filter,
              onSearch: (value) => setState(() => _query = value),
              onFilter: (value) => setState(() => _filter = value),
              onRefresh: () {
                ref.invalidate(exchangeRateProvider);
                ref.invalidate(currencyProvider);
              },
            ),
            const SizedBox(height: 12),
            if (scrollPage)
              SizedBox(height: 360, child: catalog)
            else
              Expanded(child: catalog),
            const SizedBox(height: 8),
            const _RateFooter(),
          ],
        );
        final insets = EdgeInsets.fromLTRB(
          padding,
          compact ? 16 : 20,
          padding,
          compact ? 18 : 24,
        );
        return scrollPage
            ? SingleChildScrollView(padding: insets, child: page)
            : Padding(padding: insets, child: page);
      },
    );
  }
}

class _RateHeader extends StatelessWidget {
  const _RateHeader({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PulsoLabel('PULSO · FINANZAS'),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                text: 'TIPOS DE CAMBIO',
                children: [
                  TextSpan(
                    text: '.',
                    style: TextStyle(color: tokens.accent),
                  ),
                ],
              ),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Define las tasas que convierten cobros entre divisas del catálogo.',
              style: TextStyle(color: tokens.muted, fontSize: 14),
            ),
          ],
        );
        final action = PulsoPrimaryButton(
          label: 'Nueva tasa',
          icon: Icons.add,
          onPressed: onCreate,
        );
        return constraints.maxWidth < 680
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, const SizedBox(height: 14), action],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 24),
                  action,
                ],
              );
      },
    );
  }
}

class _RateCommand extends StatelessWidget {
  const _RateCommand({
    required this.controller,
    required this.focusNode,
    required this.filter,
    required this.onSearch,
    required this.onFilter,
    required this.onRefresh,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final _RateFilter filter;
  final ValueChanged<String> onSearch;
  final ValueChanged<_RateFilter> onFilter;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return PulsoPanel(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            key: const ValueKey('pulso-rate-search'),
            controller: controller,
            focusNode: focusNode,
            onChanged: onSearch,
            decoration: const InputDecoration(
              hintText: 'Buscar par, código, tasa o estado…',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          );
          final controls = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _FilterButton(
                label: 'Todas',
                selected: filter == _RateFilter.all,
                onTap: () => onFilter(_RateFilter.all),
              ),
              _FilterButton(
                label: 'Activas',
                selected: filter == _RateFilter.active,
                onTap: () => onFilter(_RateFilter.active),
              ),
              _FilterButton(
                label: 'Vencidas',
                selected: filter == _RateFilter.expired,
                onTap: () => onFilter(_RateFilter.expired),
              ),
              PulsoIconButton(
                icon: Icons.refresh,
                tooltip: 'Actualizar',
                onPressed: onRefresh,
              ),
            ],
          );
          return constraints.maxWidth < 780
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [search, const SizedBox(height: 8), controls],
                )
              : Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 10),
                    controls,
                  ],
                );
        },
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
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
      color: selected ? tokens.accentSoft : tokens.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? tokens.accent : tokens.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? tokens.chalk : tokens.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _RateWorkspace extends StatelessWidget {
  const _RateWorkspace({
    required this.items,
    required this.currencyMap,
    required this.selected,
    required this.sort,
    required this.ascending,
    required this.pairLabel,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onRenew,
    required this.onDelete,
    required this.onCurrencies,
  });
  final List<ExchangeRateModel> items;
  final Map<String, CurrencyModel> currencyMap;
  final ExchangeRateModel? selected;
  final _RateSort sort;
  final bool ascending;
  final String Function(ExchangeRateModel) pairLabel;
  final ValueChanged<_RateSort> onSort;
  final ValueChanged<ExchangeRateModel> onSelect;
  final ValueChanged<ExchangeRateModel> onEdit;
  final ValueChanged<ExchangeRateModel> onRenew;
  final ValueChanged<ExchangeRateModel> onDelete;
  final VoidCallback onCurrencies;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final list = _RateList(
          items: items,
          currencyMap: currencyMap,
          selectedId: selected?.id,
          sort: sort,
          ascending: ascending,
          onSort: onSort,
          onSelect: onSelect,
          onEdit: onEdit,
          onDelete: onDelete,
        );
        if (constraints.maxWidth < 1040) return list;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: list),
            const SizedBox(width: 12),
            SizedBox(
              width: 330,
              child: _RateDetail(
                item: selected,
                currencyMap: currencyMap,
                onEdit: selected == null ? null : () => onEdit(selected!),
                onRenew: selected == null ? null : () => onRenew(selected!),
                onDelete: selected == null ? null : () => onDelete(selected!),
                onCurrencies: onCurrencies,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RateList extends StatelessWidget {
  const _RateList({
    required this.items,
    required this.currencyMap,
    required this.selectedId,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });
  final List<ExchangeRateModel> items;
  final Map<String, CurrencyModel> currencyMap;
  final String? selectedId;
  final _RateSort sort;
  final bool ascending;
  final ValueChanged<_RateSort> onSort;
  final ValueChanged<ExchangeRateModel> onSelect;
  final ValueChanged<ExchangeRateModel> onEdit;
  final ValueChanged<ExchangeRateModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 46),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: tokens.line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _SortButton(
                        label: 'Par',
                        active: sort == _RateSort.pair,
                        ascending: ascending,
                        onTap: () => onSort(_RateSort.pair),
                      ),
                    ),
                    if (!compact) ...[
                      Expanded(
                        flex: 2,
                        child: _SortButton(
                          label: 'Tasa',
                          active: sort == _RateSort.rate,
                          ascending: ascending,
                          onTap: () => onSort(_RateSort.rate),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _SortButton(
                          label: 'Vigencia',
                          active: sort == _RateSort.since,
                          ascending: ascending,
                          onTap: () => onSort(_RateSort.since),
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PulsoLabel('Estado'),
                        ),
                      ),
                      const SizedBox(width: 100),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  key: const PageStorageKey('pulso-rates-list'),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: tokens.line),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _RateRow(
                      key: ValueKey(item.id),
                      item: item,
                      currencyMap: currencyMap,
                      selected: selectedId == item.id,
                      compact: compact,
                      onSelect: () => onSelect(item),
                      onEdit: () => onEdit(item),
                      onDelete: () => onDelete(item),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: tokens.line)),
                ),
                child: Text(
                  '${items.length} resultados · fechas de vigencia en calendario UTC',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 9,
                    color: tokens.muted2,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
  });
  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.zero,
        foregroundColor: active ? tokens.accent : tokens.muted,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: PulsoLabel(label, color: active ? tokens.accent : null),
          ),
          if (active) ...[
            const SizedBox(width: 4),
            Icon(
              ascending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 12,
            ),
          ],
        ],
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({
    super.key,
    required this.item,
    required this.currencyMap,
    required this.selected,
    required this.compact,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });
  final ExchangeRateModel item;
  final Map<String, CurrencyModel> currencyMap;
  final bool selected;
  final bool compact;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final base = item.monedaBase ?? currencyMap[item.monedaIdBase];
    final target = item.monedaTarget ?? currencyMap[item.monedaIdTarget];
    final baseCode = base?.code.toUpperCase() ?? '—';
    final targetCode = target?.code.toUpperCase() ?? '—';
    final status = _statusOf(item);
    final vigencia =
        '${_fmtDate(item.fechaInicio)} → ${_fmtDate(item.fechaExpiracion)}';
    return Material(
      color: selected ? tokens.accentSoftStrong : Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? tokens.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              PulsoFlag(
                code: baseCode,
                base64String: base?.flagImage,
                width: 30,
                height: 20,
              ),
              const SizedBox(width: 4),
              PulsoFlag(
                code: targetCode,
                base64String: target?.flagImage,
                width: 30,
                height: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: baseCode),
                          TextSpan(
                            text: ' → ',
                            style: TextStyle(color: tokens.accent),
                          ),
                          TextSpan(text: targetCode),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: PulsoFonts.mono,
                        fontWeight: FontWeight.w700,
                        color: tokens.chalk,
                      ),
                    ),
                    if (compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${_rateFmt.format(item.exchangeRate)} · ${_statusLabel(status)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 9.5,
                          color: _statusColor(tokens, status),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!compact) ...[
                Expanded(
                  flex: 2,
                  child: Text(
                    _rateFmt.format(item.exchangeRate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontWeight: FontWeight.w600,
                      color: tokens.chalkDim,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    vigencia,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 11,
                      color: tokens.muted,
                    ),
                  ),
                ),
                Expanded(flex: 2, child: _RateStatusChip(status: status)),
                SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      PulsoIconButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Editar $baseCode → $targetCode',
                        onPressed: onEdit,
                      ),
                      const SizedBox(width: 4),
                      PulsoIconButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Eliminar $baseCode → $targetCode',
                        danger: true,
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ),
              ] else
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _statusColor(PulsoTokens tokens, _RateStatus status) => switch (status) {
  _RateStatus.active => tokens.success,
  _RateStatus.expired => tokens.warning,
  _RateStatus.inactive => tokens.muted,
};

class _RateStatusChip extends StatelessWidget {
  const _RateStatusChip({required this.status});
  final _RateStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = _statusColor(tokens, status);
    return Row(
      children: [
        Container(width: 6, height: 6, color: color),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            _statusLabel(status),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _RateDetail extends StatelessWidget {
  const _RateDetail({
    required this.item,
    required this.currencyMap,
    required this.onEdit,
    required this.onRenew,
    required this.onDelete,
    required this.onCurrencies,
  });
  final ExchangeRateModel? item;
  final Map<String, CurrencyModel> currencyMap;
  final VoidCallback? onEdit;
  final VoidCallback? onRenew;
  final VoidCallback? onDelete;
  final VoidCallback onCurrencies;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final rate = item;
    if (rate == null) {
      return const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.empty,
          message: 'Selecciona un tipo de cambio para ver su detalle.',
        ),
      );
    }
    final base = rate.monedaBase ?? currencyMap[rate.monedaIdBase];
    final target = rate.monedaTarget ?? currencyMap[rate.monedaIdTarget];
    final baseCode = base?.code.toUpperCase() ?? '—';
    final targetCode = target?.code.toUpperCase() ?? '—';
    final status = _statusOf(rate);
    return PulsoPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PulsoLabel('Detalle seleccionado'),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _rateFmt.format(rate.exchangeRate),
              maxLines: 1,
              style: TextStyle(
                fontFamily: PulsoFonts.display,
                fontSize: 48,
                height: 0.9,
                fontWeight: FontWeight.w800,
                color: tokens.accent,
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '$baseCode → $targetCode',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            _statusLabel(status),
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _statusColor(tokens, status),
            ),
          ),
          const SizedBox(height: 12),
          _DetailLine(
            label: 'Base',
            value: '$baseCode · ${base?.symbol ?? '—'}',
          ),
          _DetailLine(
            label: 'Destino',
            value: '$targetCode · ${target?.symbol ?? '—'}',
          ),
          _DetailLine(
            label: 'Inversa',
            value: rate.exchangeRate == 0
                ? '—'
                : _invFmt.format(1 / rate.exchangeRate),
          ),
          _DetailLine(
            label: 'Vigencia',
            value:
                '${_fmtDate(rate.fechaInicio)} → ${_fmtDate(rate.fechaExpiracion)}',
          ),
          const Spacer(),
          // Una tasa vencida se renueva de una pulsación: alta precargada con
          // el par y la última tasa, vigente desde hoy.
          if (status == _RateStatus.expired) ...[
            PulsoPrimaryButton(
              label: 'Renovar tasa',
              icon: Icons.autorenew,
              onPressed: onRenew,
            ),
            const SizedBox(height: 8),
            PulsoSecondaryButton(
              label: 'Editar tasa',
              icon: Icons.edit_outlined,
              onPressed: onEdit,
            ),
          ] else ...[
            PulsoPrimaryButton(
              label: 'Editar tasa',
              icon: Icons.edit_outlined,
              onPressed: onEdit,
            ),
            const SizedBox(height: 8),
            PulsoSecondaryButton(
              label: 'Ver monedas',
              icon: Icons.currency_exchange_outlined,
              onPressed: onCurrencies,
            ),
          ],
          const SizedBox(height: 8),
          PulsoSecondaryButton(
            label: 'Eliminar',
            icon: Icons.delete_outline,
            danger: true,
            onPressed: onDelete,
          ),
          const SizedBox(height: 14),
          Text(
            rate.id,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              color: tokens.muted2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: [
          Expanded(child: PulsoLabel(label)),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontWeight: FontWeight.w600,
                color: tokens.chalkDim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RateFooter extends StatelessWidget {
  const _RateFooter();
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Row(
      children: [
        const PulsoSyncStatus(compact: true),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'PULSO · TIPOS DE CAMBIO · DATOS REALES',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              color: tokens.muted2,
            ),
          ),
        ),
      ],
    );
  }
}
