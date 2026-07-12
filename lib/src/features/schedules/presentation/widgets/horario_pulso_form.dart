import 'package:flutter/material.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/horario_model.dart';

typedef HorarioPulsoSubmit =
    Future<void> Function(String nombre, int horaInicio, int horaFin);

class HorarioPulsoForm extends StatefulWidget {
  const HorarioPulsoForm({super.key, this.horario, required this.onSubmit});

  final HorarioModel? horario;
  final HorarioPulsoSubmit onSubmit;

  @override
  State<HorarioPulsoForm> createState() => _HorarioPulsoFormState();
}

class _HorarioPulsoFormState extends State<HorarioPulsoForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late TimeOfDay _horaInicio;
  late TimeOfDay _horaFin;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.horario != null;

  int get _inicioMinutes => _horaInicio.hour * 60 + _horaInicio.minute;
  int get _finMinutes => _horaFin.hour * 60 + _horaFin.minute;

  @override
  void initState() {
    super.initState();
    final horario = widget.horario;
    _nameController = TextEditingController(text: horario?.nombre);
    _horaInicio = horario == null
        ? const TimeOfDay(hour: 8, minute: 0)
        : TimeOfDay(
            hour: horario.horaInicio ~/ 60,
            minute: horario.horaInicio % 60,
          );
    _horaFin = horario == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay(hour: horario.horaFin ~/ 60, minute: horario.horaFin % 60);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _horaInicio : _horaFin,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _horaInicio = picked;
      } else {
        _horaFin = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    if (_inicioMinutes == _finMinutes) {
      setState(
        () => _error = 'La hora de inicio y la de fin no pueden coincidir.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        _nameController.text.trim(),
        _inicioMinutes,
        _finMinutes,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo guardar el horario: $error';
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
                            const PulsoLabel('PULSO · OPERACIÓN'),
                            const SizedBox(height: 9),
                            Text(
                              _isEdit ? 'EDITAR HORARIO' : 'NUEVO HORARIO',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'La franja define cuándo llegan los socios asignados a ella.',
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
                            const PulsoLabel('Identidad de la franja'),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey('pulso-horario-name'),
                              controller: _nameController,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: 'Nombre del horario',
                                hintText: 'Ej. Mañana temprano',
                              ),
                              validator: _required,
                            ),
                            const SizedBox(height: 24),
                            const PulsoLabel('Ventana de la franja'),
                            const SizedBox(height: 12),
                            _buildTimeFields(context),
                            if (_finMinutes < _inicioMinutes) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                color: tokens.warningSoft,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.nightlight_outlined,
                                      size: 18,
                                      color: tokens.warning,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'La franja cruza la medianoche: termina al día siguiente.',
                                        style: TextStyle(
                                          color: tokens.chalkDim,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_isEdit &&
                                widget.horario!.id.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              Text(
                                'ID · ${widget.horario!.id}',
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

  Widget _buildTimeFields(BuildContext context) {
    final start = _TimeField(
      key: ValueKey('pulso-horario-start-$_inicioMinutes'),
      label: 'Hora de inicio',
      value: HorarioModel.formatTime(_inicioMinutes),
      onTap: _busy ? null : () => _pickTime(true),
    );
    final end = _TimeField(
      key: ValueKey('pulso-horario-end-$_finMinutes'),
      label: 'Hora de fin',
      value: HorarioModel.formatTime(_finMinutes),
      onTap: _busy ? null : () => _pickTime(false),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [start, const SizedBox(height: 16), end],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: start),
            const SizedBox(width: 16),
            Expanded(child: end),
          ],
        );
      },
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      onTap: onTap,
      style: const TextStyle(
        fontFamily: PulsoFonts.mono,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.schedule_outlined, size: 18),
      ),
    );
  }
}

String? _required(String? value) {
  return value?.trim().isNotEmpty == true ? null : 'Campo obligatorio.';
}
