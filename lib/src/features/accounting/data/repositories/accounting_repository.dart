import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../models/accounting_models.dart';
import '../models/accrual_operating_result_models.dart';
import '../models/exchange_revaluation_models.dart';
import '../models/management_margin_annual_models.dart';
import '../models/management_margin_models.dart';
import '../models/membership_revenue_models.dart';
import '../models/operational_annual_results_models.dart';
import '../models/operational_results_models.dart';
import '../models/recurring_expense_models.dart';
import '../models/trainer_service_cost_models.dart';

final accountingRepositoryProvider = Provider<AccountingRepository>((ref) {
  return AccountingRepository(ref.watch(apiClientProvider));
});

class AccountingRepository {
  final Dio _dio;

  AccountingRepository(this._dio);

  Future<AccountingSummaryModel> getSummary() async {
    final response = await _dio.get('/contabilidad/summary');
    return AccountingSummaryModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<TrainerCommissionInstallmentModel>> getTrainerInstallments({
    String? status,
  }) async {
    final response = await _dio.get(
      '/contabilidad/trainer-installments',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'estado': status,
      },
    );
    return (response.data as List)
        .map(
          (item) => TrainerCommissionInstallmentModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<List<TrainerPayableModel>> getTrainerPayables({String? status}) async {
    final response = await _dio.get(
      '/contabilidad/trainer-payables',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'estado': status,
      },
    );
    return (response.data as List)
        .map(
          (item) => TrainerPayableModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<List<TrainerCommissionRuleModel>> getTrainerRules() async {
    final response = await _dio.get('/contabilidad/trainer-rules');
    return (response.data as List)
        .map(
          (item) => TrainerCommissionRuleModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> createTrainerRule(Map<String, dynamic> payload) async {
    await _dio.post('/contabilidad/trainer-rules', data: payload);
  }

  Future<void> updateTrainerRule(
    String id,
    Map<String, dynamic> payload,
  ) async {
    await _dio.put('/contabilidad/trainer-rules/$id', data: payload);
  }

  Future<void> deleteTrainerRule(String id) async {
    await _dio.delete('/contabilidad/trainer-rules/$id');
  }

  Future<List<TrainerCompensationProfileModel>>
  getTrainerCompensationProfiles() async {
    final response = await _dio.get(
      '/contabilidad/trainer-compensation-profiles',
    );
    return (response.data as List)
        .map(
          (item) => TrainerCompensationProfileModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> createTrainerCompensationProfile(
    Map<String, dynamic> payload,
  ) async {
    await _dio.post(
      '/contabilidad/trainer-compensation-profiles',
      data: payload,
    );
  }

  Future<void> updateTrainerCompensationProfile(
    String id,
    Map<String, dynamic> payload,
  ) async {
    await _dio.put(
      '/contabilidad/trainer-compensation-profiles/$id',
      data: payload,
    );
  }

  Future<void> deleteTrainerCompensationProfile(String id) async {
    await _dio.delete('/contabilidad/trainer-compensation-profiles/$id');
  }

  Future<List<TrainerFixedObligationModel>> getTrainerFixedObligations({
    String? status,
  }) async {
    final response = await _dio.get(
      '/contabilidad/trainer-fixed-obligations',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'estado': status,
      },
    );
    return (response.data as List)
        .map(
          (item) => TrainerFixedObligationModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> materializeTrainerFixedObligations() async {
    await _dio.post(
      '/contabilidad/trainer-fixed-obligations/materialize',
      data: const <String, dynamic>{},
    );
  }

  Future<TrainerPayoutOptionsModel> getTrainerPayoutOptions() async {
    final response = await _dio.get('/contabilidad/trainer-payout-options');
    return TrainerPayoutOptionsModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<TrainerLiquidationModel>> getTrainerLiquidations() async {
    final response = await _dio.get('/contabilidad/trainer-liquidations');
    return (response.data as List)
        .map(
          (item) => TrainerLiquidationModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<TrainerLiquidationModel> getTrainerLiquidation(String id) async {
    final response = await _dio.get('/contabilidad/trainer-liquidations/$id');
    return TrainerLiquidationModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TrainerLiquidationModel> createTrainerLiquidation({
    required String operationId,
    required String accountId,
    required String paymentTypeId,
    required List<Map<String, dynamic>> applications,
    List<Map<String, dynamic>> fixedApplications = const [],
    String? notes,
  }) async {
    final response = await _dio.post(
      '/contabilidad/trainer-liquidations',
      data: {
        'operacion_id': operationId,
        'cuenta_id': accountId,
        'tipo_pago_id': paymentTypeId,
        'aplicaciones': applications,
        'aplicaciones_fijas': fixedApplications,
        'notas': notes,
      },
    );
    return TrainerLiquidationModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TrainerLiquidationModel> reverseTrainerLiquidation({
    required String id,
    required String operationId,
    required String reason,
  }) async {
    final response = await _dio.post(
      '/contabilidad/trainer-liquidations/$id/reverse',
      data: {'operacion_id': operationId, 'motivo': reason},
    );
    return TrainerLiquidationModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<TreasuryRefundModel>> getTreasuryRefunds() async {
    final response = await _dio.get('/contabilidad/treasury-refunds');
    return (response.data as List)
        .map(
          (item) => TreasuryRefundModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<TreasuryRefundOptionsModel> getTreasuryRefundOptions() async {
    final response = await _dio.get('/contabilidad/treasury-refunds/options');
    return TreasuryRefundOptionsModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TreasuryRefundReceiptModel> decideTreasuryRefund({
    required String adjustmentId,
    required String operationId,
    required String action,
    String? accountId,
    String? paymentTypeId,
    required String reason,
  }) async {
    final response = await _dio.post(
      '/contabilidad/treasury-refunds/$adjustmentId/decision',
      data: {
        'operacion_id': operationId,
        'accion': action,
        'cuenta_id': accountId,
        'tipo_pago_id': paymentTypeId,
        'motivo': reason,
      },
    );
    return TreasuryRefundReceiptModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TreasuryRefundReceiptModel> getTreasuryRefundReceipt(
    String refundId,
  ) async {
    final response = await _dio.get(
      '/contabilidad/treasury-refunds/$refundId/receipt',
    );
    return TreasuryRefundReceiptModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TreasuryRefundReceiptModel> reverseTreasuryRefund({
    required String refundId,
    required String operationId,
    required String reason,
  }) async {
    final response = await _dio.post(
      '/contabilidad/treasury-refunds/$refundId/reverse',
      data: {'operacion_id': operationId, 'motivo': reason},
    );
    return TreasuryRefundReceiptModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TreasuryLedgerModel> getTreasuryLedger({String? businessDate}) async {
    final response = await _dio.get(
      '/contabilidad/treasury-ledger',
      queryParameters: {
        if (businessDate != null && businessDate.isNotEmpty)
          'fecha': businessDate,
      },
    );
    return TreasuryLedgerModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TreasuryMonthlySummaryModel> getTreasuryMonthlySummary({
    String? month,
  }) async {
    final response = await _dio.get(
      '/contabilidad/treasury-monthly-summary',
      queryParameters: {if (month != null && month.isNotEmpty) 'mes': month},
    );
    return TreasuryMonthlySummaryModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<OperationalResultsModel> getOperationalResults({String? month}) async {
    final response = await _dio.get(
      '/contabilidad/operational-results',
      queryParameters: {if (month != null && month.isNotEmpty) 'mes': month},
    );
    return OperationalResultsModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<OperationalAnnualResultsModel> getOperationalAnnualResults({
    String? year,
  }) async {
    final response = await _dio.get(
      '/contabilidad/operational-results/annual',
      queryParameters: {if (year != null && year.isNotEmpty) 'anio': year},
    );
    return OperationalAnnualResultsModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<MembershipRevenueModel> getMembershipRevenue({String? month}) async {
    final response = await _dio.get(
      '/contabilidad/membership-revenue',
      queryParameters: {if (month != null && month.isNotEmpty) 'mes': month},
    );
    return MembershipRevenueModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<ExchangeRevaluationModel> getExchangeRevaluation({
    String? month,
  }) async {
    final response = await _dio.get(
      '/contabilidad/exchange-revaluation',
      queryParameters: {if (month != null && month.isNotEmpty) 'mes': month},
    );
    return ExchangeRevaluationModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TrainerServiceCostModel> getTrainerServiceCost({String? month}) async {
    final response = await _dio.get(
      '/contabilidad/trainer-service-cost',
      queryParameters: {if (month != null && month.isNotEmpty) 'mes': month},
    );
    return TrainerServiceCostModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<ManagementMarginModel> getManagementMargin({String? month}) async {
    final response = await _dio.get(
      '/contabilidad/management-margin',
      queryParameters: {if (month != null && month.isNotEmpty) 'mes': month},
    );
    return ManagementMarginModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<RecurringExpenseModel>> getRecurringExpenses() async {
    final response = await _dio.get('/contabilidad/recurring-expenses');
    return (response.data as List)
        .map(
          (row) => RecurringExpenseModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<RecurringExpenseModel> createRecurringExpense(
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.post(
      '/contabilidad/recurring-expenses',
      data: body,
    );
    return RecurringExpenseModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<RecurringExpenseModel> updateRecurringExpense({
    required String templateId,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.put(
      '/contabilidad/recurring-expenses/$templateId',
      data: body,
    );
    return RecurringExpenseModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<RecurringExpensePlanModel> previewRecurringExpenses({
    String? month,
  }) async {
    final response = await _dio.get(
      '/contabilidad/recurring-expenses/preview',
      queryParameters: {if (month != null && month.isNotEmpty) 'mes': month},
    );
    return RecurringExpensePlanModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<RecurringExpensePlanModel> generateRecurringExpenses({
    String? month,
  }) async {
    final response = await _dio.post(
      '/contabilidad/recurring-expenses/generate',
      data: {if (month != null && month.isNotEmpty) 'mes': month},
    );
    return RecurringExpensePlanModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<AccrualOperatingResultModel> getAccrualOperatingResult({
    String? month,
  }) async {
    final response = await _dio.get(
      '/contabilidad/accrual-operating-result',
      queryParameters: {if (month != null && month.isNotEmpty) 'mes': month},
    );
    return AccrualOperatingResultModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<ManagementMarginAnnualResultsModel> getManagementMarginAnnualResults({
    String? year,
  }) async {
    final response = await _dio.get(
      '/contabilidad/management-margin/annual',
      queryParameters: {if (year != null && year.isNotEmpty) 'anio': year},
    );
    return ManagementMarginAnnualResultsModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TreasuryMonthlySummaryModel> closeTreasuryMonth({
    required String month,
    required String operationId,
    required String reason,
  }) async {
    final response = await _dio.post(
      '/contabilidad/treasury-monthly-closes',
      data: {'mes': month, 'operacion_id': operationId, 'motivo': reason},
    );
    return TreasuryMonthlySummaryModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TreasuryMonthlySummaryModel> reopenTreasuryMonth({
    required String month,
    required String operationId,
    required String reason,
  }) async {
    final response = await _dio.post(
      '/contabilidad/treasury-monthly-closes/reopen',
      data: {'mes': month, 'operacion_id': operationId, 'motivo': reason},
    );
    return TreasuryMonthlySummaryModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TreasuryRefundOptionsModel> getTreasuryManualOptions() async {
    final response = await _dio.get('/contabilidad/treasury-manual-options');
    return TreasuryRefundOptionsModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TreasuryLedgerModel> createTreasuryManualOperation({
    required String operationId,
    required String type,
    required String concept,
    String? description,
    required String evidenceReference,
    required String amount,
    String? originAccountId,
    String? destinationAccountId,
    String? originPaymentTypeId,
    String? destinationPaymentTypeId,
  }) async {
    final response = await _dio.post(
      '/contabilidad/treasury-manual-operations',
      data: {
        'operacion_id': operationId,
        'tipo': type,
        'concepto': concept,
        'descripcion': description,
        'evidencia_referencia': evidenceReference,
        'monto': amount,
        'cuenta_origen_id': originAccountId,
        'cuenta_destino_id': destinationAccountId,
        'tipo_pago_origen_id': originPaymentTypeId,
        'tipo_pago_destino_id': destinationPaymentTypeId,
      },
    );
    return TreasuryLedgerModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TreasuryLedgerModel> closeTreasuryAccount({
    required String operationId,
    required String businessDate,
    required String accountId,
    required String openingBalance,
    required String countedBalance,
    String? varianceReason,
  }) async {
    final response = await _dio.post(
      '/contabilidad/treasury-closes',
      data: {
        'operacion_id': operationId,
        'fecha_negocio': businessDate,
        'cuenta_id': accountId,
        'saldo_inicial': openingBalance,
        'saldo_contado': countedBalance,
        'motivo_diferencia': varianceReason,
      },
    );
    return TreasuryLedgerModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TreasuryLedgerModel> decideTreasuryCloseRequest({
    required String requestId,
    required String operationId,
    required String decision,
    String? reason,
  }) async {
    final response = await _dio.post(
      '/contabilidad/treasury-close-requests/$requestId/decision',
      data: {
        'operacion_id': operationId,
        'decision': decision,
        'motivo': reason,
      },
    );
    return TreasuryLedgerModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TreasuryClosePolicyModel> updateTreasuryClosePolicy({
    required String defaultTolerance,
    required Map<String, String> currencyTolerances,
    required List<String> submitterRoles,
    required List<String> approverRoles,
    required bool allowSelfApproval,
    required bool requireVarianceReason,
  }) async {
    final response = await _dio.put(
      '/contabilidad/treasury-close-policy',
      data: {
        'default_tolerance': defaultTolerance,
        'currency_tolerances': currencyTolerances,
        'submitter_roles': submitterRoles,
        'approver_roles': approverRoles,
        'allow_self_approval': allowSelfApproval,
        'require_reason_for_difference': requireVarianceReason,
      },
    );
    return TreasuryClosePolicyModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TreasuryLedgerModel> reconcileTreasuryClose({
    required String operationId,
    required String closeId,
    required String reason,
    required String evidenceReference,
  }) async {
    final response = await _dio.post(
      '/contabilidad/treasury-reconciliations',
      data: {
        'operacion_id': operationId,
        'cierre_id': closeId,
        'motivo': reason,
        'evidencia_referencia': evidenceReference,
      },
    );
    return TreasuryLedgerModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<GovernedExpensesReportModel> getGovernedExpenses({
    String? month,
  }) async {
    final response = await _dio.get(
      '/contabilidad/governed-expenses',
      queryParameters: {if (month != null && month.isNotEmpty) 'mes': month},
    );
    return GovernedExpensesReportModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<GastoCategoriaModel>> getGovernedExpenseCategories() async {
    final response = await _dio.get(
      '/contabilidad/governed-expense-categories',
    );
    return (response.data as List)
        .map(
          (e) =>
              GastoCategoriaModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<GastoCategoriaModel> createGovernedExpenseCategory(
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.post(
      '/contabilidad/governed-expense-categories',
      data: data,
    );
    return GastoCategoriaModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<GastoProveedorModel>> getGovernedExpenseSuppliers() async {
    final response = await _dio.get('/contabilidad/governed-expense-suppliers');
    return (response.data as List)
        .map(
          (e) =>
              GastoProveedorModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<GastoProveedorModel> createGovernedExpenseSupplier(
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.post(
      '/contabilidad/governed-expense-suppliers',
      data: data,
    );
    return GastoProveedorModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<GastoGobernadoModel> createGovernedExpense(
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.post(
      '/contabilidad/governed-expenses',
      data: data,
    );
    return GastoGobernadoModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<Map<String, dynamic>> payGovernedExpense(
    String gastoId,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.post(
      '/contabilidad/governed-expenses/$gastoId/payments',
      data: data,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> reverseGovernedExpensePayment(
    String aplicacionId,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.post(
      '/contabilidad/governed-expense-payments/$aplicacionId/reversals',
      data: data,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
