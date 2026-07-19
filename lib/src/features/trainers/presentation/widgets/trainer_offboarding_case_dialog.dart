import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/trainer_model.dart';
import '../../data/models/trainer_offboarding_case.dart';
import '../../data/models/trainer_offboarding_financial.dart';
import '../../data/models/trainer_final_settlement.dart';

typedef UpdateOffboardingDecision =
    Future<TrainerOffboardingCase> Function({
      required TrainerOffboardingDecision decision,
      required String type,
      String? targetTrainerId,
      String? reason,
    });

typedef ExecuteOffboardingCase = Future<TrainerOffboardingCase> Function();
typedef PreviewOffboardingFinancial =
    Future<TrainerOffboardingFinancialPreview> Function({
      required TrainerOffboardingDecision decision,
      String? type,
      String? destinationPlanId,
    });
typedef ResolveOffboardingFinancial =
    Future<TrainerOffboardingCase> Function({
      required TrainerOffboardingDecision decision,
      required String type,
      String? destinationPlanId,
      String? targetTrainerId,
      required String reason,
    });
typedef PreviewFinalSettlement = Future<TrainerFinalSettlementPreview> Function();
typedef CreateFinalSettlement =
    Future<TrainerFinalSettlementResult> Function({
      required String currencyId,
      required String accountId,
      required String paymentTypeId,
      String? notes,
    });
typedef CloseFinalSettlement = Future<TrainerFinalSettlementResult> Function();

class TrainerOffboardingCaseDialog extends StatefulWidget {
  const TrainerOffboardingCaseDialog({
    super.key,
    required this.initialCase,
    required this.availableTrainers,
    required this.onUpdate,
    required this.onExecute,
    required this.onPreviewFinancial,
    required this.onResolveFinancial,
    this.onPreviewFinalSettlement,
    this.onCreateFinalSettlement,
    this.onCloseFinalSettlement,
  });

  final TrainerOffboardingCase initialCase;
  final List<TrainerModel> availableTrainers;
  final UpdateOffboardingDecision onUpdate;
  final ExecuteOffboardingCase onExecute;
  final PreviewOffboardingFinancial onPreviewFinancial;
  final ResolveOffboardingFinancial onResolveFinancial;
  final PreviewFinalSettlement? onPreviewFinalSettlement;
  final CreateFinalSettlement? onCreateFinalSettlement;
  final CloseFinalSettlement? onCloseFinalSettlement;

  @override
  State<TrainerOffboardingCaseDialog> createState() =>
      _TrainerOffboardingCaseDialogState();
}

class _TrainerOffboardingCaseDialogState
    extends State<TrainerOffboardingCaseDialog> {
  final _tableScroll = ScrollController();
  late TrainerOffboardingCase _case;
  String? _savingMembershipId;
  String? _error;
  bool _executing = false;
  bool _openingFinalSettlement = false;

  @override
  void initState() {
    super.initState();
    _case = widget.initialCase;
  }

  @override
  void dispose() {
    _tableScroll.dispose();
    super.dispose();
  }

  Future<void> _edit(TrainerOffboardingDecision decision) async {
    if (decision.awaitingTreasury) return;
    if (decision.type == 'AJUSTAR_CANCELAR' &&
        decision.executionState != 'APLICADA') {
      await _resolveFinancial(decision);
      return;
    }
    final draft = await showDialog<_DecisionDraft>(
      context: context,
      builder: (context) => PulsoThemeScope(
        child: _DecisionEditorDialog(
          decision: decision,
          trainers: widget.availableTrainers
              .where(
                (trainer) => trainer.activo && trainer.id != _case.trainerId,
              )
              .toList(),
        ),
      ),
    );
    if (draft == null || !mounted) return;
    setState(() {
      _savingMembershipId = decision.membershipId;
      _error = null;
    });
    try {
      final updated = await widget.onUpdate(
        decision: decision,
        type: draft.type,
        targetTrainerId: draft.targetTrainerId,
        reason: draft.reason,
      );
      if (!mounted) return;
      setState(() => _case = updated);
      if (draft.type == 'AJUSTAR_CANCELAR') {
        final financialDecision = updated.decisions.firstWhere(
          (item) => item.membershipId == decision.membershipId,
        );
        await _resolveFinancial(financialDecision);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _savingMembershipId = null);
    }
  }

  Future<void> _resolveFinancial(TrainerOffboardingDecision decision) async {
    final draft = await showDialog<_FinancialDraft>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PulsoThemeScope(
        child: _FinancialResolutionDialog(
          decision: decision,
          trainers: widget.availableTrainers
              .where(
                (trainer) => trainer.activo && trainer.id != _case.trainerId,
              )
              .toList(),
          onPreview: widget.onPreviewFinancial,
        ),
      ),
    );
    if (draft == null || !mounted) return;
    setState(() {
      _savingMembershipId = decision.membershipId;
      _error = null;
    });
    try {
      final updated = await widget.onResolveFinancial(
        decision: decision,
        type: draft.type,
        destinationPlanId: draft.destinationPlanId,
        targetTrainerId: draft.targetTrainerId,
        reason: draft.reason,
      );
      if (!mounted) return;
      setState(() => _case = updated);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _savingMembershipId = null);
    }
  }

  Future<void> _execute() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aplicar reasignaciones'),
        content: const Text(
          'Se cerrarán las asignaciones del entrenador saliente y se crearán las nuevas. '
          'El plan, precio y vigencia de cada socio se conservan. Las cuotas futuras '
          'se transferirán al entrenador destino o se anularán si continúa sin entrenador; '
          'lo ya ganado permanecerá pendiente de liquidación para el entrenador saliente.',
        ),
        actions: [
          PulsoSecondaryButton(
            label: 'Cancelar',
            onPressed: () => Navigator.of(context).pop(false),
          ),
          PulsoPrimaryButton(
            label: 'Aplicar ahora',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _executing = true;
      _error = null;
    });
    try {
      final updated = await widget.onExecute();
      if (!mounted) return;
      setState(() => _case = updated);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _executing = false);
    }
  }

  Future<void> _openFinalSettlement() async {
    final previewFinal = widget.onPreviewFinalSettlement;
    final createFinal = widget.onCreateFinalSettlement;
    final closeFinal = widget.onCloseFinalSettlement;
    if (previewFinal == null || createFinal == null || closeFinal == null) {
      return;
    }
    setState(() {
      _openingFinalSettlement = true;
      _error = null;
    });
    try {
      final preview = await previewFinal();
      if (!mounted) return;
      final result = await showDialog<TrainerFinalSettlementResult>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PulsoThemeScope(
          child: _FinalSettlementDialog(
            initialPreview: preview,
            onCreate: createFinal,
            onCloseCase: closeFinal,
          ),
        ),
      );
      if (!mounted || result == null) return;
      setState(() => _case = result.offboardingCase);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _openingFinalSettlement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = math.min(980.0, math.max(320.0, size.width - 32));
    final height = math.min(720.0, math.max(440.0, size.height - 32));
    final tokens = PulsoTokens.of(context);
    final date = DateFormat('yyyy-MM-dd');
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: tokens.line)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PulsoLabel('BAJA DE ENTRENADOR'),
                        SizedBox(height: 4),
                        Text(
                          'Expediente y decisiones por membresía',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(status: _case.status),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
              child: Wrap(
                spacing: 24,
                runSpacing: 10,
                children: [
                  _SummaryValue(
                    label: 'Fecha efectiva',
                    value: date.format(_case.effectiveDate),
                  ),
                  _SummaryValue(
                    label: 'Decisiones',
                    value:
                        '${_case.totalDecisions - _case.pendingDecisions}/${_case.totalDecisions}',
                  ),
                  _SummaryValue(label: 'Preparado por', value: _case.createdBy),
                  _SummaryValue(label: 'Motivo', value: _case.reason),
                ],
              ),
            ),
            if (_error != null)
              Container(
                margin: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                padding: const EdgeInsets.all(10),
                color: tokens.dangerSoft,
                child: Text(_error!, style: TextStyle(color: tokens.danger)),
              ),
            if (_case.executionSummary != null)
              _ExecutionSummaryBand(
                summary: _case.executionSummary!,
                executedBy: _case.executedBy,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  const Expanded(child: PulsoLabel('MEMBRESÍAS AFECTADAS')),
                  Text(
                    '${_case.pendingDecisions} pendiente${_case.pendingDecisions == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: _case.membershipsReady
                          ? tokens.success
                          : tokens.warning,
                      fontFamily: PulsoFonts.mono,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: _DecisionTable(
                  decisions: _case.decisions,
                  controller: _tableScroll,
                  savingMembershipId: _savingMembershipId,
                  onEdit: _edit,
                  editable:
                      _case.status == 'BORRADOR' ||
                      _case.status == 'LISTO_PARA_REVISION',
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: tokens.line)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 620;
                  final message = Text(
                    _footerMessage(_case),
                    style: TextStyle(color: tokens.muted, fontSize: 12),
                  );
                  final actions = Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      PulsoSecondaryButton(
                        label: 'Cerrar',
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(_case.status == 'EN_EJECUCION'),
                      ),
                      if (_case.status == 'LISTO_PARA_REVISION')
                        PulsoPrimaryButton(
                          label: _executing
                              ? 'Aplicando…'
                              : 'Aplicar reasignaciones',
                          onPressed: _case.canApplyAssignments && !_executing
                              ? _execute
                              : null,
                        ),
                      if (_case.status == 'EN_EJECUCION' &&
                          widget.onPreviewFinalSettlement != null &&
                          widget.onCreateFinalSettlement != null &&
                          widget.onCloseFinalSettlement != null)
                        PulsoPrimaryButton(
                          label: _openingFinalSettlement
                              ? 'Abriendo…'
                              : 'Liquidación final',
                          onPressed: _openingFinalSettlement
                              ? null
                              : _openFinalSettlement,
                        ),
                    ],
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [message, const SizedBox(height: 10), actions],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: message),
                      const SizedBox(width: 12),
                      actions,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionTable extends StatelessWidget {
  const _DecisionTable({
    required this.decisions,
    required this.controller,
    required this.savingMembershipId,
    required this.onEdit,
    required this.editable,
  });

  final List<TrainerOffboardingDecision> decisions;
  final ScrollController controller;
  final String? savingMembershipId;
  final ValueChanged<TrainerOffboardingDecision> onEdit;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: tokens.line)),
          child: Column(
            children: [
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                color: tokens.raised,
                child: Row(
                  children: [
                    const Expanded(flex: 4, child: PulsoLabel('Socio / plan')),
                    if (!compact)
                      const Expanded(flex: 2, child: PulsoLabel('Vigencia')),
                    const Expanded(flex: 3, child: PulsoLabel('Decisión')),
                    const SizedBox(width: 82),
                  ],
                ),
              ),
              Expanded(
                child: decisions.isEmpty
                    ? const Center(
                        child: Text('No hay membresías que resolver.'),
                      )
                    : Scrollbar(
                        key: const Key('offboarding-case-table-scrollbar'),
                        controller: controller,
                        thumbVisibility: true,
                        child: ListView.separated(
                          controller: controller,
                          primary: false,
                          itemCount: decisions.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: tokens.line),
                          itemBuilder: (context, index) {
                            final item = decisions[index];
                            final saving =
                                savingMembershipId == item.membershipId;
                            final awaitingTreasury = item.awaitingTreasury;
                            return SizedBox(
                              height: 66,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: _TwoLineCell(
                                        primary: item.clientName,
                                        secondary:
                                            '${item.planName} · ${item.clientId}',
                                      ),
                                    ),
                                    if (!compact)
                                      Expanded(
                                        flex: 2,
                                        child: _TwoLineCell(
                                          primary: DateFormat(
                                            'yyyy-MM-dd',
                                          ).format(item.endDate),
                                          secondary: item.membershipStatus,
                                        ),
                                      ),
                                    Expanded(
                                      flex: 3,
                                      child: _TwoLineCell(
                                        primary: awaitingTreasury
                                            ? 'Reembolso pendiente'
                                            : _decisionLabel(item.type),
                                        secondary: awaitingTreasury
                                            ? 'Tesorería debe confirmarlo'
                                            : item.targetTrainerName ??
                                                  item.reason ??
                                                  'sin definir',
                                        accent: item.type != 'PENDIENTE',
                                      ),
                                    ),
                                    SizedBox(
                                      width: 82,
                                      child: saving
                                          ? const Center(
                                              child: SizedBox.square(
                                                dimension: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                            )
                                          : TextButton(
                                              onPressed:
                                                  editable && !awaitingTreasury
                                                  ? () => onEdit(item)
                                                  : null,
                                              child: Text(
                                                item.executionState ==
                                                        'APLICADA'
                                                    ? 'Aplicada'
                                                    : awaitingTreasury
                                                    ? 'Tesorería'
                                                    : item.type ==
                                                          'AJUSTAR_CANCELAR'
                                                    ? 'Resolver finanzas'
                                                    : item.type == 'PENDIENTE'
                                                    ? 'Resolver'
                                                    : 'Editar',
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DecisionEditorDialog extends StatefulWidget {
  const _DecisionEditorDialog({required this.decision, required this.trainers});

  final TrainerOffboardingDecision decision;
  final List<TrainerModel> trainers;

  @override
  State<_DecisionEditorDialog> createState() => _DecisionEditorDialogState();
}

class _DecisionEditorDialogState extends State<_DecisionEditorDialog> {
  late String _type;
  String? _targetTrainerId;
  late final TextEditingController _reason;
  String? _validation;

  @override
  void initState() {
    super.initState();
    _type = widget.decision.type == 'PENDIENTE'
        ? 'REASIGNAR'
        : widget.decision.type;
    _targetTrainerId = widget.decision.targetTrainerId;
    _reason = TextEditingController(text: widget.decision.reason ?? '');
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reason.text.trim();
    if (_type == 'REASIGNAR' && _targetTrainerId == null) {
      setState(() => _validation = 'Seleccione el entrenador de destino.');
      return;
    }
    if (_type == 'AJUSTAR_CANCELAR' && reason.length < 5) {
      setState(() => _validation = 'Explique el ajuste o la cancelación.');
      return;
    }
    Navigator.of(context).pop(
      _DecisionDraft(
        type: _type,
        targetTrainerId: _type == 'REASIGNAR' ? _targetTrainerId : null,
        reason: reason.isEmpty ? null : reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Resolver ${widget.decision.clientName}'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.decision.planName} · vence ${DateFormat('yyyy-MM-dd').format(widget.decision.endDate)}',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Decisión'),
              items: const [
                DropdownMenuItem(
                  value: 'REASIGNAR',
                  child: Text('Reasignar a otro entrenador'),
                ),
                DropdownMenuItem(
                  value: 'SIN_ENTRENADOR',
                  child: Text('Continuar sin entrenador'),
                ),
                DropdownMenuItem(
                  value: 'AJUSTAR_CANCELAR',
                  child: Text('Cambiar plan / ajuste financiero'),
                ),
              ],
              onChanged: (value) => setState(() {
                _type = value ?? _type;
                _validation = null;
              }),
            ),
            if (_type == 'REASIGNAR') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _targetTrainerId,
                decoration: const InputDecoration(
                  labelText: 'Entrenador de destino',
                ),
                items: [
                  for (final trainer in widget.trainers)
                    DropdownMenuItem(
                      value: trainer.id,
                      child: Text(
                        '${trainer.nombres ?? ''} ${trainer.apellidos ?? ''}'
                            .trim(),
                      ),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _targetTrainerId = value;
                  _validation = null;
                }),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _type == 'AJUSTAR_CANCELAR'
                    ? 'Cambio de plan o ajuste requerido'
                    : 'Nota opcional',
              ),
            ),
            if (_validation != null)
              Text(
                _validation!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        PulsoSecondaryButton(
          label: 'Cancelar',
          onPressed: () => Navigator.of(context).pop(),
        ),
        PulsoPrimaryButton(label: 'Guardar decisión', onPressed: _submit),
      ],
    );
  }
}

class _DecisionDraft {
  const _DecisionDraft({
    required this.type,
    required this.targetTrainerId,
    required this.reason,
  });
  final String type;
  final String? targetTrainerId;
  final String? reason;
}

class _FinancialResolutionDialog extends StatefulWidget {
  const _FinancialResolutionDialog({
    required this.decision,
    required this.trainers,
    required this.onPreview,
  });

  final TrainerOffboardingDecision decision;
  final List<TrainerModel> trainers;
  final PreviewOffboardingFinancial onPreview;

  @override
  State<_FinancialResolutionDialog> createState() =>
      _FinancialResolutionDialogState();
}

class _FinancialResolutionDialogState
    extends State<_FinancialResolutionDialog> {
  final _reason = TextEditingController();
  TrainerOffboardingFinancialPreview? _preview;
  String _type = 'CAMBIO_PLAN';
  String? _planId;
  String? _trainerId;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  TrainerOffboardingFinancialPlan? get _selectedPlan {
    final preview = _preview;
    if (preview == null || _planId == null) return null;
    for (final plan in preview.plans) {
      if (plan.id == _planId) return plan;
    }
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.onPreview(
        decision: widget.decision,
        type: _type,
        destinationPlanId: _type == 'CAMBIO_PLAN' ? _planId : null,
      );
      if (!mounted) return;
      setState(() => _preview = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _submit() {
    final reason = _reason.text.trim();
    if (_type == 'CAMBIO_PLAN' && _planId == null) {
      setState(() => _error = 'Seleccione el plan de destino.');
      return;
    }
    if (_selectedPlan?.includesTrainer == true && _trainerId == null) {
      setState(() => _error = 'Seleccione el entrenador del nuevo plan.');
      return;
    }
    if (reason.length < 5) {
      setState(() => _error = 'Explique la razón financiera.');
      return;
    }
    Navigator.of(context).pop(
      _FinancialDraft(
        type: _type,
        destinationPlanId: _type == 'CAMBIO_PLAN' ? _planId : null,
        targetTrainerId: _selectedPlan?.includesTrainer == true
            ? _trainerId
            : null,
        reason: reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final tokens = PulsoTokens.of(context);
    final compact = size.width < 720;
    final preview = _preview;
    final destination = preview?.destination;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: math.min(820, math.max(320, size.width - 32)),
        height: math.min(680, math.max(460, size.height - 32)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 16, 12, 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: tokens.lineStrong)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PulsoLabel('RESOLUCIÓN FINANCIERA'),
                        const SizedBox(height: 3),
                        Text(
                          widget.decision.clientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(compact ? 16 : 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loading && preview == null)
                      const SizedBox(
                        height: 180,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (preview != null) ...[
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _FinancialMetric(
                            label: 'Valor pagado',
                            value: preview.valuation.paid,
                            currency: preview.currencyId,
                          ),
                          _FinancialMetric(
                            label: 'Valor consumido',
                            value: preview.valuation.consumedValue,
                            currency: preview.currencyId,
                          ),
                          _FinancialMetric(
                            label: 'Crédito disponible',
                            value: preview.valuation.unusedValue,
                            currency: preview.currencyId,
                            accent: true,
                          ),
                          _FinancialMetric(
                            label: 'Servicio restante',
                            text:
                                '${preview.valuation.remainingDays}/${preview.valuation.totalDays} días',
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        key: const Key('offboarding-financial-type'),
                        initialValue: _type,
                        decoration: const InputDecoration(
                          labelText: 'Qué ocurrirá con la membresía',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'CAMBIO_PLAN',
                            child: Text('Cambiar a otro plan'),
                          ),
                          DropdownMenuItem(
                            value: 'CREDITO_CLIENTE',
                            child: Text('Cancelar y dejar crédito al socio'),
                          ),
                          DropdownMenuItem(
                            value: 'REEMBOLSO_PENDIENTE',
                            child: Text('Solicitar reembolso a tesorería'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _type = value ?? _type;
                            _planId = null;
                            _trainerId = null;
                            _error = null;
                          });
                          _load();
                        },
                      ),
                      if (_type == 'CAMBIO_PLAN') ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: const Key('offboarding-financial-plan'),
                          initialValue: _planId,
                          decoration: const InputDecoration(
                            labelText: 'Plan de destino · misma moneda',
                          ),
                          items: [
                            for (final plan in preview.plans)
                              DropdownMenuItem(
                                value: plan.id,
                                child: Text(
                                  '${plan.name} · ${plan.price.toStringAsFixed(2)} ${plan.currencyId}',
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _planId = value;
                              _trainerId = null;
                              _error = null;
                            });
                            _load();
                          },
                        ),
                        if (_selectedPlan?.includesTrainer == true) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            key: const Key('offboarding-financial-trainer'),
                            initialValue: _trainerId,
                            decoration: const InputDecoration(
                              labelText: 'Entrenador del nuevo plan',
                            ),
                            items: [
                              for (final trainer in widget.trainers)
                                DropdownMenuItem(
                                  value: trainer.id,
                                  child: Text(
                                    '${trainer.nombres ?? ''} ${trainer.apellidos ?? ''}'
                                        .trim(),
                                  ),
                                ),
                            ],
                            onChanged: (value) => setState(() {
                              _trainerId = value;
                              _error = null;
                            }),
                          ),
                        ],
                      ],
                      const SizedBox(height: 14),
                      _FinancialOutcome(
                        type: _type,
                        destination: destination,
                        currency: preview.currencyId,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        key: const Key('offboarding-financial-reason'),
                        controller: _reason,
                        maxLength: 500,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Razón y observación contable',
                        ),
                      ),
                    ],
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(10),
                        color: tokens.dangerSoft,
                        child: Text(
                          _error!,
                          style: TextStyle(color: tokens.danger),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: tokens.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _type == 'REEMBOLSO_PENDIENTE'
                          ? 'La baja seguirá bloqueada hasta que tesorería confirme el reembolso.'
                          : 'El crédito es interno: no aumenta caja ni banco.',
                      style: TextStyle(color: tokens.muted, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 12),
                  PulsoSecondaryButton(
                    label: 'Cancelar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  PulsoPrimaryButton(
                    label: _type == 'REEMBOLSO_PENDIENTE'
                        ? 'Enviar a tesorería'
                        : 'Aplicar resolución',
                    onPressed:
                        !_loading &&
                            (_type != 'CAMBIO_PLAN' || destination != null)
                        ? _submit
                        : null,
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

class _FinancialMetric extends StatelessWidget {
  const _FinancialMetric({
    required this.label,
    this.value,
    this.currency,
    this.text,
    this.accent = false,
  });
  final String label;
  final double? value;
  final String? currency;
  final String? text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      width: 175,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(border: Border.all(color: tokens.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PulsoLabel(label),
          const SizedBox(height: 5),
          Text(
            text ?? '${value?.toStringAsFixed(2)} ${currency ?? ''}',
            style: TextStyle(
              color: accent ? tokens.accent : tokens.chalk,
              fontFamily: PulsoFonts.mono,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinancialOutcome extends StatelessWidget {
  const _FinancialOutcome({
    required this.type,
    required this.destination,
    required this.currency,
  });
  final String type;
  final TrainerOffboardingFinancialDestination? destination;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final value = destination;
    final text = value == null
        ? 'Seleccione un plan para calcular la diferencia.'
        : type == 'CAMBIO_PLAN'
        ? 'Crédito aplicado ${value.creditApplied.toStringAsFixed(2)} · '
              'por cobrar ${value.amountDue.toStringAsFixed(2)} · '
              'saldo ${value.remainingCredit.toStringAsFixed(2)} $currency'
        : type == 'CREDITO_CLIENTE'
        ? 'Quedarán ${value.remainingCredit.toStringAsFixed(2)} $currency disponibles para el socio.'
        : 'Tesorería deberá resolver ${value.refundAmount.toStringAsFixed(2)} $currency.';
    return Container(
      key: const Key('offboarding-financial-outcome'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: type == 'REEMBOLSO_PENDIENTE'
            ? tokens.warningSoft
            : tokens.successSoft,
        border: Border(
          left: BorderSide(
            color: type == 'REEMBOLSO_PENDIENTE'
                ? tokens.warning
                : tokens.success,
            width: 3,
          ),
        ),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _FinancialDraft {
  const _FinancialDraft({
    required this.type,
    required this.destinationPlanId,
    required this.targetTrainerId,
    required this.reason,
  });
  final String type;
  final String? destinationPlanId;
  final String? targetTrainerId;
  final String reason;
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 250),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: tokens.muted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TwoLineCell extends StatelessWidget {
  const _TwoLineCell({
    required this.primary,
    required this.secondary,
    this.accent = false,
  });
  final String primary;
  final String secondary;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          primary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: accent ? tokens.accent : tokens.chalk,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          secondary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: tokens.muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final ready = status == 'LISTO_PARA_REVISION';
    final applying = status == 'EN_EJECUCION';
    final closed = status == 'EJECUTADO';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: ready || applying || closed
          ? tokens.successSoft
          : tokens.warningSoft,
      child: Text(
        closed
            ? 'BAJA CERRADA'
            : applying
            ? 'REASIGNACIONES APLICADAS'
            : ready
            ? 'LISTO PARA REVISIÓN'
            : 'BORRADOR',
        style: TextStyle(
          color: ready || applying || closed
              ? tokens.success
              : tokens.warning,
          fontFamily: PulsoFonts.mono,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ExecutionSummaryBand extends StatelessWidget {
  const _ExecutionSummaryBand({
    required this.summary,
    required this.executedBy,
  });

  final Map<String, dynamic> summary;
  final String? executedBy;

  int _count(String key) => (summary[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final memberships = _count('membresias_aplicadas');
    final assignments = _count('asignaciones_creadas');
    final transferred = _count('cuotas_transferidas');
    final cancelled = _count('cuotas_anuladas');
    final operator = executedBy?.trim();
    return Container(
      key: const Key('offboarding-execution-summary'),
      margin: const EdgeInsets.fromLTRB(22, 0, 22, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.successSoft,
        border: Border(left: BorderSide(color: tokens.success, width: 3)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'RESULTADO APLICADO',
            style: TextStyle(
              color: tokens.success,
              fontFamily: PulsoFonts.mono,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '$memberships membresía${memberships == 1 ? '' : 's'} · '
            '$assignments nueva${assignments == 1 ? '' : 's'} asignación${assignments == 1 ? '' : 'es'} · '
            '$transferred cuota${transferred == 1 ? '' : 's'} transferida${transferred == 1 ? '' : 's'} · '
            '$cancelled anulada${cancelled == 1 ? '' : 's'}',
            style: TextStyle(color: tokens.chalk, fontSize: 12),
          ),
          if (operator != null && operator.isNotEmpty)
            Text(
              'por $operator',
              style: TextStyle(color: tokens.muted, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _FinalSettlementDialog extends StatefulWidget {
  const _FinalSettlementDialog({
    required this.initialPreview,
    required this.onCreate,
    required this.onCloseCase,
  });

  final TrainerFinalSettlementPreview initialPreview;
  final CreateFinalSettlement onCreate;
  final CloseFinalSettlement onCloseCase;

  @override
  State<_FinalSettlementDialog> createState() => _FinalSettlementDialogState();
}

class _FinalSettlementDialogState extends State<_FinalSettlementDialog> {
  final _rowsScroll = ScrollController();
  final _notes = TextEditingController();
  late TrainerFinalSettlementPreview _preview;
  TrainerFinalSettlementResult? _lastResult;
  String? _currencyId;
  String? _accountId;
  String? _paymentTypeId;
  String? _error;
  String? _notice;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _preview = widget.initialPreview;
    _selectDefaults();
  }

  @override
  void dispose() {
    _rowsScroll.dispose();
    _notes.dispose();
    super.dispose();
  }

  TrainerFinalSettlementCurrency? get _selectedCurrency {
    for (final item in _preview.currencies) {
      if (item.currencyId == _currencyId) return item;
    }
    return _preview.currencies.isEmpty ? null : _preview.currencies.first;
  }

  List<TrainerFinalSettlementAccount> get _accounts {
    final currency = _selectedCurrency;
    if (currency == null) return const [];
    return _preview.accounts
        .where((item) => item.currencyId == currency.currencyId)
        .toList();
  }

  void _selectDefaults() {
    if (_preview.currencies.isEmpty) {
      _currencyId = null;
      _accountId = null;
      _paymentTypeId = null;
      return;
    }
    if (!_preview.currencies.any((item) => item.currencyId == _currencyId)) {
      _currencyId = _preview.currencies.first.currencyId;
    }
    final accounts = _preview.accounts
        .where((item) => item.currencyId == _currencyId)
        .toList();
    if (!accounts.any((item) => item.id == _accountId)) {
      _accountId = accounts.isEmpty ? null : accounts.first.id;
    }
    final selectedAccount = accounts
        .where((item) => item.id == _accountId)
        .firstOrNull;
    final preferredPaymentType = selectedAccount?.paymentTypeId;
    if (preferredPaymentType != null &&
        _preview.paymentTypes.any((item) => item.id == preferredPaymentType)) {
      _paymentTypeId = preferredPaymentType;
    } else if (!_preview.paymentTypes.any(
      (item) => item.id == _paymentTypeId,
    )) {
      _paymentTypeId = _preview.paymentTypes.isEmpty
          ? null
          : _preview.paymentTypes.first.id;
    }
  }

  Future<void> _settle() async {
    final currency = _selectedCurrency;
    if (currency == null || _accountId == null || _paymentTypeId == null) {
      setState(() {
        _error = _accounts.isEmpty
            ? 'No existe una cuenta de salida para esta moneda.'
            : 'Seleccione cuenta y método de salida.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      final result = await widget.onCreate(
        currencyId: currency.currencyId,
        accountId: _accountId!,
        paymentTypeId: _paymentTypeId!,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _preview = result.preview;
        _notice = result.receiptNumber == null
            ? 'Liquidación registrada.'
            : 'Comprobante ${result.receiptNumber} registrado.';
        _notes.clear();
        _selectDefaults();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _closeWithoutBalance() async {
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      final result = await widget.onCloseCase();
      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _preview = result.preview;
        _notice = 'Expediente cerrado sin saldo pendiente.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = math.min(820.0, math.max(320.0, size.width - 32));
    final height = math.min(680.0, math.max(440.0, size.height - 32));
    final amount = NumberFormat('#,##0.00');
    final selected = _selectedCurrency;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: tokens.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PulsoLabel('CIERRE DE BAJA'),
                        const SizedBox(height: 4),
                        Text(
                          'Liquidación extraordinaria final',
                          style: TextStyle(
                            color: tokens.chalk,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${_preview.trainerName} · corte ${DateFormat('yyyy-MM-dd').format(_preview.effectiveDate)}',
                          style: TextStyle(color: tokens.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(_lastResult),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (_notice != null)
              Container(
                margin: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                padding: const EdgeInsets.all(10),
                color: tokens.successSoft,
                child: Text(
                  _notice!,
                  style: TextStyle(color: tokens.success),
                ),
              ),
            if (_error != null)
              Container(
                margin: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                padding: const EdgeInsets.all(10),
                color: tokens.dangerSoft,
                child: Text(_error!, style: TextStyle(color: tokens.danger)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
              child: Row(
                children: [
                  const Expanded(child: PulsoLabel('SALDOS POR MONEDA')),
                  Text(
                    _preview.closed
                        ? 'EXPEDIENTE CERRADO'
                        : '${_preview.currencies.length} moneda${_preview.currencies.length == 1 ? '' : 's'} pendiente${_preview.currencies.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: _preview.closed
                          ? tokens.success
                          : tokens.warning,
                      fontFamily: PulsoFonts.mono,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: tokens.line),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        color: tokens.raised,
                        child: const Row(
                          children: [
                            Expanded(flex: 2, child: PulsoLabel('Moneda')),
                            Expanded(flex: 2, child: PulsoLabel('Comisión')),
                            Expanded(flex: 2, child: PulsoLabel('Fijo')),
                            Expanded(flex: 2, child: PulsoLabel('Total')),
                            Expanded(flex: 2, child: PulsoLabel('Conceptos')),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _preview.currencies.isEmpty
                            ? Center(
                                child: Text(
                                  _preview.closed
                                      ? 'No quedan saldos. La baja está cerrada.'
                                      : 'No existen conceptos pendientes de pago.',
                                  style: TextStyle(color: tokens.muted),
                                ),
                              )
                            : Scrollbar(
                                key: const Key(
                                  'final-settlement-currency-scrollbar',
                                ),
                                controller: _rowsScroll,
                                thumbVisibility: true,
                                child: ListView.separated(
                                  controller: _rowsScroll,
                                  primary: false,
                                  itemCount: _preview.currencies.length,
                                  separatorBuilder: (_, _) => Divider(
                                    height: 1,
                                    color: tokens.line,
                                  ),
                                  itemBuilder: (context, index) {
                                    final item = _preview.currencies[index];
                                    final active =
                                        item.currencyId == _currencyId;
                                    return InkWell(
                                      onTap: _saving
                                          ? null
                                          : () => setState(() {
                                              _currencyId = item.currencyId;
                                              _selectDefaults();
                                            }),
                                      child: Container(
                                        height: 58,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        color: active
                                            ? tokens.accentSoft
                                            : index.isOdd
                                            ? tokens.raised.withValues(
                                                alpha: 0.45,
                                              )
                                            : tokens.surface,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                item.currencyCode,
                                                style: TextStyle(
                                                  color: tokens.chalk,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                amount.format(
                                                  item.commissionTotal,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                amount.format(item.fixedTotal),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                amount.format(item.total),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text('${item.concepts}'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: tokens.line)),
              ),
              child: _preview.closed
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: PulsoPrimaryButton(
                        label: 'Terminar',
                        onPressed: () => Navigator.of(context).pop(_lastResult),
                      ),
                    )
                  : selected == null
                  ? Row(
                      children: [
                        Expanded(
                          child: Text(
                            'No hay saldo que desembolsar. Puede cerrar el expediente con evidencia de saldo cero.',
                            style: TextStyle(
                              color: tokens.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        PulsoPrimaryButton(
                          label: _saving
                              ? 'Cerrando…'
                              : 'Cerrar sin saldo',
                          onPressed: _saving ? null : _closeWithoutBalance,
                        ),
                      ],
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 650;
                        final accountField =
                            DropdownButtonFormField<String>(
                              key: const Key('final-settlement-account'),
                              initialValue: _accountId,
                              decoration: const InputDecoration(
                                labelText: 'Cuenta de salida',
                              ),
                              items: _accounts
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item.id,
                                      child: Text(
                                        '${item.name} · ${item.currencyCode}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _saving
                                  ? null
                                  : (value) => setState(() {
                                      _accountId = value;
                                      _selectDefaults();
                                    }),
                            );
                        final paymentField =
                            DropdownButtonFormField<String>(
                              key: const Key('final-settlement-payment-type'),
                              initialValue: _paymentTypeId,
                              decoration: const InputDecoration(
                                labelText: 'Método de salida',
                              ),
                              items: _preview.paymentTypes
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item.id,
                                      child: Text(item.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _saving
                                  ? null
                                  : (value) => setState(
                                      () => _paymentTypeId = value,
                                    ),
                            );
                        final fields = compact
                            ? Column(
                                children: [
                                  accountField,
                                  const SizedBox(height: 8),
                                  paymentField,
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: accountField),
                                  const SizedBox(width: 10),
                                  Expanded(child: paymentField),
                                ],
                              );
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            fields,
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _notes,
                                    enabled: !_saving,
                                    decoration: const InputDecoration(
                                      labelText: 'Nota opcional',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                PulsoPrimaryButton(
                                  label: _saving
                                      ? 'Liquidando…'
                                      : 'Liquidar ${selected.currencyCode} ${amount.format(selected.total)}',
                                  onPressed: _saving ? null : _settle,
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String _decisionLabel(String type) => switch (type) {
  'REASIGNAR' => 'Reasignar',
  'SIN_ENTRENADOR' => 'Sin entrenador',
  'AJUSTAR_CANCELAR' => 'Cambiar plan / ajustar',
  _ => 'Pendiente',
};

String _footerMessage(TrainerOffboardingCase value) {
  if (value.status == 'EJECUTADO') {
    return 'La liquidación final quedó registrada y el expediente de baja está cerrado.';
  }
  if (value.status == 'EN_EJECUCION') {
    return 'Las asignaciones y cuotas futuras ya fueron aplicadas. Falta liquidar lo ganado y cerrar definitivamente la baja.';
  }
  if (value.hasFinancialReview) {
    return 'Hay una membresía marcada para cambio de plan o ajuste financiero. Debe resolverse antes de aplicar la baja.';
  }
  if (value.membershipsReady) {
    return 'Todo está listo. Reasignar conserva el plan; cambiar de plan requiere el flujo financiero separado.';
  }
  return 'La baja sigue protegida hasta decidir todas las membresías.';
}
