import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/currency_model.dart';
import '../../data/models/exchange_rate_model.dart';
import '../providers/exchange_rate_notifier.dart';
import '../state/currency_notifier.dart';
import '../widgets/currency_pulso_form.dart';

class CurrenciesPulsoView extends ConsumerStatefulWidget {
  const CurrenciesPulsoView({super.key});

  @override
  ConsumerState<CurrenciesPulsoView> createState() =>
      _CurrenciesPulsoViewState();
}

enum _CurrencyFilter { all, withFlag, withoutFlag }

enum _CurrencySort { name, code, rates }

class _CurrencyRateUsage {
  const _CurrencyRateUsage({this.asBase = 0, this.asTarget = 0});

  final int asBase;
  final int asTarget;

  int get total => asBase + asTarget;

  _CurrencyRateUsage addBase() =>
      _CurrencyRateUsage(asBase: asBase + 1, asTarget: asTarget);

  _CurrencyRateUsage addTarget() =>
      _CurrencyRateUsage(asBase: asBase, asTarget: asTarget + 1);
}

class _CurrenciesPulsoViewState extends ConsumerState<CurrenciesPulsoView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  String _query = '';
  String? _selectedId;
  _CurrencyFilter _filter = _CurrencyFilter.all;
  _CurrencySort _sort = _CurrencySort.name;
  bool _ascending = true;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _openForm([CurrencyModel? currency]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CurrencyPulsoForm(
        id: currency?.id,
        initialName: currency?.name,
        initialCode: currency?.code,
        initialSymbol: currency?.symbol,
        initialFlagImage: currency?.flagImage,
        onSubmit: (name, code, symbol, flagBytes) async {
          final notifier = ref.read(currencyProvider.notifier);
          if (currency == null) {
            await notifier.createCurrency(name, code, symbol, flagBytes);
          } else {
            await notifier.updateCurrency(
              currency.id,
              name,
              code,
              symbol,
              flagBytes,
            );
          }
        },
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          currency == null
              ? 'Nueva moneda creada.'
              : '${currency.code.toUpperCase()} fue actualizada.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(CurrencyModel currency) async {
    final tokens = PulsoTokens.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      // El diálogo se monta en el Overlay del Navigator, por encima del
      // PulsoThemeScope de la pantalla; se envuelve para que los botones
      // Pulso resuelvan tokens sin depender del contexto anfitrión.
      builder: (context) => PulsoThemeScope(
        child: AlertDialog(
          title: const Text('Eliminar moneda'),
          content: Text(
            'Se eliminará “${currency.name}” del catálogo. Esta acción puede fallar si la moneda tiene relaciones activas.',
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
      await ref.read(currencyProvider.notifier).deleteCurrency(currency.id);
      if (!mounted) return;
      if (_selectedId == currency.id) {
        setState(() => _selectedId = null);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“${currency.name}” fue eliminada.')),
      );
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

  void _exportCsv(
    List<CurrencyModel> currencies,
    Map<String, _CurrencyRateUsage> usage,
  ) {
    final buffer = StringBuffer(
      'nombre,codigo,simbolo,como_base,como_destino,cambios\n',
    );
    for (final currency in currencies) {
      final rates = usage[currency.id] ?? const _CurrencyRateUsage();
      buffer.writeln(
        '${_csvCell(currency.name)},${_csvCell(currency.code)},${_csvCell(currency.symbol ?? '')},${rates.asBase},${rates.asTarget},${rates.total}',
      );
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Catálogo copiado como CSV.')));
  }

  String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

  void _showDetailDialog(
    BuildContext context,
    CurrencyModel currency,
    List<ExchangeRateModel> rates,
    Map<String, CurrencyModel> currencyMap,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => PulsoThemeScope(
        child: Builder(
          builder: (pulsoContext) {
            final tokens = PulsoTokens.of(pulsoContext);
            return Dialog(
              backgroundColor: tokens.floor,
              shape: Border.all(color: tokens.lineStrong),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 40,
              ),
              child: SizedBox(
                width: 320,
                height: 480,
                child: _CurrencyInspector(
                  currency: currency,
                  rates: rates,
                  currencyMap: currencyMap,
                  onEdit: () {
                    Navigator.of(dialogContext).pop();
                    _openForm(currency);
                  },
                  onDelete: () {
                    Navigator.of(dialogContext).pop();
                    _confirmDelete(currency);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<CurrencyModel> _visibleCurrencies(
    List<CurrencyModel> all,
    Map<String, _CurrencyRateUsage> usage,
  ) {
    final result = all.where((currency) {
      final query = _query.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          currency.name.toLowerCase().contains(query) ||
          currency.code.toLowerCase().contains(query) ||
          (currency.symbol ?? '').toLowerCase().contains(query);
      final hasFlag = currency.flagImage?.isNotEmpty == true;
      final matchesFilter = switch (_filter) {
        _CurrencyFilter.all => true,
        _CurrencyFilter.withFlag => hasFlag,
        _CurrencyFilter.withoutFlag => !hasFlag,
      };
      return matchesQuery && matchesFilter;
    }).toList();

    int compare(CurrencyModel a, CurrencyModel b) {
      final value = switch (_sort) {
        _CurrencySort.name => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
        _CurrencySort.code => a.code.toLowerCase().compareTo(
          b.code.toLowerCase(),
        ),
        _CurrencySort.rates => (usage[a.id]?.total ?? 0).compareTo(
          usage[b.id]?.total ?? 0,
        ),
      };
      return _ascending ? value : -value;
    }

    result.sort(compare);
    return result;
  }

  void _setSort(_CurrencySort sort) {
    setState(() {
      if (_sort == sort) {
        _ascending = !_ascending;
      } else {
        _sort = sort;
        _ascending = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PulsoThemeScope(
      child: Builder(
        builder: (context) {
          final tokens = PulsoTokens.of(context);
          return ColoredBox(
            color: tokens.floor,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                    _searchFocus.requestFocus,
                const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                    _searchFocus.requestFocus,
              },
              child: Focus(autofocus: true, child: _buildPage(context)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPage(BuildContext context) {
    final currenciesAsync = ref.watch(currencyProvider);
    final ratesAsync = ref.watch(exchangeRateProvider);
    final currencies = currenciesAsync.value ?? const <CurrencyModel>[];
    final rates = ratesAsync.value ?? const <ExchangeRateModel>[];
    final usage = _rateUsage(rates);
    final visible = _visibleCurrencies(currencies, usage);
    final currencyMap = <String, CurrencyModel>{
      for (final currency in currencies) currency.id: currency,
    };
    final withFlag = currencies
        .where((currency) => currency.flagImage?.isNotEmpty == true)
        .length;
    final inUse = currencies
        .where((currency) => (usage[currency.id]?.total ?? 0) > 0)
        .length;

    CurrencyModel? selected;
    for (final currency in currencies) {
      if (currency.id == _selectedId) {
        selected = currency;
        break;
      }
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
        final workspaceWidth = constraints.maxWidth - (padding * 2);
        final isWorkspaceWide = workspaceWidth >= 1040;

        final catalog = currenciesAsync.when(
          loading: () => const PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.loading,
              message: 'Cargando catálogo de monedas…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message: 'No se pudo cargar el catálogo.\n$error',
              onRetry: () => ref.read(currencyProvider.notifier).refresh(),
            ),
          ),
          data: (_) {
            if (visible.isEmpty) {
              return PulsoPanel(
                child: PulsoStateView(
                  kind: PulsoStateKind.empty,
                  message: currencies.isEmpty
                      ? 'Todavía no hay monedas registradas.'
                      : 'Ninguna moneda coincide con la búsqueda.',
                ),
              );
            }
            return _CurrencyWorkspace(
              currencies: visible,
              usage: usage,
              rates: rates,
              currencyMap: currencyMap,
              selected: isWorkspaceWide ? selected : null,
              sort: _sort,
              ascending: _ascending,
              onSort: _setSort,
              onSelect: (currency) {
                if (!isWorkspaceWide) {
                  _showDetailDialog(context, currency, rates, currencyMap);
                } else {
                  setState(() => _selectedId = currency.id);
                }
              },
              onEdit: _openForm,
              onDelete: _confirmDelete,
            );
          },
        );
        final page = Column(
          mainAxisSize: scrollPage ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PageHeader(onCreate: () => _openForm()),
            const SizedBox(height: 14),
            PulsoMetricStrip(
              metrics: [
                PulsoMetricData(
                  value: '${currencies.length}',
                  label: 'Monedas',
                  note: 'catálogo total',
                  emphasis: true,
                ),
                PulsoMetricData(
                  value: '$inUse',
                  label: 'En uso',
                  note: 'con tipos de cambio',
                ),
                PulsoMetricData(
                  value: '$withFlag',
                  label: 'Con bandera',
                  note: '${currencies.length - withFlag} pendientes',
                ),
                PulsoMetricData(
                  value: '${rates.where((rate) => rate.activo).length}',
                  label: 'Cambios activos',
                  note: 'relaciones vigentes',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CommandBar(
              searchController: _searchController,
              searchFocus: _searchFocus,
              filter: _filter,
              onSearch: (value) => setState(() => _query = value),
              onFilter: (value) => setState(() => _filter = value),
              onRefresh: () => ref.read(currencyProvider.notifier).refresh(),
              onExport: visible.isEmpty
                  ? null
                  : () => _exportCsv(visible, usage),
            ),
            const SizedBox(height: 12),
            if (scrollPage)
              SizedBox(height: 360, child: catalog)
            else
              Expanded(child: catalog),
            const SizedBox(height: 8),
            _PilotFooter(compact: compact),
          ],
        );
        final insets = EdgeInsets.fromLTRB(
          padding,
          compact ? 16 : 20,
          padding,
          compact ? 18 : 24,
        );
        if (scrollPage) {
          return SingleChildScrollView(padding: insets, child: page);
        }
        return Padding(padding: insets, child: page);
      },
    );
  }

  Map<String, _CurrencyRateUsage> _rateUsage(List<ExchangeRateModel> rates) {
    final usage = <String, _CurrencyRateUsage>{};
    for (final rate in rates) {
      if (!rate.activo) continue;
      usage[rate.monedaIdBase] =
          (usage[rate.monedaIdBase] ?? const _CurrencyRateUsage()).addBase();
      usage[rate.monedaIdTarget] =
          (usage[rate.monedaIdTarget] ?? const _CurrencyRateUsage())
              .addTarget();
    }
    return usage;
  }
}

class _PilotFooter extends StatelessWidget {
  const _PilotFooter({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final note = Text(
      'PILOTO PULSO · DATOS REALES · PRODUCCIÓN SIN REEMPLAZAR',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: PulsoFonts.mono,
        fontSize: 9,
        letterSpacing: 0.5,
        color: tokens.muted2,
      ),
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PulsoSyncStatus(compact: true),
          const SizedBox(height: 8),
          note,
        ],
      );
    }
    return Row(
      children: [
        const PulsoSyncStatus(),
        const SizedBox(width: 10),
        Expanded(child: note),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PulsoLabel('PULSO / PILOTO · FINANZAS'),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                text: 'MONEDAS',
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
              'Administra divisas, símbolos y banderas sin perder el contexto del catálogo.',
              style: TextStyle(color: tokens.muted, fontSize: 14),
            ),
          ],
        );
        final action = PulsoPrimaryButton(
          label: 'Nueva moneda',
          icon: Icons.add,
          onPressed: onCreate,
        );
        if (constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [copy, const SizedBox(height: 14), action],
          );
        }
        return Row(
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

class _CommandBar extends StatelessWidget {
  const _CommandBar({
    required this.searchController,
    required this.searchFocus,
    required this.filter,
    required this.onSearch,
    required this.onFilter,
    required this.onRefresh,
    required this.onExport,
  });

  final TextEditingController searchController;
  final FocusNode searchFocus;
  final _CurrencyFilter filter;
  final ValueChanged<String> onSearch;
  final ValueChanged<_CurrencyFilter> onFilter;
  final VoidCallback onRefresh;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            key: const ValueKey('pulso-currency-search'),
            controller: searchController,
            focusNode: searchFocus,
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Buscar nombre, código o símbolo…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: constraints.maxWidth >= 620
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          'CTRL K',
                          style: TextStyle(
                            fontFamily: PulsoFonts.mono,
                            fontSize: 9,
                            color: tokens.muted2,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
          );
          final controls = Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _FilterButton(
                label: 'Todas',
                selected: filter == _CurrencyFilter.all,
                onTap: () => onFilter(_CurrencyFilter.all),
              ),
              _FilterButton(
                label: 'Con bandera',
                selected: filter == _CurrencyFilter.withFlag,
                onTap: () => onFilter(_CurrencyFilter.withFlag),
              ),
              _FilterButton(
                label: 'Sin bandera',
                selected: filter == _CurrencyFilter.withoutFlag,
                onTap: () => onFilter(_CurrencyFilter.withoutFlag),
              ),
              PulsoIconButton(
                icon: Icons.refresh,
                tooltip: 'Actualizar',
                onPressed: onRefresh,
              ),
              PulsoIconButton(
                icon: Icons.download_outlined,
                tooltip: 'Copiar CSV',
                onPressed: onExport,
              ),
            ],
          );
          if (constraints.maxWidth < 860) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [search, const SizedBox(height: 8), controls],
            );
          }
          return Row(
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
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
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
      ),
    );
  }
}

class _CurrencyWorkspace extends StatelessWidget {
  const _CurrencyWorkspace({
    required this.currencies,
    required this.usage,
    required this.rates,
    required this.currencyMap,
    required this.selected,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final List<CurrencyModel> currencies;
  final Map<String, _CurrencyRateUsage> usage;
  final List<ExchangeRateModel> rates;
  final Map<String, CurrencyModel> currencyMap;
  final CurrencyModel? selected;
  final _CurrencySort sort;
  final bool ascending;
  final ValueChanged<_CurrencySort> onSort;
  final ValueChanged<CurrencyModel> onSelect;
  final ValueChanged<CurrencyModel> onEdit;
  final ValueChanged<CurrencyModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final detail = _CurrencyInspector(
      key: ValueKey('currency-inspector-${selected?.id ?? 'empty'}'),
      currency: selected,
      rates: rates,
      currencyMap: currencyMap,
      onEdit: selected == null ? null : () => onEdit(selected!),
      onDelete: selected == null ? null : () => onDelete(selected!),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final list = _CurrencyList(
          currencies: currencies,
          usage: usage,
          selectedId: selected?.id,
          sort: sort,
          ascending: ascending,
          onSort: onSort,
          onSelect: onSelect,
          onEdit: onEdit,
          onDelete: onDelete,
        );
        // Detalle lateral cuando hay ancho suficiente para dos columnas.
        if (constraints.maxWidth >= 1040) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: list),
              const SizedBox(width: 12),
              SizedBox(width: 320, child: detail),
            ],
          );
        }
        // Sin selección: solo la lista ocupa el espacio.
        if (selected == null) return list;
        // Ancho insuficiente: el detalle se apila bajo la lista en una sola
        // columna (DESIGN_SYSTEM_PULSO §7). La lista es flexible y el detalle
        // tiene altura acotada con scroll propio para no desbordar.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: list),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: detail,
            ),
          ],
        );
      },
    );
  }
}

class _CurrencyList extends StatelessWidget {
  const _CurrencyList({
    required this.currencies,
    required this.usage,
    required this.selectedId,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final List<CurrencyModel> currencies;
  final Map<String, _CurrencyRateUsage> usage;
  final String? selectedId;
  final _CurrencySort sort;
  final bool ascending;
  final ValueChanged<_CurrencySort> onSort;
  final ValueChanged<CurrencyModel> onSelect;
  final ValueChanged<CurrencyModel> onEdit;
  final ValueChanged<CurrencyModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final wide = constraints.maxWidth >= 1100;
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
                        label: 'Moneda',
                        active: sort == _CurrencySort.name,
                        ascending: ascending,
                        onTap: () => onSort(_CurrencySort.name),
                      ),
                    ),
                    if (!compact) ...[
                      Expanded(
                        flex: 2,
                        child: _SortButton(
                          label: 'Código',
                          active: sort == _CurrencySort.code,
                          ascending: ascending,
                          onTap: () => onSort(_CurrencySort.code),
                        ),
                      ),
                      const Expanded(flex: 2, child: PulsoLabel('Símbolo')),
                      if (wide) ...[
                        const Expanded(flex: 2, child: PulsoLabel('Como base')),
                        const Expanded(
                          flex: 2,
                          child: PulsoLabel('Como destino'),
                        ),
                      ],
                      Expanded(
                        flex: 2,
                        child: _SortButton(
                          label: 'Cambios',
                          active: sort == _CurrencySort.rates,
                          ascending: ascending,
                          onTap: () => onSort(_CurrencySort.rates),
                        ),
                      ),
                      const Expanded(flex: 2, child: PulsoLabel('Estado')),
                      const SizedBox(width: 100),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  key: const PageStorageKey('pulso-currencies-list'),
                  itemCount: currencies.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: tokens.line.withValues(alpha: 0.75),
                  ),
                  itemBuilder: (context, index) {
                    final currency = currencies[index];
                    return _CurrencyRow(
                      key: ValueKey(currency.id),
                      currency: currency,
                      usage: usage[currency.id] ?? const _CurrencyRateUsage(),
                      selected: selectedId == currency.id,
                      compact: compact,
                      wide: wide,
                      onSelect: () => onSelect(currency),
                      onEdit: () => onEdit(currency),
                      onDelete: () => onDelete(currency),
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
                  '${currencies.length} resultados · selección y scroll preservados',
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
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({
    super.key,
    required this.currency,
    required this.usage,
    required this.selected,
    required this.compact,
    required this.wide,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final CurrencyModel currency;
  final _CurrencyRateUsage usage;
  final bool selected;
  final bool compact;
  final bool wide;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final symbol = currency.symbol?.trim().isNotEmpty == true
        ? currency.symbol!.trim()
        : '—';
    final rates = usage.total;
    final status = currency.flagImage?.isNotEmpty != true
        ? 'Sin bandera'
        : rates > 0
        ? 'En uso'
        : 'Disponible';
    return Material(
      color: selected ? tokens.accentSoftStrong : Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        child: Container(
          constraints: const BoxConstraints(minHeight: 66),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? tokens.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(11, 9, 12, 9),
          child: Row(
            children: [
              PulsoFlag(code: currency.code, base64String: currency.flagImage),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      currency.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: tokens.chalk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      compact
                          ? '${currency.code.toUpperCase()} · $symbol · $rates cambios'
                          : rates > 0
                          ? 'Activa en operaciones'
                          : 'Sin tipos de cambio',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: PulsoFonts.mono,
                        fontSize: 9.5,
                        color: rates > 0 ? tokens.success : tokens.muted2,
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                Expanded(
                  flex: 2,
                  child: Text(
                    currency.code.toUpperCase(),
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontWeight: FontWeight.w600,
                      color: tokens.chalkDim,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    symbol,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontWeight: FontWeight.w600,
                      color: tokens.chalkDim,
                    ),
                  ),
                ),
                if (wide) ...[
                  Expanded(
                    flex: 2,
                    child: _UsageValue(value: usage.asBase, label: 'base'),
                  ),
                  Expanded(
                    flex: 2,
                    child: _UsageValue(value: usage.asTarget, label: 'destino'),
                  ),
                ],
                Expanded(
                  flex: 2,
                  child: Text(
                    '$rates',
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      color: rates > 0 ? tokens.success : tokens.muted,
                    ),
                  ),
                ),
                Expanded(flex: 2, child: _CurrencyStatus(label: status)),
                SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      PulsoIconButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Editar ${currency.name}',
                        onPressed: onEdit,
                      ),
                      const SizedBox(width: 4),
                      PulsoIconButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Eliminar ${currency.name}',
                        danger: true,
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ),
              ] else
                PopupMenuButton<String>(
                  tooltip: 'Acciones de ${currency.name}',
                  color: tokens.surface,
                  iconColor: tokens.muted,
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

class _UsageValue extends StatelessWidget {
  const _UsageValue({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Text.rich(
      TextSpan(
        text: '$value',
        children: [
          TextSpan(
            text: '  $label',
            style: TextStyle(color: tokens.muted2, fontSize: 9),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: PulsoFonts.mono,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: value > 0 ? tokens.success : tokens.muted,
      ),
    );
  }
}

class _CurrencyStatus extends StatelessWidget {
  const _CurrencyStatus({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = label == 'En uso'
        ? tokens.success
        : label == 'Sin bandera'
        ? tokens.warning
        : tokens.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, color: color),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.35,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _CurrencyInspector extends StatefulWidget {
  const _CurrencyInspector({
    super.key,
    required this.currency,
    required this.rates,
    required this.currencyMap,
    required this.onEdit,
    required this.onDelete,
  });

  final CurrencyModel? currency;
  final List<ExchangeRateModel> rates;
  final Map<String, CurrencyModel> currencyMap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<_CurrencyInspector> createState() => _CurrencyInspectorState();
}

class _CurrencyInspectorState extends State<_CurrencyInspector> {
  bool _showRates = false;

  @override
  void didUpdateWidget(covariant _CurrencyInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currency?.id != widget.currency?.id) {
      _showRates = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.currency;
    final associated = currency == null
        ? const <ExchangeRateModel>[]
        : widget.rates
              .where(
                (rate) =>
                    rate.monedaIdBase == currency.id ||
                    rate.monedaIdTarget == currency.id,
              )
              .toList();
    final activeCount = associated.where((rate) => rate.activo).length;

    if (_showRates && currency != null) {
      return _CurrencyRatesPanel(
        currency: currency,
        rates: associated,
        currencyMap: widget.currencyMap,
        onBack: () => setState(() => _showRates = false),
      );
    }

    return _CurrencyDetail(
      currency: currency,
      activeRates: activeCount,
      associatedRates: associated.length,
      onExploreRates: associated.isEmpty
          ? null
          : () => setState(() => _showRates = true),
      onEdit: widget.onEdit,
      onDelete: widget.onDelete,
    );
  }
}

class _CurrencyRatesPanel extends StatelessWidget {
  const _CurrencyRatesPanel({
    required this.currency,
    required this.rates,
    required this.currencyMap,
    required this.onBack,
  });

  final CurrencyModel currency;
  final List<ExchangeRateModel> rates;
  final Map<String, CurrencyModel> currencyMap;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final active = rates.where((rate) => rate.activo).length;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): onBack,
      },
      child: Focus(
        autofocus: true,
        child: PulsoPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PulsoSecondaryButton(
                      label: 'Volver a moneda',
                      icon: Icons.arrow_back,
                      onPressed: onBack,
                    ),
                    const SizedBox(height: 18),
                    const PulsoLabel('Relaciones cambiarias'),
                    const SizedBox(height: 8),
                    Text(
                      'TIPOS DE CAMBIO / ${currency.code.toUpperCase()}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${rates.length} relaciones · $active activas',
                      style: TextStyle(
                        fontFamily: PulsoFonts.mono,
                        fontSize: 10,
                        color: tokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: tokens.line),
              Expanded(
                child: rates.isEmpty
                    ? const PulsoStateView(
                        kind: PulsoStateKind.empty,
                        message: 'Esta moneda no tiene tipos de cambio.',
                      )
                    : ListView.separated(
                        key: ValueKey('rates-for-${currency.id}'),
                        padding: EdgeInsets.zero,
                        itemCount: rates.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: tokens.line),
                        itemBuilder: (context, index) => _ExchangeRateRow(
                          selectedCurrency: currency,
                          rate: rates[index],
                          currencyMap: currencyMap,
                        ),
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: tokens.line)),
                ),
                child: Text(
                  'ALT + ← PARA VOLVER',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 9,
                    color: tokens.muted2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExchangeRateRow extends StatelessWidget {
  const _ExchangeRateRow({
    required this.selectedCurrency,
    required this.rate,
    required this.currencyMap,
  });

  final CurrencyModel selectedCurrency;
  final ExchangeRateModel rate;
  final Map<String, CurrencyModel> currencyMap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final base = rate.monedaBase ?? currencyMap[rate.monedaIdBase];
    final target = rate.monedaTarget ?? currencyMap[rate.monedaIdTarget];
    final baseCode = base?.code.toUpperCase() ?? 'BASE';
    final targetCode = target?.code.toUpperCase() ?? 'DESTINO';
    final isBase = rate.monedaIdBase == selectedCurrency.id;
    final statusColor = rate.activo ? tokens.success : tokens.muted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$baseCode  →  $targetCode',
                  style: TextStyle(
                    fontFamily: PulsoFonts.display,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: tokens.chalk,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                color: tokens.accentSoft,
                child: Text(
                  isBase ? 'COMO BASE' : 'COMO DESTINO',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: tokens.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1 $baseCode = ${_formatExchangeRate(rate.exchangeRate)} $targetCode',
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tokens.chalkDim,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(width: 6, height: 6, color: statusColor),
              const SizedBox(width: 7),
              Text(
                rate.activo ? 'ACTIVO' : 'INACTIVO',
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatExchangeRate(double value) {
  final fixed = value.toStringAsFixed(6);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

class _CurrencyDetail extends StatelessWidget {
  const _CurrencyDetail({
    required this.currency,
    required this.activeRates,
    required this.associatedRates,
    required this.onExploreRates,
    required this.onEdit,
    required this.onDelete,
  });

  final CurrencyModel? currency;
  final int activeRates;
  final int associatedRates;
  final VoidCallback? onExploreRates;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final item = currency;
    if (item == null) {
      return const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.empty,
          message: 'Selecciona una moneda para ver su detalle.',
        ),
      );
    }

    return PulsoPanel(
      padding: const EdgeInsets.all(20),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              const PulsoLabel('Detalle seleccionado'),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PulsoFlag(
                    code: item.code,
                    base64String: item.flagImage,
                    width: 84,
                    height: 56,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.symbol?.isNotEmpty == true ? item.symbol! : '—',
                          style: TextStyle(
                            fontFamily: PulsoFonts.display,
                            fontSize: 42,
                            height: 0.9,
                            fontWeight: FontWeight.w800,
                            color: tokens.accent,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _DetailLine(label: 'Código ISO', value: item.code.toUpperCase()),
              _DetailLine(label: 'Cambios activos', value: '$activeRates'),
              _DetailLine(
                label: 'Bandera',
                value: item.flagImage?.isNotEmpty == true
                    ? 'Asignada'
                    : 'Pendiente',
              ),
            ]),
          ),
          // El pie de acciones se mantiene visible cuando hay espacio y
          // se vuelve alcanzable con scroll cuando la ventana se reduce.
          SliverFillRemaining(
            hasScrollBody: false,
            fillOverscroll: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 18),
                PulsoSecondaryButton(
                  label: associatedRates == 0
                      ? 'Sin tipos de cambio'
                      : 'Ver tipos de cambio ($associatedRates)',
                  icon: Icons.swap_horiz,
                  onPressed: onExploreRates,
                ),
                const SizedBox(height: 8),
                PulsoPrimaryButton(
                  label: 'Editar moneda',
                  icon: Icons.edit_outlined,
                  onPressed: onEdit,
                ),
                const SizedBox(height: 8),
                PulsoSecondaryButton(
                  label: 'Eliminar',
                  icon: Icons.delete_outline,
                  danger: true,
                  onPressed: onDelete,
                ),
                const SizedBox(height: 14),
                Text(
                  item.id,
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
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: [
          Expanded(child: PulsoLabel(label)),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tokens.chalkDim,
            ),
          ),
        ],
      ),
    );
  }
}
