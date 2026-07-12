// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reference_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReferenceNotifier)
const referenceProvider = ReferenceNotifierProvider._();

final class ReferenceNotifierProvider
    extends $AsyncNotifierProvider<ReferenceNotifier, List<ReferenceModel>> {
  const ReferenceNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'referenceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$referenceNotifierHash();

  @$internal
  @override
  ReferenceNotifier create() => ReferenceNotifier();
}

String _$referenceNotifierHash() => r'236c48cfc0a19e2b296828cb88387fcaedcd7f48';

abstract class _$ReferenceNotifier
    extends $AsyncNotifier<List<ReferenceModel>> {
  FutureOr<List<ReferenceModel>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<List<ReferenceModel>>, List<ReferenceModel>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<ReferenceModel>>,
                List<ReferenceModel>
              >,
              AsyncValue<List<ReferenceModel>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
