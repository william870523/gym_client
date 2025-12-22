// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clients_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(getClients)
const getClientsProvider = GetClientsProvider._();

final class GetClientsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Client>>,
          List<Client>,
          FutureOr<List<Client>>
        >
    with $FutureModifier<List<Client>>, $FutureProvider<List<Client>> {
  const GetClientsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getClientsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getClientsHash();

  @$internal
  @override
  $FutureProviderElement<List<Client>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Client>> create(Ref ref) {
    return getClients(ref);
  }
}

String _$getClientsHash() => r'7bd7b4730e6962193e763b8687b80de31fa437bc';
