import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../financials/presentation/state/account_notifier.dart';
import '../../data/models/accounting_models.dart';
import '../../data/repositories/accounting_repository.dart';
import '../state/accounting_providers.dart';

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
  late String? _month = widget.initialMonth;
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
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.accent,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo Gasto'),
                onPressed: () => _showCreateExpenseDialog(context, categories, suppliers),
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
              OutlinedButton.icon(
                icon: const Icon(Icons.category_outlined, size: 18),
                label: const Text('Categorías'),
                onPressed: () => _showCategoryManagementDialog(context, categories),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.business_outlined, size: 18),
                label: const Text('Proveedores'),
                onPressed: () => _showSupplierManagementDialog(context, suppliers),
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
              separatorBuilder: (_, __) => const SizedBox(height: 12),
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
    String? categoryId = categories.isNotEmpty ? categories.first.categoriaId : null;
    String? supplierId;
    String currencyId = 'USD';

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Registrar Nuevo Gasto Devengado'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: categoryId,
                decoration: const InputDecoration(labelText: 'Categoría *'),
                items: categories
                    .map((c) => DropdownMenuItem(value: c.categoriaId, child: Text(c.nombre)))
                    .toList(),
                onChanged: (val) => categoryId = val,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: supplierId,
                decoration: const InputDecoration(labelText: 'Proveedor (Opcional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sin proveedor')),
                  ...suppliers.map((s) => DropdownMenuItem(value: s.proveedorId, child: Text(s.nombre))),
                ],
                onChanged: (val) => supplierId = val,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Descripción del gasto *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: montoCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monto *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mesCtrl,
                decoration: const InputDecoration(labelText: 'Periodo pertenencia (AAAA-MM) *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: refCtrl,
                decoration: const InputDecoration(labelText: 'Comprobante / Referencia (Opcional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (categoryId == null || descCtrl.text.isEmpty || montoCtrl.text.isEmpty) {
                return;
              }
              try {
                await ref.read(accountingRepositoryProvider).createGovernedExpense({
                  'categoria_id': categoryId,
                  'proveedor_id': supplierId,
                  'moneda_id': currencyId,
                  'descripcion': descCtrl.text,
                  'monto': montoCtrl.text,
                  'periodo_pertenencia_mes': mesCtrl.text,
                  'comprobante_referencia': refCtrl.text.isNotEmpty ? refCtrl.text : null,
                });
                Navigator.pop(dialogCtx);
                _refresh();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_errorText(e))),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
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
      builder: (dialogCtx) => AlertDialog(
        title: Text('Registrar Pago: ${item.descripcion}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: accountId,
              decoration: const InputDecoration(labelText: 'Cuenta de Salida *'),
              items: accounts
                  .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                  .toList(),
              onChanged: (val) => accountId = val,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: montoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Monto a Pagar *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: refCtrl,
              decoration: const InputDecoration(labelText: 'Comprobante / Referencia'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (montoCtrl.text.isEmpty) return;
              try {
                await ref.read(accountingRepositoryProvider).payGovernedExpense(
                  item.gastoId,
                  {
                    'monto': montoCtrl.text,
                    'cuenta_id': accountId,
                    'comprobante_referencia': refCtrl.text.isNotEmpty ? refCtrl.text : null,
                  },
                );
                Navigator.pop(dialogCtx);
                _refresh();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_errorText(e))),
                );
              }
            },
            child: const Text('Confirmar Pago'),
          ),
        ],
      ),
    );
  }

  void _showReversePaymentDialog(BuildContext context, GastoGobernadoAplicacionModel app) {
    final motivoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Reversar Pago de Gasto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Desea reversar la aplicación de pago por \$${app.montoAplicado}?'),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              decoration: const InputDecoration(labelText: 'Motivo de Reversión *'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (motivoCtrl.text.isEmpty) return;
              try {
                await ref.read(accountingRepositoryProvider).reverseGovernedExpensePayment(
                  app.aplicacionId,
                  {'motivo': motivoCtrl.text},
                );
                Navigator.pop(dialogCtx);
                _refresh();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_errorText(e))),
                );
              }
            },
            child: const Text('Reversar Pago'),
          ),
        ],
      ),
    );
  }

  void _showCategoryManagementDialog(BuildContext context, List<GastoCategoriaModel> categories) {
    final nameCtrl = TextEditingController();
    String nature = 'OPERATIVO';

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Gestión de Categorías de Gastos'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre de la Nueva Categoría'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: nature,
                decoration: const InputDecoration(labelText: 'Naturaleza Contable'),
                items: const [
                  DropdownMenuItem(value: 'OPERATIVO', child: Text('Operativo (OPEX)')),
                  DropdownMenuItem(value: 'ADMINISTRATIVO', child: Text('Administrativo')),
                  DropdownMenuItem(value: 'COSTO_VENTAS', child: Text('Costo de Ventas')),
                ],
                onChanged: (val) => nature = val ?? 'OPERATIVO',
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Categorías Existentes:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 150,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    title: Text(categories[i].nombre),
                    subtitle: Text(categories[i].naturaleza),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cerrar')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              try {
                await ref.read(accountingRepositoryProvider).createGovernedExpenseCategory({
                  'nombre': nameCtrl.text,
                  'naturaleza': nature,
                });
                Navigator.pop(dialogCtx);
                _refresh();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_errorText(e))),
                );
              }
            },
            child: const Text('Crear Categoría'),
          ),
        ],
      ),
    );
  }

  void _showSupplierManagementDialog(BuildContext context, List<GastoProveedorModel> suppliers) {
    final nameCtrl = TextEditingController();
    final docCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Gestión de Proveedores'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del Proveedor *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: docCtrl,
                decoration: const InputDecoration(labelText: 'Documento / RUC / NIT (Opcional)'),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Proveedores Registrados:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 150,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: suppliers.length,
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    title: Text(suppliers[i].nombre),
                    subtitle: Text(suppliers[i].documento ?? 'Sin documento'),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cerrar')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              try {
                await ref.read(accountingRepositoryProvider).createGovernedExpenseSupplier({
                  'nombre': nameCtrl.text,
                  'documento': docCtrl.text.isNotEmpty ? docCtrl.text : null,
                });
                Navigator.pop(dialogCtx);
                _refresh();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_errorText(e))),
                );
              }
            },
            child: const Text('Crear Proveedor'),
          ),
        ],
      ),
    );
  }
}
