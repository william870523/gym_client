// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trainer_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TrainerNotifier)
const trainerProvider = TrainerNotifierProvider._();

final class TrainerNotifierProvider
    extends $AsyncNotifierProvider<TrainerNotifier, List<TrainerModel>> {
  const TrainerNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trainerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trainerNotifierHash();

  @$internal
  @override
  TrainerNotifier create() => TrainerNotifier();
}

String _$trainerNotifierHash() => r'ac847858c507925037325d139d428bf03afb67bb';

abstract class _$TrainerNotifier extends $AsyncNotifier<List<TrainerModel>> {
  FutureOr<List<TrainerModel>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<List<TrainerModel>>, List<TrainerModel>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<TrainerModel>>, List<TrainerModel>>,
              AsyncValue<List<TrainerModel>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
