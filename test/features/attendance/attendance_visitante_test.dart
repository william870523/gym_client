import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/attendance/data/models/attendance_model.dart';

/// El contrato de cable del visitante (M4a).
///
/// El servidor decide quién es visitante —comparando la sede del socio con la
/// de la instalación, no por si le falta la ficha— y el cliente solo lo
/// transporta. Esta prueba fija esa frontera: si el nombre del campo cambia en
/// una API, el distintivo del mostrador desaparecería sin que nada fallara.
void main() {
  Map<String, dynamic> fila({bool visitante = false, String? origen}) => {
    'asistencia_id': 'a-1',
    'ci': '99090100009',
    'created_at': '2026-08-16T12:00:00.000Z',
    'fecha_salida': null,
    'pausa_ms': 0,
    'cliente': {'nombres': 'Adela', 'apellidos': 'Sede Ajena DEMO'},
    if (visitante) 'visitante': true,
    if (origen != null) 'gym_id_origen': origen,
  };

  test('una entrada de socio propio no se marca como visitante', () {
    final a = AttendanceModel.fromJson(fila());
    expect(a.visitante, isFalse);
    expect(a.sedeDeOrigen, isNull);
  });

  test('la entrada de un socio de otra sede llega marcada y con su origen', () {
    final a = AttendanceModel.fromJson(
      fila(visitante: true, origen: 'dtc-gym-ajeno'),
    );
    expect(a.visitante, isTrue);
    expect(a.sedeDeOrigen, 'dtc-gym-ajeno');
    expect(a.clientName, 'Adela Sede Ajena DEMO');
  });
}
