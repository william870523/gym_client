import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gym_client/src/features/trainers/presentation/providers/trainer_notifier.dart';
import 'package:gym_client/src/features/trainers/presentation/widgets/camera_selector_dialog.dart';
import 'package:gym_client/src/features/schedules/presentation/state/horario_notifier.dart'; // IMPORTED
import 'package:gym_client/src/features/schedules/data/models/horario_model.dart'; // IMPORTED
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/app_flag.dart';
import '../../../../features/configuration/data/models/nacionalidad_model.dart';
import '../../../../features/configuration/presentation/state/nacionalidad_notifier.dart';

import '../../../../features/products/presentation/state/payment_plan_notifier.dart';

import 'package:gym_client/src/features/configuration/presentation/state/referencia_notifier.dart';

import '../../data/models/client_model.dart';
import '../state/client_notifier.dart';
import '../state/weight_history_notifier.dart';
import 'add_weight_modal.dart';

class ClientFormResult {
  const ClientFormResult({required this.client, required this.payNow});

  final ClientModel client;
  final bool payNow;
}

class ClientForm extends ConsumerStatefulWidget {
  final ClientModel? client;

  const ClientForm({super.key, this.client});

  @override
  ConsumerState<ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends ConsumerState<ClientForm> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _surnameController;
  late TextEditingController _ciController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _heightController;
  late TextEditingController _objectiveController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  late TextEditingController _weightController;

  String _sex = 'M';
  // R5.3: categoría del cliente para el descuento. Sin default: obligatorio.
  String? _categoria;
  String? _planId;
  String? _nacionalidadId;
  String? _horarioId; // NEW

  String? _referenciaId;
  String? _entrenadorId;
  String? _photoBase64;
  Uint8List? _fotoBytes;
  DateTime _startDate = todayInZone(appClock.gymTimezone);
  DateTime _endDate = todayInZone(
    appClock.gymTimezone,
  ).add(const Duration(days: 30));
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    final c = widget.client;
    _nameController = TextEditingController(text: c?.nombres ?? '');
    _surnameController = TextEditingController(text: c?.apellidos ?? '');

    _photoBase64 = c?.photoUrl;
    if (_photoBase64 != null) {
      try {
        _fotoBytes = base64Decode(_photoBase64!);
      } catch (_) {}
    }

    _entrenadorId = c?.trainerId;
    _ciController = TextEditingController(text: c?.id ?? '');
    _emailController = TextEditingController(text: c?.correo ?? '');
    _phoneController = TextEditingController(
      text: c?.telefono?.toString() ?? '',
    );
    _addressController = TextEditingController(text: c?.direccion ?? '');
    _heightController = TextEditingController(
      text: c?.estatura_cliente?.toString() ?? '',
    );
    _weightController = TextEditingController(text: c?.peso?.toString() ?? '');
    _objectiveController = TextEditingController(text: c?.objetivo ?? '');

    final rawSex = c?.sexo?.trim() ?? 'M';
    if (rawSex.toUpperCase().startsWith('M') || rawSex == 'Masculino') {
      _sex = 'M';
    } else if (rawSex.toUpperCase().startsWith('F') || rawSex == 'Femenino') {
      _sex = 'F';
    } else {
      _sex = 'O';
    }
    // R5.3: cargar categoría; si el cliente heredado no la tiene, queda null
    // y el dropdown obliga a elegir antes de guardar.
    final rawCat = c?.categoria?.trim().toUpperCase();
    _categoria = (rawCat == 'NUEVO' || rawCat == 'VIEJO') ? rawCat : 'NUEVO';
    _planId = c?.planId;
    _nacionalidadId = c?.nacionalidadId;
    _referenciaId = c?.referralId;
    _entrenadorId = c?.trainerId;
    _horarioId = c?.scheduleId;
    _isActive = c?.activo ?? true;
    _startDate = c?.startDate ?? todayInZone(appClock.gymTimezone);
    _endDate = c?.endDate ?? _startDate.add(const Duration(days: 30));
    _startDateController = TextEditingController(text: _formatDate(_startDate));
    _endDateController = TextEditingController(text: _formatDate(_endDate));

    // Attempt to parse horarioId if present (Note: ClientModel might not support it yet, but UI should)
    // If ClientModel doesn't have horarioId, we just leave it null.
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _ciController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _heightController.dispose();
    _objectiveController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  // Helper used by initState
  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  List<dynamic> _activeOrSelectedOptions(
    Iterable<dynamic> items,
    String? selectedId,
  ) {
    return items.where((item) {
      final itemId = item.id?.toString();
      if (selectedId != null && itemId == selectedId) return true;
      return item.activo == true && item.isDeleted != true;
    }).toList();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      Uint8List? fileBytes;

      if (file.bytes != null) {
        fileBytes = file.bytes;
      } else if (file.path != null) {
        fileBytes = await File(file.path!).readAsBytes();
      }

      if (fileBytes != null) {
        setState(() {
          _fotoBytes = fileBytes;
          _photoBase64 = base64Encode(fileBytes!);
        });
      }
    }
  }

  Future<void> _takePhoto() async {
    final bytes = await showDialog<Uint8List>(
      context: context,
      builder: (context) => const CameraSelectorDialog(),
    );

    if (bytes != null) {
      setState(() {
        _fotoBytes = bytes;
        _photoBase64 = base64Encode(bytes);
      });
    }
  }

  void _clearPhoto() {
    setState(() {
      _photoBase64 = null;
      _fotoBytes = null;
    });
  }

  Future<void> _selectDate({required bool isStart}) async {
    final initialDate = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        // Calculate the duration of the current plan (or current selection)
        final difference = _endDate.difference(_startDate).inDays;

        _startDate = picked;
        _startDateController.text = _formatDate(picked);

        // Smart Date Logic: Shift End Date to maintain duration
        _endDate = picked.add(Duration(days: difference > 0 ? difference : 30));
        _endDateController.text = _formatDate(_endDate);
      } else {
        _endDate = picked;
        _endDateController.text = _formatDate(picked);
      }
    });
  }

  Future<void> _submit({bool payNow = false}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final address = _addressController.text.trim();
      final objective = _objectiveController.text.trim();

      final heightText = _heightController.text.trim();
      final weightText = _weightController.text.trim();

      if (_nacionalidadId == null || _nacionalidadId!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Seleccione una nacionalidad.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final plans = ref.read(paymentPlanProvider).value ?? const [];
      final selectedPlan = plans.where((p) => p.id == _planId).firstOrNull;

      if (selectedPlan != null &&
          selectedPlan.incluyeEntrenador &&
          (_entrenadorId == null || _entrenadorId!.isEmpty)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'El plan seleccionado incluye entrenador. Debe asignar un entrenador personal al cliente.',
              ),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // R5.3: la categoría de cliente es obligatoria (define el descuento).
      if (_categoria == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Seleccione la categoría del cliente (NUEVO o VIEJO).',
              ),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final client = ClientModel(
        id: _ciController.text.trim(),
        nombres: _nameController.text.trim(),
        apellidos: _surnameController.text.trim(),
        sexo: _sex == 'M' ? 'Masculino' : (_sex == 'F' ? 'Femenino' : 'Otro'),
        correo: email.isEmpty ? null : email,
        telefono: int.tryParse(_phoneController.text.trim()),
        planId: (_planId == null || _planId!.isEmpty) ? null : _planId,
        direccion: address.isEmpty ? null : address,
        estatura_cliente: heightText.isEmpty
            ? null
            : double.tryParse(heightText.replaceAll(',', '.')),
        peso: weightText.isEmpty
            ? null
            : double.tryParse(weightText.replaceAll(',', '.')),
        objetivo: objective.isEmpty ? null : objective,
        activo: _isActive,
        nacionalidadId: _nacionalidadId,
        photoUrl: _fotoBytes != null ? base64Encode(_fotoBytes!) : null,
        startDate: calendarDateToUtc(_startDate),
        endDate: calendarDateToUtc(_endDate),
        referralId: _referenciaId,
        trainerId: _entrenadorId,
        scheduleId: _horarioId,
        categoria: _categoria,
      );

      final saved = widget.client == null
          ? await ref.read(clientNotifierProvider.notifier).createClient(client)
          : await ref
                .read(clientNotifierProvider.notifier)
                .updateClient(client);

      if (mounted) {
        Navigator.of(context).pop(
          ClientFormResult(
            client: saved,
            payNow: widget.client == null && payNow,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(paymentPlanProvider);
    final nacionalidadesAsync = ref.watch(nacionalidadProvider);
    final referenciasAsync = ref.watch(referenciaNotifierProvider);
    final trainersAsync = ref.watch(trainerProvider);
    final horariosAsync = ref.watch(horarioNotifierProvider); // WATCH HORARIOS

    final planOptions = _activeOrSelectedOptions(
      plansAsync.value ?? const [],
      _planId,
    );

    final nacionalidadOptions = nacionalidadesAsync.maybeWhen(
      data: (items) => items,
      orElse: () => const <NacionalidadModel>[],
    );
    final trainerOptions = _activeOrSelectedOptions(
      trainersAsync.value ?? const [],
      _entrenadorId,
    );
    final referenciaOptions = referenciasAsync.value ?? [];
    final horarioOptions = horariosAsync.value ?? [];

    final palette = _ClientFormPalette.of(context);
    final isDark = palette.isDark;
    final surfaceColor = palette.surface;
    final backgroundColor = palette.background;
    final borderColor = palette.border;
    final textMain = palette.textPrimary;
    final textMuted = palette.textSecondary;
    final primaryColor = palette.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              key: const ValueKey('pulso-client-form-shell'),
              width: 1100,
              constraints: BoxConstraints(
                // Compact height: Max 80% or 800px
                maxHeight: constraints.maxHeight > 0
                    ? constraints.maxHeight * 0.85
                    : 800,
              ),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadow,
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      border: Border(bottom: BorderSide(color: borderColor)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.person_add, color: primaryColor),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.client == null
                                  ? 'Crear Cliente'
                                  : 'Editar Cliente',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textMain,
                              ),
                            ),
                            Text(
                              'Complete el formulario para registrar un nuevo miembro.',
                              style: TextStyle(fontSize: 13, color: textMuted),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close, color: textMuted),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Main Layout Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // LEFT COLUMN: Photo & Status
                                SizedBox(
                                  key: const ValueKey(
                                    'pulso-client-form-sidebar',
                                  ),
                                  width: 300,
                                  child: Column(
                                    children: [
                                      _buildPhotoSection(
                                        surfaceColor,
                                        borderColor,
                                        textMain,
                                        textMuted,
                                        primaryColor,
                                      ),
                                      const SizedBox(height: 24),
                                      _buildStatusSection(
                                        surfaceColor,
                                        borderColor,
                                        textMain,
                                        textMuted,
                                        primaryColor,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(
                                  key: ValueKey('pulso-client-form-main-gap'),
                                  width: 32,
                                ),
                                // RIGHT COLUMN: Form Fields
                                Expanded(
                                  child: Column(
                                    children: [
                                      // Personal Info
                                      _buildSectionHeader(
                                        'Información Personal',
                                        Icons.person,
                                        primaryColor,
                                        textMain,
                                        surfaceColor,
                                        borderColor,
                                      ),
                                      const SizedBox(height: 16),
                                      LayoutGrid(
                                        columnGap: 16,
                                        rowGap: 16,
                                        children: [
                                          _buildTextField(
                                            label: 'Cédula de Identidad (CI)',
                                            controller: _ciController,
                                            isRequired: true,
                                            placeholder: 'Ej: 1234567',
                                          ),
                                          _buildDropdown(
                                            label: 'Sexo',
                                            value: _sex,
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'M',
                                                child: Text('Masculino'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'F',
                                                child: Text('Femenino'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'O',
                                                child: Text('Otro'),
                                              ),
                                            ],
                                            onChanged: (v) => setState(
                                              () => _sex = v as String,
                                            ),
                                            placeholder: 'Seleccionar',
                                          ),
                                          _buildTextField(
                                            label: 'Nombres',
                                            controller: _nameController,
                                            isRequired: true,
                                            placeholder: 'Ej: Juan Andrés',
                                          ),
                                          _buildTextField(
                                            label: 'Apellidos',
                                            controller: _surnameController,
                                            isRequired: true,
                                            placeholder: 'Ej: Pérez González',
                                          ),
                                          _buildTextField(
                                            label: 'Estatura',
                                            controller: _heightController,
                                            suffix: 'cm',
                                            placeholder: '175',
                                            isNumber: true,
                                          ),
                                          _buildTextField(
                                            label: 'Peso',
                                            controller: _weightController,
                                            suffix: 'kg',
                                            placeholder: '70.5',
                                            isNumber: true,
                                          ),
                                          _buildDropdown(
                                            label: 'Categoría *',
                                            value: _categoria,
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'NUEVO',
                                                child: Text('Nuevo (precio normal)'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'VIEJO',
                                                child: Text(
                                                  'Viejo (con descuento)',
                                                ),
                                              ),
                                            ],
                                            onChanged: (v) => setState(
                                              () => _categoria = v as String?,
                                            ),
                                            placeholder: 'Seleccionar',
                                          ),
                                          _buildSearchableNationality(
                                            nacionalidadOptions,
                                          ),
                                          _buildTextField(
                                            label: 'Teléfono',
                                            controller: _phoneController,
                                            prefix: '+595',
                                            placeholder: '981 123 456',
                                            isPhone: true,
                                          ),
                                          _buildTextField(
                                            label: 'Correo Electrónico',
                                            controller: _emailController,
                                            placeholder: 'cliente@email.com',
                                          ),
                                          // REPLACED WITH SEARCHABLE
                                          _buildSearchableReferencia(
                                            referenciaOptions,
                                          ),

                                          _buildTextField(
                                            label: 'Dirección',
                                            controller: _addressController,
                                            placeholder: 'Ej: Av. España 1234',
                                            fullWidth: true,
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 32),

                                      // Membership & Plan
                                      _buildSectionHeader(
                                        'Membresía y Plan',
                                        Icons.fitness_center,
                                        primaryColor,
                                        textMain,
                                        surfaceColor,
                                        borderColor,
                                      ),
                                      const SizedBox(height: 16),
                                      LayoutGrid(
                                        columnGap: 16,
                                        rowGap: 16,
                                        children: [
                                          _buildPlanDropdown(planOptions),
                                          // NEW HORARIO DROPDOWN
                                          _buildHorarioDropdown(horarioOptions),
                                          _buildTrainerDropdown(trainerOptions),
                                          _buildTextField(
                                            label: 'Objetivo Principal',
                                            controller: _objectiveController,
                                            placeholder:
                                                'Ej: Ganar masa muscular',
                                          ),
                                          _buildDatePicker(
                                            label: 'Fecha de Inicio',
                                            controller: _startDateController,
                                            onTap: () =>
                                                _selectDate(isStart: true),
                                          ),
                                          _buildDatePicker(
                                            label: 'Fecha de Fin',
                                            controller: _endDateController,
                                            onTap: () =>
                                                _selectDate(isStart: false),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (widget.client != null) ...[
                              const SizedBox(height: 32),
                              _buildWeightHistorySection(
                                isDark,
                                textMain,
                                textMuted,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ), // Reduced vertical padding
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                      border: Border(top: BorderSide(color: borderColor)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            side: BorderSide(color: borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            foregroundColor: textMain,
                          ),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () => _submit(payNow: false),
                          icon: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: palette.accentInk,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            _isLoading
                                ? 'Guardando...'
                                : widget.client == null
                                ? 'Guardar'
                                : 'Guardar cambios',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: palette.accentInk,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                        ),
                        if (widget.client == null && _planId != null) ...[
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () => _submit(payNow: true),
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Guardar y cobrar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: palette.accentInk,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ... [Photo Section and Status Section remain unchanged] ...
  Widget _buildPhotoSection(
    Color surface,
    Color border,
    Color text,
    Color muted,
    Color primary,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Foto del Cliente',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: text,
              ),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickImage,
            borderRadius: BorderRadius.circular(100),
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _ClientFormPalette.of(context).surfaceAlt,
                border: Border.all(
                  color: _fotoBytes != null ? primary : border,
                  width: _fotoBytes != null ? 2 : 1,
                  style: _fotoBytes != null
                      ? BorderStyle.solid
                      : BorderStyle.none,
                ),
                image: _fotoBytes != null
                    ? DecorationImage(
                        image: MemoryImage(_fotoBytes!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _fotoBytes == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add, size: 48, color: muted),
                        const SizedBox(height: 8),
                        Text(
                          'Sin imagen',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Subir'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: border),
                    foregroundColor: text,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.photo_camera, size: 18),
                  label: const Text('Cámara'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: border),
                    foregroundColor: text,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_fotoBytes != null)
            TextButton.icon(
              onPressed: _clearPhoto,
              icon: Icon(
                Icons.delete,
                size: 16,
                color: PulsoTokens.of(context).danger,
              ),
              label: Text(
                'Eliminar foto',
                style: TextStyle(
                  color: PulsoTokens.of(context).danger,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Formatos: JPG, PNG. Máx 2MB.\nUtilice la cámara web para captura instantánea.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: muted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(
    Color surface,
    Color border,
    Color text,
    Color muted,
    Color primary,
  ) {
    final palette = _ClientFormPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estado de la Cuenta',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: text,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
            title: Text(
              _isActive ? 'Activo' : 'Inactivo',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _isActive ? palette.success : palette.danger,
              ),
            ),
            subtitle: Text(
              'Permitir acceso al gimnasio',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            activeTrackColor: palette.success,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ],
      ),
    );
  }

  Widget _buildWeightHistorySection(
    bool isDark,
    Color textColor,
    Color secondaryTextColor,
  ) {
    final palette = _ClientFormPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.border)),
              color: palette.surfaceAlt,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: palette.accentSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.monitor_weight,
                        size: 20,
                        color: palette.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Historial de Peso",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (c) => AddWeightModal(client: widget.client!),
                    ).then(
                      (_) =>
                          ref.refresh(weightHistoryProvider(widget.client!.ci)),
                    );
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    "Nuevo Peso",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.accentInk,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildWeightTable(isDark, textColor, secondaryTextColor),
        ],
      ),
    );
  }

  Widget _buildWeightTable(
    bool isDark,
    Color textColor,
    Color secondaryTextColor,
  ) {
    final palette = _ClientFormPalette.of(context);
    return Consumer(
      builder: (context, ref, child) {
        final historyAsync = ref.watch(
          weightHistoryProvider(widget.client!.ci),
        );

        return historyAsync.when(
          data: (history) {
            if (history.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    "No hay registros de peso.",
                    style: TextStyle(color: secondaryTextColor),
                  ),
                ),
              );
            }
            return SizedBox(
              width: double.infinity,
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(1),
                  2: FixedColumnWidth(120),
                },
                border: TableBorder(
                  horizontalInside: BorderSide(color: palette.border, width: 1),
                ),
                children: [
                  // Header
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: palette.border)),
                    ),
                    children: [
                      _TableHeaderCell("Fecha", isDark),
                      _TableHeaderCell("Peso (kg)", isDark),
                      _TableHeaderCell(
                        "Acciones",
                        isDark,
                        align: TextAlign.right,
                      ),
                    ],
                  ),
                  // Body
                  ...history.map((entry) {
                    final date =
                        DateTime.tryParse(entry['fecha'].toString()) ??
                        DateTime.now();
                    final weight = entry['peso'] ?? 0;
                    return TableRow(
                      children: [
                        _TableCell(
                          DateFormat('dd MMM, yyyy').format(date),
                          isDark,
                          textColor,
                          fontWeight: FontWeight.w500,
                        ),
                        _TableCell(
                          "$weight kg",
                          isDark,
                          textColor,
                          fontWeight: FontWeight.bold,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.edit, size: 18),
                                color: secondaryTextColor,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.delete, size: 18),
                                color: palette.danger,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                "Error: $err",
                style: TextStyle(color: palette.danger),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color primary,
    Color text,
    Color bg,
    Color border,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _ClientFormPalette.of(context).surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: primary, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  // ... [TextField and Dropdown remain generic] ...
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool isRequired = false,
    String? placeholder,
    String? prefix,
    String? suffix,
    bool isNumber = false,
    bool isPhone = false,
    bool fullWidth = false,
  }) {
    final palette = _ClientFormPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: palette.textSecondary,
            ),
            children: [
              if (isRequired)
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: palette.danger),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : isPhone
              ? TextInputType.phone
              : TextInputType.text,
          inputFormatters: isNumber
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))]
              : isPhone
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          validator: isRequired
              ? (v) => v?.trim().isEmpty == true ? 'Requerido' : null
              : null,
          style: TextStyle(fontSize: 14, color: palette.textPrimary),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(fontSize: 13, color: palette.textSecondary),
            filled: true,
            fillColor: palette.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: palette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: palette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: palette.primary),
            ),
            prefixIcon: prefix != null
                ? Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    width: 60,
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: palette.border)),
                    ),
                    child: Text(
                      prefix,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  )
                : null,
            suffixIcon: suffix != null
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      suffix,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required dynamic value,
    required List<DropdownMenuItem<Object>> items,
    required Function(Object?) onChanged,
    String? placeholder,
  }) {
    final palette = _ClientFormPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          icon: Icon(Icons.arrow_drop_down, color: palette.textSecondary),
          style: TextStyle(color: palette.textPrimary),
          decoration: InputDecoration(
            hintText: placeholder,
            filled: true,
            fillColor: palette.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: palette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: palette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: palette.primary),
            ),
          ),
          dropdownColor: palette.surface,
        ),
      ],
    );
  }

  // UPDATED: Nationality with Flag in Input
  Widget _buildSearchableNationality(List<NacionalidadModel> options) {
    final palette = _ClientFormPalette.of(context);
    final currentValue = options
        .where((n) => n.id == _nacionalidadId)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nacionalidad',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Autocomplete<NacionalidadModel>(
          key: ValueKey(
            'nat-${options.isEmpty ? 'empty' : options.length}',
          ), // Force rebuild when data loads
          initialValue: TextEditingValue(text: currentValue?.name ?? ''),
          displayStringForOption: (option) => option.name,
          optionsBuilder: (textEditingValue) {
            final query = textEditingValue.text.trim().toLowerCase();
            if (query.isEmpty) return options;
            if (currentValue != null && currentValue.name.toLowerCase() == query) {
              return options;
            }
            final matches = options.where(
              (o) => o.name.toLowerCase().contains(query),
            ).toList();
            if (matches.isEmpty) return options;
            final nonMatches = options.where(
              (o) => !o.name.toLowerCase().contains(query),
            );
            return [...matches, ...nonMatches];
          },
          onSelected: (option) {
            setState(() {
              _nacionalidadId = option.id;
              // Force rebuild to show flag in prefix
            });
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            // Logic to show flag
            Widget? prefixIcon;
            final selected = options
                .where((n) => n.id == _nacionalidadId)
                .firstOrNull;

            // If the text matches the selected ID's name, show flag
            if (selected != null && controller.text == selected.name) {
              if (selected.flagImage != null) {
                prefixIcon = Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: AppFlag(
                    base64String: selected.flagImage!,
                    countryCode: selected.isoCode,
                    width: 24,
                    height: 16,
                    borderRadius: 3,
                    showFrame: false,
                  ),
                );
              } else {
                prefixIcon = Icon(
                  Icons.flag,
                  size: 18,
                  color: palette.textSecondary,
                );
              }
            } else {
              prefixIcon = Icon(
                Icons.search,
                size: 18,
                color: palette.textSecondary,
              );
            }

            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              onFieldSubmitted: (v) => onFieldSubmitted(),
              decoration: InputDecoration(
                hintText: 'Buscar nacionalidad...',
                filled: true,
                fillColor: palette.surfaceAlt,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.primary),
                ),
                prefixIcon: prefixIcon,
                suffixIcon: Icon(
                  Icons.arrow_drop_down,
                  color: palette.textSecondary,
                ),
              ),
              style: TextStyle(color: palette.textPrimary),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                color: palette.surface,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 400,
                    maxWidth: 300,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        leading: option.flagImage != null
                            ? AppFlag(
                                base64String: option.flagImage!,
                                countryCode: option.isoCode,
                                width: 24,
                                height: 16,
                                borderRadius: 3,
                              )
                            : Icon(Icons.flag, color: palette.textSecondary),
                        title: Text(
                          option.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: palette.textPrimary,
                          ),
                        ),
                        tileColor: palette.surface,
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // NEW: Searchable Referencias
  Widget _buildSearchableReferencia(List<dynamic> options) {
    final palette = _ClientFormPalette.of(context);

    // ReferenciaModel is usually dynamic in this generic list from Provider, adjust casting
    final currentValue = options
        .where((r) => r.id == _referenciaId)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿Cómo nos conoció?',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Autocomplete<Object>(
          key: ValueKey('ref-${options.isEmpty ? 'empty' : options.length}'),
          initialValue: TextEditingValue(
            text: currentValue != null ? (currentValue as dynamic).nombre : '',
          ),
          displayStringForOption: (option) => (option as dynamic).nombre,
          optionsBuilder: (textEditingValue) {
            final query = textEditingValue.text.trim().toLowerCase();
            if (query.isEmpty) return options.cast<Object>();
            if (currentValue != null &&
                (currentValue as dynamic).nombre.toString().toLowerCase() == query) {
              return options.cast<Object>();
            }
            final matches = options.where(
              (r) => (r as dynamic).nombre.toString().toLowerCase().contains(query),
            ).toList();
            if (matches.isEmpty) return options.cast<Object>();
            final nonMatches = options.where(
              (r) => !(r as dynamic).nombre.toString().toLowerCase().contains(query),
            );
            return [...matches, ...nonMatches].cast<Object>();
          },
          onSelected: (option) {
            setState(() {
              _referenciaId = (option as dynamic).id;
            });
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Seleccionar referencia...',
                filled: true,
                fillColor: palette.surfaceAlt,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.primary),
                ),
                suffixIcon: Icon(
                  Icons.arrow_drop_down,
                  color: palette.textSecondary,
                ),
              ),
              style: TextStyle(color: palette.textPrimary),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                color: palette.surface,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 200,
                    maxWidth: 300,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final option = options.elementAt(index) as dynamic;
                      return ListTile(
                        title: Text(
                          option.nombre,
                          style: TextStyle(
                            fontSize: 14,
                            color: palette.textPrimary,
                          ),
                        ),
                        tileColor: palette.surface,
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlanDropdown(List<dynamic> plans) {
    final palette = _ClientFormPalette.of(context);

    // Find selected plan for initial value
    final selectedPlan = _planId != null
        ? plans.where((p) => p.id == _planId).firstOrNull
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: 'Plan de Pago',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: palette.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Autocomplete<Object>(
          key: ValueKey('plan-${plans.isEmpty ? 'empty' : plans.length}'),
          initialValue: TextEditingValue(
            text: selectedPlan != null
                ? (selectedPlan as dynamic).nombre.toString()
                : '',
          ),
          displayStringForOption: (option) =>
              (option as dynamic).nombre.toString(),
          optionsBuilder: (textEditingValue) {
            final query = textEditingValue.text.trim().toLowerCase();
            if (query.isEmpty) return plans.cast<Object>();
            if (selectedPlan != null &&
                (selectedPlan as dynamic).nombre.toString().toLowerCase() == query) {
              return plans.cast<Object>();
            }
            final matches = plans.where(
              (p) => (p as dynamic).nombre.toString().toLowerCase().contains(query),
            ).toList();
            if (matches.isEmpty) return plans.cast<Object>();
            final nonMatches = plans.where(
              (p) => !(p as dynamic).nombre.toString().toLowerCase().contains(query),
            );
            return [...matches, ...nonMatches].cast<Object>();
          },
          onSelected: (option) {
            final dynOption = option as dynamic;
            final durationDays = (dynOption.duracion as num?)?.toInt() ?? 0;
            final baseToday = todayInZone(appClock.gymTimezone);
            setState(() {
              _planId = dynOption.id as String?;
              if (durationDays > 0) {
                _endDate = baseToday.add(Duration(days: durationDays));
                _endDateController.text = _formatDate(_endDate);
              }
            });
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Seleccione un plan',
                filled: true,
                fillColor: palette.surfaceAlt,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.primary),
                ),
                suffixIcon: Icon(
                  Icons.arrow_drop_down,
                  color: palette.textSecondary,
                ),
              ),
              style: TextStyle(color: palette.textPrimary),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                color: palette.surface,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 200,
                    maxWidth: 300,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index) as dynamic;
                      return ListTile(
                        title: Text(
                          '${option.nombre}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Gs. ${option.importe}',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textSecondary,
                          ),
                        ),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // NEW: Horario Dropdown
  Widget _buildHorarioDropdown(List<HorarioModel> horarios) {
    final palette = _ClientFormPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Horario Preferido',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          isExpanded: true,
          initialValue: _horarioId,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'Horario Libre / Sin preferencia',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ...horarios.map(
              (h) => DropdownMenuItem(
                value: h.id,
                child: Text(h.nombre, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _horarioId = v),
          icon: Icon(Icons.arrow_drop_down, color: palette.textSecondary),
          decoration: InputDecoration(
            hintText: 'Seleccionar horario',
            filled: true,
            fillColor: palette.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: palette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: palette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: palette.primary),
            ),
          ),
          dropdownColor: palette.surface,
          style: TextStyle(color: palette.textPrimary),
        ),
      ],
    );
  }

  Widget _buildTrainerDropdown(List<dynamic> trainers) {
    final palette = _ClientFormPalette.of(context);
    final plans = ref.watch(paymentPlanProvider).value ?? const [];
    final selectedPlan = plans.where((p) => p.id == _planId).firstOrNull;
    final requiresTrainer = selectedPlan?.incluyeEntrenador == true;

    final selectedTrainer = _entrenadorId != null
        ? trainers.where((t) => t.id == _entrenadorId).firstOrNull
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: 'Entrenador Asignado',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: palette.textSecondary,
            ),
            children: [
              if (requiresTrainer)
                TextSpan(
                  text: ' * (Requerido)',
                  style: TextStyle(
                    color: palette.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Autocomplete<Object>(
          key: ValueKey(
            'trainer-${trainers.isEmpty ? 'empty' : trainers.length}',
          ),
          initialValue: TextEditingValue(
            text: selectedTrainer != null
                ? '${(selectedTrainer as dynamic).nombres} ${(selectedTrainer as dynamic).apellidos}'
                : '',
          ),
          displayStringForOption: (option) {
            final t = option as dynamic;
            return '${t.nombres} ${t.apellidos}';
          },
          optionsBuilder: (textEditingValue) {
            final query = textEditingValue.text.trim().toLowerCase();
            if (query.isEmpty) return trainers.cast<Object>();
            if (selectedTrainer != null &&
                '${(selectedTrainer as dynamic).nombres} ${(selectedTrainer as dynamic).apellidos}'.toLowerCase() == query) {
              return trainers.cast<Object>();
            }
            final matches = trainers.where(
              (t) => '${t.nombres} ${t.apellidos}'.toLowerCase().contains(query),
            ).toList();
            if (matches.isEmpty) return trainers.cast<Object>();
            final nonMatches = trainers.where(
              (t) => !'${t.nombres} ${t.apellidos}'.toLowerCase().contains(query),
            );
            return [...matches, ...nonMatches].cast<Object>();
          },
          onSelected: (option) {
            final t = option as dynamic;
            setState(() => _entrenadorId = t.id);
          },
          fieldViewBuilder: (context, controller, focusNode, onFn) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              validator: (val) {
                if (requiresTrainer && (_entrenadorId == null || _entrenadorId!.isEmpty)) {
                  return 'Debe seleccionar un entrenador personal.';
                }
                return null;
              },
              decoration: InputDecoration(
                hintText: requiresTrainer ? 'Seleccionar Entrenador...' : 'Sin Entrenador Personal',
                filled: true,
                fillColor: palette.surfaceAlt,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.primary),
                ),
                suffixIcon: Icon(
                  Icons.arrow_drop_down,
                  color: palette.textSecondary,
                ),
              ),
              style: TextStyle(color: palette.textPrimary),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                color: palette.surface,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 200,
                    maxWidth: 300,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index) as dynamic;
                      return ListTile(
                        title: Text(
                          '${option.nombres} ${option.apellidos}',
                          style: TextStyle(
                            fontSize: 14,
                            color: palette.textPrimary,
                          ),
                        ),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDatePicker({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
  }) {
    final palette = _ClientFormPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          style: TextStyle(fontSize: 14, color: palette.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: palette.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: palette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: palette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: palette.primary),
            ),
            suffixIcon: Icon(
              Icons.calendar_today,
              size: 18,
              color: palette.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class LayoutGrid extends StatelessWidget {
  final List<Widget> children;
  final double columnGap;
  final double rowGap;

  const LayoutGrid({
    super.key,
    required this.children,
    this.columnGap = 16,
    this.rowGap = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    List<Widget> rows = [];
    for (int i = 0; i < children.length; i += 2) {
      final left = children[i];
      final right = (i + 1 < children.length) ? children[i + 1] : null;

      if (right == null) {
        rows.add(Row(children: [Expanded(child: left)]));
      } else {
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              SizedBox(width: columnGap),
              Expanded(child: right),
            ],
          ),
        );
      }
    }

    return Column(
      children: rows.expand((r) => [r, SizedBox(height: rowGap)]).toList()
        ..removeLast(),
    );
  }
}

class _ClientFormPalette {
  const _ClientFormPalette({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary,
    required this.accentInk,
    required this.accentSoft,
    required this.success,
    required this.danger,
    required this.shadow,
  });

  factory _ClientFormPalette.of(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return _ClientFormPalette(
      isDark: tokens.isDark,
      background: tokens.floor,
      surface: tokens.surface,
      surfaceAlt: tokens.raised,
      border: tokens.line,
      textPrimary: tokens.chalk,
      textSecondary: tokens.muted,
      primary: tokens.accent,
      accentInk: tokens.accentInk,
      accentSoft: tokens.accentSoft,
      success: tokens.success,
      danger: tokens.danger,
      shadow: tokens.isDark
          ? Colors.black.withValues(alpha: 0.32)
          : tokens.chalk.withValues(alpha: 0.10),
    );
  }

  final bool isDark;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color primary;
  final Color accentInk;
  final Color accentSoft;
  final Color success;
  final Color danger;
  final Color shadow;
}

class _TableHeaderCell extends StatelessWidget {
  final String text;
  final bool isDark;
  final TextAlign align;

  const _TableHeaderCell(this.text, this.isDark, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    final palette = _ClientFormPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: palette.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool isDark;
  final Color textColor;
  final FontWeight fontWeight;

  const _TableCell(
    this.text,
    this.isDark,
    this.textColor, {
    this.fontWeight = FontWeight.normal,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
