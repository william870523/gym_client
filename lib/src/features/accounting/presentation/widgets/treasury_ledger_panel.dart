import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/accounting_models.dart';
import '../../data/repositories/accounting_repository.dart';
import '../../data/services/treasury_daily_close_report_service.dart';
import '../state/accounting_providers.dart';
import 'treasury_monthly_panel.dart';
import 'treasury_period_close_panel.dart';

final _treasuryMoney = NumberFormat('#,##0.00');

/// Alto de la línea «recargos condonados» plegada y de su detalle abierto.
///
/// El panel del cierre tiene altura fija, así que el alto lo fija el padre y la
/// línea se ajusta a él: si estos números no cuadraran con lo que dibuja
/// `_WaivedLateFeesLine`, la vista desbordaría a 360 px.
const double _waivedLineCompactHeight = 96;
const double _waivedLineHeight = 70;
const double _waivedDetailHeight = 150;

/// Por debajo de este ancho la línea apila el importe bajo el rótulo.
const double _waivedCompactWidth = 520;

/// Alto de la línea «cobros por recepcionista» (R5.6) plegada y abierta. Mismo
/// motivo que arriba: el panel tiene alto fijo y lo reserva el padre.
const double _collectorsLineHeight = 70;
const double _collectorsLineCompactHeight = 96;
const double _collectorsDetailHeight = 176;

enum _TreasuryRange { daily, monthly, period }

String _treasuryError(Object error) {
  if (error is DioException && error.response?.data is Map) {
    final message = (error.response!.data as Map)['error'];
    if (message != null) return message.toString();
  }
  return 'No se pudo completar la operación de Tesorería.';
}

String _businessDateLabel(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return value;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

DateTime _businessDateValue(String value) {
  final parts = value.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

String _canonicalBusinessDate(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}

String _conceptLabel(String value) {
  final words = value.toLowerCase().replaceAll('_', ' ').split(' ');
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

void _disposeDialogControllers(Iterable<TextEditingController> controllers) {
  // showDialog completes as soon as the route is popped, while its reverse
  // transition can still be rebuilding the text fields for a few frames.
  Future<void>.delayed(const Duration(milliseconds: 350), () {
    for (final controller in controllers) {
      controller.dispose();
    }
  });
}

class _TreasuryRangeSelector extends StatelessWidget {
  const _TreasuryRangeSelector({required this.value, required this.onChanged});

  final _TreasuryRange value;
  final ValueChanged<_TreasuryRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    Widget option({
      required Key key,
      required _TreasuryRange range,
      required String label,
      required IconData icon,
    }) {
      final selected = value == range;
      return Expanded(
        child: Material(
          color: selected ? tokens.accent : tokens.surface,
          child: InkWell(
            key: key,
            onTap: () => onChanged(range),
            child: Container(
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected ? tokens.accent : tokens.line,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? tokens.accentInk : tokens.muted,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? tokens.accentInk : tokens.chalkDim,
                      fontFamily: PulsoFonts.mono,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget options() => Row(
      children: [
        option(
          key: const Key('treasury-range-daily'),
          range: _TreasuryRange.daily,
          label: 'LIBRO DIARIO',
          icon: Icons.today_outlined,
        ),
        const SizedBox(width: 6),
        option(
          key: const Key('treasury-range-monthly'),
          range: _TreasuryRange.monthly,
          label: 'RESUMEN MENSUAL',
          icon: Icons.query_stats_outlined,
        ),
        const SizedBox(width: 6),
        option(
          key: const Key('treasury-range-period'),
          range: _TreasuryRange.period,
          label: 'CIERRE POR PERÍODO',
          icon: Icons.date_range_outlined,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return SingleChildScrollView(
            key: const Key('treasury-range-scroll'),
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: 620, child: options()),
          );
        }
        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: constraints.maxWidth < 700 ? constraints.maxWidth : 700,
            child: options(),
          ),
        );
      },
    );
  }
}

class _ManualTreasuryDraft {
  const _ManualTreasuryDraft({
    required this.type,
    required this.concept,
    required this.description,
    required this.evidenceReference,
    required this.amount,
    required this.originAccountId,
    required this.destinationAccountId,
    required this.originPaymentTypeId,
    required this.destinationPaymentTypeId,
  });

  final String type;
  final String concept;
  final String? description;
  final String evidenceReference;
  final String amount;
  final String? originAccountId;
  final String? destinationAccountId;
  final String? originPaymentTypeId;
  final String? destinationPaymentTypeId;
}

class TreasuryLedgerPanel extends ConsumerStatefulWidget {
  const TreasuryLedgerPanel({super.key, required this.onChanged});

  final VoidCallback onChanged;

  @override
  ConsumerState<TreasuryLedgerPanel> createState() =>
      _TreasuryLedgerPanelState();
}

class _TreasuryLedgerPanelState extends ConsumerState<TreasuryLedgerPanel> {
  final _accountsScroll = ScrollController();
  final _movementsScroll = ScrollController();
  String? _selectedDate;
  String? _accountFilterId;
  _TreasuryRange _range = _TreasuryRange.daily;
  // El plegado vive aquí, no dentro de la línea: el panel tiene alto fijo y
  // necesita reservar el espacio del detalle para no desbordar a 360 px.
  bool _waivedExpanded = false;
  bool _collectorsExpanded = false;

  @override
  void dispose() {
    _accountsScroll.dispose();
    _movementsScroll.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(treasuryLedgerProvider(_selectedDate));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(treasuryLedgerProvider(_selectedDate));
    final width = MediaQuery.sizeOf(context).width;
    final hasWaived = state.value?.waivedLateFees.isEmpty == false;
    final waivedCompact = width < _waivedCompactWidth;
    final waivedHeight = !hasWaived
        ? 0.0
        : (waivedCompact ? _waivedLineCompactHeight : _waivedLineHeight) +
              10 +
              (_waivedExpanded ? _waivedDetailHeight : 0.0);
    final hasCollectors = state.value?.collectorRows.isNotEmpty == true;
    final collectorsHeight = !hasCollectors
        ? 0.0
        : (waivedCompact
                  ? _collectorsLineCompactHeight
                  : _collectorsLineHeight) +
              10 +
              (_collectorsExpanded ? _collectorsDetailHeight : 0.0);
    // El libro apilado (cuentas sobre movimientos) entra por debajo de 880 px,
    // no de 760: con el umbral viejo la vista desbordaba entre 760 y 880.
    return SizedBox(
      height: (width < 880 ? 970 : 770) + waivedHeight + collectorsHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TreasuryRangeSelector(
            value: _range,
            onChanged: (value) => setState(() => _range = value),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _range == _TreasuryRange.monthly
                ? TreasuryMonthlyPanel(onChanged: widget.onChanged)
                : _range == _TreasuryRange.period
                ? TreasuryPeriodClosePanel(onChanged: widget.onChanged)
                : state.when(
                    loading: () => const PulsoPanel(
                      child: PulsoStateView(
                        kind: PulsoStateKind.loading,
                        message: 'Reconstruyendo el libro diario de Tesorería…',
                      ),
                    ),
                    error: (error, _) => PulsoPanel(
                      child: PulsoStateView(
                        kind: PulsoStateKind.error,
                        message: 'No se pudo cargar el libro diario.\n$error',
                        onRetry: _refresh,
                      ),
                    ),
                    data: _buildLedger,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedger(TreasuryLedgerModel ledger) {
    final tokens = PulsoTokens.of(context);
    final filteredMovements = _accountFilterId == null
        ? ledger.movements
        : ledger.movements
              .where((movement) => movement.accountId == _accountFilterId)
              .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TreasuryHeader(
          ledger: ledger,
          onManual: _createManualMovement,
          onPolicy:
              const {
                'admin',
                'administrador',
              }.contains(ledger.closeCapabilities.role)
              ? () => _editClosePolicy(ledger)
              : null,
          onPrevious: () => _moveDate(ledger.businessDate, -1),
          onNext: () => _moveDate(ledger.businessDate, 1),
          onPickDate: () => _pickDate(ledger.businessDate),
          onRefresh: _refresh,
        ),
        const SizedBox(height: 10),
        _CurrencySummaryStrip(
          summaries: ledger.currencySummaries,
          incidents: ledger.incidents,
        ),
        // Solo se dibuja si hubo condonaciones: si no, no se ensucia el cierre.
        if (!ledger.waivedLateFees.isEmpty) ...[
          const SizedBox(height: 10),
          _WaivedLateFeesLine(
            waived: ledger.waivedLateFees,
            expanded: _waivedExpanded,
            compact: MediaQuery.sizeOf(context).width < _waivedCompactWidth,
            onToggle: () => setState(() => _waivedExpanded = !_waivedExpanded),
          ),
        ],
        // R5.6 — quién recibió el dinero. Solo aparece si hubo cobros ese día.
        if (ledger.collectorRows.isNotEmpty) ...[
          const SizedBox(height: 10),
          _CollectorsLine(
            rows: ledger.collectorRows,
            expanded: _collectorsExpanded,
            compact: MediaQuery.sizeOf(context).width < _waivedCompactWidth,
            onToggle: () =>
                setState(() => _collectorsExpanded = !_collectorsExpanded),
          ),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final accounts = _AccountsLedger(
                ledger: ledger,
                selectedAccountId: _accountFilterId,
                scrollController: _accountsScroll,
                onSelected: (account) {
                  setState(() {
                    _accountFilterId = _accountFilterId == account.id
                        ? null
                        : account.id;
                  });
                },
                onClose: (account) => _closeAccount(ledger, account),
                onReview: (account) => _reviewCloseRequest(ledger, account),
                onReconcile: (account) => _reconcileAccount(ledger, account),
                onPrint: (account) => _printClose(ledger, account),
              );
              final movements = _MovementsLedger(
                items: filteredMovements,
                accountName: _accountFilterId == null
                    ? null
                    : ledger.accounts
                          .where((account) => account.id == _accountFilterId)
                          .map((account) => account.name)
                          .firstOrNull,
                scrollController: _movementsScroll,
                onClearFilter: _accountFilterId == null
                    ? null
                    : () => setState(() => _accountFilterId = null),
              );
              if (constraints.maxWidth < 880) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 252, child: accounts),
                    const SizedBox(height: 10),
                    Expanded(child: movements),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 4, child: accounts),
                  const SizedBox(width: 10),
                  Expanded(flex: 7, child: movements),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Los cierres son fotografías inmutables. Un movimiento posterior no altera el comprobante: abre una incidencia de conciliación.',
          style: TextStyle(
            color: tokens.muted2,
            fontFamily: PulsoFonts.mono,
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  void _moveDate(String current, int days) {
    final next = _businessDateValue(current).add(Duration(days: days));
    setState(() {
      _selectedDate = _canonicalBusinessDate(next);
      _accountFilterId = null;
    });
  }

  Future<void> _pickDate(String current) async {
    final today = todayInZone(appClock.gymTimezone);
    final selected = await showDatePicker(
      context: context,
      initialDate: _businessDateValue(current),
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: 'FECHA COMERCIAL DE TESORERÍA',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedDate = _canonicalBusinessDate(selected);
      _accountFilterId = null;
    });
  }

  Future<void> _createManualMovement() async {
    TreasuryRefundOptionsModel options;
    try {
      options = await ref.read(treasuryManualOptionsProvider.future);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_treasuryError(error))));
      return;
    }
    if (!mounted) return;
    if (options.accounts.isEmpty || options.methods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Configure al menos una cuenta y un método activo antes de registrar movimientos.',
          ),
        ),
      );
      return;
    }

    final concept = TextEditingController();
    final amount = TextEditingController();
    final evidence = TextEditingController();
    final description = TextEditingController();
    var type = 'GASTO';
    String? originAccountId = options.accounts.first.id;
    String? destinationAccountId;
    String? originPaymentTypeId =
        options.accounts.first.paymentTypeId ?? options.methods.first.id;
    String? destinationPaymentTypeId;
    String? error;

    TrainerPayoutAccountModel? accountById(String? id) =>
        options.accounts.where((account) => account.id == id).firstOrNull;
    List<TrainerPayoutMethodModel> methodsFor(String? accountId) {
      final account = accountById(accountId);
      if (account?.paymentTypeId == null) return options.methods;
      return options.methods
          .where((method) => method.id == account!.paymentTypeId)
          .toList();
    }

    final draft = await showDialog<_ManualTreasuryDraft>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PulsoThemeScope(
        child: StatefulBuilder(
          builder: (context, setLocal) {
            final tokens = PulsoTokens.of(context);
            final compactFields = MediaQuery.sizeOf(context).width < 720;
            final needsOrigin = type != 'DEPOSITO';
            final needsDestination =
                type == 'DEPOSITO' || type == 'TRANSFERENCIA';
            final originAccount = accountById(originAccountId);
            final destinationCandidates = type == 'TRANSFERENCIA'
                ? options.accounts
                      .where(
                        (account) =>
                            account.id != originAccountId &&
                            account.currencyId == originAccount?.currencyId,
                      )
                      .toList()
                : options.accounts;
            if (needsDestination &&
                destinationAccountId != null &&
                !destinationCandidates.any(
                  (account) => account.id == destinationAccountId,
                )) {
              destinationAccountId = null;
              destinationPaymentTypeId = null;
            }
            final originMethods = methodsFor(originAccountId);
            final destinationMethods = methodsFor(destinationAccountId);
            final typeField = DropdownButtonFormField<String>(
              key: ValueKey('treasury-manual-type-$type'),
              initialValue: type,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Tipo de movimiento',
              ),
              items: const [
                DropdownMenuItem(value: 'GASTO', child: Text('Gasto')),
                DropdownMenuItem(value: 'RETIRO', child: Text('Retiro')),
                DropdownMenuItem(value: 'DEPOSITO', child: Text('Depósito')),
                DropdownMenuItem(
                  value: 'TRANSFERENCIA',
                  child: Text('Transferencia entre cuentas'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setLocal(() {
                  type = value;
                  error = null;
                  if (type == 'DEPOSITO') {
                    destinationAccountId ??= options.accounts.first.id;
                    final destination = accountById(destinationAccountId);
                    destinationPaymentTypeId =
                        destination?.paymentTypeId ?? options.methods.first.id;
                    originAccountId = null;
                    originPaymentTypeId = null;
                  } else {
                    originAccountId ??= options.accounts.first.id;
                    final origin = accountById(originAccountId);
                    originPaymentTypeId =
                        origin?.paymentTypeId ?? options.methods.first.id;
                    if (type != 'TRANSFERENCIA') {
                      destinationAccountId = null;
                      destinationPaymentTypeId = null;
                    }
                  }
                });
              },
            );
            final amountField = TextField(
              key: const Key('treasury-manual-amount'),
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Importe'),
            );
            return AlertDialog(
              title: const Text('Registrar movimiento'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 720,
                  maxHeight: 660,
                ),
                child: SingleChildScrollView(
                  key: const Key('treasury-manual-dialog-scroll'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PulsoLabel('OPERACIÓN MANUAL · TESORERÍA'),
                      const SizedBox(height: 6),
                      Text(
                        'Crea un comprobante auditable y actualiza el libro del día comercial actual.',
                        style: TextStyle(color: tokens.muted, fontSize: 11),
                      ),
                      const SizedBox(height: 16),
                      if (compactFields)
                        Column(
                          children: [
                            typeField,
                            const SizedBox(height: 12),
                            amountField,
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(flex: 3, child: typeField),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: amountField),
                          ],
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('treasury-manual-concept'),
                        controller: concept,
                        maxLength: 120,
                        decoration: const InputDecoration(
                          labelText: 'Concepto',
                          hintText: 'Ej. compra de agua o depósito bancario',
                        ),
                      ),
                      if (needsOrigin) ...[
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'treasury-manual-origin-$originAccountId',
                          ),
                          initialValue: originAccountId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Cuenta de salida',
                          ),
                          items: options.accounts
                              .map(
                                (account) => DropdownMenuItem(
                                  value: account.id,
                                  child: Text(
                                    '${account.name} · ${account.currencyCode}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setLocal(() {
                            originAccountId = value;
                            final selected = accountById(value);
                            originPaymentTypeId =
                                selected?.paymentTypeId ??
                                options.methods.first.id;
                            destinationAccountId = null;
                            destinationPaymentTypeId = null;
                          }),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'treasury-manual-origin-method-$originPaymentTypeId',
                          ),
                          initialValue:
                              originMethods.any(
                                (method) => method.id == originPaymentTypeId,
                              )
                              ? originPaymentTypeId
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Método de salida',
                          ),
                          items: originMethods
                              .map(
                                (method) => DropdownMenuItem(
                                  value: method.id,
                                  child: Text(method.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setLocal(() => originPaymentTypeId = value),
                        ),
                      ],
                      if (needsDestination) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'treasury-manual-destination-$destinationAccountId',
                          ),
                          initialValue: destinationAccountId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: type == 'TRANSFERENCIA'
                                ? 'Cuenta de contrapartida'
                                : 'Cuenta de entrada',
                          ),
                          items: destinationCandidates
                              .map(
                                (account) => DropdownMenuItem(
                                  value: account.id,
                                  child: Text(
                                    '${account.name} · ${account.currencyCode}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setLocal(() {
                            destinationAccountId = value;
                            final selected = accountById(value);
                            destinationPaymentTypeId =
                                selected?.paymentTypeId ??
                                options.methods.first.id;
                          }),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'treasury-manual-destination-method-$destinationPaymentTypeId',
                          ),
                          initialValue:
                              destinationMethods.any(
                                (method) =>
                                    method.id == destinationPaymentTypeId,
                              )
                              ? destinationPaymentTypeId
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Método de entrada',
                          ),
                          items: destinationMethods
                              .map(
                                (method) => DropdownMenuItem(
                                  value: method.id,
                                  child: Text(method.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setLocal(() => destinationPaymentTypeId = value),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('treasury-manual-evidence'),
                        controller: evidence,
                        maxLength: 300,
                        decoration: const InputDecoration(
                          labelText: 'Evidencia o referencia',
                          hintText: 'Factura, recibo, autorización o depósito',
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: description,
                        maxLength: 500,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Nota adicional (opcional)',
                        ),
                      ),
                      if (type == 'TRANSFERENCIA') ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: tokens.accentSoft,
                          child: Text(
                            'La transferencia crea dos movimientos atómicos: una salida y su entrada de contrapartida. Solo se permiten cuentas de la misma moneda.',
                            style: TextStyle(
                              color: tokens.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          style: TextStyle(
                            color: tokens.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('CANCELAR'),
                ),
                PulsoPrimaryButton(
                  label: 'Registrar',
                  icon: Icons.post_add_outlined,
                  onPressed: () {
                    final parsedAmount = double.tryParse(
                      amount.text.trim().replaceAll(',', '.'),
                    );
                    final needsOrigin = type != 'DEPOSITO';
                    final needsDestination =
                        type == 'DEPOSITO' || type == 'TRANSFERENCIA';
                    String? validation;
                    if (parsedAmount == null || parsedAmount <= 0) {
                      validation = 'Escriba un importe mayor que cero.';
                    } else if (concept.text.trim().length < 3) {
                      validation = 'Describa el concepto del movimiento.';
                    } else if (evidence.text.trim().length < 3) {
                      validation =
                          'Indique una factura, recibo o referencia verificable.';
                    } else if (needsOrigin &&
                        (originAccountId == null ||
                            originPaymentTypeId == null)) {
                      validation =
                          'Seleccione la cuenta y el método de salida.';
                    } else if (needsDestination &&
                        (destinationAccountId == null ||
                            destinationPaymentTypeId == null)) {
                      validation =
                          'Seleccione la cuenta y el método de entrada.';
                    }
                    if (validation != null) {
                      setLocal(() => error = validation);
                      return;
                    }
                    Navigator.of(dialogContext).pop(
                      _ManualTreasuryDraft(
                        type: type,
                        concept: concept.text.trim(),
                        description: description.text.trim().isEmpty
                            ? null
                            : description.text.trim(),
                        evidenceReference: evidence.text.trim(),
                        amount: amount.text.trim().replaceAll(',', '.'),
                        originAccountId: needsOrigin ? originAccountId : null,
                        destinationAccountId: needsDestination
                            ? destinationAccountId
                            : null,
                        originPaymentTypeId: needsOrigin
                            ? originPaymentTypeId
                            : null,
                        destinationPaymentTypeId: needsDestination
                            ? destinationPaymentTypeId
                            : null,
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );

    _disposeDialogControllers([concept, amount, evidence, description]);
    if (draft == null || !mounted) return;
    try {
      final result = await ref
          .read(accountingRepositoryProvider)
          .createTreasuryManualOperation(
            operationId: const Uuid().v4(),
            type: draft.type,
            concept: draft.concept,
            description: draft.description,
            evidenceReference: draft.evidenceReference,
            amount: draft.amount,
            originAccountId: draft.originAccountId,
            destinationAccountId: draft.destinationAccountId,
            originPaymentTypeId: draft.originPaymentTypeId,
            destinationPaymentTypeId: draft.destinationPaymentTypeId,
          );
      if (!mounted) return;
      setState(() {
        _selectedDate = result.businessDate;
        _accountFilterId = null;
      });
      ref.invalidate(treasuryLedgerProvider);
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movimiento de Tesorería registrado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_treasuryError(error))));
    }
  }

  Future<void> _closeAccount(
    TreasuryLedgerModel ledger,
    TreasuryAccountDayModel account,
  ) async {
    final opening = TextEditingController(
      text: account.suggestedOpeningBalance.toStringAsFixed(2),
    );
    final counted = TextEditingController(
      text: (account.suggestedOpeningBalance + account.net).toStringAsFixed(2),
    );
    final varianceReason = TextEditingController();
    var saving = false;
    String? error;
    final result = await showDialog<TreasuryLedgerModel>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PulsoThemeScope(
        child: StatefulBuilder(
          builder: (context, setLocal) {
            final tokens = PulsoTokens.of(context);
            final compactFields = MediaQuery.sizeOf(context).width < 650;
            final openingValue =
                double.tryParse(opening.text.replaceAll(',', '.')) ?? 0;
            final countedValue =
                double.tryParse(counted.text.replaceAll(',', '.')) ?? 0;
            final expected = openingValue + account.entries - account.exits;
            final difference = countedValue - expected;
            final tolerance = ledger.closePolicy.toleranceFor(
              account.currencyId,
            );
            final needsApproval = difference.abs() > tolerance + 0.000001;
            final openingField = TextField(
              controller: opening,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: 'Saldo inicial (${account.currencyCode})',
              ),
              onChanged: (_) => setLocal(() {}),
            );
            final countedField = TextField(
              controller: counted,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: 'Saldo contado (${account.currencyCode})',
              ),
              onChanged: (_) => setLocal(() {}),
            );
            return AlertDialog(
              title: const Text('Cerrar cuenta del día'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 560,
                  maxHeight: 590,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PulsoLabel('CIERRE INMUTABLE · TESORERÍA'),
                      const SizedBox(height: 6),
                      Text(
                        account.name,
                        style: TextStyle(
                          color: tokens.chalk,
                          fontFamily: PulsoFonts.display,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                      Text(
                        '${_businessDateLabel(ledger.businessDate)} · ${account.currencyCode} · ${account.movementCount} movimiento(s)',
                        style: TextStyle(color: tokens.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      if (account.reviewCount > 0)
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: tokens.warningSoft,
                          child: Text(
                            '${account.reviewCount} movimiento(s) requieren revisión. El cierre permanecerá bloqueado hasta corregirlos.',
                            style: TextStyle(
                              color: tokens.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (account.reviewCount > 0) const SizedBox(height: 12),
                      if (compactFields)
                        Column(
                          children: [
                            openingField,
                            const SizedBox(height: 12),
                            countedField,
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(child: openingField),
                            const SizedBox(width: 12),
                            Expanded(child: countedField),
                          ],
                        ),
                      const SizedBox(height: 14),
                      _CloseArithmetic(
                        currencyCode: account.currencyCode,
                        entries: account.entries,
                        exits: account.exits,
                        expected: expected,
                        difference: difference,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: needsApproval
                              ? tokens.warningSoft
                              : tokens.successSoft,
                          border: Border.all(
                            color: needsApproval
                                ? tokens.warning
                                : tokens.success,
                          ),
                        ),
                        child: Text(
                          needsApproval
                              ? 'La diferencia supera la tolerancia de ${account.currencyCode} ${_treasuryMoney.format(tolerance)}. Se guardará para aprobación; todavía no será un cierre.'
                              : 'Diferencia dentro de la tolerancia de ${account.currencyCode} ${_treasuryMoney.format(tolerance)}. Puede emitirse el cierre ahora.',
                          style: TextStyle(
                            color: needsApproval
                                ? tokens.warning
                                : tokens.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (needsApproval) ...[
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('treasury-close-variance-reason'),
                          controller: varianceReason,
                          minLines: 2,
                          maxLines: 4,
                          maxLength: 500,
                          decoration: const InputDecoration(
                            labelText: 'Justificación de la diferencia',
                            hintText:
                                'Explique faltante, sobrante o evidencia revisada',
                          ),
                        ),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          style: TextStyle(
                            color: tokens.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('CANCELAR'),
                ),
                PulsoPrimaryButton(
                  label: needsApproval
                      ? 'Solicitar aprobación'
                      : 'Confirmar cierre',
                  icon: needsApproval
                      ? Icons.approval_outlined
                      : Icons.lock_outline,
                  busy: saving,
                  onPressed: saving || account.reviewCount > 0
                      ? null
                      : () async {
                          if (double.tryParse(
                                    opening.text.replaceAll(',', '.'),
                                  ) ==
                                  null ||
                              double.tryParse(
                                    counted.text.replaceAll(',', '.'),
                                  ) ==
                                  null) {
                            setLocal(
                              () => error = 'Escriba saldos numéricos válidos.',
                            );
                            return;
                          }
                          setLocal(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            final response = await ref
                                .read(accountingRepositoryProvider)
                                .closeTreasuryAccount(
                                  operationId: const Uuid().v4(),
                                  businessDate: ledger.businessDate,
                                  accountId: account.id,
                                  openingBalance: opening.text.replaceAll(
                                    ',',
                                    '.',
                                  ),
                                  countedBalance: counted.text.replaceAll(
                                    ',',
                                    '.',
                                  ),
                                  varianceReason: varianceReason.text.trim(),
                                );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(response);
                            }
                          } catch (exception) {
                            setLocal(() {
                              saving = false;
                              error = _treasuryError(exception);
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
    _disposeDialogControllers([opening, counted, varianceReason]);
    if (result == null || !mounted) return;
    ref.invalidate(treasuryLedgerProvider(_selectedDate));
    widget.onChanged();
    final pending = result.closeResultStatus == 'PENDIENTE';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          pending
              ? 'Arqueo de ${account.name} enviado para aprobación.'
              : 'Cierre de ${account.name} registrado.',
        ),
      ),
    );
  }

  Future<void> _reviewCloseRequest(
    TreasuryLedgerModel ledger,
    TreasuryAccountDayModel account,
  ) async {
    final request = account.pendingApproval;
    if (request == null) return;
    final reason = TextEditingController();
    var saving = false;
    String? error;
    final canDecide =
        ledger.closeCapabilities.canApprove &&
        (ledger.closeCapabilities.allowSelfApproval ||
            ledger.closeCapabilities.userId != request.requesterId);
    final result = await showDialog<TreasuryLedgerModel>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PulsoThemeScope(
        child: StatefulBuilder(
          builder: (context, setLocal) {
            final tokens = PulsoTokens.of(context);
            Future<void> decide(String decision) async {
              if (decision == 'RECHAZAR' && reason.text.trim().length < 5) {
                setLocal(
                  () =>
                      error = 'Explique el rechazo con al menos 5 caracteres.',
                );
                return;
              }
              setLocal(() {
                saving = true;
                error = null;
              });
              try {
                final response = await ref
                    .read(accountingRepositoryProvider)
                    .decideTreasuryCloseRequest(
                      requestId: request.id,
                      operationId: const Uuid().v4(),
                      decision: decision,
                      reason: reason.text.trim(),
                    );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(response);
                }
              } catch (exception) {
                setLocal(() {
                  saving = false;
                  error = _treasuryError(exception);
                });
              }
            }

            return AlertDialog(
              title: const Text('Revisar diferencia de arqueo'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 620,
                  maxHeight: 610,
                ),
                child: SingleChildScrollView(
                  key: const Key('treasury-close-approval-dialog-scroll'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PulsoLabel('SOLICITUD PENDIENTE · DOBLE CONTROL'),
                      const SizedBox(height: 6),
                      Text(
                        account.name,
                        style: TextStyle(
                          color: tokens.chalk,
                          fontFamily: PulsoFonts.display,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${request.requesterName} · ${request.requesterRole} · ${_businessDateLabel(request.businessDate)}',
                        style: TextStyle(color: tokens.muted, fontSize: 11),
                      ),
                      const SizedBox(height: 14),
                      _CloseArithmetic(
                        currencyCode: account.currencyCode,
                        entries: request.entries,
                        exits: request.exits,
                        expected: request.expectedBalance,
                        difference: request.difference,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Contado ${account.currencyCode} ${_treasuryMoney.format(request.countedBalance)} · tolerancia ${_treasuryMoney.format(request.appliedTolerance)}',
                        style: TextStyle(
                          color: tokens.warning,
                          fontFamily: PulsoFonts.mono,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        request.reason,
                        style: TextStyle(color: tokens.chalkDim),
                      ),
                      const SizedBox(height: 14),
                      if (!canDecide)
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: tokens.warningSoft,
                          child: Text(
                            ledger.closeCapabilities.userId ==
                                    request.requesterId
                                ? 'No puede aprobar su propio arqueo. Debe revisarlo otra persona autorizada.'
                                : 'Su rol permite consultar, pero no decidir esta solicitud.',
                            style: TextStyle(
                              color: tokens.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (canDecide)
                        TextField(
                          controller: reason,
                          minLines: 2,
                          maxLines: 4,
                          maxLength: 500,
                          decoration: const InputDecoration(
                            labelText: 'Nota de la decisión',
                            hintText: 'Obligatoria al rechazar',
                          ),
                        ),
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          error!,
                          style: TextStyle(
                            color: tokens.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('CERRAR'),
                ),
                if (canDecide)
                  OutlinedButton.icon(
                    onPressed: saving ? null : () => decide('RECHAZAR'),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('RECHAZAR'),
                  ),
                if (canDecide)
                  PulsoPrimaryButton(
                    label: 'Aprobar y cerrar',
                    icon: Icons.verified_outlined,
                    busy: saving,
                    onPressed: saving ? null : () => decide('APROBAR'),
                  ),
              ],
            );
          },
        ),
      ),
    );
    _disposeDialogControllers([reason]);
    if (result == null || !mounted) return;
    ref.invalidate(treasuryLedgerProvider(_selectedDate));
    widget.onChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.closeResultStatus == 'APROBADA'
              ? 'Arqueo aprobado y cierre emitido.'
              : 'Solicitud de arqueo actualizada.',
        ),
      ),
    );
  }

  Future<void> _editClosePolicy(TreasuryLedgerModel ledger) async {
    final defaultTolerance = TextEditingController(
      text: ledger.closePolicy.defaultTolerance.toStringAsFixed(2),
    );
    final currencyLabels = <String, String>{
      for (final account in ledger.accounts)
        account.currencyId: account.currencyCode,
    };
    final currencyControllers = {
      for (final entry in currencyLabels.entries)
        entry.key: TextEditingController(
          text: ledger.closePolicy.currencyTolerances[entry.key]
              ?.toStringAsFixed(2),
        ),
    };
    final submitterRoles = {...ledger.closePolicy.submitterRoles};
    final approverRoles = {...ledger.closePolicy.approverRoles};
    var allowSelfApproval = ledger.closePolicy.allowSelfApproval;
    var requireReason = ledger.closePolicy.requireVarianceReason;
    var saving = false;
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PulsoThemeScope(
        child: StatefulBuilder(
          builder: (context, setLocal) {
            final tokens = PulsoTokens.of(context);
            Widget roles(
              String title,
              Set<String> selected,
              List<(String, String)> options,
            ) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PulsoLabel(title),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final option in options)
                        FilterChip(
                          label: Text(option.$2),
                          selected: selected.contains(option.$1),
                          onSelected: saving
                              ? null
                              : (value) => setLocal(() {
                                  if (value) {
                                    selected.add(option.$1);
                                  } else if (selected.length > 1) {
                                    selected.remove(option.$1);
                                  }
                                }),
                        ),
                    ],
                  ),
                ],
              );
            }

            return AlertDialog(
              title: const Text('Política de arqueo'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 640,
                  maxHeight: 650,
                ),
                child: SingleChildScrollView(
                  key: const Key('treasury-close-policy-dialog-scroll'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PulsoLabel('TOLERANCIAS · CONTROL INTERNO'),
                      const SizedBox(height: 6),
                      Text(
                        'La diferencia se compara en la moneda original. Nunca se suman monedas para decidir una aprobación.',
                        style: TextStyle(color: tokens.muted),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        key: const Key('treasury-close-default-tolerance'),
                        controller: defaultTolerance,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Tolerancia predeterminada',
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final entry in currencyLabels.entries) ...[
                        TextField(
                          key: ValueKey(
                            'treasury-close-currency-tolerance-${entry.key}',
                          ),
                          controller: currencyControllers[entry.key],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Tolerancia ${entry.value}',
                            hintText: 'Vacío = usar la predeterminada',
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      roles('PUEDEN REGISTRAR ARQUEOS', submitterRoles, const [
                        ('admin', 'Administración'),
                        ('accounting', 'Contabilidad'),
                        ('reception', 'Recepción'),
                      ]),
                      const SizedBox(height: 12),
                      roles('PUEDEN APROBAR DIFERENCIAS', approverRoles, const [
                        ('admin', 'Administración'),
                        ('accounting', 'Contabilidad'),
                      ]),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: requireReason,
                        onChanged: saving
                            ? null
                            : (value) => setLocal(() => requireReason = value),
                        title: const Text('Exigir motivo fuera de tolerancia'),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: allowSelfApproval,
                        onChanged: saving
                            ? null
                            : (value) =>
                                  setLocal(() => allowSelfApproval = value),
                        title: const Text('Permitir autoaprobación'),
                        subtitle: const Text(
                          'Desactivado es el control recomendado.',
                        ),
                      ),
                      if (error != null)
                        Text(
                          error!,
                          style: TextStyle(
                            color: tokens.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('CANCELAR'),
                ),
                PulsoPrimaryButton(
                  label: 'Guardar política',
                  icon: Icons.policy_outlined,
                  busy: saving,
                  onPressed: saving
                      ? null
                      : () async {
                          final defaultValue = double.tryParse(
                            defaultTolerance.text.replaceAll(',', '.'),
                          );
                          if (defaultValue == null || defaultValue < 0) {
                            setLocal(
                              () => error =
                                  'La tolerancia predeterminada no es válida.',
                            );
                            return;
                          }
                          final byCurrency = <String, String>{};
                          for (final entry in currencyControllers.entries) {
                            final text = entry.value.text.trim();
                            if (text.isEmpty) continue;
                            final value = double.tryParse(
                              text.replaceAll(',', '.'),
                            );
                            if (value == null || value < 0) {
                              setLocal(
                                () => error =
                                    'Revise las tolerancias por moneda.',
                              );
                              return;
                            }
                            byCurrency[entry.key] = text.replaceAll(',', '.');
                          }
                          setLocal(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            await ref
                                .read(accountingRepositoryProvider)
                                .updateTreasuryClosePolicy(
                                  defaultTolerance: defaultTolerance.text
                                      .replaceAll(',', '.'),
                                  currencyTolerances: byCurrency,
                                  submitterRoles: submitterRoles.toList(),
                                  approverRoles: approverRoles.toList(),
                                  allowSelfApproval: allowSelfApproval,
                                  requireVarianceReason: requireReason,
                                );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          } catch (exception) {
                            setLocal(() {
                              saving = false;
                              error = _treasuryError(exception);
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
    _disposeDialogControllers([
      defaultTolerance,
      ...currencyControllers.values,
    ]);
    if (saved != true || !mounted) return;
    ref.invalidate(treasuryLedgerProvider(_selectedDate));
    widget.onChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Política de arqueo actualizada.')),
    );
  }

  Future<void> _reconcileAccount(
    TreasuryLedgerModel ledger,
    TreasuryAccountDayModel account,
  ) async {
    final close = account.close;
    if (close == null) return;
    final reason = TextEditingController();
    final evidence = TextEditingController();
    final pending = ledger.movements
        .where(
          (movement) =>
              movement.accountId == account.id &&
              movement.late &&
              !movement.reconciled,
        )
        .toList();
    final pendingEntries = pending
        .where((movement) => movement.isEntry)
        .fold<double>(0, (sum, movement) => sum + movement.amount);
    final pendingExits = pending
        .where((movement) => !movement.isEntry)
        .fold<double>(0, (sum, movement) => sum + movement.amount);
    final adjustment = pendingEntries - pendingExits;
    final currentAdjusted = account.adjustedBalance ?? close.countedBalance;
    final resultingAdjusted = currentAdjusted + adjustment;
    var saving = false;
    String? error;

    final result = await showDialog<TreasuryLedgerModel>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PulsoThemeScope(
        child: StatefulBuilder(
          builder: (context, setLocal) {
            final tokens = PulsoTokens.of(context);
            return AlertDialog(
              title: const Text('Conciliar movimientos tardíos'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 650,
                  maxHeight: 640,
                ),
                child: SingleChildScrollView(
                  key: const Key('treasury-reconciliation-dialog-scroll'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PulsoLabel('CONCILIACIÓN · CIERRE INMUTABLE'),
                      const SizedBox(height: 6),
                      Text(
                        account.name,
                        style: TextStyle(
                          color: tokens.chalk,
                          fontFamily: PulsoFonts.display,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${close.receiptNumber} · ${_businessDateLabel(ledger.businessDate)}',
                        style: TextStyle(
                          color: tokens.muted,
                          fontFamily: PulsoFonts.mono,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: tokens.warningSoft,
                        child: Text(
                          'Se reconocerán ${pending.length} movimiento(s) tardío(s). El cierre original no se modifica; se crea un comprobante separado y auditable.',
                          style: TextStyle(
                            color: tokens.warning,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ReconciliationArithmetic(
                        currencyCode: account.currencyCode,
                        entries: pendingEntries,
                        exits: pendingExits,
                        adjustment: adjustment,
                        previousAdjusted: currentAdjusted,
                        resultingAdjusted: resultingAdjusted,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        key: const Key('treasury-reconciliation-reason'),
                        controller: reason,
                        maxLength: 500,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Motivo de conciliación',
                          hintText:
                              'Explique por qué los movimientos llegaron después del cierre',
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        key: const Key('treasury-reconciliation-evidence'),
                        controller: evidence,
                        maxLength: 300,
                        decoration: const InputDecoration(
                          labelText: 'Evidencia o referencia',
                          hintText:
                              'Ticket de sincronización, recibo o autorización',
                        ),
                      ),
                      if (account.reconciliations.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Este cierre ya posee ${account.reconciliations.length} conciliación(es) previa(s). El nuevo comprobante cubrirá únicamente movimientos aún pendientes.',
                          style: TextStyle(color: tokens.muted, fontSize: 10),
                        ),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          error!,
                          style: TextStyle(
                            color: tokens.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('CANCELAR'),
                ),
                PulsoPrimaryButton(
                  key: const Key('treasury-reconciliation-confirm'),
                  label: 'Conciliar',
                  icon: Icons.fact_check_outlined,
                  busy: saving,
                  onPressed: saving || pending.isEmpty
                      ? null
                      : () async {
                          final normalizedReason = reason.text.trim();
                          final normalizedEvidence = evidence.text.trim();
                          if (normalizedReason.length < 5) {
                            setLocal(
                              () => error =
                                  'Explique el motivo con al menos 5 caracteres.',
                            );
                            return;
                          }
                          if (normalizedEvidence.length < 3) {
                            setLocal(
                              () => error =
                                  'Indique una evidencia o referencia verificable.',
                            );
                            return;
                          }
                          setLocal(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            final response = await ref
                                .read(accountingRepositoryProvider)
                                .reconcileTreasuryClose(
                                  operationId: const Uuid().v4(),
                                  closeId: close.id,
                                  reason: normalizedReason,
                                  evidenceReference: normalizedEvidence,
                                );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(response);
                            }
                          } catch (exception) {
                            setLocal(() {
                              saving = false;
                              error = _treasuryError(exception);
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
    _disposeDialogControllers([reason, evidence]);
    if (result == null || !mounted) return;
    ref.invalidate(treasuryLedgerProvider(_selectedDate));
    widget.onChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${pending.length} movimiento(s) de ${account.name} conciliado(s).',
        ),
      ),
    );
  }

  Future<void> _printClose(
    TreasuryLedgerModel ledger,
    TreasuryAccountDayModel account,
  ) async {
    try {
      await const TreasuryDailyCloseReportService().printReport(
        ledger: ledger,
        account: account,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_treasuryError(error))));
    }
  }
}

class _TreasuryHeader extends StatelessWidget {
  const _TreasuryHeader({
    required this.ledger,
    required this.onManual,
    required this.onPolicy,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
    required this.onRefresh,
  });

  final TreasuryLedgerModel ledger;
  final VoidCallback onManual;
  final VoidCallback? onPolicy;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickDate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PulsoLabel('TESORERÍA · LIBRO Y CIERRE DIARIO'),
              const SizedBox(height: 3),
              Text(
                'Caja por cuenta, moneda y fecha comercial',
                style: TextStyle(
                  color: tokens.chalk,
                  fontFamily: PulsoFonts.display,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          );
          final controls = Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                key: const Key('treasury-manual-operation-button'),
                onPressed: onManual,
                icon: const Icon(Icons.post_add_outlined, size: 17),
                label: const Text('MOVIMIENTO'),
              ),
              if (onPolicy != null)
                OutlinedButton.icon(
                  key: const Key('treasury-close-policy-button'),
                  onPressed: onPolicy,
                  icon: const Icon(Icons.policy_outlined, size: 17),
                  label: const Text('POLÍTICA'),
                ),
              PulsoIconButton(
                icon: Icons.chevron_left,
                tooltip: 'Día anterior',
                onPressed: onPrevious,
              ),
              OutlinedButton.icon(
                onPressed: onPickDate,
                icon: const Icon(Icons.calendar_month_outlined, size: 17),
                label: Text(_businessDateLabel(ledger.businessDate)),
              ),
              PulsoIconButton(
                icon: Icons.chevron_right,
                tooltip: 'Día siguiente',
                onPressed: onNext,
              ),
              PulsoIconButton(
                icon: Icons.refresh,
                tooltip: 'Actualizar Tesorería',
                onPressed: onRefresh,
              ),
            ],
          );
          if (constraints.maxWidth < 960) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [title, const SizedBox(height: 10), controls],
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

class _CurrencySummaryStrip extends StatelessWidget {
  const _CurrencySummaryStrip({
    required this.summaries,
    required this.incidents,
  });

  final List<TreasuryCurrencySummaryModel> summaries;
  final TreasuryIncidentsModel incidents;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final cards = <Widget>[
      for (final summary in summaries)
        SizedBox(
          width: 255,
          child: PulsoPanel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Text(
                  summary.currencyCode,
                  style: TextStyle(
                    color: tokens.accent,
                    fontFamily: PulsoFonts.display,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '+${_treasuryMoney.format(summary.entries)}  −${_treasuryMoney.format(summary.exits)}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.chalk,
                          fontFamily: PulsoFonts.mono,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Neto ${_treasuryMoney.format(summary.net)} · ${summary.movementCount} mov.',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: tokens.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      SizedBox(
        width: 235,
        child: PulsoPanel(
          color: incidents.total > 0 ? tokens.warningSoft : tokens.successSoft,
          borderColor: incidents.total > 0 ? tokens.warning : tokens.success,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(
                incidents.total > 0
                    ? Icons.rule_folder_outlined
                    : Icons.verified_outlined,
                color: incidents.total > 0 ? tokens.warning : tokens.success,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incidents.total > 0
                          ? '${incidents.total} incidencia(s)'
                          : 'Libro conciliable',
                      style: TextStyle(
                        color: incidents.total > 0
                            ? tokens.warning
                            : tokens.success,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${incidents.requiringReview} revisar · ${incidents.lateMovements} tardíos',
                      style: TextStyle(color: tokens.muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
    if (summaries.isEmpty) {
      cards.insert(
        0,
        SizedBox(
          width: 280,
          child: PulsoPanel(
            padding: const EdgeInsets.all(14),
            child: Text(
              'Sin movimientos en esta fecha comercial.',
              style: TextStyle(color: tokens.muted),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        primary: false,
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) => cards[index],
      ),
    );
  }
}

/// Línea «recargos condonados» del cierre (docs/RECARGO_MORA.md §6-bis).
///
/// Muestra cuánto dinero se dejó de cobrar y, al abrirla, quién lo autorizó y
/// por qué. Los importes vienen calculados y agrupados por moneda desde el
/// servidor: aquí no se suma nada, y menos entre monedas distintas.
class _WaivedLateFeesLine extends StatelessWidget {
  const _WaivedLateFeesLine({
    required this.waived,
    required this.expanded,
    required this.compact,
    required this.onToggle,
  });

  final TreasuryWaivedLateFeesModel waived;
  final bool expanded;

  /// Lo decide el padre, que es quien reserva el alto de la línea.
  final bool compact;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final amounts = waived.byCurrency
        .map(
          (currency) =>
              '${currency.currencyCode} ${_treasuryMoney.format(currency.amount)}',
        )
        .join('  ·  ');

    return PulsoPanel(
      padding: EdgeInsets.zero,
      color: tokens.warningSoft,
      borderColor: tokens.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            child: InkWell(
              onTap: onToggle,
              child: SizedBox(
                height: compact ? _waivedLineCompactHeight : _waivedLineHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
                  child: Builder(
                    builder: (context) {
                      final label = Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const PulsoLabel('Recargos condonados'),
                          const SizedBox(height: 3),
                          Text(
                            '${waived.count} condonación(es) · no afecta el arqueo',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: tokens.muted, fontSize: 10),
                          ),
                        ],
                      );
                      final total = Text(
                        amounts,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: compact ? TextAlign.left : TextAlign.right,
                        style: TextStyle(
                          color: tokens.warning,
                          fontFamily: PulsoFonts.mono,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      );
                      final chevron = Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        color: tokens.warning,
                      );
                      // A 360 px el importe no cabe al lado del rótulo.
                      if (compact) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  label,
                                  const SizedBox(height: 6),
                                  total,
                                ],
                              ),
                            ),
                            chevron,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Icon(Icons.gavel_outlined, color: tokens.warning),
                          const SizedBox(width: 10),
                          Expanded(child: label),
                          const SizedBox(width: 10),
                          Flexible(child: total),
                          const SizedBox(width: 4),
                          chevron,
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (expanded)
            Container(
              // Alto acotado y con scroll propio: el panel del cierre tiene
              // altura fija y muchas condonaciones no pueden desbordarlo.
              height: _waivedDetailHeight,
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: tokens.warning)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: ListView(
                primary: false,
                children: [
                  for (final row in waived.details)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  row.memberName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: tokens.chalk,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${row.currencyCode} ${_treasuryMoney.format(row.amount)}',
                                style: TextStyle(
                                  color: tokens.warning,
                                  fontFamily: PulsoFonts.mono,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${row.reason} · autorizó ${row.authorizedBy}',
                            style: TextStyle(color: tokens.muted, fontSize: 10),
                          ),
                        ],
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

/// Resumen auditable de cobros por persona, cuenta y moneda (R5.6).
///
/// Las filas ya llegan agrupadas desde el servidor. Esta vista no suma
/// monedas ni reconstruye importes: se limita a presentar cada grupo y sus
/// componentes bruto, cambio, anulado y neto.
class _CollectorsLine extends StatelessWidget {
  const _CollectorsLine({
    required this.rows,
    required this.expanded,
    required this.compact,
    required this.onToggle,
  });

  final List<TreasuryCollectorRowModel> rows;
  final bool expanded;
  final bool compact;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final attributed = rows.where((row) => !row.unattributed).length;
    final historical = rows.length - attributed;
    final detail = historical == 0
        ? '$attributed grupo(s) atribuido(s) por persona, cuenta y moneda'
        : '$attributed atribuido(s) · $historical histórico(s) sin atribuir';

    return PulsoPanel(
      padding: EdgeInsets.zero,
      color: tokens.accentSoft,
      borderColor: tokens.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            child: InkWell(
              key: const Key('treasury-collectors-toggle'),
              onTap: onToggle,
              child: SizedBox(
                height: compact
                    ? _collectorsLineCompactHeight
                    : _collectorsLineHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
                  child: Row(
                    children: [
                      if (!compact) ...[
                        Icon(Icons.badge_outlined, color: tokens.accent),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const PulsoLabel('Cobros por recepcionista'),
                            const SizedBox(height: 3),
                            Text(
                              detail,
                              maxLines: compact ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        color: tokens.accent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (expanded)
            Container(
              key: const Key('treasury-collectors-detail'),
              height: _collectorsDetailHeight,
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: tokens.accent)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: ListView.separated(
                primary: false,
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final actorColor = row.unattributed
                      ? tokens.warning
                      : tokens.chalk;
                  final actorContext = [
                    if ((row.role ?? '').isNotEmpty) row.role!,
                    if ((row.origin ?? '').isNotEmpty) row.origin!,
                  ].join(' · ');

                  return Semantics(
                    label:
                        '${row.name}, ${row.accountName}, '
                        '${row.currencyCode} ${_treasuryMoney.format(row.net)} neto',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                row.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: actorColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${row.currencyCode} '
                              '${_treasuryMoney.format(row.net)} neto',
                              style: TextStyle(
                                color: tokens.accent,
                                fontFamily: PulsoFonts.mono,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            row.accountName,
                            '${row.payments} pago(s)',
                            '${row.clients} cliente(s)',
                            if (actorContext.isNotEmpty) actorContext,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: tokens.muted, fontSize: 10),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bruto ${_treasuryMoney.format(row.gross)}'
                          ' · cambio ${_treasuryMoney.format(row.change)}'
                          ' · anulado ${_treasuryMoney.format(row.annulled)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.muted2,
                            fontFamily: PulsoFonts.mono,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _AccountsLedger extends StatelessWidget {
  const _AccountsLedger({
    required this.ledger,
    required this.selectedAccountId,
    required this.scrollController,
    required this.onSelected,
    required this.onClose,
    required this.onReview,
    required this.onReconcile,
    required this.onPrint,
  });

  final TreasuryLedgerModel ledger;
  final String? selectedAccountId;
  final ScrollController scrollController;
  final ValueChanged<TreasuryAccountDayModel> onSelected;
  final ValueChanged<TreasuryAccountDayModel> onClose;
  final ValueChanged<TreasuryAccountDayModel> onReview;
  final ValueChanged<TreasuryAccountDayModel> onReconcile;
  final ValueChanged<TreasuryAccountDayModel> onPrint;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    int priority(TreasuryAccountDayModel account) {
      if (account.isPendingApproval) return 0;
      if (account.requiresReconciliation) return 0;
      if (account.isOpen) return 1;
      if (account.isReconciled) return 2;
      return 3;
    }

    final orderedAccounts = [...ledger.accounts]
      ..sort((left, right) {
        final byPriority = priority(left).compareTo(priority(right));
        if (byPriority != 0) return byPriority;
        return left.name.toLowerCase().compareTo(right.name.toLowerCase());
      });
    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 11),
            child: Row(
              children: [
                const Expanded(child: PulsoLabel('CUENTAS DEL DÍA')),
                Text(
                  '${orderedAccounts.length}',
                  style: TextStyle(
                    color: tokens.muted,
                    fontFamily: PulsoFonts.mono,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.line),
          Expanded(
            child: orderedAccounts.isEmpty
                ? const PulsoStateView(
                    kind: PulsoStateKind.empty,
                    message: 'No hay cuentas configuradas.',
                  )
                : Scrollbar(
                    key: const Key('treasury-accounts-scrollbar'),
                    controller: scrollController,
                    thumbVisibility: true,
                    child: ListView.separated(
                      controller: scrollController,
                      primary: false,
                      itemCount: orderedAccounts.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: tokens.line),
                      itemBuilder: (_, index) {
                        final account = orderedAccounts[index];
                        return _AccountDayRow(
                          account: account,
                          selected: selectedAccountId == account.id,
                          onTap: () => onSelected(account),
                          onClose: () => onClose(account),
                          onReview: () => onReview(account),
                          onReconcile: () => onReconcile(account),
                          onPrint: () => onPrint(account),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AccountDayRow extends StatelessWidget {
  const _AccountDayRow({
    required this.account,
    required this.selected,
    required this.onTap,
    required this.onClose,
    required this.onReview,
    required this.onReconcile,
    required this.onPrint,
  });

  final TreasuryAccountDayModel account;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback onReview;
  final VoidCallback onReconcile;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final statusColor = account.isPendingApproval
        ? tokens.warning
        : account.requiresReconciliation
        ? tokens.warning
        : account.isOpen
        ? tokens.accent
        : tokens.success;
    final statusLabel = account.isPendingApproval
        ? 'POR APROBAR'
        : account.requiresReconciliation
        ? 'CONCILIAR'
        : account.isOpen
        ? 'ABIERTA'
        : account.isReconciled
        ? 'CONCILIADA'
        : 'CERRADA';
    return Material(
      color: selected ? tokens.accentSoft : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontFamily: PulsoFonts.mono,
                        fontWeight: FontWeight.w600,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                '${account.currencyCode}  +${_treasuryMoney.format(account.entries)}  −${_treasuryMoney.format(account.exits)}  = ${_treasuryMoney.format(account.net)}',
                style: TextStyle(
                  color: tokens.chalkDim,
                  fontFamily: PulsoFonts.mono,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${account.movementCount} mov. · ${account.reviewCount} por revisar'
                      '${account.lateMovementCount > 0 ? ' · ${account.lateMovementCount} tardío(s)' : ''}'
                      '${account.reconciledMovementCount > 0 ? ' · ${account.reconciledMovementCount} conciliado(s)' : ''}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: tokens.muted, fontSize: 9),
                    ),
                  ),
                  if (account.isPendingApproval)
                    TextButton.icon(
                      key: ValueKey('treasury-review-${account.id}'),
                      onPressed: onReview,
                      icon: const Icon(Icons.approval_outlined, size: 14),
                      label: const Text('REVISAR'),
                    )
                  else if (account.isOpen)
                    TextButton.icon(
                      key: ValueKey('treasury-close-${account.id}'),
                      onPressed: account.reviewCount > 0 ? null : onClose,
                      icon: const Icon(Icons.lock_outline, size: 14),
                      label: const Text('CERRAR'),
                    )
                  else ...[
                    if (account.requiresReconciliation)
                      TextButton.icon(
                        key: ValueKey('treasury-reconcile-${account.id}'),
                        onPressed: onReconcile,
                        icon: const Icon(Icons.fact_check_outlined, size: 14),
                        label: const Text('CONCILIAR'),
                      ),
                    IconButton(
                      onPressed: onPrint,
                      tooltip: 'Imprimir cierre',
                      icon: const Icon(Icons.print_outlined, size: 17),
                    ),
                  ],
                ],
              ),
              if (account.close != null && account.adjustedBalance != null)
                Text(
                  'Saldo cierre ${_treasuryMoney.format(account.close!.countedBalance)} · ajustado ${account.currencyCode} ${_treasuryMoney.format(account.adjustedBalance)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: account.requiresReconciliation
                        ? tokens.warning
                        : tokens.success,
                    fontFamily: PulsoFonts.mono,
                    fontSize: 8,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovementsLedger extends StatelessWidget {
  const _MovementsLedger({
    required this.items,
    required this.accountName,
    required this.scrollController,
    required this.onClearFilter,
  });

  final List<TreasuryMovementModel> items;
  final String? accountName;
  final ScrollController scrollController;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 10, 10, 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const PulsoLabel('MOVIMIENTOS'),
                          if (accountName != null)
                            Text(
                              accountName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${items.length} registro(s)',
                      style: TextStyle(
                        color: tokens.muted,
                        fontFamily: PulsoFonts.mono,
                        fontSize: 9,
                      ),
                    ),
                    if (onClearFilter != null) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: onClearFilter,
                        tooltip: 'Ver todas las cuentas',
                        icon: const Icon(Icons.filter_alt_off_outlined),
                      ),
                    ],
                  ],
                ),
              ),
              Divider(height: 1, color: tokens.line),
              _MovementHeader(compact: compact),
              Expanded(
                child: items.isEmpty
                    ? const PulsoStateView(
                        kind: PulsoStateKind.empty,
                        message: 'No hay movimientos para esta selección.',
                      )
                    : Scrollbar(
                        key: const Key('treasury-ledger-table-scrollbar'),
                        controller: scrollController,
                        thumbVisibility: true,
                        child: ListView.separated(
                          controller: scrollController,
                          primary: false,
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: tokens.line),
                          itemBuilder: (_, index) => _MovementRow(
                            movement: items[index],
                            compact: compact,
                          ),
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

class _MovementHeader extends StatelessWidget {
  const _MovementHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    Text label(String value) => Text(
      value,
      style: TextStyle(
        color: tokens.muted,
        fontFamily: PulsoFonts.mono,
        fontSize: 8,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    );
    return Container(
      color: tokens.raised,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: compact
          ? Row(
              children: [
                Expanded(child: label('MOVIMIENTO')),
                label('IMPORTE'),
              ],
            )
          : Row(
              children: [
                SizedBox(width: 60, child: label('HORA')),
                SizedBox(width: 72, child: label('TIPO')),
                Expanded(flex: 3, child: label('CONCEPTO')),
                Expanded(flex: 2, child: label('CUENTA')),
                SizedBox(width: 94, child: label('MÉTODO')),
                SizedBox(
                  width: 105,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: label('IMPORTE'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement, required this.compact});

  final TreasuryMovementModel movement;
  final bool compact;

  /// R5.6 — «Cobrado por A / Anulado por B» del movimiento.
  ///
  /// Solo se dibuja en movimientos nacidos de un cobro: en un gasto o un
  /// movimiento manual no hay recepcionista que atribuir y la línea sería
  /// ruido. Un cobro anterior al corte lo dice en vez de dejar el hueco.
  String? get _attribution {
    const fromPayment = {"PAGO_CLIENTE", "PAGO_CAMBIO", "PAGO_REVERSION"};
    if (!fromPayment.contains(movement.sourceType)) return null;
    final parts = <String>[
      movement.hasCollector
          ? 'Cobrado por ${movement.collectorName}'
          : 'Sin atribuir · histórico',
      if ((movement.annulledByName ?? '').isNotEmpty)
        'Anulado por ${movement.annulledByName}',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final manual = movement.manualOperation;
    final concept = manual?.concept ?? _conceptLabel(movement.concept);
    final attribution = _attribution;
    final directionColor = movement.isEntry ? tokens.success : tokens.danger;
    final amount = Text(
      '${movement.isEntry ? '+' : '−'} ${movement.currencyCode} ${_treasuryMoney.format(movement.amount)}',
      textAlign: TextAlign.right,
      style: TextStyle(
        color: directionColor,
        fontFamily: PulsoFonts.mono,
        fontWeight: FontWeight.w600,
        fontSize: 10,
      ),
    );
    final flags = <Widget>[
      if (movement.requiresReview)
        _MovementFlag(label: 'REVISAR', color: tokens.warning),
      if (movement.late) _MovementFlag(label: 'TARDÍO', color: tokens.danger),
      if (movement.reconciled)
        _MovementFlag(label: 'CONCILIADO', color: tokens.success),
      if (movement.counterMovementId != null)
        _MovementFlag(label: 'CONTRA', color: tokens.muted),
      if (manual != null)
        _MovementFlag(label: manual.type, color: tokens.accent),
    ];
    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    concept,
                    style: TextStyle(
                      color: tokens.chalk,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                amount,
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${formatDateInZone(movement.occurredAt, appClock.gymTimezone, pattern: 'HH:mm')} · ${movement.accountName} · ${movement.paymentTypeName ?? 'sin método'}',
              style: TextStyle(color: tokens.muted, fontSize: 9),
            ),
            if (attribution != null) ...[
              const SizedBox(height: 3),
              Text(
                attribution,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: movement.hasCollector
                      ? tokens.chalkDim
                      : tokens.muted2,
                  fontFamily: PulsoFonts.mono,
                  fontSize: 8,
                ),
              ),
            ],
            if (manual != null) ...[
              const SizedBox(height: 3),
              Text(
                '${manual.receiptNumber} · ${manual.evidenceReference} · ${manual.operatorName}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.muted2,
                  fontFamily: PulsoFonts.mono,
                  fontSize: 8,
                ),
              ),
            ],
            if (flags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 5, runSpacing: 5, children: flags),
            ],
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              formatDateInZone(
                movement.occurredAt,
                appClock.gymTimezone,
                pattern: 'HH:mm',
              ),
              style: TextStyle(
                color: tokens.muted,
                fontFamily: PulsoFonts.mono,
                fontSize: 9,
              ),
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              movement.direction,
              style: TextStyle(
                color: directionColor,
                fontFamily: PulsoFonts.mono,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  concept,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.chalk,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                if (manual != null)
                  Text(
                    '${manual.receiptNumber} · ${manual.evidenceReference}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.muted,
                      fontFamily: PulsoFonts.mono,
                      fontSize: 8,
                    ),
                  ),
                if (attribution != null)
                  Text(
                    attribution,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: movement.hasCollector
                          ? tokens.chalkDim
                          : tokens.muted2,
                      fontFamily: PulsoFonts.mono,
                      fontSize: 8,
                    ),
                  ),
                if (flags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(spacing: 4, runSpacing: 4, children: flags),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              movement.accountName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.chalkDim, fontSize: 10),
            ),
          ),
          SizedBox(
            width: 94,
            child: Text(
              movement.paymentTypeName ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.muted, fontSize: 9),
            ),
          ),
          SizedBox(width: 105, child: amount),
        ],
      ),
    );
  }
}

class _MovementFlag extends StatelessWidget {
  const _MovementFlag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: PulsoFonts.mono,
          fontWeight: FontWeight.w600,
          fontSize: 7,
        ),
      ),
    );
  }
}

class _ReconciliationArithmetic extends StatelessWidget {
  const _ReconciliationArithmetic({
    required this.currencyCode,
    required this.entries,
    required this.exits,
    required this.adjustment,
    required this.previousAdjusted,
    required this.resultingAdjusted,
  });

  final String currencyCode;
  final double entries;
  final double exits;
  final double adjustment;
  final double previousAdjusted;
  final double resultingAdjusted;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    Widget datum(String label, double value, {Color? color}) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: tokens.raised,
          border: Border.all(color: tokens.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PulsoLabel(label),
            const SizedBox(height: 4),
            Text(
              '$currencyCode ${_treasuryMoney.format(value)}',
              style: TextStyle(
                color: color ?? tokens.chalk,
                fontFamily: PulsoFonts.mono,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: datum('Entradas tardías', entries, color: tokens.success),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: datum('Salidas tardías', exits, color: tokens.danger),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: datum(
                'Ajuste neto',
                adjustment,
                color: adjustment < 0 ? tokens.danger : tokens.accent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: datum('Saldo previo', previousAdjusted)),
          ],
        ),
        const SizedBox(height: 8),
        datum(
          'Saldo ajustado resultante',
          resultingAdjusted,
          color: tokens.success,
        ),
      ],
    );
  }
}

class _CloseArithmetic extends StatelessWidget {
  const _CloseArithmetic({
    required this.currencyCode,
    required this.entries,
    required this.exits,
    required this.expected,
    required this.difference,
  });

  final String currencyCode;
  final double entries;
  final double exits;
  final double expected;
  final double difference;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    Widget datum(String label, double value, {Color? color}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: tokens.raised,
            border: Border.all(color: tokens.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PulsoLabel(label),
              const SizedBox(height: 4),
              Text(
                '$currencyCode ${_treasuryMoney.format(value)}',
                style: TextStyle(
                  color: color ?? tokens.chalk,
                  fontFamily: PulsoFonts.mono,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            datum('Entradas', entries, color: tokens.success),
            const SizedBox(width: 8),
            datum('Salidas', exits, color: tokens.danger),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            datum('Saldo esperado', expected, color: tokens.accent),
            const SizedBox(width: 8),
            datum(
              'Diferencia',
              difference,
              color: difference.abs() < 0.005 ? tokens.success : tokens.warning,
            ),
          ],
        ),
      ],
    );
  }
}
