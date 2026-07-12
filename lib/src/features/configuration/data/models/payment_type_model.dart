class PaymentTypeModel {
  final String id;
  final String name;
  final String? code;
  final bool active;
  final bool isDeleted;

  PaymentTypeModel({
    required this.id,
    required this.name,
    this.code,
    this.active = true,
    this.isDeleted = false,
  });

  factory PaymentTypeModel.fromJson(Map<String, dynamic> json) {
    return PaymentTypeModel(
      id: json['tipo_pago_id'] as String,
      name: json['nombre_tipo_pago'] as String,
      code: json['codigo'] as String?,
      active: json['activo'] == 1 || json['activo'] == true,
      isDeleted: json['is_deleted'] == 1 || json['is_deleted'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tipo_pago_id': id,
      'nombre_tipo_pago': name,
      'codigo': code,
      'activo': active,
      'is_deleted': isDeleted,
    };
  }

  PaymentTypeModel copyWith({
    String? id,
    String? name,
    String? code,
    bool? active,
    bool? isDeleted,
  }) {
    return PaymentTypeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      active: active ?? this.active,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PaymentTypeModel &&
        other.id == id &&
        other.name == name &&
        other.code == code &&
        other.active == active &&
        other.isDeleted == isDeleted;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        code.hashCode ^
        active.hashCode ^
        isDeleted.hashCode;
  }
}
