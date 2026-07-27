import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/client_model.dart';

/// Fila de la exportación de socios: exactamente lo que la vista tiene a la
/// vista, sin recalcular nada por su cuenta.
class ClientListExportRow {
  const ClientListExportRow({
    required this.ci,
    required this.nombre,
    required this.plan,
    required this.estado,
    required this.vigencia,
    required this.telefono,
    required this.correo,
    required this.categoria,
    required this.saldoPendiente,
  });

  final String ci;
  final String nombre;
  final String plan;
  final String estado;
  final String vigencia;
  final String telefono;
  final String correo;
  final String categoria;
  final String saldoPendiente;
}

/// Exportación CSV de la lista de socios visible (docs/PLAN_ASOCIADOS.md §5).
///
/// Existe para el caso que pidió el dueño: un plan que se retira o cambia de
/// precio necesita el listado de a quién avisar. Exporta **lo filtrado**, no el
/// registro entero; por eso el alcance viaja en el nombre del archivo y en una
/// columna, y no hay forma de confundir un listado de un plan con el total.
class ClientListExportService {
  Uint8List buildCsv({
    required List<ClientListExportRow> rows,
    required String alcance,
    required String fechaCorte,
    required String zonaHoraria,
  }) {
    final table = <List<String>>[
      const [
        'fecha_corte',
        'zona_horaria',
        'alcance',
        'ci',
        'socio',
        'plan',
        'estado',
        'vigencia',
        'telefono',
        'correo',
        'categoria',
        'saldo_pendiente',
      ],
      for (final row in rows)
        [
          fechaCorte,
          zonaHoraria,
          alcance,
          row.ci,
          row.nombre,
          row.plan,
          row.estado,
          row.vigencia,
          row.telefono,
          row.correo,
          row.categoria,
          row.saldoPendiente,
        ],
    ];
    final csv = table.map((row) => row.map(_csvCell).join(',')).join('\r\n');
    // BOM: sin él, Excel abre los acentos rotos.
    return Uint8List.fromList([0xef, 0xbb, 0xbf, ...utf8.encode(csv)]);
  }

  Future<String?> saveCsv({
    required List<ClientListExportRow> rows,
    required String alcance,
    required String fechaCorte,
    required String zonaHoraria,
    String? nombreArchivo,
  }) {
    return FilePicker.platform.saveFile(
      dialogTitle: 'Guardar listado de socios en CSV',
      fileName: nombreArchivo ?? 'socios-$fechaCorte.csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      bytes: buildCsv(
        rows: rows,
        alcance: alcance,
        fechaCorte: fechaCorte,
        zonaHoraria: zonaHoraria,
      ),
      lockParentWindow: true,
    );
  }
}

/// Convierte el modelo de la vista en fila exportable. `plan` y `estado` los
/// pasa quien exporta, porque son los rótulos que el operador está leyendo.
ClientListExportRow buildClientExportRow(
  ClientModel client, {
  required String plan,
  required String estado,
  required String vigencia,
}) => ClientListExportRow(
  ci: client.id,
  nombre: '${client.nombres ?? ''} ${client.apellidos ?? ''}'.trim().isEmpty
      ? client.id
      : '${client.nombres ?? ''} ${client.apellidos ?? ''}'.trim(),
  plan: plan,
  estado: estado,
  vigencia: vigencia,
  telefono: client.telefono?.toString() ?? '',
  correo: client.correo ?? '',
  categoria: client.categoria ?? '',
  saldoPendiente: client.membershipBalanceDue == null
      ? ''
      : client.membershipBalanceDue!.toStringAsFixed(2),
);

String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';
