/// R5.3 — Modelo de la configuración global del descuento de cliente VIEJO.
class ClientDiscountSettingsModel {
  const ClientDiscountSettingsModel({
    required this.gymId,
    required this.clienteViejoPct,
    required this.source,
    required this.min,
    required this.max,
    required this.changedKeys,
    required this.updatedAtUtc,
  });

  factory ClientDiscountSettingsModel.fromJson(Map<String, dynamic> json) {
    final limits = json['limits'] is Map
        ? Map<String, dynamic>.from(json['limits'] as Map)
        : const <String, dynamic>{};
    return ClientDiscountSettingsModel(
      gymId: json['gym_id']?.toString() ?? '',
      clienteViejoPct: json['cliente_viejo_pct']?.toString() ?? '16.67',
      source: json['source']?.toString() ?? 'DEFAULT',
      min: (limits['min'] as num?)?.toInt() ?? 0,
      max: (limits['max'] as num?)?.toInt() ?? 100,
      changedKeys: (json['changed_keys'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      updatedAtUtc: json['updated_at_utc'] == null
          ? null
          : DateTime.tryParse(json['updated_at_utc'].toString())?.toUtc(),
    );
  }

  final String gymId;
  final String clienteViejoPct;
  final String source; // GYM | GLOBAL | DEFAULT
  final int min;
  final int max;
  final List<String> changedKeys;
  final DateTime? updatedAtUtc;
}
