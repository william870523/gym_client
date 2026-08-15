import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../configuration/data/models/payment_type_model.dart';
import '../../../configuration/presentation/state/payment_type_notifier.dart';

class ExchangeRateSurchargeScopeForm extends ConsumerStatefulWidget {
  const ExchangeRateSurchargeScopeForm({
    super.key,
    required this.rateLabel,
    required this.initial,
    required this.globalValues,
    required this.isGlobal,
    required this.onSubmit,
    this.onReset,
  });

  final String rateLabel;
  final Map<String, String> initial;
  final Map<String, String> globalValues;
  final bool isGlobal;
  final Future<void> Function(Map<String, String>) onSubmit;
  final Future<void> Function()? onReset;

  @override
  ConsumerState<ExchangeRateSurchargeScopeForm> createState() =>
      _ExchangeRateSurchargeScopeFormState();
}

class _ExchangeRateSurchargeScopeFormState
    extends ConsumerState<ExchangeRateSurchargeScopeForm> {
  final Map<String, TextEditingController> _controllers = {};
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final entry in widget.initial.entries) {
      _controllers[entry.key] = TextEditingController(text: entry.value);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final values = <String, String>{};
    for (final entry in _controllers.entries) {
      final text = entry.value.text.trim().replaceAll(',', '.');
      if (text.isEmpty) continue;
      final parsed = double.tryParse(text);
      if (parsed == null || parsed < 0 || parsed > 100) {
        setState(() => _error = 'Cada porcentaje debe estar entre 0 y 100.');
        return;
      }
      if (widget.isGlobal && parsed == 0) continue;
      values[entry.key] = text;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(values);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo guardar: $error';
      });
    }
  }

  Future<void> _reset() async {
    final action = widget.onReset;
    if (_busy || action == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo volver al valor global: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PulsoThemeScope(
      child: Builder(
        builder: (context) {
          final tokens = PulsoTokens.of(context);
          final types = ref.watch(paymentTypeNotifierProvider);
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: MediaQuery.sizeOf(context).height - 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(height: 4, color: tokens.accent),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PulsoLabel(
                          widget.isGlobal
                              ? 'CATÁLOGO GLOBAL · PLATAFORMA'
                              : 'EXCEPCIÓN · SEDE ACTIVA',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.isGlobal
                              ? 'RECARGO GLOBAL'
                              : 'RECARGO DE LA SEDE',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.rateLabel,
                          style: TextStyle(
                            color: tokens.accent,
                            fontFamily: PulsoFonts.mono,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.isGlobal
                              ? 'Este valor se hereda en las sedes que no tengan excepción.'
                              : 'Vacío hereda el valor global; 0 % lo desactiva explícitamente en esta sede.',
                          style: TextStyle(color: tokens.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: tokens.line),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null) ...[
                            Text(_error!, style: TextStyle(color: tokens.danger)),
                            const SizedBox(height: 14),
                          ],
                          types.when(
                            loading: () => const LinearProgressIndicator(minHeight: 2),
                            error: (error, _) => Text(
                              'No se cargaron los métodos: $error',
                              style: TextStyle(color: tokens.danger),
                            ),
                            data: (items) => _fields(tokens, items),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(height: 1, color: tokens.line),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (!widget.isGlobal && widget.onReset != null)
                          PulsoSecondaryButton(
                            key: const ValueKey('rate-surcharge-reset-site'),
                            label: 'Heredar global',
                            onPressed: _busy ? null : _reset,
                          ),
                        PulsoSecondaryButton(
                          label: 'Cancelar',
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).pop(false),
                        ),
                        PulsoPrimaryButton(
                          key: const ValueKey('rate-surcharge-save'),
                          label: 'Guardar',
                          busy: _busy,
                          onPressed: _save,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _fields(PulsoTokens tokens, List<PaymentTypeModel> items) {
    final active = [for (final item in items) if (item.active && !item.isDeleted) item];
    if (active.isEmpty) {
      return const PulsoStateView(
        kind: PulsoStateKind.empty,
        message: 'No hay métodos de pago activos.',
      );
    }
    return Column(
      children: [
        for (final item in active) ...[
          TextFormField(
            key: ValueKey('rate-surcharge-${item.id}'),
            controller: _controllers.putIfAbsent(
              item.id,
              () => TextEditingController(),
            ),
            enabled: !_busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}([.,]\d{0,2})?')),
            ],
            decoration: InputDecoration(
              labelText: item.name,
              suffixText: '%',
              helperText: widget.isGlobal
                  ? 'Vacío = sin recargo global.'
                  : 'Global: ${widget.globalValues[item.id] ?? 'sin recargo'}',
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}
