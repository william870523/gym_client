import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';

typedef NacionalidadPulsoSubmit =
    Future<void> Function(String name, String isoCode, Uint8List? flagBytes);

class NacionalidadPulsoForm extends StatefulWidget {
  const NacionalidadPulsoForm({
    super.key,
    this.id,
    this.initialName,
    this.initialIsoCode,
    this.initialFlagImage,
    required this.onSubmit,
  });

  final String? id;
  final String? initialName;
  final String? initialIsoCode;
  final String? initialFlagImage;
  final NacionalidadPulsoSubmit onSubmit;

  @override
  State<NacionalidadPulsoForm> createState() => _NacionalidadPulsoFormState();
}

class _NacionalidadPulsoFormState extends State<NacionalidadPulsoForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _isoController;

  Uint8List? _flagBytes;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.id != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _isoController = TextEditingController(text: widget.initialIsoCode);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _isoController.dispose();
    super.dispose();
  }

  Future<void> _pickFlag() async {
    if (_busy) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      final bytes = result?.files.single.bytes;
      if (bytes == null) return;
      setState(() {
        _busy = true;
        _error = null;
      });
      final compressed = await compute(_compressNacionalidadFlag, bytes);
      if (!mounted) return;
      setState(() {
        _flagBytes = compressed;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo preparar la bandera: $error';
      });
    }
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        _nameController.text.trim(),
        _isoController.text.trim().toUpperCase(),
        _flagBytes,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo guardar la nacionalidad: $error';
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
                maxWidth: 680,
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
                            const PulsoLabel('PULSO · CONFIGURACIÓN'),
                            const SizedBox(height: 9),
                            Text(
                              _isEdit
                                  ? 'EDITAR NACIONALIDAD'
                                  : 'NUEVA NACIONALIDAD',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _isEdit
                                  ? 'Actualiza nombre, código ISO o bandera.'
                                  : 'Añade una nacionalidad disponible para los expedientes.',
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
                        if (constraints.maxWidth < 560) {
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
                            const PulsoLabel('Identidad nacional'),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey('pulso-nationality-name'),
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Nombre de la nacionalidad',
                                hintText: 'Ej. Dominicana',
                              ),
                              validator: _required,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const ValueKey('pulso-nationality-iso'),
                              controller: _isoController,
                              maxLength: 3,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: const [_IsoFormatter()],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              style: const TextStyle(
                                fontFamily: PulsoFonts.mono,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Código ISO',
                                hintText: 'DO',
                                counterText: '',
                              ),
                              validator: (value) {
                                final length = value?.trim().length ?? 0;
                                return length >= 2 && length <= 3
                                    ? null
                                    : 'Usa dos o tres letras.';
                              },
                            ),
                            const SizedBox(height: 24),
                            const PulsoLabel('Bandera o enseña'),
                            const SizedBox(height: 12),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _isoController,
                              builder: (context, iso, _) => _FlagPicker(
                                bytes: _flagBytes,
                                initialBase64: widget.initialFlagImage,
                                isoCode: iso.text,
                                busy: _busy,
                                onTap: _pickFlag,
                              ),
                            ),
                            if (_isEdit && widget.id != null) ...[
                              const SizedBox(height: 18),
                              Text(
                                'ID · ${widget.id}',
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
}

class _FlagPicker extends StatelessWidget {
  const _FlagPicker({
    required this.bytes,
    required this.initialBase64,
    required this.isoCode,
    required this.busy,
    required this.onTap,
  });

  final Uint8List? bytes;
  final String? initialBase64;
  final String isoCode;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    Widget image;
    if (bytes != null) {
      image = Image.memory(bytes!, fit: BoxFit.contain, gaplessPlayback: true);
    } else if (initialBase64?.isNotEmpty == true) {
      Uint8List? decoded;
      try {
        decoded = base64Decode(initialBase64!);
      } catch (_) {
        decoded = null;
      }
      image = decoded == null
          ? _FlagFallback(isoCode: isoCode)
          : Image.memory(decoded, fit: BoxFit.contain, gaplessPlayback: true);
    } else {
      image = _FlagFallback(isoCode: isoCode);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border.all(color: tokens.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final preview = Container(
            width: 132,
            height: 88,
            color: tokens.surface,
            padding: const EdgeInsets.all(5),
            child: image,
          );
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bytes != null
                    ? 'Nueva bandera preparada'
                    : initialBase64?.isNotEmpty == true
                    ? 'Bandera asignada'
                    : 'Sin bandera',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: bytes != null ? tokens.success : tokens.chalkDim,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'PNG o JPG. La imagen se normaliza a un máximo de 512 px.',
                style: TextStyle(color: tokens.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              PulsoSecondaryButton(
                label: busy ? 'Procesando' : 'Elegir imagen',
                icon: Icons.upload_file_outlined,
                onPressed: busy ? null : onTap,
              ),
            ],
          );
          if (constraints.maxWidth < 430) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [preview, const SizedBox(height: 14), copy],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              preview,
              const SizedBox(width: 18),
              Expanded(child: copy),
            ],
          );
        },
      ),
    );
  }
}

class _FlagFallback extends StatelessWidget {
  const _FlagFallback({required this.isoCode});

  final String isoCode;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Center(
      child: Text(
        isoCode.trim().isEmpty ? '—' : isoCode.trim().toUpperCase(),
        style: TextStyle(
          fontFamily: PulsoFonts.mono,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: tokens.muted,
        ),
      ),
    );
  }
}

class _IsoFormatter extends TextInputFormatter {
  const _IsoFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text
        .replaceAll(RegExp('[^a-zA-Z]'), '')
        .toUpperCase();
    return newValue.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }
}

String? _required(String? value) {
  return value?.trim().isNotEmpty == true ? null : 'Campo obligatorio.';
}

Uint8List _compressNacionalidadFlag(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw const FormatException('Formato de imagen no compatible.');
  }
  final resized = image.width > 512 || image.height > 512
      ? img.copyResize(
          image,
          width: image.width > image.height ? 512 : null,
          height: image.height >= image.width ? 512 : null,
          maintainAspect: true,
        )
      : image;
  return Uint8List.fromList(img.encodePng(resized));
}
