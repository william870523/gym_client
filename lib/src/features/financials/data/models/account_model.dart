import 'dart:typed_data';

class AccountModel {
  final String id;
  final String name;
  final String currencyId;
  final String? currencyCode;
  final String? currencyName;
  final String? currencySymbol;
  final Uint8List? currencyImage;
  final String? paymentTypeId;
  final bool isDeleted;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AccountModel({
    required this.id,
    required this.name,
    required this.currencyId,
    this.currencyCode,
    this.currencyName,
    this.currencySymbol,
    this.currencyImage,
    this.paymentTypeId,
    this.isDeleted = false,
    this.version = 1,
    this.createdAt,
    this.updatedAt,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    Uint8List? imageBytes;
    final imageData = json['moneda']?['imagen'];
    if (imageData != null) {
      try {
        if (imageData is String && imageData.isNotEmpty) {
          imageBytes = Uint8List.fromList(
            List<int>.from(
              Uri.parse('data:;base64,$imageData').data!.contentAsBytes(),
            ),
          );
        } else if (imageData is List) {
          // Direct byte array (e.g. from local API/SQLite)
          imageBytes = Uint8List.fromList(List<int>.from(imageData));
        } else if (imageData is Map) {
          if (imageData['data'] is List) {
            // Buffer object format { type: 'Buffer', data: [...] }
            imageBytes = Uint8List.fromList(List<int>.from(imageData['data']));
          } else {
            // Uint8Array serialization { "0": 137, "1": 80 ... }
            try {
              final entries = imageData.entries.toList();
              // Sort by numeric key explicitly to ensure order
              entries.sort(
                (a, b) => int.parse(
                  a.key.toString(),
                ).compareTo(int.parse(b.key.toString())),
              );
              final bytes = entries.map((e) => e.value as int).toList();
              if (bytes.isNotEmpty) {
                imageBytes = Uint8List.fromList(bytes);
              }
            } catch (_) {}
          }
        }
      } catch (_) {
        // Silent fail
      }
    }

    return AccountModel(
      id: json['cuenta_id'] as String,
      name: json['nombre_cuenta'] as String,
      currencyId: json['moneda_id'] as String,
      currencyCode: json['moneda']?['codigo'] as String?,
      currencyName: json['moneda']?['moneda_nombre'] as String?,
      currencySymbol: json['moneda']?['simbolo'] as String?,
      currencyImage: imageBytes,
      paymentTypeId: json['tipo_pago_id'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      version: json['version'] as int? ?? 1,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cuenta_id': id,
      'nombre_cuenta': name,
      'moneda_id': currencyId,
      'tipo_pago_id': paymentTypeId,
    };
  }

  AccountModel copyWith({
    String? id,
    String? name,
    String? currencyId,
    String? currencyCode,
    String? currencyName,
    String? currencySymbol,
    Uint8List? currencyImage,
    String? paymentTypeId,
    bool? isDeleted,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      currencyId: currencyId ?? this.currencyId,
      currencyCode: currencyCode ?? this.currencyCode,
      currencyName: currencyName ?? this.currencyName,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyImage: currencyImage ?? this.currencyImage,
      paymentTypeId: paymentTypeId ?? this.paymentTypeId,
      isDeleted: isDeleted ?? this.isDeleted,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AccountModel &&
        other.id == id &&
        other.name == name &&
        other.currencyId == currencyId &&
        other.paymentTypeId == paymentTypeId &&
        other.isDeleted == isDeleted &&
        other.version == version;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        currencyId.hashCode ^
        paymentTypeId.hashCode ^
        isDeleted.hashCode ^
        version.hashCode;
  }
}

/// Cómo se nombra la moneda de una cuenta **delante de una persona**.
///
/// El `moneda_id` es un UUID y no significa nada para quien cobra. Se separó
/// aquí porque el diálogo de cobro lo estaba resolviendo por su cuenta y mal:
/// recortaba el identificador a cinco caracteres, así que el operador leía
/// «Saldo restante: ₽34.00 (~0.08 1DBC5)» —los cinco primeros dígitos del UUID
/// de la cuenta en euros— justo en la línea que dice cuánto falta por cobrar.
/// La otra copia de la misma idea, en `_buildSurchargeBanner`, exigía
/// `length <= 5`, condición que un UUID no cumple nunca: el recargo se enseñaba
/// **sin moneda**, que es lo contrario de «nunca sumar monedas distintas».
///
/// El recorte del identificador se conserva como último recurso, para cuentas
/// que llegaron sin su moneda embebida, y nunca devuelve cadena vacía: es
/// preferible un código feo a un importe sin moneda.
extension AccountCurrencyLabel on AccountModel {
  String get currencyLabel {
    final codigo = currencyCode?.trim();
    if (codigo != null && codigo.isNotEmpty) return codigo.toUpperCase();
    if (currencyId.isEmpty) return '';
    return currencyId.length > 5
        ? currencyId.substring(0, 5).toUpperCase()
        : currencyId.toUpperCase();
  }
}
