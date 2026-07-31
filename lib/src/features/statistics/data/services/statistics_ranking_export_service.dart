import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/statistics_ranking_csv.dart';
import '../models/statistics_ranking_page.dart';
import '../repositories/statistics_repository.dart';

typedef StatisticsRankingExporter =
    Future<StatisticsRankingExportResult> Function(
      StatisticsRankingQuery query,
    );

final statisticsRankingExporterProvider = Provider<StatisticsRankingExporter>((
  ref,
) {
  final repository = ref.watch(statisticsRepositoryProvider);
  return (query) async {
    final csv = await repository.getRankingCsv(query);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar ranking estadístico en CSV',
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
