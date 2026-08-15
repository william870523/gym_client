// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Cliente HTTP **atado a la sede activa**.
///
/// Observar aquí la sede no es un detalle: es la palanca que hace que cambiar
/// de sede tire TODOS los datos cacheados (docs/MULTI_SEDE.md §3.4 y §7). Como
/// cada repositorio observa este proveedor, y cada vista observa su repositorio,
/// al cambiar la sede se reconstruye la cadena entera y no sobrevive nada de la
/// sede anterior.
///
/// Por eso ningún repositorio debe usar `ref.read(apiClientProvider)`: leer sin
/// observar rompe la cadena en silencio y esa vista seguiría enseñando los
/// socios de la sede que se acaba de abandonar. Lo vigila
/// `test/core/network/api_client_dependency_test.dart`.

@ProviderFor(apiClient)
const apiClientProvider = ApiClientProvider._();

/// Cliente HTTP **atado a la sede activa**.
///
/// Observar aquí la sede no es un detalle: es la palanca que hace que cambiar
/// de sede tire TODOS los datos cacheados (docs/MULTI_SEDE.md §3.4 y §7). Como
/// cada repositorio observa este proveedor, y cada vista observa su repositorio,
/// al cambiar la sede se reconstruye la cadena entera y no sobrevive nada de la
/// sede anterior.
///
/// Por eso ningún repositorio debe usar `ref.read(apiClientProvider)`: leer sin
/// observar rompe la cadena en silencio y esa vista seguiría enseñando los
/// socios de la sede que se acaba de abandonar. Lo vigila
/// `test/core/network/api_client_dependency_test.dart`.

final class ApiClientProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// Cliente HTTP **atado a la sede activa**.
  ///
  /// Observar aquí la sede no es un detalle: es la palanca que hace que cambiar
  /// de sede tire TODOS los datos cacheados (docs/MULTI_SEDE.md §3.4 y §7). Como
  /// cada repositorio observa este proveedor, y cada vista observa su repositorio,
  /// al cambiar la sede se reconstruye la cadena entera y no sobrevive nada de la
  /// sede anterior.
  ///
  /// Por eso ningún repositorio debe usar `ref.read(apiClientProvider)`: leer sin
  /// observar rompe la cadena en silencio y esa vista seguiría enseñando los
  /// socios de la sede que se acaba de abandonar. Lo vigila
  /// `test/core/network/api_client_dependency_test.dart`.
  const ApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiClientHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return apiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$apiClientHash() => r'65e61a7e55e0e146ce17919460cd51a4e53c2738';
