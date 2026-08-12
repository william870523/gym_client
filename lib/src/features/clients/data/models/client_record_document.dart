class ClientRecordDocument {
  const ClientRecordDocument({
    required this.id,
    required this.clientId,
    required this.format,
    required this.destination,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.sha256,
    required this.filters,
    required this.issuedByName,
    required this.issuedByRole,
    required this.issuedByOrigin,
    required this.issuedAtUtc,
  });

  final String id;
  final String clientId;
  final String format;
  final String destination;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String sha256;
  final Map<String, dynamic> filters;
  final String issuedByName;
  final String issuedByRole;
  final String issuedByOrigin;
  final DateTime issuedAtUtc;

  factory ClientRecordDocument.fromJson(Map<String, dynamic> json) {
    return ClientRecordDocument(
      id: json['documento_id']?.toString() ?? '',
      clientId: json['ci']?.toString() ?? '',
      format: json['formato']?.toString() ?? '',
      destination: json['destino']?.toString() ?? '',
      fileName: json['nombre_archivo']?.toString() ?? '',
      mimeType: json['mime_type']?.toString() ?? '',
      sizeBytes: int.tryParse(json['tamano_bytes']?.toString() ?? '') ?? 0,
      sha256: json['sha256']?.toString() ?? '',
      filters: json['filtros'] is Map
          ? Map<String, dynamic>.from(json['filtros'] as Map)
          : const <String, dynamic>{},
      issuedByName:
          json['emitido_por_nombre_snapshot']?.toString() ?? 'Sin atribuir',
      issuedByRole: json['emitido_por_rol_snapshot']?.toString() ?? '',
      issuedByOrigin: json['emitido_por_origen']?.toString() ?? '',
      issuedAtUtc:
          DateTime.tryParse(json['emitido_at']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
