import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/cierre_cadena_m6_models.dart';
import '../../data/repositories/cierre_cadena_repository.dart';
import 'cierre_cadena_providers.dart';

/// M6 — lo que ve contabilidad central (docs/MULTI_SEDE.md §6.3 y §6.4).
///
/// Todos `autoDispose`: el informe cambia si llegan datos nuevos, y cachearlo de
/// por vida enseñaría un total viejo justo cuando alguien acaba de cerrar.

final consolidadoProvider = FutureProvider.autoDispose
    .family<ConsolidadoModel, PeriodoSemaforo>((ref, periodo) {
      return ref
          .watch(cierreCadenaRepositoryProvider)
          .getConsolidado(desde: periodo.desde, hastaExclusivo: periodo.hastaExclusivo);
    });

/// Los certificados firmados, con los anulados incluidos.
///
/// Se piden **con** histórico a propósito: los anulados son la prueba de lo que
/// se cerró entonces, y esconderlos deja la impresión de que solo hubo uno.
final certificadosProvider = FutureProvider.autoDispose<List<CertificadoModel>>((ref) {
  return ref.watch(cierreCadenaRepositoryProvider).getCertificados(historico: true);
});

/// La sede cuyo detalle se está mirando, o `null` si no hay ninguno abierto.
class SedeEnDetalle extends Notifier<String?> {
  @override
  String? build() => null;

  /// Pulsar la sede abierta la cierra: es el gesto que espera quien la abrió
  /// para volver a la lista.
  void alternar(String gymId) => state = state == gymId ? null : gymId;

  void limpiar() => state = null;
}

final sedeEnDetalleProvider =
    NotifierProvider<SedeEnDetalle, String?>(SedeEnDetalle.new);

class DetallePedido {
  const DetallePedido({required this.gymId, required this.periodo});

  final String gymId;
  final PeriodoSemaforo periodo;

  @override
  bool operator ==(Object other) =>
      other is DetallePedido && other.gymId == gymId && other.periodo == periodo;

  @override
  int get hashCode => Object.hash(gymId, periodo);
}

final detalleDeSedeProvider = FutureProvider.autoDispose
    .family<DetalleSedeModel, DetallePedido>((ref, pedido) {
      return ref
          .watch(cierreCadenaRepositoryProvider)
          .getDetalleDeSede(
            gymId: pedido.gymId,
            desde: pedido.periodo.desde,
            hastaExclusivo: pedido.periodo.hastaExclusivo,
          );
    });
