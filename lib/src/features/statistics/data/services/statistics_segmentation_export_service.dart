import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/statistics_ranking_csv.dart';
import '../models/statistics_segmentation.dart';
import '../repositories/statistics_repository.dart';

typedef SegmentationExporter =
    Future<StatisticsRankingExportResult> Function(SegmentationQuery query);

/// Gemelo del exportador de rankings: el CSV lo genera la API con el mismo
/// cruce que se está mirando, no la vista con lo que tiene en pantalla.
final segmentationExporterProvider = Provider<SegmentationExporter>((ref) {
  final repository = ref.watch(statisticsRepositoryProvider);
  return (query) async {
    final csv = await repository.getSegmentationCsv(query);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar segmentación en CSV',
      fileName: csv.fileName,
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      bytes: csv.bytes,
      lockParentWindow: true,
    );
    // En web el navegador inicia la descarga y file_picker siempre devuelve
    // null; allí null no significa cancelación.
    return StatisticsRankingExportResult(
      rows: csv.rows,
      saved: kIsWeb || path != null,
    );
  };
});
