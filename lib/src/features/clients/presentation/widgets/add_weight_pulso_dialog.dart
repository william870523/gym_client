import 'package:flutter/material.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/client_model.dart';

typedef AddWeightSubmit = Future<void> Function(double weight);

class AddWeightPulsoDialog extends StatefulWidget {
  const AddWeightPulsoDialog({
    super.key,
    required this.client,
    required this.onSubmit,
  });

  final ClientModel client;
  final AddWeightSubmit onSubmit;

  @override
  State<AddWeightPulsoDialog> createState() => _AddWeightPulsoDialogState();
}

class _AddWeightPulsoDialogState extends State<AddWeightPulsoDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final weight = double.tryParse(
      _controller.text.trim().replaceAll(',', '.'),
    );
    if (weight == null || weight < 20 || weight > 400) {
      setState(() => _error = 'Ingrese un peso válido entre 20 y 400 kg.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(weight);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo registrar el peso: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PulsoThemeScope(
      child: Builder(
        builder: (context) {
          final tokens = PulsoTokens.of(context);
          final name =
              '${widget.client.nombres ?? ''} ${widget.client.apellidos ?? ''}'
                  .trim();
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PulsoLabel('PULSO · PROGRESO'),
                    const SizedBox(height: 8),
                    Text(
                      'REGISTRAR PESO',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$name · ${widget.client.id}',
                      style: TextStyle(color: tokens.muted),
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        color: tokens.dangerSoft,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: tokens.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextField(
                      key: const ValueKey('pulso-client-new-weight'),
                      controller: _controller,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Peso actual',
                        suffixText: 'kg',
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'El registro utiliza la hora UTC confiable y se mostrará en la zona del gimnasio.',
                      style: TextStyle(color: tokens.muted, fontSize: 11),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        PulsoSecondaryButton(
                          label: 'Cancelar',
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).pop(false),
                        ),
                        PulsoPrimaryButton(
                          label: 'Registrar',
                          onPressed: _submit,
                          busy: _busy,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
