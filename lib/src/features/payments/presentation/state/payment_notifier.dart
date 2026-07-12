import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../configuration/data/models/payment_type_model.dart';
import '../../../financials/data/models/account_model.dart';
import '../../../financials/data/models/exchange_rate_model.dart';
import '../../data/models/payment_model.dart';
import '../../data/repositories/payment_repository.dart';

// --- Configuration Providers ---

final paymentTypesProvider = FutureProvider<List<PaymentTypeModel>>((
  ref,
) async {
  return ref.read(paymentRepositoryProvider).getPaymentTypes();
});

final accountsProvider = FutureProvider<List<AccountModel>>((ref) async {
  return ref.read(paymentRepositoryProvider).getAccounts();
});

final exchangeRatesProvider = FutureProvider<List<ExchangeRateModel>>((
  ref,
) async {
  return ref.read(paymentRepositoryProvider).getExchangeRates();
});

// --- Dashboard Notifier ---

final paymentNotifierProvider =
    AsyncNotifierProvider<PaymentNotifier, List<PaymentModel>>(() {
      return PaymentNotifier();
    });

final clientPaymentHistoryProvider =
    FutureProvider.family<List<PaymentModel>, String>((ref, ci) async {
      return ref.read(paymentRepositoryProvider).getPaymentsByClient(ci);
    });

class PaymentNotifier extends AsyncNotifier<List<PaymentModel>> {
  @override
  Future<List<PaymentModel>> build() async {
    return _fetchPayments();
  }

  Future<List<PaymentModel>> _fetchPayments({int page = 1}) async {
    return ref
        .read(paymentRepositoryProvider)
        .getPayments(page: page, limit: 500);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchPayments());
  }

  Future<void> voidPayment(String paymentId) async {
    final previous = state;
    state = const AsyncValue.loading();
    try {
      await ref.read(paymentRepositoryProvider).voidPayment(paymentId);
      state = AsyncValue.data(await _fetchPayments());
    } catch (error, stackTrace) {
      state = previous;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

// --- Form Notifier (Process Payment) ---

final paymentFormProvider =
    NotifierProvider<PaymentFormNotifier, PaymentFormState>(() {
      return PaymentFormNotifier();
    });

class PaymentFormState {
  final List<PaymentDetailModel> details;
  final bool isLoading;
  final String? error;

  PaymentFormState({
    this.details = const [],
    this.isLoading = false,
    this.error,
  });

  PaymentFormState copyWith({
    List<PaymentDetailModel>? details,
    bool? isLoading,
    String? error,
  }) {
    return PaymentFormState(
      details: details ?? this.details,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  double get totalPaid => details.fold(0.0, (sum, item) => sum + item.amount);
}

class PaymentFormNotifier extends Notifier<PaymentFormState> {
  @override
  PaymentFormState build() {
    return PaymentFormState();
  }

  void addDetail(PaymentDetailModel detail) {
    state = state.copyWith(details: [...state.details, detail]);
  }

  void removeDetail(int index) {
    final updated = List<PaymentDetailModel>.from(state.details);
    updated.removeAt(index);
    state = state.copyWith(details: updated);
  }

  void updateDetail(int index, PaymentDetailModel detail) {
    final updated = List<PaymentDetailModel>.from(state.details);
    updated[index] = detail;
    state = state.copyWith(details: updated);
  }

  Future<bool> submitPayment(PaymentModel header) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref
          .read(paymentRepositoryProvider)
          .createPayment(header, state.details);
      // Refresh dashboard list
      ref.read(paymentNotifierProvider.notifier).refresh();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}
