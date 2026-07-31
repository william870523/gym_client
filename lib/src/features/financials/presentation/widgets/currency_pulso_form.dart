import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/flag_image.dart';
import '../../../../core/widgets/pulso_widgets.dart';

typedef CurrencyPulsoSubmit =
    Future<void> Function(
      String name,
      String code,
      String symbol,
      Uint8List? flagBytes,
    );

class CurrencyPulsoForm extends StatefulWidget {
  const CurrencyPulsoForm({
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
  final CurrencyPulsoSubmit onSubmit;

  @override
  State<CurrencyPulsoForm> createState() => _CurrencyPulsoFormState();
}

class _CurrencyPulsoFormState extends State<CurrencyPulsoForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _symbolController;

  Uint8List? _flagBytes;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.id != null;

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

  Future<void> _pickFlag() async {
    if (_saving) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['svg', 'png', 'jpg', 'jpeg', 'webp'],
        allowMultiple: false,
        withData: true,
      );
      final bytes = result?.files.single.bytes;
      if (bytes == null) return;
      setState(() {
        _saving = true;
        _error = null;
      });
      final compressed = await compute(normalizeFlagImageBytes, bytes);
      if (!mounted) return;
      setState(() {
        _flagBytes = compressed;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No se pudo preparar la bandera: $error';
      });
    }
  }

  Future<void> _submit() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        _nameController.text.trim(),
        _codeController.text.trim().toUpperCase(),
        _symbolController.text.trim(),
        _flagBytes,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No se pudo guardar la moneda: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Los diálogos se montan en el Overlay del Navigator, por encima del
    // PulsoThemeScope de la pantalla anfitriona, por lo que no heredan el
    // ThemeExtension<PulsoTokens>. El formulario se envuelve en su propio
    // PulsoThemeScope para resolver tokens con independencia del contexto
    // que lo abre (docs/DESIGN_SYSTEM_PULSO.md §10 y §14).
    return PulsoThemeScope(child: Builder(builder: _buildDialog));
  }

  Widget _buildDialog(BuildContext context) {
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
                      const PulsoLabel('PULSO · FINANZAS · PILOTO'),
                      const SizedBox(height: 9),
                      Text(
                        _isEdit ? 'EDITAR MONEDA' : 'NUEVA MONEDA',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _isEdit
                            ? 'Actualiza el catálogo sin perder el contexto.'
                            : 'Añade una divisa disponible para cobros y reportes.',
                        style: TextStyle(color: tokens.muted, fontSize: 13),
                      ),
                    ],
                  );
                  final actions = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PulsoSecondaryButton(
                        label: 'Cancelar',
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                      ),
                      PulsoPrimaryButton(
                        label: _isEdit ? 'Guardar cambios' : 'Crear moneda',
                        onPressed: _submit,
                        busy: _saving,
                      ),
                    ],
                  );

                  if (constraints.maxWidth < 560) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [copy, const SizedBox(height: 18), actions],
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
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: tokens.danger,
                                size: 19,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: tokens.danger,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      const PulsoLabel('Identidad de la divisa'),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const ValueKey('pulso-currency-name'),
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la divisa',
                          hintText: 'Ej. Dólar estadounidense',
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final code = TextFormField(
                            key: const ValueKey('pulso-currency-code'),
                            controller: _codeController,
                            maxLength: 3,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: const [_UpperCaseFormatter()],
                            style: const TextStyle(
                              fontFamily: PulsoFonts.mono,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Código ISO',
                              hintText: 'USD',
                              counterText: '',
                            ),
                            validator: (value) => value?.trim().length == 3
                                ? null
                                : 'Usa exactamente tres letras.',
                          );
                          final symbol = TextFormField(
                            key: const ValueKey('pulso-currency-symbol'),
                            controller: _symbolController,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            style: const TextStyle(
                              fontFamily: PulsoFonts.mono,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Símbolo',
                              hintText: r'$',
                            ),
                            validator: _required,
                          );
                          if (constraints.maxWidth < 440) {
                            return Column(
                              children: [
                                code,
                                const SizedBox(height: 16),
                                symbol,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: code),
                              const SizedBox(width: 16),
                              Expanded(child: symbol),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      const PulsoLabel('Bandera o enseña'),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _codeController,
                        builder: (context, code, _) => _FlagPicker(
                          bytes: _flagBytes,
                          initialBase64: widget.initialFlagImage,
                          code: code.text,
                          busy: _saving,
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
  }
}

class _FlagPicker extends StatelessWidget {
  const _FlagPicker({
    required this.bytes,
    required this.initialBase64,
    required this.code,
    required this.busy,
    required this.onTap,
  });

  final Uint8List? bytes;
  final String? initialBase64;
  final String code;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    Widget image;
    if (bytes != null) {
      image = FlagBytesImage(bytes: bytes!, fit: BoxFit.contain);
    } else if (initialBase64?.isNotEmpty == true) {
      Uint8List? decoded;
      try {
        decoded = base64Decode(initialBase64!);
      } catch (_) {
        decoded = null;
      }
      image = decoded == null
          ? _FlagFallback(code: code)
          : FlagBytesImage(bytes: decoded, fit: BoxFit.contain);
    } else {
      image = _FlagFallback(code: code);
    }

    return Material(
      color: tokens.raised,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: tokens.line)),
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
                        ? 'Nueva imagen preparada'
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
                    'Selecciona SVG, PNG o JPG. El SVG conserva calidad a cualquier escala.',
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
        ),
      ),
    );
  }
}

class _FlagFallback extends StatelessWidget {
  const _FlagFallback({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Center(
      child: Text(
        code.trim().isEmpty ? '—' : code.trim().toUpperCase(),
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

class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();

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
