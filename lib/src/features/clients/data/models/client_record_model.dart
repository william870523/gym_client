class ClientRecordModel {
  const ClientRecordModel({
    required this.client,
    required this.memberships,
    required this.unlinkedPayments,
    required this.totalsByCurrency,
  });

  final ClientRecordIdentity client;
  final List<ClientMembershipRecord> memberships;
  final List<ClientRecordPayment> unlinkedPayments;
  final List<ClientCurrencyTotal> totalsByCurrency;

  factory ClientRecordModel.fromJson(Map<String, dynamic> json) {
    return ClientRecordModel(
      client: ClientRecordIdentity.fromJson(_map(json['cliente'])),
      memberships: _list(
        json['membresias'],
      ).map((item) => ClientMembershipRecord.fromJson(_map(item))).toList(),
      unlinkedPayments: _list(
        json['pagos_sin_membresia'],
      ).map((item) => ClientRecordPayment.fromJson(_map(item))).toList(),
      totalsByCurrency: _list(
        json['totales_por_moneda'],
      ).map((item) => ClientCurrencyTotal.fromJson(_map(item))).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'cliente': client.toJson(),
    'membresias': memberships.map((item) => item.toJson()).toList(),
    'pagos_sin_membresia': unlinkedPayments
        .map((item) => item.toJson())
        .toList(),
    'totales_por_moneda': totalsByCurrency
        .map((item) => item.toJson())
        .toList(),
  };
}

class ClientRecordIdentity {
  const ClientRecordIdentity({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.categoria,
  });

  final String id;
  final String firstName;
  final String lastName;
  // H1: categoría del cliente (NUEVO/VIEJO). Llega del expediente (corte 1).
  final String? categoria;

  String get fullName => '$firstName $lastName'.trim();

  factory ClientRecordIdentity.fromJson(Map<String, dynamic> json) =>
      ClientRecordIdentity(
        id: _requiredString(json, 'ci'),
        firstName: '${json['nombres'] ?? ''}',
        lastName: '${json['apellidos'] ?? ''}',
        categoria: _nullableString(json['categoria']),
      );

  Map<String, dynamic> toJson() => {
    'ci': id,
    'nombres': firstName,
    'apellidos': lastName,
    if (categoria != null) 'categoria': categoria,
  };
}

class ClientMembershipRecord {
  const ClientMembershipRecord({
    required this.id,
    required this.planId,
    required this.planName,
    required this.price,
    required this.currencyId,
    this.currencyCode,
    this.currencySymbol,
    required this.durationDays,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.origin,
    required this.paidAmount,
    this.activatedAt,
    required this.reconstructed,
    this.reconstructionConfidence,
    this.pauses = const [],
    this.requests = const [],
    required this.trainers,
    required this.payments,
  });

  final String id;
  final String planId;
  final String planName;
  final double price;
  final String currencyId;
  final String? currencyCode;
  final String? currencySymbol;
  final int durationDays;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String origin;
  final double paidAmount;
  final DateTime? activatedAt;
  final bool reconstructed;
  final String? reconstructionConfidence;
  final List<ClientMembershipPause> pauses;
  final List<ClientMembershipRequest> requests;
  final List<ClientTrainerAssignment> trainers;
  final List<ClientRecordPayment> payments;

  factory ClientMembershipRecord.fromJson(Map<String, dynamic> json) =>
      ClientMembershipRecord(
        id: _requiredString(json, 'membresia_id'),
        planId: _requiredString(json, 'id_planes_pago'),
        planName: _requiredString(json, 'plan_nombre'),
        price: _double(json['precio']),
        currencyId: _requiredString(json, 'moneda_id'),
        currencyCode: _nullableString(json['moneda_codigo']),
        currencySymbol: _nullableString(json['moneda_simbolo']),
        durationDays: _int(json['duracion_dias']),
        startDate: _date(json['fecha_inicio']),
        endDate: _date(json['fecha_fin']),
        status: _requiredString(json, 'estado'),
        origin: _requiredString(json, 'origen'),
        paidAmount: _double(json['importe_pagado']),
        activatedAt: _nullableDate(json['activada_at']),
        reconstructed: json['reconstruida'] == true,
        reconstructionConfidence: _nullableString(
          json['confianza_reconstruccion'],
        ),
        pauses: _list(
          json['pausas'],
        ).map((item) => ClientMembershipPause.fromJson(_map(item))).toList(),
        requests: _list(
          json['solicitudes'],
        ).map((item) => ClientMembershipRequest.fromJson(_map(item))).toList(),
        trainers: _list(
          json['entrenadores'],
        ).map((item) => ClientTrainerAssignment.fromJson(_map(item))).toList(),
        payments: _list(
          json['pagos'],
        ).map((item) => ClientRecordPayment.fromJson(_map(item))).toList(),
      );

  Map<String, dynamic> toJson() => {
    'membresia_id': id,
    'id_planes_pago': planId,
    'plan_nombre': planName,
    'precio': price.toStringAsFixed(2),
    'moneda_id': currencyId,
    'moneda_codigo': currencyCode,
    'moneda_simbolo': currencySymbol,
    'duracion_dias': durationDays,
    'fecha_inicio': startDate.toUtc().toIso8601String(),
    'fecha_fin': endDate.toUtc().toIso8601String(),
    'estado': status,
    'origen': origin,
    'importe_pagado': paidAmount.toStringAsFixed(2),
    'activada_at': activatedAt?.toUtc().toIso8601String(),
    'reconstruida': reconstructed,
    'confianza_reconstruccion': reconstructionConfidence,
    'pausas': pauses.map((item) => item.toJson()).toList(),
    'solicitudes': requests.map((item) => item.toJson()).toList(),
    'entrenadores': trainers.map((item) => item.toJson()).toList(),
    'pagos': payments.map((item) => item.toJson()).toList(),
  };
}

class ClientMembershipRequest {
  const ClientMembershipRequest({
    required this.id,
    required this.membershipId,
    required this.clientId,
    required this.kind,
    required this.reason,
    required this.status,
    required this.requestedEffectiveDate,
    this.appliedEffectiveDate,
    required this.estimatedRemainingDays,
    this.appliedRemainingDays,
    this.estimatedEndDate,
    this.resultingEndDate,
    required this.requesterUserId,
    required this.requesterName,
    required this.requestedAt,
    this.deciderUserId,
    this.deciderName,
    this.decisionReason,
    this.decidedAt,
    this.clientName,
    this.planName,
    this.membershipStatus,
  });

  final String id;
  final String membershipId;
  final String clientId;
  final String kind;
  final String reason;
  final String status;
  final DateTime requestedEffectiveDate;
  final DateTime? appliedEffectiveDate;
  final int estimatedRemainingDays;
  final int? appliedRemainingDays;
  final DateTime? estimatedEndDate;
  final DateTime? resultingEndDate;
  final String requesterUserId;
  final String requesterName;
  final DateTime requestedAt;
  final String? deciderUserId;
  final String? deciderName;
  final String? decisionReason;
  final DateTime? decidedAt;
  final String? clientName;
  final String? planName;
  final String? membershipStatus;

  bool get isPending => status == 'PENDIENTE';
  bool get isPause => kind == 'PAUSAR';

  factory ClientMembershipRequest.fromJson(Map<String, dynamic> json) {
    final client = json['client'] is Map ? _map(json['client']) : null;
    final membership = json['membership'] is Map
        ? _map(json['membership'])
        : null;
    final firstName = client == null ? '' : '${client['nombres'] ?? ''}'.trim();
    final lastName = client == null
        ? ''
        : '${client['apellidos'] ?? ''}'.trim();
    final fullName = '$firstName $lastName'.trim();
    return ClientMembershipRequest(
      id: _requiredString(json, 'solicitud_id'),
      membershipId: _requiredString(json, 'membresia_id'),
      clientId: _requiredString(json, 'ci'),
      kind: _requiredString(json, 'tipo'),
      reason: _requiredString(json, 'motivo'),
      status: _requiredString(json, 'estado'),
      requestedEffectiveDate: _date(json['fecha_efectiva_solicitada']),
      appliedEffectiveDate: _nullableDate(json['fecha_efectiva_aplicada']),
      estimatedRemainingDays: _int(json['dias_restantes_estimados']),
      appliedRemainingDays: json['dias_restantes_aplicados'] == null
          ? null
          : _int(json['dias_restantes_aplicados']),
      estimatedEndDate: _nullableDate(json['fecha_fin_estimada']),
      resultingEndDate: _nullableDate(json['fecha_fin_resultante']),
      requesterUserId: _requiredString(json, 'solicitada_por_user_id'),
      requesterName:
          _nullableString(json['solicitada_por_nombre']) ??
          _nullableString(json['solicitada_por_nombre_snapshot']) ??
          'Cuenta ${json['solicitada_por_user_id']}',
      requestedAt: _date(json['solicitada_at']),
      deciderUserId: _nullableString(json['decidida_por_user_id']),
      deciderName:
          _nullableString(json['decidida_por_nombre']) ??
          _nullableString(json['decidida_por_nombre_snapshot']),
      decisionReason: _nullableString(json['decision_motivo']),
      decidedAt: _nullableDate(json['decidida_at']),
      clientName: fullName.isEmpty ? null : fullName,
      planName: membership == null
          ? null
          : _nullableString(membership['plan_nombre_snapshot']),
      membershipStatus: membership == null
          ? null
          : _nullableString(membership['estado']),
    );
  }

  Map<String, dynamic> toJson() => {
    'solicitud_id': id,
    'membresia_id': membershipId,
    'ci': clientId,
    'tipo': kind,
    'motivo': reason,
    'estado': status,
    'fecha_efectiva_solicitada': requestedEffectiveDate
        .toUtc()
        .toIso8601String(),
    'fecha_efectiva_aplicada': appliedEffectiveDate?.toUtc().toIso8601String(),
    'dias_restantes_estimados': estimatedRemainingDays,
    'dias_restantes_aplicados': appliedRemainingDays,
    'fecha_fin_estimada': estimatedEndDate?.toUtc().toIso8601String(),
    'fecha_fin_resultante': resultingEndDate?.toUtc().toIso8601String(),
    'solicitada_por_user_id': requesterUserId,
    'solicitada_por_nombre': requesterName,
    'solicitada_at': requestedAt.toUtc().toIso8601String(),
    'decidida_por_user_id': deciderUserId,
    'decidida_por_nombre': deciderName,
    'decision_motivo': decisionReason,
    'decidida_at': decidedAt?.toUtc().toIso8601String(),
  };
}

class ClientMembershipPause {
  const ClientMembershipPause({
    required this.id,
    required this.pauseDate,
    this.resumeDate,
    required this.previousEndDate,
    this.recalculatedEndDate,
    required this.remainingDays,
    required this.reason,
    required this.status,
    required this.pausedAt,
    this.resumedAt,
  });

  final String id;
  final DateTime pauseDate;
  final DateTime? resumeDate;
  final DateTime previousEndDate;
  final DateTime? recalculatedEndDate;
  final int remainingDays;
  final String reason;
  final String status;
  final DateTime pausedAt;
  final DateTime? resumedAt;

  bool get isActive => status == 'ACTIVA' && resumeDate == null;

  factory ClientMembershipPause.fromJson(Map<String, dynamic> json) =>
      ClientMembershipPause(
        id: _requiredString(json, 'pausa_id'),
        pauseDate: _date(json['fecha_pausa']),
        resumeDate: _nullableDate(json['fecha_reanudacion']),
        previousEndDate: _date(json['fecha_fin_anterior']),
        recalculatedEndDate: _nullableDate(json['fecha_fin_recalculada']),
        remainingDays: _int(json['dias_restantes']),
        reason: _requiredString(json, 'motivo'),
        status: _requiredString(json, 'estado'),
        pausedAt: _date(json['pausada_at']),
        resumedAt: _nullableDate(json['reanudada_at']),
      );

  Map<String, dynamic> toJson() => {
    'pausa_id': id,
    'fecha_pausa': pauseDate.toUtc().toIso8601String(),
    'fecha_reanudacion': resumeDate?.toUtc().toIso8601String(),
    'fecha_fin_anterior': previousEndDate.toUtc().toIso8601String(),
    'fecha_fin_recalculada': recalculatedEndDate?.toUtc().toIso8601String(),
    'dias_restantes': remainingDays,
    'motivo': reason,
    'estado': status,
    'pausada_at': pausedAt.toUtc().toIso8601String(),
    'reanudada_at': resumedAt?.toUtc().toIso8601String(),
  };
}

class ClientTrainerAssignment {
  const ClientTrainerAssignment({
    required this.id,
    required this.trainerId,
    this.trainerName,
    required this.startDate,
    this.endDate,
    required this.status,
    this.closeReason,
  });

  final String id;
  final String trainerId;
  final String? trainerName;
  final DateTime startDate;
  final DateTime? endDate;
  final String status;
  final String? closeReason;

  factory ClientTrainerAssignment.fromJson(Map<String, dynamic> json) =>
      ClientTrainerAssignment(
        id: _requiredString(json, 'asignacion_id'),
        trainerId: _requiredString(json, 'id_entrenador'),
        trainerName: _nullableString(json['entrenador_nombre']),
        startDate: _date(json['fecha_inicio']),
        endDate: _nullableDate(json['fecha_fin']),
        status: _requiredString(json, 'estado'),
        closeReason: _nullableString(json['motivo_cierre']),
      );

  Map<String, dynamic> toJson() => {
    'asignacion_id': id,
    'id_entrenador': trainerId,
    'entrenador_nombre': trainerName,
    'fecha_inicio': startDate.toUtc().toIso8601String(),
    'fecha_fin': endDate?.toUtc().toIso8601String(),
    'estado': status,
    'motivo_cierre': closeReason,
  };
}

class ClientRecordPayment {
  const ClientRecordPayment({
    required this.id,
    required this.date,
    required this.total,
    required this.currencyId,
    this.currencyCode,
    this.currencySymbol,
    required this.planId,
    this.trainerId,
    this.applicationId,
    this.appliedAmount,
    this.isVoided = false,
    this.voidedAt,
    this.details = const [],
    // H1: instantánea de descuento congelada al cobrar.
    this.listPrice,
    this.discountPct,
    this.discountAmount,
    this.clientCategory,
    // H3: código de plan + sufijo de cuota.
    this.planCode,
    this.installmentSuffix,
    // H5: cobrador congelado (R5.6).
    this.collectorUserId,
    this.collectorName,
    this.collectorRole,
    this.collectorOrigin,
  });

  final String id;
  final DateTime date;
  final double total;
  final String currencyId;
  final String? currencyCode;
  final String? currencySymbol;
  final String planId;
  final String? trainerId;
  final String? applicationId;
  final double? appliedAmount;
  final bool isVoided;
  final DateTime? voidedAt;
  final List<ClientRecordPaymentDetail> details;
  // H1: instantánea de descuento congelada al cobrar.
  final double? listPrice;
  final String? discountPct;
  final double? discountAmount;
  final String? clientCategory;
  // H3: código de plan + sufijo de cuota.
  final String? planCode;
  final String? installmentSuffix;
  // H5: cobrador congelado (R5.6).
  final String? collectorUserId;
  final String? collectorName;
  final String? collectorRole;
  final String? collectorOrigin;

  factory ClientRecordPayment.fromJson(Map<String, dynamic> json) =>
      ClientRecordPayment(
        id: _requiredString(json, 'pago_cliente_id'),
        date: _date(json['fecha']),
        total: _double(json['monto_total']),
        currencyId: _requiredString(json, 'moneda_id'),
        currencyCode: _nullableString(json['moneda_codigo']),
        currencySymbol: _nullableString(json['moneda_simbolo']),
        planId: _requiredString(json, 'id_planes_pago'),
        trainerId: _nullableString(json['id_entrenador']),
        applicationId: _nullableString(json['aplicacion_id']),
        appliedAmount: json['monto_aplicado'] == null
            ? null
            : _double(json['monto_aplicado']),
        isVoided: json['is_deleted'] == true,
        voidedAt: json['deleted_at'] == null ? null : _date(json['deleted_at']),
        details: _list(json['detalles'])
            .map((item) => ClientRecordPaymentDetail.fromJson(_map(item)))
            .toList(),
        // H1: snapshots de descuento.
        listPrice: json['precio_lista_snapshot'] == null
            ? null
            : _double(json['precio_lista_snapshot']),
        discountPct: _nullableString(json['descuento_pct_snapshot']),
        discountAmount: json['descuento_monto_snapshot'] == null
            ? null
            : _double(json['descuento_monto_snapshot']),
        clientCategory: _nullableString(json['categoria_cliente_snapshot']),
        // H3: código + sufijo.
        planCode: _nullableString(json['plan_codigo_snapshot']),
        installmentSuffix: _nullableString(json['cuota_sufijo_snapshot']),
        // H5: cobrador.
        collectorUserId: _nullableString(json['cobrado_por_user_id']),
        collectorName: _nullableString(json['cobrado_por_nombre_snapshot']),
        collectorRole: _nullableString(json['cobrado_por_rol_snapshot']),
        collectorOrigin: _nullableString(json['cobrado_por_origen']),
      );

  Map<String, dynamic> toJson() => {
    'pago_cliente_id': id,
    'fecha': date.toUtc().toIso8601String(),
    'monto_total': total.toStringAsFixed(2),
    'moneda_id': currencyId,
    'moneda_codigo': currencyCode,
    'moneda_simbolo': currencySymbol,
    'id_planes_pago': planId,
    'id_entrenador': trainerId,
    'aplicacion_id': applicationId,
    'monto_aplicado': appliedAmount?.toStringAsFixed(2),
    'is_deleted': isVoided,
    'deleted_at': voidedAt?.toUtc().toIso8601String(),
    'detalles': details.map((item) => item.toJson()).toList(),
    'precio_lista_snapshot': listPrice?.toStringAsFixed(2),
    'descuento_pct_snapshot': discountPct,
    'descuento_monto_snapshot': discountAmount?.toStringAsFixed(2),
    'categoria_cliente_snapshot': clientCategory,
    'plan_codigo_snapshot': planCode,
    'cuota_sufijo_snapshot': installmentSuffix,
    'cobrado_por_user_id': collectorUserId,
    'cobrado_por_nombre_snapshot': collectorName,
    'cobrado_por_rol_snapshot': collectorRole,
    'cobrado_por_origen': collectorOrigin,
  };
}

class ClientRecordPaymentDetail {
  const ClientRecordPaymentDetail({
    required this.id,
    required this.paymentTypeId,
    this.paymentTypeName,
    this.accountId,
    this.accountName,
    required this.currencyId,
    this.currencyCode,
    this.currencySymbol,
    required this.amount,
    this.exchangeRateId,
    this.exchangeRate,
    this.exchangeRateBaseCurrencyId,
    this.exchangeRateTargetCurrencyId,
  });

  final String id;
  final String paymentTypeId;
  final String? paymentTypeName;
  final String? accountId;
  final String? accountName;
  final String currencyId;
  final String? currencyCode;
  final String? currencySymbol;
  final double amount;
  final String? exchangeRateId;
  final double? exchangeRate;
  final String? exchangeRateBaseCurrencyId;
  final String? exchangeRateTargetCurrencyId;

  factory ClientRecordPaymentDetail.fromJson(Map<String, dynamic> json) =>
      ClientRecordPaymentDetail(
        id: _requiredString(json, 'detalle_pago_id'),
        paymentTypeId: _requiredString(json, 'tipo_pago_id'),
        paymentTypeName: _nullableString(json['tipo_pago_nombre']),
        accountId: _nullableString(json['cuenta_id']),
        accountName: _nullableString(json['cuenta_nombre']),
        currencyId: _requiredString(json, 'moneda_id'),
        currencyCode: _nullableString(json['moneda_codigo']),
        currencySymbol: _nullableString(json['moneda_simbolo']),
        amount: _double(json['cantidad']),
        exchangeRateId: _nullableString(json['tipo_cambio_id']),
        exchangeRate: json['tipo_cambio_tasa'] == null
            ? null
            : _double(json['tipo_cambio_tasa']),
        exchangeRateBaseCurrencyId: _nullableString(
          json['tipo_cambio_moneda_base_id'],
        ),
        exchangeRateTargetCurrencyId: _nullableString(
          json['tipo_cambio_moneda_target_id'],
        ),
      );

  Map<String, dynamic> toJson() => {
    'detalle_pago_id': id,
    'tipo_pago_id': paymentTypeId,
    'tipo_pago_nombre': paymentTypeName,
    'cuenta_id': accountId,
    'cuenta_nombre': accountName,
    'moneda_id': currencyId,
    'moneda_codigo': currencyCode,
    'moneda_simbolo': currencySymbol,
    'cantidad': amount.toStringAsFixed(4),
    'tipo_cambio_id': exchangeRateId,
    'tipo_cambio_tasa': exchangeRate,
    'tipo_cambio_moneda_base_id': exchangeRateBaseCurrencyId,
    'tipo_cambio_moneda_target_id': exchangeRateTargetCurrencyId,
  };
}

class ClientCurrencyTotal {
  const ClientCurrencyTotal({
    required this.currencyId,
    this.currencyName,
    this.code,
    this.symbol,
    required this.amount,
    required this.paymentCount,
  });

  final String currencyId;
  final String? currencyName;
  final String? code;
  final String? symbol;
  final double amount;
  final int paymentCount;

  factory ClientCurrencyTotal.fromJson(Map<String, dynamic> json) =>
      ClientCurrencyTotal(
        currencyId: _requiredString(json, 'moneda_id'),
        currencyName: _nullableString(json['moneda_nombre']),
        code: _nullableString(json['codigo']),
        symbol: _nullableString(json['simbolo']),
        amount: _double(json['monto_total']),
        paymentCount: _int(json['cantidad_pagos']),
      );

  Map<String, dynamic> toJson() => {
    'moneda_id': currencyId,
    'moneda_nombre': currencyName,
    'codigo': code,
    'simbolo': symbol,
    'monto_total': amount.toStringAsFixed(2),
    'cantidad_pagos': paymentCount,
  };
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('El expediente contiene un objeto inválido.');
}

List<dynamic> _list(Object? value) => value is List ? value : const [];

String _requiredString(Map<String, dynamic> json, String key) {
  final value = '${json[key] ?? ''}'.trim();
  if (value.isEmpty) throw FormatException('Falta el campo $key.');
  return value;
}

String? _nullableString(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}

double _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.parse('$value');
}

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.parse('$value');
}

DateTime _date(Object? value) {
  final parsed = DateTime.tryParse('$value');
  if (parsed == null) throw FormatException('Fecha inválida: $value');
  return parsed.toUtc();
}

DateTime? _nullableDate(Object? value) => value == null ? null : _date(value);
