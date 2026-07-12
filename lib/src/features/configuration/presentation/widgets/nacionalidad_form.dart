import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';

class NacionalidadForm extends ConsumerStatefulWidget {
  final String? id;
  final String? initialName;
  final String? initialIsoCode;
  final String? initialFlagImage;
  final Function(String name, String isoCode, Uint8List? flagBytes) onSubmit;

  const NacionalidadForm({
    super.key,
    this.id,
    this.initialName,
    this.initialIsoCode,
    this.initialFlagImage,
    required this.onSubmit,
  });

  @override
  ConsumerState<NacionalidadForm> createState() => _NacionalidadFormState();
}

class _NacionalidadFormState extends ConsumerState<NacionalidadForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _isoCodeController;

  Uint8List? _flagBytes;
  bool _isLoading = false;
  bool _isHoveringUpload = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _isoCodeController = TextEditingController(text: widget.initialIsoCode);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _isoCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() => _isLoading = true);
        Uint8List compressed = await _compressImage(result.files.single.bytes!);
        setState(() {
          _flagBytes = compressed;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al elegir imagen: $e')));
      }
    }
  }

  Future<Uint8List> _compressImage(Uint8List list) async {
    final image = img.decodeImage(list);
    if (image == null) throw Exception("No se pudo decodificar la imagen");

    var processed = image;
    // Resize logic intact from protocol
    if (processed.width > 512 || processed.height > 512) {
      processed = img.copyResize(
        processed,
        width: processed.width > processed.height ? 512 : null,
        height: processed.height >= processed.width ? 512 : null,
        maintainAspect: true,
      );
    }
    return Uint8List.fromList(img.encodePng(processed));
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await widget.onSubmit(
          _nameController.text,
          _isoCodeController.text.toUpperCase(),
          _flagBytes,
        );
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.id != null;

    // Colors from HTML/Tailwind config
    final primary = const Color(0xFF135BEC);
    final surfaceColor = isDark
        ? const Color(0xFF1A2332)
        : const Color(0xFFFFFFFF);
    final backgroundColor = isDark
        ? const Color(0xFF101622)
        : const Color(0xFFF8F9FC);
    final borderColor = isDark
        ? const Color(0xFF2D3748)
        : const Color(0xFFE7EBF3);
    final textMain = isDark ? Colors.white : const Color(0xFF0D121B);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF4C669A);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: 800, // max-w-3xl aprox
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16), // rounded-xl
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // HEADER
              Container(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEdit
                          ? 'Actualizar Nacionalidad'
                          : 'Insertar Nacionalidad',
                      style: GoogleFonts.inter(
                        fontSize: 30, // text-3xl
                        fontWeight: FontWeight.w900, // font-black
                        color: textMain,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isEdit
                          ? 'Edite la información y configuración de la nacionalidad seleccionada.'
                          : 'Agrega un nuevo país al catálogo del sistema. Asegúrate de tener la bandera en formato de imagen válida.',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // FORM CONTENT
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // INFO SECTION
                        _SectionHeader(
                          title: "Información General",
                          icon: Icons.info_outline,
                          primary: primary,
                          textMain: textMain,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _PremiumField(
                                label: "Nombre de la Nacionalidad",
                                controller: _nameController,
                                placeholder: "Ej: Argentina",
                                isDark: isDark,
                                backgroundColor: backgroundColor,
                                borderColor: borderColor,
                                textMain: textMain,
                                primary: primary,
                                validator: (v) =>
                                    v?.isEmpty == true ? 'Requerido' : null,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 1,
                              child: _PremiumField(
                                label: "Código ISO",
                                controller: _isoCodeController,
                                placeholder: "AR",
                                isDark: isDark,
                                backgroundColor: backgroundColor,
                                borderColor: borderColor,
                                textMain: textMain,
                                primary: primary,
                                maxLength: 2,
                                isMonospace: true,
                                isUppercase: true,
                                suffixWidget: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "ALPHA-2",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: textSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                validator: (v) => (v?.length ?? 0) < 2
                                    ? '2 caracteres'
                                    : null,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 24),

                        // FLAG SECTION
                        _SectionHeader(
                          title: "Configuración de Bandera",
                          icon: Icons.flag_outlined,
                          primary: primary,
                          textMain: textMain,
                        ),
                        const SizedBox(height: 16),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Current Flag
                            if (_flagBytes != null ||
                                widget.initialFlagImage != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Bandera Actual",
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textMain,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: 120,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.black26
                                            : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            height: 64,
                                            width: 96,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.1),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: _flagBytes != null
                                                ? Image.memory(
                                                    _flagBytes!,
                                                    fit: BoxFit.contain,
                                                    filterQuality:
                                                        FilterQuality.high,
                                                    gaplessPlayback: true,
                                                  )
                                                : Image.memory(
                                                    base64Decode(
                                                      widget.initialFlagImage!,
                                                    ),
                                                    fit: BoxFit.contain,
                                                    filterQuality:
                                                        FilterQuality.high,
                                                    gaplessPlayback: true,
                                                    errorBuilder: (c, o, s) =>
                                                        const Center(
                                                          child: Icon(
                                                            Icons.error,
                                                            size: 20,
                                                          ),
                                                        ),
                                                  ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.green.withValues(
                                                  alpha: 0.2,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              "ACTIVA",
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Upload Zone
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Subir Bandera (Opcional)",
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: textMain,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  MouseRegion(
                                    onEnter: (_) => setState(
                                      () => _isHoveringUpload = true,
                                    ),
                                    onExit: (_) => setState(
                                      () => _isHoveringUpload = false,
                                    ),
                                    child: GestureDetector(
                                      onTap: _pickImage,
                                      child: Container(
                                        height: 140,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: _isHoveringUpload
                                              ? (isDark
                                                    ? Colors.white10
                                                    : Colors.blue.shade50
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ))
                                              : backgroundColor,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: _isHoveringUpload
                                                ? primary
                                                : borderColor,
                                            width: 2,
                                            style: BorderStyle
                                                .none, // We use CustomPaint for dash usually, but here solid or different logic
                                          ),
                                        ),
                                        child: CustomPaint(
                                          painter: _DashedBorderPainter(
                                            color: _isHoveringUpload
                                                ? primary
                                                : Colors.grey.shade400,
                                            strokeWidth: 2,
                                            gap: 5,
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? Colors.blue.withValues(
                                                          alpha: 0.1,
                                                        )
                                                      : Colors.blue.shade50,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.cloud_upload_outlined,
                                                  color: primary,
                                                  size: 28,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              RichText(
                                                text: TextSpan(
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                    color: textSecondary,
                                                  ),
                                                  children: [
                                                    TextSpan(
                                                      text:
                                                          "Haz clic para subir",
                                                      style: TextStyle(
                                                        color: primary,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const TextSpan(
                                                      text:
                                                          " o arrastra y suelta",
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "PNG, JPG, SVG hasta 2MB",
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: textSecondary
                                                      .withValues(alpha: 0.7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),

              // FOOTER
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isEdit)
                      TextButton.icon(
                        onPressed: () {
                          // Delete placeholder
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red,
                        ),
                        label: Text(
                          "Eliminar Nacionalidad",
                          style: GoogleFonts.inter(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),

                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            foregroundColor: textSecondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.white,
                            side: BorderSide(color: borderColor),
                          ),
                          child: Text(
                            "Cancelar",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            elevation: 4,
                            shadowColor: primary.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined, size: 20),
                          label: Text(
                            _isLoading ? "Guardando..." : "Guardar Cambios",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color primary;
  final Color textMain;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.primary,
    required this.textMain,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title, // h3
          style: GoogleFonts.inter(
            fontSize: 18, // text-lg
            fontWeight: FontWeight.bold, // font-bold
            color: textMain,
          ),
        ),
      ],
    );
  }
}

class _PremiumField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String placeholder;
  final bool isDark;
  final Color backgroundColor;
  final Color borderColor;
  final Color textMain;
  final Color primary;
  final int? maxLength;
  final bool isMonospace;
  final bool isUppercase;
  final Widget? suffixWidget;
  final String? Function(String?)? validator;

  const _PremiumField({
    required this.label,
    required this.controller,
    required this.placeholder,
    required this.isDark,
    required this.backgroundColor,
    required this.borderColor,
    required this.textMain,
    required this.primary,
    this.maxLength,
    this.isMonospace = false,
    this.isUppercase = false,
    this.suffixWidget,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textMain,
            ),
            children: [
              TextSpan(text: label),
              const TextSpan(
                text: " *",
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.centerRight,
          children: [
            TextFormField(
              controller: controller,
              style: isMonospace
                  ? GoogleFonts.robotoMono(
                      color: textMain,
                      fontWeight: FontWeight.bold,
                    )
                  : GoogleFonts.inter(color: textMain),
              textCapitalization: isUppercase
                  ? TextCapitalization.characters
                  : TextCapitalization.none,
              maxLength: maxLength,
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: GoogleFonts.inter(
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
                filled: true,
                fillColor: backgroundColor,
                counterText: "", // Hide counter
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ), // h-11
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primary, width: 2),
                ),
              ),
              validator: validator,
            ),
            if (suffixWidget != null)
              Positioned(right: 12, child: suffixWidget!),
          ],
        ),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    Path path = Path();
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(12),
      ),
    );

    PathMetrics pathMetrics = path.computeMetrics();
    for (PathMetric pathMetric in pathMetrics) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        canvas.drawPath(
          pathMetric.extractPath(distance, distance + gap),
          paint,
        );
        distance += gap * 2;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
