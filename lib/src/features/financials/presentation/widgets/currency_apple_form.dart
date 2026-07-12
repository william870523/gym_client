import 'dart:convert';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;

import '../../../../core/theme/registro_palette.dart';
import '../../../../core/widgets/registro_widgets.dart';

typedef CurrencyFormSubmit =
    Future<void> Function(
      String name,
      String code,
      String symbol,
      Uint8List? flagBytes,
    );

class CurrencyAppleForm extends StatefulWidget {
  const CurrencyAppleForm({
    super.key,
    this.id,
    this.initialName,
    this.initialCode,
    this.initialSymbol,
    this.initialFlagImage,
    required this.onSubmit,
  });

  final String? id;
  final String? initialName;
  final String? initialCode;
  final String? initialSymbol;
  final String? initialFlagImage;
  final CurrencyFormSubmit onSubmit;

  @override
  State<CurrencyAppleForm> createState() => _CurrencyAppleFormState();
}

class _CurrencyAppleFormState extends State<CurrencyAppleForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _symbolController;
  late final AnimationController _animationController;
  late final Animation<double> _entranceAnimation;

  Uint8List? _flagBytes;
  String? _errorMessage;
  bool _isLoading = false;

  bool get _isEdit => widget.id != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _codeController = TextEditingController(text: widget.initialCode);
    _symbolController = TextEditingController(text: widget.initialSymbol);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _entranceAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _symbolController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_isLoading) {
      return;
    }
    await _animationController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      final bytes = result?.files.single.bytes;
      if (bytes == null) {
        return;
      }
      await _processBytes(bytes);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo preparar la bandera: $error';
      });
    }
  }

  /// Comprime y adopta una imagen, venga del selector o de arrastrar-y-soltar.
  Future<void> _processBytes(Uint8List bytes) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final compressed = await compute(_compressFlagImage, bytes);
      if (!mounted) {
        return;
      }
      setState(() {
        _flagBytes = compressed;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo preparar la bandera: $error';
      });
    }
  }

  Future<void> _submit() async {
    if (_isLoading || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onSubmit(
        _nameController.text.trim(),
        _codeController.text.trim().toUpperCase(),
        _symbolController.text.trim(),
        _flagBytes,
      );
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      await _close();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo guardar el asiento: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = RegistroPalette.fromContext(context);
    final screen = MediaQuery.sizeOf(context);

    return PopScope(
      canPop: !_isLoading,
      child: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _entranceAnimation,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, 20 * (1 - _entranceAnimation.value)),
              child: Opacity(opacity: _entranceAnimation.value, child: child),
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(20),
                constraints: BoxConstraints(
                  maxWidth: 640,
                  maxHeight: screen.height - 40,
                ),
                decoration: BoxDecoration(
                  color: p.paper,
                  border: Border(
                    top: BorderSide(color: p.verm, width: 3),
                    right: BorderSide(color: p.rule),
                    bottom: BorderSide(color: p.rule),
                    left: BorderSide(color: p.rule),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FormHeader(
                      p: p,
                      isEdit: _isEdit,
                      isLoading: _isLoading,
                      onCancel: _close,
                      onSave: _submit,
                    ),
                    Divider(height: 1, thickness: 1, color: p.rule),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(26, 24, 26, 28),
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_errorMessage != null) ...[
                                RegistroErrorBlock(
                                  p: p,
                                  message: _errorMessage!,
                                ),
                                const SizedBox(height: 24),
                              ],
                              RegistroSectionRule(
                                p: p,
                                number: '01',
                                label: 'IDENTIFICACION',
                              ),
                              const SizedBox(height: 18),
                              RegistroFormField(
                                p: p,
                                label: 'NOMBRE DE LA DIVISA',
                                hint: 'Ej. Dolar estadounidense',
                                controller: _nameController,
                                requiredField: true,
                                validator: _requiredText,
                              ),
                              const SizedBox(height: 22),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final codeField = RegistroFormField(
                                    p: p,
                                    label: 'CODIGO ISO',
                                    hint: 'USD',
                                    controller: _codeController,
                                    requiredField: true,
                                    monospace: true,
                                    maxLength: 3,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    inputFormatters: const [
                                      _UpperCaseTextFormatter(),
                                    ],
                                    validator: (value) =>
                                        value?.trim().length == 3
                                        ? null
                                        : 'Use exactamente 3 letras.',
                                  );
                                  final symbolField = RegistroFormField(
                                    p: p,
                                    label: 'SIMBOLO',
                                    hint: r'$',
                                    controller: _symbolController,
                                    requiredField: true,
                                    monospace: true,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    validator: _requiredText,
                                  );

                                  if (constraints.maxWidth < 430) {
                                    return Column(
                                      children: [
                                        codeField,
                                        const SizedBox(height: 22),
                                        symbolField,
                                      ],
                                    );
                                  }

                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: codeField),
                                      const SizedBox(width: 28),
                                      Expanded(child: symbolField),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 32),
                              RegistroSectionRule(
                                p: p,
                                number: '02',
                                label: 'ENSENA NACIONAL',
                              ),
                              const SizedBox(height: 18),
                              _FlagEditor(
                                p: p,
                                bytes: _flagBytes,
                                initialBase64: widget.initialFlagImage,
                                code: _codeController.text,
                                isLoading: _isLoading,
                                onPick: _pickImage,
                                onDropBytes: _processBytes,
                              ),
                              const SizedBox(height: 28),
                              Divider(height: 1, thickness: 1, color: p.rule),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '†',
                                    style: GoogleFonts.fragmentMono(
                                      fontSize: 11,
                                      color: p.verm,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      'Los campos marcados son obligatorios. '
                                      'Los cambios se aplican al catalogo real de monedas.',
                                      style: GoogleFonts.fragmentMono(
                                        fontSize: 10.5,
                                        height: 1.45,
                                        color: p.ink3,
                                      ),
                                    ),
                                  ),
                                  if (_isEdit) ...[
                                    const SizedBox(width: 18),
                                    Text(
                                      registroShortId(widget.id!),
                                      style: GoogleFonts.fragmentMono(
                                        fontSize: 10.5,
                                        color: p.ink4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormHeader extends StatelessWidget {
  const _FormHeader({
    required this.p,
    required this.isEdit,
    required this.isLoading,
    required this.onCancel,
    required this.onSave,
  });

  final RegistroPalette p;
  final bool isEdit;
  final bool isLoading;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'GYM',
              style: GoogleFonts.archivo(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.1,
                color: p.ink,
              ),
            ),
            Text(
              '·',
              style: GoogleFonts.archivo(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: p.verm,
              ),
            ),
            Text(
              'OS — FINANZAS',
              style: GoogleFonts.archivo(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.1,
                color: p.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(
            text: isEdit ? 'EDITAR DIVISA' : 'NUEVA DIVISA',
            children: [
              TextSpan(
                text: '.',
                style: TextStyle(color: p.verm),
              ),
            ],
          ),
          style: GoogleFonts.archivoBlack(
            fontSize: 30,
            height: 1,
            color: p.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isEdit
              ? 'F-03A / MODIFICACION · REV. 2026'
              : 'F-03A / ALTA · REV. 2026',
          style: GoogleFonts.fragmentMono(fontSize: 10.5, color: p.ink3),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 22,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        RegistroDialogTextAction(
          p: p,
          label: 'CANCELAR',
          onTap: isLoading ? null : onCancel,
        ),
        RegistroDialogTextAction(
          p: p,
          label: isLoading ? 'COMPONIENDO…' : 'GUARDAR CAMBIOS',
          prime: true,
          onTap: isLoading ? null : onSave,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, const SizedBox(height: 20), actions],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: copy),
              const SizedBox(width: 20),
              actions,
            ],
          );
        },
      ),
    );
  }
}

/// Zona de la enseña: clic para elegir archivo o arrastrar-y-soltar la
/// imagen encima. Borde discontinuo de tinta; al arrastrar, vermellón.
class _FlagEditor extends StatefulWidget {
  const _FlagEditor({
    required this.p,
    required this.bytes,
    required this.initialBase64,
    required this.code,
    required this.isLoading,
    required this.onPick,
    required this.onDropBytes,
  });

  final RegistroPalette p;
  final Uint8List? bytes;
  final String? initialBase64;
  final String code;
  final bool isLoading;
  final VoidCallback onPick;
  final ValueChanged<Uint8List> onDropBytes;

  @override
  State<_FlagEditor> createState() => _FlagEditorState();
}

class _FlagEditorState extends State<_FlagEditor> {
  bool _dragging = false;

  static const _imageExtensions = {'png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif'};

  Future<void> _handleDrop(DropDoneDetails detail) async {
    if (widget.isLoading || detail.files.isEmpty) {
      return;
    }
    final file = detail.files.first;
    final ext = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : '';
    if (!_imageExtensions.contains(ext)) {
      return;
    }
    final bytes = await file.readAsBytes();
    widget.onDropBytes(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final bytes = widget.bytes;

    final String statusLabel;
    final Color statusColor;
    if (_dragging) {
      statusLabel = 'SUELTA LA IMAGEN AQUÍ';
      statusColor = p.verm;
    } else if (bytes != null) {
      statusLabel = 'NUEVA IMAGEN PREPARADA';
      statusColor = p.verm;
    } else if (widget.initialBase64?.isNotEmpty == true) {
      statusLabel = 'BANDERA ASIGNADA';
      statusColor = p.ink2;
    } else {
      statusLabel = 'SIN BANDERA';
      statusColor = p.ink2;
    }

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) {
        setState(() => _dragging = false);
        _handleDrop(detail);
      },
      child: MouseRegion(
        cursor: widget.isLoading
            ? SystemMouseCursors.wait
            : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.isLoading ? null : widget.onPick,
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: _dragging ? p.verm : p.ink4,
            ),
            child: Container(
              color: _dragging ? p.vermSoft : Colors.transparent,
              padding: const EdgeInsets.all(18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final preview = _FlagPreview(
                    p: p,
                    bytes: bytes,
                    initialBase64: widget.initialBase64,
                    code: widget.code,
                  );
                  final copy = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusLabel,
                        style: GoogleFonts.archivo(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Haz clic para elegir el archivo o arrastra y suelta '
                        'la imagen sobre este recuadro.',
                        style: GoogleFonts.archivo(
                          fontSize: 13,
                          height: 1.45,
                          color: p.ink2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PNG o JPG · se normaliza a un máximo de 512 px.',
                        style: GoogleFonts.fragmentMono(
                          fontSize: 10.5,
                          height: 1.45,
                          color: p.ink3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RegistroDialogTextAction(
                        p: p,
                        label: widget.isLoading
                            ? 'PROCESANDO…'
                            : 'CAMBIAR BANDERA',
                        prime: true,
                        onTap: widget.isLoading ? null : widget.onPick,
                      ),
                    ],
                  );

                  if (constraints.maxWidth < 430) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [preview, const SizedBox(height: 18), copy],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      preview,
                      const SizedBox(width: 24),
                      Expanded(child: copy),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Borde discontinuo de tinta, como los recuadros punteados de un impreso.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const dash = 5.0;
    const gap = 4.0;
    final path = Path()..addRect(Offset.zero & size);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _FlagPreview extends StatelessWidget {
  const _FlagPreview({
    required this.p,
    required this.bytes,
    required this.initialBase64,
    required this.code,
  });

  final RegistroPalette p;
  final Uint8List? bytes;
  final String? initialBase64;
  final String code;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (bytes != null) {
      image = Image.memory(
        bytes!,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      );
    } else {
      Uint8List? initialBytes;
      try {
        if (initialBase64?.isNotEmpty == true) {
          initialBytes = base64Decode(initialBase64!);
        }
      } catch (_) {
        initialBytes = null;
      }

      image = initialBytes == null
          ? Center(
              child: Text(
                code.trim().isEmpty ? '¶' : code.toUpperCase(),
                style: GoogleFonts.fragmentMono(fontSize: 16, color: p.ink3),
              ),
            )
          : Image.memory(
              initialBytes,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  code.trim().isEmpty ? '¶' : code.toUpperCase(),
                  style: GoogleFonts.fragmentMono(fontSize: 16, color: p.ink3),
                ),
              ),
            );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 144,
          height: 96,
          decoration: BoxDecoration(
            color: p.paper2,
            border: Border.all(color: p.ruleStrong),
          ),
          clipBehavior: Clip.hardEdge,
          child: image,
        ),
        const SizedBox(height: 7),
        Text(
          'fig. 01 — enseña',
          style: GoogleFonts.fragmentMono(
            fontSize: 9.5,
            fontStyle: FontStyle.italic,
            color: p.ink3,
          ),
        ),
      ],
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  const _UpperCaseTextFormatter();

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

String? _requiredText(String? value) {
  return value?.trim().isEmpty == false ? null : 'Campo obligatorio.';
}

Uint8List _compressFlagImage(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw const FormatException('La imagen no tiene un formato compatible.');
  }

  final processed = image.width > 512 || image.height > 512
      ? img.copyResize(
          image,
          width: image.width > image.height ? 512 : null,
          height: image.height >= image.width ? 512 : null,
          maintainAspect: true,
        )
      : image;
  return Uint8List.fromList(img.encodePng(processed));
}
