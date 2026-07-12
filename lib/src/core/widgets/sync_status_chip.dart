import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/sync_status_provider.dart';

class SyncStatusChip extends ConsumerWidget {
  const SyncStatusChip({
    super.key,
    this.compact = false,
    this.showDetails = false,
    this.isDark,
  });

  final bool compact;
  final bool showDetails;
  final bool? isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStatus = ref.watch(syncStatusProvider);
    final status = asyncStatus.value ?? SyncStatusSnapshot.checking();
    final palette = _SyncStatusPalette.from(status.level);
    final dark = isDark ?? Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: _tooltipFor(status),
      child: InkWell(
        onTap: () => ref.invalidate(syncStatusProvider),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 7 : 8,
          ),
          decoration: BoxDecoration(
            color: dark ? palette.darkBackground : palette.lightBackground,
            border: Border.all(
              color: dark ? palette.darkBorder : palette.lightBorder,
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              if (!dark)
                BoxShadow(
                  color: palette.color.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusDot(color: palette.color, pulse: status.isHealthy),
              const SizedBox(width: 8),
              Icon(palette.icon, size: compact ? 14 : 16, color: palette.color),
              if (!compact || showDetails) const SizedBox(width: 7),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 120 : 150),
                child: Text(
                  status.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dark ? palette.darkText : palette.lightText,
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (showDetails) ...[
                Container(
                  height: 14,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: dark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: Text(
                    _detailText(status),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.62)
                          : const Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _detailText(SyncStatusSnapshot status) {
    if (status.level == SyncStatusLevel.synced &&
        status.lastSyncLabel != 'Sin registro') {
      return 'Ult. sinc: ${status.lastSyncLabel}';
    }
    return status.detail;
  }

  String _tooltipFor(SyncStatusSnapshot status) {
    final pending = status.pendingEvents > 0
        ? '\nPendientes: ${status.pendingEvents}'
        : '';
    final lastSync = status.lastSyncLabel != 'Sin registro'
        ? '\nUltima sync: ${status.lastSyncLabel}'
        : '';
    return '${status.label}\n${status.detail}$pending$lastSync\nClick para verificar ahora';
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.pulse});

  final Color color;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      height: 10,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (pulse)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncStatusPalette {
  const _SyncStatusPalette({
    required this.color,
    required this.icon,
    required this.lightBackground,
    required this.darkBackground,
    required this.lightBorder,
    required this.darkBorder,
    required this.lightText,
    required this.darkText,
  });

  factory _SyncStatusPalette.from(SyncStatusLevel level) {
    switch (level) {
      case SyncStatusLevel.checking:
        return const _SyncStatusPalette(
          color: Color(0xFF3B82F6),
          icon: Icons.sync,
          lightBackground: Color(0xFFEFF6FF),
          darkBackground: Color(0x1F3B82F6),
          lightBorder: Color(0xFFBFDBFE),
          darkBorder: Color(0x4D60A5FA),
          lightText: Color(0xFF1D4ED8),
          darkText: Color(0xFFBFDBFE),
        );
      case SyncStatusLevel.synced:
        return const _SyncStatusPalette(
          color: Color(0xFF16A34A),
          icon: Icons.cloud_done_outlined,
          lightBackground: Color(0xFFECFDF5),
          darkBackground: Color(0x1F22C55E),
          lightBorder: Color(0xFFBBF7D0),
          darkBorder: Color(0x4D4ADE80),
          lightText: Color(0xFF166534),
          darkText: Color(0xFFBBF7D0),
        );
      case SyncStatusLevel.pending:
        return const _SyncStatusPalette(
          color: Color(0xFFF59E0B),
          icon: Icons.cloud_sync_outlined,
          lightBackground: Color(0xFFFFFBEB),
          darkBackground: Color(0x24F59E0B),
          lightBorder: Color(0xFFFDE68A),
          darkBorder: Color(0x66FBBF24),
          lightText: Color(0xFF92400E),
          darkText: Color(0xFFFDE68A),
        );
      case SyncStatusLevel.offline:
        return const _SyncStatusPalette(
          color: Color(0xFFEF4444),
          icon: Icons.cloud_off_outlined,
          lightBackground: Color(0xFFFEF2F2),
          darkBackground: Color(0x24EF4444),
          lightBorder: Color(0xFFFECACA),
          darkBorder: Color(0x66F87171),
          lightText: Color(0xFF991B1B),
          darkText: Color(0xFFFECACA),
        );
    }
  }

  final Color color;
  final IconData icon;
  final Color lightBackground;
  final Color darkBackground;
  final Color lightBorder;
  final Color darkBorder;
  final Color lightText;
  final Color darkText;
}
