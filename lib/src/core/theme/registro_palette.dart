import 'package:flutter/material.dart';

/// Paleta del sistema de diseño "REGISTRO" — papel, tinta y vermellón.
///
/// Tokens y reglas en docs/DESIGN_SYSTEM.md. El modo día/noche sigue el
/// brightness global del tema. Un solo acento (vermellón), filetes en vez
/// de cajas, sin bordes redondeados ni sombras.
class RegistroPalette {
  final bool isNight;
  final Color paper;
  final Color paper2;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color ink4;
  final Color rule;
  final Color ruleStrong;
  final Color verm;
  final Color vermSoft;

  const RegistroPalette({
    required this.isNight,
    required this.paper,
    required this.paper2,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.ink4,
    required this.rule,
    required this.ruleStrong,
    required this.verm,
    required this.vermSoft,
  });

  static RegistroPalette of(bool isNight) => isNight ? night : day;

  static RegistroPalette fromContext(BuildContext context) =>
      of(Theme.of(context).brightness == Brightness.dark);

  static const day = RegistroPalette(
    isNight: false,
    paper: Color(0xFFF2EFE8),
    paper2: Color(0xFFECE8DF),
    ink: Color(0xFF1C1A16),
    ink2: Color(0xFF57534B),
    ink3: Color(0xFF8B867B),
    ink4: Color(0xFFBBB5A8),
    rule: Color(0xFFD8D3C6),
    ruleStrong: Color(0xFF1C1A16),
    verm: Color(0xFFD9481C),
    vermSoft: Color(0x12D9481C),
  );

  static const night = RegistroPalette(
    isNight: true,
    paper: Color(0xFF16140F),
    paper2: Color(0xFF1C1913),
    ink: Color(0xFFEFEAE0),
    ink2: Color(0xFFB0AA9C),
    ink3: Color(0xFF7A7568),
    ink4: Color(0xFF4D493F),
    rule: Color(0xFF2E2A22),
    ruleStrong: Color(0xFFEFEAE0),
    verm: Color(0xFFFF6A3D),
    vermSoft: Color(0x17FF6A3D),
  );
}

/// Tintas de datos del sistema REGISTRO — SOLO para visualizaciones
/// (gráficas, figuras, ticks, medidores, leyendas de dashboards).
/// Nunca en chrome de UI. Asignación semántica fija:
/// azul = asistencia/personas · ocre = dinero · verde = socios/positivo ·
/// el vermellón de [RegistroPalette] = alertas/picos.
/// Ver docs/DESIGN_SYSTEM.md § Tintas de datos.
class RegistroInks {
  final Color azul;
  final Color ocre;
  final Color verde;

  const RegistroInks({
    required this.azul,
    required this.ocre,
    required this.verde,
  });

  static RegistroInks of(bool isNight) => isNight ? night : day;

  static RegistroInks fromContext(BuildContext context) =>
      of(Theme.of(context).brightness == Brightness.dark);

  static const day = RegistroInks(
    azul: Color(0xFF4E6E8E),
    ocre: Color(0xFFB8862B),
    verde: Color(0xFF6E7F4E),
  );

  static const night = RegistroInks(
    azul: Color(0xFF7FA3C4),
    ocre: Color(0xFFD9A94A),
    verde: Color(0xFF9BAD72),
  );
}
