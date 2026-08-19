import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/time/app_clock.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/treasury_period_models.dart';
import '../../data/repositories/accounting_repository.dart';
import '../../data/services/treasury_period_close_report_service.dart';
import '../state/accounting_providers.dart';
import 'solicitud_cierre_aviso.dart';
import 'treasury_monthly_panel.dart';

enum _PeriodPreset { day, week, month, custom }

class TreasuryPeriodClosePanel extends ConsumerStatefulWidget {
  const TreasuryPeriodClosePanel({super.key, required this.onChanged});

  final VoidCallback onChanged;

  @override
  ConsumerState<TreasuryPeriodClosePanel> createState() =>
      _TreasuryPeriodClosePanelState();
}

class _TreasuryPeriodClosePanelState
    extends ConsumerState<TreasuryPeriodClosePanel> {
  late DateTime _from;
  late DateTime _to;
  _PeriodPreset _preset = _PeriodPreset.day;
  String? _currencyId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final today = todayInZone(appClock.gymTimezone);
    _from = today;
    _to = today;
  }

  String _date(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

  TreasuryPeriodRequest get _request => TreasuryPeriodRequest(
    from: _date(_from),
    to: _date(_to),
    type: switch (_preset) {
      _PeriodPreset.day => 'DIARIO',
      _PeriodPreset.week => 'SEMANAL',
      _PeriodPreset.month => 'MENSUAL',
      _PeriodPreset.custom => 'PERSONALIZADO',
    },
  );

  void _selectPreset(_PeriodPreset preset) {
    final anchor = _from;
    setState(() {
      _preset = preset;
      switch (preset) {
        case _PeriodPreset.day:
          _to = anchor;
        case _PeriodPreset.week:
          _from = anchor.subtract(Duration(days: anchor.weekday - 1));
          _to = _from.add(const Duration(days: 6));
        case _PeriodPreset.month:
          _from = DateTime(anchor.year, anchor.month);
          _to = DateTime(anchor.year, anchor.month + 1, 0);
        case _PeriodPreset.custom:
          if (_to.isBefore(_from)) _to = _from;
      }
      _currencyId = null;
    });
  }

  Future<void> _pickDate({required bool from}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: todayInZone(appClock.gymTimezone),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _preset = _PeriodPreset.custom;
      if (from) {
        _from = selected;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = selected;
        if (_to.isBefore(_from)) _from = _to;
      }
      _currencyId = null;
    });
  }

  /// Carga el período que administración pidió (M5, docs/MULTI_SEDE.md §6.2).
  ///
  /// El preset se deduce de la **forma** del rango, igual que lo hace el
  /// servidor al normalizarlo: un mes natural se firma con el cierre mensual
  /// formal y nunca crea certificado por período, así que ofrecerlo como
  /// `PERSONALIZADO` acabaría en un rechazo `USE_MENSUAL` que el operador no
  /// tiene por qué entender.
  void _cargarPeriodoPedido(DateTime desde, DateTime hastaIncluido) {
    final dias = hastaIncluido.difference(desde).inDays + 1;
    final mesNatural =
        desde.day == 1 &&
        hastaIncluido.day == DateTime(desde.year, desde.month + 1, 0).day &&
        desde.month == hastaIncluido.month &&
        desde.year == hastaIncluido.year;
    setState(() {
      _from = desde;
      _to = hastaIncluido;
      _currencyId = null;
      _preset = mesNatural
          ? _PeriodPreset.month
          : dias == 1
          ? _PeriodPreset.day
          : (dias == 7 && desde.weekday == DateTime.monday)
          ? _PeriodPreset.week
          : _PeriodPreset.custom;
    });
  }

  void _refresh() {
    ref.invalidate(treasuryPeriodSummaryProvider(_request));
    ref.invalidate(treasuryPeriodClosesProvider(_request));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // M5 — lo que administración pide, delante de quien puede firmarlo.
            SolicitudCierreAviso(onCargarPeriodo: _cargarPeriodoPedido),
            PulsoPanel(
              padding: const EdgeInsets.all(14),
              child: _PeriodSelector(
                preset: _preset,
                from: _date(_from),
                to: _date(_to),
                compact: compact,
                onPreset: _selectPreset,
                onFrom: () => _pickDate(from: true),
                onTo: () => _pickDate(from: false),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _preset == _PeriodPreset.month
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          color: tokens.raised,
                          child: Text(
                            'El mes natural ${_date(_from)} → ${_date(_to)} usa el cierre mensual formal; no crea un certificado paralelo.',
                            style: TextStyle(color: tokens.chalkDim),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: TreasuryMonthlyPanel(
                            onChanged: widget.onChanged,
                          ),
                        ),
                      ],
                    )
                  : ref
                        .watch(treasuryPeriodSummaryProvider(_request))
                        .when(
                          loading: () => const PulsoPanel(
                            child: PulsoStateView(
                              kind: PulsoStateKind.loading,
                              message: 'Calculando el cierre por período…',
                            ),
                          ),
                          error: (error, _) => PulsoPanel(
                            child: PulsoStateView(
                              kind: PulsoStateKind.error,
                              message:
                                  'No se pudo calcular el período.\n${_errorText(error)}',
                              onRetry: _refresh,
                            ),
                          ),
                          data: (summary) => _PeriodBody(
                            summary: summary,
                            selectedCurrencyId: _currencyId,
                            busy: _busy,
                            onCurrency: (value) =>
                                setState(() => _currencyId = value),
                            history: ref.watch(
                              treasuryPeriodClosesProvider(_request),
                            ),
                            onSign: summary.canSign
                                ? () => _changeState(summary, reopen: false)
                                : null,
                            onReopen:
                                summary.canReopen && summary.activeCycle != null
                                ? () => _changeState(summary, reopen: true)
                                : null,
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changeState(
    TreasuryPeriodSummaryModel summary, {
    required bool reopen,
  }) async {
    final reason = await _reasonDialog(reopen: reopen);
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final repository = ref.read(accountingRepositoryProvider);
      if (reopen) {
        await repository.reopenTreasuryPeriod(
          closeId: summary.activeCycle!.id,
          operationId: const Uuid().v4(),
          reason: reason,
        );
      } else {
        await repository.closeTreasuryPeriod(
          request: _request,
          operationId: const Uuid().v4(),
          reason: reason,
        );
      }
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reopen
                ? 'El ciclo fue reabierto; su certificado se conserva.'
                : 'Período firmado y certificado.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _reasonDialog({required bool reopen}) async {
    final controller = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          key: Key(
            reopen
                ? 'treasury-period-reopen-dialog'
                : 'treasury-period-sign-dialog',
          ),
          title: Text(reopen ? 'Reabrir ciclo' : 'Firmar período'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    reopen
                        ? 'El certificado original y su SHA se conservarán.'
                        : 'La firma congela el detalle y genera una huella SHA-256.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('treasury-period-reason'),
                    controller: controller,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Motivo (mínimo 10 caracteres)',
                      errorText: error,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('treasury-period-confirm'),
              onPressed: () {
                final value = controller.text.trim();
                if (value.length < 10) {
                  setDialogState(
                    () =>
                        error = 'Escriba un motivo de al menos 10 caracteres.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: Text(reopen ? 'Reabrir' : 'Firmar'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 350), controller.dispose);
    return result;
  }
}

String _errorText(Object error) {
  if (error is DioException && error.response?.data is Map) {
    return ((error.response!.data as Map)['error'] ?? error.message).toString();
  }
  return error.toString();
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.preset,
    required this.from,
    required this.to,
    required this.compact,
    required this.onPreset,
    required this.onFrom,
    required this.onTo,
  });

  final _PeriodPreset preset;
  final String from;
  final String to;
  final bool compact;
  final ValueChanged<_PeriodPreset> onPreset;
  final VoidCallback onFrom;
  final VoidCallback onTo;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final presets = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in _PeriodPreset.values)
          ChoiceChip(
            key: ValueKey('treasury-period-preset-${item.name}'),
            label: Text(switch (item) {
              _PeriodPreset.day => 'DÍA',
              _PeriodPreset.week => 'SEMANA',
              _PeriodPreset.month => 'MES',
              _PeriodPreset.custom => 'PERSONALIZADO',
            }),
            selected: preset == item,
            onSelected: (_) => onPreset(item),
          ),
      ],
    );
    final dates = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          key: const Key('treasury-period-from'),
          onPressed: onFrom,
          icon: const Icon(Icons.event_outlined, size: 16),
          label: Text('DESDE $from'),
        ),
        Icon(Icons.arrow_forward, size: 16, color: tokens.muted),
        OutlinedButton.icon(
          key: const Key('treasury-period-to'),
          onPressed: onTo,
          icon: const Icon(Icons.event_available_outlined, size: 16),
          label: Text('HASTA $to'),
        ),
      ],
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [presets, const SizedBox(height: 10), dates],
      );
    }
    return Row(
      children: [
        Expanded(child: presets),
        const SizedBox(width: 12),
        dates,
      ],
    );
  }
}

class _PeriodBody extends StatelessWidget {
  const _PeriodBody({
    required this.summary,
    required this.selectedCurrencyId,
    required this.busy,
    required this.onCurrency,
    required this.history,
    required this.onSign,
    required this.onReopen,
  });

  final TreasuryPeriodSummaryModel summary;
  final String? selectedCurrencyId;
  final bool busy;
  final ValueChanged<String?> onCurrency;
  final AsyncValue<TreasuryPeriodCyclesModel> history;
  final VoidCallback? onSign;
  final VoidCallback? onReopen;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final selected = selectedCurrencyId == null
        ? summary.currencies
        : summary.currencies
              .where((item) => item.id == selectedCurrencyId)
              .toList(growable: false);
    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: SingleChildScrollView(
          key: const Key('treasury-period-scroll'),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 8,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PulsoLabel('CIERRE POR PERÍODO'),
                      const SizedBox(height: 4),
                      Text(
                        '${summary.from} → ${summary.to} · ${summary.dayCount} días comerciales',
                        key: const Key('treasury-period-scope'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${summary.closeState} · zona ${summary.timezone}',
                        style: TextStyle(color: tokens.muted),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PulsoSecondaryButton(
                        key: const Key('treasury-period-export-pdf'),
                        label: 'PDF',
                        onPressed: () => _export(context, selected, pdf: true),
                      ),
                      PulsoSecondaryButton(
                        key: const Key('treasury-period-export-csv'),
                        label: 'CSV',
                        onPressed: () => _export(context, selected, pdf: false),
                      ),
                      PulsoSecondaryButton(
                        key: const Key('treasury-period-sign'),
                        label: 'Firmar período',
                        onPressed: busy ? null : onSign,
                      ),
                      if (summary.activeCycle != null)
                        PulsoSecondaryButton(
                          key: const Key('treasury-period-reopen'),
                          label: 'Reabrir ciclo',
                          onPressed: busy ? null : onReopen,
                        ),
                    ],
                  ),
                ],
              ),
              if (onSign == null && summary.closeState == 'ABIERTO') ...[
                const SizedBox(height: 8),
                Text(
                  summary.blockers.isEmpty
                      ? 'Su rol no tiene permiso para firmar este período.'
                      : 'La firma está deshabilitada hasta resolver las incidencias indicadas.',
                  key: const Key('treasury-period-sign-explanation'),
                  style: TextStyle(color: tokens.warning),
                ),
              ],
              if (summary.blockers.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Blockers(items: summary.blockers),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    key: const Key('treasury-period-currency-all'),
                    label: const Text('TODAS · SEPARADAS'),
                    selected: selectedCurrencyId == null,
                    onSelected: (_) => onCurrency(null),
                  ),
                  for (final currency in summary.currencies)
                    ChoiceChip(
                      key: ValueKey(
                        'treasury-period-currency-${currency.code}',
                      ),
                      label: Text(currency.code),
                      selected: selectedCurrencyId == currency.id,
                      onSelected: (_) => onCurrency(currency.id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              for (final currency in selected) ...[
                _CurrencySection(currency: currency, days: summary.days),
                const SizedBox(height: 12),
              ],
              _Payments(payments: summary.payments, currencies: selected),
              const SizedBox(height: 12),
              _History(history: history),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    List<TreasuryPeriodCurrencyModel> selected, {
    required bool pdf,
  }) async {
    try {
      const service = TreasuryPeriodCloseReportService();
      final ids = selected.map((item) => item.id).toList(growable: false);
      if (pdf) {
        await service.savePdf(summary, currencyIds: ids);
      } else {
        await service.saveCsv(summary, currencyIds: ids);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    }
  }
}

class _Blockers extends StatelessWidget {
  const _Blockers({required this.items});
  final List<TreasuryPeriodBlockerModel> items;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      key: const Key('treasury-period-blockers'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.warning.withValues(alpha: .08),
        border: Border.all(color: tokens.warning.withValues(alpha: .45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PulsoLabel('INCIDENCIAS QUE BLOQUEAN LA FIRMA'),
          const SizedBox(height: 8),
          for (final item in items)
            Text('• ${item.code.replaceAll('_', ' ')} · ${item.count}'),
        ],
      ),
    );
  }
}

class _CurrencySection extends StatelessWidget {
  const _CurrencySection({required this.currency, required this.days});
  final TreasuryPeriodCurrencyModel currency;
  final List<TreasuryPeriodDayModel> days;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat('#,##0.00');
    return Container(
      key: ValueKey('treasury-period-section-${currency.code}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: PulsoTokens.of(context).line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            currency.code,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 840
                  ? 4
                  : constraints.maxWidth >= 520
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 8) / columns;
              final metrics = <(String, String)>[
                ('Cobro bruto', money.format(currency.gross)),
                ('Cambio entregado', money.format(currency.change)),
                ('Anulaciones', money.format(currency.annulled)),
                ('Cobro neto', money.format(currency.netCollected)),
                ('Flujo neto', money.format(currency.netFlow)),
                (
                  'Cobros / clientes',
                  '${currency.paymentCount} / ${currency.clientCount}',
                ),
                (
                  'Cobertura diaria',
                  '${currency.coverage.toStringAsFixed(0)}%',
                ),
                ('Sin atribuir histórico', money.format(currency.unattributed)),
              ];
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final metric in metrics)
                    SizedBox(
                      width: width,
                      child: _Metric(label: metric.$1, value: metric.$2),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            key: ValueKey('treasury-period-collectors-${currency.code}'),
            tilePadding: EdgeInsets.zero,
            title: const Text('Cobros por recepcionista'),
            children: [
              for (final collector in currency.collectors)
                ListTile(
                  dense: true,
                  title: Text(collector.name),
                  subtitle: Text(
                    '${collector.paymentCount} cobros · ${collector.clientCount} clientes · bruto ${money.format(collector.gross)} · cambio ${money.format(collector.change)} · anulado ${money.format(collector.annulled)}',
                  ),
                  trailing: Text(
                    '${currency.code} ${money.format(collector.net)}',
                  ),
                ),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Cobertura de cuentas / días'),
            children: [
              for (final account in currency.accounts)
                ListTile(
                  dense: true,
                  title: Text(account.name),
                  subtitle: Text(
                    '${account.closedDays}/${account.activityDays} jornadas cerradas',
                  ),
                  trailing: Text(
                    '${currency.code} ${money.format(account.net)}',
                  ),
                ),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Evolución diaria'),
            children: [
              for (final day in days)
                for (final row in day.currencies.where(
                  (item) => item.currencyId == currency.id,
                ))
                  ListTile(
                    dense: true,
                    title: Text(day.businessDate),
                    subtitle: Text(
                      '+${money.format(row.entries)}  −${money.format(row.exits)}',
                    ),
                    trailing: Text(money.format(row.net)),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(10),
      color: tokens.raised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: tokens.muted, fontSize: 12)),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _Payments extends StatelessWidget {
  const _Payments({required this.payments, required this.currencies});
  final List<TreasuryPeriodPaymentModel> payments;
  final List<TreasuryPeriodCurrencyModel> currencies;

  @override
  Widget build(BuildContext context) {
    final ids = currencies.map((item) => item.id).toSet();
    final visible = payments
        .where(
          (payment) =>
              payment.details.any((row) => ids.contains(row.currencyId)),
        )
        .toList(growable: false);
    return ExpansionTile(
      key: const Key('treasury-period-payments'),
      tilePadding: EdgeInsets.zero,
      title: Text('Pagos y movimientos (${visible.length})'),
      children: [
        if (visible.isEmpty)
          const ListTile(title: Text('Sin pagos en el rango.')),
        for (final payment in visible)
          ExpansionTile(
            title: Text(payment.clientId),
            subtitle: Text(
              'Cobrado por ${payment.collectorName}${payment.annulledBy == null ? '' : ' · Anulado por ${payment.annulledBy}'}',
            ),
            children: [
              for (final row in payment.details.where(
                (item) => ids.contains(item.currencyId),
              ))
                ListTile(
                  dense: true,
                  title: Text(row.id),
                  subtitle: Text('${row.direction} · cuenta ${row.accountId}'),
                  trailing: Text(row.amount.toStringAsFixed(2)),
                ),
            ],
          ),
      ],
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.history});
  final AsyncValue<TreasuryPeriodCyclesModel> history;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: const Key('treasury-period-history'),
    tilePadding: EdgeInsets.zero,
    title: const Text('Historial de ciclos'),
    children: history.when(
      loading: () => const [
        Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ],
      error: (error, _) => [ListTile(title: Text(_errorText(error)))],
      data: (value) => value.cycles.isEmpty
          ? const [ListTile(title: Text('Todavía no hay ciclos.'))]
          : [
              for (final cycle in value.cycles)
                ListTile(
                  title: Text(
                    'Ciclo ${cycle.cycleNumber} · ${cycle.state} · ${cycle.integrityState}',
                  ),
                  subtitle: Text(
                    '${cycle.from} → ${cycle.to}\nFirmado por ${cycle.closerName} · SHA ${cycle.hash}',
                  ),
                  isThreeLine: true,
                ),
            ],
    ),
  );
}
