import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../configuration/data/models/payment_type_model.dart';
import '../../../configuration/presentation/state/payment_type_notifier.dart';
import '../../../dashboard/presentation/state/dashboard_nav_provider.dart';
import '../../data/models/account_model.dart';
import '../state/account_notifier.dart';
import '../widgets/account_pulso_form.dart';

enum _AccountFilter { all, linked, unlinked }

enum _AccountSort { name, currency }

String _shortAccountId(String id) {
  if (id.length <= 8) return id;
  return '${id.substring(0, 4)}…${id.substring(id.length - 4)}';
}

String _currencyLabel(AccountModel account) =>
    account.currencyCode?.toUpperCase() ?? _shortAccountId(account.currencyId);

class AccountsPulsoView extends ConsumerStatefulWidget {
  const AccountsPulsoView({super.key});

  @override
  ConsumerState<AccountsPulsoView> createState() => _AccountsPulsoViewState();
}

class _AccountsPulsoViewState extends ConsumerState<AccountsPulsoView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  String? _selectedId;
  _AccountFilter _filter = _AccountFilter.all;
  _AccountSort _sort = _AccountSort.name;
  bool _ascending = true;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<AccountModel> _visible(List<AccountModel> all) {
    final query = _query.trim().toLowerCase();
    final result = all.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          (item.currencyCode ?? '').toLowerCase().contains(query) ||
          (item.currencyName ?? '').toLowerCase().contains(query) ||
          (item.currencySymbol ?? '').toLowerCase().contains(query);
      final matchesFilter = switch (_filter) {
        _AccountFilter.all => true,
        _AccountFilter.linked => item.paymentTypeId != null,
        _AccountFilter.unlinked => item.paymentTypeId == null,
      };
      return matchesQuery && matchesFilter;
    }).toList();
    int compare(AccountModel a, AccountModel b) {
      final value = switch (_sort) {
        _AccountSort.name => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
        _AccountSort.currency => _currencyLabel(
          a,
        ).toLowerCase().compareTo(_currencyLabel(b).toLowerCase()),
      };
      return _ascending ? value : -value;
    }

    result.sort(compare);
    return result;
  }

  void _setSort(_AccountSort sort) {
    setState(() {
      if (_sort == sort) {
        _ascending = !_ascending;
      } else {
        _sort = sort;
        _ascending = true;
      }
    });
  }

  Future<void> _openForm([AccountModel? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AccountPulsoForm(
        account: item,
        onSubmit: (name, currencyId, paymentTypeId) async {
          final notifier = ref.read(accountProvider.notifier);
          if (item == null) {
            await notifier.createAccount(
              name,
              currencyId,
              paymentTypeId: paymentTypeId,
            );
          } else {
            await notifier.updateAccount(
              item.id,
              name,
              currencyId,
              paymentTypeId: paymentTypeId,
            );
          }
        },
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          item == null
              ? 'Nueva cuenta creada.'
              : '“${item.name}” fue actualizada.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(AccountModel item) async {
    final tokens = PulsoTokens.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PulsoThemeScope(
        child: AlertDialog(
          title: const Text('Eliminar cuenta'),
          content: Text(
            'Se eliminará “${item.name}” del plan de cuentas. '
            'La operación puede fallar si existen movimientos relacionados.',
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
      await ref.read(accountProvider.notifier).deleteAccount(item.id);
      if (!mounted) return;
      if (_selectedId == item.id) setState(() => _selectedId = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('“${item.name}” fue eliminada.')));
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
    AccountModel item,
    Map<String, String> paymentTypeNames,
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
            child: _AccountDetail(
              item: item,
              paymentTypeNames: paymentTypeNames,
              onEdit: () {
                Navigator.of(dialogContext).pop();
                _openForm(item);
              },
              onDelete: () {
                Navigator.of(dialogContext).pop();
                _confirmDelete(item);
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
    final state = ref.watch(accountProvider);
    final all = state.value ?? const <AccountModel>[];
    final paymentTypeNames = <String, String>{
      for (final type
          in ref.watch(paymentTypeNotifierProvider).value ??
              const <PaymentTypeModel>[])
        type.id: type.name,
    };
    final visible = _visible(all);
    final currencyCounts = <String, int>{};
    for (final item in all) {
      final label = _currencyLabel(item);
      currencyCounts[label] = (currencyCounts[label] ?? 0) + 1;
    }
    String? mainCurrency;
    for (final entry in currencyCounts.entries) {
      if (mainCurrency == null ||
          entry.value > (currencyCounts[mainCurrency] ?? 0)) {
        mainCurrency = entry.key;
      }
    }
    final linked = all.where((item) => item.paymentTypeId != null).length;
    AccountModel? selected;
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
              message: 'Cargando el plan de cuentas…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message: 'No se pudo cargar el plan de cuentas.\n$error',
              onRetry: () => ref.invalidate(accountProvider),
            ),
          ),
          data: (_) => visible.isEmpty
              ? PulsoPanel(
                  child: PulsoStateView(
                    kind: PulsoStateKind.empty,
                    message: all.isEmpty
                        ? 'El plan está vacío. Asienta la primera cuenta.'
                        : 'Ninguna cuenta coincide con la búsqueda.',
                  ),
                )
              : _AccountWorkspace(
                  items: visible,
                  paymentTypeNames: paymentTypeNames,
                  selected: workspaceWide ? selected : null,
                  sort: _sort,
                  ascending: _ascending,
                  onSort: _setSort,
                  onSelect: (item) {
                    if (workspaceWide) {
                      setState(() => _selectedId = item.id);
                    } else {
                      _showDetail(context, item, paymentTypeNames);
                    }
                  },
                  onEdit: _openForm,
                  onDelete: _confirmDelete,
                  onCurrencies: _goToCurrencies,
                ),
        );
        final page = Column(
          mainAxisSize: scrollPage ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AccountHeader(onCreate: () => _openForm()),
            const SizedBox(height: 14),
            PulsoMetricStrip(
              metrics: [
                PulsoMetricData(
                  value: '${all.length}',
                  label: 'Cuentas',
                  note: 'plan completo',
                  emphasis: true,
                ),
                PulsoMetricData(
                  value: '${currencyCounts.length}',
                  label: 'Divisas',
                  note: 'una divisa por cuenta',
                ),
                PulsoMetricData(
                  value: '$linked',
                  label: 'Con tipo de pago',
                  note: '${all.length - linked} sin asociar',
                  warning: all.isNotEmpty && linked < all.length,
                ),
                PulsoMetricData(
                  value: mainCurrency == null
                      ? '—'
                      : '${currencyCounts[mainCurrency]}',
                  label: 'Divisa principal',
                  note: mainCurrency ?? 'sin cuentas todavía',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _AccountCommand(
              controller: _searchController,
              focusNode: _searchFocus,
              filter: _filter,
              onSearch: (value) => setState(() => _query = value),
              onFilter: (value) => setState(() => _filter = value),
              onRefresh: () => ref.invalidate(accountProvider),
            ),
            const SizedBox(height: 12),
            if (scrollPage)
              SizedBox(height: 360, child: catalog)
            else
              Expanded(child: catalog),
            const SizedBox(height: 8),
            const _AccountFooter(),
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

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.onCreate});
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
                text: 'PLAN DE CUENTAS',
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
              'Organiza dónde se asienta cada cobro y en qué divisa opera.',
              style: TextStyle(color: tokens.muted, fontSize: 14),
            ),
          ],
        );
        final action = PulsoPrimaryButton(
          label: 'Nueva cuenta',
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

class _AccountCommand extends StatelessWidget {
  const _AccountCommand({
    required this.controller,
    required this.focusNode,
    required this.filter,
    required this.onSearch,
    required this.onFilter,
    required this.onRefresh,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final _AccountFilter filter;
  final ValueChanged<String> onSearch;
  final ValueChanged<_AccountFilter> onFilter;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return PulsoPanel(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            key: const ValueKey('pulso-account-search'),
            controller: controller,
            focusNode: focusNode,
            onChanged: onSearch,
            decoration: const InputDecoration(
              hintText: 'Buscar cuenta, divisa o símbolo…',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          );
          final controls = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _FilterButton(
                label: 'Todas',
                selected: filter == _AccountFilter.all,
                onTap: () => onFilter(_AccountFilter.all),
              ),
              _FilterButton(
                label: 'Con tipo de pago',
                selected: filter == _AccountFilter.linked,
                onTap: () => onFilter(_AccountFilter.linked),
              ),
              _FilterButton(
                label: 'Sin tipo',
                selected: filter == _AccountFilter.unlinked,
                onTap: () => onFilter(_AccountFilter.unlinked),
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

class _AccountWorkspace extends StatelessWidget {
  const _AccountWorkspace({
    required this.items,
    required this.paymentTypeNames,
    required this.selected,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onCurrencies,
  });
  final List<AccountModel> items;
  final Map<String, String> paymentTypeNames;
  final AccountModel? selected;
  final _AccountSort sort;
  final bool ascending;
  final ValueChanged<_AccountSort> onSort;
  final ValueChanged<AccountModel> onSelect;
  final ValueChanged<AccountModel> onEdit;
  final ValueChanged<AccountModel> onDelete;
  final VoidCallback onCurrencies;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final list = _AccountList(
          items: items,
          paymentTypeNames: paymentTypeNames,
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
              child: _AccountDetail(
                item: selected,
                paymentTypeNames: paymentTypeNames,
                onEdit: selected == null ? null : () => onEdit(selected!),
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

class _AccountList extends StatelessWidget {
  const _AccountList({
    required this.items,
    required this.paymentTypeNames,
    required this.selectedId,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });
  final List<AccountModel> items;
  final Map<String, String> paymentTypeNames;
  final String? selectedId;
  final _AccountSort sort;
  final bool ascending;
  final ValueChanged<_AccountSort> onSort;
  final ValueChanged<AccountModel> onSelect;
  final ValueChanged<AccountModel> onEdit;
  final ValueChanged<AccountModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;
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
                      flex: 5,
                      child: _SortButton(
                        label: 'Cuenta',
                        active: sort == _AccountSort.name,
                        ascending: ascending,
                        onTap: () => onSort(_AccountSort.name),
                      ),
                    ),
                    if (!compact) ...[
                      Expanded(
                        flex: 3,
                        child: _SortButton(
                          label: 'Divisa',
                          active: sort == _AccountSort.currency,
                          ascending: ascending,
                          onTap: () => onSort(_AccountSort.currency),
                        ),
                      ),
                      const Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PulsoLabel('Tipo de pago'),
                        ),
                      ),
                      const SizedBox(width: 100),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  key: const PageStorageKey('pulso-accounts-list'),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: tokens.line),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _AccountRow(
                      key: ValueKey(item.id),
                      item: item,
                      paymentTypeName: item.paymentTypeId == null
                          ? null
                          : paymentTypeNames[item.paymentTypeId],
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
                  '${items.length} resultados · una divisa por cuenta',
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

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    super.key,
    required this.item,
    required this.paymentTypeName,
    required this.selected,
    required this.compact,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });
  final AccountModel item;
  final String? paymentTypeName;
  final bool selected;
  final bool compact;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final currency = _currencyLabel(item);
    final symbol = item.currencySymbol?.isNotEmpty == true
        ? item.currencySymbol!
        : '¤';
    final linked = item.paymentTypeId != null;
    final typeLabel = !linked
        ? '—'
        : paymentTypeName ?? _shortAccountId(item.paymentTypeId!);
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
                code: item.currencyCode ?? '¤¤',
                base64String: item.currencyImage == null
                    ? null
                    : base64Encode(item.currencyImage!),
                width: 33,
                height: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: tokens.chalk,
                      ),
                    ),
                    if (compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$currency · $symbol · $typeLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 9.5,
                          color: tokens.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!compact) ...[
                Expanded(
                  flex: 3,
                  child: Text(
                    '$currency · $symbol',
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
                    typeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      color: linked ? tokens.chalkDim : tokens.muted,
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      PulsoIconButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Editar ${item.name}',
                        onPressed: onEdit,
                      ),
                      const SizedBox(width: 4),
                      PulsoIconButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Eliminar ${item.name}',
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

class _AccountDetail extends StatelessWidget {
  const _AccountDetail({
    required this.item,
    required this.paymentTypeNames,
    required this.onEdit,
    required this.onDelete,
    required this.onCurrencies,
  });
  final AccountModel? item;
  final Map<String, String> paymentTypeNames;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback onCurrencies;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final account = item;
    if (account == null) {
      return const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.empty,
          message: 'Selecciona una cuenta para ver su detalle.',
        ),
      );
    }
    final symbol = account.currencySymbol?.isNotEmpty == true
        ? account.currencySymbol!
        : '¤';
    final typeLabel = account.paymentTypeId == null
        ? '—'
        : paymentTypeNames[account.paymentTypeId] ??
              _shortAccountId(account.paymentTypeId!);
    return PulsoPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PulsoLabel('Detalle seleccionado'),
          const SizedBox(height: 18),
          Text(
            symbol,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.display,
              fontSize: 48,
              height: 0.9,
              fontWeight: FontWeight.w800,
              color: tokens.accent,
            ),
          ),
          const SizedBox(height: 9),
          Text(account.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 22),
          _DetailLine(label: 'Divisa', value: _currencyLabel(account)),
          _DetailLine(label: 'Símbolo', value: symbol),
          _DetailLine(label: 'Tipo de pago', value: typeLabel),
          const Spacer(),
          PulsoPrimaryButton(
            label: 'Editar cuenta',
            icon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
          const SizedBox(height: 8),
          PulsoSecondaryButton(
            label: 'Ver monedas',
            icon: Icons.currency_exchange_outlined,
            onPressed: onCurrencies,
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
            account.id,
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
      padding: const EdgeInsets.symmetric(vertical: 11),
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

class _AccountFooter extends StatelessWidget {
  const _AccountFooter();
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Row(
      children: [
        const PulsoSyncStatus(compact: true),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'PULSO · PLAN DE CUENTAS · DATOS REALES',
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
