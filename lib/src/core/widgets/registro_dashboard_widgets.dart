import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/registro_palette.dart';

/// Láminas compartidas del arquetipo "Parte del día" (dashboards del sistema
/// REGISTRO). Usadas por el dashboard admin y el de recepción. Ver
/// docs/DESIGN_SYSTEM.md § arquetipo Parte del día y docs/registro_dashboard.html.

/// Dato de una "figura" numerada (KPI de dashboard, no tarjeta).
class RegistroFigure {
  final String number;
  final String caption;
  final String value;
  final String note;
  final Color ink; // tinta de datos de la figura
  final double meter; // 0..1, barrita de proporción
  const RegistroFigure({
    required this.number,
    required this.caption,
    required this.value,
    required this.note,
    required this.ink,
    required this.meter,
  });
}

/// Celda de una figura: tick de tinta + caption, numeral gigante y medidor.
class RegistroFigureCell extends StatelessWidget {
  const RegistroFigureCell({super.key, required this.p, required this.figure});
  final RegistroPalette p;
  final RegistroFigure figure;

  @override
  Widget build(BuildContext context) {
    final f = figure;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 9, height: 9, color: f.ink),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  'fig. ${f.number} — ${f.caption}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.fragmentMono(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: p.ink3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              f.value,
              maxLines: 1,
              style: GoogleFonts.archivo(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                height: 1.05,
                color: f.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            f.note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.archivo(fontSize: 12, color: p.ink3),
          ),
          const SizedBox(height: 12),
          Container(
            height: 4,
            color: p.paper2,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: f.meter.clamp(0.0, 1.0),
              child: Container(color: f.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Retícula responsiva de figuras con filete de tinta superior (4 → 2 columnas).
class RegistroFiguresGrid extends StatelessWidget {
  const RegistroFiguresGrid({
    super.key,
    required this.p,
    required this.figures,
  });
  final RegistroPalette p;
  final List<RegistroFigure> figures;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 900 ? 4 : 2;
        final rows = (figures.length / columns).ceil();
        return Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: p.ruleStrong, width: 2)),
          ),
          child: Column(
            children: List.generate(rows, (r) {
              final slice = figures.sublist(
                r * columns,
                math.min((r + 1) * columns, figures.length),
              );
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < slice.length; i++) ...[
                      if (i > 0)
                        VerticalDivider(width: 1, thickness: 1, color: p.rule),
                      Expanded(child: RegistroFigureCell(p: p, figure: slice[i])),
                    ],
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

/// Marco de lámina: "● fig. NN — TÍTULO … nota" con filete de tinta.
class RegistroPlateFrame extends StatelessWidget {
  const RegistroPlateFrame({
    super.key,
    required this.p,
    required this.tick,
    required this.number,
    required this.title,
    required this.note,
    required this.child,
  });

  final RegistroPalette p;
  final Color? tick;
  final String number;
  final String title;
  final String? note;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: p.ruleStrong, width: 2)),
          ),
          child: Row(
            children: [
              if (tick != null) ...[
                Container(width: 9, height: 9, color: tick),
                const SizedBox(width: 8),
              ] else ...[
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    border: Border.all(color: p.ink3, width: 1.5),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                'fig. $number',
                style: GoogleFonts.fragmentMono(fontSize: 10.5, color: p.ink3),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.archivo(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: p.ink2,
                  ),
                ),
              ),
              if (note != null) ...[
                const SizedBox(width: 10),
                Text(
                  note!,
                  style: GoogleFonts.fragmentMono(
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                    color: p.ink3,
                  ),
                ),
              ],
            ],
          ),
        ),
        child,
      ],
    );
  }
}

/// Estado vacío de una lámina (¶ + mensaje).
class RegistroPlateEmpty extends StatelessWidget {
  const RegistroPlateEmpty({super.key, required this.p, required this.message});
  final RegistroPalette p;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Text('¶',
              style: GoogleFonts.archivoBlack(fontSize: 26, color: p.ink4)),
          const SizedBox(height: 6),
          Text(
            message,
            style: GoogleFonts.fragmentMono(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: p.ink3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Curva horaria de barras (asistencia por hora). `buckets`: hora→conteo.
/// La barra pico va en vermellón; al hover muestra su valor.
class RegistroHourlyChart extends StatelessWidget {
  const RegistroHourlyChart({
    super.key,
    required this.p,
    required this.ink,
    required this.buckets,
  });

  final RegistroPalette p;
  final Color ink;
  final Map<int, int> buckets;

  @override
  Widget build(BuildContext context) {
    final hours = buckets.keys.toList()..sort();
    final start = math.max(0, math.min(hours.isEmpty ? 7 : hours.first, 7));
    final end = math.min(23, math.max(hours.isEmpty ? 20 : hours.last, 20));
    final range = [for (int h = start; h <= end; h++) h];
    final maxVal = buckets.values.fold<int>(1, (m, v) => math.max(m, v));
    int? peak;
    var peakCount = 0;
    buckets.forEach((h, c) {
      if (c > peakCount) {
        peak = h;
        peakCount = c;
      }
    });

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: Padding(
            padding: const EdgeInsets.only(top: 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final h in range) ...[
                  Expanded(
                    child: _RegHourBar(
                      p: p,
                      ink: ink,
                      value: buckets[h] ?? 0,
                      fraction: (buckets[h] ?? 0) / maxVal,
                      isPeak: h == peak,
                    ),
                  ),
                  if (h != range.last) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: p.ruleStrong)),
          ),
          child: Row(
            children: [
              for (final h in range) ...[
                Expanded(
                  child: Text(
                    h.toString().padLeft(2, '0'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.fragmentMono(
                      fontSize: 9.5,
                      color: h == peak ? p.verm : p.ink4,
                    ),
                  ),
                ),
                if (h != range.last) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RegHourBar extends StatefulWidget {
  const _RegHourBar({
    required this.p,
    required this.ink,
    required this.value,
    required this.fraction,
    required this.isPeak,
  });

  final RegistroPalette p;
  final Color ink;
  final int value;
  final double fraction;
  final bool isPeak;

  @override
  State<_RegHourBar> createState() => _RegHourBarState();
}

class _RegHourBarState extends State<_RegHourBar> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final showVal = widget.isPeak || _hover;
    final color = widget.isPeak ? widget.p.verm : widget.ink;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (showVal && widget.value > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${widget.value}',
                style: GoogleFonts.fragmentMono(
                  fontSize: 9.5,
                  color: widget.isPeak ? widget.p.verm : widget.p.ink3,
                ),
              ),
            ),
          FractionallySizedBox(
            widthFactor: 1,
            child: Container(
              height: math.max(2, 100 * widget.fraction),
              constraints: const BoxConstraints(maxWidth: 46),
              color: widget.value == 0 ? widget.p.paper2 : color,
            ),
          ),
        ],
      ),
    );
  }
}
