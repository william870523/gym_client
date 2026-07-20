import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../financials/presentation/state/account_notifier.dart';
import '../../../financials/presentation/state/currency_notifier.dart';
import '../../data/models/accounting_models.dart';
import '../../data/repositories/accounting_repository.dart';
import '../state/accounting_providers.dart';

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
    return ref.watch(governedExpensesProvider(_month)).when(
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

  Widget _buildContent(BuildContext context, GovernedExpensesReportModel report) {
    final tokens = PulsoTokens.of(context);
    final categories = ref.watch(governedExpenseCategoriesProvider).value ?? [];
    final suppliers = ref.watch(governedExpenseSuppliersProvider).value ?? [];

    final filtered = report.gastos.where((g) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return g.descripcion.toLowerCase().contains(q) ||
          (g.categoriaNombre?.toLowerCase().contains(q) ?? false) ||
          (g.proveedorNombre?.toLowerCase().contains(q) ?? false);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                tooltip: 'Regresar',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
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
                      'Contabilidad de devengo real, periodos de pertenencia y control de tesorería',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
              PulsoPrimaryButton(
                label: 'Nuevo gasto',
                icon: Icons.add,
                onPressed: () =>
                    _showCreateExpenseDialog(context, categories, suppliers),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // KPI Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  context,
                  title: 'DEVENGADO TOTAL',
                  value: '\$${report.totalDevengado}',
                  subtitle: 'Mes ${report.mes}',
                  color: tokens.chalk,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiCard(
                  context,
                  title: 'PAGADO ACUMULADO',
                  value: '\$${report.totalPagado}',
                  subtitle: 'Salidas de Tesorería',
                  color: tokens.success,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiCard(
                  context,
                  title: 'PENDIENTE DE PAGO',
                  value: '\$${report.totalPendiente}',
                  subtitle: 'Pasivos por Liquidar',
                  color: tokens.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Action toolbar & Filter
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por descripción, categoría o proveedor',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => setState(() => _query = val),
                ),
              ),
              const SizedBox(width: 16),
              PulsoSecondaryButton(
                label: 'Categorías',
                icon: Icons.category_outlined,
                onPressed: () =>
                    _showCategoryManagementDialog(context, categories),
              ),
              const SizedBox(width: 8),
              PulsoSecondaryButton(
                label: 'Proveedores',
                icon: Icons.business_outlined,
                onPressed: () =>
                    _showSupplierManagementDialog(context, suppliers),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Expenses List
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Text(
                'No se encontraron gastos devengados registrados en el periodo.',
                style: TextStyle(color: tokens.muted),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = filtered[index];
                return _buildExpenseRow(context, item);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border.all(color: tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: tokens.muted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: PulsoFonts.display,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: tokens.muted2,
            ),
          ),
        ],
      ),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border.all(color: tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category tag & Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  item.estado,
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (item.categoriaNombre != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tokens.floor,
                    border: Border.all(color: tokens.line),
                  ),
                  child: Text(
                    item.categoriaNombre!.toUpperCase(),
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 10,
                      color: tokens.muted,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        style: TextStyle(
                          fontSize: 11,
                          color: tokens.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Amounts
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${item.monto}',
                    style: TextStyle(
                      fontFamily: PulsoFonts.display,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: tokens.chalk,
                    ),
                  ),
                  if (item.pagadoAcumulado != '0.00' && item.pagadoAcumulado != '0') ...[
                    const SizedBox(height: 2),
                    Text(
                      'Pagado: \$${item.pagadoAcumulado}',
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.success,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 16),
              // Actions
              if (item.estado != 'PAGADO' && item.estado != 'ANULADO')
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.accent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _showPayExpenseDialog(context, item),
                  child: const Text('Pagar'),
                ),
            ],
          ),
          // Applications (Payment history / reversals)
          if (item.aplicaciones.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 4),
            Text(
              'Historial de Pagos:',
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: tokens.muted,
              ),
            ),
            const SizedBox(height: 4),
            ...item.aplicaciones.map((app) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      Icon(
                        app.estado == 'REVERSADA' ? Icons.undo : Icons.check_circle_outline,
                        size: 14,
                        color: app.estado == 'REVERSADA' ? tokens.muted : tokens.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '\$${app.montoAplicado} - ${app.aplicadaAt.toLocal().toString().substring(0, 16)} (${app.estado})',
                        style: TextStyle(
                          fontSize: 11,
                          color: app.estado == 'REVERSADA' ? tokens.muted : tokens.chalk,
                          decoration: app.estado == 'REVERSADA' ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const Spacer(),
                      if (app.estado == 'APLICADA')
                        TextButton(
                          onPressed: () => _showReversePaymentDialog(context, app),
                          child: Text(
                            'Reversar',
                            style: TextStyle(
                              fontSize: 11,
                              color: tokens.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  void _showCreateExpenseDialog(
    BuildContext context,
    List<GastoCategoriaModel> categories,
    List<GastoProveedorModel> suppliers,
  ) {
    final descCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    final nowStr = DateTime.now().toUtc().toIso8601String().substring(0, 7);
    final mesCtrl = TextEditingController(text: _month ?? nowStr);
    final refCtrl = TextEditingController();
    final currencies = ref.read(currencyProvider).value ?? const [];
    String? categoryId =
        categories.isNotEmpty ? categories.first.categoriaId : null;
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
                  'comprobante_referencia':
                      refCtrl.text.isNotEmpty ? refCtrl.text : null,
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
                      .map((c) => DropdownMenuItem(
                            value: c.categoriaId,
                            child: Text(c.nombre),
                          ))
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
                    ...suppliers.map((s) => DropdownMenuItem(
                          value: s.proveedorId,
                          child: Text(s.nombre),
                        )),
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
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.code),
                                ))
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
      text: (double.parse(item.monto) - double.parse(item.pagadoAcumulado)).toStringAsFixed(2),
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
                  'comprobante_referencia':
                      refCtrl.text.isNotEmpty ? refCtrl.text : null,
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
                      .map((a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ))
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

  void _showReversePaymentDialog(BuildContext context, GastoGobernadoAplicacionModel app) {
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
                  .reverseGovernedExpensePayment(
                app.aplicacionId,
                {'motivo': motivoCtrl.text},
              );
              navigator.pop();
              _refresh();
            } catch (e) {
              messenger.showSnackBar(SnackBar(content: Text(_errorText(e))));
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Se reversará la aplicación de pago por \$${app.montoAplicado}.'),
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

  void _showCategoryManagementDialog(BuildContext context, List<GastoCategoriaModel> categories) {
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
                    messenger
                        .showSnackBar(SnackBar(content: Text(_errorText(e))));
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
                            child: Text('Operativo (OPEX)')),
                        DropdownMenuItem(
                            value: 'ADMINISTRATIVO',
                            child: Text('Administrativo')),
                        DropdownMenuItem(
                            value: 'COSTO_VENTAS',
                            child: Text('Costo de ventas')),
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

  void _showSupplierManagementDialog(BuildContext context, List<GastoProveedorModel> suppliers) {
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
                    'documento': docCtrl.text.isNotEmpty ? docCtrl.text : null,
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
