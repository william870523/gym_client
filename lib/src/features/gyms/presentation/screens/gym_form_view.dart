import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/gym.dart';
import '../gyms_provider.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';

class GymFormView extends ConsumerStatefulWidget {
  final Gym? gym;
  const GymFormView({super.key, this.gym});

  @override
  ConsumerState<GymFormView> createState() => _GymFormViewState();
}

class _GymFormViewState extends ConsumerState<GymFormView> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();

  String _country = '';
  String _timezone = appClock.gymTimezone;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    if (widget.gym != null) {
      _loadGym(widget.gym!);
    }
  }

  void _loadGym(Gym gym) {
    _codeController.text = gym.code;
    _nameController.text = gym.name;
    _addressController.text = gym.address ?? '';
    _cityController.text = gym.city ?? '';
    _stateController.text = gym.state ?? '';
    _zipController.text = gym.zipCode ?? '';
    _country = gym.country ?? '';
    _timezone = gym.timezone ?? appClock.gymTimezone;
    _active = gym.active;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final gym = Gym(
      id: widget.gym?.id ?? '',
      code: _codeController.text,
      name: _nameController.text,
      address: _addressController.text,
      city: _cityController.text,
      state: _stateController.text,
      country: _country,
      timezone: _timezone,
      zipCode: _zipController.text,
      active: _active,
    );

    if (widget.gym == null) {
      await ref.read(gymsControllerProvider.notifier).createGym(gym);
    } else {
      await ref.read(gymsControllerProvider.notifier).updateGym(gym);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.gym != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Watch the controller state
    final state = ref.watch(gymsControllerProvider);

    // Listen for success/error
    ref.listen<AsyncValue<void>>(gymsControllerProvider, (prev, next) {
      if (!next.isLoading && !next.hasError && (prev?.isLoading ?? false)) {
        Navigator.of(context).pop();
      } else if (next.hasError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${next.error}")));
      }
    });

    final isLoading = state.isLoading;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF256AF4).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.fitness_center,
                      color: Color(0xFF256AF4),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? "Actualizar Gimnasio" : "Nuevo Gimnasio",
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          isEditing
                              ? "Edite los detalles del gimnasio"
                              : "Ingrese los datos del nuevo gimnasio",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content (flexible, only scrolls if needed)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        context,
                        Icons.storefront,
                        "Identificación",
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 1,
                            child: _buildTextField(
                              controller: _codeController,
                              label: "Código",
                              hint: "Ej: GYM-001",
                              readOnly: isEditing,
                              helperText: isEditing
                                  ? "El código no se puede modificar."
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              controller: _nameController,
                              label: "Nombre Comercial",
                              hint: "Ej: Diamond Gym Central",
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Divider(),
                      ),

                      _buildSectionHeader(
                        context,
                        Icons.location_on,
                        "Ubicación",
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        controller: _addressController,
                        label: "Dirección",
                        hint: "Calle, número, oficina...",
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        controller: _zipController,
                        label: "Código Postal",
                        hint: "Ej: 28001",
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _cityController,
                              label: "Ciudad",
                              hint: "Ej: Madrid",
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildTextField(
                              controller: _stateController,
                              label: "Provincia/Estado",
                              hint: "Ej: Madrid",
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildDropdown(
                              label: "País",
                              value: _country,
                              items: const [
                                DropdownMenuItem(
                                  value: '',
                                  child: Text("Sin definir"),
                                ),
                                DropdownMenuItem(
                                  value: 'CU',
                                  child: Text("Cuba"),
                                ),
                                DropdownMenuItem(
                                  value: 'ES',
                                  child: Text("España"),
                                ),
                                DropdownMenuItem(
                                  value: 'MX',
                                  child: Text("México"),
                                ),
                                DropdownMenuItem(
                                  value: 'AR',
                                  child: Text("Argentina"),
                                ),
                                DropdownMenuItem(
                                  value: 'CO',
                                  child: Text("Colombia"),
                                ),
                                DropdownMenuItem(
                                  value: 'US',
                                  child: Text("Estados Unidos"),
                                ),
                              ],
                              onChanged: (v) => setState(() => _country = v!),
                            ),
                          ),
                        ],
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Divider(),
                      ),

                      _buildSectionHeader(
                        context,
                        Icons.settings,
                        "Configuración",
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(child: _buildTimezoneField()),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.grey.shade300,
                                ),
                                color: isDark
                                    ? Colors.white10
                                    : Colors.grey.shade50,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "Estado del Gimnasio",
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        _active ? "Activo" : "Inactivo",
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.white60
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Switch(
                                    value: _active,
                                    onChanged: (v) =>
                                        setState(() => _active = v),
                                    activeThumbColor: const Color(0xFF256AF4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer (Actions)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF151D2B)
                    : const Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      side: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      foregroundColor: isDark
                          ? Colors.white
                          : const Color(0xFF0F172A),
                    ),
                    child: const Text("Cancelar"),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: isLoading ? null : _save,
                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      isLoading ? "Guardando..." : "Guardar Gimnasio",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF256AF4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    IconData icon,
    String title,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF256AF4), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool readOnly = false,
    String? helperText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          style: GoogleFonts.inter(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            hintStyle: GoogleFonts.inter(
              color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
            ),
            filled: true,
            fillColor: readOnly
                ? (isDark ? Colors.white10 : Colors.grey.shade50)
                : (isDark ? const Color(0xFF0F172A) : Colors.white),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF256AF4), width: 2),
            ),
          ),
          validator: (value) {
            if (!readOnly && (value == null || value.isEmpty)) {
              return 'Campo requerido';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: GoogleFonts.inter(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 16,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimezoneField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Zona Horaria",
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: _timezone),
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            return availableGymTimezones
                .where(
                  (zone) => query.isEmpty || zone.toLowerCase().contains(query),
                )
                .take(80);
          },
          onSelected: (value) => setState(() => _timezone = value),
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              onChanged: (value) => _timezone = value.trim(),
              validator: (value) {
                final timezone = value?.trim() ?? '';
                if (!isKnownGymTimezone(timezone)) {
                  return 'Seleccione una zona IANA válida';
                }
                return null;
              },
              style: GoogleFonts.inter(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Ej: America/Sao_Paulo',
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
