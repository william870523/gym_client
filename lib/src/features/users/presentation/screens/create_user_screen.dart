import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/domain/models/user.dart';
import '../providers/users_provider.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import '../../../gyms/presentation/gyms_provider.dart';

class CreateUserScreen extends ConsumerStatefulWidget {
  final User? userToEdit; // If provided, we are in Edit mode
  const CreateUserScreen({super.key, this.userToEdit});

  @override
  ConsumerState<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends ConsumerState<CreateUserScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'admin';
  String? _selectedGymId; // Null by default, or loaded from user

  bool _isEditing = false;
  bool _isActive = true;
  bool _showPasswordReset = false; // For Edit mode

  // Password Validation State
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasDigit = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    if (widget.userToEdit != null) {
      _isEditing = true;
      _nameController.text = widget.userToEdit!.name;
      _emailController.text = widget.userToEdit!.email;
      _selectedRole = widget.userToEdit!.role;
      _isActive = widget.userToEdit!.active;
      _selectedGymId = widget.userToEdit!.gymId;
    }
  }

  void _updatePasswordStrength(String password) {
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasDigit = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#\$&*~]'));
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: backgroundColor,
      // Common AppBar or specific per mode? Using common for navigation safety
      appBar: AppBar(
        title: Text(_isEditing ? l10n.updateUserButton : l10n.createUserTitle),
        centerTitle: false,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: _isEditing ? _buildEditUI(context) : _buildCreateUI(context),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // EDIT UI
  // ===========================================================================
  Widget _buildEditUI(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF0D121B);
    final textMuted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final primary = const Color(0xFF136DEC);
    final borderColor = isDark ? Colors.white10 : Colors.grey.shade200;
    final l10n = AppLocalizations.of(context)!;
    final createdLabel = widget.userToEdit?.id != null ? "12 Mar 2023" : "-";

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            // Profile Header
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
                image: widget.userToEdit?.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(widget.userToEdit!.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: widget.userToEdit?.imageUrl == null
                  ? Icon(Icons.person, size: 50, color: Colors.grey.shade400)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              widget.userToEdit?.name ?? l10n.userFallbackName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textMain,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.createdLabel(createdLabel),
              style: TextStyle(color: textMuted, fontSize: 14),
            ),
            const SizedBox(height: 32),

            // Form Fields
            _buildTextField(
              label: l10n.usernameLabel.toUpperCase(),
              controller: _nameController,
              textMain: textMain,
              borderColor: borderColor,
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              label: l10n.corporateEmailLabel.toUpperCase(),
              controller: _emailController,
              textMain: textMain,
              borderColor: borderColor,
              icon: Icons.email_outlined,
            ),
            const SizedBox(height: 16),

            _buildLabel(l10n.systemRoleLabel.toUpperCase(), textMuted),
            const SizedBox(height: 8),
            _buildRoleDropdown(surfaceColor, textMain, borderColor),
            const SizedBox(height: 16),

            if (kIsWeb) ...[
              _buildLabel(l10n.assignedGymLabel.toUpperCase(), textMuted),
              const SizedBox(height: 8),
              _buildGymDropdown(surfaceColor, textMain, borderColor),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 24),

            Divider(color: borderColor),
            const SizedBox(height: 24),

            // Active Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.userActiveLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textMain,
                      ),
                    ),
                    Text(
                      _isActive
                          ? l10n.userActiveSubtitleOn
                          : l10n.userActiveSubtitleOff,
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                  ],
                ),
                Switch(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  activeColor: primary,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Password Reset Toggle
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showPasswordReset = !_showPasswordReset;
                    _passwordController.clear();
                    _confirmPasswordController.clear();
                  });
                },
                icon: const Icon(Icons.lock_reset, size: 20),
                label: Text(l10n.resetPasswordButton),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: textMain,
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            if (_showPasswordReset) ...[
              const SizedBox(height: 24),
              _buildTextField(
                label: l10n.newPasswordLabel,
                controller: _passwordController,
                isPassword: true,
                textMain: textMain,
                borderColor: borderColor,
                onChanged: _updatePasswordStrength,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: l10n.confirmPasswordLabel,
                controller: _confirmPasswordController,
                isPassword: true,
                textMain: textMain,
                borderColor: borderColor,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child:
                    _buildPasswordCriteria(l10n), // Show criteria when resetting
              ),
            ],

            const SizedBox(height: 32),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      l10n.saveChangesButton,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: textMain,
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(l10n.cancelButton),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // CREATE UI
  // ===========================================================================
  Widget _buildCreateUI(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF0D121B);
    final textMuted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final primary = const Color(0xFF136DEC);
    final borderColor = isDark ? Colors.white10 : Colors.grey.shade200;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Intro Text
        // Intro Text
        Text(
          l10n.createUserTitle,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: textMain,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.createUserSubtitle,
          style: TextStyle(fontSize: 16, color: textMuted),
        ),
        const SizedBox(height: 32),

        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Name & Email
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTextField(
                      label: l10n.fullNameLabel,
                      hint: l10n.fullNameHint,
                      controller: _nameController,
                      icon: Icons.person_outline,
                      textMain: textMain,
                      borderColor: borderColor,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildTextField(
                      label: l10n.emailLabel,
                      hint: l10n.emailHint,
                      controller: _emailController,
                      icon: Icons.mail_outline,
                      textMain: textMain,
                      borderColor: borderColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Role
              // Role
              Text(
                l10n.systemRoleLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textMain,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              _buildRoleDropdown(
                isDark ? Colors.black12 : Colors.grey.shade50,
                textMain,
                borderColor,
              ),

              // GYM SELECTOR (Only on Web/Remote)
              if (kIsWeb) ...[
                const SizedBox(height: 24),
                Text(
                  l10n.assignedGymLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textMain,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                _buildGymDropdown(
                  isDark ? Colors.black12 : Colors.grey.shade50,
                  textMain,
                  borderColor,
                ),
              ],

              const SizedBox(height: 24),

              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.black12 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: SwitchListTile.adaptive(
                  title: Text(
                    l10n.userActiveLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textMain,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    _isActive
                        ? l10n.userActiveSubtitleOn
                        : l10n.userActiveSubtitleOff,
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                  value: _isActive,
                  activeColor: primary,
                  onChanged: (val) => setState(() => _isActive = val),
                ),
              ),

              const SizedBox(height: 32),

              Divider(color: borderColor, height: 48),

              Text(
                l10n.securitySectionTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textMain,
                ),
              ),
              const SizedBox(height: 16),

              // Layout for Password & Requirements
              // Using LayoutBuilder or just Row effectively
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Password Fields
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        _buildTextField(
                          label: l10n.passwordLabel,
                          hint: '********',
                          controller: _passwordController,
                          isPassword: true,
                          textMain: textMain,
                          borderColor: borderColor,
                          onChanged: _updatePasswordStrength,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: l10n.confirmPasswordLabel,
                          hint: '********',
                          controller: _confirmPasswordController,
                          isPassword: true,
                          textMain: textMain,
                          borderColor: borderColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Right: Security Requirements Box
                  Expanded(
                    flex: 4,
                    child: _buildSecurityRequirementsBox(isDark, l10n),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      l10n.cancelButton,
                      style: TextStyle(
                        color: textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _saveUser,
                    icon: const Icon(Icons.save, size: 20),
                    label: Text(l10n.createUserButton),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // WIDGET HELPERS
  // ===========================================================================

  Widget _buildLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: 11,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildRoleDropdown(Color bgColor, Color textColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRole,
          isExpanded: true,
          dropdownColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E293B)
              : Colors.white,
          style: TextStyle(color: textColor),
          items: ['admin', 'reception', 'trainer', 'maintenance']
              .map(
                (r) => DropdownMenuItem(
                  value: r,
                  child: Row(
                    children: [
                      Icon(
                        Icons.badge_outlined,
                        size: 18,
                        color: textColor.withOpacity(0.7),
                      ),
                      const SizedBox(width: 12),
                      Text(r.toUpperCase()),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedRole = v!),
        ),
      ),
    );
  }

  Widget _buildGymDropdown(Color bgColor, Color textColor, Color borderColor) {
    final l10n = AppLocalizations.of(context)!;
    final gymsAsync = ref.watch(gymsListProvider);

    return gymsAsync.when(
      data: (gyms) {
        if (gyms.isEmpty) {
          return Text(l10n.noGymsAvailable);
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedGymId,
              hint: Text(
                l10n.selectGymHint,
                style: TextStyle(color: textColor),
              ),
              isExpanded: true,
              dropdownColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E293B)
                  : Colors.white,
              style: TextStyle(color: textColor),
              items: gyms
                  .map(
                    (g) => DropdownMenuItem(
                      value: g.id,
                      child: Text("${g.name} (${g.code})"),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedGymId = v),
            ),
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, s) =>
          Text(l10n.gymsLoadError, style: TextStyle(color: Colors.red)),
    );
  }

  Widget _buildTextField({
    required String label,
    String? hint,
    required TextEditingController controller,
    IconData? icon,
    bool isPassword = false,
    required Color textMain,
    required Color borderColor,
    bool readOnly = false,
    Function(String)? onChanged,
  }) {
    final isDark = textMain == Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textMain,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          obscureText: isPassword,
          readOnly: readOnly,
          style: TextStyle(color: textMain),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            suffixIcon: isPassword
                ? const Icon(Icons.visibility_off, color: Colors.grey)
                : (icon != null ? Icon(icon, color: Colors.grey) : null),
            filled: true,
            fillColor: isDark ? Colors.black12 : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityRequirementsBox(
    bool isDark,
    AppLocalizations l10n,
  ) {
    final bgColor = isDark
        ? const Color(0xFF172033)
        : const Color(0xFFF1F8FF); // Light blue for requirements
    final iconColor = const Color(0xFF136DEC); // Blue shield
    final textColor = isDark ? Colors.white : const Color(0xFF0D121B);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Text(
                l10n.securityRequirementsTitle,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCriteriaRow(l10n.reqMinLength, _hasMinLength),
          _buildCriteriaRow(l10n.reqUppercase, _hasUppercase),
          _buildCriteriaRow(l10n.reqLowercase, _hasLowercase),
          _buildCriteriaRow(l10n.reqDigit, _hasDigit),
          _buildCriteriaRow(l10n.reqSpecialChar, _hasSpecialChar),
        ],
      ),
    );
  }

  Widget _buildPasswordCriteria(AppLocalizations l10n) {
    // Logic reused for Edit screen if needed, but styled differently
    return Column(
      children: [
        _buildCriteriaRow(l10n.reqMinLength, _hasMinLength),
        _buildCriteriaRow(l10n.reqUppercase, _hasUppercase),
        _buildCriteriaRow(l10n.reqLowercase, _hasLowercase),
        _buildCriteriaRow(l10n.reqDigit, _hasDigit),
        _buildCriteriaRow(l10n.reqSpecialChar, _hasSpecialChar),
      ],
    );
  }

  Widget _buildCriteriaRow(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.remove_circle,
            color: met ? Colors.green : Colors.grey.shade400,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: met ? Colors.green.shade700 : Colors.grey.shade600,
              fontSize: 13,
              fontWeight: met ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveUser() async {
    final l10n = AppLocalizations.of(context)!;
    // Validate
    if (_nameController.text.trim().length < 3 ||
        _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.nameEmailRequired)),
      );
      return;
    }

    // Password validation:
    // - Required for New Users
    // - Required for Edit User ONLY if fields are not empty
    bool passwordIsBeingSet = _passwordController.text.isNotEmpty;

    if (!_isEditing) {
      // Creating: Password is mandatory and must meet criteria
      if (!passwordIsBeingSet) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.passwordRequiredNew)),
        );
        return;
      }
    }

    if (passwordIsBeingSet) {
      if (!_hasMinLength ||
          !_hasUppercase ||
          !_hasLowercase ||
          !_hasDigit ||
          !_hasSpecialChar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.passwordRequirementsFail)),
        );
        return;
      }

      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.passwordsDoNotMatch)),
        );
        return;
      }
    }

    final newUser = User(
      id: _isEditing ? widget.userToEdit!.id : '',
      name: _nameController.text,
      email: _emailController.text,
      role: _selectedRole,
      active: _isActive,
      // Status string kept for compatibility, optional
      status: _isActive ? 'active' : 'inactive',
      password: passwordIsBeingSet ? _passwordController.text : null,
      imageUrl: widget.userToEdit?.imageUrl,
      gymId: _selectedGymId, // Pass selected gym
    );

    try {
      if (_isEditing) {
        await ref.read(usersProvider.notifier).updateUser(newUser);
      } else {
        await ref.read(usersProvider.notifier).createUser(newUser);
      }

      if (!mounted) return;

      // Show Success Dialog
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text(l10n.successTitle),
            ],
          ),
          content: Text(
            _isEditing
                ? l10n.successUserUpdated
                : l10n.successUserCreated,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
              },
              child: Text(l10n.okButton),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.pop(context); // Go back to list
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorWithDetails('$e'))));
    }
  }
}
