import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';

typedef PaymentTypePulsoSubmit =
    Future<void> Function(String name, String code, bool active);

class PaymentTypePulsoForm extends StatefulWidget {
  const PaymentTypePulsoForm({
    super.key,
    this.id,
    this.initialName,
    this.initialCode,
    this.initialActive = true,
    required this.onSubmit,
  });

  final String? id;
  final String? initialName;
  final String? initialCode;
  final bool initialActive;
  final PaymentTypePulsoSubmit onSubmit;

  @override
  State<PaymentTypePulsoForm> createState() => _PaymentTypePulsoFormState();
}

class _PaymentTypePulsoFormState extends State<PaymentTypePulsoForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late bool _active;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.id != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _codeController = TextEditingController(text: widget.initialCode);
    _active = widget.initialActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        _nameController.text.trim(),
        _codeController.text.trim().toUpperCase(),
        _active,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo guardar el tipo de pago: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PulsoThemeScope(
      child: Builder(
        builder: (context) {
          final tokens = PulsoTokens.of(context);
          final screen = MediaQuery.sizeOf(context);
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 620,
                maxHeight: screen.height - 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(height: 4, color: tokens.accent),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 20, 18),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final copy = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const PulsoLabel('PULSO · CONFIGURACIÓN'),
                            const SizedBox(height: 9),
                            Text(
                              _isEdit
                                  ? 'EDITAR TIPO DE PAGO'
                                  : 'NUEVO TIPO DE PAGO',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Define cómo aparecerá este medio durante los cobros y reportes.',
                              style: TextStyle(
                                color: tokens.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        );
                        final actions = Wrap(
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
                              label: _isEdit ? 'Guardar cambios' : 'Crear',
                              onPressed: _submit,
                              busy: _busy,
                            ),
                          ],
                        );
                        if (constraints.maxWidth < 520) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              copy,
                              const SizedBox(height: 18),
                              actions,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: copy),
                            const SizedBox(width: 18),
                            actions,
                          ],
                        );
                      },
                    ),
                  ),
                  Divider(height: 1, color: tokens.line),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                color: tokens.dangerSoft,
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: tokens.danger,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            const PulsoLabel('Identidad contable'),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey('pulso-payment-type-name'),
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Nombre del tipo de pago',
                                hintText: 'Ej. Efectivo',
                              ),
                              validator: _required,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const ValueKey('pulso-payment-type-code'),
                              controller: _codeController,
                              inputFormatters: const [_PaymentCodeFormatter()],
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              style: const TextStyle(
                                fontFamily: PulsoFonts.mono,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Código interno',
                                hintText: 'CASH',
                                helperText:
                                    'Se utiliza en reportes y sincronización.',
                              ),
                              validator: _required,
                            ),
                            const SizedBox(height: 24),
                            const PulsoLabel('Disponibilidad operativa'),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _active
                                    ? tokens.successSoft
                                    : tokens.raised,
                                border: Border.all(
                                  color: _active ? tokens.success : tokens.line,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _active
                                        ? Icons.check_circle_outline
                                        : Icons.pause_circle_outline,
                                    color: _active
                                        ? tokens.success
                                        : tokens.muted,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _active ? 'Activo' : 'Inactivo',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: tokens.chalk,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _active
                                              ? 'Disponible para nuevos cobros.'
                                              : 'Oculto al registrar nuevos cobros.',
                                          style: TextStyle(
                                            color: tokens.muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: _active,
                                    activeThumbColor: tokens.success,
                                    onChanged: _busy
                                        ? null
                                        : (value) =>
                                              setState(() => _active = value),
                                  ),
                                ],
                              ),
                            ),
                            if (_isEdit && widget.id != null) ...[
                              const SizedBox(height: 18),
                              Text(
                                'ID · ${widget.id}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: PulsoFonts.mono,
                                  fontSize: 10,
                                  color: tokens.muted2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
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
}

class _PaymentCodeFormatter extends TextInputFormatter {
  const _PaymentCodeFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text
        .replaceAll(RegExp('[^a-zA-Z0-9_-]'), '')
        .toUpperCase();
    return newValue.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }
}

String? _required(String? value) {
  return value?.trim().isNotEmpty == true ? null : 'Campo obligatorio.';
}
