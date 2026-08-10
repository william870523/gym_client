import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/accounting_models.dart';
import '../../data/models/accrual_operating_result_models.dart';
import '../../data/models/exchange_revaluation_models.dart';
import '../../data/models/management_margin_annual_models.dart';
import '../../data/models/management_margin_models.dart';
import '../../data/models/membership_revenue_models.dart';
import '../../data/models/operational_annual_results_models.dart';
import '../../data/models/operational_results_models.dart';
import '../../data/models/recurring_expense_models.dart';
import '../../data/models/trainer_service_cost_models.dart';
import '../../data/models/treasury_period_models.dart';
import '../../data/repositories/accounting_repository.dart';

final accountingSummaryProvider =
    FutureProvider.autoDispose<AccountingSummaryModel>((ref) {
      return ref.watch(accountingRepositoryProvider).getSummary();
    });

final trainerCommissionInstallmentsProvider =
    FutureProvider.autoDispose<List<TrainerCommissionInstallmentModel>>((ref) {
      return ref
          .watch(accountingRepositoryProvider)
          .getTrainerInstallments(status: 'PENDIENTE');
    });

final trainerPayablesProvider =
    FutureProvider.autoDispose<List<TrainerPayableModel>>((ref) {
      return ref
          .watch(accountingRepositoryProvider)
          .getTrainerPayables(status: 'PENDIENTE');
    });

final trainerCommissionRulesProvider =
    FutureProvider.autoDispose<List<TrainerCommissionRuleModel>>((ref) {
      return ref.watch(accountingRepositoryProvider).getTrainerRules();
    });

final trainerPayoutOptionsProvider =
    FutureProvider.autoDispose<TrainerPayoutOptionsModel>((ref) {
      return ref.watch(accountingRepositoryProvider).getTrainerPayoutOptions();
    });

final trainerLiquidationsProvider =
    FutureProvider.autoDispose<List<TrainerLiquidationModel>>((ref) {
      return ref.watch(accountingRepositoryProvider).getTrainerLiquidations();
    });

final trainerCompensationProfilesProvider =
    FutureProvider.autoDispose<List<TrainerCompensationProfileModel>>((ref) {
      return ref
          .watch(accountingRepositoryProvider)
          .getTrainerCompensationProfiles();
    });

final trainerFixedObligationsProvider =
    FutureProvider.autoDispose<List<TrainerFixedObligationModel>>((ref) {
      return ref
          .watch(accountingRepositoryProvider)
          .getTrainerFixedObligations(status: 'PENDIENTE');
    });

final treasuryRefundsProvider =
    FutureProvider.autoDispose<List<TreasuryRefundModel>>((ref) {
      return ref.watch(accountingRepositoryProvider).getTreasuryRefunds();
    });

final treasuryRefundOptionsProvider =
    FutureProvider.autoDispose<TreasuryRefundOptionsModel>((ref) {
      return ref.watch(accountingRepositoryProvider).getTreasuryRefundOptions();
    });

final treasuryLedgerProvider = FutureProvider.autoDispose
    .family<TreasuryLedgerModel, String?>((ref, businessDate) {
      return ref
          .watch(accountingRepositoryProvider)
          .getTreasuryLedger(businessDate: businessDate);
    });

final treasuryMonthlySummaryProvider = FutureProvider.autoDispose
    .family<TreasuryMonthlySummaryModel, String?>((ref, month) {
      return ref
          .watch(accountingRepositoryProvider)
          .getTreasuryMonthlySummary(month: month);
    });

final treasuryPeriodSummaryProvider = FutureProvider.autoDispose
    .family<TreasuryPeriodSummaryModel, TreasuryPeriodRequest>((ref, request) {
      return ref
          .watch(accountingRepositoryProvider)
          .getTreasuryPeriodSummary(request);
    });

final treasuryPeriodClosesProvider = FutureProvider.autoDispose
    .family<TreasuryPeriodCyclesModel, TreasuryPeriodRequest>((ref, request) {
      return ref
          .watch(accountingRepositoryProvider)
          .getTreasuryPeriodCloses(from: request.from, to: request.to);
    });

final operationalResultsProvider = FutureProvider.autoDispose
    .family<OperationalResultsModel, String?>((ref, month) {
      return ref
          .watch(accountingRepositoryProvider)
          .getOperationalResults(month: month);
    });

final operationalAnnualResultsProvider = FutureProvider.autoDispose
    .family<OperationalAnnualResultsModel, String?>((ref, year) {
      return ref
          .watch(accountingRepositoryProvider)
          .getOperationalAnnualResults(year: year);
    });

final exchangeRevaluationProvider = FutureProvider.autoDispose
    .family<ExchangeRevaluationModel, String?>((ref, month) {
      return ref
          .watch(accountingRepositoryProvider)
          .getExchangeRevaluation(month: month);
    });

final membershipRevenueProvider = FutureProvider.autoDispose
    .family<MembershipRevenueModel, String?>((ref, month) {
      return ref
          .watch(accountingRepositoryProvider)
          .getMembershipRevenue(month: month);
    });

final trainerServiceCostProvider = FutureProvider.autoDispose
    .family<TrainerServiceCostModel, String?>((ref, month) {
      return ref
          .watch(accountingRepositoryProvider)
          .getTrainerServiceCost(month: month);
    });

final managementMarginProvider = FutureProvider.autoDispose
    .family<ManagementMarginModel, String?>((ref, month) {
      return ref
          .watch(accountingRepositoryProvider)
          .getManagementMargin(month: month);
    });

final recurringExpensesProvider =
    FutureProvider.autoDispose<List<RecurringExpenseModel>>((ref) {
      return ref.watch(accountingRepositoryProvider).getRecurringExpenses();
    });

final recurringExpensePlanProvider = FutureProvider.autoDispose
    .family<RecurringExpensePlanModel, String?>((ref, month) {
      return ref
          .watch(accountingRepositoryProvider)
          .previewRecurringExpenses(month: month);
    });

final accrualOperatingResultProvider = FutureProvider.autoDispose
    .family<AccrualOperatingResultModel, String?>((ref, month) {
      return ref
          .watch(accountingRepositoryProvider)
          .getAccrualOperatingResult(month: month);
    });

final managementMarginAnnualResultsProvider = FutureProvider.autoDispose
    .family<ManagementMarginAnnualResultsModel, String?>((ref, year) {
      return ref
          .watch(accountingRepositoryProvider)
          .getManagementMarginAnnualResults(year: year);
    });

final treasuryManualOptionsProvider =
    FutureProvider.autoDispose<TreasuryRefundOptionsModel>((ref) {
      return ref.watch(accountingRepositoryProvider).getTreasuryManualOptions();
    });

final governedExpensesProvider = FutureProvider.autoDispose
    .family<GovernedExpensesReportModel, String?>((ref, month) {
      return ref
          .watch(accountingRepositoryProvider)
          .getGovernedExpenses(month: month);
    });

final governedExpenseCategoriesProvider =
    FutureProvider.autoDispose<List<GastoCategoriaModel>>((ref) {
      return ref
          .watch(accountingRepositoryProvider)
          .getGovernedExpenseCategories();
    });

final governedExpenseSuppliersProvider =
    FutureProvider.autoDispose<List<GastoProveedorModel>>((ref) {
      return ref
          .watch(accountingRepositoryProvider)
          .getGovernedExpenseSuppliers();
    });
