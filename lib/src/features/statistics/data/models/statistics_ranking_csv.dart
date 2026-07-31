import 'dart:typed_data';

class StatisticsRankingCsv {
  const StatisticsRankingCsv({
    required this.bytes,
    required this.fileName,
    required this.rows,
  });

  final Uint8List bytes;
  final String fileName;
  final int rows;
}

class StatisticsRankingExportResult {
  const StatisticsRankingExportResult({
    required this.rows,
    required this.saved,
  });

  final int rows;
  final bool saved;
}
