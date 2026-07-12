// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clients_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(clientsRepository)
const clientsRepositoryProvider = ClientsRepositoryProvider._();

final class ClientsRepositoryProvider
    extends
        $FunctionalProvider<
          ClientsRepository,
          ClientsRepository,
          ClientsRepository
        >
    with $Provider<ClientsRepository> {
  const ClientsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clientsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clientsRepositoryHash();

  @$internal
  @override
  $ProviderElement<ClientsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ClientsRepository create(Ref ref) {
    return clientsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClientsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClientsRepository>(value),
    );
  }
}

String _$clientsRepositoryHash() => r'1eb9d0d29e04a054b3cba5f647b841ab403a81ed';
