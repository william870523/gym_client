import 'package:flutter/material.dart';

import 'pulso_palette_id.dart';

@immutable
class PulsoTokens extends ThemeExtension<PulsoTokens> {
  const PulsoTokens({
    required this.palette,
    required this.brightness,
    required this.floor,
    required this.floor2,
    required this.surface,
    required this.raised,
    required this.raised2,
    required this.line,
    required this.lineStrong,
    required this.chalk,
    required this.chalkDim,
    required this.muted,
    required this.muted2,
    required this.accent,
    required this.accentInk,
    required this.success,
    required this.warning,
    required this.danger,
    required this.sync,
  });

  final PulsoPaletteId palette;
  final Brightness brightness;
  final Color floor;
  final Color floor2;
  final Color surface;
  final Color raised;
  final Color raised2;
  final Color line;
  final Color lineStrong;
  final Color chalk;
  final Color chalkDim;
  final Color muted;
  final Color muted2;
  final Color accent;
  final Color accentInk;
  final Color success;
  final Color warning;
  final Color danger;
  final Color sync;

  bool get isDark => brightness == Brightness.dark;

  Color get accentSoft => accent.withValues(alpha: isDark ? 0.12 : 0.10);
  Color get accentSoftStrong => accent.withValues(alpha: isDark ? 0.20 : 0.17);
  Color get accentBorder => accent.withValues(alpha: isDark ? 0.52 : 0.42);
  Color get successSoft => success.withValues(alpha: isDark ? 0.12 : 0.10);
  Color get warningSoft => warning.withValues(alpha: isDark ? 0.12 : 0.10);
  Color get dangerSoft => danger.withValues(alpha: isDark ? 0.10 : 0.08);

  List<BoxShadow> get panelShadow => isDark
      ? const []
      : [
          BoxShadow(
            color: chalk.withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ];

  static PulsoTokens of(BuildContext context) {
    final tokens = Theme.of(context).extension<PulsoTokens>();
    assert(tokens != null, 'PulsoThemeScope is missing above this widget.');
    return tokens!;
  }

  static PulsoTokens resolve(PulsoPaletteId palette, Brightness brightness) {
    return switch ((palette, brightness)) {
      (PulsoPaletteId.clay, Brightness.light) => clayLight,
      (PulsoPaletteId.clay, Brightness.dark) => clayDark,
      (PulsoPaletteId.midnight, Brightness.light) => midnightLight,
      (PulsoPaletteId.midnight, Brightness.dark) => midnightDark,
      (PulsoPaletteId.ironGold, Brightness.light) => ironGoldLight,
      (PulsoPaletteId.ironGold, Brightness.dark) => ironGoldDark,
    };
  }

  static const clayLight = PulsoTokens(
    palette: PulsoPaletteId.clay,
    brightness: Brightness.light,
    floor: Color(0xFFF2EEE8),
    floor2: Color(0xFFE8E1D9),
    surface: Color(0xFFFFFDF9),
    raised: Color(0xFFF7F1EA),
    raised2: Color(0xFFEEE4DA),
    line: Color(0xFFD2C4B6),
    lineStrong: Color(0xFF9A8577),
    chalk: Color(0xFF251E1B),
    chalkDim: Color(0xFF514640),
    muted: Color(0xFF6E615A),
    muted2: Color(0xFF75675F),
    accent: Color(0xFFA64831),
    accentInk: Color(0xFFFFF8F1),
    success: Color(0xFF28724F),
    warning: Color(0xFF925A12),
    danger: Color(0xFFA93649),
    sync: Color(0xFFA64831),
  );

  static const clayDark = PulsoTokens(
    palette: PulsoPaletteId.clay,
    brightness: Brightness.dark,
    floor: Color(0xFF171310),
    floor2: Color(0xFF1B1613),
    surface: Color(0xFF211B18),
    raised: Color(0xFF2B231F),
    raised2: Color(0xFF352A25),
    line: Color(0xFF4A3B35),
    lineStrong: Color(0xFF80685E),
    chalk: Color(0xFFF8F0E8),
    chalkDim: Color(0xFFD8C9BE),
    muted: Color(0xFFAA9B90),
    muted2: Color(0xFF95867C),
    accent: Color(0xFFF07A5A),
    accentInk: Color(0xFF26100A),
    success: Color(0xFF69C090),
    warning: Color(0xFFF0B55C),
    danger: Color(0xFFFF7786),
    sync: Color(0xFFF07A5A),
  );

  static const midnightLight = PulsoTokens(
    palette: PulsoPaletteId.midnight,
    brightness: Brightness.light,
    floor: Color(0xFFEDF0F1),
    floor2: Color(0xFFE3E8EA),
    surface: Color(0xFFFBFCFC),
    raised: Color(0xFFF1F4F4),
    raised2: Color(0xFFE5EBED),
    line: Color(0xFFC5CFD2),
    lineStrong: Color(0xFF81959C),
    chalk: Color(0xFF172127),
    chalkDim: Color(0xFF3F5058),
    muted: Color(0xFF5E7078),
    muted2: Color(0xFF5F7078),
    accent: Color(0xFFB9473E),
    accentInk: Color(0xFFFFF8F6),
    success: Color(0xFF287256),
    warning: Color(0xFF8C5A10),
    danger: Color(0xFFA93049),
    sync: Color(0xFF456D79),
  );

  static const midnightDark = PulsoTokens(
    palette: PulsoPaletteId.midnight,
    brightness: Brightness.dark,
    floor: Color(0xFF0B151E),
    floor2: Color(0xFF0E1A24),
    surface: Color(0xFF12212B),
    raised: Color(0xFF192B36),
    raised2: Color(0xFF203945),
    line: Color(0xFF344E58),
    lineStrong: Color(0xFF647D86),
    chalk: Color(0xFFF2F5F3),
    chalkDim: Color(0xFFCCD7D7),
    muted: Color(0xFF9BADB0),
    muted2: Color(0xFF879A9E),
    accent: Color(0xFFFF7B6D),
    accentInk: Color(0xFF2B0C08),
    success: Color(0xFF68C09A),
    warning: Color(0xFFF0B65A),
    danger: Color(0xFFFF7284),
    sync: Color(0xFF8FBCC5),
  );

  static const ironGoldLight = PulsoTokens(
    palette: PulsoPaletteId.ironGold,
    brightness: Brightness.light,
    floor: Color(0xFFF0EEE8),
    floor2: Color(0xFFE7E3DC),
    surface: Color(0xFFFAF9F5),
    raised: Color(0xFFF2EFE8),
    raised2: Color(0xFFE7E1D8),
    line: Color(0xFFC9C1B5),
    lineStrong: Color(0xFF8A8072),
    chalk: Color(0xFF211F1B),
    chalkDim: Color(0xFF49453F),
    muted: Color(0xFF666159),
    muted2: Color(0xFF6F6961),
    accent: Color(0xFF80601B),
    accentInk: Color(0xFFFFF9EC),
    success: Color(0xFF2D7350),
    warning: Color(0xFF925114),
    danger: Color(0xFFAD3E43),
    sync: Color(0xFF715A29),
  );

  static const ironGoldDark = PulsoTokens(
    palette: PulsoPaletteId.ironGold,
    brightness: Brightness.dark,
    floor: Color(0xFF11110F),
    floor2: Color(0xFF161512),
    surface: Color(0xFF1B1A17),
    raised: Color(0xFF25231E),
    raised2: Color(0xFF302C25),
    line: Color(0xFF474036),
    lineStrong: Color(0xFF746A5B),
    chalk: Color(0xFFF4F0E6),
    chalkDim: Color(0xFFD4CDBF),
    muted: Color(0xFFA9A295),
    muted2: Color(0xFF969083),
    accent: Color(0xFFDEB552),
    accentInk: Color(0xFF241A06),
    success: Color(0xFF6BBC8B),
    warning: Color(0xFFE8974C),
    danger: Color(0xFFF8787E),
    sync: Color(0xFFDEB552),
  );

  @override
  PulsoTokens copyWith({
    PulsoPaletteId? palette,
    Brightness? brightness,
    Color? floor,
    Color? floor2,
    Color? surface,
    Color? raised,
    Color? raised2,
    Color? line,
    Color? lineStrong,
    Color? chalk,
    Color? chalkDim,
    Color? muted,
    Color? muted2,
    Color? accent,
    Color? accentInk,
    Color? success,
    Color? warning,
    Color? danger,
    Color? sync,
  }) {
    return PulsoTokens(
      palette: palette ?? this.palette,
      brightness: brightness ?? this.brightness,
      floor: floor ?? this.floor,
      floor2: floor2 ?? this.floor2,
      surface: surface ?? this.surface,
      raised: raised ?? this.raised,
      raised2: raised2 ?? this.raised2,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      chalk: chalk ?? this.chalk,
      chalkDim: chalkDim ?? this.chalkDim,
      muted: muted ?? this.muted,
      muted2: muted2 ?? this.muted2,
      accent: accent ?? this.accent,
      accentInk: accentInk ?? this.accentInk,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      sync: sync ?? this.sync,
    );
  }

  @override
  PulsoTokens lerp(covariant PulsoTokens? other, double t) {
    if (other == null) return this;
    Color blend(Color a, Color b) => Color.lerp(a, b, t)!;
    return PulsoTokens(
      palette: t < 0.5 ? palette : other.palette,
      brightness: t < 0.5 ? brightness : other.brightness,
      floor: blend(floor, other.floor),
      floor2: blend(floor2, other.floor2),
      surface: blend(surface, other.surface),
      raised: blend(raised, other.raised),
      raised2: blend(raised2, other.raised2),
      line: blend(line, other.line),
      lineStrong: blend(lineStrong, other.lineStrong),
      chalk: blend(chalk, other.chalk),
      chalkDim: blend(chalkDim, other.chalkDim),
      muted: blend(muted, other.muted),
      muted2: blend(muted2, other.muted2),
      accent: blend(accent, other.accent),
      accentInk: blend(accentInk, other.accentInk),
      success: blend(success, other.success),
      warning: blend(warning, other.warning),
      danger: blend(danger, other.danger),
      sync: blend(sync, other.sync),
    );
  }
}
