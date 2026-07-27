import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../identity/document_type.dart';
import '../utils/cuba_ci.dart';

typedef CubaCiAnalysisChanged = void Function(CubaCiAnalisis analysis);

/// Campo de captura asistida para el CI cubano.
///
/// En modo CI la estructura y la edad son obligatorias. Pasaporte, Otro y los
/// registros heredados sin clasificar conservan el valor como texto.
class CubaCiField extends StatefulWidget {
  const CubaCiField({
    super.key,
    required this.controller,
    required this.referenceDate,
    required this.documentType,
    required this.decoration,
    this.fieldKey,
    this.style,
    this.textInputAction,
    this.enabled = true,
    this.requiredMessage = 'Requerido',
    this.onAnalysisChanged,
  });

  final TextEditingController controller;
  final DateTime referenceDate;
  final DocumentType documentType;
  final InputDecoration decoration;
  final Key? fieldKey;
  final TextStyle? style;
  final TextInputAction? textInputAction;
  final bool enabled;
  final String requiredMessage;
  final CubaCiAnalysisChanged? onAnalysisChanged;

  @override
  State<CubaCiField> createState() => _CubaCiFieldState();
}

class _CubaCiFieldState extends State<CubaCiField> {
  late CubaCiAnalisis _analysis;

  @override
  void initState() {
    super.initState();
    _analysis = _analyze();
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(CubaCiField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChanged);
      widget.controller.addListener(_handleTextChanged);
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.referenceDate != widget.referenceDate ||
        oldWidget.documentType != widget.documentType) {
      _analysis = _analyze();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    super.dispose();
  }

  CubaCiAnalisis _analyze() => analizarCubaCi(
    widget.controller.text,
    fechaReferencia: widget.referenceDate,
  );

  void _handleTextChanged() {
    final next = _analyze();
    if (mounted) setState(() => _analysis = next);
    widget.onAnalysisChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final presentation = _presentation(context, _analysis, widget.documentType);
    return Semantics(
      textField: true,
      label: widget.documentType.label,
      child: TextFormField(
        key: widget.fieldKey,
        controller: widget.controller,
        enabled: widget.enabled,
        textInputAction: widget.textInputAction,
        keyboardType: widget.documentType == DocumentType.cubanCi
            ? TextInputType.number
            : widget.documentType == DocumentType.passport
            ? TextInputType.visiblePassword
            : TextInputType.text,
        textCapitalization: widget.documentType == DocumentType.passport
            ? TextCapitalization.characters
            : TextCapitalization.none,
        autocorrect: false,
        enableSuggestions: false,
        inputFormatters: switch (widget.documentType) {
          DocumentType.cubanCi => [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          DocumentType.passport => [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            const _UpperCaseTextInputFormatter(),
            LengthLimitingTextInputFormatter(9),
          ],
          DocumentType.other || DocumentType.unknown => const [],
        },
        style: widget.style,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return widget.requiredMessage;
          }
          if (widget.documentType == DocumentType.passport &&
              value != restrictDocumentText(value, DocumentType.passport)) {
            return 'Use como máximo 9 caracteres: únicamente A–Z y 0–9.';
          }
          if (!widget.documentType.validatesCubanCi) return null;
          final analysis = analizarCubaCi(
            value,
            fechaReferencia: widget.referenceDate,
          );
          if (analysis.esValido) return null;
          return analysis.errores.isNotEmpty
              ? analysis.errores.first.mensaje
              : 'Complete los 11 dígitos del CI cubano.';
        },
        decoration: widget.decoration.copyWith(
          helperText: presentation.text,
          helperStyle: presentation.style,
          helperMaxLines: 2,
          suffixIcon: presentation.icon,
        ),
      ),
    );
  }
}

_CubaCiPresentation _presentation(
  BuildContext context,
  CubaCiAnalisis analysis,
  DocumentType documentType,
) {
  final colors = Theme.of(context).colorScheme;
  if (documentType == DocumentType.passport) {
    final length = analysis.normalizado.length;
    return _CubaCiPresentation(
      text:
          'Pasaporte ICAO · $length/9 · solo A–Z y 0–9. '
          'Formato compatible; autenticidad no verificada.',
      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
      icon: Icon(
        Icons.travel_explore_outlined,
        color: colors.onSurfaceVariant,
        size: 18,
      ),
    );
  }
  if (documentType == DocumentType.other) {
    return _CubaCiPresentation(
      text: 'Documento extranjero u otro identificador oficial.',
      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
      icon: Icon(
        Icons.badge_outlined,
        color: colors.onSurfaceVariant,
        size: 18,
      ),
    );
  }
  if (documentType == DocumentType.unknown) {
    return _CubaCiPresentation(
      text: 'Documento heredado sin clasificar; se conserva sin bloqueo.',
      style: TextStyle(color: colors.tertiary, fontSize: 11),
      icon: Icon(Icons.help_outline, color: colors.tertiary, size: 18),
    );
  }
  switch (analysis.estado) {
    case CubaCiEstado.vacio:
      return const _CubaCiPresentation();
    case CubaCiEstado.incompleto:
      return _CubaCiPresentation(
        text: _progressText(analysis),
        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
        icon: Icon(
          Icons.info_outline,
          color: colors.onSurfaceVariant,
          size: 18,
        ),
      );
    case CubaCiEstado.invalido:
      return _CubaCiPresentation(
        text:
            'Aviso CI cubano: ${analysis.errores.first.mensaje} '
            'Si no es un CI, selecciona Pasaporte u Otro documento.',
        style: TextStyle(color: colors.tertiary, fontSize: 11),
        icon: Icon(
          Icons.warning_amber_rounded,
          color: colors.tertiary,
          size: 18,
        ),
      );
    case CubaCiEstado.valido:
      final sex = analysis.sexoCodificado == CubaCiSexo.masculino
          ? 'masculino'
          : 'femenino';
      return _CubaCiPresentation(
        text:
            'CI cubano válido · nacimiento ${_dateLabel(analysis.fechaNacimiento!)}'
            ' · ${analysis.edad} años · sexo codificado: $sex.',
        style: TextStyle(color: colors.primary, fontSize: 11),
        icon: Icon(Icons.check_circle_outline, color: colors.primary, size: 18),
      );
  }
}

String _progressText(CubaCiAnalisis analysis) {
  final value = analysis.normalizado;
  if (value.length < 2) return 'Año: escribe sus 2 dígitos.';
  if (value.length < 4) {
    return 'Año ${value.substring(0, 2)} · escribe el mes (01–12).';
  }
  if (value.length < 6) {
    return 'Año ${value.substring(0, 2)} · mes ${value.substring(2, 4)} ✓ '
        '· escribe el día.';
  }
  if (value.length < 7) {
    return 'Fecha ${value.substring(4, 6)}/${value.substring(2, 4)}/'
        '${value.substring(0, 2)} · escribe el dígito del siglo.';
  }
  final date = analysis.fechaNacimiento;
  if (value.length < 10) {
    return 'Nacimiento ${date == null ? 'por confirmar' : _dateLabel(date)}'
        ' · siglo ${analysis.siglo} · completa el número.';
  }
  return 'Nacimiento ${date == null ? 'por confirmar' : _dateLabel(date)}'
      ' · ${analysis.edad ?? '—'} años · completa el dígito 11.';
}

String _dateLabel(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year}';
}

class _CubaCiPresentation {
  const _CubaCiPresentation({this.text, this.style, this.icon});

  final String? text;
  final TextStyle? style;
  final Widget? icon;
}

class _UpperCaseTextInputFormatter extends TextInputFormatter {
  const _UpperCaseTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
