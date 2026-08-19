import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/saldo_enlace_models.dart';
import '../../data/repositories/saldo_enlace_repository.dart';

/// M8 — el saldo entre sedes (docs/MULTI_SEDE.md §5.4).
///
/// Todos `autoDispose`. El saldo cambia cada vez que se cobra por cuenta ajena
/// en cualquier sede, así que cachearlo de por vida enseñaría una deuda vieja
/// justo a quien está a punto de transferir dinero contra ella.
///
/// **El saldo no es del período.** Es lo que se debe *hoy*, acumulado desde el
/// primer cobro cruzado, y por eso estos providers no llevan período: filtrarlo
/// por el de la pantalla daría una cifra que nadie puede transferir.

final saldoDeSedeProvider = FutureProvider.autoDispose
    .family<SaldoSedeModel, String?>((ref, gymId) {
      return ref.watch(saldoEnlaceRepositoryProvider).getSaldo(gymId: gymId);
    });

final liquidacionesDeSedeProvider = FutureProvider.autoDispose
    .family<List<LiquidacionModel>, String?>((ref, gymId) {
      return ref.watch(saldoEnlaceRepositoryProvider).getLiquidaciones(gymId: gymId);
    });
