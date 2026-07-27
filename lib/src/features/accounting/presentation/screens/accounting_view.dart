import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../products/data/models/payment_plan_model.dart';
import '../../../products/presentation/state/payment_plan_notifier.dart';
import '../../../trainers/data/models/trainer_model.dart';
import '../../../trainers/presentation/providers/trainer_notifier.dart';
import '../../data/models/accounting_models.dart';
import '../../data/repositories/accounting_repository.dart';
import '../../data/services/trainer_liquidation_receipt_service.dart';
import '../state/accounting_providers.dart';
import '../widgets/compensation_profiles_panel.dart';
import '../widgets/governed_expenses_panel.dart';
import '../widgets/operational_cash_results_panel.dart';
import '../widgets/treasury_ledger_panel.dart';
import '../widgets/treasury_refunds_panel.dart';

enum _AccountingTab {
  summary,
  operationalResults,
  treasury,
  expenses,
  installments,
  refunds,
  rules,
  payroll,
}

final _amount = NumberFormat('#,##0.00');
final _date = DateFormat('dd/MM/yyyy');

// Estas fechas llegan como fechas contractuales/contables. Se presentan por
// componentes UTC para conservar el año/mes/día, sin usar la zona del equipo.
String _calendarDate(DateTime value) => _date.format(value.toUtc());

String _requestError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
  }
  return 'No se pudo completar la operación. Revise los datos e inténtelo de nuevo.';
}

class AccountingView extends ConsumerStatefulWidget {
  const AccountingView({super.key});

  @override
  ConsumerState<AccountingView> createState() => _AccountingViewState();
}

class _AccountingViewState extends ConsumerState<AccountingView> {
  _AccountingTab _tab = _AccountingTab.summary;
  String _period = 'BIWEEKLY';
  String? _expensesMonth;

  void _refresh() {
    ref.invalidate(accountingSummaryProvider);
    ref.invalidate(trainerCommissionInstallmentsProvider);
    ref.invalidate(trainerPayablesProvider);
    ref.invalidate(trainerCommissionRulesProvider);
    ref.invalidate(trainerPayoutOptionsProvider);
    ref.invalidate(trainerLiquidationsProvider);
    ref.invalidate(trainerCompensationProfilesProvider);
    ref.invalidate(trainerFixedObligationsProvider);
    ref.invalidate(treasuryRefundsProvider);
    ref.invalidate(treasuryRefundOptionsProvider);
    ref.invalidate(treasuryManualOptionsProvider);
    ref.invalidate(treasuryLedgerProvider);
    ref.invalidate(treasuryMonthlySummaryProvider);
    ref.invalidate(operationalResultsProvider);
    ref.invalidate(operationalAnnualResultsProvider);
    ref.invalidate(membershipRevenueProvider);
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
        final content = switch (_tab) {
          _AccountingTab.summary => _buildSummary(),
          _AccountingTab.operationalResults => OperationalCashResultsPanel(
            onOpenTrainerPayments: () =>
                setState(() => _tab = _AccountingTab.installments),
            onOpenRefunds: () => setState(() => _tab = _AccountingTab.refunds),
            onOpenTreasury: () =>
                setState(() => _tab = _AccountingTab.treasury),
          ),
          _AccountingTab.treasury => _buildTreasury(),
          _AccountingTab.expenses => GovernedExpensesPanel(
            initialMonth: _expensesMonth,
            onMonthChanged: (m) => setState(() => _expensesMonth = m),
            onBack: () => setState(() => _tab = _AccountingTab.summary),
          ),
          _AccountingTab.installments => _buildInstallments(),
          _AccountingTab.refunds => _buildRefunds(),
          _AccountingTab.rules => _buildRules(),
          _AccountingTab.payroll => _buildPayroll(),
        };
        final pagePadding = EdgeInsets.fromLTRB(
          padding,
          compact ? 16 : 20,
          padding,
          compact ? 18 : 24,
        );
        final contentOwnsVerticalScroll =
            _tab == _AccountingTab.operationalResults ||
            _tab == _AccountingTab.expenses;
        if (contentOwnsVerticalScroll) {
          return Padding(
            padding: pagePadding,
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
                Expanded(child: content),
                const SizedBox(height: 10),
                _AccountingFooter(period: _period),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: pagePadding,
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
              content,
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
    final payablesState = ref.watch(trainerPayablesProvider);
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
        final payables = payablesState.value ?? const <TrainerPayableModel>[];
        final byCurrency = <String, double>{};
        for (final item in payables) {
          final code = item.currencyCode.trim().isEmpty
              ? 'SIN MONEDA'
              : item.currencyCode.toUpperCase();
          byCurrency[code] = (byCurrency[code] ?? 0) + item.remainingAmount;
        }
        final commissionPending = payables
            .where((item) => item.isCommission)
            .length;
        final fixedPending = payables.where((item) => item.isFixed).length;
        final overdue = payables
            .where(
              (item) =>
                  item.payable &&
                  item.scheduledDate.toUtc().isBefore(appClock.nowUtc()),
            )
            .length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PulsoMetricStrip(
              metrics: [
                PulsoMetricData(
                  value:
                      '${payablesState.hasValue ? payables.length : summary.pendingTrainerCount}',
                  label: 'Conceptos pendientes',
                  note: payablesState.hasValue
                      ? '$commissionPending comisión · $fixedPending fijo'
                      : 'pagos por liquidar',
                  emphasis: true,
                ),
                PulsoMetricData(
                  value:
                      '${payablesState.hasValue ? overdue : summary.overdueTrainerCount}',
                  label: 'Vencidas',
                  note: 'requieren revisión',
                  warning: payablesState.hasValue
                      ? overdue > 0
                      : summary.overdueTrainerCount > 0,
                ),
                PulsoMetricData(
                  value: '${summary.activeRuleCount}',
                  label: 'Reglas activas',
                  note: summary.conflictRuleCount > 0
                      ? '${summary.conflictRuleCount} con conflicto'
                      : '${summary.scheduledRuleCount} programadas',
                  warning: summary.conflictRuleCount > 0,
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
                  loading: payablesState.isLoading,
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
    final state = ref.watch(trainerPayablesProvider);
    final history = ref.watch(trainerLiquidationsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        state.when(
          loading: () => const PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.loading,
              message: 'Cargando pagos pendientes de entrenadores…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message: 'No se pudieron cargar los pagos pendientes.\n$error',
              onRetry: _refresh,
            ),
          ),
          data: (items) => items.isEmpty
              ? const PulsoPanel(
                  child: PulsoStateView(
                    kind: PulsoStateKind.empty,
                    message:
                        'No hay comisiones ni obligaciones fijas pendientes.',
                  ),
                )
              : _InstallmentCatalog(
                  items: items,
                  onLiquidate: _openLiquidationDialog,
                ),
        ),
        const SizedBox(height: 14),
        _LiquidationHistory(
          state: history,
          onOpen: _openLiquidationReceipt,
          onRetry: _refresh,
        ),
      ],
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
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RuleGuide(rules: rules),
                    const SizedBox(height: 12),
                    _RuleCatalog(
                      rules: rules,
                      onEdit: _openRuleDialog,
                      onDelete: _deleteRule,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildPayroll() {
    return CompensationProfilesPanel(onChanged: _refresh);
  }

  Widget _buildTreasury() {
    return TreasuryLedgerPanel(onChanged: _refresh);
  }

  Widget _buildRefunds() {
    return TreasuryRefundsPanel(onChanged: _refresh);
  }

  Future<void> _openLiquidationDialog(
    List<TrainerPayableModel> installments,
  ) async {
    if (installments.isEmpty) return;
    final options = await ref.read(trainerPayoutOptionsProvider.future);
    if (!mounted) return;
    final currencyId = installments.first.currencyId;
    final accounts = options.accounts
        .where((account) => account.currencyId == currencyId)
        .toList();
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No existe una cuenta de salida para ${installments.first.currencyCode}.',
          ),
        ),
      );
      return;
    }
    final operationId = const Uuid().v4();
    final amountControllers = {
      for (final item in installments)
        item.id: TextEditingController(
          text: item.remainingAmount.toStringAsFixed(2),
        ),
    };
    final notesController = TextEditingController();
    String? accountId = accounts.first.id;
    String? paymentTypeId =
        accounts.first.paymentTypeId ?? options.methods.firstOrNull?.id;
    bool saving = false;
    String? error;

    final receipt = await showDialog<TrainerLiquidationModel>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PulsoThemeScope(
        child: StatefulBuilder(
          builder: (context, setLocalState) {
            final tokens = PulsoTokens.of(context);
            final compactPaymentFields = MediaQuery.sizeOf(context).width < 700;
            final selectedAccount = accounts
                .where((account) => account.id == accountId)
                .firstOrNull;
            final compatibleMethods = selectedAccount?.paymentTypeId == null
                ? options.methods
                : options.methods
                      .where(
                        (method) => method.id == selectedAccount!.paymentTypeId,
                      )
                      .toList();
            final total = amountControllers.values.fold<double>(
              0,
              (sum, controller) =>
                  sum +
                  (double.tryParse(controller.text.replaceAll(',', '.')) ?? 0),
            );
            double subtotal(bool fixed) => installments
                .where((item) => item.isFixed == fixed)
                .fold<double>(
                  0,
                  (sum, item) =>
                      sum +
                      (double.tryParse(
                            amountControllers[item.id]!.text.replaceAll(
                              ',',
                              '.',
                            ),
                          ) ??
                          0),
                );
            final commissionTotal = subtotal(false);
            final fixedTotal = subtotal(true);
            final accountField = DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: accountId,
              decoration: const InputDecoration(labelText: 'Cuenta de salida'),
              items: [
                for (final account in accounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(
                      '${account.name} · ${account.currencyCode}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                setLocalState(() {
                  accountId = value;
                  final selected = accounts
                      .where((item) => item.id == value)
                      .firstOrNull;
                  paymentTypeId =
                      selected?.paymentTypeId ??
                      options.methods.firstOrNull?.id;
                });
              },
            );
            final methodField = DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue:
                  compatibleMethods.any((item) => item.id == paymentTypeId)
                  ? paymentTypeId
                  : null,
              decoration: const InputDecoration(labelText: 'Método de salida'),
              items: [
                for (final method in compatibleMethods)
                  DropdownMenuItem(value: method.id, child: Text(method.name)),
              ],
              onChanged: compatibleMethods.length == 1
                  ? null
                  : (value) => setLocalState(() => paymentTypeId = value),
            );
            return AlertDialog(
              title: const Text('Liquidar entrenador'),
              content: SizedBox(
                width: 660,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        color: tokens.raised,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const PulsoLabel('Entrenador'),
                                  const SizedBox(height: 4),
                                  Text(
                                    installments.first.trainerName,
                                    style: TextStyle(
                                      color: tokens.chalk,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${installments.first.currencyCode} ${_amount.format(total)}',
                                  style: TextStyle(
                                    color: tokens.accent,
                                    fontFamily: PulsoFonts.display,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Comisión ${_amount.format(commissionTotal)} · fijo ${_amount.format(fixedTotal)}',
                                  style: TextStyle(
                                    color: tokens.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const PulsoLabel('Aplicación por concepto y periodo'),
                      const SizedBox(height: 8),
                      _LiquidationApplicationEditor(
                        items: installments,
                        controllers: amountControllers,
                        onChanged: () => setLocalState(() {}),
                      ),
                      const SizedBox(height: 4),
                      if (compactPaymentFields)
                        Column(
                          children: [
                            accountField,
                            const SizedBox(height: 12),
                            methodField,
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(child: accountField),
                            const SizedBox(width: 12),
                            Expanded(child: methodField),
                          ],
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        maxLength: 500,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notas (opcional)',
                          hintText: 'Referencia del pago o detalle operativo',
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          error!,
                          style: TextStyle(color: tokens.danger, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'El comprobante conservará cada aplicación. Una corrección posterior se registra como contramovimiento; no borra este pago.',
                        style: TextStyle(color: tokens.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                PulsoSecondaryButton(
                  label: 'Cancelar',
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                ),
                PulsoPrimaryButton(
                  label: 'Confirmar pago',
                  busy: saving,
                  onPressed:
                      saving || accountId == null || paymentTypeId == null
                      ? null
                      : () async {
                          final applications = <Map<String, dynamic>>[];
                          final fixedApplications = <Map<String, dynamic>>[];
                          for (final item in installments) {
                            final value = double.tryParse(
                              amountControllers[item.id]!.text.replaceAll(
                                ',',
                                '.',
                              ),
                            );
                            if (value == null ||
                                value <= 0 ||
                                value > item.remainingAmount + 0.0001) {
                              setLocalState(() {
                                error =
                                    'Revise el importe de ${_calendarDate(item.periodEnd)}; debe ser mayor que cero y no superar el saldo.';
                              });
                              return;
                            }
                            final payload = {
                              if (item.isFixed)
                                'obligacion_id': item.id
                              else
                                'cuota_id': item.id,
                              'monto': value.toStringAsFixed(2),
                            };
                            if (item.isFixed) {
                              fixedApplications.add(payload);
                            } else {
                              applications.add(payload);
                            }
                          }
                          setLocalState(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            final result = await ref
                                .read(accountingRepositoryProvider)
                                .createTrainerLiquidation(
                                  operationId: operationId,
                                  accountId: accountId!,
                                  paymentTypeId: paymentTypeId!,
                                  applications: applications,
                                  fixedApplications: fixedApplications,
                                  notes: notesController.text.trim(),
                                );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(result);
                            }
                          } catch (caught) {
                            setLocalState(() {
                              saving = false;
                              error = _requestError(caught);
                            });
                          }
                        },
                ),
              ],
            );
          },
        ),
      ),
    );
    for (final controller in amountControllers.values) {
      controller.dispose();
    }
    notesController.dispose();
    if (receipt == null || !mounted) return;
    _refresh();
    await _showLiquidationReceipt(receipt);
  }

  Future<void> _openLiquidationReceipt(TrainerLiquidationModel item) async {
    try {
      final receipt = await ref
          .read(accountingRepositoryProvider)
          .getTrainerLiquidation(item.id);
      if (!mounted) return;
      await _showLiquidationReceipt(receipt);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_requestError(error))));
    }
  }

  Future<void> _showLiquidationReceipt(TrainerLiquidationModel receipt) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => PulsoThemeScope(
        child: AlertDialog(
          title: Text(receipt.receiptNumber),
          content: SizedBox(
            width: 620,
            child: _LiquidationReceipt(receipt: receipt),
          ),
          actions: [
            if (receipt.status == 'PAGADA')
              PulsoSecondaryButton(
                label: 'Registrar reverso',
                danger: true,
                onPressed: () => Navigator.of(dialogContext).pop('reverse'),
              ),
            PulsoSecondaryButton(
              label: 'Imprimir',
              icon: Icons.print_outlined,
              onPressed: () async {
                await const TrainerLiquidationReceiptService().printReceipt(
                  receipt,
                );
              },
            ),
            PulsoPrimaryButton(
              label: 'Cerrar',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
      ),
    );
    if (action == 'reverse' && mounted) {
      await _reverseLiquidation(receipt);
    }
  }

  Future<void> _reverseLiquidation(TrainerLiquidationModel receipt) async {
    final controller = TextEditingController();
    String? error;
    bool saving = false;
    final reversed = await showDialog<TrainerLiquidationModel>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PulsoThemeScope(
        child: StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            title: const Text('Registrar contramovimiento'),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Se anulará ${receipt.receiptNumber} por ${receipt.currencyCode} ${_amount.format(receipt.total)}. Las cuotas recuperarán solo el saldo de este pago.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Motivo obligatorio',
                      errorText: error,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              PulsoSecondaryButton(
                label: 'Cancelar',
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
              ),
              PulsoPrimaryButton(
                label: 'Confirmar reverso',
                busy: saving,
                onPressed: saving
                    ? null
                    : () async {
                        final reason = controller.text.trim();
                        if (reason.length < 8) {
                          setLocalState(
                            () => error =
                                'Escriba un motivo de al menos 8 caracteres.',
                          );
                          return;
                        }
                        setLocalState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final result = await ref
                              .read(accountingRepositoryProvider)
                              .reverseTrainerLiquidation(
                                id: receipt.id,
                                operationId: const Uuid().v4(),
                                reason: reason,
                              );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(result);
                          }
                        } catch (caught) {
                          setLocalState(() {
                            saving = false;
                            error = _requestError(caught);
                          });
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (reversed == null || !mounted) return;
    _refresh();
    await _showLiquidationReceipt(reversed);
  }

  Future<void> _openRuleDialog([TrainerCommissionRuleModel? initial]) async {
    final plans =
        (ref.read(paymentPlanProvider).value ?? const <PaymentPlanModel>[])
            .where(
              (plan) =>
                  plan.id != null &&
                  plan.activo &&
                  !plan.isDeleted &&
                  plan.incluyeEntrenador,
            )
            .toList();
    final trainers = (ref.read(trainerProvider).value ?? const <TrainerModel>[])
        .where((trainer) => trainer.activo && !trainer.isDeleted)
        .toList();
    String? planId = initial?.planId;
    String? trainerId = initial?.trainerId;
    String type = initial?.type ?? 'PERCENTAGE';
    DateTime startDate =
        initial?.startDate.toUtc() ??
        calendarDateToUtc(todayInZone(appClock.gymTimezone));
    DateTime? endDate = initial?.endDate?.toUtc();
    final replacingCurrent = initial?.validityStatus == 'VIGENTE';
    bool saving = false;
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
                        onChanged: plans.isEmpty || replacingCurrent
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
                        onChanged: replacingCurrent
                            ? null
                            : (value) => setLocalState(() => trainerId = value),
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
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _RuleDateField(
                              label: 'Inicio de vigencia',
                              value: startDate,
                              enabled: !replacingCurrent,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setLocalState(() {
                                    startDate = calendarDateToUtc(picked);
                                    if (endDate != null &&
                                        !endDate!.isAfter(startDate)) {
                                      endDate = null;
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _RuleDateField(
                              label: 'Fin (no incluye)',
                              value: endDate,
                              onTap: () async {
                                final initialEnd =
                                    endDate ??
                                    startDate.add(const Duration(days: 30));
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: initialEnd,
                                  firstDate: startDate.add(
                                    const Duration(days: 1),
                                  ),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setLocalState(
                                    () => endDate = calendarDateToUtc(picked),
                                  );
                                }
                              },
                              onClear: endDate == null
                                  ? null
                                  : () => setLocalState(() => endDate = null),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: tokens.raised,
                        child: Text(
                          replacingCurrent
                              ? 'Al guardar, la vigencia actual se cerrará ahora y se creará una nueva. Los devengos anteriores conservarán su cálculo.'
                              : 'La excepción de un entrenador tiene prioridad sobre la regla general del mismo plan. Las vigencias del mismo alcance no pueden solaparse.',
                          style: TextStyle(color: tokens.muted, fontSize: 12),
                        ),
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
                  busy: saving,
                  onPressed: planId == null || saving
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
                            'activo': true,
                            'fecha_inicio': startDate.toUtc().toIso8601String(),
                            'fecha_fin': endDate?.toUtc().toIso8601String(),
                          };
                          setLocalState(() {
                            saving = true;
                            error = null;
                          });
                          try {
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
                          } catch (caught) {
                            setLocalState(() {
                              saving = false;
                              error = _requestError(caught);
                            });
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
    final scheduled = rule.validityStatus == 'PROGRAMADA';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => PulsoThemeScope(
        child: AlertDialog(
          title: Text(
            scheduled ? 'Cancelar regla programada' : 'Finalizar regla',
          ),
          content: Text(
            scheduled
                ? 'La regla de “${rule.planName}” todavía no comenzó y se cancelará.'
                : 'La regla de “${rule.planName}” terminará ahora. Su historial y los devengos ya calculados se conservarán.',
          ),
          actions: [
            PulsoSecondaryButton(
              label: 'Cancelar',
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            PulsoSecondaryButton(
              label: scheduled ? 'Cancelar regla' : 'Finalizar',
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(scheduled ? 'Regla cancelada.' : 'Vigencia finalizada.'),
      ),
    );
  }
}

class _RuleDateField extends StatelessWidget {
  const _RuleDateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
    this.enabled = true,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return InkWell(
      onTap: enabled ? onTap : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear != null
              ? IconButton(
                  tooltip: 'Sin fecha de fin',
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 17),
                )
              : const Icon(Icons.calendar_today_outlined, size: 17),
        ),
        child: Text(
          value == null ? 'Sin fecha' : _calendarDate(value!),
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: 11,
            color: enabled ? tokens.chalkDim : tokens.muted,
          ),
        ),
      ),
    );
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
              label: 'Tesorería · cierre',
              selected: selected == _AccountingTab.treasury,
              onTap: () => onSelected(_AccountingTab.treasury),
            ),
            _TabButton(
              label: 'Gastos devengados',
              selected: selected == _AccountingTab.expenses,
              onTap: () => onSelected(_AccountingTab.expenses),
            ),
            _TabButton(
              label: 'Cuotas entrenadores',
              selected: selected == _AccountingTab.installments,
              onTap: () => onSelected(_AccountingTab.installments),
            ),
            _TabButton(
              label: 'Tesorería · reembolsos',
              selected: selected == _AccountingTab.refunds,
              onTap: () => onSelected(_AccountingTab.refunds),
            ),
            _TabButton(
              label: 'Reglas de comisión',
              selected: selected == _AccountingTab.rules,
              onTap: () => onSelected(_AccountingTab.rules),
            ),
            _TabButton(
              label: 'Perfiles y nómina',
              selected: selected == _AccountingTab.payroll,
              onTap: () => onSelected(_AccountingTab.payroll),
            ),
            _TabButton(
              label: 'Resultado de caja',
              selected: selected == _AccountingTab.operationalResults,
              onTap: () => onSelected(_AccountingTab.operationalResults),
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

class _RuleGuide extends StatelessWidget {
  const _RuleGuide({required this.rules});
  final List<TrainerCommissionRuleModel> rules;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final conflicts = rules.where((rule) => rule.hasConflict).length;
    final scheduled = rules
        .where((rule) => rule.validityStatus == 'PROGRAMADA')
        .length;
    return PulsoPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            conflicts > 0 ? Icons.warning_amber_outlined : Icons.rule_outlined,
            color: conflicts > 0 ? tokens.danger : tokens.accent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conflicts > 0
                      ? '$conflicts reglas requieren resolver su vigencia'
                      : 'Excepción individual primero; regla general después',
                  style: TextStyle(
                    color: tokens.chalk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  conflicts > 0
                      ? 'Puede ocurrir si dos equipos crean reglas del mismo alcance sin conexión. La selección del cobro sigue siendo determinista, pero conviene corregir las fechas.'
                      : '$scheduled programadas · las reglas finalizadas se conservan para auditoría y nunca cambian devengos anteriores.',
                  style: TextStyle(color: tokens.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiquidationApplicationEditor extends StatefulWidget {
  const _LiquidationApplicationEditor({
    required this.items,
    required this.controllers,
    required this.onChanged,
  });

  final List<TrainerPayableModel> items;
  final Map<String, TextEditingController> controllers;
  final VoidCallback onChanged;

  @override
  State<_LiquidationApplicationEditor> createState() =>
      _LiquidationApplicationEditorState();
}

class _LiquidationApplicationEditorState
    extends State<_LiquidationApplicationEditor> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return SizedBox(
      height: (widget.items.length * 76.0).clamp(76.0, 244.0),
      child: Scrollbar(
        key: const Key('trainer-liquidation-editor-scrollbar'),
        controller: _controller,
        thumbVisibility: widget.items.length > 3,
        child: ListView.separated(
          controller: _controller,
          itemCount: widget.items.length,
          separatorBuilder: (_, _) => Divider(height: 1, color: tokens.line),
          itemBuilder: (context, index) {
            final item = widget.items[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.sourceLabel.toUpperCase()} · ${_calendarDate(item.periodStart)} – ${_calendarDate(item.periodEnd)}',
                          style: TextStyle(
                            color: tokens.chalk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Saldo ${item.currencyCode} ${_amount.format(item.remainingAmount)}'
                          '${item.appliedAmount > 0 ? ' · abonado ${_amount.format(item.appliedAmount)}' : ''}',
                          style: TextStyle(color: tokens.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: widget.controllers[item.id],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Importe',
                        prefixText: '${item.currencyCode} ',
                      ),
                      onChanged: (_) => widget.onChanged(),
                    ),
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

class _InstallmentCatalog extends StatefulWidget {
  const _InstallmentCatalog({required this.items, required this.onLiquidate});
  final List<TrainerPayableModel> items;
  final ValueChanged<List<TrainerPayableModel>> onLiquidate;

  @override
  State<_InstallmentCatalog> createState() => _InstallmentCatalogState();
}

class _InstallmentCatalogState extends State<_InstallmentCatalog> {
  final Set<String> _selected = {};

  List<TrainerPayableModel> get _selectedItems =>
      widget.items.where((item) => _selected.contains(item.id)).toList();

  bool _compatible(TrainerPayableModel item) {
    final first = _selectedItems.firstOrNull;
    return first == null ||
        (first.trainerId == item.trainerId &&
            first.currencyId == item.currencyId);
  }

  void _toggle(TrainerPayableModel item, bool value) {
    setState(() {
      if (value) {
        _selected.add(item.id);
      } else {
        _selected.remove(item.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final selected = _selectedItems;
    final total = selected.fold<double>(
      0,
      (sum, item) => sum + item.remainingAmount,
    );
    final commissionTotal = selected
        .where((item) => item.isCommission)
        .fold<double>(0, (sum, item) => sum + item.remainingAmount);
    final fixedTotal = selected
        .where((item) => item.isFixed)
        .fold<double>(0, (sum, item) => sum + item.remainingAmount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PulsoPanel(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final summary = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PulsoLabel('Preparar liquidación'),
                  const SizedBox(height: 4),
                  Text(
                    selected.isEmpty
                        ? 'Seleccione conceptos del mismo entrenador y moneda.'
                        : '${selected.length} concepto(s) · ${selected.first.currencyCode} ${_amount.format(total)} · comisión ${_amount.format(commissionTotal)} · fijo ${_amount.format(fixedTotal)}',
                    style: TextStyle(
                      color: selected.isEmpty ? tokens.muted : tokens.chalk,
                      fontWeight: selected.isEmpty
                          ? FontWeight.w400
                          : FontWeight.w700,
                    ),
                  ),
                ],
              );
              final button = PulsoPrimaryButton(
                label: 'Liquidar selección',
                icon: Icons.payments_outlined,
                onPressed: selected.isEmpty
                    ? null
                    : () => widget.onLiquidate(selected),
              );
              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [summary, const SizedBox(height: 12), button],
                );
              }
              return Row(
                children: [
                  Expanded(child: summary),
                  const SizedBox(width: 16),
                  button,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        PulsoPanel(
          padding: EdgeInsets.zero,
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 760
                ? _InstallmentCards(
                    items: widget.items,
                    selected: _selected,
                    compatible: _compatible,
                    onToggle: _toggle,
                  )
                : _InstallmentTable(
                    items: widget.items,
                    selected: _selected,
                    compatible: _compatible,
                    onToggle: _toggle,
                  ),
          ),
        ),
      ],
    );
  }
}

class _InstallmentTable extends StatefulWidget {
  const _InstallmentTable({
    required this.items,
    required this.selected,
    required this.compatible,
    required this.onToggle,
  });
  final List<TrainerPayableModel> items;
  final Set<String> selected;
  final bool Function(TrainerPayableModel) compatible;
  final void Function(TrainerPayableModel, bool) onToggle;

  @override
  State<_InstallmentTable> createState() => _InstallmentTableState();
}

class _InstallmentTableState extends State<_InstallmentTable> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
              SizedBox(width: 44),
              Expanded(flex: 3, child: PulsoLabel('Entrenador')),
              Expanded(flex: 2, child: PulsoLabel('Concepto')),
              Expanded(flex: 2, child: PulsoLabel('Programada')),
              Expanded(flex: 2, child: PulsoLabel('Periodo')),
              Expanded(flex: 2, child: PulsoLabel('Estado')),
              Expanded(flex: 2, child: PulsoLabel('Monto')),
            ],
          ),
        ),
        SizedBox(
          height: (widget.items.length * 58.0).clamp(58.0, 360.0),
          child: Scrollbar(
            key: const Key('trainer-payables-table-scrollbar'),
            controller: _controller,
            thumbVisibility: widget.items.length > 6,
            child: ListView.builder(
              controller: _controller,
              itemCount: widget.items.length,
              itemExtent: 58,
              itemBuilder: (context, index) => _InstallmentRow(
                item: widget.items[index],
                alternate: index.isOdd,
                selected: widget.selected.contains(widget.items[index].id),
                enabled:
                    widget.items[index].payable &&
                    widget.compatible(widget.items[index]),
                onChanged: (value) =>
                    widget.onToggle(widget.items[index], value),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  const _InstallmentRow({
    required this.item,
    required this.alternate,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });
  final TrainerPayableModel item;
  final bool alternate;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onChanged;

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
          SizedBox(
            width: 44,
            child: Checkbox(
              value: selected,
              onChanged: enabled ? (value) => onChanged(value ?? false) : null,
            ),
          ),
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
            child: _MonoText(
              item.sourceLabel.toUpperCase(),
              color: item.isFixed ? tokens.accent : tokens.chalkDim,
              strong: true,
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
              !item.payable
                  ? 'FUTURA'
                  : overdue
                  ? 'VENCIDA'
                  : item.status.toUpperCase(),
              color: !item.payable
                  ? tokens.muted
                  : overdue
                  ? tokens.danger
                  : tokens.warning,
            ),
          ),
          Expanded(
            flex: 2,
            child: _MonoText(
              '${item.currencyCode} ${_amount.format(item.remainingAmount)}',
              strong: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstallmentCards extends StatefulWidget {
  const _InstallmentCards({
    required this.items,
    required this.selected,
    required this.compatible,
    required this.onToggle,
  });
  final List<TrainerPayableModel> items;
  final Set<String> selected;
  final bool Function(TrainerPayableModel) compatible;
  final void Function(TrainerPayableModel, bool) onToggle;

  @override
  State<_InstallmentCards> createState() => _InstallmentCardsState();
}

class _InstallmentCardsState extends State<_InstallmentCards> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return SizedBox(
      height: (widget.items.length * 178.0).clamp(178.0, 420.0),
      child: Scrollbar(
        key: const Key('trainer-payables-cards-scrollbar'),
        controller: _controller,
        thumbVisibility: widget.items.length > 2,
        child: ListView.separated(
          controller: _controller,
          itemCount: widget.items.length,
          separatorBuilder: (_, _) => Divider(height: 1, color: tokens.line),
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: widget.selected.contains(widget.items[index].id),
                      onChanged:
                          widget.items[index].payable &&
                              widget.compatible(widget.items[index])
                          ? (value) => widget.onToggle(
                              widget.items[index],
                              value ?? false,
                            )
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.items[index].trainerName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: tokens.chalk,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  children: [
                    _Datum(
                      label: 'Concepto',
                      value: widget.items[index].sourceLabel,
                    ),
                    _Datum(
                      label: 'Programada',
                      value: _calendarDate(widget.items[index].scheduledDate),
                    ),
                    _Datum(label: 'Estado', value: widget.items[index].status),
                    _Datum(
                      label: 'Saldo',
                      value:
                          '${widget.items[index].currencyCode} ${_amount.format(widget.items[index].remainingAmount)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidationHistory extends StatelessWidget {
  const _LiquidationHistory({
    required this.state,
    required this.onOpen,
    required this.onRetry,
  });

  final AsyncValue<List<TrainerLiquidationModel>> state;
  final ValueChanged<TrainerLiquidationModel> onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PulsoLabel('Tesorería', color: tokens.accent),
                  const SizedBox(height: 5),
                  Text(
                    'Liquidaciones recientes',
                    style: TextStyle(
                      color: tokens.chalk,
                      fontFamily: PulsoFonts.display,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Comprobantes pagados y contramovimientos, sin borrar el historial.',
                    style: TextStyle(color: tokens.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        state.when(
          loading: () => const PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.loading,
              message: 'Cargando liquidaciones…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message: 'No se pudo cargar el historial.\n$error',
              onRetry: onRetry,
            ),
          ),
          data: (items) => items.isEmpty
              ? const PulsoPanel(
                  child: PulsoStateView(
                    kind: PulsoStateKind.empty,
                    message: 'Todavía no se ha emitido ninguna liquidación.',
                  ),
                )
              : PulsoPanel(
                  padding: EdgeInsets.zero,
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth < 760
                        ? _LiquidationHistoryCards(items: items, onOpen: onOpen)
                        : _LiquidationHistoryTable(
                            items: items,
                            onOpen: onOpen,
                          ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _LiquidationHistoryTable extends StatefulWidget {
  const _LiquidationHistoryTable({required this.items, required this.onOpen});
  final List<TrainerLiquidationModel> items;
  final ValueChanged<TrainerLiquidationModel> onOpen;

  @override
  State<_LiquidationHistoryTable> createState() =>
      _LiquidationHistoryTableState();
}

class _LiquidationHistoryTableState extends State<_LiquidationHistoryTable> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
              Expanded(flex: 2, child: PulsoLabel('Comprobante')),
              Expanded(flex: 3, child: PulsoLabel('Entrenador')),
              Expanded(flex: 2, child: PulsoLabel('Fecha')),
              Expanded(flex: 2, child: PulsoLabel('Estado')),
              Expanded(flex: 2, child: PulsoLabel('Total')),
              SizedBox(width: 48),
            ],
          ),
        ),
        SizedBox(
          height: (widget.items.length * 62.0).clamp(62.0, 310.0),
          child: Scrollbar(
            key: const Key('trainer-liquidations-table-scrollbar'),
            controller: _controller,
            thumbVisibility: widget.items.length > 5,
            child: ListView.builder(
              controller: _controller,
              itemCount: widget.items.length,
              itemExtent: 62,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return Container(
                  color: index.isOdd
                      ? tokens.raised.withValues(alpha: 0.55)
                      : tokens.surface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _MonoText(item.receiptNumber, strong: true),
                            if (item.type == 'BAJA_FINAL')
                              Text(
                                'BAJA FINAL',
                                style: TextStyle(
                                  color: tokens.accent,
                                  fontFamily: PulsoFonts.mono,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          item.trainerName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.chalk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _MonoText(
                          formatDateInZone(
                            item.paidAt,
                            appClock.gymTimezone,
                            pattern: 'dd/MM/yyyy HH:mm',
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _MonoText(
                          item.status,
                          color: item.status == 'PAGADA'
                              ? tokens.success
                              : tokens.danger,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _MonoText(
                              '${item.currencyCode} ${_amount.format(item.total)}',
                              strong: true,
                            ),
                            Text(
                              'C ${_amount.format(item.commissionTotal)} · F ${_amount.format(item.fixedTotal)}',
                              style: TextStyle(
                                color: tokens.muted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: PulsoIconButton(
                          icon: Icons.receipt_long_outlined,
                          tooltip: 'Ver ${item.receiptNumber}',
                          onPressed: () => widget.onOpen(item),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _LiquidationHistoryCards extends StatefulWidget {
  const _LiquidationHistoryCards({required this.items, required this.onOpen});
  final List<TrainerLiquidationModel> items;
  final ValueChanged<TrainerLiquidationModel> onOpen;

  @override
  State<_LiquidationHistoryCards> createState() =>
      _LiquidationHistoryCardsState();
}

class _LiquidationHistoryCardsState extends State<_LiquidationHistoryCards> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return SizedBox(
      height: (widget.items.length * 155.0).clamp(155.0, 380.0),
      child: Scrollbar(
        key: const Key('trainer-liquidations-cards-scrollbar'),
        controller: _controller,
        thumbVisibility: widget.items.length > 2,
        child: ListView.separated(
          controller: _controller,
          itemCount: widget.items.length,
          separatorBuilder: (_, _) => Divider(height: 1, color: tokens.line),
          itemBuilder: (context, index) {
            final item = widget.items[index];
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MonoText(item.receiptNumber, strong: true),
                        const SizedBox(height: 6),
                        Text(
                          item.trainerName,
                          style: TextStyle(
                            color: tokens.chalk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 18,
                          runSpacing: 10,
                          children: [
                            _Datum(label: 'Estado', value: item.status),
                            _Datum(
                              label: 'Total',
                              value:
                                  '${item.currencyCode} ${_amount.format(item.total)}',
                            ),
                            _Datum(
                              label: 'Desglose',
                              value:
                                  'Comisión ${_amount.format(item.commissionTotal)} · fijo ${_amount.format(item.fixedTotal)}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PulsoIconButton(
                    icon: Icons.receipt_long_outlined,
                    tooltip: 'Ver comprobante',
                    onPressed: () => widget.onOpen(item),
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

class _LiquidationReceipt extends StatelessWidget {
  const _LiquidationReceipt({required this.receipt});
  final TrainerLiquidationModel receipt;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: tokens.raised,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PulsoLabel(
                        receipt.status,
                        color: receipt.status == 'PAGADA'
                            ? tokens.success
                            : tokens.danger,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        receipt.trainerName,
                        style: TextStyle(
                          color: tokens.chalk,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${receipt.currencyCode} ${_amount.format(receipt.total)}',
                      style: TextStyle(
                        color: tokens.accent,
                        fontFamily: PulsoFonts.display,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Comisión ${_amount.format(receipt.commissionTotal)} · fijo ${_amount.format(receipt.fixedTotal)}',
                      style: TextStyle(color: tokens.muted, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 24,
            runSpacing: 14,
            children: [
              _Datum(
                label: 'Fecha',
                value: formatDateInZone(
                  receipt.paidAt,
                  appClock.gymTimezone,
                  pattern: 'dd/MM/yyyy HH:mm',
                ),
              ),
              _Datum(label: 'Cuenta', value: receipt.accountName),
              _Datum(label: 'Método', value: receipt.paymentTypeName),
              _Datum(label: 'Registró', value: receipt.operatorName),
            ],
          ),
          if (receipt.notes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Text(receipt.notes!, style: TextStyle(color: tokens.chalkDim)),
          ],
          const SizedBox(height: 16),
          PulsoLabel(
            'Comisiones · ${receipt.currencyCode} ${_amount.format(receipt.commissionTotal)}',
          ),
          const SizedBox(height: 8),
          for (final item in receipt.applications)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: tokens.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.periodStart == null || item.periodEnd == null
                          ? item.installmentId
                          : '${_calendarDate(item.periodStart!)} – ${_calendarDate(item.periodEnd!)}',
                      style: TextStyle(color: tokens.chalkDim),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _MonoText(
                    '${receipt.currencyCode} ${_amount.format(item.amount)}',
                    strong: true,
                  ),
                ],
              ),
            ),
          if (receipt.fixedApplications.isNotEmpty) ...[
            const SizedBox(height: 16),
            PulsoLabel(
              'Obligaciones fijas · ${receipt.currencyCode} ${_amount.format(receipt.fixedTotal)}',
            ),
            const SizedBox(height: 8),
            for (final item in receipt.fixedApplications)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: tokens.line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.periodStart == null || item.periodEnd == null
                            ? item.obligationId
                            : '${_calendarDate(item.periodStart!)} – ${_calendarDate(item.periodEnd!)}',
                        style: TextStyle(color: tokens.chalkDim),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _MonoText(
                      '${receipt.currencyCode} ${_amount.format(item.amount)}',
                      strong: true,
                    ),
                  ],
                ),
              ),
          ],
          if (receipt.reversal != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: tokens.danger),
                color: tokens.danger.withValues(alpha: 0.06),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PulsoLabel('Contramovimiento', color: tokens.danger),
                  const SizedBox(height: 6),
                  Text(
                    receipt.reversal!.reason,
                    style: TextStyle(color: tokens.chalk),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${receipt.reversal!.operatorName} · ${formatDateInZone(receipt.reversal!.registeredAt, appClock.gymTimezone, pattern: 'dd/MM/yyyy HH:mm')}',
                    style: TextStyle(color: tokens.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
              Expanded(flex: 2, child: PulsoLabel('Vigencia')),
              Expanded(flex: 3, child: PulsoLabel('Periodo')),
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
                    rules[index].hasConflict
                        ? 'CONFLICTO'
                        : rules[index].validityStatus,
                    color: _ruleStatusColor(tokens, rules[index]),
                  ),
                ),
                Expanded(flex: 3, child: _MonoText(_rulePeriod(rules[index]))),
                SizedBox(
                  width: 108,
                  child: Row(
                    children: [
                      PulsoIconButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Editar ${rules[index].planName}',
                        onPressed: rules[index].validityStatus == 'FINALIZADA'
                            ? null
                            : () => onEdit(rules[index]),
                      ),
                      const SizedBox(width: 4),
                      PulsoIconButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Eliminar ${rules[index].planName}',
                        danger: true,
                        onPressed: rules[index].validityStatus == 'FINALIZADA'
                            ? null
                            : () => onDelete(rules[index]),
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
                      onPressed: rules[index].validityStatus == 'FINALIZADA'
                          ? null
                          : () => onEdit(rules[index]),
                    ),
                    const SizedBox(width: 4),
                    PulsoIconButton(
                      icon: Icons.delete_outline,
                      tooltip: 'Eliminar ${rules[index].planName}',
                      danger: true,
                      onPressed: rules[index].validityStatus == 'FINALIZADA'
                          ? null
                          : () => onDelete(rules[index]),
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
                      label: 'Vigencia',
                      value: rules[index].hasConflict
                          ? 'Conflicto'
                          : rules[index].validityStatus,
                    ),
                    _Datum(label: 'Periodo', value: _rulePeriod(rules[index])),
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

String _rulePeriod(TrainerCommissionRuleModel rule) =>
    '${_calendarDate(rule.startDate)} → ${rule.endDate == null ? 'sin fin' : _calendarDate(rule.endDate!)}';

Color _ruleStatusColor(PulsoTokens tokens, TrainerCommissionRuleModel rule) {
  if (rule.hasConflict) return tokens.danger;
  return switch (rule.validityStatus) {
    'VIGENTE' => tokens.success,
    'PROGRAMADA' => tokens.warning,
    _ => tokens.muted,
  };
}

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
