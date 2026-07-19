import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../trainers/presentation/providers/trainer_notifier.dart';
import '../../data/models/accounting_models.dart';
import '../../data/repositories/accounting_repository.dart';
import '../state/accounting_providers.dart';

final _date = DateFormat('dd/MM/yyyy');

class CompensationProfilesPanel extends ConsumerWidget {
  const CompensationProfilesPanel({super.key, required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trainerCompensationProfilesProvider);
    final obligations = ref.watch(trainerFixedObligationsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PulsoPanel(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final intro = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PulsoLabel('Perfiles de compensación'),
                  const SizedBox(height: 8),
                  Text(
                    'Separa cómo se gana la comisión de cuándo se desembolsa.',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Los cambios crean historia y solo afectan compromisos futuros.',
                    style: TextStyle(color: PulsoTokens.of(context).muted),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Las comisiones nacen de cada cobro; el componente fijo genera obligaciones separadas al vencer cada corte.',
                    style: TextStyle(
                      color: PulsoTokens.of(context).success,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
              final add = PulsoPrimaryButton(
                label: 'Nuevo perfil',
                icon: Icons.add,
                onPressed: () => _openProfileDialog(context, ref, onChanged),
              );
              if (constraints.maxWidth < 650) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [intro, const SizedBox(height: 16), add],
                );
              }
              return Row(
                children: [
                  Expanded(child: intro),
                  const SizedBox(width: 20),
                  add,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        state.when(
          loading: () => const PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.loading,
              message: 'Cargando perfiles de compensación…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message: 'No se pudieron cargar los perfiles.\n$error',
              onRetry: () =>
                  ref.invalidate(trainerCompensationProfilesProvider),
            ),
          ),
          data: (items) => items.isEmpty
              ? const PulsoPanel(
                  child: PulsoStateView(
                    kind: PulsoStateKind.empty,
                    message:
                        'Todavía no hay perfiles. Sin perfil, las comisiones nuevas conservan el calendario mensual anterior.',
                  ),
                )
              : _ProfileCatalog(
                  items: items,
                  onEdit: (item) => _openProfileDialog(
                    context,
                    ref,
                    onChanged,
                    initial: item,
                  ),
                  onClose: (item) =>
                      _closeProfile(context, ref, onChanged, item),
                ),
        ),
        const SizedBox(height: 12),
        obligations.when(
          loading: () => const PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.loading,
              message: 'Calculando obligaciones fijas vencidas…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message:
                  'No se pudieron calcular las obligaciones fijas.\n$error',
              onRetry: () => ref.invalidate(trainerFixedObligationsProvider),
            ),
          ),
          data: (items) => _FixedObligationsCatalog(
            items: items,
            onRefresh: () async {
              await ref
                  .read(accountingRepositoryProvider)
                  .materializeTrainerFixedObligations();
              ref.invalidate(trainerFixedObligationsProvider);
              ref.invalidate(accountingSummaryProvider);
              onChanged();
            },
          ),
        ),
      ],
    );
  }
}

class _FixedObligationsCatalog extends StatelessWidget {
  const _FixedObligationsCatalog({
    required this.items,
    required this.onRefresh,
  });

  final List<TrainerFixedObligationModel> items;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final totals = <String, double>{};
    for (final item in items) {
      totals[item.currencyCode] =
          (totals[item.currencyCode] ?? 0) + item.amount;
    }
    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final description = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PulsoLabel('Obligaciones fijas vencidas'),
                    const SizedBox(height: 6),
                    Text(
                      items.isEmpty
                          ? 'No hay cortes fijos pendientes hasta el día comercial actual.'
                          : '${items.length} corte${items.length == 1 ? '' : 's'} pendiente${items.length == 1 ? '' : 's'} · ${totals.entries.map((entry) => '${entry.key} ${entry.value.toStringAsFixed(2)}').join(' · ')}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'El snapshot conserva importe, frecuencia, prorrateo y días cubiertos. Todavía no mezcla estos saldos con las cuotas de comisión.',
                      style: TextStyle(color: tokens.muted, fontSize: 12),
                    ),
                  ],
                );
                final refresh = PulsoSecondaryButton(
                  label: 'Actualizar cortes',
                  icon: Icons.refresh,
                  onPressed: onRefresh,
                );
                if (constraints.maxWidth < 650) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      description,
                      const SizedBox(height: 14),
                      refresh,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: description),
                    const SizedBox(width: 20),
                    refresh,
                  ],
                );
              },
            ),
          ),
          if (items.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final visible = items.take(16).toList();
                if (constraints.maxWidth < 720) {
                  return Column(
                    children: [
                      for (final item in visible)
                        _FixedObligationCard(item: item),
                    ],
                  );
                }
                return Column(
                  children: [
                    Container(
                      color: tokens.raised,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: PulsoLabel('Entrenador')),
                          Expanded(flex: 2, child: PulsoLabel('Periodo')),
                          Expanded(flex: 2, child: PulsoLabel('Cálculo')),
                          Expanded(flex: 2, child: PulsoLabel('Importe')),
                        ],
                      ),
                    ),
                    for (final item in visible) _FixedObligationRow(item: item),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _FixedObligationRow extends StatelessWidget {
  const _FixedObligationRow({required this.item});
  final TrainerFixedObligationModel item;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              item.trainerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${_date.format(item.periodStart.toUtc())}–${_date.format(item.periodEnd.toUtc())}',
              style: const TextStyle(fontFamily: PulsoFonts.mono, fontSize: 11),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.prorationMethod == 'DIAS_SERVICIO'
                  ? '${item.coveredDays}/${item.periodDays} días'
                  : 'periodo completo',
              style: TextStyle(color: tokens.muted, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${item.currencyCode} ${item.amount.toStringAsFixed(2)}',
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: PulsoFonts.mono,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FixedObligationCard extends StatelessWidget {
  const _FixedObligationCard({required this.item});
  final TrainerFixedObligationModel item;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.trainerName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_date.format(item.periodStart.toUtc())}–${_date.format(item.periodEnd.toUtc())} · ${item.coveredDays}/${item.periodDays} días',
                  style: TextStyle(color: tokens.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${item.currencyCode}\n${item.amount.toStringAsFixed(2)}',
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontFamily: PulsoFonts.mono,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCatalog extends StatelessWidget {
  const _ProfileCatalog({
    required this.items,
    required this.onEdit,
    required this.onClose,
  });

  final List<TrainerCompensationProfileModel> items;
  final ValueChanged<TrainerCompensationProfileModel> onEdit;
  final ValueChanged<TrainerCompensationProfileModel> onClose;

  @override
  Widget build(BuildContext context) {
    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 760) {
            return Column(
              children: [
                for (final item in items)
                  _ProfileCard(
                    key: ValueKey(item.id),
                    item: item,
                    onEdit: () => onEdit(item),
                    onClose: () => onClose(item),
                  ),
              ],
            );
          }
          return Column(
            children: [
              const _ProfileHeader(),
              for (final item in items)
                _ProfileRow(
                  key: ValueKey(item.id),
                  item: item,
                  onEdit: () => onEdit(item),
                  onClose: () => onClose(item),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      color: tokens.raised,
      child: const Row(
        children: [
          Expanded(flex: 3, child: PulsoLabel('Entrenador')),
          Expanded(flex: 2, child: PulsoLabel('Modalidad')),
          Expanded(flex: 2, child: PulsoLabel('Desembolso')),
          Expanded(flex: 2, child: PulsoLabel('Vigencia')),
          SizedBox(width: 104),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onClose,
  });

  final TrainerCompensationProfileModel item;
  final VoidCallback onEdit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: _TitleBlock(item: item)),
          Expanded(flex: 2, child: Text(_modalityLabel(item))),
          Expanded(flex: 2, child: Text(_frequencyLabel(item))),
          Expanded(flex: 2, child: _Validity(item: item)),
          SizedBox(
            width: 104,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PulsoIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Editar perfil',
                  onPressed: item.validityStatus == 'FINALIZADO'
                      ? null
                      : onEdit,
                ),
                PulsoIconButton(
                  icon: Icons.stop_circle_outlined,
                  tooltip: 'Finalizar perfil',
                  danger: true,
                  onPressed: item.validityStatus == 'FINALIZADO'
                      ? null
                      : onClose,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onClose,
  });

  final TrainerCompensationProfileModel item;
  final VoidCallback onEdit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _TitleBlock(item: item)),
              _Validity(item: item),
            ],
          ),
          const SizedBox(height: 12),
          Text('${_modalityLabel(item)} · ${_frequencyLabel(item)}'),
          const SizedBox(height: 4),
          Text(
            _earningLabel(item.earningMethod),
            style: TextStyle(color: tokens.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PulsoSecondaryButton(
                  label: 'Editar',
                  onPressed: item.validityStatus == 'FINALIZADO'
                      ? null
                      : onEdit,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PulsoSecondaryButton(
                  label: 'Finalizar',
                  danger: true,
                  onPressed: item.validityStatus == 'FINALIZADO'
                      ? null
                      : onClose,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.item});

  final TrainerCompensationProfileModel item;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.trainerName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          item.preferredAccountName ?? 'sin cuenta preferida',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: tokens.muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _Validity extends StatelessWidget {
  const _Validity({required this.item});

  final TrainerCompensationProfileModel item;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final warning = item.hasConflict || item.validityStatus == 'PROGRAMADO';
    final color = item.hasConflict
        ? tokens.danger
        : item.validityStatus == 'VIGENTE'
        ? tokens.success
        : warning
        ? tokens.warning
        : tokens.muted;
    return Text(
      item.hasConflict ? 'CONFLICTO' : item.validityStatus,
      style: TextStyle(
        color: color,
        fontFamily: PulsoFonts.mono,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

Future<void> _openProfileDialog(
  BuildContext context,
  WidgetRef ref,
  VoidCallback onChanged, {
  TrainerCompensationProfileModel? initial,
}) async {
  final loadedTrainers = await ref.read(trainerProvider.future);
  final trainers = loadedTrainers
      .where((trainer) => trainer.activo || trainer.id == initial?.trainerId)
      .toList();
  final options = await ref.read(trainerPayoutOptionsProvider.future);
  if (!context.mounted) return;
  if (trainers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No hay entrenadores activos.')),
    );
    return;
  }

  String trainerId = initial?.trainerId ?? trainers.first.id;
  String modality = initial?.modality ?? 'COMISION';
  String earning = initial?.earningMethod ?? 'PERIODOS_IGUALES';
  String frequency = initial?.payoutFrequency ?? 'MENSUAL';
  int? cutoff = initial?.cutoffDay ?? 28;
  String? currencyId = initial?.currencyId;
  String? accountId = initial?.preferredAccountId;
  DateTime start =
      initial?.startDate.toUtc() ??
      calendarDateToUtc(todayInZone(appClock.gymTimezone));
  DateTime? end = initial?.endDate?.toUtc();
  final amountController = TextEditingController(
    text: initial?.fixedAmount?.toStringAsFixed(2) ?? '',
  );
  final notesController = TextEditingController(text: initial?.notes ?? '');
  bool saving = false;
  String? error;

  final currencyCodes = <String, String>{};
  for (final account in options.accounts) {
    currencyCodes[account.currencyId] = account.currencyCode;
  }
  if (initial?.currencyId != null) {
    currencyCodes.putIfAbsent(
      initial!.currencyId!,
      () => initial.currencyCode ?? initial.currencyId!,
    );
  }
  currencyId ??= currencyCodes.keys.firstOrNull;

  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PulsoThemeScope(
      child: StatefulBuilder(
        builder: (context, setLocalState) {
          final fixed = modality == 'FIJO' || modality == 'MIXTO';
          final accounts = options.accounts.where((account) {
            return !fixed || account.currencyId == currencyId;
          }).toList();
          if (accountId != null &&
              !accounts.any((item) => item.id == accountId)) {
            accountId = null;
          }

          Future<void> pickDate({required bool isEnd}) async {
            final current = isEnd
                ? end ?? start.add(const Duration(days: 30))
                : start;
            final value = await showDatePicker(
              context: context,
              initialDate: DateTime(current.year, current.month, current.day),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (value == null) return;
            setLocalState(() {
              if (isEnd) {
                end = calendarDateToUtc(value);
              } else {
                start = calendarDateToUtc(value);
              }
            });
          }

          return AlertDialog(
            title: Text(initial == null ? 'Nuevo perfil' : 'Editar perfil'),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: PulsoTokens.of(context).dangerSoft,
                        child: Text(error!),
                      ),
                      const SizedBox(height: 16),
                    ],
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      key: ValueKey('profile-trainer-$trainerId'),
                      initialValue: trainerId,
                      decoration: const InputDecoration(
                        labelText: 'Entrenador',
                      ),
                      items: [
                        for (final trainer in trainers)
                          DropdownMenuItem(
                            value: trainer.id,
                            child: Text(
                              '${trainer.nombres ?? ''} ${trainer.apellidos ?? ''}'
                                  .trim(),
                            ),
                          ),
                      ],
                      onChanged: saving || initial != null
                          ? null
                          : (value) => setLocalState(
                              () => trainerId = value ?? trainerId,
                            ),
                    ),
                    const SizedBox(height: 16),
                    _ResponsiveFields(
                      left: DropdownButtonFormField<String>(
                        isExpanded: true,
                        key: ValueKey('profile-modality-$modality'),
                        initialValue: modality,
                        decoration: const InputDecoration(
                          labelText: 'Modalidad',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'COMISION',
                            child: Text('Solo comisión'),
                          ),
                          DropdownMenuItem(
                            value: 'FIJO',
                            child: Text('Importe fijo'),
                          ),
                          DropdownMenuItem(
                            value: 'MIXTO',
                            child: Text('Fijo + comisión'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) => setLocalState(
                                () => modality = value ?? modality,
                              ),
                      ),
                      right: DropdownButtonFormField<String>(
                        isExpanded: true,
                        key: ValueKey('profile-earning-$earning'),
                        initialValue: earning,
                        decoration: const InputDecoration(
                          labelText: 'Cómo se gana comisión',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'PERIODOS_IGUALES',
                            child: Text('Periodos iguales'),
                          ),
                          DropdownMenuItem(
                            value: 'DIAS_SERVICIO',
                            child: Text('Días de servicio'),
                          ),
                        ],
                        onChanged: saving || modality == 'FIJO'
                            ? null
                            : (value) => setLocalState(
                                () => earning = value ?? earning,
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ResponsiveFields(
                      left: DropdownButtonFormField<String>(
                        isExpanded: true,
                        key: ValueKey('profile-frequency-$frequency'),
                        initialValue: frequency,
                        decoration: const InputDecoration(
                          labelText: 'Frecuencia de desembolso',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'DIARIA',
                            child: Text('Diaria'),
                          ),
                          DropdownMenuItem(
                            value: 'SEMANAL',
                            child: Text('Semanal'),
                          ),
                          DropdownMenuItem(
                            value: 'QUINCENAL',
                            child: Text('Quincenal'),
                          ),
                          DropdownMenuItem(
                            value: 'MENSUAL',
                            child: Text('Mensual'),
                          ),
                          DropdownMenuItem(
                            value: 'EXTRAORDINARIA',
                            child: Text('Solo liquidación extraordinaria'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) => setLocalState(() {
                                frequency = value ?? frequency;
                                cutoff = switch (frequency) {
                                  'SEMANAL' => 5,
                                  'QUINCENAL' => 15,
                                  'MENSUAL' => 28,
                                  _ => null,
                                };
                              }),
                      ),
                      right: _CutoffField(
                        frequency: frequency,
                        value: cutoff,
                        enabled: !saving,
                        onChanged: (value) =>
                            setLocalState(() => cutoff = value),
                      ),
                    ),
                    if (fixed) ...[
                      const SizedBox(height: 16),
                      _ResponsiveFields(
                        left: TextFormField(
                          key: const ValueKey('profile-fixed-amount'),
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*[.,]?\d{0,2}'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Importe fijo por periodo',
                          ),
                        ),
                        right: DropdownButtonFormField<String>(
                          isExpanded: true,
                          key: ValueKey('profile-currency-$currencyId'),
                          initialValue: currencyId,
                          decoration: const InputDecoration(
                            labelText: 'Moneda',
                          ),
                          items: [
                            for (final entry in currencyCodes.entries)
                              DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                          ],
                          onChanged: saving
                              ? null
                              : (value) => setLocalState(() {
                                  currencyId = value;
                                  accountId = null;
                                }),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      isExpanded: true,
                      key: ValueKey('profile-account-$accountId-$currencyId'),
                      initialValue: accountId,
                      decoration: const InputDecoration(
                        labelText: 'Cuenta preferida (opcional)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Sin preferencia'),
                        ),
                        for (final account in accounts)
                          DropdownMenuItem<String?>(
                            value: account.id,
                            child: Text(
                              '${account.name} · ${account.currencyCode}',
                            ),
                          ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) => setLocalState(() => accountId = value),
                    ),
                    const SizedBox(height: 16),
                    _ResponsiveFields(
                      left: _DateField(
                        label: 'Inicio de vigencia',
                        value: start,
                        onTap: saving ? null : () => pickDate(isEnd: false),
                      ),
                      right: _DateField(
                        label: 'Fin opcional',
                        value: end,
                        onTap: saving ? null : () => pickDate(isEnd: true),
                        onClear: end == null || saving
                            ? null
                            : () => setLocalState(() => end = null),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notas operativas (opcional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Al editar un perfil ya utilizado, la versión anterior se cierra y los devengos existentes conservan su configuración.',
                      style: TextStyle(
                        color: PulsoTokens.of(context).muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              PulsoSecondaryButton(
                label: 'Cancelar',
                onPressed: saving
                    ? null
                    : () => Navigator.of(context).pop(false),
              ),
              PulsoPrimaryButton(
                label: saving ? 'Guardando…' : 'Guardar perfil',
                onPressed: saving
                    ? null
                    : () async {
                        if (fixed &&
                            (double.tryParse(
                                      amountController.text.replaceAll(
                                        ',',
                                        '.',
                                      ),
                                    ) ??
                                    0) <=
                                0) {
                          setLocalState(
                            () => error =
                                'Indique un importe fijo mayor que cero.',
                          );
                          return;
                        }
                        setLocalState(() {
                          saving = true;
                          error = null;
                        });
                        final payload = <String, dynamic>{
                          'id_entrenador': trainerId,
                          'modalidad': modality,
                          'metodo_devengo': earning,
                          'frecuencia_desembolso': frequency,
                          'dia_corte': cutoff,
                          'monto_fijo': fixed
                              ? amountController.text.replaceAll(',', '.')
                              : null,
                          'moneda_id': fixed ? currencyId : null,
                          'cuenta_preferida_id': accountId,
                          'fecha_inicio': calendarDateToUtc(
                            start,
                          ).toIso8601String(),
                          'fecha_fin': end == null
                              ? null
                              : calendarDateToUtc(end!).toIso8601String(),
                          'notas': notesController.text.trim(),
                        };
                        try {
                          final repository = ref.read(
                            accountingRepositoryProvider,
                          );
                          if (initial == null) {
                            await repository.createTrainerCompensationProfile(
                              payload,
                            );
                          } else {
                            await repository.updateTrainerCompensationProfile(
                              initial.id,
                              payload,
                            );
                          }
                          if (context.mounted) Navigator.of(context).pop(true);
                        } on DioException catch (exception) {
                          final data = exception.response?.data;
                          setLocalState(() {
                            saving = false;
                            error = data is Map && data['error'] != null
                                ? data['error'].toString()
                                : 'No se pudo guardar el perfil.';
                          });
                        }
                      },
              ),
            ],
          );
        },
      ),
    ),
  );
  amountController.dispose();
  notesController.dispose();
  if (saved != true) return;
  ref.invalidate(trainerCompensationProfilesProvider);
  ref.invalidate(accountingSummaryProvider);
  onChanged();
}

Future<void> _closeProfile(
  BuildContext context,
  WidgetRef ref,
  VoidCallback onChanged,
  TrainerCompensationProfileModel item,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => PulsoThemeScope(
      child: AlertDialog(
        title: const Text('Finalizar perfil'),
        content: Text(
          item.validityStatus == 'PROGRAMADO'
              ? 'Se cancelará la programación de ${item.trainerName}.'
              : 'El perfil de ${item.trainerName} terminará hoy. Los compromisos anteriores no se recalcularán.',
        ),
        actions: [
          PulsoSecondaryButton(
            label: 'Volver',
            onPressed: () => Navigator.of(context).pop(false),
          ),
          PulsoSecondaryButton(
            label: 'Finalizar',
            danger: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true) return;
  try {
    await ref
        .read(accountingRepositoryProvider)
        .deleteTrainerCompensationProfile(item.id);
    ref.invalidate(trainerCompensationProfilesProvider);
    ref.invalidate(accountingSummaryProvider);
    onChanged();
  } on DioException catch (exception) {
    if (!context.mounted) return;
    final data = exception.response?.data;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          data is Map && data['error'] != null
              ? data['error'].toString()
              : 'No se pudo finalizar el perfil.',
        ),
      ),
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 650;
    if (compact) {
      return Column(children: [left, const SizedBox(height: 16), right]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }
}

class _CutoffField extends StatelessWidget {
  const _CutoffField({
    required this.frequency,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
  final String frequency;
  final int? value;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (frequency == 'DIARIA' || frequency == 'EXTRAORDINARIA') {
      return TextFormField(
        enabled: false,
        decoration: const InputDecoration(
          labelText: 'Día de corte',
          hintText: 'No aplica',
        ),
      );
    }
    final maximum = frequency == 'SEMANAL'
        ? 7
        : frequency == 'QUINCENAL'
        ? 15
        : 28;
    return DropdownButtonFormField<int>(
      isExpanded: true,
      key: ValueKey('profile-cutoff-$frequency-$value'),
      initialValue: value != null && value! <= maximum ? value : maximum,
      decoration: InputDecoration(
        labelText: frequency == 'SEMANAL'
            ? 'Día ISO (1=lunes)'
            : 'Día de corte',
      ),
      items: [
        for (var day = 1; day <= maximum; day += 1)
          DropdownMenuItem(value: day, child: Text('$day')),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });
  final String label;
  final DateTime? value;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey('$label-${value?.toIso8601String()}'),
      initialValue: value == null ? '' : _date.format(value!.toUtc()),
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: onClear == null
            ? const Icon(Icons.event_outlined)
            : IconButton(onPressed: onClear, icon: const Icon(Icons.close)),
      ),
    );
  }
}

String _modalityLabel(TrainerCompensationProfileModel item) {
  final fixed = item.fixedAmount == null
      ? ''
      : ' · ${item.currencyCode ?? ''} ${item.fixedAmount!.toStringAsFixed(2)}';
  return switch (item.modality) {
    'FIJO' => 'Fijo$fixed',
    'MIXTO' => 'Mixto$fixed',
    _ => 'Comisión',
  };
}

String _earningLabel(String value) => switch (value) {
  'DIAS_SERVICIO' => 'Devengo por días de servicio',
  _ => 'Devengo por periodos iguales',
};

String _frequencyLabel(TrainerCompensationProfileModel item) {
  final base = switch (item.payoutFrequency) {
    'DIARIA' => 'Diaria',
    'SEMANAL' => 'Semanal',
    'QUINCENAL' => 'Quincenal',
    'EXTRAORDINARIA' => 'Extraordinaria',
    _ => 'Mensual',
  };
  return item.cutoffDay == null ? base : '$base · corte ${item.cutoffDay}';
}
