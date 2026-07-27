import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/base64_image.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../clients/domain/plan_associates.dart';
import '../../../clients/presentation/state/client_notifier.dart';
import '../../../clients/presentation/state/clients_scope_filter_provider.dart';
import '../../../dashboard/presentation/state/dashboard_nav_provider.dart';
import '../../../payments/presentation/state/payment_notifier.dart';
import '../../data/models/trainer_model.dart';
import '../../data/models/trainer_offboarding_impact.dart';
import '../../data/models/trainer_offboarding_case.dart';
import '../../data/repositories/trainer_repository.dart';
import '../providers/trainer_notifier.dart';
import '../widgets/trainer_offboarding_case_dialog.dart';
import '../widgets/trainer_pulso_form.dart';

enum _TrainerFilter { all, active, inactive }

enum _TrainerSort { name, clients }

final _dateFmt = DateFormat('yyyy-MM-dd');

/// Índice de la vista de Clientes en el conmutador del panel principal.
const int _clientsViewIndex = 1;

String _fullName(TrainerModel trainer) {
  final first = (trainer.nombres ?? '').trim();
  final last = (trainer.apellidos ?? '').trim();
  final value = '$first $last'.trim();
  return value.isEmpty ? 'Entrenador sin nombre' : value;
}

String _initials(TrainerModel trainer) {
  final first = (trainer.nombres ?? '').trim();
  final last = (trainer.apellidos ?? '').trim();
  final buffer = StringBuffer();
  if (first.isNotEmpty) buffer.write(first[0]);
  if (last.isNotEmpty) buffer.write(last[0]);
  final value = buffer.toString().toUpperCase();
  return value.isEmpty ? '?' : value;
}

String _contactLine(TrainerModel trainer) {
  final phone = trainer.telefono?.toString() ?? '';
  final email = (trainer.correo ?? '').trim();
  if (phone.isNotEmpty && email.isNotEmpty) return '$phone · $email';
  if (phone.isNotEmpty) return phone;
  if (email.isNotEmpty) return email;
  return 'sin contacto';
}

// La fecha de alta es fecha de calendario (medianoche UTC); se muestra por
// componentes, sin conversión de zona (TIME_CONTRACT §4).
String _startDate(TrainerModel trainer) =>
    _dateFmt.format(trainer.fechaInicio.toUtc());

/// Socios por entrenador, con el criterio de asociado de
/// docs/PLAN_ASOCIADOS.md §5 (el mismo que usa la lista de Clientes).
class _TrainerStats {
  const _TrainerStats({required this.ready, required this.counts});

  /// `false` mientras el catálogo de clientes no ha cargado: los conteos se
  /// muestran como «—» en lugar de un cero engañoso.
  final bool ready;
  final Map<String, int> counts;

  int of(TrainerModel trainer) => counts[trainer.id] ?? 0;

  int get assignedTotal =>
      counts.values.fold(0, (total, value) => total + value);
}

class TrainersPulsoView extends ConsumerStatefulWidget {
  const TrainersPulsoView({super.key});

  @override
  ConsumerState<TrainersPulsoView> createState() => _TrainersPulsoViewState();
}

class _TrainersPulsoViewState extends ConsumerState<TrainersPulsoView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  String? _selectedId;
  _TrainerFilter _filter = _TrainerFilter.all;
  _TrainerSort _sort = _TrainerSort.name;
  bool _ascending = true;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<TrainerModel> _visible(List<TrainerModel> all, _TrainerStats stats) {
    final query = _query.trim().toLowerCase();
    final result = all.where((trainer) {
      final haystack =
          '${_fullName(trainer)} ${trainer.ci} ${_contactLine(trainer)}'
              .toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      final matchesFilter = switch (_filter) {
        _TrainerFilter.all => true,
        _TrainerFilter.active => trainer.activo,
        _TrainerFilter.inactive => !trainer.activo,
      };
      return matchesQuery && matchesFilter;
    }).toList();
    int compare(TrainerModel a, TrainerModel b) {
      final value = switch (_sort) {
        _TrainerSort.name => _fullName(
          a,
        ).toLowerCase().compareTo(_fullName(b).toLowerCase()),
        _TrainerSort.clients => stats.of(a).compareTo(stats.of(b)),
      };
      return _ascending ? value : -value;
    }

    result.sort(compare);
    return result;
  }

  void _setSort(_TrainerSort sort) {
    setState(() {
      if (_sort == sort) {
        _ascending = !_ascending;
      } else {
        _sort = sort;
        // Por socios interesa primero el entrenador con más carga.
        _ascending = sort != _TrainerSort.clients;
      }
    });
  }

  /// Formulario PULSO en diálogo dentro del shell, con captura de foto por
  /// cámara o archivo.
  Future<void> _openForm([TrainerModel? trainer]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TrainerPulsoForm(
        trainer: trainer,
        onSubmit: (payload) async {
          final notifier = ref.read(trainerProvider.notifier);
          if (trainer == null) {
            await notifier.createTrainer(payload);
          } else {
            await notifier.updateTrainer(trainer.id, payload);
          }
        },
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          trainer == null
              ? 'Nuevo entrenador registrado.'
              : '“${_fullName(trainer)}” fue actualizado.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(TrainerModel trainer, _TrainerStats stats) async {
    TrainerOffboardingImpact impact;
    try {
      impact = await ref
          .read(trainerRepositoryProvider)
          .getOffboardingImpact(trainer.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('No se pudo analizar la baja: $error'),
        ),
      );
      return;
    }
    if (!mounted) return;
    if (!impact.canDeleteDirectly) {
      await _showOffboardingImpact(impact);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PulsoThemeScope(
        child: AlertDialog(
          title: const Text('Confirmar baja sin impacto'),
          content: Text(
            'No existen membresías, perfiles vigentes ni saldos por resolver. '
            '“${_fullName(trainer)}” quedará inactivo y su historia se conservará.',
          ),
          actions: [
            PulsoSecondaryButton(
              label: 'Cancelar',
              onPressed: () => Navigator.of(context).pop(false),
            ),
            PulsoSecondaryButton(
              label: 'Confirmar baja',
              danger: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(trainerProvider.notifier).deleteTrainer(trainer.id);
      if (!mounted) return;
      if (_selectedId == trainer.id) setState(() => _selectedId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“${_fullName(trainer)}” quedó de baja.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('No se pudo eliminar: $error'),
        ),
      );
    }
  }

  Future<void> _showOffboardingImpact(TrainerOffboardingImpact impact) async {
    final openCase = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => PulsoThemeScope(
        child: Builder(
          builder: (context) {
            final tokens = PulsoTokens.of(context);
            final compactDialog = MediaQuery.sizeOf(context).width < 700;
            final availableHeight = (MediaQuery.sizeOf(context).height - 220)
                .clamp(380.0, 620.0);
            return AlertDialog(
              title: const Text('Preparar baja de entrenador'),
              content: SizedBox(
                width: 760,
                height: availableHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      color: tokens.warningSoft,
                      child: Text(
                        'La baja no se ejecutó. Primero hay que resolver ${impact.memberships.length} membresía${impact.memberships.length == 1 ? '' : 's'}, ${impact.activeProfiles} perfil${impact.activeProfiles == 1 ? '' : 'es'} vigente${impact.activeProfiles == 1 ? '' : 's'} y los saldos mostrados por moneda.',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const PulsoLabel('Impacto financiero'),
                    const SizedBox(height: 8),
                    if (impact.finances.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          'Sin compromisos financieros registrados.',
                          style: TextStyle(color: tokens.muted),
                        ),
                      )
                    else
                      SizedBox(
                        height: compactDialog ? 96 : 250,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: impact.finances.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) => compactDialog
                              ? _OffboardingFinanceCompactCard(
                                  item: impact.finances[index],
                                )
                              : _OffboardingFinanceCard(
                                  item: impact.finances[index],
                                ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Expanded(
                          child: PulsoLabel('Membresías afectadas'),
                        ),
                        Text(
                          '${impact.memberships.length}',
                          style: TextStyle(
                            color: tokens.accent,
                            fontFamily: PulsoFonts.mono,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _OffboardingImpactTable(items: impact.memberships),
                    ),
                  ],
                ),
              ),
              actions: [
                PulsoSecondaryButton(
                  label: 'Cerrar',
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                PulsoPrimaryButton(
                  label: 'Abrir expediente',
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (openCase == true && mounted) await _openOffboardingCase(impact);
  }

  Future<void> _openOffboardingCase(TrainerOffboardingImpact impact) async {
    final repository = ref.read(trainerRepositoryProvider);
    TrainerOffboardingCase? offboardingCase;
    try {
      offboardingCase = await repository.getOpenOffboardingCase(
        impact.trainerId,
      );
      if (offboardingCase == null) {
        if (!mounted) return;
        final draft = await showDialog<_NewOffboardingCaseInput>(
          context: context,
          builder: (context) => PulsoThemeScope(
            child: _CreateOffboardingCaseDialog(
              trainerName: impact.trainerName,
              businessDate: impact.businessDate,
            ),
          ),
        );
        if (draft == null || !mounted) return;
        offboardingCase = await repository.createOffboardingCase(
          trainerId: impact.trainerId,
          effectiveDate: draft.effectiveDate,
          reason: draft.reason,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('No se pudo abrir el expediente: $error'),
        ),
      );
      return;
    }
    if (!mounted) return;
    final caseToShow = offboardingCase;
    final executionOperationId = const Uuid().v4();
    final trainers = ref.read(trainerProvider).value ?? const <TrainerModel>[];
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PulsoThemeScope(
        child: TrainerOffboardingCaseDialog(
          initialCase: caseToShow,
          availableTrainers: trainers,
          onUpdate:
              ({required decision, required type, targetTrainerId, reason}) =>
                  repository.updateOffboardingDecision(
                    trainerId: impact.trainerId,
                    caseId: caseToShow.id,
                    membershipId: decision.membershipId,
                    type: type,
                    targetTrainerId: targetTrainerId,
                    reason: reason,
                  ),
          onExecute: () async {
            final updated = await repository.executeOffboardingCase(
              trainerId: impact.trainerId,
              caseId: caseToShow.id,
              operationId: executionOperationId,
            );
            ref.invalidate(trainerProvider);
            ref.invalidate(clientNotifierProvider);
            return updated;
          },
          onPreviewFinancial: ({required decision, type, destinationPlanId}) =>
              repository.previewOffboardingFinancial(
                trainerId: impact.trainerId,
                caseId: caseToShow.id,
                membershipId: decision.membershipId,
                type: type,
                destinationPlanId: destinationPlanId,
              ),
          onResolveFinancial:
              ({
                required decision,
                required type,
                destinationPlanId,
                targetTrainerId,
                required reason,
              }) async {
                final updated = await repository.resolveOffboardingFinancial(
                  trainerId: impact.trainerId,
                  caseId: caseToShow.id,
                  membershipId: decision.membershipId,
                  type: type,
                  destinationPlanId: destinationPlanId,
                  targetTrainerId: targetTrainerId,
                  reason: reason,
                );
                ref.invalidate(clientNotifierProvider);
                ref.invalidate(paymentNotifierProvider);
                return updated;
              },
          onPreviewFinalSettlement: () => repository.previewFinalSettlement(
            trainerId: impact.trainerId,
            caseId: caseToShow.id,
          ),
          onCreateFinalSettlement:
              ({
                required currencyId,
                required accountId,
                required paymentTypeId,
                notes,
              }) async {
                final result = await repository.createFinalSettlement(
                  trainerId: impact.trainerId,
                  caseId: caseToShow.id,
                  currencyId: currencyId,
                  accountId: accountId,
                  paymentTypeId: paymentTypeId,
                  notes: notes,
                );
                ref.invalidate(trainerProvider);
                return result;
              },
          onCloseFinalSettlement: () async {
            final result = await repository.closeFinalSettlement(
              trainerId: impact.trainerId,
              caseId: caseToShow.id,
            );
            ref.invalidate(trainerProvider);
            return result;
          },
        ),
      ),
    );
  }

  _TrainerStats _buildStats(List<TrainerModel> all) {
    final clients = ref.watch(clientNotifierProvider).value;
    if (clients == null) {
      return const _TrainerStats(ready: false, counts: {});
    }
    // Mismo criterio de socio que usa la lista de Clientes a la que lleva el
    // contador (docs/PLAN_ASOCIADOS.md §5): enseñar 11 y encontrar 8 al pulsar
    // sería peor que no enseñar nada.
    return _TrainerStats(
      ready: true,
      counts: countAssociatesByTrainer(
        clients,
        trainerIds: {for (final trainer in all) trainer.id},
        today: todayInZone(appClock.gymTimezone),
      ),
    );
  }

  /// Lleva a Clientes con los socios de este entrenador ya filtrados.
  void _showTrainerClients(TrainerModel trainer) {
    if (trainer.id.isEmpty) return;
    ref
        .read(clientsScopeFilterProvider.notifier)
        .showTrainer(trainerId: trainer.id, trainerName: _fullName(trainer));
    ref.read(dashboardNavProvider.notifier).setIndex(_clientsViewIndex);
  }

  void _showDetail(
    BuildContext context,
    TrainerModel trainer,
    _TrainerStats stats,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => PulsoThemeScope(
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 40,
          ),
          child: SizedBox(
            width: 340,
            height: 560,
            child: _TrainerDetail(
              trainer: trainer,
              stats: stats,
              onEdit: () {
                Navigator.of(dialogContext).pop();
                _openForm(trainer);
              },
              onDelete: () {
                Navigator.of(dialogContext).pop();
                _confirmDelete(trainer, stats);
              },
              onClients: () {
                Navigator.of(dialogContext).pop();
                _showTrainerClients(trainer);
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PulsoThemeScope(
      child: Builder(
        builder: (context) => ColoredBox(
          color: PulsoTokens.of(context).floor,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                  _searchFocus.requestFocus,
              const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                  _searchFocus.requestFocus,
            },
            child: Focus(autofocus: true, child: _buildPage(context)),
          ),
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context) {
    final state = ref.watch(trainerProvider);
    final all = state.value ?? const <TrainerModel>[];
    final stats = _buildStats(all);
    final visible = _visible(all, stats);
    final active = all.where((trainer) => trainer.activo).length;
    TrainerModel? leader;
    for (final trainer in all) {
      if (stats.of(trainer) == 0) continue;
      if (leader == null || stats.of(trainer) > stats.of(leader)) {
        leader = trainer;
      }
    }
    TrainerModel? selected;
    for (final trainer in all) {
      if (trainer.id == _selectedId) selected = trainer;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final scrollPage = compact || constraints.maxHeight < 760;
        final padding = compact
            ? 16.0
            : constraints.maxWidth < 840
            ? 24.0
            : 32.0;
        final workspaceWide = constraints.maxWidth - (padding * 2) >= 1040;
        final catalog = state.when(
          loading: () => const PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.loading,
              message: 'Cargando el registro de entrenadores…',
            ),
          ),
          error: (error, _) => PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.error,
              message: 'No se pudo cargar el registro.\n$error',
              onRetry: () => ref.invalidate(trainerProvider),
            ),
          ),
          data: (_) => visible.isEmpty
              ? PulsoPanel(
                  child: PulsoStateView(
                    kind: PulsoStateKind.empty,
                    message: all.isEmpty
                        ? 'Todavía no hay entrenadores registrados.'
                        : 'Ningún entrenador coincide con la búsqueda.',
                  ),
                )
              : _TrainerWorkspace(
                  items: visible,
                  stats: stats,
                  selected: workspaceWide ? selected : null,
                  sort: _sort,
                  ascending: _ascending,
                  onSort: _setSort,
                  onSelect: (trainer) {
                    if (workspaceWide) {
                      setState(() => _selectedId = trainer.id);
                    } else {
                      _showDetail(context, trainer, stats);
                    }
                  },
                  onEdit: _openForm,
                  onDelete: (trainer) => _confirmDelete(trainer, stats),
                  onClients: _showTrainerClients,
                ),
        );
        final page = Column(
          mainAxisSize: scrollPage ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TrainerHeader(onCreate: () => _openForm()),
            const SizedBox(height: 14),
            PulsoMetricStrip(
              metrics: [
                PulsoMetricData(
                  value: '${all.length}',
                  label: 'Entrenadores',
                  note: 'registro del gimnasio',
                  emphasis: true,
                ),
                PulsoMetricData(
                  value: '$active',
                  label: 'Activos',
                  note: '${all.length - active} inactivos',
                  warning: all.length - active > 0,
                ),
                PulsoMetricData(
                  value: stats.ready ? '${stats.assignedTotal}' : '—',
                  label: 'Socios asignados',
                  note: 'con entrenador personal',
                ),
                PulsoMetricData(
                  value: leader == null ? '—' : '${stats.of(leader)}',
                  label: 'Mayor carga',
                  note: leader == null
                      ? 'sin asignaciones todavía'
                      : _fullName(leader),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _TrainerCommand(
              controller: _searchController,
              focusNode: _searchFocus,
              filter: _filter,
              onSearch: (value) => setState(() => _query = value),
              onFilter: (value) => setState(() => _filter = value),
              onRefresh: () => ref.invalidate(trainerProvider),
            ),
            const SizedBox(height: 12),
            if (scrollPage)
              SizedBox(height: 360, child: catalog)
            else
              Expanded(child: catalog),
            const SizedBox(height: 8),
            const _TrainerFooter(),
          ],
        );
        final insets = EdgeInsets.fromLTRB(
          padding,
          compact ? 16 : 20,
          padding,
          compact ? 18 : 24,
        );
        return scrollPage
            ? SingleChildScrollView(padding: insets, child: page)
            : Padding(padding: insets, child: page);
      },
    );
  }
}

class _TrainerHeader extends StatelessWidget {
  const _TrainerHeader({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PulsoLabel('PULSO · EQUIPO'),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                text: 'ENTRENADORES',
                children: [
                  TextSpan(
                    text: '.',
                    style: TextStyle(color: tokens.accent),
                  ),
                ],
              ),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Registra al equipo y mide cuántos socios acompaña cada entrenador.',
              style: TextStyle(color: tokens.muted, fontSize: 14),
            ),
          ],
        );
        final action = PulsoPrimaryButton(
          label: 'Nuevo entrenador',
          icon: Icons.add,
          onPressed: onCreate,
        );
        return constraints.maxWidth < 680
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, const SizedBox(height: 14), action],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 24),
                  action,
                ],
              );
      },
    );
  }
}

class _TrainerCommand extends StatelessWidget {
  const _TrainerCommand({
    required this.controller,
    required this.focusNode,
    required this.filter,
    required this.onSearch,
    required this.onFilter,
    required this.onRefresh,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final _TrainerFilter filter;
  final ValueChanged<String> onSearch;
  final ValueChanged<_TrainerFilter> onFilter;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return PulsoPanel(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            key: const ValueKey('pulso-trainer-search'),
            controller: controller,
            focusNode: focusNode,
            onChanged: onSearch,
            decoration: const InputDecoration(
              hintText: 'Buscar nombre, CI o contacto…',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          );
          final controls = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _FilterButton(
                label: 'Todos',
                selected: filter == _TrainerFilter.all,
                onTap: () => onFilter(_TrainerFilter.all),
              ),
              _FilterButton(
                label: 'Activos',
                selected: filter == _TrainerFilter.active,
                onTap: () => onFilter(_TrainerFilter.active),
              ),
              _FilterButton(
                label: 'Inactivos',
                selected: filter == _TrainerFilter.inactive,
                onTap: () => onFilter(_TrainerFilter.inactive),
              ),
              PulsoIconButton(
                icon: Icons.refresh,
                tooltip: 'Actualizar',
                onPressed: onRefresh,
              ),
            ],
          );
          return constraints.maxWidth < 780
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [search, const SizedBox(height: 8), controls],
                )
              : Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 10),
                    controls,
                  ],
                );
        },
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Material(
      color: selected ? tokens.accentSoft : tokens.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? tokens.accent : tokens.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? tokens.chalk : tokens.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrainerAvatar extends StatelessWidget {
  const _TrainerAvatar({required this.trainer, this.size = 36});
  final TrainerModel trainer;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final fallback = Center(
      child: Text(
        _initials(trainer),
        style: TextStyle(
          fontFamily: PulsoFonts.mono,
          fontSize: size * 0.32,
          fontWeight: FontWeight.w600,
          color: tokens.muted,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border.all(color: tokens.line),
      ),
      child: trainer.foto?.isNotEmpty == true
          ? Base64Image(
              base64String: trainer.foto!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: fallback,
            )
          : fallback,
    );
  }
}

class _TrainerWorkspace extends StatelessWidget {
  const _TrainerWorkspace({
    required this.items,
    required this.stats,
    required this.selected,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onClients,
  });
  final List<TrainerModel> items;
  final _TrainerStats stats;
  final TrainerModel? selected;
  final _TrainerSort sort;
  final bool ascending;
  final ValueChanged<_TrainerSort> onSort;
  final ValueChanged<TrainerModel> onSelect;
  final ValueChanged<TrainerModel> onEdit;
  final ValueChanged<TrainerModel> onDelete;
  final ValueChanged<TrainerModel> onClients;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final list = _TrainerList(
          items: items,
          stats: stats,
          selectedId: selected?.id,
          sort: sort,
          ascending: ascending,
          onSort: onSort,
          onSelect: onSelect,
          onEdit: onEdit,
          onDelete: onDelete,
          onClients: onClients,
        );
        if (constraints.maxWidth < 1040) return list;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: list),
            const SizedBox(width: 12),
            SizedBox(
              width: 330,
              child: _TrainerDetail(
                trainer: selected,
                stats: stats,
                onEdit: selected == null ? null : () => onEdit(selected!),
                onDelete: selected == null ? null : () => onDelete(selected!),
                onClients: selected == null
                    ? null
                    : () => onClients(selected!),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TrainerList extends StatelessWidget {
  const _TrainerList({
    required this.items,
    required this.stats,
    required this.selectedId,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onClients,
  });
  final List<TrainerModel> items;
  final _TrainerStats stats;
  final String? selectedId;
  final _TrainerSort sort;
  final bool ascending;
  final ValueChanged<_TrainerSort> onSort;
  final ValueChanged<TrainerModel> onSelect;
  final ValueChanged<TrainerModel> onEdit;
  final ValueChanged<TrainerModel> onDelete;
  final ValueChanged<TrainerModel> onClients;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 46),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: tokens.line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _SortButton(
                        label: 'Entrenador',
                        active: sort == _TrainerSort.name,
                        ascending: ascending,
                        onTap: () => onSort(_TrainerSort.name),
                      ),
                    ),
                    if (!compact) ...[
                      const Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PulsoLabel('Contacto'),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _SortButton(
                          label: 'Socios',
                          active: sort == _TrainerSort.clients,
                          ascending: ascending,
                          onTap: () => onSort(_TrainerSort.clients),
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PulsoLabel('Estado'),
                        ),
                      ),
                      const SizedBox(width: 100),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  key: const PageStorageKey('pulso-trainers-list'),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: tokens.line),
                  itemBuilder: (context, index) {
                    final trainer = items[index];
                    return _TrainerRow(
                      key: ValueKey(trainer.id),
                      trainer: trainer,
                      stats: stats,
                      selected: selectedId == trainer.id,
                      compact: compact,
                      onSelect: () => onSelect(trainer),
                      onEdit: () => onEdit(trainer),
                      onDelete: () => onDelete(trainer),
                      onClients: () => onClients(trainer),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: tokens.line)),
                ),
                child: Text(
                  '${items.length} resultados · socios por entrenador',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 9,
                    color: tokens.muted2,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
  });
  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.zero,
        foregroundColor: active ? tokens.accent : tokens.muted,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: PulsoLabel(label, color: active ? tokens.accent : null),
          ),
          if (active) ...[
            const SizedBox(width: 4),
            Icon(
              ascending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 12,
            ),
          ],
        ],
      ),
    );
  }
}

class _OffboardingFinanceCard extends StatelessWidget {
  const _OffboardingFinanceCard({required this.item});
  final TrainerOffboardingFinanceImpact item;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      width: 222,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(border: Border.all(color: tokens.lineStrong)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: PulsoLabel(item.currencyCode)),
              Text(
                (item.pendingCommission + item.pendingFixed).toStringAsFixed(2),
                style: TextStyle(
                  color: tokens.warning,
                  fontFamily: PulsoFonts.mono,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _OffboardingMoneyLine(
            label: 'Comisión ganada',
            value: item.earnedCommission,
          ),
          _OffboardingMoneyLine(
            label: 'Comisión pagada',
            value: item.paidCommission,
          ),
          _OffboardingMoneyLine(
            label: 'Comisión pendiente',
            value: item.pendingCommission,
            warning: true,
          ),
          _OffboardingMoneyLine(
            label: 'Comisión futura',
            value: item.futureCommission,
          ),
          _OffboardingMoneyLine(
            label: 'Fijo pendiente',
            value: item.pendingFixed,
            warning: true,
          ),
        ],
      ),
    );
  }
}

class _OffboardingFinanceCompactCard extends StatelessWidget {
  const _OffboardingFinanceCompactCard({required this.item});
  final TrainerOffboardingFinanceImpact item;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final pending = item.pendingCommission + item.pendingFixed;
    return Container(
      width: 218,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(border: Border.all(color: tokens.lineStrong)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: PulsoLabel(item.currencyCode)),
              Text(
                pending.toStringAsFixed(2),
                style: TextStyle(
                  color: pending > 0 ? tokens.warning : tokens.success,
                  fontFamily: PulsoFonts.mono,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'pendiente ganado · futuro ${item.futureCommission.toStringAsFixed(2)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _OffboardingMoneyLine extends StatelessWidget {
  const _OffboardingMoneyLine({
    required this.label,
    required this.value,
    this.warning = false,
  });
  final String label;
  final double value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: tokens.muted, fontSize: 11),
            ),
          ),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              color: warning && value > 0 ? tokens.warning : tokens.chalkDim,
              fontFamily: PulsoFonts.mono,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OffboardingMembershipRow extends StatelessWidget {
  const _OffboardingMembershipRow({required this.item});
  final TrainerOffboardingMembershipImpact item;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.clientId} · ${item.planName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              'hasta ${_dateFmt.format(item.endDate.toUtc())}',
              style: const TextStyle(fontFamily: PulsoFonts.mono, fontSize: 10),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'REASIGNAR',
            style: TextStyle(
              color: tokens.accent,
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OffboardingImpactTable extends StatefulWidget {
  const _OffboardingImpactTable({required this.items});
  final List<TrainerOffboardingMembershipImpact> items;

  @override
  State<_OffboardingImpactTable> createState() =>
      _OffboardingImpactTableState();
}

class _OffboardingImpactTableState extends State<_OffboardingImpactTable> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: tokens.line)),
      child: Column(
        children: [
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: tokens.raised,
            child: const Row(
              children: [
                Expanded(flex: 3, child: PulsoLabel('Socio / plan')),
                SizedBox(width: 12),
                Expanded(flex: 2, child: PulsoLabel('Vigencia')),
                SizedBox(width: 12),
                PulsoLabel('Sugerencia'),
              ],
            ),
          ),
          Expanded(
            child: widget.items.isEmpty
                ? Center(
                    child: Text(
                      'No hay membresías vigentes asignadas.',
                      style: TextStyle(color: tokens.muted),
                    ),
                  )
                : Scrollbar(
                    key: const Key('offboarding-impact-table-scrollbar'),
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: ListView.builder(
                      key: const PageStorageKey('offboarding-impact-table'),
                      controller: _scrollController,
                      primary: false,
                      itemCount: widget.items.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _OffboardingMembershipRow(
                          item: widget.items[index],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CreateOffboardingCaseDialog extends StatefulWidget {
  const _CreateOffboardingCaseDialog({
    required this.trainerName,
    required this.businessDate,
  });
  final String trainerName;
  final String businessDate;

  @override
  State<_CreateOffboardingCaseDialog> createState() =>
      _CreateOffboardingCaseDialogState();
}

class _CreateOffboardingCaseDialogState
    extends State<_CreateOffboardingCaseDialog> {
  late DateTime _effectiveDate;
  final _reason = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _effectiveDate =
        DateTime.tryParse('${widget.businessDate}T00:00:00.000Z')?.toUtc() ??
        DateTime.utc(2000);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveDate,
      firstDate: _effectiveDate,
      lastDate: DateTime.utc(_effectiveDate.year + 2, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() {
        _effectiveDate = DateTime.utc(picked.year, picked.month, picked.day);
        _error = null;
      });
    }
  }

  void _submit() {
    final reason = _reason.text.trim();
    if (reason.length < 5) {
      setState(() => _error = 'Explique brevemente el motivo de la baja.');
      return;
    }
    Navigator.of(context).pop(
      _NewOffboardingCaseInput(
        effectiveDate: _dateFmt.format(_effectiveDate),
        reason: reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear expediente de baja'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Entrenador: ${widget.trainerName}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha efectiva',
                  suffixIcon: Icon(Icons.calendar_month_outlined),
                ),
                child: Text(_dateFmt.format(_effectiveDate)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _reason,
              autofocus: true,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo administrativo',
                hintText:
                    'Ej.: terminación de contrato solicitada por el entrenador',
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        PulsoSecondaryButton(
          label: 'Cancelar',
          onPressed: () => Navigator.of(context).pop(),
        ),
        PulsoPrimaryButton(label: 'Crear expediente', onPressed: _submit),
      ],
    );
  }
}

class _NewOffboardingCaseInput {
  const _NewOffboardingCaseInput({
    required this.effectiveDate,
    required this.reason,
  });
  final String effectiveDate;
  final String reason;
}

class _TrainerRow extends StatelessWidget {
  const _TrainerRow({
    super.key,
    required this.trainer,
    required this.stats,
    required this.selected,
    required this.compact,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onClients,
  });
  final TrainerModel trainer;
  final _TrainerStats stats;
  final bool selected;
  final bool compact;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClients;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final count = stats.of(trainer);
    final membersLabel = !stats.ready
        ? '—'
        : count == 0
        ? 'sin socios'
        : count == 1
        ? '1 socio'
        : '$count socios';
    final membersColor = !stats.ready
        ? tokens.muted
        : count == 0
        ? tokens.muted
        : tokens.success;
    final name = _fullName(trainer);
    return Material(
      color: selected ? tokens.accentSoftStrong : Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? tokens.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              _TrainerAvatar(trainer: trainer),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: trainer.activo ? tokens.chalk : tokens.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      compact
                          ? 'CI ${trainer.ci} · $membersLabel'
                          : 'CI ${trainer.ci}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: PulsoFonts.mono,
                        fontSize: 9.5,
                        color: compact ? membersColor : tokens.muted2,
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                Expanded(
                  flex: 3,
                  child: Text(
                    _contactLine(trainer),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 11,
                      color: tokens.muted,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _TrainerClientsCell(
                    label: membersLabel,
                    color: membersColor,
                    trainerName: name,
                    // Sin socios no hay a quién ir a ver: el contador se queda
                    // como texto y no promete una lista vacía.
                    onTap: stats.ready && count > 0 ? onClients : null,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _TrainerStatus(active: trainer.activo),
                ),
                SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      PulsoIconButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Editar $name',
                        onPressed: onEdit,
                      ),
                      const SizedBox(width: 4),
                      PulsoIconButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Preparar baja de $name',
                        danger: true,
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ),
              ] else
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                    if (value == 'clients') onClients();
                  },
                  itemBuilder: (context) => [
                    if (stats.ready && count > 0)
                      const PopupMenuItem(
                        value: 'clients',
                        child: Text('Ver sus socios'),
                      ),
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Preparar baja'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El número grande del detalle, pulsable cuando hay socios que enseñar.
class _DetailClientsLink extends StatelessWidget {
  const _DetailClientsLink({
    super.key,
    required this.value,
    required this.trainerName,
    required this.onTap,
  });

  final String value;
  final String trainerName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final text = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: PulsoFonts.display,
        fontSize: 48,
        height: 0.9,
        fontWeight: FontWeight.w800,
        color: tokens.accent,
        decoration: onTap == null ? null : TextDecoration.underline,
        decorationColor: tokens.accent,
      ),
    );
    if (onTap == null) return text;
    return Tooltip(
      message: 'Ver los socios de $trainerName en Clientes',
      child: InkWell(onTap: onTap, child: text),
    );
  }
}

/// Contador de socios de la fila. Cuando hay a quién enseñar, lleva a Clientes
/// con ese entrenador filtrado; cuando no, es texto y ya.
class _TrainerClientsCell extends StatelessWidget {
  const _TrainerClientsCell({
    required this.label,
    required this.color,
    required this.trainerName,
    required this.onTap,
  });

  final String label;
  final Color color;
  final String trainerName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: PulsoFonts.mono,
        fontWeight: FontWeight.w600,
        color: color,
        decoration: onTap == null ? null : TextDecoration.underline,
        decorationColor: color,
      ),
    );
    if (onTap == null) return text;
    return Tooltip(
      message: 'Ver los socios de $trainerName en Clientes',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: text,
        ),
      ),
    );
  }
}

class _TrainerStatus extends StatelessWidget {
  const _TrainerStatus({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = active ? tokens.success : tokens.warning;
    return Row(
      children: [
        Container(width: 6, height: 6, color: color),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            active ? 'ACTIVO' : 'INACTIVO',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrainerDetail extends StatelessWidget {
  const _TrainerDetail({
    required this.trainer,
    required this.stats,
    required this.onEdit,
    required this.onDelete,
    required this.onClients,
  });
  final TrainerModel? trainer;
  final _TrainerStats stats;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onClients;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final selected = trainer;
    if (selected == null) {
      return const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.empty,
          message: 'Selecciona un entrenador para ver su detalle.',
        ),
      );
    }
    final count = stats.of(selected);
    return PulsoPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PulsoLabel('Detalle seleccionado'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // El número grande es el enlace a la lista de esos socios: es lo
              // primero que se mira al preguntarse «¿quiénes son?».
              _DetailClientsLink(
                key: const ValueKey('trainer-detail-clients'),
                value: stats.ready ? '$count' : '—',
                trainerName: _fullName(selected),
                onTap: stats.ready && count > 0 ? onClients : null,
              ),
              const Spacer(),
              _TrainerAvatar(trainer: selected, size: 48),
            ],
          ),
          const SizedBox(height: 4),
          PulsoLabel(
            stats.ready && count > 0
                ? 'Socios asignados · ver lista'
                : 'Socios asignados',
          ),
          const SizedBox(height: 9),
          Text(
            _fullName(selected),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            selected.activo ? 'ACTIVO' : 'INACTIVO',
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: selected.activo ? tokens.success : tokens.warning,
            ),
          ),
          const SizedBox(height: 12),
          _DetailLine(label: 'CI', value: selected.ci),
          _DetailLine(
            label: 'Teléfono',
            value: selected.telefono?.toString() ?? '—',
          ),
          _DetailLine(
            label: 'Correo',
            value: selected.correo?.trim().isNotEmpty == true
                ? selected.correo!.trim()
                : '—',
          ),
          _DetailLine(label: 'Alta', value: _startDate(selected)),
          const Spacer(),
          PulsoPrimaryButton(
            label: 'Editar entrenador',
            icon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
          const SizedBox(height: 8),
          PulsoSecondaryButton(
            label: 'Preparar baja',
            icon: Icons.delete_outline,
            danger: true,
            onPressed: onDelete,
          ),
          const SizedBox(height: 14),
          Text(
            selected.id,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              color: tokens.muted2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: [
          Expanded(child: PulsoLabel(label)),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: PulsoFonts.mono,
                fontWeight: FontWeight.w600,
                color: tokens.chalkDim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerFooter extends StatelessWidget {
  const _TrainerFooter();
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Row(
      children: [
        const PulsoSyncStatus(compact: true),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'PULSO · ENTRENADORES · DATOS REALES',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              color: tokens.muted2,
            ),
          ),
        ),
      ],
    );
  }
}
