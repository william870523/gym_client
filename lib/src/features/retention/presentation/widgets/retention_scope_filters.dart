import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/retention_models.dart';
import '../state/retention_providers.dart';

class RetentionScopeFilters extends ConsumerWidget {
  const RetentionScopeFilters({
    super.key,
    required this.dashboard,
    required this.compact,
    required this.onCompare,
    required this.onExport,
  });

  final RetentionDashboardModel dashboard;
  final bool compact;
  final VoidCallback onCompare;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(retentionFilterProvider);
    final from = query.from ?? dashboard.window.from;
    final to = query.to ?? dashboard.window.to;
    if (compact || MediaQuery.sizeOf(context).width < 1000) {
      return _CompactScope(
        dashboard: dashboard,
        query: query,
        from: from,
        to: to,
        onCompare: onCompare,
        onOpen: () => showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _ScopeDialog(dashboard: dashboard),
        ),
        onExport: onExport,
      );
    }
    return PulsoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      color: PulsoTokens.of(context).raised,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 9,
        runSpacing: 9,
        children: [
          _DateAction(
            label: 'Desde',
            value: from,
            onTap: () => _pickDate(context, ref, dashboard, fromField: true),
          ),
          _DateAction(
            label: 'Hasta',
            value: to,
            onTap: () => _pickDate(context, ref, dashboard, fromField: false),
          ),
          _PeriodMenu(dashboard: dashboard),
          SizedBox(
            width: 220,
            child: KeyedSubtree(
              key: const ValueKey('retention-plan-filter'),
              child: DropdownButtonFormField<String?>(
                key: ValueKey(query.planId),
                initialValue: query.planId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Plan',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Todos los planes'),
                  ),
                  for (final option in dashboard.dimensions.plans)
                    DropdownMenuItem(
                      value: option.id,
                      child: Text('${option.name} · ${option.count}'),
                    ),
                ],
                onChanged: ref.read(retentionFilterProvider.notifier).setPlan,
              ),
            ),
          ),
          SizedBox(
            width: 220,
            child: KeyedSubtree(
              key: const ValueKey('retention-trainer-filter'),
              child: DropdownButtonFormField<String?>(
                key: ValueKey(query.trainerId),
                initialValue: query.trainerId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Entrenador atribuido',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Todos los entrenadores'),
                  ),
                  for (final option in dashboard.dimensions.trainers)
                    DropdownMenuItem(
                      value: option.id,
                      child: Text('${option.name} · ${option.count}'),
                    ),
                ],
                onChanged: ref
                    .read(retentionFilterProvider.notifier)
                    .setTrainer,
              ),
            ),
          ),
          if (_hasFilters(query))
            PulsoSecondaryButton(
              label: 'Limpiar',
              icon: Icons.filter_alt_off_outlined,
              onPressed: ref.read(retentionFilterProvider.notifier).clear,
            ),
          PulsoSecondaryButton(
            label: 'Comparar',
            icon: Icons.analytics_outlined,
            onPressed: onCompare,
          ),
          PulsoSecondaryButton(
            label: 'Exportar',
            icon: Icons.file_download_outlined,
            onPressed: onExport,
          ),
        ],
      ),
    );
  }
}

class _CompactScope extends StatelessWidget {
  const _CompactScope({
    required this.dashboard,
    required this.query,
    required this.from,
    required this.to,
    required this.onOpen,
    required this.onCompare,
    required this.onExport,
  });

  final RetentionDashboardModel dashboard;
  final RetentionDashboardQuery query;
  final String from;
  final String to;
  final VoidCallback onOpen;
  final VoidCallback onCompare;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final selections = [
      if (query.planId != null)
        dashboard.dimensions.plans
            .where((item) => item.id == query.planId)
            .map((item) => item.name)
            .firstOrNull,
      if (query.trainerId != null)
        dashboard.dimensions.trainers
            .where((item) => item.id == query.trainerId)
            .map((item) => item.name)
            .firstOrNull,
    ].whereType<String>().join(' · ');
    return PulsoPanel(
      padding: const EdgeInsets.fromLTRB(13, 9, 7, 9),
      color: tokens.raised,
      child: Row(
        children: [
          Icon(Icons.tune, size: 18, color: tokens.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PulsoLabel('Alcance del análisis'),
                const SizedBox(height: 2),
                Text(
                  '${_shortDate(from)} — ${_shortDate(to)}${selections.isEmpty ? '' : ' · $selections'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: tokens.chalkDim),
                ),
              ],
            ),
          ),
          PulsoIconButton(
            tooltip: 'Cambiar filtros',
            icon: Icons.filter_alt_outlined,
            onPressed: onOpen,
          ),
          PulsoIconButton(
            tooltip: 'Comparar planes y entrenadores',
            icon: Icons.analytics_outlined,
            onPressed: onCompare,
          ),
          PulsoIconButton(
            tooltip: 'Exportar resultado',
            icon: Icons.file_download_outlined,
            onPressed: onExport,
          ),
        ],
      ),
    );
  }
}

class _DateAction extends StatelessWidget {
  const _DateAction({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.calendar_today_outlined, size: 16),
    label: Text('${label.toUpperCase()} · ${_shortDate(value)}'),
  );
}

class _PeriodMenu extends ConsumerWidget {
  const _PeriodMenu({required this.dashboard});

  final RetentionDashboardModel dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<int>(
    tooltip: 'Períodos rápidos',
    onSelected: (days) {
      final today = _date(dashboard.businessDate);
      final from = today.subtract(Duration(days: days - 1));
      ref
          .read(retentionFilterProvider.notifier)
          .setPeriod(_dateOnly(from), dashboard.businessDate);
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 30, child: Text('Últimos 30 días')),
      PopupMenuItem(value: 90, child: Text('Últimos 90 días')),
      PopupMenuItem(value: 180, child: Text('Últimos 180 días')),
      PopupMenuItem(value: 365, child: Text('Últimos 365 días')),
    ],
    child: const _MenuButton(),
  );
}

class _MenuButton extends StatelessWidget {
  const _MenuButton();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: OutlinedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.date_range_outlined, size: 16),
      label: const Text('PERÍODO'),
    ),
  );
}

class _ScopeDialog extends ConsumerStatefulWidget {
  const _ScopeDialog({required this.dashboard});

  final RetentionDashboardModel dashboard;

  @override
  ConsumerState<_ScopeDialog> createState() => _ScopeDialogState();
}

class _ScopeDialogState extends ConsumerState<_ScopeDialog> {
  late String _from;
  late String _to;
  String? _planId;
  String? _trainerId;

  @override
  void initState() {
    super.initState();
    final query = ref.read(retentionFilterProvider);
    _from = query.from ?? widget.dashboard.window.from;
    _to = query.to ?? widget.dashboard.window.to;
    _planId = query.planId;
    _trainerId = query.trainerId;
  }

  Future<void> _pick(bool fromField) async {
    final businessDate = _date(widget.dashboard.businessDate);
    final current = _date(fromField ? _from : _to);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: businessDate.subtract(const Duration(days: 730)),
      lastDate: businessDate.add(const Duration(days: 365)),
      helpText: fromField ? 'DESDE' : 'HASTA',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (fromField) {
        _from = _dateOnly(picked);
        if (_date(_from).isAfter(_date(_to))) _to = _from;
      } else {
        _to = _dateOnly(picked);
        if (_date(_to).isBefore(_date(_from))) _from = _to;
      }
    });
  }

  @override
  Widget build(BuildContext context) => PulsoThemeScope(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final tokens = PulsoTokens.of(context);
        return Center(
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: (constraints.maxWidth - 32).clamp(320.0, 540.0),
              height: (constraints.maxHeight - 32).clamp(480.0, 620.0),
              child: PulsoPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 15, 10, 14),
                      color: tokens.raised,
                      child: Row(
                        children: [
                          Container(width: 7, height: 40, color: tokens.accent),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                PulsoLabel('CONTROL Y CALIDAD'),
                                Text(
                                  'ALCANCE DEL ANÁLISIS',
                                  style: TextStyle(
                                    fontFamily: PulsoFonts.display,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PulsoIconButton(
                            tooltip: 'Cerrar',
                            icon: Icons.close,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _DateAction(
                                  label: 'Desde',
                                  value: _from,
                                  onTap: () => _pick(true),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DateAction(
                                  label: 'Hasta',
                                  value: _to,
                                  onTap: () => _pick(false),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String?>(
                            initialValue: _planId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Plan',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Todos los planes'),
                              ),
                              for (final item
                                  in widget.dashboard.dimensions.plans)
                                DropdownMenuItem(
                                  value: item.id,
                                  child: Text(item.name),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _planId = value),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String?>(
                            initialValue: _trainerId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Entrenador atribuido',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Todos los entrenadores'),
                              ),
                              for (final item
                                  in widget.dashboard.dimensions.trainers)
                                DropdownMenuItem(
                                  value: item.id,
                                  child: Text(item.name),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _trainerId = value),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Las métricas se recalculan para este alcance. El estado operativo y la búsqueda refinan únicamente la cola visible.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.45,
                              color: tokens.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: tokens.line)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          PulsoSecondaryButton(
                            label: 'Limpiar',
                            onPressed: () {
                              ref
                                  .read(retentionFilterProvider.notifier)
                                  .clear();
                              Navigator.pop(context);
                            },
                          ),
                          const SizedBox(width: 8),
                          PulsoPrimaryButton(
                            label: 'Aplicar',
                            icon: Icons.check,
                            onPressed: () {
                              ref
                                  .read(retentionFilterProvider.notifier)
                                  .replace(
                                    RetentionDashboardQuery(
                                      from: _from,
                                      to: _to,
                                      planId: _planId,
                                      trainerId: _trainerId,
                                    ),
                                  );
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

Future<void> _pickDate(
  BuildContext context,
  WidgetRef ref,
  RetentionDashboardModel dashboard, {
  required bool fromField,
}) async {
  final query = ref.read(retentionFilterProvider);
  final from = query.from ?? dashboard.window.from;
  final to = query.to ?? dashboard.window.to;
  final businessDate = _date(dashboard.businessDate);
  final picked = await showDatePicker(
    context: context,
    initialDate: _date(fromField ? from : to),
    firstDate: businessDate.subtract(const Duration(days: 730)),
    lastDate: businessDate.add(const Duration(days: 365)),
    helpText: fromField ? 'DESDE' : 'HASTA',
  );
  if (picked == null || !context.mounted) return;
  var nextFrom = from;
  var nextTo = to;
  if (fromField) {
    nextFrom = _dateOnly(picked);
    if (_date(nextFrom).isAfter(_date(nextTo))) nextTo = nextFrom;
  } else {
    nextTo = _dateOnly(picked);
    if (_date(nextTo).isBefore(_date(nextFrom))) nextFrom = nextTo;
  }
  ref.read(retentionFilterProvider.notifier).setPeriod(nextFrom, nextTo);
}

bool _hasFilters(RetentionDashboardQuery query) =>
    query.from != null ||
    query.to != null ||
    query.planId != null ||
    query.trainerId != null;

DateTime _date(String value) => DateTime.parse('${value}T00:00:00Z').toUtc();
String _dateOnly(DateTime value) =>
    DateFormat('yyyy-MM-dd').format(value.toUtc());
String _shortDate(String value) =>
    DateFormat('dd/MM/yyyy').format(_date(value));
