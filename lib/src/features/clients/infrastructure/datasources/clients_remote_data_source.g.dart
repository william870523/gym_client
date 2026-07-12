// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clients_remote_data_source.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(clientsRemoteDataSource)
const clientsRemoteDataSourceProvider = ClientsRemoteDataSourceProvider._();

final class ClientsRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          ClientsRemoteDataSource,
          ClientsRemoteDataSource,
          ClientsRemoteDataSource
        >
    with $Provider<ClientsRemoteDataSource> {
  const ClientsRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clientsRemoteDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clientsRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<ClientsRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ClientsRemoteDataSource create(Ref ref) {
    return clientsRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClientsRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClientsRemoteDataSource>(value),
    );
  }
}

String _$clientsRemoteDataSourceHash() =>
    r'2979122d6e2755aa609ef4bbc62e1fceca87c195';
