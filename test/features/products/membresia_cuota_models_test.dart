import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/products/data/models/membresia_cuota_models.dart';

/// `importe` es `Decimal` en SQLite y en MariaDB, y **Prisma lo serializa como
/// cadena** (`"10"`), no como número. Leerlo con `as num?` reventaba con
/// `type 'String' is not a subtype of type 'num'` y tumbaba la carga de cuotas
/// entera: la ventana de cobro se quedaba sin saber qué cuota tocaba.
///
/// Estas pruebas fijan el JSON tal y como lo mandan las APIs de verdad.
void main() {
  group('MembresiaCuotaModel', () {
    Map<String, dynamic> cuota(Object importe) => {
      'cuota_instancia_id': 'mcuota-1',
      'membresia_id': 'mem-1',
      'numero_cuota': 2,
      'importe': importe,
      'dias_cobertura': 10,
      'fecha_exigible': '2026-07-20T00:00:00.000Z',
      'fecha_cobertura_inicio': '2026-07-20T00:00:00.000Z',
      'fecha_cobertura_fin': '2026-07-30T00:00:00.000Z',
      'estado': 'PENDIENTE',
    };

    test('lee el importe que mandan las APIs: una cadena', () {
      expect(MembresiaCuotaModel.fromJson(cuota('10')).importe, 10.0);
      expect(MembresiaCuotaModel.fromJson(cuota('10.50')).importe, 10.5);
    });

    test('sigue leyendo un importe numérico', () {
      expect(MembresiaCuotaModel.fromJson(cuota(15)).importe, 15.0);
      expect(MembresiaCuotaModel.fromJson(cuota(15.25)).importe, 15.25);
    });

    test('un importe ilegible no revienta la carga', () {
      expect(MembresiaCuotaModel.fromJson(cuota('')).importe, 0.0);
      final sinImporte = cuota('10')..remove('importe');
      expect(MembresiaCuotaModel.fromJson(sinImporte).importe, 0.0);
    });
  });

  group('PlanCuotaEsquemaModel', () {
    test('lee el importe como cadena o como número', () {
      Map<String, dynamic> tramo(Object importe) => {
        'esquema_id': 'esq-1',
        'plan_id': 'plan-1',
        'numero_cuota': 1,
        'importe': importe,
        'dias_cobertura': 10,
        'orden': 1,
      };

      expect(PlanCuotaEsquemaModel.fromJson(tramo('10')).importe, 10.0);
      expect(PlanCuotaEsquemaModel.fromJson(tramo(10.75)).importe, 10.75);
    });
  });
}
