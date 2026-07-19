import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../accounting/presentation/state/accounting_providers.dart';
import '../../../clients/presentation/state/client_notifier.dart';
import '../../../clients/presentation/state/client_record_provider.dart';
import '../../../retention/presentation/state/retention_providers.dart';
import 'payment_notifier.dart';

/// Mantiene consistentes todas las lecturas derivadas después de confirmar un
/// pago. El pago ya fue persistido cuando se llama este coordinador.
final paymentRefreshCoordinatorProvider = Provider<PaymentRefreshCoordinator>(
  PaymentRefreshCoordinator.new,
);

class PaymentRefreshCoordinator {
  PaymentRefreshCoordinator(this._ref);

  final Ref _ref;

  Future<void> afterSuccessfulPayment(String clientId) async {
    return afterPaymentMutation(clientId);
  }

  Future<void> afterPaymentMutation(
    String clientId, {
    bool refreshPayments = true,
  }) async {
    // Estas dos listas alimentan Clientes, Finanzas y el panel principal. Se
    // esperan antes de cerrar el cobro para que la pantalla de origen nunca
    // vuelva a mostrar la vigencia anterior.
    await Future.wait([
      _ref.read(clientNotifierProvider.notifier).refresh(),
      if (refreshPayments)
        _ref.read(paymentNotifierProvider.notifier).refresh(),
    ]);

    _ref.invalidate(clientPaymentHistoryProvider(clientId));
    _ref.invalidate(clientRecordProvider(clientId));
    _ref.invalidate(accountingSummaryProvider);
    _ref.invalidate(operationalResultsProvider);
    _ref.invalidate(trainerCommissionInstallmentsProvider);
    _ref.invalidate(retentionDashboardProvider);
  }
}
