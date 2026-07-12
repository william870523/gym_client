import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreateClientScreen extends ConsumerStatefulWidget {
  const CreateClientScreen({super.key});

  @override
  ConsumerState<CreateClientScreen> createState() => _CreateClientScreenState();
}

class _CreateClientScreenState extends ConsumerState<CreateClientScreen> {
  String _selectedPlan = 'Mensual';
  bool _isActive = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final backgroundColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF6F6F8);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE7EBF3);
    final primaryColor = const Color(0xFF135BEC);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.diamond, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Diamond Gym',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0D121B),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          // Online Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Online',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Sync Status
          Row(
            children: [
              Icon(Icons.cloud_done, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                'Sincronizado: 10:42 AM',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const VerticalDivider(indent: 12, endIndent: 12),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            backgroundColor: Color(0xFFE0E7FF),
            child: Text(
              'AD',
              style: TextStyle(
                color: Color(0xFF135BEC),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Breadcrumb & Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Text(
                                'Clientes',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                            Text(
                              'Nuevo Registro',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Crear Cliente',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0D121B),
                          ),
                        ),
                        Text(
                          'Complete el formulario para registrar un nuevo miembro en el sistema.',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Cancelar'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            backgroundColor: surfaceColor,
                            foregroundColor: isDark
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.save, size: 18),
                          label: const Text('Guardar Cliente'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Grid Layout
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Col 1 (Left) - Photo & Status
                    SizedBox(
                      width: 320,
                      child: Column(
                        children: [
                          // Photo Upload
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Foto del Cliente',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0D121B),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Stack(
                                  children: [
                                    Container(
                                      width: 180,
                                      height: 180,
                                      decoration: BoxDecoration(
                                        color: backgroundColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: primaryColor.withValues(
                                            alpha: 0.3,
                                          ),
                                          width: 2,
                                          style: BorderStyle.solid,
                                        ), // Simulated dashed
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_a_photo,
                                            size: 48,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Subir foto',
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 4,
                                      right: 16,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.2,
                                              ),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Formatos permitidos: JPG, PNG. Máx 2MB.\nSe recomienda una foto de rostro claro.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Status
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Estado de la Cuenta',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0D121B),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: backgroundColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Estado Activo',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(0xFF0D121B),
                                            ),
                                          ),
                                          Text(
                                            'El cliente puede acceder al gimnasio.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Switch(
                                        value: _isActive,
                                        onChanged: (val) =>
                                            setState(() => _isActive = val),
                                        activeThumbColor: primaryColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    // Col 2 (Right) - Forms
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            // Section Header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: borderColor),
                                ),
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.02)
                                    : Colors.grey.shade50.withValues(
                                        alpha: 0.5,
                                      ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.person, color: primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Información Personal',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0D121B),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Personal Info Fields
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  _buildTwoColumnRow(
                                    _buildTextField(
                                      'Cédula de Identidad (CI)',
                                      'Ej: 1234567',
                                      required: true,
                                    ),
                                    _buildDropdownField('Sexo', [
                                      'Masculino',
                                      'Femenino',
                                      'Otro',
                                    ]),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTwoColumnRow(
                                    _buildTextField(
                                      'Nombres',
                                      'Ej: Juan Andrés',
                                      required: true,
                                    ),
                                    _buildTextField(
                                      'Apellidos',
                                      'Ej: Pérez González',
                                      required: true,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTwoColumnRow(
                                    _buildTextField('Estatura (cm)', '175'),
                                    _buildDropdownField('Nacionalidad', [
                                      'Paraguaya',
                                      'Argentina',
                                      'Brasileña',
                                      'Uruguaya',
                                      'Otra',
                                    ]),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    'Dirección',
                                    'Ej: Av. España 1234 c/ Brasilia',
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTwoColumnRow(
                                    _buildTextField(
                                      'Teléfono',
                                      '981 123 456',
                                      prefix: '+595',
                                    ),
                                    _buildTextField(
                                      'Correo Electrónico',
                                      'cliente@email.com',
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Section Divider
                            Divider(height: 1, color: borderColor),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: borderColor),
                                ),
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.02)
                                    : Colors.grey.shade50.withValues(
                                        alpha: 0.5,
                                      ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.fitness_center,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Membresía y Plan',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0D121B),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Plan Selection Cards
                                  Text.rich(
                                    const TextSpan(
                                      text: 'Plan de Pago ',
                                      children: [
                                        TextSpan(
                                          text: '*',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.grey.shade200
                                          : const Color(0xFF0D121B),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildPlanRadioCard(
                                          'Mensual',
                                          'Acceso completo 30 días',
                                          'Gs. 250.000',
                                          _selectedPlan == 'Mensual',
                                          () => setState(
                                            () => _selectedPlan = 'Mensual',
                                          ),
                                          surfaceColor,
                                          borderColor,
                                          primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildPlanRadioCard(
                                          'Trimestral',
                                          'Desc. 10% aplicado',
                                          'Gs. 675.000',
                                          _selectedPlan == 'Trimestral',
                                          () => setState(
                                            () => _selectedPlan = 'Trimestral',
                                          ),
                                          surfaceColor,
                                          borderColor,
                                          primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildPlanRadioCard(
                                          'Anual',
                                          'Desc. 20% aplicado',
                                          'Gs. 2.400.000',
                                          _selectedPlan == 'Anual',
                                          () => setState(
                                            () => _selectedPlan = 'Anual',
                                          ),
                                          surfaceColor,
                                          borderColor,
                                          primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  _buildDropdownField('Entrenador Asignado', [
                                    'Sin Entrenador Personal',
                                    'Carlos Mendoza',
                                    'Ana Torres',
                                    'Pedro Benítez',
                                  ]),
                                  const SizedBox(height: 16),
                                  _buildTwoColumnRow(
                                    _buildTextField(
                                      'Fecha de Inicio',
                                      '2023-10-27',
                                      isDate: true,
                                    ),
                                    _buildTextField(
                                      'Fecha de Fin',
                                      '2023-11-27',
                                      isDate: true,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    'Objetivo Principal',
                                    'Ej: Ganar masa muscular, Perder peso',
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDropdownField('¿Cómo nos conoció?', [
                                    'Redes Sociales',
                                    'Recomendación de Amigo',
                                    'Publicidad Online',
                                    'Pasaba por el lugar',
                                  ]),
                                ],
                              ),
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
    );
  }

  Widget _buildTwoColumnRow(Widget left, Widget right) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 24),
        Expanded(child: right),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    String placeholder, {
    bool required = false,
    String? prefix,
    bool isDate = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: required
                ? [
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: Colors.red),
                    ),
                  ]
                : [],
          ),
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          readOnly: isDate, // In a real app, use a date picker
          decoration: InputDecoration(
            hintText: placeholder,
            prefixText: prefix != null ? '$prefix ' : null,
            suffixIcon: isDate
                ? const Icon(Icons.calendar_today, size: 16)
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {},
          hint: const Text('Seleccionar'),
        ),
      ],
    );
  }

  Widget _buildPlanRadioCard(
    String title,
    String subtitle,
    String price,
    bool selected,
    VoidCallback onTap,
    Color surfaceColor,
    Color borderColor,
    Color primaryColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? primaryColor : borderColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? primaryColor : Colors.grey.shade400,
                  width: selected ? 4 : 1,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    price,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
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
}
