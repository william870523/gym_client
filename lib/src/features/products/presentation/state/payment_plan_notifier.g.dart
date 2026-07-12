// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_plan_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PaymentPlanNotifier)
const paymentPlanProvider = PaymentPlanNotifierProvider._();

final class PaymentPlanNotifierProvider
    extends
        $AsyncNotifierProvider<PaymentPlanNotifier, List<PaymentPlanModel>> {
  const PaymentPlanNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paymentPlanProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paymentPlanNotifierHash();

  @$internal
  @override
  PaymentPlanNotifier create() => PaymentPlanNotifier();
}

String _$paymentPlanNotifierHash() =>
    r'8ce8e729442e146e1ad88cacc8a3dc4dd4fdcef1';

abstract class _$PaymentPlanNotifier
    extends $AsyncNotifier<List<PaymentPlanModel>> {
  FutureOr<List<PaymentPlanModel>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<List<PaymentPlanModel>>, List<PaymentPlanModel>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<PaymentPlanModel>>,
                List<PaymentPlanModel>
              >,
              AsyncValue<List<PaymentPlanModel>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
