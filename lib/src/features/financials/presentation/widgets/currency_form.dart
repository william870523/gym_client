import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:typed_data';
import 'dart:convert';

class CurrencyForm extends ConsumerStatefulWidget {
  final String? id;
  final String? initialName;
  final String? initialCode;
  final String? initialSymbol;
  final String? initialFlagImage;
  final Function(String name, String code, String symbol, Uint8List? flagBytes)
  onSubmit;

  const CurrencyForm({
    super.key,
    this.id,
    this.initialName,
    this.initialCode,
    this.initialSymbol,
    this.initialFlagImage,
    required this.onSubmit,
  });

  @override
  ConsumerState<CurrencyForm> createState() => _CurrencyFormState();
}

class _CurrencyFormState extends ConsumerState<CurrencyForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _symbolController;

  Uint8List? _flagBytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _codeController = TextEditingController(text: widget.initialCode);
    _symbolController = TextEditingController(text: widget.initialSymbol);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _symbolController.dispose();
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
          _codeController.text.toUpperCase(),
          _symbolController.text,
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

    // Colors
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
          width: 800,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
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
                      isEdit ? 'Actualizar Moneda' : 'Insertar Moneda',
                      style: GoogleFonts.inter(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: textMain,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isEdit
                          ? 'Edite la configuración de la moneda.'
                          : 'Configure una nueva moneda para el sistema.',
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
                        _SectionHeader(
                          title: "Información General",
                          icon: Icons.monetization_on_outlined,
                          primary: primary,
                          textMain: textMain,
                        ),
                        const SizedBox(height: 16),
                        _PremiumField(
                          label: "Nombre de la Moneda",
                          controller: _nameController,
                          placeholder: "Ej: Peso Argentino",
                          isDark: isDark,
                          backgroundColor: backgroundColor,
                          borderColor: borderColor,
                          textMain: textMain,
                          primary: primary,
                          validator: (v) =>
                              v?.isEmpty == true ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _PremiumField(
                                label: "Código ISO",
                                controller: _codeController,
                                placeholder: "ARS",
                                isDark: isDark,
                                backgroundColor: backgroundColor,
                                borderColor: borderColor,
                                textMain: textMain,
                                primary: primary,
                                maxLength: 3,
                                isMonospace: true,
                                isUppercase: true,
                                validator: (v) =>
                                    (v?.length ?? 0) < 3 ? '3 chars' : null,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _PremiumField(
                                label: "Símbolo",
                                controller: _symbolController,
                                placeholder: "\$",
                                isDark: isDark,
                                backgroundColor: backgroundColor,
                                borderColor: borderColor,
                                textMain: textMain,
                                primary: primary,
                                isMonospace: true,
                                validator: (v) =>
                                    v?.isEmpty == true ? 'Requerido' : null,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 24),

                        _SectionHeader(
                          title: "Icono / Bandera",
                          icon: Icons.image_outlined,
                          primary: primary,
                          textMain: textMain,
                        ),
                        const SizedBox(height: 16),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_flagBytes != null ||
                                widget.initialFlagImage != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 24),
                                child: _ThumbnailPreview(
                                  bytes: _flagBytes,
                                  base64Str: widget.initialFlagImage,
                                  borderColor: borderColor,
                                  isDark: isDark,
                                ),
                              ),

                            Expanded(
                              child: _UploadZone(
                                onTap: _pickImage,
                                isDark: isDark,
                                backgroundColor: backgroundColor,
                                borderColor: borderColor,
                                primary: primary,
                                textSecondary: textSecondary,
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
                  mainAxisAlignment: MainAxisAlignment.end,
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
                      ),
                      child: Text(
                        "Cancelar",
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
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
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
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

// ---- SUBCOMPONENTS (Copied from NacionalidadForm for consistency) ----

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
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
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
                counterText: "",
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
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
          ],
        ),
      ],
    );
  }
}

class _ThumbnailPreview extends StatelessWidget {
  final Uint8List? bytes;
  final String? base64Str;
  final Color borderColor;
  final bool isDark;

  const _ThumbnailPreview({
    this.bytes,
    this.base64Str,
    required this.borderColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 100,
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: bytes != null
            ? Image.memory(
                bytes!,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
              )
            : Image.memory(
                base64Decode(base64Str!),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
                errorBuilder: (c, e, s) =>
                    const Center(child: Icon(Icons.error)),
              ),
      ),
    );
  }
}

class _UploadZone extends StatefulWidget {
  final VoidCallback onTap;
  final bool isDark;
  final Color backgroundColor;
  final Color borderColor;
  final Color primary;
  final Color textSecondary;

  const _UploadZone({
    required this.onTap,
    required this.isDark,
    required this.backgroundColor,
    required this.borderColor,
    required this.primary,
    required this.textSecondary,
  });

  @override
  State<_UploadZone> createState() => _UploadZoneState();
}

class _UploadZoneState extends State<_UploadZone> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: _isHovering
                ? (widget.isDark ? Colors.white10 : Colors.blue.shade50)
                : widget.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovering ? widget.primary : widget.borderColor,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload_outlined, color: widget.primary),
                const SizedBox(height: 8),
                Text(
                  "Subir Icono/Bandera",
                  style: GoogleFonts.inter(
                    color: widget.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
