import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/recurring_expense_models.dart';
import '../../data/repositories/accounting_repository.dart';
import '../../../financials/presentation/state/currency_notifier.dart';
import '../state/accounting_providers.dart';

/// R4.7 — Gastos recurrentes.
///
/// Dos mitades: las plantillas vigentes y el plan del mes. El plan es lo que
/// evita la sorpresa: antes de generar, el operador ve exactamente qué gastos
/// se crearán y cuáles se saltan y por qué.
class RecurringExpensesPanel extends ConsumerStatefulWidget {
  const RecurringExpensesPanel({
    super.key,
    this.initialMonth,
    required this.onBack,
    this.onGenerated,
  });

  final String? initialMonth;
  final VoidCallback onBack;

  /// Se invoca tras generar, para que el panel de gastos se refresque.
  final VoidCallback? onGenerated;

  @override
  ConsumerState<RecurringExpensesPanel> createState() =>
      _RecurringExpensesPanelState();
}

class _RecurringExpensesPanelState
    extends ConsumerState<RecurringExpensesPanel> {
  final _scroll = ScrollController();
  late String? _month = widget.initialMonth;
  bool _working = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(recurringExpensePlanProvider(_month))
        .when(
          loading: () => const PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.loading,
              message: 'Revisando qué gastos toca generar este mes…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message:
                  'No se pudo preparar el plan de gastos recurrentes.\n${_errorText(error)}',
              onRetry: _refresh,
            ),
          ),
          data: _buildPlan,
        );
  }

  Widget _buildPlan(RecurringExpensePlanModel plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecurringToolbar(
          plan: plan,
          working: _working,
          onBack: widget.onBack,
          onPrevious: () => _moveMonth(plan.month, -1),
          onNext: () => _moveMonth(plan.month, 1),
          onCurrent: () => _setMonth(null),
          onGenerate: plan.canGenerate && !_working
              ? () => _generate(plan)
              : null,
          onCreate: _working ? null : _createTemplate,
          onRefresh: _refresh,
        ),
        const SizedBox(height: 8),
        PulsoMetricStrip(
          key: const Key('recurring-expenses-metrics'),
          metrics: [
            PulsoMetricData(
              value: '${plan.summary.toGenerate}',
              label: 'A GENERAR',
              note: 'Plantillas pendientes de este mes',
              emphasis: plan.summary.toGenerate > 0,
            ),
            PulsoMetricData(
              value: '${plan.summary.alreadyGenerated}',
              label: 'YA GENERADAS',
              note: 'Su gasto del mes ya existe',
            ),
            PulsoMetricData(
              value: '${plan.summary.evaluated}',
              label: 'PLANTILLAS',
              note: 'Activas e inactivas',
            ),
          ],
        ),
        const SizedBox(height: 8),
        _PlanNotice(plan: plan),
        const SizedBox(height: 8),
        Expanded(
          child: PulsoPanel(
            padding: EdgeInsets.zero,
            child: Scrollbar(
              key: const Key('recurring-expenses-scrollbar'),
              controller: _scroll,
              thumbVisibility: true,
              child: ListView(
                key: const Key('recurring-expenses-list'),
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                children: [
                  _PendingSection(plan: plan),
                  const SizedBox(height: 12),
                  _SkippedSection(plan: plan),
                  const SizedBox(height: 12),
                  _TemplatesSection(
                    onToggle: _working ? null : _toggleTemplate,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _generate(RecurringExpensePlanModel plan) async {
    final confirmed = await _confirmGeneration(plan);
    if (confirmed != true || !mounted) return;

    setState(() => _working = true);
    try {
      final result = await ref
          .read(accountingRepositoryProvider)
          .generateRecurringExpenses(month: plan.month);
      _refresh();
      widget.onGenerated?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.generated.length == 1
                  ? 'Se generó 1 gasto para ${plan.month}.'
                  : 'Se generaron ${result.generated.length} gastos para ${plan.month}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo generar: ${_errorText(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<bool?> _confirmGeneration(RecurringExpensePlanModel plan) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final tokens = PulsoTokens.of(dialogContext);
        return Dialog(
          key: const Key('recurring-expenses-confirm-dialog'),
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
            child: PulsoPanel(
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(height: 3, color: tokens.accent),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PulsoLabel('PULSO · CONTABILIDAD'),
                        const SizedBox(height: 6),
                        Text(
                          'GENERAR GASTOS DE ${plan.month}',
                          style: TextStyle(
                            color: tokens.chalk,
                            fontFamily: PulsoFonts.display,
                            fontSize: 25,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Se creará un gasto pendiente de pago por cada plantilla. '
                          'Generar dos veces el mismo mes no duplica nada.',
                          style: TextStyle(
                            color: tokens.chalkDim,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final row in plan.pending)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      row.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: tokens.chalk,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_exactMoney(row.amount)} ${row.currencyCode}',
                                    style: TextStyle(
                                      color: tokens.chalk,
                                      fontFamily: PulsoFonts.mono,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 6),
                          for (final total in plan.totals)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              color: tokens.raised,
                              child: Row(
                                children: [
                                  const Expanded(child: PulsoLabel('TOTAL')),
                                  Text(
                                    '${_exactMoney(total.amount)} ${total.currencyCode}',
                                    style: TextStyle(
                                      color: tokens.accent,
                                      fontFamily: PulsoFonts.mono,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        PulsoSecondaryButton(
                          label: 'CANCELAR',
                          onPressed: () => Navigator.pop(dialogContext, false),
                        ),
                        const SizedBox(width: 8),
                        PulsoPrimaryButton(
                          key: const Key('recurring-expenses-confirm-submit'),
                          label: 'GENERAR',
                          onPressed: () => Navigator.pop(dialogContext, true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// R4.7 — alta de plantilla.
  ///
  /// Existía en la API y en el repositorio, pero **ninguna vista la llamaba**:
  /// el panel sabía pausar y generar, no crear. Sin esto la unidad 09 no se
  /// puede recorrer, porque no hay forma de dar de alta una plantilla desde la
  /// pantalla ni en escritorio ni en web. Lo destapó el recorrido del
  /// 02-08-2026.
  Future<void> _createTemplate() async {
    final cuerpo = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _NewRecurringTemplateDialog(),
    );
    if (cuerpo == null || !mounted) return;
    setState(() => _working = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(accountingRepositoryProvider).createRecurringExpense(cuerpo);
      ref.invalidate(recurringExpensesProvider);
      _refresh();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Plantilla creada. Aparecerá en el plan del mes en cuanto le toque.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo crear la plantilla: ${_errorText(error)}')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _toggleTemplate(RecurringExpenseModel template) async {
    setState(() => _working = true);
    try {
      await ref
          .read(accountingRepositoryProvider)
          .updateRecurringExpense(
            templateId: template.templateId,
            body: {'activo': !template.active},
          );
      ref.invalidate(recurringExpensesProvider);
      _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo cambiar la plantilla: ${_errorText(error)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

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
    setState(() => _month = value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void _refresh() {
    ref.invalidate(recurringExpensePlanProvider(_month));
    ref.invalidate(recurringExpensesProvider);
  }
}

/// R4.7 — alta de plantilla de gasto recurrente.
///
/// El servidor decide el dinero: aquí solo se recogen los datos y se envían.
/// El importe viaja como texto, sin redondear ni convertir en el cliente.
class _NewRecurringTemplateDialog extends ConsumerStatefulWidget {
  const _NewRecurringTemplateDialog();

  @override
  ConsumerState<_NewRecurringTemplateDialog> createState() =>
      _NewRecurringTemplateDialogState();
}

class _NewRecurringTemplateDialogState
    extends ConsumerState<_NewRecurringTemplateDialog> {
  final _descripcion = TextEditingController();
  final _monto = TextEditingController();
  final _dia = TextEditingController(text: '1');
  String? _categoriaId;
  String? _proveedorId;
  String? _monedaId;
  late String _mesInicio = _mesActual();

  static String _mesActual() {
    final ahora = appClock.nowUtc();
    return '${ahora.year.toString().padLeft(4, '0')}-'
        '${ahora.month.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _descripcion.dispose();
    _monto.dispose();
    _dia.dispose();
    super.dispose();
  }

  bool get _valido =>
      _categoriaId != null &&
      _monedaId != null &&
      _descripcion.text.trim().isNotEmpty &&
      (double.tryParse(_monto.text.trim()) ?? 0) > 0 &&
      RegExp(r'^\d{4}-\d{2}$').hasMatch(_mesInicio);

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final categorias = ref.watch(governedExpenseCategoriesProvider).value ?? const [];
    final proveedores = ref.watch(governedExpenseSuppliersProvider).value ?? const [];
    final monedas = ref.watch(currencyProvider).value ?? const [];

    return AlertDialog(
      key: const Key('recurring-expenses-create-dialog'),
      title: const Text('NUEVA PLANTILLA RECURRENTE'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'La plantilla no crea ningún gasto por sí sola: aparecerá en el '
                'plan del mes y solo se materializa al generar.',
                style: TextStyle(color: tokens.muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: const Key('recurring-create-category'),
                initialValue: _categoriaId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Categoría', isDense: true),
                items: [
                  for (final c in categorias)
                    DropdownMenuItem(value: c.categoriaId, child: Text(c.nombre)),
                ],
                onChanged: (v) => setState(() => _categoriaId = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: const Key('recurring-create-supplier'),
                initialValue: _proveedorId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Proveedor (opcional)', isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sin proveedor')),
                  for (final p in proveedores)
                    DropdownMenuItem(value: p.proveedorId, child: Text(p.nombre)),
                ],
                onChanged: (v) => setState(() => _proveedorId = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: const Key('recurring-create-currency'),
                initialValue: _monedaId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Moneda', isDense: true),
                items: [
                  for (final m in monedas)
                    DropdownMenuItem(value: m.id, child: Text(m.code)),
                ],
                onChanged: (v) => setState(() => _monedaId = v),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('recurring-create-description'),
                controller: _descripcion,
                decoration: const InputDecoration(labelText: 'Descripción', isDense: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('recurring-create-amount'),
                controller: _monto,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Importe', isDense: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('recurring-create-day'),
                      controller: _dia,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Día del mes', isDense: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      key: const Key('recurring-create-start'),
                      initialValue: _mesInicio,
                      decoration: const InputDecoration(
                        labelText: 'Mes de inicio (AAAA-MM)', isDense: true),
                      onChanged: (v) => setState(() => _mesInicio = v.trim()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCELAR'),
        ),
        FilledButton(
          key: const Key('recurring-create-submit'),
          onPressed: _valido
              ? () => Navigator.of(context).pop({
                  'categoria_id': _categoriaId,
                  'proveedor_id': _proveedorId,
                  'moneda_id': _monedaId,
                  'descripcion': _descripcion.text.trim(),
                  // Texto, no número: redondear aquí sería calcular dinero en
                  // el cliente.
                  'monto': _monto.text.trim(),
                  'dia_programado': int.tryParse(_dia.text.trim()) ?? 1,
                  'mes_inicio': _mesInicio,
                })
              : null,
          child: const Text('CREAR PLANTILLA'),
        ),
      ],
    );
  }
}

class _RecurringToolbar extends StatelessWidget {
  const _RecurringToolbar({
    required this.plan,
    required this.working,
    required this.onBack,
    required this.onPrevious,
    required this.onNext,
    required this.onCurrent,
    required this.onGenerate,
    required this.onCreate,
    required this.onRefresh,
  });

  final RecurringExpensePlanModel plan;
  final bool working;
  final VoidCallback onBack;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCurrent;
  final VoidCallback? onGenerate;
  final VoidCallback? onCreate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 880;
          final monthBox = Container(
            constraints: BoxConstraints(
              minWidth: compact ? 0 : 132,
              minHeight: 40,
            ),
            alignment: Alignment.center,
            color: tokens.raised,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _monthName(plan.month).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.chalk,
                fontFamily: PulsoFonts.mono,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          );
          if (compact) {
            return Row(
              children: [
                PulsoIconButton(
                  key: const Key('recurring-expenses-back-compact'),
                  icon: Icons.arrow_back,
                  tooltip: 'Volver a gastos',
                  onPressed: onBack,
                ),
                const SizedBox(width: 6),
                Expanded(child: monthBox),
                const SizedBox(width: 6),
                PulsoIconButton(
                  key: const Key('recurring-expenses-create-compact'),
                  icon: Icons.add,
                  tooltip: 'Nueva plantilla',
                  onPressed: onCreate,
                ),
                PulsoIconButton(
                  key: const Key('recurring-expenses-generate-compact'),
                  icon: Icons.playlist_add_check,
                  tooltip: 'Generar los gastos del mes',
                  onPressed: onGenerate,
                ),
                PulsoIconButton(
                  icon: Icons.refresh,
                  tooltip: 'Actualizar plan',
                  onPressed: onRefresh,
                ),
              ],
            );
          }
          return Row(
            children: [
              TextButton.icon(
                key: const Key('recurring-expenses-back'),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('VOLVER A GASTOS'),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'GASTOS RECURRENTES',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.chalk,
                    fontFamily: PulsoFonts.display,
                    fontSize: 25,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const Spacer(),
              PulsoIconButton(
                icon: Icons.chevron_left,
                tooltip: 'Mes anterior',
                onPressed: onPrevious,
              ),
              monthBox,
              PulsoIconButton(
                icon: Icons.chevron_right,
                tooltip: 'Mes siguiente',
                onPressed: onNext,
              ),
              const SizedBox(width: 6),
              PulsoSecondaryButton(label: 'MES EN CURSO', onPressed: onCurrent),
              const SizedBox(width: 6),
              // Sin esto el panel sabía pausar y generar, pero no crear: la
              // plantilla solo podía darse de alta llamando a la API a mano.
              //
              // La etiqueta es corta a propósito: con «NUEVA PLANTILLA» la
              // barra desbordaba 61 px a 1280, y en una barra que ya lleva
              // cuatro acciones el texto largo no cabe sin partir la fila.
              PulsoSecondaryButton(
                key: const Key('recurring-expenses-create'),
                label: 'NUEVA',
                icon: Icons.add,
                onPressed: onCreate,
              ),
              const SizedBox(width: 6),
              PulsoPrimaryButton(
                key: const Key('recurring-expenses-generate'),
                label: working ? 'GENERANDO…' : 'GENERAR MES',
                onPressed: onGenerate,
              ),
              const SizedBox(width: 6),
              PulsoIconButton(
                icon: Icons.refresh,
                tooltip: 'Actualizar plan',
                onPressed: onRefresh,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanNotice extends StatelessWidget {
  const _PlanNotice({required this.plan});

  final RecurringExpensePlanModel plan;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final blocked = !plan.canGenerate;
    final future = plan.periodState == 'FUTURO';
    final color = future
        ? tokens.warning
        : blocked
        ? tokens.muted
        : tokens.success;
    return PulsoPanel(
      color: future ? tokens.warningSoft : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  switch (plan.periodState) {
                    'FUTURO' => 'MES FUTURO',
                    'HISTORICO' => 'MES YA TERMINADO',
                    _ => 'MES EN CURSO',
                  },
                  style: TextStyle(
                    color: color,
                    fontFamily: PulsoFonts.mono,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  plan.blockReason ?? plan.note,
                  style: TextStyle(
                    color: tokens.chalkDim,
                    fontSize: 12,
                    height: 1.35,
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

class _PendingSection extends StatelessWidget {
  const _PendingSection({required this.plan});

  final RecurringExpensePlanModel plan;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      decoration: BoxDecoration(border: Border.all(color: tokens.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionCap(label: 'SE GENERARÁ', trailing: '${plan.pending.length}'),
          if (plan.pending.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Text(
                'Ninguna plantilla queda pendiente para este mes.',
                style: TextStyle(color: tokens.muted, fontSize: 12),
              ),
            )
          else
            for (var index = 0; index < plan.pending.length; index++)
              _PendingRow(
                row: plan.pending[index],
                last: index == plan.pending.length - 1,
              ),
          for (final total in plan.totals)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: tokens.raised,
                border: Border(top: BorderSide(color: tokens.line)),
              ),
              child: Row(
                children: [
                  Expanded(child: PulsoLabel('TOTAL ${total.currencyCode}')),
                  Text(
                    '${_exactMoney(total.amount)} ${total.currencyCode}',
                    style: TextStyle(
                      color: tokens.accent,
                      fontFamily: PulsoFonts.mono,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.row, required this.last});

  final RecurringExpensePendingModel row;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.chalk, fontSize: 12),
                ),
                Text(
                  [
                    row.categoryName,
                    if (row.supplierName != null) row.supplierName!,
                    'PROGRAMADO ${row.scheduledDate}',
                  ].join(' · ').toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.muted2,
                    fontFamily: PulsoFonts.mono,
                    fontSize: 8,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${_exactMoney(row.amount)} ${row.currencyCode}',
            style: TextStyle(
              color: tokens.chalk,
              fontFamily: PulsoFonts.mono,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkippedSection extends StatelessWidget {
  const _SkippedSection({required this.plan});

  final RecurringExpensePlanModel plan;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    if (plan.skipped.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(border: Border.all(color: tokens.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionCap(
            label: 'SE SALTA, Y POR QUÉ',
            trailing: '${plan.skipped.length}',
          ),
          for (var index = 0; index < plan.skipped.length; index++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                border: index == plan.skipped.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: tokens.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.skipped[index].description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.chalkDim,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          plan.skipped[index].explanation,
                          maxLines: 2,
                          style: TextStyle(color: tokens.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.raised,
                      border: Border.all(color: tokens.line),
                    ),
                    child: Text(
                      plan.skipped[index].reasonLabel.toUpperCase(),
                      style: TextStyle(
                        color: tokens.muted,
                        fontFamily: PulsoFonts.mono,
                        fontSize: 8,
                        letterSpacing: 0.8,
                      ),
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

class _TemplatesSection extends ConsumerWidget {
  const _TemplatesSection({required this.onToggle});

  final ValueChanged<RecurringExpenseModel>? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    return ref
        .watch(recurringExpensesProvider)
        .when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (templates) => Container(
            decoration: BoxDecoration(border: Border.all(color: tokens.line)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionCap(
                  label: 'PLANTILLAS',
                  trailing: '${templates.length}',
                ),
                if (templates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    child: Text(
                      'Todavía no hay plantillas. Una plantilla convierte un gasto '
                      'que se repite en algo que no hay que volver a escribir cada mes.',
                      style: TextStyle(color: tokens.muted, fontSize: 12),
                    ),
                  )
                else
                  for (var index = 0; index < templates.length; index++)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        border: index == templates.length - 1
                            ? null
                            : Border(bottom: BorderSide(color: tokens.line)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  templates[index].description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: templates[index].active
                                        ? tokens.chalk
                                        : tokens.muted,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${templates[index].validityLabel} · DÍA ${templates[index].scheduledDay}'
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: tokens.muted2,
                                    fontFamily: PulsoFonts.mono,
                                    fontSize: 8,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _exactMoney(templates[index].amount),
                            style: TextStyle(
                              color: tokens.chalkDim,
                              fontFamily: PulsoFonts.mono,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 10),
                          PulsoSecondaryButton(
                            key: Key(
                              'recurring-template-toggle-${templates[index].templateId}',
                            ),
                            label: templates[index].active
                                ? 'PAUSAR'
                                : 'ACTIVAR',
                            onPressed: onToggle == null
                                ? null
                                : () => onToggle!(templates[index]),
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

class _SectionCap extends StatelessWidget {
  const _SectionCap({required this.label, this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.muted,
                fontFamily: PulsoFonts.mono,
                fontSize: 9,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.3,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                color: tokens.accent,
                fontFamily: PulsoFonts.mono,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
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
  if (parts.length < 2) return month;
  final index = int.tryParse(parts[1]) ?? 0;
  if (index < 1 || index > 12) return month;
  return '${names[index - 1]} ${parts.first}';
}

String _errorText(Object error) {
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
  return error.toString();
}
