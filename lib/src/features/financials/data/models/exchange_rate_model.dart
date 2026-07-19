import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'currency_model.dart';

part 'exchange_rate_model.freezed.dart';
part 'exchange_rate_model.g.dart';

@freezed
sealed class ExchangeRateModel with _$ExchangeRateModel {
  const factory ExchangeRateModel({
    @JsonKey(name: 'tipo_cambio_id') required String id,
    @JsonKey(name: 'moneda_id_base') required String monedaIdBase,
    @JsonKey(name: 'moneda_id_target') required String monedaIdTarget,
    @JsonKey(name: 'exchange_rate') required double exchangeRate,
    @JsonKey(name: 'recargos_json') String? recargosJson,
    @JsonKey(name: 'fecha_inicio') required DateTime fechaInicio,
    @JsonKey(name: 'fecha_expiracion') DateTime? fechaExpiracion,
    @Default(true) bool activo,
    @JsonKey(name: 'moneda_base') CurrencyModel? monedaBase,
    @JsonKey(name: 'moneda_target') CurrencyModel? monedaTarget,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _ExchangeRateModel;

  factory ExchangeRateModel.fromJson(Map<String, dynamic> json) =>
      _$ExchangeRateModelFromJson(json);
}

/// R5.1 — recargos porcentuales por método de pago persistidos en la tasa.
/// El recargo es ganancia del gimnasio y se muestra desglosado al cobrar.
extension ExchangeRateSurcharges on ExchangeRateModel {
  /// Mapa `tipo_pago_id → porcentaje` ("5.00"). Vacío si no hay recargos o el
  /// JSON persistido no es legible (el servidor es la autoridad de validez).
  Map<String, String> get recargos {
    final stored = recargosJson;
    if (stored == null || stored.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          entry.key.toString(): entry.value.toString(),
      };
    } catch (_) {
      return const {};
    }
  }

  bool get tieneRecargos => recargos.isNotEmpty;
}
