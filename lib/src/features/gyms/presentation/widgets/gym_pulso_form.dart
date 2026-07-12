import 'package:flutter/material.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../domain/models/gym.dart';

typedef GymPulsoSubmit = Future<void> Function(Gym gym);

class GymPulsoForm extends StatefulWidget {
  const GymPulsoForm({super.key, this.gym, required this.onSubmit});

  final Gym? gym;
  final GymPulsoSubmit onSubmit;

  @override
  State<GymPulsoForm> createState() => _GymPulsoFormState();
}

class _GymPulsoFormState extends State<GymPulsoForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _zipController;

  String _country = '';
  late String _timezone;
  bool _active = true;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.gym != null;

  @override
  void initState() {
    super.initState();
    final gym = widget.gym;
    _codeController = TextEditingController(text: gym?.code);
    _nameController = TextEditingController(text: gym?.name);
    _addressController = TextEditingController(text: gym?.address);
    _cityController = TextEditingController(text: gym?.city);
    _stateController = TextEditingController(text: gym?.state);
    _zipController = TextEditingController(text: gym?.zipCode);
    _country = gym?.country ?? '';
    _timezone = gym?.timezone ?? appClock.gymTimezone;
    _active = gym?.active ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final gym = Gym(
      id: widget.gym?.id ?? '',
      code: _codeController.text.trim().toUpperCase(),
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      country: _country,
      timezone: _timezone.trim(),
      zipCode: _zipController.text.trim(),
      active: _active,
    );
    try {
      await widget.onSubmit(gym);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo guardar la sede: $error';
      });
    }
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Campo requerido.' : null;

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
                maxWidth: 760,
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
                            const PulsoLabel('PULSO · RED DE SEDES'),
                            const SizedBox(height: 9),
                            Text(
                              _isEdit ? 'EDITAR GIMNASIO' : 'NUEVO GIMNASIO',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Identidad, ubicación y zona horaria comercial de la sede.',
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
                              label: _isEdit ? 'Guardar cambios' : 'Crear sede',
                              onPressed: _submit,
                              busy: _busy,
                            ),
                          ],
                        );
                        if (constraints.maxWidth < 600) {
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
                            const PulsoLabel('Identidad de la sede'),
                            const SizedBox(height: 12),
                            _ResponsiveFields(
                              children: [
                                TextFormField(
                                  key: const ValueKey('pulso-gym-code'),
                                  controller: _codeController,
                                  readOnly: _isEdit,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    labelText: 'Código',
                                    hintText: 'GYM-001',
                                    helperText: _isEdit
                                        ? 'El código no se modifica.'
                                        : null,
                                  ),
                                  validator: _required,
                                ),
                                TextFormField(
                                  key: const ValueKey('pulso-gym-name'),
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nombre comercial',
                                    hintText: 'Gym Central',
                                  ),
                                  validator: _required,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const PulsoLabel('Ubicación comercial'),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey('pulso-gym-address'),
                              controller: _addressController,
                              decoration: const InputDecoration(
                                labelText: 'Dirección',
                                hintText: 'Calle, número y local',
                              ),
                              validator: _required,
                            ),
                            const SizedBox(height: 16),
                            _ResponsiveFields(
                              children: [
                                TextFormField(
                                  controller: _cityController,
                                  decoration: const InputDecoration(
                                    labelText: 'Ciudad',
                                  ),
                                  validator: _required,
                                ),
                                TextFormField(
                                  controller: _stateController,
                                  decoration: const InputDecoration(
                                    labelText: 'Provincia / estado',
                                  ),
                                  validator: _required,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _ResponsiveFields(
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: _country,
                                  decoration: const InputDecoration(
                                    labelText: 'País',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: '',
                                      child: Text('Sin definir'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'CU',
                                      child: Text('Cuba'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'ES',
                                      child: Text('España'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'MX',
                                      child: Text('México'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'AR',
                                      child: Text('Argentina'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'CO',
                                      child: Text('Colombia'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'US',
                                      child: Text('Estados Unidos'),
                                    ),
                                  ],
                                  onChanged: _busy
                                      ? null
                                      : (value) => setState(
                                          () => _country = value ?? '',
                                        ),
                                ),
                                TextFormField(
                                  controller: _zipController,
                                  decoration: const InputDecoration(
                                    labelText: 'Código postal',
                                  ),
                                  validator: _required,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const PulsoLabel('Configuración operativa'),
                            const SizedBox(height: 12),
                            _ResponsiveFields(
                              children: [
                                Autocomplete<String>(
                                  initialValue: TextEditingValue(
                                    text: _timezone,
                                  ),
                                  optionsBuilder: (value) {
                                    final query = value.text
                                        .trim()
                                        .toLowerCase();
                                    return availableGymTimezones
                                        .where(
                                          (zone) =>
                                              query.isEmpty ||
                                              zone.toLowerCase().contains(
                                                query,
                                              ),
                                        )
                                        .take(80);
                                  },
                                  onSelected: (value) => _timezone = value,
                                  fieldViewBuilder:
                                      (
                                        context,
                                        controller,
                                        focusNode,
                                        onFieldSubmitted,
                                      ) {
                                        return TextFormField(
                                          key: const ValueKey(
                                            'pulso-gym-timezone',
                                          ),
                                          controller: controller,
                                          focusNode: focusNode,
                                          onChanged: (value) =>
                                              _timezone = value.trim(),
                                          decoration: const InputDecoration(
                                            labelText: 'Zona horaria IANA',
                                            hintText: 'America/Los_Angeles',
                                          ),
                                          validator: (value) =>
                                              isKnownGymTimezone(
                                                (value ?? '').trim(),
                                              )
                                              ? null
                                              : 'Seleccione una zona IANA válida.',
                                        );
                                      },
                                ),
                                Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 58,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.raised,
                                    border: Border.all(
                                      color: tokens.lineStrong,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Sede activa',
                                              style: TextStyle(
                                                color: tokens.chalk,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              _active
                                                  ? 'Operativa'
                                                  : 'Fuera de operación',
                                              style: TextStyle(
                                                color: _active
                                                    ? tokens.success
                                                    : tokens.warning,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch.adaptive(
                                        value: _active,
                                        onChanged: _busy
                                            ? null
                                            : (value) => setState(
                                                () => _active = value,
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'La zona horaria define cómo se muestra la hora del negocio. Los instantes continúan almacenándose en UTC.',
                              style: TextStyle(
                                color: tokens.muted,
                                fontSize: 12,
                              ),
                            ),
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

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) const SizedBox(height: 16),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              Expanded(child: children[index]),
              if (index != children.length - 1) const SizedBox(width: 16),
            ],
          ],
        );
      },
    );
  }
}
