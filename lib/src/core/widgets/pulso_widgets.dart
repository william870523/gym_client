import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/sync_status_provider.dart';
import '../theme/pulso/appearance_provider.dart';
import '../theme/pulso/pulso_palette_id.dart';
import '../theme/pulso/pulso_theme.dart';
import '../theme/pulso/pulso_tokens.dart';
import 'base64_image.dart';

class PulsoPanel extends StatelessWidget {
  const PulsoPanel({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? tokens.surface,
        border: Border(
          top: BorderSide(
            color: tokens.isDark
                ? tokens.chalk.withValues(alpha: 0.08)
                : borderColor ?? tokens.line,
          ),
          right: BorderSide(color: borderColor ?? tokens.line),
          bottom: BorderSide(color: borderColor ?? tokens.line),
          left: BorderSide(color: borderColor ?? tokens.line),
        ),
        boxShadow: tokens.panelShadow,
      ),
      child: child,
    );
  }
}

class PulsoLabel extends StatelessWidget {
  const PulsoLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: PulsoFonts.mono,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
        color: color ?? tokens.muted,
      ),
    );
  }
}

class PulsoPrimaryButton extends StatelessWidget {
  const PulsoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final child = busy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: tokens.accentInk,
            ),
          )
        : Text(label.toUpperCase());

    final style = FilledButton.styleFrom(
      minimumSize: const Size(44, 48),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      backgroundColor: tokens.accent,
      foregroundColor: tokens.accentInk,
      disabledBackgroundColor: tokens.raised2,
      disabledForegroundColor: tokens.muted,
      elevation: 0,
      textStyle: const TextStyle(
        fontFamily: PulsoFonts.display,
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
      shape: const BeveledRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
      ),
    );

    if (icon == null || busy) {
      return FilledButton(
        onPressed: busy ? null : onPressed,
        style: style,
        child: child,
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: 19),
      label: child,
    );
  }
}

class PulsoSecondaryButton extends StatelessWidget {
  const PulsoSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final foreground = danger ? tokens.danger : tokens.chalkDim;
    final side = danger ? tokens.danger : tokens.lineStrong;
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      foregroundColor: foreground,
      side: BorderSide(color: side),
      textStyle: const TextStyle(
        fontFamily: PulsoFonts.display,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    );
    if (icon == null) {
      return OutlinedButton(
        onPressed: onPressed,
        style: style,
        child: Text(label.toUpperCase()),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: 17),
      label: Text(label.toUpperCase()),
    );
  }
}

class PulsoIconButton extends StatelessWidget {
  const PulsoIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        foregroundColor: danger ? tokens.danger : tokens.chalkDim,
        side: BorderSide(color: tokens.line),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }
}

class PulsoSyncStatus extends ConsumerWidget {
  const PulsoSyncStatus({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    final status =
        ref.watch(syncStatusProvider).value ?? SyncStatusSnapshot.checking();
    final (color, icon) = switch (status.level) {
      SyncStatusLevel.checking => (tokens.sync, Icons.sync),
      SyncStatusLevel.synced => (tokens.success, Icons.cloud_done_outlined),
      SyncStatusLevel.pending => (tokens.warning, Icons.cloud_sync_outlined),
      SyncStatusLevel.offline => (tokens.danger, Icons.cloud_off_outlined),
    };
    final label = switch (status.level) {
      SyncStatusLevel.checking => 'Verificando',
      SyncStatusLevel.synced => 'Sincronizado',
      SyncStatusLevel.pending =>
        status.pendingEvents > 0
            ? '${status.pendingEvents} pendientes'
            : 'Pendiente',
      SyncStatusLevel.offline => 'Modo local',
    };

    return Tooltip(
      message: '${status.label} · ${status.detail}\nPulsa para verificar ahora',
      child: Semantics(
        button: true,
        label: 'Sincronización: $label. ${status.detail}',
        child: Material(
          color: color.withValues(alpha: tokens.isDark ? 0.11 : 0.08),
          child: InkWell(
            onTap: () => ref.invalidate(syncStatusProvider),
            child: Container(
              constraints: const BoxConstraints(minHeight: 34),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 9 : 11,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: color.withValues(alpha: 0.48)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 7, height: 7, color: color),
                  const SizedBox(width: 7),
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.45,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PulsoAppearanceMenuButton extends ConsumerWidget {
  const PulsoAppearanceMenuButton({
    super.key,
    this.compact = true,
    this.tooltip = 'Apariencia de GymOS',
  });

  final bool compact;
  final String tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    final preference = ref.watch(appearanceProvider);
    final notifier = ref.read(appearanceProvider.notifier);

    return PopupMenuButton<String>(
      tooltip: tooltip,
      color: tokens.surface,
      surfaceTintColor: Colors.transparent,
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value.startsWith('palette:')) {
          final stored = value.substring('palette:'.length);
          notifier.setPalette(PulsoPaletteId.fromStorage(stored));
          return;
        }
        final mode = switch (value) {
          'mode:dark' => ThemeMode.dark,
          'mode:system' => ThemeMode.system,
          _ => ThemeMode.light,
        };
        notifier.setThemeMode(mode);
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          height: 34,
          child: PulsoLabel('Paleta'),
        ),
        for (final palette in PulsoPaletteId.values)
          PopupMenuItem<String>(
            value: 'palette:${palette.storageValue}',
            child: _AppearanceMenuRow(
              label: palette.label,
              selected: preference.palette == palette,
              swatch: PulsoTokens.resolve(palette, tokens.brightness).accent,
            ),
          ),
        PopupMenuItem<String>(
          enabled: false,
          height: 34,
          child: PulsoLabel('Luminosidad'),
        ),
        _modeItem(
          value: 'mode:light',
          label: 'Claro',
          icon: Icons.light_mode_outlined,
          selected: preference.themeMode == ThemeMode.light,
        ),
        _modeItem(
          value: 'mode:dark',
          label: 'Oscuro',
          icon: Icons.dark_mode_outlined,
          selected: preference.themeMode == ThemeMode.dark,
        ),
        _modeItem(
          value: 'mode:system',
          label: 'Sistema',
          icon: Icons.brightness_auto_outlined,
          selected: preference.themeMode == ThemeMode.system,
        ),
      ],
      child: Semantics(
        button: true,
        label:
            '$tooltip. ${preference.palette.label}, ${preference.themeMode.name}',
        child: Container(
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 13),
          decoration: BoxDecoration(
            color: tokens.raised,
            border: Border.all(color: tokens.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.palette_outlined, size: 18, color: tokens.accent),
              if (!compact) ...[
                const SizedBox(width: 8),
                Text(
                  preference.palette.label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: tokens.chalkDim,
                  ),
                ),
              ],
              const SizedBox(width: 5),
              Icon(Icons.arrow_drop_down, size: 16, color: tokens.muted),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _modeItem({
    required String value,
    required String label,
    required IconData icon,
    required bool selected,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: _AppearanceMenuRow(label: label, selected: selected, icon: icon),
    );
  }
}

class _AppearanceMenuRow extends StatelessWidget {
  const _AppearanceMenuRow({
    required this.label,
    required this.selected,
    this.swatch,
    this.icon,
  });

  final String label;
  final bool selected;
  final Color? swatch;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Row(
      children: [
        if (swatch != null)
          Container(width: 12, height: 12, color: swatch)
        else
          Icon(icon, size: 17, color: tokens.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: tokens.chalk,
            ),
          ),
        ),
        if (selected) Icon(Icons.check, size: 17, color: tokens.accent),
      ],
    );
  }
}

class PulsoAppearanceBar extends ConsumerWidget {
  const PulsoAppearanceBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    final preference = ref.watch(appearanceProvider);
    final notifier = ref.read(appearanceProvider.notifier);
    final brightness = preference.resolveBrightness(
      MediaQuery.platformBrightnessOf(context),
    );

    return PulsoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: tokens.floor2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final paletteChoices = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final palette in PulsoPaletteId.values)
                _AppearanceChoice(
                  label: palette.label,
                  selected: preference.palette == palette,
                  swatch: PulsoTokens.resolve(palette, brightness).accent,
                  onTap: () => notifier.setPalette(palette),
                ),
            ],
          );
          final modeChoices = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _AppearanceChoice(
                label: 'Claro',
                selected: preference.themeMode == ThemeMode.light,
                icon: Icons.light_mode_outlined,
                onTap: () => notifier.setThemeMode(ThemeMode.light),
              ),
              _AppearanceChoice(
                label: 'Oscuro',
                selected: preference.themeMode == ThemeMode.dark,
                icon: Icons.dark_mode_outlined,
                onTap: () => notifier.setThemeMode(ThemeMode.dark),
              ),
              _AppearanceChoice(
                label: 'Sistema',
                selected: preference.themeMode == ThemeMode.system,
                icon: Icons.brightness_auto_outlined,
                onTap: () => notifier.setThemeMode(ThemeMode.system),
              ),
            ],
          );

          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PulsoLabel('Apariencia de GymOS'),
                const SizedBox(height: 10),
                paletteChoices,
                const SizedBox(height: 8),
                modeChoices,
              ],
            );
          }

          return Row(
            children: [
              const SizedBox(
                width: 154,
                child: PulsoLabel('Apariencia de GymOS'),
              ),
              Expanded(child: paletteChoices),
              const SizedBox(width: 12),
              modeChoices,
            ],
          );
        },
      ),
    );
  }
}

class _AppearanceChoice extends StatelessWidget {
  const _AppearanceChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.swatch,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? swatch;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? tokens.accentSoft : tokens.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: selected ? tokens.accent : tokens.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (swatch != null) ...[
                  Container(width: 10, height: 10, color: swatch),
                  const SizedBox(width: 7),
                ],
                if (icon != null) ...[
                  Icon(icon, size: 15, color: tokens.muted),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? tokens.chalk : tokens.muted,
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

class PulsoFlag extends StatelessWidget {
  const PulsoFlag({
    super.key,
    required this.code,
    this.base64String,
    this.width = 42,
    this.height = 28,
  }) : assert(width > height);

  final String code;
  final String? base64String;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final fallback = Center(
      child: Text(
        code.length > 2 ? code.substring(0, 2).toUpperCase() : code,
        style: TextStyle(
          fontFamily: PulsoFonts.mono,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: tokens.muted,
        ),
      ),
    );
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border.all(color: tokens.line),
      ),
      child: base64String?.isNotEmpty == true
          ? Base64Image(
              base64String: base64String!,
              width: width,
              height: height,
              fit: BoxFit.contain,
              placeholder: fallback,
            )
          : fallback,
    );
  }
}

enum PulsoStateKind { loading, empty, error }

class PulsoStateView extends StatelessWidget {
  const PulsoStateView({
    super.key,
    required this.kind,
    required this.message,
    this.onRetry,
  });

  final PulsoStateKind kind;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = kind == PulsoStateKind.error ? tokens.danger : tokens.muted;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kind == PulsoStateKind.loading)
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tokens.accent,
                ),
              )
            else
              Icon(
                kind == PulsoStateKind.error
                    ? Icons.error_outline
                    : Icons.inventory_2_outlined,
                size: 30,
                color: color,
              ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              PulsoSecondaryButton(label: 'Reintentar', onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}

class PulsoMetricData {
  const PulsoMetricData({
    required this.value,
    required this.label,
    required this.note,
    this.emphasis = false,
    this.warning = false,
  });

  final String value;
  final String label;
  final String note;
  final bool emphasis;
  final bool warning;
}

class PulsoMetricStrip extends StatelessWidget {
  const PulsoMetricStrip({super.key, required this.metrics});

  final List<PulsoMetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 840) {
          return SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: metrics.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => SizedBox(
                width: 224,
                child: _PulsoMetric(data: metrics[index]),
              ),
            ),
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < metrics.length; index++) ...[
                Expanded(child: _PulsoMetric(data: metrics[index])),
                if (index != metrics.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PulsoMetric extends StatelessWidget {
  const _PulsoMetric({required this.data});

  final PulsoMetricData data;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final valueColor = data.warning
        ? tokens.warning
        : data.emphasis
        ? tokens.accent
        : tokens.chalk;
    return PulsoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      child: Row(
        children: [
          Text(
            data.value,
            style: TextStyle(
              fontFamily: PulsoFonts.display,
              fontSize: 28,
              height: 1,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tokens.chalkDim,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 9,
                    color: tokens.muted2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
