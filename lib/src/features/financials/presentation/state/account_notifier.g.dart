// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AccountNotifier)
const accountProvider = AccountNotifierProvider._();

final class AccountNotifierProvider
    extends $AsyncNotifierProvider<AccountNotifier, List<AccountModel>> {
  const AccountNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountNotifierHash();

  @$internal
  @override
  AccountNotifier create() => AccountNotifier();
}

String _$accountNotifierHash() => r'1d75ded7ee5377f772527e1956dbe5d3d5d76769';

abstract class _$AccountNotifier extends $AsyncNotifier<List<AccountModel>> {
  FutureOr<List<AccountModel>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<List<AccountModel>>, List<AccountModel>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<AccountModel>>, List<AccountModel>>,
              AsyncValue<List<AccountModel>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
