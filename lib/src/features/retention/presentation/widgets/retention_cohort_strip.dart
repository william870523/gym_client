import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/retention_models.dart';

class RetentionCohortStrip extends StatelessWidget {
  const RetentionCohortStrip({
    super.key,
    required this.cohorts,
    this.compact = false,
  });

  final List<RetentionCohortModel> cohorts;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final visible = cohorts.length <= 6
        ? cohorts
        : cohorts.sublist(cohorts.length - 6);
    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 9, 12, 8),
            color: tokens.raised,
            child: Row(
              children: [
                const PulsoLabel('Comparación por cohortes'),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'solo meses maduros son comparables',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 8,
                      color: tokens.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: compact ? 82 : 112,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: compact ? 6 : 9,
              ),
              scrollDirection: Axis.horizontal,
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) =>
                  _CohortCell(cohort: visible[index], compact: compact),
            ),
          ),
        ],
      ),
    );
  }
}

class _CohortCell extends StatelessWidget {
  const _CohortCell({required this.cohort, required this.compact});

  final RetentionCohortModel cohort;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final rate = cohort.retentionRatePct;
    final color = cohort.provisional
        ? tokens.muted
        : rate == null
        ? tokens.sync
        : rate >= 75
        ? tokens.success
        : rate >= 50
        ? tokens.warning
        : tokens.danger;
    final change = cohort.retentionChangePp;
    return Container(
      width: 172,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _month(cohort.month).toUpperCase(),
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 8.5,
                    color: tokens.muted,
                  ),
                ),
              ),
              Text(
                cohort.provisional ? 'ABIERTO' : 'CERRADO',
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 7,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rate == null ? '—' : '${NumberFormat('0.#').format(rate)}%',
                style: TextStyle(
                  fontFamily: PulsoFonts.display,
                  fontSize: 22,
                  height: 0.9,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const Spacer(),
              if (change != null)
                Text(
                  '${change > 0 ? '+' : ''}${NumberFormat('0.#').format(change)} pp',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 8,
                    color: change >= 0 ? tokens.success : tokens.danger,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRect(
            child: LinearProgressIndicator(
              value: rate == null ? 0 : (rate / 100).clamp(0, 1),
              minHeight: 3,
              color: color,
              backgroundColor: tokens.line,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 4),
            Text(
              '${cohort.matureEligible} maduros · ${cohort.retained} retenidos · ${cohort.historicalExits} salidas',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 8.5, color: tokens.muted),
            ),
          ],
        ],
      ),
    );
  }
}

String _month(String value) {
  final date = DateTime.tryParse('$value-01T00:00:00Z');
  if (date == null) return value;
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${months[date.month - 1]} ${date.year}';
}
