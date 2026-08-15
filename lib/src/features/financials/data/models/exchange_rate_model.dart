import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'currency_model.dart';
import '../../../../core/money/decimal_json.dart';

part 'exchange_rate_model.freezed.dart';
part 'exchange_rate_model.g.dart';

@freezed
sealed class ExchangeRateModel with _$ExchangeRateModel {
  const factory ExchangeRateModel({
    @JsonKey(name: 'tipo_cambio_id') required String id,
    @JsonKey(name: 'moneda_id_base') required String monedaIdBase,
    @JsonKey(name: 'moneda_id_target') required String monedaIdTarget,
    @JsonKey(name: 'exchange_rate', fromJson: decimalJsonToDouble)
    required double exchangeRate,
    @JsonKey(name: 'recargos_json') String? recargosJson,
    @JsonKey(name: 'recargos_globales_json') String? recargosGlobalesJson,
    @JsonKey(name: 'recargos_sede_json') String? recargosSedeJson,
    @JsonKey(name: 'recargos_fuentes_json') String? recargosFuentesJson,
    @JsonKey(name: 'recargos_fuente') @Default('NINGUNO') String recargosFuente,
    @JsonKey(name: 'recargos_gym_id') String? recargosGymId,
    @JsonKey(name: 'puede_editar_global') @Default(true) bool puedeEditarGlobal,
    @JsonKey(name: 'puede_editar_sede') @Default(true) bool puedeEditarSede,
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
    return _decodeSurcharges(recargosJson);
  }

  Map<String, String> get recargosGlobales => _decodeSurcharges(
    recargosGlobalesJson ?? recargosJson,
  );

  /// Incluye `0.00`: es la excepción explícita que apaga un valor global.
  Map<String, String> get recargosSede => _decodeSurcharges(recargosSedeJson);

  Map<String, String> get recargosFuentes =>
      _decodeSurcharges(recargosFuentesJson);

  Map<String, String> _decodeSurcharges(String? stored) {
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

  bool get tieneExcepcionSede => recargosSede.isNotEmpty;
}
