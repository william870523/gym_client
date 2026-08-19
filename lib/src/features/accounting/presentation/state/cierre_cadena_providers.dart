import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/cierre_cadena_models.dart';
import '../../data/repositories/cierre_cadena_repository.dart';

/// Lo que administración le pide a esta sede (M5, §6.2).
///
/// `autoDispose` y no `keepAlive`: la solicitud baja por la cola y puede
/// aparecer o retirarse mientras la aplicación está abierta. Cachearla de por
/// vida dejaría al mostrador reclamado por un cierre ya retirado hasta que
/// alguien reiniciara.
final solicitudesCierreProvider =
    FutureProvider.autoDispose<List<SolicitudCierreModel>>((ref) {
      return ref.watch(cierreCadenaRepositoryProvider).getSolicitudes();
    });

/// El período que el semáforo está mirando. Se compara por valor para que dos
/// peticiones del mismo período compartan resultado.
class PeriodoSemaforo {
  const PeriodoSemaforo({required this.desde, required this.hastaExclusivo});

  final DateTime desde;
  final DateTime hastaExclusivo;

  /// El mes natural completo que contiene esa fecha, que es el período que se
  /// pide de forma corriente.
  factory PeriodoSemaforo.mesDe(DateTime fecha) => PeriodoSemaforo(
    desde: DateTime(fecha.year, fecha.month),
    hastaExclusivo: DateTime(fecha.year, fecha.month + 1),
  );

  PeriodoSemaforo get mesAnterior =>
      PeriodoSemaforo.mesDe(DateTime(desde.year, desde.month - 1));
  PeriodoSemaforo get mesSiguiente =>
      PeriodoSemaforo.mesDe(DateTime(desde.year, desde.month + 1));

  /// Último día incluido, para enseñarlo sin que nadie reste de cabeza.
  DateTime get ultimoDiaIncluido =>
      hastaExclusivo.subtract(const Duration(days: 1));

  /// El rango cubre un mes natural exacto, que la sede firma con el cierre
  /// mensual formal y no con el certificado por período.
  bool get esMesNatural =>
      desde.day == 1 &&
      hastaExclusivo.day == 1 &&
      (hastaExclusivo.year * 12 + hastaExclusivo.month) -
              (desde.year * 12 + desde.month) ==
          1;

  @override
  bool operator ==(Object other) =>
      other is PeriodoSemaforo &&
      other.desde == desde &&
      other.hastaExclusivo == hastaExclusivo;

  @override
  int get hashCode => Object.hash(desde, hastaExclusivo);
}

/// El semáforo de la cadena para un período. Solo contesta el concentrador.
final semaforoCadenaProvider = FutureProvider.autoDispose
    .family<SemaforoCadenaModel, PeriodoSemaforo>((ref, periodo) {
      return ref
          .watch(cierreCadenaRepositoryProvider)
          .getSemaforo(desde: periodo.desde, hastaExclusivo: periodo.hastaExclusivo);
    });
