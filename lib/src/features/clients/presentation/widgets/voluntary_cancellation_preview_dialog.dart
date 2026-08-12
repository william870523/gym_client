import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/voluntary_cancellation_preview.dart';
import '../../data/repositories/client_repository.dart';

class VoluntaryCancellationPreviewDialog extends ConsumerStatefulWidget {
  const VoluntaryCancellationPreviewDialog({
    super.key,
    required this.clientId,
    required this.membershipId,
    this.canExecute = false,
  });

  final String clientId;
  final String membershipId;
  final bool canExecute;

  @override
  ConsumerState<VoluntaryCancellationPreviewDialog> createState() =>
      _VoluntaryCancellationPreviewDialogState();
}

class _VoluntaryCancellationPreviewDialogState
    extends ConsumerState<VoluntaryCancellationPreviewDialog> {
  late Future<VoluntaryCancellationPreview> _preview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _preview = ref
        .read(clientRepositoryProvider)
        .previewVoluntaryCancellation(
          clientId: widget.clientId,
          membershipId: widget.membershipId,
        );
  }

  @override
  Widget build(BuildContext context) => PulsoThemeScope(
    child: Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: FutureBuilder<VoluntaryCancellationPreview>(
          future: _preview,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 320,
                child: PulsoStateView(
                  kind: PulsoStateKind.loading,
                  message: 'Calculando valor no consumido…',
                ),
              );
            }
            if (snapshot.hasError) {
              return SizedBox(
                height: 360,
                child: PulsoStateView(
                  kind: PulsoStateKind.error,
                  message:
                      'No se pudo valorar la cancelación.\n${snapshot.error}',
                  onRetry: () => setState(_load),
                ),
              );
            }
            return _PreviewBody(
              preview: snapshot.requireData,
              canExecute: widget.canExecute,
              clientId: widget.clientId,
              membershipId: widget.membershipId,
            );
          },
        ),
      ),
    ),
  );
}

class _PreviewBody extends ConsumerStatefulWidget {
  const _PreviewBody({
    required this.preview,
    required this.canExecute,
    required this.clientId,
    required this.membershipId,
  });

  final VoluntaryCancellationPreview preview;
  final bool canExecute;
  final String clientId;
  final String membershipId;

  @override
  ConsumerState<_PreviewBody> createState() => _PreviewBodyState();
}

class _PreviewBodyState extends ConsumerState<_PreviewBody> {
  final _reason = TextEditingController();
  String _resolutionType = 'CREDITO_CLIENTE';
  bool _confirmed = false;
  bool _busy = false;
  String? _error;

  VoluntaryCancellationPreview get preview => widget.preview;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _execute() async {
    final reason = _reason.text.trim();
    if (!_confirmed || reason.length < 5) {
      setState(
        () => _error = !_confirmed
            ? 'Confirme que revisó el valor y el efecto de la cancelación.'
            : 'Escriba un motivo de al menos 5 caracteres.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(clientRepositoryProvider)
          .executeVoluntaryCancellation(
            clientId: widget.clientId,
            membershipId: widget.membershipId,
            resolutionType: _resolutionType,
            reason: reason,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _money(double value) =>
      '${preview.currencySymbol}${value.toStringAsFixed(2)} ${preview.currency}';

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      key: const ValueKey('voluntary-cancellation-preview-dialog'),
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 12, 16),
            color: tokens.raised,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PulsoLabel('MEMBRESÍA · DECISIÓN PROTEGIDA'),
                      const SizedBox(height: 4),
                      Text(
                        'VALORAR CANCELACIÓN',
                        style: TextStyle(
                          fontFamily: PulsoFonts.display,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: tokens.chalk,
                        ),
                      ),
                      Text(
                        '${preview.clientName} · ${preview.planName}',
                        style: TextStyle(color: tokens.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                PulsoIconButton(
                  tooltip: 'Cerrar',
                  icon: Icons.close,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    key: const ValueKey('voluntary-cancellation-safety-note'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tokens.warningSoft,
                      border: Border.all(color: tokens.warning),
                    ),
                    child: Text(
                      widget.canExecute
                          ? 'AL CONFIRMAR SE CANCELA LA MEMBRESÍA. No se mueve dinero en caja: '
                                'el crédito queda disponible y el reembolso queda pendiente de Tesorería.'
                          : 'ESTA VISTA NO CANCELA LA MEMBRESÍA NI MUEVE DINERO. '
                                'Administración debe confirmar la resolución.',
                      style: TextStyle(
                        color: tokens.warning,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _Metric(
                        label: 'DÍAS CONSUMIDOS',
                        value: '${preview.consumedDays}',
                      ),
                      _Metric(
                        label: 'DÍAS RESTANTES',
                        value: '${preview.remainingDays}',
                      ),
                      _Metric(
                        label: 'VALOR CONSUMIDO',
                        value: _money(preview.consumedValue),
                      ),
                      _Metric(
                        key: const ValueKey(
                          'voluntary-cancellation-unused-value',
                        ),
                        label: 'VALOR NO CONSUMIDO',
                        value: _money(preview.unusedValue),
                        emphasis: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  PulsoLabel(
                    widget.canExecute
                        ? 'ELIJA LA RESOLUCIÓN'
                        : 'ALTERNATIVAS A DECIDIR',
                  ),
                  const SizedBox(height: 8),
                  for (final alternative in preview.alternatives)
                    InkWell(
                      key: ValueKey(
                        'voluntary-cancellation-option-${alternative.type}',
                      ),
                      onTap: widget.canExecute && !_busy
                          ? () => setState(
                              () => _resolutionType = alternative.type,
                            )
                          : null,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                widget.canExecute &&
                                    _resolutionType == alternative.type
                                ? tokens.accent
                                : tokens.lineStrong,
                            width:
                                widget.canExecute &&
                                    _resolutionType == alternative.type
                                ? 2
                                : 1,
                          ),
                          color: tokens.raised2,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.canExecute)
                              Icon(
                                _resolutionType == alternative.type
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: _resolutionType == alternative.type
                                    ? tokens.accent
                                    : tokens.muted,
                              )
                            else
                              Icon(
                                alternative.requiresTreasury
                                    ? Icons.account_balance_outlined
                                    : Icons.savings_outlined,
                                color: tokens.accent,
                              ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alternative.type == 'CREDITO_CLIENTE'
                                        ? 'CRÉDITO DEL CLIENTE'
                                        : 'REEMBOLSO PENDIENTE',
                                    style: TextStyle(
                                      color: tokens.chalk,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '${_money(alternative.amount)} · ${alternative.description}',
                                    style: TextStyle(
                                      color: tokens.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Fecha efectiva usada: ${preview.effectiveDate} · Estado actual: ${preview.membershipState}',
                    style: TextStyle(
                      color: tokens.muted,
                      fontFamily: PulsoFonts.mono,
                      fontSize: 9.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (widget.canExecute) ...[
                    TextField(
                      key: const ValueKey('voluntary-cancellation-reason'),
                      controller: _reason,
                      enabled: !_busy,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Motivo de la cancelación',
                        hintText: 'Ej.: traslado definitivo del cliente',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: Colors.transparent,
                      child: CheckboxListTile(
                        key: const ValueKey('voluntary-cancellation-confirm'),
                        contentPadding: EdgeInsets.zero,
                        value: _confirmed,
                        onChanged: _busy
                            ? null
                            : (value) =>
                                  setState(() => _confirmed = value == true),
                        title: Text(
                          'Confirmo la cancelación y la resolución seleccionada.',
                          style: TextStyle(
                            color: tokens.chalkDim,
                            fontSize: 11,
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        key: const ValueKey('voluntary-cancellation-error'),
                        style: TextStyle(color: tokens.danger),
                      ),
                    const SizedBox(height: 8),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: widget.canExecute
                        ? PulsoPrimaryButton(
                            key: const ValueKey(
                              'voluntary-cancellation-execute',
                            ),
                            label: 'Confirmar cancelación',
                            icon: Icons.cancel_outlined,
                            busy: _busy,
                            onPressed: _busy ? null : _execute,
                          )
                        : PulsoPrimaryButton(
                            label: 'Cerrar valoración',
                            icon: Icons.check,
                            onPressed: () => Navigator.of(context).pop(false),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    super.key,
    required this.label,
    required this.value,
    this.emphasis = false,
  });
  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: emphasis ? tokens.accentSoft : tokens.raised2,
        border: Border.all(color: emphasis ? tokens.accent : tokens.lineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: tokens.muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: emphasis ? tokens.accent : tokens.chalk,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
