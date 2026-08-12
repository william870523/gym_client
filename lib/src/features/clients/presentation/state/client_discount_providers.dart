import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/client_discount_settings_model.dart';
import '../../data/repositories/client_discount_repository.dart';

/// R5.3 — Provider del % global de descuento para cliente VIEJO.
final clientDiscountSettingsProvider =
    FutureProvider.autoDispose<ClientDiscountSettingsModel>((ref) {
      return ref.watch(clientDiscountRepositoryProvider).get();
    });
