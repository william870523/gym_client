import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/clients/data/models/voluntary_cancellation_preview.dart';

void main() {
  test(
    'interpreta la valoración ejecutable sin movimiento inmediato de caja',
    () {
      final value = VoluntaryCancellationPreview.fromJson({
        'fecha_efectiva': '2026-08-11',
        'socio': {'nombre': 'Carmen Cancelación'},
        'membresia': {
          'plan_nombre': 'Mensual',
          'estado': 'ACTIVA',
          'moneda_id': 'cup-id',
          'moneda_codigo': 'CUP',
          'moneda_simbolo': r'$',
        },
        'valoracion': {
          'dias_totales': 30,
          'dias_consumidos': 18,
          'dias_restantes': 12,
          'importe_pagado': 90,
          'valor_consumido': 54,
          'valor_no_consumido': 36,
        },
        'alternativas': [
          {
            'tipo': 'CREDITO_CLIENTE',
            'importe': 36,
            'descripcion': 'Crédito interno',
          },
        ],
        'reglas': {'solo_previsualizacion': false},
      });

      expect(value.remainingDays, 12);
      expect(value.unusedValue, 36);
      expect(value.currency, 'CUP');
      expect(value.alternatives.single.type, 'CREDITO_CLIENTE');
      expect(value.isPreviewOnly, isFalse);
    },
  );
}
