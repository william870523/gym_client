import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../auth/domain/models/user.dart';
import '../../../gyms/presentation/gyms_provider.dart';

typedef UserPulsoSubmit = Future<void> Function(User user);

/// Alta y edición de usuarios en PULSO. Mantiene la lógica original:
/// contraseña obligatoria al crear (opcional al editar) con los mismos cinco
/// criterios de seguridad, rol del sistema y gimnasio asignado (solo web).
class UserPulsoForm extends ConsumerStatefulWidget {
  const UserPulsoForm({super.key, this.user, required this.onSubmit});

  final User? user;
  final UserPulsoSubmit onSubmit;

  @override
  ConsumerState<UserPulsoForm> createState() => _UserPulsoFormState();
}

class _UserPulsoFormState extends ConsumerState<UserPulsoForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String _role = 'reception';
  String? _gymId;
  bool _active = true;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.user != null;

  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasUppercase => _passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => _passwordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasDigit => _passwordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial =>
      _passwordController.text.contains(RegExp(r'[!@#\$&*~]'));
  bool get _passwordOk =>
      _hasMinLength &&
      _hasUppercase &&
      _hasLowercase &&
      _hasDigit &&
      _hasSpecial;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _nameController = TextEditingController(text: user?.name);
    _emailController = TextEditingController(text: user?.email);
    if (user != null) {
      _role = user.role;
      _gymId = user.gymId;
      _active = user.active;
    } else {
      // Al crear, la sección de contraseña es parte del alta.
      _showPassword = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Roles que el sistema ofrece al crear o editar una cuenta.
  static const _knownRoles = <String>[
    'admin',
    'reception',
    'accounting',
    'trainer',
    'maintenance',
  ];

  /// Opciones del desplegable **incluyendo el rol que la cuenta ya tiene**.
  ///
  /// Sin esto, abrir un usuario cuyo rol no esté en la lista —el `user` por
  /// defecto del esquema, o cualquier rol sembrado por una fixture— reventaba
  /// el formulario entero con una aserción de Flutter en vez de dejar
  /// corregirlo. Se conserva el valor tal cual para no cambiar el rol de nadie
  /// por el mero hecho de abrir su ficha.
  List<String> get _roleOptions => [
    ..._knownRoles,
    if (_role.isNotEmpty && !_knownRoles.contains(_role)) _role,
  ];

  String _roleLabel(String role) => switch (role) {
    'admin' => 'Administrador',
    'reception' => 'Recepción',
    'accounting' => 'Contabilidad / Control',
    'trainer' => 'Entrenador',
    'maintenance' => 'Mantenimiento',
    _ => role,
  };

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    final settingPassword = _passwordController.text.isNotEmpty;
    if (!_isEdit && !settingPassword) {
      setState(() => _error = 'La contraseña es obligatoria al crear.');
      return;
    }
    if (settingPassword) {
      if (!_passwordOk) {
        setState(
          () => _error = 'La contraseña no cumple los requisitos de seguridad.',
        );
        return;
      }
      if (_passwordController.text != _confirmController.text) {
        setState(() => _error = 'Las contraseñas no coinciden.');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final user = User(
      id: widget.user?.id ?? '',
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      role: _role,
      active: _active,
      status: _active ? 'active' : 'inactive',
      password: settingPassword ? _passwordController.text : null,
      imageUrl: widget.user?.imageUrl,
      gymId: _gymId,
    );
    try {
      await widget.onSubmit(user);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo guardar el usuario: $error';
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
                            const PulsoLabel('PULSO · EQUIPO'),
                            const SizedBox(height: 9),
                            Text(
                              _isEdit ? 'EDITAR USUARIO' : 'NUEVO USUARIO',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'La cuenta define quién entra al sistema y con qué rol opera.',
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
                            const PulsoLabel('Identidad de la cuenta'),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey('pulso-user-name'),
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Nombre completo',
                                hintText: 'Ej. Laura Fernández',
                              ),
                              validator: (value) =>
                                  (value ?? '').trim().length < 3
                                  ? 'Mínimo 3 caracteres.'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const ValueKey('pulso-user-email'),
                              controller: _emailController,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Correo corporativo',
                                hintText: 'usuario@gimnasio.com',
                              ),
                              validator: (value) => (value ?? '').trim().isEmpty
                                  ? 'Campo obligatorio.'
                                  : null,
                            ),
                            const SizedBox(height: 24),
                            const PulsoLabel('Rol y cobertura'),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: const ValueKey('pulso-user-role'),
                              initialValue: _role,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Rol del sistema',
                              ),
                              items: [
                                for (final role in _roleOptions)
                                  DropdownMenuItem(
                                    value: role,
                                    child: Text(
                                      _knownRoles.contains(role)
                                          ? _roleLabel(role)
                                          : '$role (rol heredado)',
                                    ),
                                  ),
                              ],
                              onChanged: _busy
                                  ? null
                                  : (value) => setState(
                                      () => _role = value ?? 'reception',
                                    ),
                            ),
                            // El gimnasio asignado solo aplica en la gestión
                            // remota (web), igual que en la pantalla original.
                            if (kIsWeb) ...[
                              const SizedBox(height: 16),
                              _buildGymField(context),
                            ],
                            const SizedBox(height: 24),
                            const PulsoLabel('Disponibilidad operativa'),
                            const SizedBox(height: 12),
                            _buildStatusField(context),
                            const SizedBox(height: 24),
                            const PulsoLabel('Seguridad'),
                            const SizedBox(height: 12),
                            if (_isEdit && !_showPassword)
                              PulsoSecondaryButton(
                                label: 'Restablecer contraseña',
                                icon: Icons.lock_reset,
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                        _showPassword = true;
                                        _passwordController.clear();
                                        _confirmController.clear();
                                      }),
                              )
                            else
                              _buildPasswordFields(context),
                            if (_isEdit) ...[
                              const SizedBox(height: 18),
                              Text(
                                'ID · ${widget.user!.id}',
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

  Widget _buildGymField(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final gymsState = ref.watch(gymsListProvider);
    return gymsState.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (error, _) => Text(
        'No se pudo cargar el catálogo de gimnasios: $error',
        style: TextStyle(color: tokens.danger, fontSize: 12),
      ),
      data: (gyms) {
        if (gyms.isEmpty) {
          return Text(
            'No hay gimnasios disponibles.',
            style: TextStyle(color: tokens.muted, fontSize: 12),
          );
        }
        final known = gyms.any((gym) => gym.id == _gymId);
        return DropdownButtonFormField<String>(
          key: const ValueKey('pulso-user-gym'),
          initialValue: known ? _gymId : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Gimnasio asignado',
            hintText: 'Selecciona la sede',
          ),
          items: [
            for (final gym in gyms)
              DropdownMenuItem(
                value: gym.id,
                child: Text(
                  '${gym.name} (${gym.code})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _busy ? null : (value) => setState(() => _gymId = value),
        );
      },
    );
  }

  Widget _buildStatusField(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _active ? tokens.successSoft : tokens.raised,
        border: Border.all(color: _active ? tokens.success : tokens.line),
      ),
      child: Row(
        children: [
          Icon(
            _active ? Icons.check_circle_outline : Icons.pause_circle_outline,
            color: _active ? tokens.success : tokens.muted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      ? 'Puede iniciar sesión y operar según su rol.'
                      : 'El acceso al sistema queda suspendido.',
                  style: TextStyle(color: tokens.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _active,
            activeThumbColor: tokens.success,
            onChanged: _busy
                ? null
                : (value) => setState(() => _active = value),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const ValueKey('pulso-user-password'),
          controller: _passwordController,
          obscureText: true,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontFamily: PulsoFonts.mono),
          decoration: InputDecoration(
            labelText: _isEdit ? 'Nueva contraseña' : 'Contraseña',
            hintText: '••••••••',
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const ValueKey('pulso-user-password-confirm'),
          controller: _confirmController,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          style: const TextStyle(fontFamily: PulsoFonts.mono),
          decoration: const InputDecoration(
            labelText: 'Confirmar contraseña',
            hintText: '••••••••',
          ),
        ),
        const SizedBox(height: 14),
        _CriteriaRow(label: 'Mínimo 8 caracteres', met: _hasMinLength),
        _CriteriaRow(label: 'Una letra mayúscula', met: _hasUppercase),
        _CriteriaRow(label: 'Una letra minúscula', met: _hasLowercase),
        _CriteriaRow(label: 'Un número', met: _hasDigit),
        _CriteriaRow(
          label: r'Un carácter especial (!@#$&*~)',
          met: _hasSpecial,
        ),
      ],
    );
  }
}

class _CriteriaRow extends StatelessWidget {
  const _CriteriaRow({required this.label, required this.met});
  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = met ? tokens.success : tokens.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_outline : Icons.circle_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: met ? FontWeight.w700 : FontWeight.w400,
                color: met ? tokens.chalkDim : tokens.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
