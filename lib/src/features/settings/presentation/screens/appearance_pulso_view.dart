import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/appearance_provider.dart';
import '../../../../core/theme/pulso/pulso_palette_id.dart';
import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../auth/presentation/state/auth_notifier.dart';

String _paletteTagline(PulsoPaletteId id) => switch (id) {
  PulsoPaletteId.clay => 'Piedra cálida y terracota. La identidad más humana.',
  PulsoPaletteId.midnight =>
    'Tinta naval y coral deportivo. La alternativa más enérgica.',
  PulsoPaletteId.ironGold =>
    'Carbón cálido y dorado tostado. Sobria y sin adornos.',
};

/// Ajustes → Apariencia (Fase 2): previsualización de las tres paletas,
/// luminosidad Claro/Oscuro/Sistema y preferencia guardada por usuario
/// (`gymos.ui.<user_id>.*`) con fallback del dispositivo antes del login.
class AppearancePulsoView extends ConsumerWidget {
  const AppearancePulsoView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PulsoThemeScope(
      child: Builder(
        builder: (context) {
          final tokens = PulsoTokens.of(context);
          final preference = ref.watch(appearanceProvider);
          final brightness = preference.resolveBrightness(
            MediaQuery.platformBrightnessOf(context),
          );
          final user = ref.watch(authProvider).value;

          return ColoredBox(
            color: tokens.floor,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 600;
                final padding = compact
                    ? 16.0
                    : constraints.maxWidth < 840
                    ? 24.0
                    : 32.0;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    padding,
                    compact ? 16 : 20,
                    padding,
                    compact ? 18 : 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _AppearanceHeader(),
                          const SizedBox(height: 18),
                          _SectionPanel(
                            label: 'Paleta',
                            description:
                                'Tres identidades completas; el acento dirige la '
                                'acción y los estados nunca dependen de él.',
                            child: LayoutBuilder(
                              builder: (context, panelConstraints) {
                                final horizontal =
                                    panelConstraints.maxWidth >= 720;
                                final cards = [
                                  for (final id in PulsoPaletteId.values)
                                    _PaletteCard(
                                      id: id,
                                      brightness: brightness,
                                      selected: preference.palette == id,
                                      onTap: () => ref
                                          .read(appearanceProvider.notifier)
                                          .setPalette(id),
                                    ),
                                ];
                                if (!horizontal) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (final card in cards) ...[
                                        card,
                                        if (card != cards.last)
                                          const SizedBox(height: 10),
                                      ],
                                    ],
                                  );
                                }
                                return IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (final card in cards) ...[
                                        Expanded(child: card),
                                        if (card != cards.last)
                                          const SizedBox(width: 10),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SectionPanel(
                            label: 'Luminosidad',
                            description:
                                'Claro y Oscuro fijan el modo; Sistema sigue la '
                                'preferencia del equipo.',
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _ModeOption(
                                  icon: Icons.light_mode_outlined,
                                  label: 'Claro',
                                  selected:
                                      preference.themeMode == ThemeMode.light,
                                  onTap: () => ref
                                      .read(appearanceProvider.notifier)
                                      .setThemeMode(ThemeMode.light),
                                ),
                                _ModeOption(
                                  icon: Icons.dark_mode_outlined,
                                  label: 'Oscuro',
                                  selected:
                                      preference.themeMode == ThemeMode.dark,
                                  onTap: () => ref
                                      .read(appearanceProvider.notifier)
                                      .setThemeMode(ThemeMode.dark),
                                ),
                                _ModeOption(
                                  icon: Icons.brightness_auto_outlined,
                                  label: 'Sistema',
                                  selected:
                                      preference.themeMode == ThemeMode.system,
                                  onTap: () => ref
                                      .read(appearanceProvider.notifier)
                                      .setThemeMode(ThemeMode.system),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SectionPanel(
                            label: 'Vista previa',
                            description:
                                'Así se leen los paneles, cifras y estados con '
                                'la combinación elegida.',
                            child: const _LivePreview(),
                          ),
                          const SizedBox(height: 12),
                          _ScopeNote(
                            userLabel: user == null
                                ? null
                                : (user.name.trim().isNotEmpty
                                      ? user.name.trim()
                                      : user.email),
                          ),
                          const SizedBox(height: 16),
                          const _AppearanceFooter(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AppearanceHeader extends StatelessWidget {
  const _AppearanceHeader();

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PulsoLabel('PULSO · AJUSTES'),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            text: 'APARIENCIA',
            children: [
              TextSpan(
                text: '.',
                style: TextStyle(color: tokens.accent),
              ),
            ],
          ),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Elige la paleta y la luminosidad de GymOS. El cambio se aplica al '
          'instante, sin reiniciar.',
          style: TextStyle(color: tokens.muted, fontSize: 14),
        ),
      ],
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.label,
    required this.description,
    required this.child,
  });
  final String label;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PulsoLabel(label),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(color: tokens.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PaletteCard extends StatelessWidget {
  const _PaletteCard({
    required this.id,
    required this.brightness,
    required this.selected,
    required this.onTap,
  });

  final PulsoPaletteId id;
  final Brightness brightness;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    // La tarjeta se pinta con los tokens de SU paleta, en la luminosidad
    // efectiva, para previsualizar sin aplicar.
    final preview = PulsoTokens.resolve(id, brightness);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('pulso-palette-${id.storageValue}'),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? tokens.accent : tokens.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Miniatura: piso, panel, acento y semántica de la paleta.
              Container(
                height: 96,
                color: preview.floor,
                padding: const EdgeInsets.all(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: preview.surface,
                    border: Border.all(color: preview.line),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 42, height: 8, color: preview.accent),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        height: 6,
                        color: preview.chalk.withValues(alpha: 0.85),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 90,
                        height: 6,
                        color: preview.muted.withValues(alpha: 0.7),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            color: preview.success,
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 10,
                            height: 10,
                            color: preview.warning,
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 10,
                            height: 10,
                            color: preview.danger,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                color: selected ? tokens.accentSoft : tokens.surface,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            id.label,
                            style: TextStyle(
                              fontFamily: PulsoFonts.display,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: tokens.chalk,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _paletteTagline(id),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: tokens.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 18,
                      color: selected ? tokens.accent : tokens.muted2,
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

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Material(
      color: selected ? tokens.accentSoft : tokens.surface,
      child: InkWell(
        key: ValueKey('pulso-mode-$label'),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? tokens.accent : tokens.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? tokens.accent : tokens.muted,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? tokens.chalk : tokens.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LivePreview extends StatelessWidget {
  const _LivePreview();

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    Widget chip(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border.all(color: tokens.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 520;
          final figure = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PulsoLabel('Dentro ahora'),
              const SizedBox(height: 4),
              Text(
                '27',
                style: TextStyle(
                  fontFamily: PulsoFonts.display,
                  fontSize: 40,
                  height: 0.95,
                  fontWeight: FontWeight.w800,
                  color: tokens.accent,
                ),
              ),
            ],
          );
          final sample = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'La tipografía del cuerpo se lee así, con alto contraste.',
                style: TextStyle(fontSize: 13, color: tokens.chalk),
              ),
              const SizedBox(height: 4),
              Text(
                '08:00 – 09:30 · IBM Plex Mono para horas e importes',
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 11,
                  color: tokens.chalkDim,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  chip('PERMITIDO', tokens.success),
                  chip('POR VENCER', tokens.warning),
                  chip('BLOQUEADO', tokens.danger),
                ],
              ),
            ],
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [figure, const SizedBox(height: 12), sample],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              figure,
              const SizedBox(width: 24),
              Expanded(child: sample),
            ],
          );
        },
      ),
    );
  }
}

class _ScopeNote extends StatelessWidget {
  const _ScopeNote({required this.userLabel});
  final String? userLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border.all(color: tokens.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.person_pin_outlined, size: 18, color: tokens.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              userLabel == null
                  ? 'La preferencia se guarda en este equipo y se aplicará '
                        'como punto de partida al iniciar sesión.'
                  : 'Se guarda para $userLabel en este equipo, y también como '
                        'preferencia del dispositivo (se usa antes de iniciar '
                        'sesión). Es un ajuste de interfaz: no se sincroniza '
                        'como dato de negocio ni cambia la configuración del '
                        'gimnasio.',
              style: TextStyle(fontSize: 12, color: tokens.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceFooter extends StatelessWidget {
  const _AppearanceFooter();
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Row(
      children: [
        const PulsoSyncStatus(compact: true),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'PULSO · AJUSTES · APARIENCIA',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              color: tokens.muted2,
            ),
          ),
        ),
      ],
    );
  }
}
