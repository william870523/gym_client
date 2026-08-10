double _periodMoney(dynamic value) =>
    double.tryParse(value?.toString() ?? '') ?? 0;

class TreasuryPeriodRequest {
  const TreasuryPeriodRequest({
    required this.from,
    required this.to,
    required this.type,
    this.currencyId,
    this.accountId,
  });

  final String from;
  final String to;
  final String type;
  final String? currencyId;
  final String? accountId;

  @override
  bool operator ==(Object other) =>
      other is TreasuryPeriodRequest &&
      other.from == from &&
      other.to == to &&
      other.type == type &&
      other.currencyId == currencyId &&
      other.accountId == accountId;

  @override
  int get hashCode => Object.hash(from, to, type, currencyId, accountId);
}

class TreasuryPeriodSummaryModel {
  const TreasuryPeriodSummaryModel({
    required this.origin,
    required this.type,
    required this.from,
    required this.to,
    required this.dayCount,
    required this.timezone,
    required this.currencies,
    required this.days,
    required this.payments,
    required this.blockers,
    required this.closeState,
    required this.readyToSign,
    required this.canSign,
    required this.canReopen,
    this.activeCycle,
  });

  final String origin;
  final String type;
  final String from;
  final String to;
  final int dayCount;
  final String timezone;
  final List<TreasuryPeriodCurrencyModel> currencies;
  final List<TreasuryPeriodDayModel> days;
  final List<TreasuryPeriodPaymentModel> payments;
  final List<TreasuryPeriodBlockerModel> blockers;
  final String closeState;
  final bool readyToSign;
  final bool canSign;
  final bool canReopen;
  final TreasuryPeriodCycleModel? activeCycle;

  factory TreasuryPeriodSummaryModel.fromJson(Map<String, dynamic> json) {
    final close = Map<String, dynamic>.from(
      json['cierre_periodo'] as Map? ?? const <String, dynamic>{},
    );
    final capabilities = Map<String, dynamic>.from(
      close['capacidades'] as Map? ?? const <String, dynamic>{},
    );
    final cycle = close['ciclo_activo'];
    return TreasuryPeriodSummaryModel(
      origin: json['origen_cierre'] as String? ?? 'PERIODO',
      type: json['tipo_periodo'] as String? ?? '',
      from: json['desde'] as String? ?? '',
      to: json['hasta'] as String? ?? '',
      dayCount: (json['dias_cantidad'] as num?)?.toInt() ?? 0,
      timezone: json['timezone'] as String? ?? '',
      currencies: (json['resumen_monedas'] as List? ?? const [])
          .map(
            (item) => TreasuryPeriodCurrencyModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      days: (json['dias'] as List? ?? const [])
          .map(
            (item) => TreasuryPeriodDayModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      payments: (json['pagos'] as List? ?? const [])
          .map(
            (item) => TreasuryPeriodPaymentModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      blockers: (json['bloqueadores'] as List? ?? const [])
          .map(
            (item) => TreasuryPeriodBlockerModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      closeState: close['estado'] as String? ?? 'ABIERTO',
      readyToSign: close['listo_para_firmar'] as bool? ?? false,
      canSign: capabilities['puede_firmar'] as bool? ?? false,
      canReopen: capabilities['puede_reabrir'] as bool? ?? false,
      activeCycle: cycle is Map
          ? TreasuryPeriodCycleModel.fromJson(Map<String, dynamic>.from(cycle))
          : null,
    );
  }
}

class TreasuryPeriodBlockerModel {
  const TreasuryPeriodBlockerModel({required this.code, required this.count});

  final String code;
  final int count;

  factory TreasuryPeriodBlockerModel.fromJson(Map<String, dynamic> json) =>
      TreasuryPeriodBlockerModel(
        code: json['codigo'] as String? ?? '',
        count: (json['cantidad'] as num?)?.toInt() ?? 0,
      );
}

class TreasuryPeriodCurrencyModel {
  const TreasuryPeriodCurrencyModel({
    required this.id,
    required this.code,
    required this.gross,
    required this.change,
    required this.annulled,
    required this.netCollected,
    required this.netFlow,
    required this.paymentCount,
    required this.clientCount,
    required this.coverage,
    required this.unattributed,
    required this.accounts,
    required this.collectors,
  });

  final String id;
  final String code;
  final double gross;
  final double change;
  final double annulled;
  final double netCollected;
  final double netFlow;
  final int paymentCount;
  final int clientCount;
  final double coverage;
  final double unattributed;
  final List<TreasuryPeriodAccountModel> accounts;
  final List<TreasuryPeriodCollectorModel> collectors;

  factory TreasuryPeriodCurrencyModel.fromJson(Map<String, dynamic> json) =>
      TreasuryPeriodCurrencyModel(
        id: json['moneda_id'] as String? ?? '',
        code: json['codigo'] as String? ?? '',
        gross: _periodMoney(json['cobro_bruto']),
        change: _periodMoney(json['cambio_entregado']),
        annulled: _periodMoney(json['anulaciones']),
        netCollected: _periodMoney(json['cobro_neto']),
        netFlow: _periodMoney(json['flujo_neto']),
        paymentCount: (json['cobros_cantidad_distinta'] as num?)?.toInt() ?? 0,
        clientCount: (json['clientes_cantidad_distinta'] as num?)?.toInt() ?? 0,
        coverage: (json['cobertura_diaria'] as num?)?.toDouble() ?? 0,
        unattributed: _periodMoney(json['sin_atribuir_importe']),
        accounts: (json['cuentas'] as List? ?? const [])
            .map(
              (item) => TreasuryPeriodAccountModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
        collectors: (json['cobradores'] as List? ?? const [])
            .map(
              (item) => TreasuryPeriodCollectorModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
      );
}

class TreasuryPeriodAccountModel {
  const TreasuryPeriodAccountModel({
    required this.id,
    required this.name,
    required this.activityDays,
    required this.closedDays,
    required this.entries,
    required this.exits,
    required this.net,
  });

  final String id;
  final String name;
  final int activityDays;
  final int closedDays;
  final double entries;
  final double exits;
  final double net;

  factory TreasuryPeriodAccountModel.fromJson(Map<String, dynamic> json) =>
      TreasuryPeriodAccountModel(
        id: json['cuenta_id'] as String? ?? '',
        name: json['nombre'] as String? ?? '',
        activityDays: (json['dias_actividad'] as num?)?.toInt() ?? 0,
        closedDays: (json['dias_cerrados'] as num?)?.toInt() ?? 0,
        entries: _periodMoney(json['entradas']),
        exits: _periodMoney(json['salidas']),
        net: _periodMoney(json['neto']),
      );
}

class TreasuryPeriodCollectorModel {
  const TreasuryPeriodCollectorModel({
    this.userId,
    required this.name,
    this.role,
    required this.paymentCount,
    required this.clientCount,
    required this.gross,
    required this.change,
    required this.annulled,
    required this.net,
  });

  final String? userId;
  final String name;
  final String? role;
  final int paymentCount;
  final int clientCount;
  final double gross;
  final double change;
  final double annulled;
  final double net;

  factory TreasuryPeriodCollectorModel.fromJson(Map<String, dynamic> json) =>
      TreasuryPeriodCollectorModel(
        userId: json['user_id'] as String?,
        name: json['nombre'] as String? ?? 'Sin atribuir · histórico',
        role: json['rol'] as String?,
        paymentCount: (json['cobros_cantidad_distinta'] as num?)?.toInt() ?? 0,
        clientCount: (json['clientes_cantidad_distinta'] as num?)?.toInt() ?? 0,
        gross: _periodMoney(json['cobro_bruto']),
        change: _periodMoney(json['cambio_entregado']),
        annulled: _periodMoney(json['anulaciones']),
        net: _periodMoney(json['cobro_neto']),
      );
}

class TreasuryPeriodDayModel {
  const TreasuryPeriodDayModel({
    required this.businessDate,
    required this.currencies,
    required this.closeIds,
  });

  final String businessDate;
  final List<TreasuryPeriodDayCurrencyModel> currencies;
  final List<String> closeIds;

  factory TreasuryPeriodDayModel.fromJson(Map<String, dynamic> json) =>
      TreasuryPeriodDayModel(
        businessDate: json['fecha_negocio'] as String? ?? '',
        currencies: (json['monedas'] as List? ?? const [])
            .map(
              (item) => TreasuryPeriodDayCurrencyModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
        closeIds: (json['cierre_ids'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
      );
}

class TreasuryPeriodDayCurrencyModel {
  const TreasuryPeriodDayCurrencyModel({
    required this.currencyId,
    required this.code,
    required this.entries,
    required this.exits,
    required this.net,
  });

  final String currencyId;
  final String code;
  final double entries;
  final double exits;
  final double net;

  factory TreasuryPeriodDayCurrencyModel.fromJson(Map<String, dynamic> json) =>
      TreasuryPeriodDayCurrencyModel(
        currencyId: json['moneda_id'] as String? ?? '',
        code: json['codigo'] as String? ?? '',
        entries: _periodMoney(json['entradas']),
        exits: _periodMoney(json['salidas']),
        net: _periodMoney(json['neto']),
      );
}

class TreasuryPeriodPaymentModel {
  const TreasuryPeriodPaymentModel({
    required this.id,
    required this.occurredAtUtc,
    required this.clientId,
    this.planCode,
    this.installment,
    required this.collectorName,
    this.annulledBy,
    required this.details,
  });

  final String id;
  final String occurredAtUtc;
  final String clientId;
  final String? planCode;
  final String? installment;
  final String collectorName;
  final String? annulledBy;
  final List<TreasuryPeriodPaymentDetailModel> details;

  factory TreasuryPeriodPaymentModel.fromJson(Map<String, dynamic> json) {
    final collector = Map<String, dynamic>.from(
      json['cobrador'] as Map? ?? const <String, dynamic>{},
    );
    final reversal = json['reverso'];
    return TreasuryPeriodPaymentModel(
      id: json['pago_cliente_id'] as String? ?? '',
      occurredAtUtc: json['ocurrido_at_utc']?.toString() ?? '',
      clientId: json['ci'] as String? ?? '',
      planCode: json['plan_codigo'] as String?,
      installment: json['cuota']?.toString(),
      collectorName:
          collector['nombre'] as String? ?? 'Sin atribuir · histórico',
      annulledBy: reversal is Map
          ? Map<String, dynamic>.from(reversal)['anulado_por_nombre'] as String?
          : null,
      details: (json['detalles'] as List? ?? const [])
          .map(
            (item) => TreasuryPeriodPaymentDetailModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}

class TreasuryPeriodPaymentDetailModel {
  const TreasuryPeriodPaymentDetailModel({
    required this.id,
    required this.accountId,
    required this.currencyId,
    required this.direction,
    required this.amount,
    required this.originType,
    required this.paymentTypeId,
  });

  final String id;
  final String accountId;
  final String currencyId;
  final String direction;
  final double amount;
  final String originType;
  final String paymentTypeId;

  factory TreasuryPeriodPaymentDetailModel.fromJson(
    Map<String, dynamic> json,
  ) => TreasuryPeriodPaymentDetailModel(
    id: json['movimiento_id'] as String? ?? '',
    accountId: json['cuenta_id'] as String? ?? '',
    currencyId: json['moneda_id'] as String? ?? '',
    direction: json['direccion'] as String? ?? '',
    amount: _periodMoney(json['monto']),
    originType: json['origen_tipo'] as String? ?? '',
    paymentTypeId: json['tipo_pago_id'] as String? ?? '',
  );
}

class TreasuryPeriodCycleModel {
  const TreasuryPeriodCycleModel({
    required this.id,
    required this.type,
    required this.from,
    required this.to,
    required this.cycleNumber,
    required this.state,
    required this.closeReason,
    required this.closerName,
    required this.closerRole,
    required this.closedAt,
    required this.hash,
    required this.hashVerified,
    required this.integrityState,
    this.reopenReason,
    this.reopenerName,
    this.reopenedAt,
  });

  final String id;
  final String type;
  final String from;
  final String to;
  final int cycleNumber;
  final String state;
  final String closeReason;
  final String closerName;
  final String closerRole;
  final String closedAt;
  final String hash;
  final bool hashVerified;
  final String integrityState;
  final String? reopenReason;
  final String? reopenerName;
  final String? reopenedAt;

  factory TreasuryPeriodCycleModel.fromJson(Map<String, dynamic> json) =>
      TreasuryPeriodCycleModel(
        id: json['cierre_periodo_id'] as String? ?? '',
        type: json['tipo_periodo'] as String? ?? '',
        from: json['desde'] as String? ?? '',
        to: json['hasta'] as String? ?? '',
        cycleNumber: (json['ciclo_numero'] as num?)?.toInt() ?? 0,
        state: json['estado'] as String? ?? '',
        closeReason: json['motivo_cierre'] as String? ?? '',
        closerName: json['cerrado_por_nombre'] as String? ?? '',
        closerRole: json['cerrado_por_rol'] as String? ?? '',
        closedAt: json['cerrado_at']?.toString() ?? '',
        hash: json['snapshot_sha256'] as String? ?? '',
        hashVerified: json['integridad_hash'] as bool? ?? false,
        integrityState: json['estado_integridad'] as String? ?? '',
        reopenReason: json['reapertura_motivo'] as String?,
        reopenerName: json['reabierto_por_nombre'] as String?,
        reopenedAt: json['reabierto_at']?.toString(),
      );
}

class TreasuryPeriodCyclesModel {
  const TreasuryPeriodCyclesModel({required this.cycles});

  final List<TreasuryPeriodCycleModel> cycles;

  factory TreasuryPeriodCyclesModel.fromJson(Map<String, dynamic> json) =>
      TreasuryPeriodCyclesModel(
        cycles: (json['cierres'] as List? ?? const [])
            .map(
              (item) => TreasuryPeriodCycleModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
      );
}
