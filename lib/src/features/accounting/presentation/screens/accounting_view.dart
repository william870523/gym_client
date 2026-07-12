import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../products/data/models/payment_plan_model.dart';
import '../../../products/presentation/state/payment_plan_notifier.dart';
import '../../../trainers/data/models/trainer_model.dart';
import '../../../trainers/presentation/providers/trainer_notifier.dart';
import '../../data/models/accounting_models.dart';
import '../../data/repositories/accounting_repository.dart';
import '../state/accounting_providers.dart';

enum _AccountingTab { summary, installments, rules, payroll }

final _amount = NumberFormat('#,##0.00');
final _date = DateFormat('dd/MM/yyyy');

// Estas fechas llegan como fechas contractuales/contables. Se presentan por
// componentes UTC para conservar el año/mes/día, sin usar la zona del equipo.
String _calendarDate(DateTime value) => _date.format(value.toUtc());

class AccountingView extends ConsumerStatefulWidget {
  const AccountingView({super.key});

  @override
  ConsumerState<AccountingView> createState() => _AccountingViewState();
}

class _AccountingViewState extends ConsumerState<AccountingView> {
  _AccountingTab _tab = _AccountingTab.summary;
  String _period = 'BIWEEKLY';

  void _refresh() {
    ref.invalidate(accountingSummaryProvider);
    ref.invalidate(trainerCommissionInstallmentsProvider);
    ref.invalidate(trainerCommissionRulesProvider);
    ref.read(paymentPlanProvider.notifier).refresh();
    ref.read(trainerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    return PulsoThemeScope(
      child: Builder(
        builder: (context) => Material(
          color: PulsoTokens.of(context).floor,
          child: _buildPage(context),
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final padding = compact
            ? 16.0
            : constraints.maxWidth < 840
            ? 24.0
            : 32.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            padding,
            compact ? 16 : 20,
            padding,
            compact ? 18 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AccountingHeader(onRefresh: _refresh),
              const SizedBox(height: 16),
              _AccountingTabs(
                selected: _tab,
                onSelected: (value) => setState(() => _tab = value),
              ),
              const SizedBox(height: 14),
              switch (_tab) {
                _AccountingTab.summary => _buildSummary(),
                _AccountingTab.installments => _buildInstallments(),
                _AccountingTab.rules => _buildRules(),
                _AccountingTab.payroll => _buildPayroll(),
              },
              const SizedBox(height: 10),
              _AccountingFooter(period: _period),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummary() {
    final summaryState = ref.watch(accountingSummaryProvider);
    final installmentsState = ref.watch(trainerCommissionInstallmentsProvider);
    return summaryState.when(
      loading: () => const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.loading,
          message: 'Leyendo situación contable…',
        ),
      ),
      error: (error, _) => PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.error,
          message: 'No se pudo cargar el resumen.\n$error',
          onRetry: _refresh,
        ),
      ),
      data: (summary) {
        final byCurrency = <String, double>{};
        for (final item
            in installmentsState.value ??
                const <TrainerCommissionInstallmentModel>[]) {
          final code = item.currencyCode.trim().isEmpty
              ? 'SIN MONEDA'
              : item.currencyCode.toUpperCase();
          byCurrency[code] = (byCurrency[code] ?? 0) + item.amount;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PulsoMetricStrip(
              metrics: [
                PulsoMetricData(
                  value: '${summary.pendingTrainerCount}',
                  label: 'Cuotas pendientes',
                  note: 'comisiones por liquidar',
                  emphasis: true,
                ),
                PulsoMetricData(
                  value: '${summary.overdueTrainerCount}',
                  label: 'Vencidas',
                  note: 'requieren revisión',
                  warning: summary.overdueTrainerCount > 0,
                ),
                PulsoMetricData(
                  value: '${summary.activeRuleCount}',
                  label: 'Reglas activas',
                  note: '${summary.individualRuleCount} individuales',
                ),
                PulsoMetricData(
                  value: '${summary.paidTrainerCount}',
                  label: 'Cuotas pagadas',
                  note: 'histórico liquidado',
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final breakdown = _CurrencyBreakdown(
                  values: byCurrency,
                  loading: installmentsState.isLoading,
                );
                final policy = _SettlementPolicy(
                  value: _period,
                  onChanged: (value) => setState(() => _period = value),
                );
                if (constraints.maxWidth < 820) {
                  return Column(
                    children: [breakdown, const SizedBox(height: 12), policy],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: breakdown),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: policy),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            _RuleCoverage(summary: summary),
          ],
        );
      },
    );
  }

  Widget _buildInstallments() {
    final state = ref.watch(trainerCommissionInstallmentsProvider);
    return state.when(
      loading: () => const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.loading,
          message: 'Cargando cuotas de entrenadores…',
        ),
      ),
      error: (error, _) => PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.error,
          message: 'No se pudieron cargar las cuotas.\n$error',
          onRetry: _refresh,
        ),
      ),
      data: (items) => items.isEmpty
          ? const PulsoPanel(
              child: PulsoStateView(
                kind: PulsoStateKind.empty,
                message: 'No hay comisiones pendientes de pago.',
              ),
            )
          : _InstallmentCatalog(items: items),
    );
  }

  Widget _buildRules() {
    final state = ref.watch(trainerCommissionRulesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: PulsoPrimaryButton(
            label: 'Nueva regla',
            icon: Icons.add,
            onPressed: () => _openRuleDialog(),
          ),
        ),
        const SizedBox(height: 12),
        state.when(
          loading: () => const PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.loading,
              message: 'Cargando reglas…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message: 'No se pudieron cargar las reglas.\n$error',
              onRetry: _refresh,
            ),
          ),
          data: (rules) => rules.isEmpty
              ? const PulsoPanel(
                  child: PulsoStateView(
                    kind: PulsoStateKind.empty,
                    message: 'No hay reglas de comisión configuradas.',
                  ),
                )
              : _RuleCatalog(
                  rules: rules,
                  onEdit: _openRuleDialog,
                  onDelete: _deleteRule,
                ),
        ),
      ],
    );
  }

  Widget _buildPayroll() {
    final state = ref.watch(accountingSummaryProvider);
    return state.when(
      loading: () => const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.loading,
          message: 'Consultando nómina fija…',
        ),
      ),
      error: (error, _) => PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.error,
          message: 'No se pudo consultar la nómina.\n$error',
          onRetry: _refresh,
        ),
      ),
      data: (summary) => Builder(
        builder: (context) => PulsoPanel(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PulsoLabel('Nómina fija'),
              const SizedBox(height: 10),
              Text(
                '${summary.fixedPayrollProfiles} perfiles activos',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                summary.fixedPayrollProfiles == 0
                    ? 'Todavía no hay perfiles de sueldo fijo configurados. La liquidación disponible actualmente corresponde a comisiones.'
                    : '${summary.fixedPayrollPending} pagos de periodo están pendientes.',
                style: TextStyle(color: PulsoTokens.of(context).muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openRuleDialog([TrainerCommissionRuleModel? initial]) async {
    final plans =
        (ref.read(paymentPlanProvider).value ?? const <PaymentPlanModel>[])
            .where((plan) => plan.id != null && plan.activo && !plan.isDeleted)
            .toList();
    final trainers = (ref.read(trainerProvider).value ?? const <TrainerModel>[])
        .where((trainer) => trainer.activo && !trainer.isDeleted)
        .toList();
    String? planId = initial?.planId;
    String? trainerId = initial?.trainerId;
    String type = initial?.type ?? 'PERCENTAGE';
    bool active = initial?.active ?? true;
    String? error;
    final controller = TextEditingController(
      text: initial?.value.toString() ?? '',
    );

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PulsoThemeScope(
        child: StatefulBuilder(
          builder: (context, setLocalState) {
            final tokens = PulsoTokens.of(context);
            return AlertDialog(
              title: Text(
                initial == null ? 'Nueva regla de comisión' : 'Editar regla',
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: planId,
                        decoration: const InputDecoration(
                          labelText: 'Plan de pago',
                        ),
                        items: [
                          for (final plan in plans)
                            DropdownMenuItem(
                              value: plan.id,
                              child: Text(
                                plan.nombre,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: plans.isEmpty
                            ? null
                            : (value) => setLocalState(() => planId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        isExpanded: true,
                        initialValue: trainerId,
                        decoration: const InputDecoration(
                          labelText: 'Entrenador',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Regla general del plan'),
                          ),
                          for (final trainer in trainers)
                            DropdownMenuItem<String?>(
                              value: trainer.id,
                              child: Text(
                                '${trainer.nombres ?? ''} ${trainer.apellidos ?? ''}'
                                    .trim(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setLocalState(() => trainerId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de cálculo',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'PERCENTAGE',
                            child: Text('Porcentaje (%)'),
                          ),
                          DropdownMenuItem(
                            value: 'FIXED_AMOUNT',
                            child: Text('Monto fijo'),
                          ),
                        ],
                        onChanged: (value) =>
                            setLocalState(() => type = value ?? 'PERCENTAGE'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: type == 'PERCENTAGE'
                              ? 'Porcentaje'
                              : 'Monto fijo',
                          suffixText: type == 'PERCENTAGE' ? '%' : null,
                          errorText: error,
                        ),
                      ),
                      SwitchListTile(
                        value: active,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Regla activa'),
                        subtitle: const Text(
                          'Se aplicará a nuevas liquidaciones compatibles.',
                        ),
                        activeTrackColor: tokens.success,
                        onChanged: (value) =>
                            setLocalState(() => active = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                PulsoSecondaryButton(
                  label: 'Cancelar',
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                PulsoPrimaryButton(
                  label: 'Guardar',
                  onPressed: planId == null
                      ? null
                      : () async {
                          final value = double.tryParse(
                            controller.text.trim().replaceAll(',', '.'),
                          );
                          final invalid =
                              value == null ||
                              value <= 0 ||
                              (type == 'PERCENTAGE' && value > 100);
                          if (invalid) {
                            setLocalState(() {
                              error = type == 'PERCENTAGE'
                                  ? 'Ingrese un porcentaje entre 0 y 100.'
                                  : 'Ingrese un monto mayor que cero.';
                            });
                            return;
                          }
                          final payload = <String, dynamic>{
                            'id_planes_pago': planId,
                            'id_entrenador': trainerId,
                            'tipo_calculo': type,
                            'valor_calculo': value,
                            'activo': active,
                          };
                          final repository = ref.read(
                            accountingRepositoryProvider,
                          );
                          if (initial == null) {
                            await repository.createTrainerRule(payload);
                          } else {
                            await repository.updateTrainerRule(
                              initial.id,
                              payload,
                            );
                          }
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                        },
                ),
              ],
            );
          },
        ),
      ),
    );
    controller.dispose();
    if (!mounted || saved != true) return;
    ref.invalidate(trainerCommissionRulesProvider);
    ref.invalidate(accountingSummaryProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(initial == null ? 'Regla creada.' : 'Regla actualizada.'),
      ),
    );
  }

  Future<void> _deleteRule(TrainerCommissionRuleModel rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => PulsoThemeScope(
        child: AlertDialog(
          title: const Text('Eliminar regla'),
          content: Text(
            'Se eliminará la regla de comisión para “${rule.planName}”.',
          ),
          actions: [
            PulsoSecondaryButton(
              label: 'Cancelar',
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            PulsoSecondaryButton(
              label: 'Eliminar',
              danger: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await ref.read(accountingRepositoryProvider).deleteTrainerRule(rule.id);
    ref.invalidate(trainerCommissionRulesProvider);
    ref.invalidate(accountingSummaryProvider);
  }
}

class _AccountingHeader extends StatelessWidget {
  const _AccountingHeader({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PulsoLabel('PULSO · FINANZAS Y NÓMINA'),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                text: 'CONTABILIDAD',
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
              'Comisiones, vencimientos y reglas de liquidación sin mezclar monedas.',
              style: TextStyle(color: tokens.muted, fontSize: 14),
            ),
          ],
        );
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PulsoSyncStatus(compact: true),
            const SizedBox(width: 8),
            PulsoIconButton(
              icon: Icons.refresh,
              tooltip: 'Actualizar contabilidad',
              onPressed: onRefresh,
            ),
          ],
        );
        if (constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [copy, const SizedBox(height: 14), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: copy),
            const SizedBox(width: 20),
            actions,
          ],
        );
      },
    );
  }
}

class _AccountingTabs extends StatelessWidget {
  const _AccountingTabs({required this.selected, required this.onSelected});
  final _AccountingTab selected;
  final ValueChanged<_AccountingTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return PulsoPanel(
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _TabButton(
              label: 'Resumen',
              selected: selected == _AccountingTab.summary,
              onTap: () => onSelected(_AccountingTab.summary),
            ),
            _TabButton(
              label: 'Cuotas entrenadores',
              selected: selected == _AccountingTab.installments,
              onTap: () => onSelected(_AccountingTab.installments),
            ),
            _TabButton(
              label: 'Reglas de comisión',
              selected: selected == _AccountingTab.rules,
              onTap: () => onSelected(_AccountingTab.rules),
            ),
            _TabButton(
              label: 'Nómina fija',
              selected: selected == _AccountingTab.payroll,
              onTap: () => onSelected(_AccountingTab.payroll),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
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
      color: selected ? tokens.accentSoft : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? tokens.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: selected ? tokens.accent : tokens.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrencyBreakdown extends StatelessWidget {
  const _CurrencyBreakdown({required this.values, required this.loading});
  final Map<String, double> values;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PulsoLabel('Pendiente por moneda'),
          const SizedBox(height: 5),
          Text(
            'Los importes se mantienen separados para evitar totales engañosos.',
            style: TextStyle(color: tokens.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (loading)
            LinearProgressIndicator(color: tokens.accent)
          else if (values.isEmpty)
            Text(
              'Sin importes pendientes.',
              style: TextStyle(color: tokens.muted),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final entry in values.entries)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    color: tokens.raised,
                    child: Text(
                      '${entry.key} ${_amount.format(entry.value)}',
                      style: TextStyle(
                        fontFamily: PulsoFonts.mono,
                        fontWeight: FontWeight.w700,
                        color: tokens.chalk,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SettlementPolicy extends StatelessWidget {
  const _SettlementPolicy({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PulsoPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PulsoLabel('Frecuencia de liquidación'),
          const SizedBox(height: 5),
          Text(
            'Preferencia operativa de esta vista; no altera cuotas existentes.',
            style: TextStyle(
              color: PulsoTokens.of(context).muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'WEEKLY', label: Text('Semanal')),
              ButtonSegment(value: 'BIWEEKLY', label: Text('Quincenal')),
              ButtonSegment(value: 'MONTHLY', label: Text('Mensual')),
            ],
            selected: {value},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ],
      ),
    );
  }
}

class _RuleCoverage extends StatelessWidget {
  const _RuleCoverage({required this.summary});
  final AccountingSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final total = summary.defaultRuleCount + summary.individualRuleCount;
    return PulsoPanel(
      padding: const EdgeInsets.all(18),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const PulsoLabel('Cobertura de reglas'),
          Text(
            '${summary.defaultRuleCount} generales',
            style: TextStyle(color: tokens.chalkDim),
          ),
          Text(
            '${summary.individualRuleCount} individuales',
            style: TextStyle(color: tokens.chalkDim),
          ),
          Text(
            '$total configuradas',
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontWeight: FontWeight.w700,
              color: tokens.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstallmentCatalog extends StatelessWidget {
  const _InstallmentCatalog({required this.items});
  final List<TrainerCommissionInstallmentModel> items;

  @override
  Widget build(BuildContext context) {
    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 760
            ? _InstallmentCards(items: items)
            : _InstallmentTable(items: items),
      ),
    );
  }
}

class _InstallmentTable extends StatelessWidget {
  const _InstallmentTable({required this.items});
  final List<TrainerCommissionInstallmentModel> items;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      children: [
        Container(
          color: tokens.raised,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: const Row(
            children: [
              Expanded(flex: 3, child: PulsoLabel('Entrenador')),
              Expanded(flex: 2, child: PulsoLabel('Programada')),
              Expanded(flex: 2, child: PulsoLabel('Periodo')),
              Expanded(flex: 2, child: PulsoLabel('Estado')),
              Expanded(flex: 2, child: PulsoLabel('Monto')),
            ],
          ),
        ),
        for (var index = 0; index < items.length; index++)
          _InstallmentRow(item: items[index], alternate: index.isOdd),
      ],
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  const _InstallmentRow({required this.item, required this.alternate});
  final TrainerCommissionInstallmentModel item;
  final bool alternate;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final overdue =
        item.status.toUpperCase() == 'PENDIENTE' &&
        item.scheduledDate.toUtc().isBefore(appClock.nowUtc());
    return Container(
      color: alternate ? tokens.raised.withValues(alpha: 0.55) : tokens.surface,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              item.trainerName,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: tokens.chalk,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _MonoText(_calendarDate(item.scheduledDate)),
          ),
          Expanded(
            flex: 2,
            child: _MonoText(
              '${_calendarDate(item.periodStart)}–${_calendarDate(item.periodEnd)}',
            ),
          ),
          Expanded(
            flex: 2,
            child: _MonoText(
              overdue ? 'VENCIDA' : item.status.toUpperCase(),
              color: overdue ? tokens.danger : tokens.warning,
            ),
          ),
          Expanded(
            flex: 2,
            child: _MonoText(
              '${item.currencyCode} ${_amount.format(item.amount)}',
              strong: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstallmentCards extends StatelessWidget {
  const _InstallmentCards({required this.items});
  final List<TrainerCommissionInstallmentModel> items;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  items[index].trainerName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tokens.chalk,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  children: [
                    _Datum(
                      label: 'Programada',
                      value: _calendarDate(items[index].scheduledDate),
                    ),
                    _Datum(label: 'Estado', value: items[index].status),
                    _Datum(
                      label: 'Monto',
                      value:
                          '${items[index].currencyCode} ${_amount.format(items[index].amount)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (index != items.length - 1) Divider(height: 1, color: tokens.line),
        ],
      ],
    );
  }
}

class _RuleCatalog extends StatelessWidget {
  const _RuleCatalog({
    required this.rules,
    required this.onEdit,
    required this.onDelete,
  });
  final List<TrainerCommissionRuleModel> rules;
  final ValueChanged<TrainerCommissionRuleModel> onEdit;
  final ValueChanged<TrainerCommissionRuleModel> onDelete;

  @override
  Widget build(BuildContext context) {
    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 760
            ? _RuleCards(rules: rules, onEdit: onEdit, onDelete: onDelete)
            : _RuleTable(rules: rules, onEdit: onEdit, onDelete: onDelete),
      ),
    );
  }
}

class _RuleTable extends StatelessWidget {
  const _RuleTable({
    required this.rules,
    required this.onEdit,
    required this.onDelete,
  });
  final List<TrainerCommissionRuleModel> rules;
  final ValueChanged<TrainerCommissionRuleModel> onEdit;
  final ValueChanged<TrainerCommissionRuleModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      children: [
        Container(
          color: tokens.raised,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: const Row(
            children: [
              Expanded(flex: 3, child: PulsoLabel('Plan')),
              Expanded(flex: 3, child: PulsoLabel('Entrenador')),
              Expanded(flex: 2, child: PulsoLabel('Cálculo')),
              Expanded(flex: 2, child: PulsoLabel('Estado')),
              SizedBox(width: 108, child: PulsoLabel('Acciones')),
            ],
          ),
        ),
        for (var index = 0; index < rules.length; index++)
          Container(
            color: index.isOdd
                ? tokens.raised.withValues(alpha: 0.55)
                : tokens.surface,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    rules[index].planName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tokens.chalk,
                    ),
                  ),
                ),
                Expanded(flex: 3, child: _MonoText(rules[index].trainerName)),
                Expanded(flex: 2, child: _MonoText(_ruleValue(rules[index]))),
                Expanded(
                  flex: 2,
                  child: _MonoText(
                    rules[index].active ? 'ACTIVA' : 'INACTIVA',
                    color: rules[index].active ? tokens.success : tokens.muted,
                  ),
                ),
                SizedBox(
                  width: 108,
                  child: Row(
                    children: [
                      PulsoIconButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Editar ${rules[index].planName}',
                        onPressed: () => onEdit(rules[index]),
                      ),
                      const SizedBox(width: 4),
                      PulsoIconButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Eliminar ${rules[index].planName}',
                        danger: true,
                        onPressed: () => onDelete(rules[index]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RuleCards extends StatelessWidget {
  const _RuleCards({
    required this.rules,
    required this.onEdit,
    required this.onDelete,
  });
  final List<TrainerCommissionRuleModel> rules;
  final ValueChanged<TrainerCommissionRuleModel> onEdit;
  final ValueChanged<TrainerCommissionRuleModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      children: [
        for (var index = 0; index < rules.length; index++) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        rules[index].planName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: tokens.chalk,
                        ),
                      ),
                    ),
                    PulsoIconButton(
                      icon: Icons.edit_outlined,
                      tooltip: 'Editar ${rules[index].planName}',
                      onPressed: () => onEdit(rules[index]),
                    ),
                    const SizedBox(width: 4),
                    PulsoIconButton(
                      icon: Icons.delete_outline,
                      tooltip: 'Eliminar ${rules[index].planName}',
                      danger: true,
                      onPressed: () => onDelete(rules[index]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  children: [
                    _Datum(
                      label: 'Entrenador',
                      value: rules[index].trainerName,
                    ),
                    _Datum(label: 'Cálculo', value: _ruleValue(rules[index])),
                    _Datum(
                      label: 'Estado',
                      value: rules[index].active ? 'Activa' : 'Inactiva',
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (index != rules.length - 1) Divider(height: 1, color: tokens.line),
        ],
      ],
    );
  }
}

String _ruleValue(TrainerCommissionRuleModel rule) => rule.type == 'PERCENTAGE'
    ? '${rule.value.toStringAsFixed(2)}%'
    : _amount.format(rule.value);

class _Datum extends StatelessWidget {
  const _Datum({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PulsoLabel(label),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: tokens.chalkDim,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonoText extends StatelessWidget {
  const _MonoText(this.text, {this.color, this.strong = false});
  final String text;
  final Color? color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: PulsoFonts.mono,
        fontSize: 10,
        fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
        color: color ?? tokens.chalkDim,
      ),
    );
  }
}

class _AccountingFooter extends StatelessWidget {
  const _AccountingFooter({required this.period});
  final String period;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final label = switch (period) {
      'WEEKLY' => 'semanal',
      'MONTHLY' => 'mensual',
      _ => 'quincenal',
    };
    return Text(
      'LECTURA CONTABLE · LIQUIDACIÓN $label · RELOJ ${appClock.gymTimezone}',
      style: TextStyle(
        fontFamily: PulsoFonts.mono,
        fontSize: 8,
        letterSpacing: 0.5,
        color: tokens.muted2,
      ),
    );
  }
}
