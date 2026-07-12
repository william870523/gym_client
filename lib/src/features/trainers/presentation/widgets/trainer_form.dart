import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../data/models/trainer_model.dart';
import '../providers/trainer_notifier.dart';
import 'camera_selector_dialog.dart';

class TrainerForm extends ConsumerStatefulWidget {
  final TrainerModel? trainer;
  final VoidCallback onCancel;
  final VoidCallback onSuccess;

  const TrainerForm({
    super.key,
    this.trainer,
    required this.onCancel,
    required this.onSuccess,
  });

  @override
  ConsumerState<TrainerForm> createState() => _TrainerFormState();
}

class _TrainerFormState extends ConsumerState<TrainerForm> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _ciController;
  late TextEditingController _nombresController;
  late TextEditingController _apellidosController;
  late TextEditingController _direccionController;
  late TextEditingController _telefonoController;
  late TextEditingController _correoController;
  late TextEditingController _fechaInicioController;

  String _sexo = 'M';
  bool _activo = true;
  Uint8List? _fotoBytes;
  DateTime _fechaInicio = todayInZone(appClock.gymTimezone);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _ciController = TextEditingController(text: widget.trainer?.ci ?? '');
    _nombresController = TextEditingController(
      text: widget.trainer?.nombres ?? '',
    );
    _apellidosController = TextEditingController(
      text: widget.trainer?.apellidos ?? '',
    );
    _direccionController = TextEditingController(
      text: widget.trainer?.direccion ?? '',
    );
    _telefonoController = TextEditingController(
      text: widget.trainer?.telefono?.toString() ?? '',
    );
    _correoController = TextEditingController(
      text: widget.trainer?.correo ?? '',
    );

    if (widget.trainer != null) {
      final rawSexo = widget.trainer!.sexo?.trim() ?? 'M';
      if (rawSexo.toUpperCase().startsWith('M') || rawSexo == 'Masculino') {
        _sexo = 'M';
      } else if (rawSexo.toUpperCase().startsWith('F') ||
          rawSexo == 'Femenino') {
        _sexo = 'F';
      } else {
        _sexo = 'M';
      }
      _activo = widget.trainer!.activo;
      _fechaInicio = widget.trainer!.fechaInicio;
      if (widget.trainer!.foto != null) {
        _fotoBytes = base64Decode(widget.trainer!.foto!);
      }
    }

    _fechaInicioController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(_fechaInicio),
    );
  }

  @override
  void dispose() {
    _ciController.dispose();
    _nombresController.dispose();
    _apellidosController.dispose();
    _direccionController.dispose();
    _telefonoController.dispose();
    _correoController.dispose();
    _fechaInicioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.first.bytes != null) {
      if (!mounted) return;
      setState(() {
        _fotoBytes = result.files.first.bytes;
      });
    }
  }

  Future<void> _takePhoto() async {
    final bytes = await showDialog<Uint8List>(
      context: context,
      builder: (context) => const CameraSelectorDialog(),
    );

    if (bytes != null) {
      if (!mounted) return;
      setState(() {
        _fotoBytes = bytes;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaInicio,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        _fechaInicio = picked;
        _fechaInicioController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final ci = _ciController.text.trim();
    final nombres = _nombresController.text.trim();
    final apellidos = _apellidosController.text.trim();
    final direccion = _direccionController.text.trim();
    final correo = _correoController.text.trim();

    final payload = {
      'ci_entrenador': ci,
      'nombres_entrenador': nombres,
      'apellidos_entrenador': apellidos,
      'sexo_entrenador': _sexo == 'M' ? 'Masculino' : 'Femenino',
      'direccion_entrenador': direccion.isNotEmpty ? direccion : null,
      'telefono_entrenador': int.tryParse(_telefonoController.text.trim()),
      'correo_entrenador': correo.isNotEmpty ? correo : null,
      'activo_entrenador': _activo,
      'fecha_incio_entrenador': calendarDateToUtc(
        _fechaInicio,
      ).toIso8601String(),
      if (_fotoBytes != null) 'foto_entrenador': base64Encode(_fotoBytes!),
      if (_fotoBytes == null && widget.trainer != null) 'foto_entrenador': null,
    };

    try {
      if (widget.trainer == null) {
        await ref.read(trainerProvider.notifier).createTrainer(payload);
      } else {
        await ref
            .read(trainerProvider.notifier)
            .updateTrainer(widget.trainer!.id, payload);
      }
      if (!mounted) return;
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _delete() async {
    if (widget.trainer == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Entrenador'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este entrenador?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(trainerProvider.notifier)
          .deleteTrainer(widget.trainer!.id);
      if (!mounted) return;
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Bar
        _buildTopBar(),

        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPhotoSection(),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),
                  _buildPersonalSection(),
                  const SizedBox(height: 32),
                  _buildContactSection(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE7EBF3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.trainer == null ? 'Nuevo Entrenador' : 'Editar Perfil',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Información personal y de contacto',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF4C669A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: widget.onCancel,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF4C669A),
            ),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 8),
          if (widget.trainer != null)
            TextButton(
              onPressed: _isLoading ? null : _delete,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _save,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save, size: 18),
            label: Text(_isLoading ? 'Guardando...' : 'Guardar Cambios'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF135BEC),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F6F8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                      ),
                    ],
                    image: _fotoBytes != null
                        ? DecorationImage(
                            image: MemoryImage(_fotoBytes!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _fotoBytes == null
                      ? Icon(Icons.person, size: 64, color: Colors.grey[400])
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE7EBF3)),
                    ),
                    child: IconButton(
                      onPressed: _pickImage,
                      icon: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Color(0xFF4C669A),
                      ),
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 36,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'JPG o PNG, max 2MB',
              style: TextStyle(fontSize: 10, color: Color(0xFF4C669A)),
            ),
          ],
        ),
        const SizedBox(width: 32),
        Expanded(
          child: Column(
            children: [
              // Photo Actions
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.upload, size: 18),
                    label: const Text('Subir Foto'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('Tomar con Webcam'),
                  ),
                  if (_fotoBytes != null) ...[
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () => setState(() => _fotoBytes = null),
                      icon: const Icon(
                        Icons.delete,
                        size: 18,
                        color: Colors.red,
                      ),
                      label: const Text(
                        'Quitar',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              // State Row
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F6F8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE7EBF3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Estado del Entrenador',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Desactiva para restringir el acceso',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4C669A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _activo,
                      onChanged: (val) => setState(() => _activo = val),
                      activeThumbColor: const Color(0xFF135BEC),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.person, size: 20, color: Color(0xFF135BEC)),
            SizedBox(width: 8),
            Text(
              'Datos Personales',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'Cédula de Identidad (CI)',
                controller: _ciController,
                icon: Icons.badge_outlined,
                validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildTextField(
                label: 'Fecha de Inicio',
                controller: _fechaInicioController,
                icon: Icons.calendar_today,
                readOnly: true,
                onTap: _selectDate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'Nombres',
                controller: _nombresController,
                validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildTextField(
                label: 'Apellidos',
                controller: _apellidosController,
                validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sexo',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF4C669A),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _sexo,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'M', child: Text('Masculino')),
                  DropdownMenuItem(value: 'F', child: Text('Femenino')),
                ],
                onChanged: (val) => setState(() => _sexo = val!),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF6F6F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.contact_mail, size: 20, color: Color(0xFF135BEC)),
            SizedBox(width: 8),
            Text(
              'Información de Contacto',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'Dirección Domiciliaria',
          controller: _direccionController,
          icon: Icons.location_on,
          maxLines: 2,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'Teléfono / Celular',
                controller: _telefonoController,
                icon: Icons.call,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return null;
                  final isNumeric = RegExp(r'^\d+$').hasMatch(trimmed);
                  return isNumeric ? null : 'Solo se permiten numeros';
                },
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildTextField(
                label: 'Correo Electrónico',
                controller: _correoController,
                icon: Icons.mail,
                keyboardType: TextInputType.emailAddress,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: Color(0xFF4C669A),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: icon != null
                ? Icon(icon, size: 20, color: const Color(0xFF4C669A))
                : null,
            filled: true,
            fillColor: const Color(0xFFF6F6F8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
