// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trainer_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(trainerRepository)
const trainerRepositoryProvider = TrainerRepositoryProvider._();

final class TrainerRepositoryProvider
    extends
        $FunctionalProvider<
          TrainerRepository,
          TrainerRepository,
          TrainerRepository
        >
    with $Provider<TrainerRepository> {
  const TrainerRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trainerRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trainerRepositoryHash();

  @$internal
  @override
  $ProviderElement<TrainerRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TrainerRepository create(Ref ref) {
    return trainerRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrainerRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrainerRepository>(value),
    );
  }
}

String _$trainerRepositoryHash() => r'7f1af6dbbf2dbebaf3f1f1ea3e82e4fa802e3cb5';
