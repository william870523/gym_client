import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/accounting_models.dart';
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

final trainerCommissionRulesProvider =
    FutureProvider.autoDispose<List<TrainerCommissionRuleModel>>((ref) {
      return ref.watch(accountingRepositoryProvider).getTrainerRules();
    });
