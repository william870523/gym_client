class PaymentReversalResult {
  const PaymentReversalResult({
    required this.reversalId,
    required this.paymentId,
    required this.reason,
    required this.idempotent,
    required this.summary,
  });

  final String reversalId;
  final String paymentId;
  final String reason;
  final bool idempotent;
  final Map<String, dynamic> summary;

  factory PaymentReversalResult.fromJson(Map<String, dynamic> json) {
    return PaymentReversalResult(
      reversalId: json['reversion_id']?.toString() ?? '',
      paymentId: json['pago_cliente_id']?.toString() ?? '',
      reason: json['motivo']?.toString() ?? '',
      idempotent: json['idempotent'] == true,
      summary: Map<String, dynamic>.from(
        (json['resumen'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }

  int get membershipsPending =>
      (summary['membresias_pendientes'] as List?)?.length ?? 0;
  int get commissionsVoided =>
      (summary['devengos_anulados'] as num?)?.toInt() ?? 0;
}
