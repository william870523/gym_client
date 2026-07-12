// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'currency_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(currencyRepository)
const currencyRepositoryProvider = CurrencyRepositoryProvider._();

final class CurrencyRepositoryProvider
    extends
        $FunctionalProvider<
          CurrencyRepository,
          CurrencyRepository,
          CurrencyRepository
        >
    with $Provider<CurrencyRepository> {
  const CurrencyRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currencyRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currencyRepositoryHash();

  @$internal
  @override
  $ProviderElement<CurrencyRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CurrencyRepository create(Ref ref) {
    return currencyRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CurrencyRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CurrencyRepository>(value),
    );
  }
}

String _$currencyRepositoryHash() =>
    r'781904792e31c0e228e22e747523e87b574898a8';
