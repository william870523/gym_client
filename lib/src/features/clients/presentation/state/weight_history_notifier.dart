import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/client_repository.dart';

final weightHistoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, ci) {
      return ref.watch(clientRepositoryProvider).getWeights(ci);
    });
