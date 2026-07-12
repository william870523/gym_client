import 'package:flutter/material.dart';
import 'pulso_mostrador_view.dart';

/// Pantalla de asistencia / recepción (índice 7 del dashboard).
/// Usa el mostrador operativo PULSO con entrada, pausa, reanudación y salida.
class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PulsoMostradorView();
  }
}
