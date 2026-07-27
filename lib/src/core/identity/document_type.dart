enum DocumentType {
  cubanCi('CI_CUBANO', 'CI cubano'),
  passport('PASAPORTE', 'Pasaporte'),
  other('OTRO', 'Otro documento'),
  unknown('DESCONOCIDO', 'Sin clasificar');

  const DocumentType(this.code, this.label);

  final String code;
  final String label;

  bool get validatesCubanCi => this == DocumentType.cubanCi;
  bool get isClassified => this != DocumentType.unknown;

  static DocumentType fromCode(String? value) {
    final normalized = value?.trim().toUpperCase();
    return DocumentType.values.firstWhere(
      (type) => type.code == normalized,
      orElse: () => DocumentType.unknown,
    );
  }
}

String restrictDocumentText(String value, DocumentType type) {
  final filtered = switch (type) {
    DocumentType.cubanCi => value.replaceAll(RegExp(r'[^0-9]'), ''),
    DocumentType.passport => value.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    ),
    DocumentType.other || DocumentType.unknown => value,
  };
  final maximumLength = switch (type) {
    DocumentType.cubanCi => 11,
    DocumentType.passport => 9,
    DocumentType.other || DocumentType.unknown => null,
  };
  if (maximumLength == null || filtered.length <= maximumLength) {
    return filtered;
  }
  return filtered.substring(0, maximumLength);
}
