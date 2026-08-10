import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/accounting_models.dart';
import '../../data/repositories/accounting_repository.dart';
import '../../data/services/treasury_monthly_report_service.dart';
import '../state/accounting_providers.dart';

final _monthlyMoney = NumberFormat('#,##0.00');

class TreasuryMonthlyPanel extends ConsumerStatefulWidget {
  const TreasuryMonthlyPanel({super.key, required this.onChanged});

  final VoidCallback onChanged;

  @override
  ConsumerState<TreasuryMonthlyPanel> createState() =>
      _TreasuryMonthlyPanelState();
}

class _TreasuryMonthlyPanelState extends ConsumerState<TreasuryMonthlyPanel> {
  final _accountScroll = ScrollController();
  final _trendScroll = ScrollController();
  static const _reportService = TreasuryMonthlyReportService();
  String? _selectedMonth;
  String? _selectedCurrencyId;
  bool _exporting = false;
  bool _changingMonthClose = false;

  @override
  void dispose() {
    _accountScroll.dispose();
    _trendScroll.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(treasuryMonthlySummaryProvider(_selectedMonth));
    widget.onChanged();
  }

  /// Filas de cobradores del mes en la moneda seleccionada. El servidor ya las
  /// separa por moneda; aquí solo se elige la que el operador está mirando,
  /// para no mezclar CUP con USD en una misma tabla.
  List<TreasuryCollectorRowModel> _collectorsFor(
    TreasuryMonthlySummaryModel summary,
    TreasuryMonthlyCurrencyModel currency,
  ) => summary.collectorRows
      .where((row) => row.currencyId == currency.currencyId)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(treasuryMonthlySummaryProvider(_selectedMonth));
    return state.when(
      loading: () => const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.loading,
          message: 'Consolidando cierres y conciliaciones del mes…',
        ),
      ),
      error: (error, _) => PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.error,
          message: 'No se pudo cargar el consolidado mensual.\n$error',
          onRetry: _refresh,
        ),
      ),
      data: _buildSummary,
    );
  }

  Widget _buildSummary(TreasuryMonthlySummaryModel summary) {
    final currencies = summary.currencies;
    final compactMonthly = MediaQuery.sizeOf(context).width < 880;
    final selected = currencies
        .where((item) => item.currencyId == _selectedCurrencyId)
        .firstOrNull;
    final currency = selected ?? currencies.firstOrNull;
    if (currency != null && _selectedCurrencyId != currency.currencyId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedCurrencyId != currency.currencyId) {
          setState(() => _selectedCurrencyId = currency.currencyId);
        }
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MonthlyHeader(
          month: summary.month,
          onPrevious: () => _moveMonth(summary.month, -1),
          onNext: () => _moveMonth(summary.month, 1),
          onPick: () => _pickMonth(summary.month),
          onRefresh: _refresh,
          onExport: currency == null || _exporting
              ? null
              : () => _openExport(summary, currency),
          exporting: _exporting,
        ),
        const SizedBox(height: 8),
        if (!compactMonthly || currencies.isEmpty) ...[
          _monthCloseStatus(summary),
          const SizedBox(height: 8),
        ],
        if (currencies.isEmpty)
          const Expanded(
            child: PulsoPanel(
              child: PulsoStateView(
                kind: PulsoStateKind.empty,
                message:
                    'No existen movimientos, cierres ni saldos para este mes.',
              ),
            ),
          )
        else ...[
          _CurrencySelector(
            currencies: currencies,
            selectedId: currency!.currencyId,
            onSelected: (value) => setState(() => _selectedCurrencyId = value),
          ),
          const SizedBox(height: 8),
          if (compactMonthly)
            _monthCloseStatus(summary, currency: currency)
          else
            _MonthlyMetricStrip(
              metrics: [
                PulsoMetricData(
                  value: _monthlyMoney.format(currency.entries),
                  label: 'Entradas · ${currency.currencyCode}',
                  note: '${currency.movementCount} movimientos',
                  emphasis: true,
                ),
                PulsoMetricData(
                  value: _monthlyMoney.format(currency.exits),
                  label: 'Salidas · ${currency.currencyCode}',
                  note: '${currency.activeAccountCount} cuentas activas',
                ),
                PulsoMetricData(
                  value: _monthlyMoney.format(currency.net),
                  label: 'Flujo neto · ${currency.currencyCode}',
                  note:
                      '${currency.reconciliationCount} conciliaciones · ajuste ${_signed(currency.monthlyReconciledAdjustments)}',
                ),
                PulsoMetricData(
                  value: '${currency.closeCoverage.toStringAsFixed(1)}%',
                  label: 'Cobertura de cierre',
                  note:
                      '${currency.closedJourneys}/${currency.activityJourneys} jornadas cerradas',
                  warning: currency.openJourneys > 0,
                ),
              ],
            ),
          const SizedBox(height: 8),
          _BalanceEquation(currency: currency),
          const SizedBox(height: 8),
          // R5.6 — cobros del mes por persona, dentro de la moneda elegida.
          // Solo se dibuja si hubo cobros: si no, no se ensucia el resumen.
          if (_collectorsFor(summary, currency).isNotEmpty) ...[
            _MonthlyCollectors(rows: _collectorsFor(summary, currency)),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trend = _MonthlyTrend(
                  currency: currency,
                  scrollController: _trendScroll,
                );
                final accounts = _MonthlyAccounts(
                  currency: currency,
                  scrollController: _accountScroll,
                );
                if (constraints.maxWidth < 880) {
                  return Column(
                    children: [
                      SizedBox(height: 176, child: trend),
                      const SizedBox(height: 8),
                      Expanded(child: accounts),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 4, child: trend),
                    const SizedBox(width: 8),
                    Expanded(flex: 7, child: accounts),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _monthCloseStatus(
    TreasuryMonthlySummaryModel summary, {
    TreasuryMonthlyCurrencyModel? currency,
  }) {
    return _MonthlyCloseStatus(
      status: summary.monthlyClose,
      currency: currency,
      busy: _changingMonthClose,
      onClose: summary.monthlyClose.canClose
          ? () => _changeMonthClose(summary, reopen: false)
          : null,
      onReopen: summary.monthlyClose.canReopen
          ? () => _changeMonthClose(summary, reopen: true)
          : null,
      onInspectBlockers: summary.monthlyClose.blockers.isEmpty
          ? null
          : () => _showMonthlyCloseBlockers(summary),
      onInspectHistory: summary.monthlyClose.history.isEmpty
          ? null
          : () => _showMonthlyCloseHistory(summary),
    );
  }

  String _signed(double value) {
    final sign = value > 0
        ? '+'
        : value < 0
        ? '−'
        : '';
    return '$sign${_monthlyMoney.format(value.abs())}';
  }

  void _moveMonth(String current, int delta) {
    final date = _monthDate(current);
    final next = DateTime.utc(date.year, date.month + delta, 1);
    setState(() {
      _selectedMonth = _canonicalMonth(next);
      _selectedCurrencyId = null;
    });
  }

  Future<void> _pickMonth(String current) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _monthDate(current),
      firstDate: DateTime.utc(2020),
      lastDate: DateTime.utc(2100, 12, 31),
      helpText: 'Seleccionar mes contable',
    );
    if (!mounted || selected == null) return;
    setState(() {
      _selectedMonth = _canonicalMonth(selected);
      _selectedCurrencyId = null;
    });
  }

  Future<void> _changeMonthClose(
    TreasuryMonthlySummaryModel summary, {
    required bool reopen,
  }) async {
    final reasonController = TextEditingController();
    var confirmed = false;
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final tokens = PulsoTokens.of(context);
          final valid = reasonController.text.trim().length >= 12 && confirmed;
          return Dialog(
            key: Key(
              reopen
                  ? 'treasury-monthly-reopen-dialog'
                  : 'treasury-monthly-close-dialog',
            ),
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 610, maxHeight: 540),
              child: PulsoPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                      child: Row(
                        children: [
                          Icon(
                            reopen
                                ? Icons.lock_open_outlined
                                : Icons.verified_outlined,
                            color: reopen ? tokens.warning : tokens.accent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                PulsoLabel(
                                  reopen
                                      ? 'REAPERTURA AUDITADA'
                                      : 'FIRMA DEL CIERRE MENSUAL',
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${reopen ? 'Reabrir' : 'Cerrar'} ${_monthLabel(summary.month)}',
                                  style: TextStyle(
                                    color: tokens.chalk,
                                    fontFamily: PulsoFonts.display,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PulsoIconButton(
                            icon: Icons.close,
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: tokens.line),
                    Flexible(
                      child: SingleChildScrollView(
                        key: Key(
                          reopen
                              ? 'treasury-monthly-reopen-dialog-scroll'
                              : 'treasury-monthly-close-dialog-scroll',
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: (reopen ? tokens.warning : tokens.accent)
                                    .withValues(alpha: 0.08),
                                border: Border.all(
                                  color:
                                      (reopen ? tokens.warning : tokens.accent)
                                          .withValues(alpha: 0.45),
                                ),
                              ),
                              child: Text(
                                reopen
                                    ? 'La reapertura habilita operaciones retroactivas. El cierre firmado no se borra: queda como ciclo reabierto y el próximo cierre creará otro ciclo.'
                                    : 'Se congelarán conjuntamente Tesorería y Resultado de caja con una huella SHA-256. Desde ese momento no se admitirán cobros, gastos, arqueos ni conciliaciones dentro del mes.',
                                style: TextStyle(
                                  color: tokens.chalk,
                                  fontFamily: PulsoFonts.body,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: Key(
                                reopen
                                    ? 'treasury-monthly-reopen-reason'
                                    : 'treasury-monthly-close-reason',
                              ),
                              controller: reasonController,
                              minLines: 3,
                              maxLines: 5,
                              maxLength: 500,
                              onChanged: (_) => setDialogState(() {}),
                              decoration: InputDecoration(
                                labelText: reopen
                                    ? 'Motivo de la reapertura'
                                    : 'Motivo y revisión realizada',
                                helperText:
                                    'Explique la decisión en al menos 12 caracteres.',
                                alignLabelWithHint: true,
                              ),
                            ),
                            // El panel del diálogo pinta su propio fondo: sin
                            // este Material transparente Flutter avisa de que
                            // la tinta del tile quedaría oculta. Sin cambio
                            // visual.
                            Material(
                              type: MaterialType.transparency,
                              child: CheckboxListTile(
                                key: Key(
                                  reopen
                                      ? 'treasury-monthly-reopen-confirm'
                                      : 'treasury-monthly-close-confirm',
                                ),
                                value: confirmed,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity: ListTileControlAffinity.leading,
                                title: Text(
                                  reopen
                                      ? 'Confirmo que esta excepción debe quedar registrada.'
                                      : 'Confirmo que revisé los cierres, incidencias y saldos.',
                                  style: TextStyle(
                                    color: tokens.chalk,
                                    fontFamily: PulsoFonts.body,
                                    fontSize: 12,
                                  ),
                                ),
                                onChanged: (value) => setDialogState(
                                  () => confirmed = value ?? false,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: tokens.line),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('CANCELAR'),
                          ),
                          FilledButton.icon(
                            key: Key(
                              reopen
                                  ? 'treasury-monthly-reopen-submit'
                                  : 'treasury-monthly-close-submit',
                            ),
                            onPressed: valid
                                ? () => Navigator.pop(
                                    dialogContext,
                                    reasonController.text.trim(),
                                  )
                                : null,
                            icon: Icon(
                              reopen
                                  ? Icons.lock_open_outlined
                                  : Icons.lock_outline,
                              size: 17,
                            ),
                            label: Text(reopen ? 'REABRIR MES' : 'CERRAR MES'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    reasonController.dispose();
    if (!mounted || reason == null) return;
    setState(() => _changingMonthClose = true);
    try {
      final repository = ref.read(accountingRepositoryProvider);
      if (reopen) {
        await repository.reopenTreasuryMonth(
          month: summary.month,
          operationId: const Uuid().v4(),
          reason: reason,
        );
      } else {
        await repository.closeTreasuryMonth(
          month: summary.month,
          operationId: const Uuid().v4(),
          reason: reason,
        );
      }
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              reopen
                  ? 'El mes fue reabierto y el ciclo anterior quedó preservado.'
                  : 'El mes y su Resultado de caja quedaron certificados y bloqueados correctamente.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo completar la operación: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _changingMonthClose = false);
    }
  }

  Future<void> _showMonthlyCloseBlockers(
    TreasuryMonthlySummaryModel summary,
  ) async {
    final scroll = ScrollController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final tokens = PulsoTokens.of(dialogContext);
        return Dialog(
          key: const Key('treasury-monthly-blockers-dialog'),
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 520),
            child: PulsoPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.rule_folder_outlined, color: tokens.warning),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: PulsoLabel('REQUISITOS PENDIENTES'),
                      ),
                      PulsoIconButton(
                        icon: Icons.close,
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Resuelva estos puntos antes de firmar ${_monthLabel(summary.month)}.',
                    style: TextStyle(color: tokens.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Scrollbar(
                      controller: scroll,
                      thumbVisibility: true,
                      child: ListView.separated(
                        key: const Key('treasury-monthly-blockers-scroll'),
                        controller: scroll,
                        itemCount: summary.monthlyClose.blockers.length,
                        separatorBuilder: (_, _) => Divider(color: tokens.line),
                        itemBuilder: (context, index) {
                          final blocker = summary.monthlyClose.blockers[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: tokens.warning.withValues(
                                alpha: 0.12,
                              ),
                              foregroundColor: tokens.warning,
                              child: Text('${blocker.count}'),
                            ),
                            title: Text(
                              blocker.message,
                              style: TextStyle(
                                color: tokens.chalk,
                                fontSize: 12,
                              ),
                            ),
                            subtitle: Text(
                              blocker.code.replaceAll('_', ' '),
                              style: TextStyle(
                                color: tokens.muted,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    scroll.dispose();
  }

  Future<void> _showMonthlyCloseHistory(
    TreasuryMonthlySummaryModel summary,
  ) async {
    final scroll = ScrollController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final tokens = PulsoTokens.of(dialogContext);
        return Dialog(
          key: const Key('treasury-monthly-history-dialog'),
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 560),
            child: PulsoPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history_outlined, color: tokens.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PulsoLabel(
                          'CICLOS DE CIERRE · ${_monthLabel(summary.month)}',
                        ),
                      ),
                      PulsoIconButton(
                        icon: Icons.close,
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Scrollbar(
                      controller: scroll,
                      thumbVisibility: true,
                      child: ListView.separated(
                        key: const Key('treasury-monthly-history-scroll'),
                        controller: scroll,
                        itemCount: summary.monthlyClose.history.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final cycle = summary.monthlyClose.history[index];
                          final reopened = cycle.state == 'REABIERTO';
                          return Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: tokens.raised,
                              border: Border.all(
                                color: reopened
                                    ? tokens.warning
                                    : tokens.success,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      reopened
                                          ? Icons.lock_open_outlined
                                          : Icons.verified_outlined,
                                      size: 17,
                                      color: reopened
                                          ? tokens.warning
                                          : tokens.success,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: PulsoLabel(
                                        'CICLO ${summary.monthlyClose.history.length - index} · ${cycle.state}',
                                      ),
                                    ),
                                    Text(
                                      cycle.integrityVerified
                                          ? 'SHA-256 OK'
                                          : 'REVISAR FIRMA',
                                      style: TextStyle(
                                        color: cycle.integrityVerified
                                            ? tokens.success
                                            : tokens.danger,
                                        fontFamily: PulsoFonts.mono,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Firmó ${cycle.closerName} (${cycle.closerRole})',
                                  style: TextStyle(
                                    color: tokens.chalk,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  cycle.closeReason,
                                  style: TextStyle(
                                    color: tokens.muted,
                                    fontSize: 11,
                                    height: 1.35,
                                  ),
                                ),
                                if (reopened) ...[
                                  const SizedBox(height: 8),
                                  Divider(color: tokens.line, height: 1),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Reabrió ${cycle.reopenerName ?? 'Administración'} (${cycle.reopenerRole ?? 'admin'})',
                                    style: TextStyle(
                                      color: tokens.warning,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    cycle.reopenReason ??
                                        'Sin motivo disponible.',
                                    style: TextStyle(
                                      color: tokens.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                SelectableText(
                                  cycle.hash,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: tokens.muted2,
                                    fontFamily: PulsoFonts.mono,
                                    fontSize: 8,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    scroll.dispose();
  }

  Future<void> _openExport(
    TreasuryMonthlySummaryModel summary,
    TreasuryMonthlyCurrencyModel currency,
  ) async {
    var allCurrencies = false;
    var accountId = _allAccountsValue;
    var includeDailyTrend = true;
    final dialogScroll = ScrollController();
    final request = await showDialog<_MonthlyExportRequest>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final tokens = PulsoTokens.of(context);
          final accountFilterEnabled = !allCurrencies;
          return Dialog(
            key: const Key('treasury-monthly-export-dialog'),
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 660, maxHeight: 640),
              child: Container(
                decoration: BoxDecoration(
                  color: tokens.surface,
                  border: Border.all(color: tokens.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 13),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const PulsoLabel('INFORME EJECUTIVO'),
                                const SizedBox(height: 4),
                                Text(
                                  'Exportar consolidado mensual',
                                  style: TextStyle(
                                    color: tokens.chalk,
                                    fontFamily: PulsoFonts.display,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PulsoIconButton(
                            icon: Icons.close,
                            tooltip: 'Cerrar exportación',
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: tokens.line),
                    Expanded(
                      child: Scrollbar(
                        controller: dialogScroll,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          key: const Key(
                            'treasury-monthly-export-dialog-scroll',
                          ),
                          controller: dialogScroll,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ExportScopeCard(
                                icon: Icons.currency_exchange,
                                title: 'ALCANCE DE MONEDAS',
                                description: allCurrencies
                                    ? 'Se generará una sección independiente por moneda, sin total general ni conversiones.'
                                    : 'El informe conservará ${currency.currencyCode} como unidad original.',
                                child: SwitchListTile.adaptive(
                                  key: const Key(
                                    'treasury-monthly-export-all-currencies',
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Incluir todas las monedas',
                                  ),
                                  subtitle: Text(
                                    '${summary.currencies.length} moneda(s) disponible(s)',
                                  ),
                                  value: allCurrencies,
                                  onChanged: (value) => setDialogState(() {
                                    allCurrencies = value;
                                    if (value) accountId = _allAccountsValue;
                                  }),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _ExportScopeCard(
                                icon: Icons.account_balance_outlined,
                                title: 'CUENTAS',
                                description: accountFilterEnabled
                                    ? 'Puede limitar el informe a una cuenta de ${currency.currencyCode}.'
                                    : 'Para comparar monedas se incluyen todas sus cuentas.',
                                child: DropdownButtonFormField<String>(
                                  key: const Key(
                                    'treasury-monthly-export-account',
                                  ),
                                  initialValue: accountId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Cuenta del informe',
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: _allAccountsValue,
                                      child: Text('Todas las cuentas'),
                                    ),
                                    ...currency.accounts.map(
                                      (account) => DropdownMenuItem(
                                        value: account.id,
                                        child: Text(
                                          '${account.name} · ${account.status.replaceAll('_', ' ')}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: accountFilterEnabled
                                      ? (value) => setDialogState(() {
                                          accountId =
                                              value ?? _allAccountsValue;
                                          if (accountId != _allAccountsValue) {
                                            includeDailyTrend = false;
                                          }
                                        })
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _ExportScopeCard(
                                icon: Icons.show_chart,
                                title: 'DETALLE DIARIO',
                                description: accountId == _allAccountsValue
                                    ? 'Añade la evolución diaria del flujo de cada moneda seleccionada.'
                                    : 'La proyección diaria disponible es por moneda; se omite para no atribuirla incorrectamente a una sola cuenta.',
                                child: SwitchListTile.adaptive(
                                  key: const Key(
                                    'treasury-monthly-export-daily-trend',
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Incluir evolución diaria'),
                                  value: includeDailyTrend,
                                  onChanged: accountId == _allAccountsValue
                                      ? (value) => setDialogState(
                                          () => includeDailyTrend = value,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'El PDF resume flujo, cobertura, aprobaciones, conciliaciones, incidencias y saldo por cuenta. El CSV conserva filas MONEDA, CUENTA y DÍA para análisis externo.',
                                style: TextStyle(
                                  color: tokens.muted,
                                  fontFamily: PulsoFonts.body,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: tokens.line),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 11, 16, 13),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton.icon(
                            key: const Key('treasury-monthly-export-print'),
                            onPressed: () => Navigator.of(dialogContext).pop(
                              _MonthlyExportRequest(
                                action: _MonthlyExportAction.printPdf,
                                allCurrencies: allCurrencies,
                                accountId: accountId == _allAccountsValue
                                    ? null
                                    : accountId,
                                includeDailyTrend: includeDailyTrend,
                              ),
                            ),
                            icon: const Icon(Icons.print_outlined, size: 17),
                            label: const Text('IMPRIMIR'),
                          ),
                          OutlinedButton.icon(
                            key: const Key('treasury-monthly-export-csv'),
                            onPressed: () => Navigator.of(dialogContext).pop(
                              _MonthlyExportRequest(
                                action: _MonthlyExportAction.saveCsv,
                                allCurrencies: allCurrencies,
                                accountId: accountId == _allAccountsValue
                                    ? null
                                    : accountId,
                                includeDailyTrend: includeDailyTrend,
                              ),
                            ),
                            icon: const Icon(
                              Icons.table_view_outlined,
                              size: 17,
                            ),
                            label: const Text('GUARDAR CSV'),
                          ),
                          FilledButton.icon(
                            key: const Key('treasury-monthly-export-pdf'),
                            onPressed: () => Navigator.of(dialogContext).pop(
                              _MonthlyExportRequest(
                                action: _MonthlyExportAction.savePdf,
                                allCurrencies: allCurrencies,
                                accountId: accountId == _allAccountsValue
                                    ? null
                                    : accountId,
                                includeDailyTrend: includeDailyTrend,
                              ),
                            ),
                            icon: const Icon(
                              Icons.picture_as_pdf_outlined,
                              size: 17,
                            ),
                            label: const Text('GUARDAR PDF'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    dialogScroll.dispose();
    if (!mounted || request == null) return;

    setState(() => _exporting = true);
    try {
      final snapshot = _reportService.snapshot(
        summary: summary,
        allCurrencies: request.allCurrencies,
        selectedCurrencyId: currency.currencyId,
        accountId: request.accountId,
        includeDailyTrend: request.includeDailyTrend,
      );
      final message = switch (request.action) {
        _MonthlyExportAction.savePdf =>
          await _reportService.savePdf(snapshot) == null
              ? null
              : 'Informe PDF guardado.',
        _MonthlyExportAction.saveCsv =>
          await _reportService.saveCsv(snapshot) == null
              ? null
              : 'Archivo CSV guardado.',
        _MonthlyExportAction.printPdf =>
          await _reportService.printPdf(snapshot)
              ? 'Informe enviado al diálogo de impresión.'
              : null,
      };
      if (mounted && message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo exportar el informe: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

const _allAccountsValue = '__all_accounts__';

enum _MonthlyExportAction { savePdf, saveCsv, printPdf }

class _MonthlyExportRequest {
  const _MonthlyExportRequest({
    required this.action,
    required this.allCurrencies,
    required this.accountId,
    required this.includeDailyTrend,
  });

  final _MonthlyExportAction action;
  final bool allCurrencies;
  final String? accountId;
  final bool includeDailyTrend;
}

class _MonthlyCloseStatus extends StatelessWidget {
  const _MonthlyCloseStatus({
    required this.status,
    this.currency,
    required this.busy,
    required this.onClose,
    required this.onReopen,
    required this.onInspectBlockers,
    required this.onInspectHistory,
  });

  final TreasuryMonthlyCloseStatusModel status;
  final TreasuryMonthlyCurrencyModel? currency;
  final bool busy;
  final VoidCallback? onClose;
  final VoidCallback? onReopen;
  final VoidCallback? onInspectBlockers;
  final VoidCallback? onInspectHistory;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final cycle = status.currentCycle;
    final hasBlockers = status.blockers.isNotEmpty;
    final color = status.isClosed
        ? tokens.success
        : status.readyToClose
        ? tokens.accent
        : hasBlockers
        ? tokens.warning
        : tokens.muted;
    final icon = status.isClosed
        ? Icons.verified_user_outlined
        : status.readyToClose
        ? Icons.fact_check_outlined
        : hasBlockers
        ? Icons.rule_folder_outlined
        : Icons.calendar_today_outlined;
    final title = status.isClosed
        ? 'PERÍODO CERRADO Y FIRMADO'
        : status.readyToClose
        ? 'LISTO PARA CIERRE MENSUAL'
        : hasBlockers
        ? 'CIERRE MENSUAL PENDIENTE'
        : status.monthEnded
        ? 'PERÍODO ABIERTO'
        : 'MES COMERCIAL EN CURSO';
    final baseDetail = status.isClosed
        ? '${cycle?.closerName ?? 'Operador'} · firma ${_shortHash(cycle?.hash)} · ${cycle?.integrityVerified == true ? 'integridad verificada' : 'revisar integridad'}'
        : status.readyToClose
        ? 'No existen jornadas, aprobaciones, conciliaciones ni asignaciones pendientes.'
        : hasBlockers
        ? '${status.blockers.length} requisito(s) pendientes · ${status.blockers.first.message}'
        : status.monthEnded
        ? 'El período terminó, pero su rol no dispone de la firma de cierre.'
        : 'El cierre se habilitará después del último día comercial del mes.';
    final detail = currency == null
        ? baseDetail
        : '$baseDetail · Saldo ${currency!.currencyCode} ${_monthlyMoney.format(currency!.currentBalance)}';
    return PulsoPanel(
      padding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 520;
          final summary = Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PulsoLabel(title),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.muted,
                        fontFamily: PulsoFonts.body,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final actionButtons = <Widget>[
            if (onInspectBlockers != null)
              narrow
                  ? IconButton.outlined(
                      key: const Key('treasury-monthly-inspect-blockers'),
                      onPressed: busy ? null : onInspectBlockers,
                      tooltip: 'Ver requisitos',
                      icon: const Icon(Icons.checklist_outlined, size: 16),
                    )
                  : OutlinedButton.icon(
                      key: const Key('treasury-monthly-inspect-blockers'),
                      onPressed: busy ? null : onInspectBlockers,
                      icon: const Icon(Icons.checklist_outlined, size: 16),
                      label: const Text('VER REQUISITOS'),
                    ),
            if (onInspectHistory != null)
              narrow
                  ? IconButton.outlined(
                      key: const Key('treasury-monthly-inspect-history'),
                      onPressed: busy ? null : onInspectHistory,
                      tooltip: 'Ver ciclos de cierre',
                      icon: const Icon(Icons.history_outlined, size: 16),
                    )
                  : OutlinedButton.icon(
                      key: const Key('treasury-monthly-inspect-history'),
                      onPressed: busy ? null : onInspectHistory,
                      icon: const Icon(Icons.history_outlined, size: 16),
                      label: const Text('HISTORIAL'),
                    ),
            if (onClose != null)
              narrow
                  ? IconButton.filled(
                      key: const Key('treasury-monthly-close-action'),
                      onPressed: busy ? null : onClose,
                      tooltip: 'Cerrar mes',
                      icon: busy
                          ? const SizedBox.square(
                              dimension: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.6,
                              ),
                            )
                          : const Icon(Icons.lock_outline, size: 16),
                    )
                  : FilledButton.icon(
                      key: const Key('treasury-monthly-close-action'),
                      onPressed: busy ? null : onClose,
                      icon: busy
                          ? const SizedBox.square(
                              dimension: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.6,
                              ),
                            )
                          : const Icon(Icons.lock_outline, size: 16),
                      label: const Text('CERRAR MES'),
                    ),
            if (onReopen != null)
              narrow
                  ? IconButton.outlined(
                      key: const Key('treasury-monthly-reopen-action'),
                      onPressed: busy ? null : onReopen,
                      tooltip: 'Reabrir mes',
                      icon: const Icon(Icons.lock_open_outlined, size: 16),
                    )
                  : OutlinedButton.icon(
                      key: const Key('treasury-monthly-reopen-action'),
                      onPressed: busy ? null : onReopen,
                      icon: const Icon(Icons.lock_open_outlined, size: 16),
                      label: const Text('REABRIR'),
                    ),
          ];
          final actions = Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.end,
            children: actionButtons,
          );
          return Row(
            children: [
              Expanded(child: summary),
              if (actionButtons.isNotEmpty) ...[
                const SizedBox(width: 12),
                actions,
              ],
            ],
          );
        },
      ),
    );
  }

  static String _shortHash(String? value) {
    final hash = value ?? '';
    if (hash.isEmpty) return 'sin huella';
    return hash.length <= 12 ? hash : '${hash.substring(0, 12)}…';
  }
}

class _MonthlyHeader extends StatelessWidget {
  const _MonthlyHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
    required this.onRefresh,
    required this.onExport,
    required this.exporting,
  });

  final String month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final VoidCallback onRefresh;
  final VoidCallback? onExport;
  final bool exporting;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final compact = MediaQuery.sizeOf(context).width < 820;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PulsoLabel('TESORERÍA · CONSOLIDADO MENSUAL'),
        const SizedBox(height: 3),
        Text(
          'Flujo, cierres y saldo vigente sin mezclar monedas',
          style: TextStyle(
            color: tokens.chalk,
            fontFamily: PulsoFonts.display,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
    final controls = Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        PulsoIconButton(
          icon: Icons.chevron_left,
          tooltip: 'Mes anterior',
          onPressed: onPrevious,
        ),
        OutlinedButton.icon(
          key: const Key('treasury-month-picker'),
          onPressed: onPick,
          icon: const Icon(Icons.calendar_month_outlined, size: 17),
          label: Text(_monthLabel(month)),
        ),
        PulsoIconButton(
          icon: Icons.chevron_right,
          tooltip: 'Mes siguiente',
          onPressed: onNext,
        ),
        PulsoIconButton(
          icon: Icons.refresh,
          tooltip: 'Actualizar consolidado mensual',
          onPressed: onRefresh,
        ),
        if (compact)
          IconButton.outlined(
            key: const Key('treasury-monthly-export'),
            onPressed: onExport,
            tooltip: exporting ? 'Generando informe' : 'Exportar informe',
            icon: exporting
                ? const SizedBox.square(
                    dimension: 15,
                    child: CircularProgressIndicator(strokeWidth: 1.6),
                  )
                : const Icon(Icons.ios_share_outlined, size: 17),
          )
        else
          OutlinedButton.icon(
            key: const Key('treasury-monthly-export'),
            onPressed: onExport,
            icon: exporting
                ? const SizedBox.square(
                    dimension: 15,
                    child: CircularProgressIndicator(strokeWidth: 1.6),
                  )
                : const Icon(Icons.ios_share_outlined, size: 17),
            label: Text(exporting ? 'GENERANDO…' : 'EXPORTAR INFORME'),
          ),
      ],
    );
    return PulsoPanel(
      padding: const EdgeInsets.fromLTRB(18, 13, 14, 13),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 820) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [title, const SizedBox(height: 8), controls],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _ExportScopeCard extends StatelessWidget {
  const _ExportScopeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border.all(color: tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: tokens.accent),
              const SizedBox(width: 8),
              Expanded(child: PulsoLabel(title)),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: TextStyle(
              color: tokens.muted,
              fontFamily: PulsoFonts.body,
              fontSize: 11,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          // La tarjeta pinta fondo propio; los tiles que recibe necesitan su
          // Material transparente o Flutter avisa de que su tinta quedaría
          // oculta y la aserción tumba la prueba. No cambia el aspecto.
          Material(type: MaterialType.transparency, child: child),
        ],
      ),
    );
  }
}

class _CurrencySelector extends StatefulWidget {
  const _CurrencySelector({
    required this.currencies,
    required this.selectedId,
    required this.onSelected,
  });

  final List<TreasuryMonthlyCurrencyModel> currencies;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  State<_CurrencySelector> createState() => _CurrencySelectorState();
}

class _CurrencySelectorState extends State<_CurrencySelector> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _selectedLabel());
  }

  @override
  void didUpdateWidget(covariant _CurrencySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId ||
        oldWidget.currencies != widget.currencies) {
      _controller.text = _selectedLabel();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _selectedLabel() {
    final selected = widget.currencies
        .where((item) => item.currencyId == widget.selectedId)
        .firstOrNull;
    return selected == null ? '' : _label(selected);
  }

  String _label(TreasuryMonthlyCurrencyModel currency) =>
      '${currency.currencyCode} · ${currency.activeAccountCount} cuenta(s)';

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final selector = DropdownMenu<String>(
            key: const Key('treasury-monthly-currency-selector'),
            width: constraints.maxWidth < 600 ? constraints.maxWidth : 360,
            menuHeight: 320,
            controller: _controller,
            initialSelection: widget.selectedId,
            enableFilter: true,
            enableSearch: true,
            requestFocusOnTap: true,
            leadingIcon: Icon(
              Icons.currency_exchange,
              size: 17,
              color: tokens.muted,
            ),
            trailingIcon: Icon(
              Icons.expand_more,
              size: 18,
              color: tokens.muted,
            ),
            selectedTrailingIcon: Icon(
              Icons.expand_less,
              size: 18,
              color: tokens.accent,
            ),
            textStyle: TextStyle(
              color: tokens.chalk,
              fontFamily: PulsoFonts.mono,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            inputDecorationTheme: InputDecorationTheme(
              isDense: true,
              filled: true,
              fillColor: tokens.raised,
              constraints: const BoxConstraints.tightFor(height: 38),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: tokens.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: tokens.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: tokens.accent, width: 1.5),
              ),
            ),
            menuStyle: MenuStyle(
              backgroundColor: WidgetStatePropertyAll(tokens.surface),
              elevation: const WidgetStatePropertyAll(8),
              shape: const WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              side: WidgetStatePropertyAll(BorderSide(color: tokens.line)),
            ),
            dropdownMenuEntries: widget.currencies
                .map(
                  (currency) => DropdownMenuEntry<String>(
                    value: currency.currencyId,
                    label: _label(currency),
                    leadingIcon: Icon(
                      currency.requiresAttention
                          ? Icons.error_outline
                          : Icons.account_balance_wallet_outlined,
                      size: 16,
                      color: currency.requiresAttention
                          ? tokens.warning
                          : tokens.muted,
                    ),
                    style: ButtonStyle(
                      foregroundColor: WidgetStatePropertyAll(tokens.chalk),
                      textStyle: WidgetStatePropertyAll(
                        TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
            onSelected: (value) {
              if (value != null) widget.onSelected(value);
            },
          );
          final contextText = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const PulsoLabel('MONEDA DEL INFORME'),
              const SizedBox(height: 3),
              Text(
                '${widget.currencies.length} moneda(s) disponible(s) · escribe para buscar',
                style: TextStyle(
                  color: tokens.muted,
                  fontFamily: PulsoFonts.mono,
                  fontSize: 8,
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 600) {
            return selector;
          }
          return Row(
            children: [
              Expanded(child: contextText),
              const SizedBox(width: 16),
              selector,
            ],
          );
        },
      ),
    );
  }
}

class _MonthlyMetricStrip extends StatelessWidget {
  const _MonthlyMetricStrip({required this.metrics});

  final List<PulsoMetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 840) {
          return SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              primary: false,
              itemCount: metrics.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) => SizedBox(
                width: 280,
                child: _MonthlyMetric(data: metrics[index]),
              ),
            ),
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < metrics.length; index++) ...[
                Expanded(child: _MonthlyMetric(data: metrics[index])),
                if (index != metrics.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MonthlyMetric extends StatelessWidget {
  const _MonthlyMetric({required this.data});

  final PulsoMetricData data;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = data.warning
        ? tokens.warning
        : data.emphasis
        ? tokens.accent
        : tokens.chalk;
    return PulsoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Flexible(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                data.value,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontFamily: PulsoFonts.display,
                  fontSize: 27,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.chalkDim,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.muted2,
                    fontFamily: PulsoFonts.mono,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cobros del mes por recepcionista, dentro de una sola moneda
/// (docs/PAYMENT_COLLECTOR_ATTRIBUTION.md §6).
///
/// A diferencia del cierre diario, aquí las cuentas se funden: en un mes la
/// misma persona puede haber cobrado en varias cajas y lo que se lee es su
/// total. Las monedas no se funden nunca.
class _MonthlyCollectors extends StatelessWidget {
  const _MonthlyCollectors({required this.rows});

  final List<TreasuryCollectorRowModel> rows;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      key: const ValueKey('treasury-monthly-collectors'),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.badge_outlined, size: 16, color: tokens.accent),
              const SizedBox(width: 8),
              const Expanded(child: PulsoLabel('Cobros del mes por recepcionista')),
            ],
          ),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: row.unattributed
                                ? tokens.warning
                                : tokens.chalk,
                          ),
                        ),
                        Text(
                          '${row.accountName} · ${row.payments} pago(s) · '
                          '${row.clients} cliente(s)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: tokens.muted, fontSize: 9.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${row.currencyCode} '
                        '${_monthlyMoney.format(row.net)} neto',
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: tokens.accent,
                        ),
                      ),
                      Text(
                        'Bruto ${_monthlyMoney.format(row.gross)}'
                        ' · anulado ${_monthlyMoney.format(row.annulled)}',
                        style: TextStyle(
                          color: tokens.muted2,
                          fontFamily: PulsoFonts.mono,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BalanceEquation extends StatelessWidget {
  const _BalanceEquation({required this.currency});

  final TreasuryMonthlyCurrencyModel currency;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final warning = currency.requiresAttention;
    return PulsoPanel(
      color: warning ? tokens.warningSoft : tokens.successSoft,
      borderColor: warning ? tokens.warning : tokens.success,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final equation = Wrap(
            spacing: 9,
            runSpacing: 3,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _EquationValue(
                label: 'SALDO ORIGINAL',
                value:
                    '${currency.currencyCode} ${_monthlyMoney.format(currency.originalCloseBalance)}',
              ),
              Text('+', style: TextStyle(color: tokens.muted, fontSize: 18)),
              _EquationValue(
                label: 'AJUSTES VIGENTES',
                value:
                    '${currency.currencyCode} ${_signedMoney(currency.currentAdjustments)}',
              ),
              Text('=', style: TextStyle(color: tokens.muted, fontSize: 18)),
              _EquationValue(
                label: 'SALDO VIGENTE',
                value:
                    '${currency.currencyCode} ${_monthlyMoney.format(currency.currentBalance)}',
                emphasis: true,
              ),
            ],
          );
          final note = Text(
            warning
                ? '${currency.openJourneys} jornada(s) por cerrar · ${currency.pendingLateMovementCount} tardío(s) · pendiente ${currency.currencyCode} ${_signedMoney(currency.pendingCloseNet)}'
                : 'Todas las jornadas con actividad están cerradas; el saldo conserva sus conciliaciones.',
            style: TextStyle(
              color: warning ? tokens.warning : tokens.success,
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          );
          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [equation, const SizedBox(height: 6), note],
            );
          }
          return Row(
            children: [
              Expanded(child: equation),
              const SizedBox(width: 12),
              note,
            ],
          );
        },
      ),
    );
  }
}

class _EquationValue extends StatelessWidget {
  const _EquationValue({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: tokens.muted,
            fontFamily: PulsoFonts.mono,
            fontSize: 7,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: emphasis ? tokens.accent : tokens.chalk,
            fontFamily: PulsoFonts.mono,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MonthlyTrend extends StatelessWidget {
  const _MonthlyTrend({required this.currency, required this.scrollController});

  final TreasuryMonthlyCurrencyModel currency;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final maxAmount = currency.trend.fold<double>(
      0,
      (current, item) => [
        current,
        item.entries,
        item.exits,
      ].reduce((left, right) => left > right ? left : right),
    );
    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 8),
            child: Row(
              children: [
                const Expanded(child: PulsoLabel('RITMO DIARIO')),
                _Legend(color: tokens.success, label: 'ENTRA'),
                const SizedBox(width: 8),
                _Legend(color: tokens.danger, label: 'SALE'),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.line),
          Expanded(
            child: Scrollbar(
              key: const Key('treasury-monthly-trend-scrollbar'),
              controller: scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final item in currency.trend)
                      _TrendDay(item: item, maxAmount: maxAmount),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: tokens.muted,
            fontFamily: PulsoFonts.mono,
            fontSize: 7,
          ),
        ),
      ],
    );
  }
}

class _TrendDay extends StatelessWidget {
  const _TrendDay({required this.item, required this.maxAmount});

  final TreasuryMonthlyTrendModel item;
  final double maxAmount;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    double height(double value) => maxAmount <= 0 ? 2 : 58 * value / maxAmount;
    final day = item.businessDate.length >= 10
        ? item.businessDate.substring(8, 10)
        : item.businessDate;
    return Tooltip(
      message:
          '$day · +${_monthlyMoney.format(item.entries)} · −${_monthlyMoney.format(item.exits)} · neto ${_monthlyMoney.format(item.net)}',
      child: SizedBox(
        width: 29,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              height: 62,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: height(item.entries),
                    color: tokens.success,
                  ),
                  const SizedBox(width: 2),
                  Container(
                    width: 6,
                    height: height(item.exits),
                    color: tokens.danger,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 5,
              height: 5,
              color: item.closeCount > 0 ? tokens.accent : Colors.transparent,
            ),
            const SizedBox(height: 2),
            Text(
              day,
              style: TextStyle(
                color: tokens.muted,
                fontFamily: PulsoFonts.mono,
                fontSize: 7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyAccounts extends StatefulWidget {
  const _MonthlyAccounts({
    required this.currency,
    required this.scrollController,
  });

  final TreasuryMonthlyCurrencyModel currency;
  final ScrollController scrollController;

  @override
  State<_MonthlyAccounts> createState() => _MonthlyAccountsState();
}

class _MonthlyAccountsState extends State<_MonthlyAccounts> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void didUpdateWidget(covariant _MonthlyAccounts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currency.currencyId != widget.currency.currencyId) {
      _searchController.clear();
      _query = '';
      _resetScroll();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.scrollController.hasClients) {
        widget.scrollController.jumpTo(0);
      }
    });
  }

  void _updateQuery(String value) {
    setState(() => _query = value.trim().toLowerCase());
    _resetScroll();
  }

  void _clearQuery() {
    _searchController.clear();
    _updateQuery('');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final accounts = widget.currency.accounts.where((account) {
      if (_query.isEmpty) return true;
      final status = account.status.replaceAll('_', ' ').toLowerCase();
      return account.name.toLowerCase().contains(_query) ||
          account.id.toLowerCase().contains(_query) ||
          status.contains(_query);
    }).toList();
    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PulsoLabel(
                      'DESGLOSE POR CUENTA · ${widget.currency.currencyCode}',
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${accounts.length} de ${widget.currency.accounts.length} cuenta(s) · selecciona una para ver el detalle',
                      style: TextStyle(
                        color: tokens.muted,
                        fontFamily: PulsoFonts.mono,
                        fontSize: 8,
                      ),
                    ),
                  ],
                );
                final search = SizedBox(
                  width: constraints.maxWidth < 580
                      ? constraints.maxWidth
                      : 245,
                  height: 36,
                  child: TextField(
                    key: const Key('treasury-monthly-account-search'),
                    controller: _searchController,
                    onChanged: _updateQuery,
                    style: TextStyle(
                      color: tokens.chalk,
                      fontFamily: PulsoFonts.mono,
                      fontSize: 10,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar cuenta o estado…',
                      hintStyle: TextStyle(color: tokens.muted, fontSize: 9),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 16,
                        color: tokens.muted,
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              onPressed: _clearQuery,
                              icon: Icon(
                                Icons.close,
                                size: 15,
                                color: tokens.muted,
                              ),
                            ),
                      filled: true,
                      fillColor: tokens.raised,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: tokens.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: tokens.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(
                          color: tokens.accent,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                );
                if (constraints.maxWidth < 580) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [title, const SizedBox(height: 8), search],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 12),
                    search,
                  ],
                );
              },
            ),
          ),
          Divider(height: 1, color: tokens.line),
          LayoutBuilder(
            builder: (context, constraints) => Container(
              color: tokens.raised,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: constraints.maxWidth < 620
                  ? Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: _header(context, 'CUENTA / FLUJO'),
                        ),
                        Expanded(flex: 3, child: _header(context, 'JORNADAS')),
                        Expanded(
                          flex: 3,
                          child: _header(context, 'SALDO VIGENTE'),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(flex: 4, child: _header(context, 'CUENTA')),
                        Expanded(flex: 2, child: _header(context, 'ENTRADAS')),
                        Expanded(flex: 2, child: _header(context, 'SALIDAS')),
                        Expanded(flex: 2, child: _header(context, 'NETO')),
                        Expanded(flex: 2, child: _header(context, 'CIERRES')),
                        Expanded(
                          flex: 3,
                          child: _header(context, 'SALDO / ESTADO'),
                        ),
                      ],
                    ),
            ),
          ),
          Expanded(
            child: accounts.isEmpty
                ? PulsoStateView(
                    kind: PulsoStateKind.empty,
                    message: widget.currency.accounts.isEmpty
                        ? 'No hay cuentas para esta moneda.'
                        : 'No hay cuentas que coincidan con la búsqueda.',
                  )
                : Scrollbar(
                    key: const Key('treasury-monthly-accounts-scrollbar'),
                    controller: widget.scrollController,
                    thumbVisibility: true,
                    child: ListView.separated(
                      key: PageStorageKey(
                        'treasury-monthly-accounts-${widget.currency.currencyId}',
                      ),
                      controller: widget.scrollController,
                      primary: false,
                      itemCount: accounts.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: tokens.line),
                      itemBuilder: (_, index) => _MonthlyAccountRow(
                        account: accounts[index],
                        onTap: () => _showAccountDetail(accounts[index]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String value) {
    final tokens = PulsoTokens.of(context);
    return Text(
      value,
      style: TextStyle(
        color: tokens.muted,
        fontFamily: PulsoFonts.mono,
        fontSize: 7,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Future<void> _showAccountDetail(TreasuryMonthlyAccountModel account) =>
      showDialog<void>(
        context: context,
        builder: (_) => _MonthlyAccountDetailDialog(account: account),
      );
}

class _MonthlyAccountRow extends StatelessWidget {
  const _MonthlyAccountRow({required this.account, required this.onTap});

  final TreasuryMonthlyAccountModel account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = account.requiresAttention
        ? tokens.warning
        : account.status == 'CONCILIADO'
        ? tokens.success
        : tokens.chalkDim;
    final status = switch (account.status) {
      'PENDIENTE_APROBACION' => 'PENDIENTE APROBACIÓN',
      'POR_CERRAR' => 'POR CERRAR',
      'REQUIERE_CONCILIACION' => 'CONCILIAR',
      'SIN_CIERRE' => 'SIN CIERRE',
      'CONCILIADO' => 'CONCILIADA',
      _ => 'CERRADA',
    };
    return InkWell(
      key: ValueKey('treasury-monthly-account-${account.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 620) {
              return _compactRow(context, color, status);
            }
            return _expandedRow(context, color, status);
          },
        ),
      ),
    );
  }

  Widget _compactRow(BuildContext context, Color color, String status) {
    final tokens = PulsoTokens.of(context);
    return Row(
      children: [
        Expanded(flex: 4, child: _accountIdentity(context, showFlow: true)),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${account.closedJourneys}/${account.activityDays} cerradas',
                style: TextStyle(
                  color: color,
                  fontFamily: PulsoFonts.mono,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                account.openJourneys > 0
                    ? '${account.openJourneys} pendiente(s)'
                    : '${account.reconciliationCount} conciliación(es)',
                style: TextStyle(color: tokens.muted, fontSize: 8),
              ),
            ],
          ),
        ),
        Expanded(flex: 3, child: _balanceAndStatus(context, color, status)),
      ],
    );
  }

  Widget _expandedRow(BuildContext context, Color color, String status) {
    return Row(
      children: [
        Expanded(flex: 4, child: _accountIdentity(context, showFlow: false)),
        Expanded(flex: 2, child: _amount(context, account.entries)),
        Expanded(flex: 2, child: _amount(context, account.exits)),
        Expanded(flex: 2, child: _amount(context, account.net, signed: true)),
        Expanded(
          flex: 2,
          child: Text(
            '${account.closedJourneys}/${account.activityDays}',
            style: TextStyle(
              color: color,
              fontFamily: PulsoFonts.mono,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(flex: 3, child: _balanceAndStatus(context, color, status)),
      ],
    );
  }

  Widget _accountIdentity(BuildContext context, {required bool showFlow}) {
    final tokens = PulsoTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.chalk,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 14, color: tokens.muted),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            showFlow
                ? '+${_monthlyMoney.format(account.entries)} · −${_monthlyMoney.format(account.exits)} · ${account.movementCount} mov.'
                : '${account.movementCount} movimiento(s)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.muted,
              fontFamily: PulsoFonts.mono,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _amount(BuildContext context, double value, {bool signed = false}) {
    final tokens = PulsoTokens.of(context);
    final prefix = signed
        ? value > 0
              ? '+'
              : value < 0
              ? '−'
              : ''
        : '';
    return Text(
      '$prefix${_monthlyMoney.format(value.abs())}',
      style: TextStyle(
        color: tokens.chalkDim,
        fontFamily: PulsoFonts.mono,
        fontSize: 9,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _balanceAndStatus(BuildContext context, Color color, String status) {
    final tokens = PulsoTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          account.currentBalance == null
              ? '—'
              : '${account.currencyCode} ${_monthlyMoney.format(account.currentBalance)}',
          style: TextStyle(
            color: tokens.chalk,
            fontFamily: PulsoFonts.mono,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          status,
          style: TextStyle(
            color: color,
            fontFamily: PulsoFonts.mono,
            fontSize: 7,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MonthlyAccountDetailDialog extends StatelessWidget {
  const _MonthlyAccountDetailDialog({required this.account});

  final TreasuryMonthlyAccountModel account;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final coverage = account.activityDays == 0
        ? 0.0
        : account.closedJourneys * 100 / account.activityDays;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border.all(color: tokens.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 15, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const PulsoLabel('DETALLE MENSUAL DE CUENTA'),
                          const SizedBox(height: 4),
                          Text(
                            account.name,
                            style: TextStyle(
                              color: tokens.chalk,
                              fontFamily: PulsoFonts.display,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PulsoIconButton(
                      icon: Icons.close,
                      tooltip: 'Cerrar detalle',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: tokens.line),
              Expanded(
                child: SingleChildScrollView(
                  key: const Key('treasury-monthly-account-detail-scroll'),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AccountDetailEquation(account: account),
                      const SizedBox(height: 16),
                      _AccountDetailSection(
                        title: 'FLUJO DEL MES · ${account.currencyCode}',
                        rows: [
                          ('Entradas', _monthlyMoney.format(account.entries)),
                          ('Salidas', _monthlyMoney.format(account.exits)),
                          ('Flujo neto', _signedMoney(account.net)),
                          ('Movimientos', '${account.movementCount}'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _AccountDetailSection(
                        title: 'CIERRES Y CONCILIACIÓN',
                        rows: [
                          ('Días con actividad', '${account.activityDays}'),
                          (
                            'Jornadas cerradas',
                            '${account.closedJourneys} · ${coverage.toStringAsFixed(1)}%',
                          ),
                          ('Jornadas pendientes', '${account.openJourneys}'),
                          ('Cierres registrados', '${account.closeCount}'),
                          (
                            'Cierres aprobados',
                            '${account.approvedCloseCount}',
                          ),
                          (
                            'Dentro de tolerancia',
                            '${account.withinToleranceCloseCount}',
                          ),
                          (
                            'Solicitudes pendientes',
                            '${account.pendingApprovalCount}',
                          ),
                          (
                            'Solicitudes rechazadas / obsoletas',
                            '${account.rejectedRequestCount} / ${account.obsoleteRequestCount}',
                          ),
                          ('Conciliaciones', '${account.reconciliationCount}'),
                          (
                            'Último cierre',
                            account.lastCloseDate ?? 'Sin cierre',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _AccountDetailSection(
                        title: 'SEGUIMIENTO',
                        rows: [
                          (
                            'Ajustes conciliados del mes',
                            _signedMoney(account.monthlyReconciledAdjustments),
                          ),
                          (
                            'Movimientos conciliados',
                            '${account.reconciledMovementCount}',
                          ),
                          (
                            'Movimientos tardíos pendientes',
                            '${account.pendingLateMovementCount}',
                          ),
                          (
                            'Revisiones pendientes',
                            '${account.pendingReviewCount}',
                          ),
                          (
                            'Neto pendiente de cierre',
                            '${account.currencyCode} ${_signedMoney(account.pendingCloseNet)}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountDetailEquation extends StatelessWidget {
  const _AccountDetailEquation({required this.account});

  final TreasuryMonthlyAccountModel account;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final original = account.originalCloseBalance;
    final adjustment = account.currentAdjustments;
    final current = account.currentBalance;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border(left: BorderSide(color: tokens.accent, width: 3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 500;
          final values = [
            _AccountEquationValue(
              label: 'SALDO DEL CIERRE',
              value: original == null
                  ? '—'
                  : '${account.currencyCode} ${_monthlyMoney.format(original)}',
            ),
            _AccountEquationValue(
              label: 'AJUSTES VIGENTES',
              value: adjustment == null
                  ? '—'
                  : compact
                  ? '${account.currencyCode} ${_signedMoney(adjustment)}'
                  : '${account.currencyCode} ${_monthlyMoney.format(adjustment.abs())}',
            ),
            _AccountEquationValue(
              label: 'SALDO VIGENTE',
              value: current == null
                  ? '—'
                  : '${account.currencyCode} ${_monthlyMoney.format(current)}',
              emphasis: true,
            ),
          ];
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                values[0],
                const SizedBox(height: 9),
                values[1],
                const SizedBox(height: 9),
                values[2],
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: values[0]),
              Text(
                adjustment != null && adjustment < 0 ? ' − ' : ' + ',
                style: TextStyle(color: tokens.muted),
              ),
              Expanded(child: values[1]),
              Text(' = ', style: TextStyle(color: tokens.muted)),
              Expanded(child: values[2]),
            ],
          );
        },
      ),
    );
  }
}

class _AccountEquationValue extends StatelessWidget {
  const _AccountEquationValue({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: tokens.muted,
            fontFamily: PulsoFonts.mono,
            fontSize: 7,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: emphasis ? tokens.accent : tokens.chalk,
            fontFamily: PulsoFonts.mono,
            fontSize: emphasis ? 13 : 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _AccountDetailSection extends StatelessWidget {
  const _AccountDetailSection({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PulsoLabel(title),
        const SizedBox(height: 5),
        for (final row in rows)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.$1,
                    style: TextStyle(color: tokens.chalkDim, fontSize: 10),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  row.$2,
                  style: TextStyle(
                    color: tokens.chalk,
                    fontFamily: PulsoFonts.mono,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

DateTime _monthDate(String value) {
  final parts = value.split('-');
  return DateTime.utc(int.parse(parts[0]), int.parse(parts[1]), 1);
}

String _canonicalMonth(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}';

String _monthLabel(String value) {
  const months = [
    'ENERO',
    'FEBRERO',
    'MARZO',
    'ABRIL',
    'MAYO',
    'JUNIO',
    'JULIO',
    'AGOSTO',
    'SEPTIEMBRE',
    'OCTUBRE',
    'NOVIEMBRE',
    'DICIEMBRE',
  ];
  final date = _monthDate(value);
  return '${months[date.month - 1]} ${date.year}';
}

String _signedMoney(double value) {
  final sign = value > 0
      ? '+'
      : value < 0
      ? '−'
      : '';
  return '$sign${_monthlyMoney.format(value.abs())}';
}
