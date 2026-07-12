import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/registro_palette.dart';

/// Componentes compartidos del sistema de diseño "REGISTRO".
/// Ver docs/DESIGN_SYSTEM.md y la vista de referencia
/// currencies_apple_view.dart (F-03 · Monedas).

/// Estilo de encabezado de columna (versalitas).
TextStyle registroThStyle(RegistroPalette p) => GoogleFonts.archivo(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.9,
      color: p.ink2,
    );

/// Acorta un ID largo: `cur_4f8a…c2e1`.
String registroShortId(String id) {
  if (id.length <= 8) return id;
  return '${id.substring(0, 4)}…${id.substring(id.length - 4)}';
}

/// Membrete del documento: filete de tinta 3px, marca y nº de formulario.
class RegistroMasthead extends StatelessWidget {
  const RegistroMasthead({
    super.key,
    required this.p,
    required this.department,
    required this.code,
  });

  final RegistroPalette p;

  /// Sección del membrete, p. ej. 'FINANZAS' → "GYM·OS — FINANZAS".
  final String department;

  /// Nº de formulario, p. ej. 'F-05 / TIPOS DE CAMBIO · REV. 2026'.
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.ruleStrong, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'GYM'),
                TextSpan(text: '·', style: TextStyle(color: p.verm)),
                TextSpan(text: 'OS — $department'),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.archivo(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.4,
                color: p.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              code,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.fragmentMono(fontSize: 11, color: p.ink3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Acción tipográfica del título ("↻ ACTUALIZAR", "＋ NUEVA MONEDA").
class RegistroTextAction extends StatefulWidget {
  const RegistroTextAction({
    super.key,
    required this.p,
    required this.label,
    required this.onTap,
    this.prime = false,
  });
  final RegistroPalette p;
  final String label;
  final VoidCallback onTap;
  final bool prime;

  @override
  State<RegistroTextAction> createState() => _RegistroTextActionState();
}

class _RegistroTextActionState extends State<RegistroTextAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final color = widget.prime ? p.verm : (_hover ? p.ink : p.ink2);
    final underline =
        _hover ? (widget.prime ? p.verm : p.ruleStrong) : Colors.transparent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.only(bottom: 5),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: underline, width: 2)),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.archivo(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pestaña de filtro subrayada ("TODAS 40", "FILTROS ¶").
class RegistroTab extends StatefulWidget {
  const RegistroTab({
    super.key,
    required this.p,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });
  final RegistroPalette p;
  final String label;
  final int? count;
  final bool active;
  final VoidCallback onTap;

  @override
  State<RegistroTab> createState() => _RegistroTabState();
}

class _RegistroTabState extends State<RegistroTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final color = widget.active ? p.verm : (_hover ? p.ink : p.ink3);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.only(bottom: 7),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.active ? p.verm : Colors.transparent,
                width: 1.5,
              ),
            ),
          ),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                text: widget.label,
                style: GoogleFonts.archivo(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: color,
                ),
              ),
              if (widget.count != null)
                TextSpan(
                  text: '  ${widget.count}',
                  style: GoogleFonts.fragmentMono(
                    fontSize: 10.5,
                    color: color,
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Encabezado de columna ordenable con flecha vermellón.
class RegistroSortHead extends StatefulWidget {
  const RegistroSortHead({
    super.key,
    required this.p,
    required this.label,
    required this.active,
    required this.asc,
    required this.onTap,
    this.alignRight = false,
  });
  final RegistroPalette p;
  final String label;
  final bool active;
  final bool asc;
  final VoidCallback onTap;
  final bool alignRight;

  @override
  State<RegistroSortHead> createState() => _RegistroSortHeadState();
}

class _RegistroSortHeadState extends State<RegistroSortHead> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final style = registroThStyle(p).copyWith(color: _hover ? p.verm : p.ink2);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: widget.alignRight
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              Text(widget.label, style: style),
              const SizedBox(width: 5),
              if (widget.active)
                Transform.rotate(
                  angle: widget.asc ? 0 : 3.14159,
                  child: Text(
                    '▲',
                    style: TextStyle(fontSize: 8, color: p.verm),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila clave–valor con puntos conductores, como un índice impreso.
class RegistroKvLeader extends StatelessWidget {
  const RegistroKvLeader({
    super.key,
    required this.p,
    required this.k,
    required this.v,
    this.mono = false,
  });
  final RegistroPalette p;
  final String k;
  final String v;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            k,
            style: GoogleFonts.archivo(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: p.ink3,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: RegistroDottedLine(color: p.ink4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            v,
            style: mono
                ? GoogleFonts.fragmentMono(fontSize: 12, color: p.ink)
                : GoogleFonts.archivo(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Línea de puntos conductores.
class RegistroDottedLine extends StatelessWidget {
  const RegistroDottedLine({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1.5,
      child: CustomPaint(
        painter: _DotsPainter(color),
        size: const Size(double.infinity, 1.5),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const gap = 4.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawCircle(Offset(x, size.height / 2), 0.7, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => oldDelegate.color != color;
}

/// Enlace de la marginalia ("EDITAR DIVISA →").
class RegistroMarginAction extends StatefulWidget {
  const RegistroMarginAction({
    super.key,
    required this.p,
    required this.label,
    required this.onTap,
  });
  final RegistroPalette p;
  final String label;
  final VoidCallback onTap;

  @override
  State<RegistroMarginAction> createState() => _RegistroMarginActionState();
}

class _RegistroMarginActionState extends State<RegistroMarginAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
              text: widget.label,
              style: GoogleFonts.archivo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: _hover ? p.verm : p.ink2,
              ),
            ),
            TextSpan(
              text: ' →',
              style: GoogleFonts.archivo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: p.verm,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Acción de fila en versalitas ("EDITAR", "ELIMINAR").
class RegistroRowTextAction extends StatefulWidget {
  const RegistroRowTextAction({
    super.key,
    required this.p,
    required this.label,
    required this.onTap,
    this.danger = false,
  });
  final RegistroPalette p;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<RegistroRowTextAction> createState() => _RegistroRowTextActionState();
}

class _RegistroRowTextActionState extends State<RegistroRowTextAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final color = _hover ? (widget.danger ? p.verm : p.ink) : p.ink3;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: GoogleFonts.archivo(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
            color: color,
            decoration: _hover ? TextDecoration.underline : null,
            decorationColor: color,
          ),
        ),
      ),
    );
  }
}

/// Bloque de carga: "componiendo el registro…".
class RegistroLoadingBlock extends StatelessWidget {
  const RegistroLoadingBlock({super.key, required this.p});
  final RegistroPalette p;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: p.ruleStrong, width: 2),
          bottom: BorderSide(color: p.rule),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: p.verm,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'componiendo el registro…',
              style: GoogleFonts.fragmentMono(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: p.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado vacío con el signo ¶.
class RegistroEmptyBlock extends StatelessWidget {
  const RegistroEmptyBlock({super.key, required this.p, required this.message});
  final RegistroPalette p;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.rule)),
      ),
      child: Column(
        children: [
          Text(
            '¶',
            style: GoogleFonts.archivoBlack(fontSize: 40, color: p.ink4),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.archivo(fontSize: 13, color: p.ink2),
          ),
        ],
      ),
    );
  }
}

/// Bloque de filas de tabla con altura acotada y scroll interno propio.
///
/// Con listas cortas mide lo justo (`shrinkWrap`); si el contenido supera la
/// altura máxima, se recorta y aparece scrollbar, dejando encabezado y colofón
/// de la tabla siempre visibles — la página no crece con la tabla (NORMA del
/// sistema, ver docs/DESIGN_SYSTEM.md § Tablas con scroll propio).
///
/// Si no se pasa [maxHeight], la altura se **auto-ajusta al alto de la
/// pantalla** (≈56% del viewport, acotado), para que la tabla aproveche la
/// ventana disponible sin empujar los controles fuera de vista.
class RegistroScrollableRows extends StatefulWidget {
  const RegistroScrollableRows({
    super.key,
    required this.p,
    required this.itemCount,
    required this.itemBuilder,
    this.maxHeight,
  });

  final RegistroPalette p;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Alto máximo fijo. Si es `null`, se calcula desde el alto de la pantalla.
  final double? maxHeight;

  @override
  State<RegistroScrollableRows> createState() => _RegistroScrollableRowsState();
}

class _RegistroScrollableRowsState extends State<RegistroScrollableRows> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedMaxHeight = widget.maxHeight ??
        (MediaQuery.sizeOf(context).height * 0.56).clamp(280.0, 680.0);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: resolvedMaxHeight),
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: ListView.separated(
          controller: _controller,
          primary: false,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: widget.itemCount,
          separatorBuilder: (_, _) =>
              Divider(height: 1, thickness: 1, color: widget.p.rule),
          itemBuilder: widget.itemBuilder,
        ),
      ),
    );
  }
}

/// Diálogo de confirmación de borrado — estilo impreso.
/// Devuelve `true` si el usuario confirma.
class RegistroDeleteDialog extends StatelessWidget {
  const RegistroDeleteDialog({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  static Future<bool?> show(
    BuildContext context, {
    String title = 'ELIMINAR ASIENTO',
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => RegistroDeleteDialog(title: title, message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = RegistroPalette.fromContext(context);
    return AlertDialog(
      backgroundColor: p.paper,
      shape: Border(top: BorderSide(color: p.verm, width: 3)),
      title: Text(
        title,
        style: GoogleFonts.archivo(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
          color: p.ink,
        ),
      ),
      content: Text(
        message,
        style: GoogleFonts.archivo(fontSize: 14, color: p.ink2),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'CANCELAR',
            style: GoogleFonts.archivo(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
              color: p.ink2,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: p.verm,
            shape: const RoundedRectangleBorder(),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'ELIMINAR',
            style: GoogleFonts.archivo(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Acción tipográfica para diálogos ("CANCELAR", "GUARDAR CAMBIOS").
/// Con `onTap == null` se muestra deshabilitada.
class RegistroDialogTextAction extends StatefulWidget {
  const RegistroDialogTextAction({
    super.key,
    required this.p,
    required this.label,
    required this.onTap,
    this.prime = false,
  });

  final RegistroPalette p;
  final String label;
  final VoidCallback? onTap;
  final bool prime;

  @override
  State<RegistroDialogTextAction> createState() =>
      _RegistroDialogTextActionState();
}

class _RegistroDialogTextActionState extends State<RegistroDialogTextAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final baseColor = widget.prime ? widget.p.verm : widget.p.ink2;
    final color = enabled
        ? (_hover && !widget.prime ? widget.p.ink : baseColor)
        : widget.p.ink4;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      onEnter: enabled ? (_) => setState(() => _hover = true) : null,
      onExit: enabled ? (_) => setState(() => _hover = false) : null,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.only(bottom: 5),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _hover && enabled ? color : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.archivo(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Regla de sección de formulario: "01 IDENTIFICACIÓN" sobre filete de tinta.
class RegistroSectionRule extends StatelessWidget {
  const RegistroSectionRule({
    super.key,
    required this.p,
    required this.number,
    required this.label,
  });

  final RegistroPalette p;
  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.ruleStrong, width: 2)),
      ),
      child: Row(
        children: [
          Text(
            number,
            style: GoogleFonts.fragmentMono(fontSize: 10.5, color: p.verm),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.archivo(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.7,
              color: p.ink2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de formulario subrayado con etiqueta en versalitas y daga (†)
/// para obligatorios.
class RegistroFormField extends StatelessWidget {
  const RegistroFormField({
    super.key,
    required this.p,
    required this.label,
    required this.hint,
    required this.controller,
    this.requiredField = false,
    this.monospace = false,
    this.maxLength,
    this.readOnly = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.inputFormatters,
    this.onFieldSubmitted,
    this.onTap,
    this.validator,
    this.suffix,
  });

  final RegistroPalette p;
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool requiredField;
  final bool monospace;
  final int? maxLength;
  final bool readOnly;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onFieldSubmitted;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (requiredField)
                TextSpan(
                  text: '  †',
                  style: TextStyle(color: p.verm),
                ),
            ],
          ),
          style: GoogleFonts.archivo(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: p.ink3,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          maxLength: maxLength,
          readOnly: readOnly,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          onFieldSubmitted: onFieldSubmitted,
          onTap: onTap,
          cursorColor: p.verm,
          style: monospace
              ? GoogleFonts.fragmentMono(fontSize: 16, color: p.ink)
              : GoogleFonts.archivo(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: p.ink,
                ),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            counterText: '',
            suffixIcon: suffix,
            suffixIconConstraints:
                const BoxConstraints(minWidth: 28, minHeight: 20),
            hintStyle: monospace
                ? GoogleFonts.fragmentMono(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: p.ink4,
                  )
                : GoogleFonts.archivo(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: p.ink4,
                  ),
            contentPadding: const EdgeInsets.only(bottom: 9),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: p.ruleStrong, width: 1.2),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: p.ruleStrong, width: 1.2),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: p.verm, width: 2),
            ),
            errorBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: p.verm, width: 1.2),
            ),
            focusedErrorBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: p.verm, width: 2),
            ),
            errorStyle: GoogleFonts.fragmentMono(fontSize: 10, color: p.verm),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

/// Bloque de error: barra vermellón + mensaje en mono.
class RegistroErrorBlock extends StatelessWidget {
  const RegistroErrorBlock({
    super.key,
    required this.p,
    required this.message,
  });
  final RegistroPalette p;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: p.verm, width: 3)),
        color: p.vermSoft,
      ),
      child: Text(
        message,
        style: GoogleFonts.fragmentMono(fontSize: 12, color: p.verm),
      ),
    );
  }
}

/// Fila con puntos conductores para notas marginales y fichas impresas.
class RegistroDotLeader extends StatelessWidget {
  const RegistroDotLeader({
    super.key,
    required this.p,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final RegistroPalette p;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: GoogleFonts.archivo(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: p.ink3,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: RegistroDottedLine(color: p.ink4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.fragmentMono(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor ?? p.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de búsqueda estándar del sistema de diseño REGISTRO.
class RegistroSearchBar extends StatefulWidget {
  const RegistroSearchBar({
    super.key,
    required this.p,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  final RegistroPalette p;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<RegistroSearchBar> createState() => _RegistroSearchBarState();
}

class _RegistroSearchBarState extends State<RegistroSearchBar> {
  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final focused = widget.focusNode.hasFocus;
    final hasText = widget.controller.text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: focused ? p.verm : p.ruleStrong,
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'BUSCAR',
            style: GoogleFonts.archivo(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: focused ? p.verm : p.ink3,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              onChanged: widget.onChanged,
              style: GoogleFonts.archivo(fontSize: 15, color: p.ink),
              cursorColor: p.verm,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: widget.hintText,
                hintStyle: GoogleFonts.archivo(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: p.ink4,
                ),
              ),
            ),
          ),
          if (hasText)
            GestureDetector(
              onTap: widget.onClear,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  '✕',
                  style: GoogleFonts.archivo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.verm,
                  ),
                ),
              ),
            )
          else
            Text(
              'CTRL K',
              style: GoogleFonts.fragmentMono(fontSize: 10, color: p.ink4),
            ),
        ],
      ),
    );
  }
}

