/// R4.7 — Plantillas de gasto recurrente y plan de generación mensual.
///
/// La plantilla describe un gasto que se repite (alquiler, electricidad); el
/// gasto solo existe cuando se genera para un mes concreto.
class RecurringExpenseModel {
  const RecurringExpenseModel({
    required this.templateId,
    required this.categoryId,
    required this.supplierId,
    required this.currencyId,
    required this.description,
    required this.amount,
    required this.scheduledDay,
    required this.startMonth,
    required this.endMonth,
    required this.active,
    required this.notes,
  });

  factory RecurringExpenseModel.fromJson(Map<String, dynamic> json) {
    return RecurringExpenseModel(
      templateId: _text(json['recurrente_id']),
      categoryId: _text(json['categoria_id']),
      supplierId: _nullableText(json['proveedor_id']),
      currencyId: _text(json['moneda_id']),
      description: _text(json['descripcion']),
      amount: _money(json['monto']),
      scheduledDay: _integer(json['dia_programado']),
      startMonth: _text(json['mes_inicio']),
      endMonth: _nullableText(json['mes_fin']),
      active: json['activo'] == true,
      notes: _nullableText(json['notas']),
    );
  }

  final String templateId;
  final String categoryId;
  final String? supplierId;
  final String currencyId;
  final String description;
  final String amount;
  final int scheduledDay;
  final String startMonth;
  final String? endMonth;
  final bool active;
  final String? notes;

  /// Vigencia legible para el operador.
  String get validityLabel =>
      endMonth == null ? 'Desde $startMonth' : 'De $startMonth a $endMonth';
}

/// Plan de generación de un mes: qué se creará y qué se salta, con motivo.
class RecurringExpensePlanModel {
  const RecurringExpensePlanModel({
    required this.month,
    required this.periodState,
    required this.canGenerate,
    required this.blockReason,
    required this.summary,
    required this.pending,
    required this.skipped,
    required this.totals,
    required this.note,
    required this.limitations,
    required this.generated,
  });

  factory RecurringExpensePlanModel.fromJson(Map<String, dynamic> json) {
    return RecurringExpensePlanModel(
      month: _text(json['mes']),
      periodState: _text(json['estado_periodo']),
      canGenerate: json['puede_generar'] == true,
      blockReason: _nullableText(json['motivo_bloqueo']),
      summary: RecurringExpensePlanSummary.fromJson(_map(json['resumen'])),
      pending: _maps(
        json['a_generar'],
      ).map(RecurringExpensePendingModel.fromJson).toList(growable: false),
      skipped: _maps(
        json['omitidas'],
      ).map(RecurringExpenseSkippedModel.fromJson).toList(growable: false),
      totals: _maps(
        json['totales_por_moneda'],
      ).map(RecurringExpenseTotalModel.fromJson).toList(growable: false),
      note: _text(json['nota']),
      limitations: (json['limitaciones'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      generated: _maps(json['generados'])
          .map((row) => _text(row['gasto_id']))
          .where((id) => id.isNotEmpty)
          .toList(growable: false),
    );
  }

  final String month;
  final String periodState;
  final bool canGenerate;
  final String? blockReason;
  final RecurringExpensePlanSummary summary;
  final List<RecurringExpensePendingModel> pending;
  final List<RecurringExpenseSkippedModel> skipped;
  final List<RecurringExpenseTotalModel> totals;
  final String note;
  final List<String> limitations;

  /// Ids de los gastos creados por la última generación (vacío en la previa).
  final List<String> generated;
}

class RecurringExpensePlanSummary {
  const RecurringExpensePlanSummary({
    required this.evaluated,
    required this.toGenerate,
    required this.skipped,
    required this.alreadyGenerated,
  });

  factory RecurringExpensePlanSummary.fromJson(Map<String, dynamic> json) {
    return RecurringExpensePlanSummary(
      evaluated: _integer(json['plantillas_evaluadas']),
      toGenerate: _integer(json['a_generar']),
      skipped: _integer(json['omitidas']),
      alreadyGenerated: _integer(json['ya_generadas']),
    );
  }

  final int evaluated;
  final int toGenerate;
  final int skipped;
  final int alreadyGenerated;
}

class RecurringExpensePendingModel {
  const RecurringExpensePendingModel({
    required this.templateId,
    required this.categoryName,
    required this.supplierName,
    required this.currencyCode,
    required this.description,
    required this.amount,
    required this.belongingMonth,
    required this.scheduledDate,
  });

  factory RecurringExpensePendingModel.fromJson(Map<String, dynamic> json) {
    return RecurringExpensePendingModel(
      templateId: _text(json['recurrente_id']),
      categoryName: _text(json['categoria_nombre'], fallback: '—'),
      supplierName: _nullableText(json['proveedor_nombre']),
      currencyCode: _text(json['moneda_codigo'], fallback: '—'),
      description: _text(json['descripcion']),
      amount: _money(json['importe']),
      belongingMonth: _text(json['mes_pertenencia']),
      scheduledDate: _text(json['fecha_programada']),
    );
  }

  final String templateId;
  final String categoryName;
  final String? supplierName;
  final String currencyCode;
  final String description;
  final String amount;
  final String belongingMonth;
  final String scheduledDate;
}

class RecurringExpenseSkippedModel {
  const RecurringExpenseSkippedModel({
    required this.templateId,
    required this.description,
    required this.categoryName,
    required this.currencyCode,
    required this.reason,
    required this.expenseId,
    required this.explanation,
  });

  factory RecurringExpenseSkippedModel.fromJson(Map<String, dynamic> json) {
    return RecurringExpenseSkippedModel(
      templateId: _text(json['recurrente_id']),
      description: _text(json['descripcion']),
      categoryName: _text(json['categoria_nombre'], fallback: '—'),
      currencyCode: _text(json['moneda_codigo'], fallback: '—'),
      reason: _text(json['motivo']),
      expenseId: _nullableText(json['gasto_id']),
      explanation: _text(json['explicacion']),
    );
  }

  final String templateId;
  final String description;
  final String categoryName;
  final String currencyCode;
  final String reason;
  final String? expenseId;
  final String explanation;

  /// Etiqueta corta para el operador, en lugar de la constante del dominio.
  String get reasonLabel => switch (reason) {
    'YA_GENERADO' => 'Ya generado',
    'INACTIVA' => 'Inactiva',
    'ANTES_DE_VIGENCIA' => 'Aún no empieza',
    'DESPUES_DE_VIGENCIA' => 'Ya terminó',
    _ => reason,
  };
}

class RecurringExpenseTotalModel {
  const RecurringExpenseTotalModel({
    required this.currencyId,
    required this.currencyCode,
    required this.amount,
  });

  factory RecurringExpenseTotalModel.fromJson(Map<String, dynamic> json) {
    return RecurringExpenseTotalModel(
      currencyId: _text(json['moneda_id']),
      currencyCode: _text(json['moneda_codigo'], fallback: '—'),
      amount: _money(json['importe']),
    );
  }

  final String currencyId;
  final String currencyCode;
  final String amount;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<Map<String, dynamic>> _maps(Object? value) => (value as List? ?? const [])
    .whereType<Map>()
    .map(Map<String, dynamic>.from)
    .toList(growable: false);

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

String _money(Object? value) => _text(value, fallback: '0.00');

int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
