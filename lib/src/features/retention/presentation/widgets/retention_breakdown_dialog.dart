import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/retention_models.dart';

Future<void> showRetentionBreakdownDialog(
  BuildContext context,
  RetentionDashboardModel dashboard,
) => showDialog<void>(
  context: context,
  builder: (_) => RetentionBreakdownDialog(dashboard: dashboard),
);

class RetentionBreakdownDialog extends StatelessWidget {
  const RetentionBreakdownDialog({super.key, required this.dashboard});

  final RetentionDashboardModel dashboard;

  @override
  Widget build(BuildContext context) => PulsoThemeScope(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final tokens = PulsoTokens.of(context);
        return Center(
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              key: const ValueKey('retention-breakdown-dialog'),
              width: (constraints.maxWidth - 24).clamp(330.0, 1060.0),
              height: (constraints.maxHeight - 24).clamp(520.0, 760.0),
              child: PulsoPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(dashboard: dashboard),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, body) {
                          final sideBySide = body.maxWidth >= 780;
                          if (sideBySide) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: _BreakdownSection(
                                      title: 'POR PLAN',
                                      subtitle:
                                          'Ordenado por evidencia madura disponible',
                                      rows: dashboard.breakdowns.plans,
                                      bounded: true,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _BreakdownSection(
                                      title: 'POR ENTRENADOR',
                                      subtitle:
                                          'Atribución vigente al vencimiento',
                                      rows: dashboard.breakdowns.trainers,
                                      bounded: true,
                                      excluded: dashboard
                                          .breakdowns
                                          .unattributedTrainerTotal,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return ListView(
                            padding: const EdgeInsets.all(14),
                            children: [
                              _BreakdownSection(
                                title: 'POR PLAN',
                                subtitle:
                                    'Ordenado por evidencia madura disponible',
                                rows: dashboard.breakdowns.plans,
                              ),
                              const SizedBox(height: 12),
                              _BreakdownSection(
                                title: 'POR ENTRENADOR',
                                subtitle: 'Atribución vigente al vencimiento',
                                rows: dashboard.breakdowns.trainers,
                                excluded: dashboard
                                    .breakdowns
                                    .unattributedTrainerTotal,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: tokens.raised,
                        border: Border(top: BorderSide(color: tokens.line)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Una muestra pequeña describe casos; no prueba que una categoría sea mejor.',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: tokens.muted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          PulsoSecondaryButton(
                            label: 'Cerrar',
                            icon: Icons.close,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.dashboard});

  final RetentionDashboardModel dashboard;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 13),
      color: tokens.raised,
      child: Row(
        children: [
          Container(width: 7, height: 49, color: tokens.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PulsoLabel('CONTROL Y CALIDAD'),
                Text(
                  'LUPA COMPARATIVA.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: PulsoFonts.display,
                    fontSize: 24,
                    height: 0.95,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${dashboard.window.from} — ${dashboard.window.to} · corte ${dashboard.businessDate}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 8.5,
                    color: tokens.muted,
                  ),
                ),
              ],
            ),
          ),
          PulsoIconButton(
            tooltip: 'Cerrar comparación',
            icon: Icons.close,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  const _BreakdownSection({
    required this.title,
    required this.subtitle,
    required this.rows,
    this.bounded = false,
    this.excluded = 0,
  });

  final String title;
  final String subtitle;
  final List<RetentionBreakdownRowModel> rows;
  final bool bounded;
  final int excluded;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final header = Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 10),
      color: tokens.raised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: PulsoFonts.display,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(subtitle, style: TextStyle(fontSize: 9.5, color: tokens.muted)),
          if (excluded > 0) ...[
            const SizedBox(height: 5),
            Text(
              '$excluded caso(s) sin entrenador quedan fuera de esta columna.',
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontSize: 8,
                color: tokens.warning,
              ),
            ),
          ],
        ],
      ),
    );
    final empty = const Padding(
      padding: EdgeInsets.all(22),
      child: PulsoStateView(
        kind: PulsoStateKind.empty,
        message: 'No hay categorías para este alcance.',
      ),
    );
    final items = [
      for (var index = 0; index < rows.length; index++)
        _BreakdownRow(index: index, row: rows[index]),
    ];

    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: bounded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Expanded(
                  child: rows.isEmpty
                      ? empty
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: tokens.line),
                          itemBuilder: (_, index) => items[index],
                        ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                if (rows.isEmpty)
                  empty
                else
                  for (var index = 0; index < items.length; index++) ...[
                    if (index > 0) Divider(height: 1, color: tokens.line),
                    items[index],
                  ],
              ],
            ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.index, required this.row});

  final int index;
  final RetentionBreakdownRowModel row;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final rate = row.retentionRatePct;
    final evidence = row.matureEligible == 0
        ? 'SIN CIERRE'
        : row.matureEligible < 5
        ? 'MUESTRA BAJA'
        : 'N=${row.matureEligible}';
    final color = rate == null ? tokens.muted : tokens.accent;
    return Semantics(
      label: '${row.name}, ${row.retained} de ${row.matureEligible} retenidos',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '${index + 1}'.padLeft(2, '0'),
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 9,
                    color: tokens.muted,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: tokens.chalk,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  color: tokens.floor,
                  child: Text(
                    evidence,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 7,
                      color: row.matureEligible < 5
                          ? tokens.warning
                          : tokens.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  rate == null ? '—' : '${NumberFormat('0.#').format(rate)}%',
                  style: TextStyle(
                    fontFamily: PulsoFonts.display,
                    fontSize: 19,
                    height: 0.9,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            LinearProgressIndicator(
              value: rate == null ? 0 : (rate / 100).clamp(0, 1),
              minHeight: 3,
              color: color,
              backgroundColor: tokens.line,
            ),
            const SizedBox(height: 7),
            Text(
              '${row.retained}/${row.matureEligible} retenidos · ${row.renewedOnTime} puntuales · ${row.renewedInGrace} en gracia',
              style: TextStyle(fontSize: 9.5, color: tokens.chalkDim),
            ),
            const SizedBox(height: 2),
            Text(
              '${row.historicalExits} salidas · ${row.recovered} recuperados · ${row.openCases} abiertos · ${row.totalDue} vencimientos',
              style: TextStyle(fontSize: 8.8, color: tokens.muted),
            ),
          ],
        ),
      ),
    );
  }
}
