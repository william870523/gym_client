import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/attendance/data/models/attendance_model.dart';

void main() {
  test('conserva nombre y foto del cliente incluido en la asistencia', () {
    final photo = base64Encode([1, 2, 3, 4]);
    final attendance = AttendanceModel.fromJson({
      'asistencia_id': 'attendance-1',
      'ci': '91021547301',
      'created_at': '2026-07-06T02:12:59.231Z',
      'fecha_salida': null,
      'cliente': {
        'nombres': 'Carlos Antonio',
        'apellidos': 'Millán',
        'foto_cliente': photo,
      },
    });

    expect(attendance.clientId, '91021547301');
    expect(attendance.clientName, 'Carlos Antonio Millán');
    expect(attendance.photoUrl, photo);
    expect(attendance.status, 'activo');
  });
}
