import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/statistics_segmentation.dart';

/// Vistas guardadas del cruzador (docs/PLAN_ESTADISTICAS.md §5, «filtros
/// guardados»).
///
/// **Por qué no van a la base de datos.** Una vista guardada es una comodidad
/// personal —«el cruce que miro cada lunes»—, no un dato del negocio: no se
/// cobra, no se audita y nadie más la consulta. Meterla en las dos bases
/// exigiría una migración paritaria y su cola de sincronización para algo que
/// no cambia ninguna cifra. Se guarda como preferencia de interfaz, con el
/// mismo mecanismo y el mismo espacio de claves que la apariencia
/// (`gymos.ui.<user>.*`, DESIGN_SYSTEM_PULSO §3), que funciona igual en
/// escritorio y en navegador.
///
/// Consecuencia que conviene saber: **son de este puesto y de este usuario**.
/// Quien entre desde la web verá las suyas, no las del escritorio. La vista lo
/// dice para que nadie las dé por compartidas.
class SegmentationSavedView {
  const SegmentationSavedView({required this.name, required this.query});

  factory SegmentationSavedView.fromJson(Map<String, dynamic> json) =>
      SegmentationSavedView(
        name: json['nombre']?.toString() ?? '',
        query: SegmentationQuery(
          dimension: json['dimension']?.toString() ?? '',
          measure: json['medida']?.toString() ?? '',
          days: (json['dias'] as num?)?.toInt() ?? 90,
          currencyId: json['monedaId']?.toString(),
        ),
      );

  final String name;
  final SegmentationQuery query;

  Map<String, dynamic> toJson() => {
    'nombre': name,
    'dimension': query.dimension,
    'medida': query.measure,
    'dias': query.days,
    if (query.currencyId != null) 'monedaId': query.currencyId,
  };

  /// Dos vistas con el mismo nombre son la misma: guardar reemplaza.
  bool sameName(String other) =>
      name.trim().toLowerCase() == other.trim().toLowerCase();
}

abstract interface class SegmentationSavedViewsStore {
  Future<List<SegmentationSavedView>> load(String? userId);

  Future<void> save(String? userId, List<SegmentationSavedView> views);
}

class SharedPreferencesSegmentationViewsStore
    implements SegmentationSavedViewsStore {
  SharedPreferencesSegmentationViewsStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  static String _normalize(String userId) =>
      userId.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');

  static String _key(String? userId) => userId == null || userId.trim().isEmpty
      ? 'gymos.ui.device.segmentacion.vistas'
      : 'gymos.ui.${_normalize(userId)}.segmentacion.vistas';

  @override
  Future<List<SegmentationSavedView>> load(String? userId) async {
    final crudo = await _preferences.getString(_key(userId));
    if (crudo == null || crudo.isEmpty) return const [];
    try {
      final lista = jsonDecode(crudo);
      if (lista is! List) return const [];
      return lista
          .whereType<Map>()
          .map(
            (item) =>
                SegmentationSavedView.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((vista) => vista.name.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      // Preferencia corrupta: se ignora en vez de tumbar la pantalla. Lo peor
      // que puede pasar con una comodidad es perderla, no impedir trabajar.
      return const [];
    }
  }

  @override
  Future<void> save(
    String? userId,
    List<SegmentationSavedView> views,
  ) async {
    await _preferences.setString(
      _key(userId),
      jsonEncode(views.map((vista) => vista.toJson()).toList()),
    );
  }
}
