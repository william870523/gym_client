import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/trainer_model.dart';
import 'camera_selector_dialog.dart';

typedef TrainerPulsoSubmit =
    Future<void> Function(Map<String, dynamic> payload);

/// Alta y edición de entrenadores en PULSO. Mantiene el contrato original:
/// `onSubmit(Map)` con las mismas claves de la API, foto por cámara
/// ([CameraSelectorDialog]) o archivo, y fecha de alta como fecha de
/// calendario en medianoche UTC (`calendarDateToUtc`).
class TrainerPulsoForm extends StatefulWidget {
  const TrainerPulsoForm({super.key, this.trainer, required this.onSubmit});

  final TrainerModel? trainer;
  final TrainerPulsoSubmit onSubmit;

  @override
  State<TrainerPulsoForm> createState() => _TrainerPulsoFormState();
}

class _TrainerPulsoFormState extends State<TrainerPulsoForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ciController;
  late final TextEditingController _nombresController;
  late final TextEditingController _apellidosController;
  late final TextEditingController _direccionController;
  late final TextEditingController _telefonoController;
  late final TextEditingController _correoController;

  String _sexo = 'M';
  bool _activo = true;
  Uint8List? _fotoBytes;
  late DateTime _fechaInicio;
  bool _busy = false;
  String? _error;

  static final _dateFmt = DateFormat('yyyy-MM-dd');

  bool get _isEdit => widget.trainer != null;

  @override
  void initState() {
    super.initState();
    final trainer = widget.trainer;
    _ciController = TextEditingController(text: trainer?.ci);
    _nombresController = TextEditingController(text: trainer?.nombres);
    _apellidosController = TextEditingController(text: trainer?.apellidos);
    _direccionController = TextEditingController(text: trainer?.direccion);
    _telefonoController = TextEditingController(
      text: trainer?.telefono?.toString(),
    );
    _correoController = TextEditingController(text: trainer?.correo);
    if (trainer != null) {
      final rawSexo = (trainer.sexo ?? 'M').trim().toUpperCase();
      _sexo = rawSexo.startsWith('F') ? 'F' : 'M';
      _activo = trainer.activo;
      _fechaInicio = trainer.fechaInicio;
      if (trainer.foto != null) {
        try {
          _fotoBytes = base64Decode(trainer.foto!);
        } catch (_) {}
      }
    } else {
      _fechaInicio = todayInZone(appClock.gymTimezone);
    }
  }

  @override
  void dispose() {
    _ciController.dispose();
    _nombresController.dispose();
    _apellidosController.dispose();
    _direccionController.dispose();
    _telefonoController.dispose();
    _correoController.dispose();
    super.dispose();
  }

  // La fecha de alta es fecha de calendario (medianoche UTC); se muestra por
  // componentes, sin conversión de zona.
  String get _fechaLabel => _dateFmt.format(_fechaInicio.toUtc());

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.first.bytes == null || !mounted) return;
    setState(() => _fotoBytes = result.files.first.bytes);
  }

  Future<void> _takePhoto() async {
    final bytes = await showDialog<Uint8List>(
      context: context,
      builder: (context) => const CameraSelectorDialog(),
    );
    if (bytes == null || !mounted) return;
    setState(() => _fotoBytes = bytes);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaInicio,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _fechaInicio = picked);
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final direccion = _direccionController.text.trim();
    final correo = _correoController.text.trim();
    final payload = <String, dynamic>{
      'ci_entrenador': _ciController.text.trim(),
      'nombres_entrenador': _nombresController.text.trim(),
      'apellidos_entrenador': _apellidosController.text.trim(),
      'sexo_entrenador': _sexo == 'M' ? 'Masculino' : 'Femenino',
      'direccion_entrenador': direccion.isNotEmpty ? direccion : null,
      'telefono_entrenador': int.tryParse(_telefonoController.text.trim()),
      'correo_entrenador': correo.isNotEmpty ? correo : null,
      'activo_entrenador': _activo,
      'fecha_incio_entrenador': calendarDateToUtc(
        _fechaInicio,
      ).toIso8601String(),
      if (_fotoBytes != null) 'foto_entrenador': base64Encode(_fotoBytes!),
      if (_fotoBytes == null && _isEdit) 'foto_entrenador': null,
    };
    try {
      await widget.onSubmit(payload);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo guardar el entrenador: $error';
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
                              _isEdit
                                  ? 'EDITAR ENTRENADOR'
                                  : 'NUEVO ENTRENADOR',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Ficha personal, contacto y foto del entrenador.',
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
                            const PulsoLabel('Fotografía'),
                            const SizedBox(height: 12),
                            _buildPhotoSection(context),
                            const SizedBox(height: 24),
                            const PulsoLabel('Datos personales'),
                            const SizedBox(height: 12),
                            _buildPersonalFields(context),
                            const SizedBox(height: 24),
                            const PulsoLabel('Contacto'),
                            const SizedBox(height: 12),
                            _buildContactFields(context),
                            const SizedBox(height: 24),
                            const PulsoLabel('Disponibilidad operativa'),
                            const SizedBox(height: 12),
                            _buildStatusField(context),
                            if (_isEdit) ...[
                              const SizedBox(height: 18),
                              Text(
                                'ID · ${widget.trainer!.id}',
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

  Widget _buildPhotoSection(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final preview = Container(
      width: 96,
      height: 96,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border.all(color: tokens.line),
      ),
      child: _fotoBytes != null
          ? Image.memory(_fotoBytes!, fit: BoxFit.cover)
          : Icon(Icons.person_outline, size: 40, color: tokens.muted),
    );
    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PulsoSecondaryButton(
              label: 'Tomar foto',
              icon: Icons.photo_camera_outlined,
              onPressed: _busy ? null : _takePhoto,
            ),
            PulsoSecondaryButton(
              label: 'Elegir archivo',
              icon: Icons.folder_open_outlined,
              onPressed: _busy ? null : _pickImage,
            ),
            if (_fotoBytes != null)
              PulsoSecondaryButton(
                label: 'Quitar',
                icon: Icons.close,
                danger: true,
                onPressed: _busy
                    ? null
                    : () => setState(() => _fotoBytes = null),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'La foto ayuda a identificar al entrenador en el mostrador.',
          style: TextStyle(color: tokens.muted, fontSize: 12),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [preview, const SizedBox(height: 12), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            preview,
            const SizedBox(width: 16),
            Expanded(child: actions),
          ],
        );
      },
    );
  }

  Widget _buildPersonalFields(BuildContext context) {
    final ci = TextFormField(
      key: const ValueKey('pulso-trainer-ci'),
      controller: _ciController,
      textInputAction: TextInputAction.next,
      style: const TextStyle(
        fontFamily: PulsoFonts.mono,
        fontWeight: FontWeight.w600,
      ),
      decoration: const InputDecoration(
        labelText: 'Cédula de identidad (CI)',
      ),
      validator: _required,
    );
    final fecha = TextFormField(
      key: ValueKey('pulso-trainer-start-$_fechaLabel'),
      initialValue: _fechaLabel,
      readOnly: true,
      onTap: _busy ? null : _pickDate,
      style: const TextStyle(
        fontFamily: PulsoFonts.mono,
        fontWeight: FontWeight.w600,
      ),
      decoration: const InputDecoration(
        labelText: 'Fecha de alta',
        suffixIcon: Icon(Icons.event_outlined, size: 18),
      ),
    );
    final nombres = TextFormField(
      key: const ValueKey('pulso-trainer-nombres'),
      controller: _nombresController,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(labelText: 'Nombres'),
      validator: _required,
    );
    final apellidos = TextFormField(
      key: const ValueKey('pulso-trainer-apellidos'),
      controller: _apellidosController,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(labelText: 'Apellidos'),
      validator: _required,
    );
    final sexo = DropdownButtonFormField<String>(
      key: const ValueKey('pulso-trainer-sexo'),
      initialValue: _sexo,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Sexo'),
      items: const [
        DropdownMenuItem(value: 'M', child: Text('Masculino')),
        DropdownMenuItem(value: 'F', child: Text('Femenino')),
      ],
      onChanged: _busy
          ? null
          : (value) => setState(() => _sexo = value ?? 'M'),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 480;
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ci,
              const SizedBox(height: 16),
              fecha,
              const SizedBox(height: 16),
              nombres,
              const SizedBox(height: 16),
              apellidos,
              const SizedBox(height: 16),
              sexo,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: ci),
                const SizedBox(width: 16),
                Expanded(child: fecha),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: nombres),
                const SizedBox(width: 16),
                Expanded(child: apellidos),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: sexo),
                const SizedBox(width: 16),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildContactFields(BuildContext context) {
    final telefono = TextFormField(
      key: const ValueKey('pulso-trainer-telefono'),
      controller: _telefonoController,
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        fontFamily: PulsoFonts.mono,
        fontWeight: FontWeight.w600,
      ),
      decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
    );
    final correo = TextFormField(
      key: const ValueKey('pulso-trainer-correo'),
      controller: _correoController,
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(labelText: 'Correo (opcional)'),
    );
    final direccion = TextFormField(
      key: const ValueKey('pulso-trainer-direccion'),
      controller: _direccionController,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      decoration: const InputDecoration(labelText: 'Dirección (opcional)'),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 480;
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              telefono,
              const SizedBox(height: 16),
              correo,
              const SizedBox(height: 16),
              direccion,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: telefono),
                const SizedBox(width: 16),
                Expanded(child: correo),
              ],
            ),
            const SizedBox(height: 16),
            direccion,
          ],
        );
      },
    );
  }

  Widget _buildStatusField(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _activo ? tokens.successSoft : tokens.raised,
        border: Border.all(color: _activo ? tokens.success : tokens.line),
      ),
      child: Row(
        children: [
          Icon(
            _activo ? Icons.check_circle_outline : Icons.pause_circle_outline,
            color: _activo ? tokens.success : tokens.muted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activo ? 'Activo' : 'Inactivo',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tokens.chalk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _activo
                      ? 'Disponible para acompañar socios.'
                      : 'Su acceso queda restringido.',
                  style: TextStyle(color: tokens.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _activo,
            activeThumbColor: tokens.success,
            onChanged: _busy
                ? null
                : (value) => setState(() => _activo = value),
          ),
        ],
      ),
    );
  }
}

String? _required(String? value) {
  return value?.trim().isNotEmpty == true ? null : 'Campo obligatorio.';
}
