import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/referencia_model.dart';
import '../../data/repositories/referencia_repository.dart';

class ReferenciaNotifier extends AsyncNotifier<List<ReferenciaModel>> {
  @override
  Future<List<ReferenciaModel>> build() async {
    return ref.watch(referenciaRepositoryProvider).getReferencias();
  }
}

final referenciaNotifierProvider =
    AsyncNotifierProvider<ReferenciaNotifier, List<ReferenciaModel>>(() {
      return ReferenciaNotifier();
    });
