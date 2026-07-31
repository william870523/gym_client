import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/retention_models.dart';

typedef DropoutReasonSubmit =
    Future<void> Function({
      required String name,
      String? code,
      required int order,
      required bool active,
    });

/// Alta y edición de un motivo de baja (docs/PLAN_ESTADISTICAS.md §7-ter).
///
/// El motivo de sistema se puede renombrar y desactivar, pero no borrar: esa
/// regla la impone el servidor y aquí solo se explica, para que el operador no
/// descubra el límite al recibir un error.
class DropoutReasonPulsoForm extends StatefulWidget {
  const DropoutReasonPulsoForm({
    super.key,
    this.reason,
    required this.onSubmit,
  });

  final DropoutReasonModel? reason;
  final DropoutReasonSubmit onSubmit;

  @override
  State<DropoutReasonPulsoForm> createState() => _DropoutReasonPulsoFormState();
}

class _DropoutReasonPulsoFormState extends State<DropoutReasonPulsoForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _orderController;
  late bool _active;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.reason != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.reason?.name ?? '');
    _codeController = TextEditingController(text: widget.reason?.code ?? '');
    _orderController = TextEditingController(
      text: (widget.reason?.order ?? 0).toString(),
    );
    _active = widget.reason?.active ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = _codeController.text.trim();
      await widget.onSubmit(
        name: _nameController.text.trim(),
        code: code.isEmpty ? null : code,
        order: int.tryParse(_orderController.text.trim()) ?? 0,
        active: _active,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo guardar el motivo: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PulsoThemeScope(
      child: Builder(
        builder: (context) {
          final tokens = PulsoTokens.of(context);
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 40,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PulsoLabel(
                        _isEdit ? 'Editar motivo' : 'Nuevo motivo',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const ValueKey('dropout-reason-name'),
                        controller: _nameController,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del motivo *',
                          hintText: 'Ej: Se mudó de barrio',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'El nombre es obligatorio.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const ValueKey('dropout-reason-code'),
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Código (opcional)',
                          hintText: 'Ej: MUDANZA',
                          helperText: 'Se usa en informes y exportaciones CSV.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const ValueKey('dropout-reason-order'),
                        controller: _orderController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Orden',
                          helperText:
                              'Posición en la lista que ve recepción al '
                              'registrar una gestión.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        key: const ValueKey('dropout-reason-active'),
                        value: _active,
                        onChanged: (value) => setState(() => _active = value),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          _active ? 'Activo' : 'Inactivo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _active ? tokens.success : tokens.muted,
                          ),
                        ),
                        subtitle: Text(
                          _active
                              ? 'Se ofrece al registrar una gestión.'
                              : 'Se oculta de gestiones nuevas. Las que ya lo '
                                    'usaron no cambian.',
                          style: TextStyle(fontSize: 11, color: tokens.muted),
                        ),
                      ),
                      if (widget.reason?.isSystem == true) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Es un motivo base: puedes renombrarlo y desactivarlo, '
                          'pero no borrarlo.',
                          style: TextStyle(fontSize: 11, color: tokens.muted),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(fontSize: 12, color: tokens.danger),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          PulsoSecondaryButton(
                            label: 'Cancelar',
                            onPressed: _busy
                                ? null
                                : () => Navigator.of(context).pop(false),
                          ),
                          const SizedBox(width: 10),
                          PulsoPrimaryButton(
                            key: const ValueKey('dropout-reason-save'),
                            label: _busy ? 'Guardando…' : 'Guardar',
                            onPressed: _busy ? null : _submit,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
