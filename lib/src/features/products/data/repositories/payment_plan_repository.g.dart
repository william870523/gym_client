// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_plan_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(paymentPlanRepository)
const paymentPlanRepositoryProvider = PaymentPlanRepositoryProvider._();

final class PaymentPlanRepositoryProvider
    extends
        $FunctionalProvider<
          PaymentPlanRepository,
          PaymentPlanRepository,
          PaymentPlanRepository
        >
    with $Provider<PaymentPlanRepository> {
  const PaymentPlanRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paymentPlanRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paymentPlanRepositoryHash();

  @$internal
  @override
  $ProviderElement<PaymentPlanRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PaymentPlanRepository create(Ref ref) {
    return paymentPlanRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaymentPlanRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaymentPlanRepository>(value),
    );
  }
}

String _$paymentPlanRepositoryHash() =>
    r'c42de8091f69c74a07788e0dd200779a08c6539e';
