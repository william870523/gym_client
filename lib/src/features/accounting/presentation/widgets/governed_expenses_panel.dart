import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../financials/presentation/state/account_notifier.dart';
import '../../../financials/presentation/state/currency_notifier.dart';
import '../../data/models/accounting_models.dart';
import '../../data/repositories/accounting_repository.dart';
import '../state/accounting_providers.dart';
import 'recurring_expenses_panel.dart';

/// Diálogo de formulario con la gramática PULSO (banda de acento, etiqueta
/// de sección, título condensado y acciones enmarcadas). Sustituye a los
/// AlertDialog Material del módulo de gastos.
class _PulsoFormDialog extends StatelessWidget {
  const _PulsoFormDialog({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.onConfirm,
    required this.child,
    this.danger = false,
  });

  final String title;
  final String subtitle;
  final String confirmLabel;
  final Future<void> Function() onConfirm;
  final Widget child;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: screen.height - 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 4, color: danger ? tokens.danger : tokens.accent),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PulsoLabel('PULSO · CONTABILIDAD'),
                  const SizedBox(height: 8),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: tokens.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: tokens.line),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                child: child,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PulsoSecondaryButton(
                    label: 'Cancelar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  PulsoPrimaryButton(
                    label: confirmLabel,
                    onPressed: () => onConfirm(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _errorText(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
  }
  return 'No se pudo completar la operación. Inténtelo de nuevo.';
}

String _currencyCode(String? value) {
  final code = value?.trim().toUpperCase() ?? '';
  return code.isEmpty ? 'SIN MONEDA' : code;
}

String _moneyWithCurrency(String amount, String? currencyCode) =>
    '$amount ${_currencyCode(currencyCode)}';

final _paymentInstantFormat = DateFormat('dd/MM/yyyy HH:mm');

class GovernedExpensesPanel extends ConsumerStatefulWidget {
  const GovernedExpensesPanel({
    super.key,
    this.initialMonth,
    this.onMonthChanged,
    required this.onBack,
  });

  final String? initialMonth;
  final ValueChanged<String>? onMonthChanged;
  final VoidCallback onBack;

  @override
  ConsumerState<GovernedExpensesPanel> createState() =>
      _GovernedExpensesPanelState();
}

class _GovernedExpensesPanelState extends ConsumerState<GovernedExpensesPanel> {
  late final String? _month = widget.initialMonth;
  final _search = TextEditingController();
  String _query = '';
  bool _recurringView = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(governedExpensesProvider(_month));
    ref.invalidate(governedExpenseCategoriesProvider);
    ref.invalidate(governedExpenseSuppliersProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (_recurringView) {
      return RecurringExpensesPanel(
        initialMonth: _month,
        onBack: () => setState(() => _recurringView = false),
        onGenerated: _refresh,
      );
    }
    return ref
        .watch(governedExpensesProvider(_month))
        .when(
          loading: () => const PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.loading,
              message: 'Cargando gastos devengados gobernados…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message:
                  'No se pudieron cargar los gastos devengados.\n${_errorText(error)}',
              onRetry: _refresh,
            ),
          ),
          data: (report) => _buildContent(context, report),
        );
  }

  Widget _buildContent(
    BuildContext context,
    GovernedExpensesReportModel report,
  ) {
    final tokens = PulsoTokens.of(context);
    final categories = ref.watch(governedExpenseCategoriesProvider).value ?? [];
    final suppliers = ref.watch(governedExpenseSuppliersProvider).value ?? [];
    final query = _query.trim().toLowerCase();
    final filteredByCurrency =
        <GovernedExpenseCurrencyModel, List<GastoGobernadoModel>>{};
    for (final currency in report.monedas) {
      final expenses = currency.gastos
          .where((expense) {
            if (query.isEmpty) return true;
            return expense.descripcion.toLowerCase().contains(query) ||
                (expense.categoriaNombre?.toLowerCase().contains(query) ??
                    false) ||
                (expense.proveedorNombre?.toLowerCase().contains(query) ??
                    false);
          })
          .toList(growable: false);
      if (expenses.isNotEmpty) filteredByCurrency[currency] = expenses;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        return SingleChildScrollView(
          key: const Key('governed-expenses-scroll'),
          padding: EdgeInsets.all(compact ? 12 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(
                context,
                compact: compact,
                reportMonth: report.mes,
                categories: categories,
                suppliers: suppliers,
              ),
              const SizedBox(height: 20),
              if (report.monedas.isEmpty)
                const PulsoPanel(
                  child: PulsoStateView(
                    kind: PulsoStateKind.empty,
                    message: 'El informe no contiene monedas para este mes.',
                  ),
                )
              else
                for (var index = 0; index < report.monedas.length; index++) ...[
                  _buildCurrencySummary(context, report.monedas[index], report),
                  if (index != report.monedas.length - 1)
                    const SizedBox(height: 12),
                ],
              const SizedBox(height: 20),
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  labelText: 'Buscar por descripción, categoría o proveedor',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PulsoSecondaryButton(
                    label: 'Categorías',
                    icon: Icons.category_outlined,
                    onPressed: () =>
                        _showCategoryManagementDialog(context, categories),
                  ),
                  PulsoSecondaryButton(
                    label: 'Proveedores',
                    icon: Icons.business_outlined,
                    onPressed: () =>
                        _showSupplierManagementDialog(context, suppliers),
                  ),
                  PulsoSecondaryButton(
                    key: const Key('governed-expenses-recurring-action'),
                    label: 'Recurrentes',
                    icon: Icons.event_repeat_outlined,
                    onPressed: () => setState(() => _recurringView = true),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (filteredByCurrency.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: Text(
                    'No se encontraron gastos devengados registrados en el periodo.',
                    style: TextStyle(color: tokens.muted),
                  ),
                )
              else
                for (final entry in filteredByCurrency.entries) ...[
                  PulsoLabel(
                    '${_currencyCode(entry.key.codigoMoneda)} · '
                    '${entry.value.length} GASTO${entry.value.length == 1 ? '' : 'S'}',
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: entry.value.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildExpenseRow(context, entry.value[index]),
                  ),
                  const SizedBox(height: 18),
                ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required bool compact,
    required String reportMonth,
    required List<GastoCategoriaModel> categories,
    required List<GastoProveedorModel> suppliers,
  }) {
    final tokens = PulsoTokens.of(context);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GASTOS DEVENGADOS GOBERNADOS',
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: tokens.accent,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Devengo por pertenencia y pagos de tesorería, siempre separados por moneda',
          style: TextStyle(fontSize: 12, color: tokens.muted),
        ),
      ],
    );
    final create = PulsoPrimaryButton(
      label: 'Nuevo gasto',
      icon: Icons.add,
      onPressed: () =>
          _showCreateExpenseDialog(context, categories, suppliers, reportMonth),
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                tooltip: 'Regresar',
              ),
              const SizedBox(width: 4),
              Expanded(child: title),
            ],
          ),
          const SizedBox(height: 12),
          create,
        ],
      );
    }
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
          tooltip: 'Regresar',
        ),
        const SizedBox(width: 8),
        Expanded(child: title),
        const SizedBox(width: 16),
        create,
      ],
    );
  }

  Widget _buildCurrencySummary(
    BuildContext context,
    GovernedExpenseCurrencyModel currency,
    GovernedExpensesReportModel report,
  ) {
    final code = _currencyCode(currency.codigoMoneda);
    return Column(
      key: Key('governed-expenses-currency-$code'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PulsoLabel('MONEDA · $code'),
        const SizedBox(height: 8),
        PulsoMetricStrip(
          metrics: [
            PulsoMetricData(
              value: _moneyWithCurrency(currency.devengadoMes, code),
              label: 'DEVENGADO DEL MES',
              note: report.mes,
            ),
            PulsoMetricData(
              value: _moneyWithCurrency(currency.pagadoMes, code),
              label: 'PAGADO EN EL MES',
              note: 'Salida ocurrida en el periodo',
            ),
            PulsoMetricData(
              value: _moneyWithCurrency(currency.pagadoAcumulado, code),
              label: 'PAGADO AL CORTE',
              note: report.fechaNegocio.isEmpty
                  ? 'Corte del informe'
                  : report.fechaNegocio,
            ),
            PulsoMetricData(
              value: _moneyWithCurrency(currency.pendientePago, code),
              label: 'PENDIENTE DE PAGO',
              note: 'Sin convertir ni sumar monedas',
              emphasis: currency.pendientePago != '0.00',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExpenseRow(BuildContext context, GastoGobernadoModel item) {
    final tokens = PulsoTokens.of(context);

    Color statusColor;
    switch (item.estado) {
      case 'PAGADO':
        statusColor = tokens.success;
        break;
      case 'PARCIAL':
        statusColor = tokens.warning;
        break;
      case 'ANULADO':
        statusColor = tokens.muted;
        break;
      default:
        statusColor = tokens.accent;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final badges = Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _buildBadge(
              item.estado,
              foreground: statusColor,
              background: statusColor.withValues(alpha: 0.12),
              border: statusColor.withValues(alpha: 0.5),
            ),
            if (item.categoriaNombre != null)
              _buildBadge(
                item.categoriaNombre!.toUpperCase(),
                foreground: tokens.muted,
                background: tokens.floor,
                border: tokens.line,
              ),
          ],
        );
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            badges,
            const SizedBox(height: 10),
            Text(
              item.descripcion,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: tokens.chalk,
              ),
            ),
            if (item.proveedorNombre != null) ...[
              const SizedBox(height: 2),
              Text(
                'Proveedor: ${item.proveedorNombre}',
                style: TextStyle(fontSize: 11, color: tokens.muted),
              ),
            ],
            if (item.periodoPertenenciaMes.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Pertenece a ${item.periodoPertenenciaMes}',
                style: TextStyle(fontSize: 11, color: tokens.muted2),
              ),
            ],
          ],
        );
        final amounts = Column(
          crossAxisAlignment: compact
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            Text(
              _moneyWithCurrency(item.monto, item.codigoMoneda),
              style: TextStyle(
                fontFamily: PulsoFonts.display,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: tokens.chalk,
              ),
            ),
            if (item.pagadoAcumulado != '0.00' &&
                item.pagadoAcumulado != '0') ...[
              const SizedBox(height: 2),
              Text(
                'Pagado: ${_moneyWithCurrency(item.pagadoAcumulado, item.codigoMoneda)}',
                style: TextStyle(fontSize: 11, color: tokens.success),
              ),
            ],
          ],
        );
        final payButton = item.estado != 'PAGADO' && item.estado != 'ANULADO'
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.accent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _showPayExpenseDialog(context, item),
                child: const Text('Pagar'),
              )
            : null;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.raised,
            border: Border.all(color: tokens.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact) ...[
                details,
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: amounts),
                    if (payButton != null) ...[
                      const SizedBox(width: 12),
                      payButton,
                    ],
                  ],
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 16),
                    amounts,
                    if (payButton != null) ...[
                      const SizedBox(width: 16),
                      payButton,
                    ],
                  ],
                ),
              if (item.aplicaciones.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 4),
                Text(
                  'HISTORIAL DE PAGOS',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: tokens.muted,
                  ),
                ),
                const SizedBox(height: 4),
                for (final application in item.aplicaciones)
                  _buildApplicationRow(context, item, application),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadge(
    String label, {
    required Color foreground,
    required Color background,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: PulsoFonts.mono,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  Widget _buildApplicationRow(
    BuildContext context,
    GastoGobernadoModel expense,
    GastoGobernadoAplicacionModel application,
  ) {
    final tokens = PulsoTokens.of(context);
    final reversed = application.estado == 'REVERSADA';
    final appliedAt = formatInZone(
      application.aplicadaAt,
      appClock.gymTimezone,
      _paymentInstantFormat,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            reversed ? Icons.undo : Icons.check_circle_outline,
            size: 14,
            color: reversed ? tokens.muted : tokens.success,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${_moneyWithCurrency(application.montoAplicado, expense.codigoMoneda)} · '
              '$appliedAt (${application.estado})',
              style: TextStyle(
                fontSize: 11,
                color: reversed ? tokens.muted : tokens.chalk,
                decoration: reversed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (!reversed)
            TextButton(
              onPressed: () => _showReversePaymentDialog(
                context,
                application,
                expense.codigoMoneda,
              ),
              child: Text(
                'Reversar',
                style: TextStyle(fontSize: 11, color: tokens.accent),
              ),
            ),
        ],
      ),
    );
  }

  void _showCreateExpenseDialog(
    BuildContext context,
    List<GastoCategoriaModel> categories,
    List<GastoProveedorModel> suppliers,
    String reportMonth,
  ) {
    final descCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    final gymNow = toGymWallClock(appClock.nowUtc(), appClock.gymTimezone);
    final currentGymMonth = DateFormat('yyyy-MM').format(gymNow);
    final mesCtrl = TextEditingController(
      text: _month ?? (reportMonth.isNotEmpty ? reportMonth : currentGymMonth),
    );
    final refCtrl = TextEditingController();
    final currencies = ref.read(currencyProvider).value ?? const [];
    String? categoryId = categories.isNotEmpty
        ? categories.first.categoriaId
        : null;
    String? supplierId;
    String? currencyId = currencies.isNotEmpty ? currencies.first.id : null;

    showDialog(
      context: context,
      builder: (dialogCtx) => PulsoThemeScope(
        child: StatefulBuilder(
          builder: (context, setLocal) => _PulsoFormDialog(
            title: 'NUEVO GASTO',
            subtitle:
                'Gasto devengado por su mes de pertenencia; el pago sale luego de tesorería.',
            confirmLabel: 'Guardar',
            onConfirm: () async {
              if (categoryId == null ||
                  descCtrl.text.isEmpty ||
                  montoCtrl.text.isEmpty ||
                  currencyId == null) {
                return;
              }
              final navigator = Navigator.of(dialogCtx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref
                    .read(accountingRepositoryProvider)
                    .createGovernedExpense({
                      'categoria_id': categoryId,
                      'proveedor_id': supplierId,
                      'moneda_id': currencyId,
                      'descripcion': descCtrl.text,
                      'monto': montoCtrl.text,
                      'periodo_pertenencia_mes': mesCtrl.text,
                      'comprobante_referencia': refCtrl.text.isNotEmpty
                          ? refCtrl.text
                          : null,
                    });
                navigator.pop();
                _refresh();
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(_errorText(e))));
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Categoría *',
                    isDense: true,
                  ),
                  items: categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.categoriaId,
                          child: Text(c.nombre),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setLocal(() => categoryId = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: supplierId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Proveedor (opcional)',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Sin proveedor'),
                    ),
                    ...suppliers.map(
                      (s) => DropdownMenuItem(
                        value: s.proveedorId,
                        child: Text(s.nombre),
                      ),
                    ),
                  ],
                  onChanged: (val) => setLocal(() => supplierId = val),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: montoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Monto *',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: currencyId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Moneda *',
                          isDense: true,
                        ),
                        items: currencies
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.code),
                              ),
                            )
                            .toList(),
                        onChanged: (val) => setLocal(() => currencyId = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción del gasto *',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Periodo de pertenencia (AAAA-MM) *',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Comprobante / referencia (opcional)',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPayExpenseDialog(BuildContext context, GastoGobernadoModel item) {
    final montoCtrl = TextEditingController(
      text: (double.parse(item.monto) - double.parse(item.pagadoAcumulado))
          .toStringAsFixed(2),
    );
    final refCtrl = TextEditingController();
    final accounts = ref.watch(accountProvider).value ?? [];
    String? accountId = accounts.isNotEmpty ? accounts.first.id : null;

    showDialog(
      context: context,
      builder: (dialogCtx) => PulsoThemeScope(
        child: StatefulBuilder(
          builder: (context, setLocal) => _PulsoFormDialog(
            title: 'REGISTRAR PAGO',
            subtitle:
                '${item.descripcion} · genera una salida de tesorería por el importe pagado.',
            confirmLabel: 'Confirmar pago',
            onConfirm: () async {
              if (montoCtrl.text.isEmpty) return;
              final navigator = Navigator.of(dialogCtx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref
                    .read(accountingRepositoryProvider)
                    .payGovernedExpense(item.gastoId, {
                      'monto': montoCtrl.text,
                      'cuenta_id': accountId,
                      'comprobante_referencia': refCtrl.text.isNotEmpty
                          ? refCtrl.text
                          : null,
                    });
                navigator.pop();
                _refresh();
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(_errorText(e))));
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: accountId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Cuenta de salida *',
                    isDense: true,
                  ),
                  items: accounts
                      .map(
                        (a) =>
                            DropdownMenuItem(value: a.id, child: Text(a.name)),
                      )
                      .toList(),
                  onChanged: (val) => setLocal(() => accountId = val),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: montoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monto a pagar *',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Comprobante / referencia',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showReversePaymentDialog(
    BuildContext context,
    GastoGobernadoAplicacionModel app,
    String? currencyCode,
  ) {
    final motivoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => PulsoThemeScope(
        child: _PulsoFormDialog(
          title: 'REVERSAR PAGO',
          subtitle:
              'Crea un contramovimiento de tesorería y restablece el pasivo pendiente.',
          confirmLabel: 'Reversar pago',
          danger: true,
          onConfirm: () async {
            if (motivoCtrl.text.isEmpty) return;
            final navigator = Navigator.of(dialogCtx);
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref
                  .read(accountingRepositoryProvider)
                  .reverseGovernedExpensePayment(app.aplicacionId, {
                    'motivo': motivoCtrl.text,
                  });
              navigator.pop();
              _refresh();
            } catch (e) {
              messenger.showSnackBar(SnackBar(content: Text(_errorText(e))));
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Se reversará la aplicación de pago por '
                '${_moneyWithCurrency(app.montoAplicado, currencyCode)}.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: motivoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motivo de reversión *',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryManagementDialog(
    BuildContext context,
    List<GastoCategoriaModel> categories,
  ) {
    final nameCtrl = TextEditingController();
    String nature = 'OPERATIVO';

    showDialog(
      context: context,
      builder: (dialogCtx) => PulsoThemeScope(
        child: Builder(
          builder: (context) {
            final tokens = PulsoTokens.of(context);
            return StatefulBuilder(
              builder: (context, setLocal) => _PulsoFormDialog(
                title: 'CATEGORÍAS DE GASTO',
                subtitle:
                    'Clasifican los gastos por su naturaleza contable (OPEX, administrativo, costo de ventas).',
                confirmLabel: 'Crear categoría',
                onConfirm: () async {
                  if (nameCtrl.text.isEmpty) return;
                  final navigator = Navigator.of(dialogCtx);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await ref
                        .read(accountingRepositoryProvider)
                        .createGovernedExpenseCategory({
                          'nombre': nameCtrl.text,
                          'naturaleza': nature,
                        });
                    navigator.pop();
                    _refresh();
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(_errorText(e))),
                    );
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la nueva categoría',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: nature,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Naturaleza contable',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'OPERATIVO',
                          child: Text('Operativo (OPEX)'),
                        ),
                        DropdownMenuItem(
                          value: 'ADMINISTRATIVO',
                          child: Text('Administrativo'),
                        ),
                        DropdownMenuItem(
                          value: 'COSTO_VENTAS',
                          child: Text('Costo de ventas'),
                        ),
                      ],
                      onChanged: (val) =>
                          setLocal(() => nature = val ?? 'OPERATIVO'),
                    ),
                    const SizedBox(height: 16),
                    const PulsoLabel('CATEGORÍAS EXISTENTES'),
                    const SizedBox(height: 6),
                    _ManagementList(
                      empty: 'Aún no hay categorías.',
                      rows: [
                        for (final c in categories)
                          (title: c.nombre, subtitle: c.naturaleza),
                      ],
                      tokens: tokens,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showSupplierManagementDialog(
    BuildContext context,
    List<GastoProveedorModel> suppliers,
  ) {
    final nameCtrl = TextEditingController();
    final docCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => PulsoThemeScope(
        child: Builder(
          builder: (context) {
            final tokens = PulsoTokens.of(context);
            return _PulsoFormDialog(
              title: 'PROVEEDORES',
              subtitle:
                  'Terceros a quienes se paga un gasto gobernado (alquiler, servicios, insumos).',
              confirmLabel: 'Crear proveedor',
              onConfirm: () async {
                if (nameCtrl.text.isEmpty) return;
                final navigator = Navigator.of(dialogCtx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref
                      .read(accountingRepositoryProvider)
                      .createGovernedExpenseSupplier({
                        'nombre': nameCtrl.text,
                        'documento': docCtrl.text.isNotEmpty
                            ? docCtrl.text
                            : null,
                      });
                  navigator.pop();
                  _refresh();
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(_errorText(e))),
                  );
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del proveedor *',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: docCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Documento / RUC / NIT (opcional)',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const PulsoLabel('PROVEEDORES REGISTRADOS'),
                  const SizedBox(height: 6),
                  _ManagementList(
                    empty: 'Aún no hay proveedores.',
                    rows: [
                      for (final s in suppliers)
                        (
                          title: s.nombre,
                          subtitle: s.documento ?? 'Sin documento',
                        ),
                    ],
                    tokens: tokens,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Lista compacta de catálogo (categorías/proveedores) con encuadre PULSO.
class _ManagementList extends StatelessWidget {
  const _ManagementList({
    required this.rows,
    required this.empty,
    required this.tokens,
  });

  final List<({String title, String subtitle})> rows;
  final String empty;
  final PulsoTokens tokens;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Text(empty, style: TextStyle(color: tokens.muted, fontSize: 12));
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 170),
      decoration: BoxDecoration(border: Border.all(color: tokens.line)),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: rows.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: tokens.line),
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  rows[i].title,
                  style: TextStyle(color: tokens.chalk, fontSize: 12.5),
                ),
              ),
              Text(
                rows[i].subtitle.toUpperCase(),
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 9,
                  color: tokens.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
