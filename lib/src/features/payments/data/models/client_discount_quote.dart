class ClientDiscountQuote {
  const ClientDiscountQuote({
    required this.listPrice,
    required this.discountPct,
    required this.discount,
    required this.finalPrice,
    required this.reason,
    required this.clientCategory,
    required this.planCode,
    required this.planName,
    required this.installmentSuffix,
  });

  final double listPrice;
  final String? discountPct;
  final double discount;
  final double finalPrice;
  final String reason;
  final String clientCategory;
  final String planCode;
  final String planName;
  final String? installmentSuffix;

  factory ClientDiscountQuote.fromJson(Map<String, dynamic> json) {
    double money(String key) => double.parse(json[key].toString());
    return ClientDiscountQuote(
      listPrice: money('precio_lista'),
      discountPct: json['descuento_pct']?.toString(),
      discount: money('descuento'),
      finalPrice: money('precio_final'),
      reason: json['motivo'].toString(),
      clientCategory: json['categoria_cliente'].toString(),
      planCode: json['plan_codigo'].toString(),
      planName: json['plan_nombre'].toString(),
      installmentSuffix: json['cuota_sufijo']?.toString(),
    );
  }
}
