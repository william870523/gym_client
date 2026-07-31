import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardián de la invalidación al cambiar de sede (docs/MULTI_SEDE.md §7).
///
/// `apiClientProvider` está atado a la sede activa, así que reconstruirlo tira
/// en cascada todo lo que cuelga de él. Esa cascada solo existe si los
/// repositorios lo **observan**: `ref.read` no crea dependencia, y un
/// repositorio que lo lea se quedaría con el cliente de la sede anterior. La
/// vista seguiría enseñando los socios de la sede que se acaba de abandonar,
/// sin ningún error visible.
///
/// Esta prueba existe porque el fallo sería **silencioso** y aparecería meses
/// después, en contabilidad. Revisar 49 proveedores a mano no escala; revisar
/// la regla, sí.
void main() {
  test('ningún proveedor lee apiClientProvider sin observarlo', () {
    // Único uso legítimo: una acción puntual dentro de un callback, que no
    // construye estado cacheado y por tanto no necesita invalidarse.
    //
    // `api_client.dart` va aparte: es donde vive la regla y la explica citando
    // la forma prohibida. Buscando texto plano, el guardián se acusaba a sí
    // mismo cada vez que alguien documentaba por qué no hay que hacerlo.
    const permitidos = {
      'lib/src/core/widgets/pulso_widgets.dart',
      'lib/src/core/network/api_client.dart',
    };

    final infractores = <String>[];
    for (final entity in Directory('lib/src').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;

      final relativo = entity.path.replaceAll(r'\', '/');
      if (permitidos.any(relativo.endsWith)) continue;

      final contenido = entity.readAsStringSync();
      if (contenido.contains('ref.read(apiClientProvider)')) {
        infractores.add(relativo);
      }
    }

    expect(
      infractores,
      isEmpty,
      reason:
          'Estos archivos leen apiClientProvider sin observarlo, así que no se '
          'reconstruyen al cambiar de sede y seguirían sirviendo datos de la '
          'sede anterior. Cambia ref.read por ref.watch:\n'
          '${infractores.join('\n')}',
    );
  });
}
