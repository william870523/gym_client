class ReferenceModel {
  final String id;
  final String nombre;
  final bool activo;

  ReferenceModel({required this.id, required this.nombre, this.activo = true});

  factory ReferenceModel.fromJson(Map<String, dynamic> json) {
    return ReferenceModel(
      id: json['referencia_id'] as String,
      nombre: json['nombre_referencia'] as String,
      // API might return 'is_deleted', ui uses 'activo' inverse or separate logic.
      // Usually references just exist or are deleted.
      // If schema has 'is_deleted', we assume existing ones are active.
      activo: !(json['is_deleted'] as bool? ?? false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'referencia_id': id,
      'nombre_referencia': nombre,
      // 'is_deleted' handled by backend delete op
    };
  }

  ReferenceModel copyWith({String? id, String? nombre, bool? activo}) {
    return ReferenceModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      activo: activo ?? this.activo,
    );
  }
}
