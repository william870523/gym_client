// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exchange_rate_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ExchangeRateNotifier)
const exchangeRateProvider = ExchangeRateNotifierProvider._();

final class ExchangeRateNotifierProvider
    extends
        $AsyncNotifierProvider<ExchangeRateNotifier, List<ExchangeRateModel>> {
  const ExchangeRateNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exchangeRateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exchangeRateNotifierHash();

  @$internal
  @override
  ExchangeRateNotifier create() => ExchangeRateNotifier();
}

String _$exchangeRateNotifierHash() =>
    r'50d66577356cdf876d4947d7132252b1ec39accb';

abstract class _$ExchangeRateNotifier
    extends $AsyncNotifier<List<ExchangeRateModel>> {
  FutureOr<List<ExchangeRateModel>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<ExchangeRateModel>>,
              List<ExchangeRateModel>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<ExchangeRateModel>>,
                List<ExchangeRateModel>
              >,
              AsyncValue<List<ExchangeRateModel>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
