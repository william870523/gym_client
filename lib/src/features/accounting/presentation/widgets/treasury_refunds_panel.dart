import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/accounting_models.dart';
import '../../data/repositories/accounting_repository.dart';
import '../../data/services/treasury_refund_receipt_service.dart';
import '../state/accounting_providers.dart';

final _money = NumberFormat('#,##0.00');
final _date = DateFormat('dd/MM/yyyy');

String _errorText(Object error) {
  if (error is DioException && error.response?.data is Map) {
    final message = (error.response!.data as Map)['error'];
    if (message != null) return message.toString();
  }
  return 'No se pudo completar la operación de Tesorería.';
}

class TreasuryRefundsPanel extends ConsumerStatefulWidget {
  const TreasuryRefundsPanel({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  ConsumerState<TreasuryRefundsPanel> createState() =>
      _TreasuryRefundsPanelState();
}

class _TreasuryRefundsPanelState extends ConsumerState<TreasuryRefundsPanel> {
  final _scroll = ScrollController();
  String _filter = 'TODOS';

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(treasuryRefundsProvider);
    ref.invalidate(treasuryRefundOptionsProvider);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(treasuryRefundsProvider);
    return SizedBox(
      height: 540,
      child: PulsoPanel(
        padding: EdgeInsets.zero,
        child: state.when(
          loading: () => const PulsoStateView(
            kind: PulsoStateKind.loading,
            message: 'Leyendo solicitudes de reembolso…',
          ),
          error: (error, _) => PulsoStateView(
            kind: PulsoStateKind.error,
            message: 'No se pudo cargar Tesorería.\n$error',
            onRetry: _refresh,
          ),
          data: _buildLedger,
        ),
      ),
    );
  }

  Widget _buildLedger(List<TreasuryRefundModel> all) {
    final tokens = PulsoTokens.of(context);
    final items = all
        .where(
          (item) =>
              _filter == 'TODOS' ||
              item.status == _filter ||
              item.lastReceiptStatus == _filter,
        )
        .toList();
    final pending = all.where((item) => item.isPending).toList();
    final totals = <String, double>{};
    for (final item in pending) {
      totals[item.currencyCode] =
          (totals[item.currencyCode] ?? 0) + item.amount;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final summary = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PulsoLabel('TESORERÍA · REEMBOLSOS'),
                  const SizedBox(height: 4),
                  Text(
                    '${pending.length} pendiente${pending.length == 1 ? '' : 's'} · ${totals.entries.map((e) => '${e.key} ${_money.format(e.value)}').join(' · ')}',
                    style: TextStyle(
                      color: pending.isEmpty ? tokens.success : tokens.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Confirmar registra una salida; rechazar conserva el importe como crédito del socio.',
                    style: TextStyle(color: tokens.muted, fontSize: 11),
                  ),
                ],
              );
              final filter = DropdownButton<String>(
                value: _filter,
                items: const [
                  DropdownMenuItem(value: 'TODOS', child: Text('Todos')),
                  DropdownMenuItem(
                    value: 'PENDIENTE',
                    child: Text('Pendientes'),
                  ),
                  DropdownMenuItem(
                    value: 'CONFIRMADO',
                    child: Text('Confirmados'),
                  ),
                  DropdownMenuItem(
                    value: 'RECHAZADO_CREDITO',
                    child: Text('Acreditados'),
                  ),
                  DropdownMenuItem(value: 'ANULADO', child: Text('Anulados')),
                ],
                onChanged: (value) =>
                    setState(() => _filter = value ?? 'TODOS'),
              );
              if (constraints.maxWidth < 650) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [summary, const SizedBox(height: 8), filter],
                );
              }
              return Row(
                children: [
                  Expanded(child: summary),
                  filter,
                  const SizedBox(width: 8),
                  PulsoIconButton(
                    icon: Icons.refresh,
                    tooltip: 'Actualizar reembolsos',
                    onPressed: _refresh,
                  ),
                ],
              );
            },
          ),
        ),
        Divider(height: 1, color: tokens.line),
        _HeaderRow(compact: MediaQuery.sizeOf(context).width < 760),
        Expanded(
          child: items.isEmpty
              ? const PulsoStateView(
                  kind: PulsoStateKind.empty,
                  message: 'No hay reembolsos para este filtro.',
                )
              : Scrollbar(
                  key: const Key('treasury-refunds-table-scrollbar'),
                  controller: _scroll,
                  thumbVisibility: true,
                  child: ListView.separated(
                    controller: _scroll,
                    primary: false,
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: tokens.line),
                    itemBuilder: (_, index) => _RefundRow(
                      item: items[index],
                      compact: MediaQuery.sizeOf(context).width < 760,
                      onPressed: () => items[index].isPending
                          ? _resolve(items[index])
                          : _openReceipt(items[index]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _resolve(TreasuryRefundModel item) async {
    final options = await ref.read(treasuryRefundOptionsProvider.future);
    if (!mounted) return;
    final accounts = options.accounts
        .where((account) => account.currencyId == item.currencyId)
        .toList();
    var action = 'CONFIRMAR';
    String? accountId = accounts.firstOrNull?.id;
    String? paymentTypeId =
        accounts.firstOrNull?.paymentTypeId ?? options.methods.firstOrNull?.id;
    final reason = TextEditingController();
    var saving = false;
    String? error;
    final receipt = await showDialog<TreasuryRefundReceiptModel>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PulsoThemeScope(
        child: StatefulBuilder(
          builder: (context, setLocal) {
            final tokens = PulsoTokens.of(context);
            final selectedAccount = accounts
                .where((e) => e.id == accountId)
                .firstOrNull;
            final methods = selectedAccount?.paymentTypeId == null
                ? options.methods
                : options.methods
                      .where((e) => e.id == selectedAccount!.paymentTypeId)
                      .toList();
            return AlertDialog(
              title: const Text('Resolver reembolso'),
              content: SizedBox(
                width: 590,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        color: tokens.raised,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.clientName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${item.planName} · ${item.clientId}',
                                    style: TextStyle(color: tokens.muted),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${item.currencyCode} ${_money.format(item.amount)}',
                              style: TextStyle(
                                color: tokens.accent,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'CONFIRMAR',
                            label: Text('Confirmar salida'),
                            icon: Icon(Icons.payments_outlined),
                          ),
                          ButtonSegment(
                            value: 'RECHAZAR_ACREDITAR',
                            label: Text('Rechazar y acreditar'),
                            icon: Icon(Icons.savings_outlined),
                          ),
                        ],
                        selected: {action},
                        onSelectionChanged: (value) =>
                            setLocal(() => action = value.first),
                      ),
                      const SizedBox(height: 14),
                      if (action == 'CONFIRMAR') ...[
                        DropdownButtonFormField<String>(
                          initialValue: accountId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Cuenta de salida',
                          ),
                          items: [
                            for (final account in accounts)
                              DropdownMenuItem(
                                value: account.id,
                                child: Text(account.name),
                              ),
                          ],
                          onChanged: (value) => setLocal(() {
                            accountId = value;
                            final selected = accounts
                                .where((e) => e.id == value)
                                .firstOrNull;
                            paymentTypeId =
                                selected?.paymentTypeId ??
                                options.methods.firstOrNull?.id;
                          }),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue:
                              methods.any((e) => e.id == paymentTypeId)
                              ? paymentTypeId
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Método de salida',
                          ),
                          items: [
                            for (final method in methods)
                              DropdownMenuItem(
                                value: method.id,
                                child: Text(method.name),
                              ),
                          ],
                          onChanged: (value) =>
                              setLocal(() => paymentTypeId = value),
                        ),
                      ] else
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: tokens.warningSoft,
                          child: const Text(
                            'No se perderá el valor: el importe completo quedará disponible como crédito interno del socio.',
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reason,
                        maxLength: 500,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Motivo de la decisión',
                          hintText:
                              'Referencia, autorización o causa del rechazo',
                        ),
                      ),
                      if (error != null)
                        Text(
                          error!,
                          style: TextStyle(color: tokens.danger, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                PulsoSecondaryButton(
                  label: 'Cancelar',
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                ),
                PulsoPrimaryButton(
                  label: action == 'CONFIRMAR'
                      ? 'Registrar salida'
                      : 'Crear crédito',
                  busy: saving,
                  onPressed:
                      saving ||
                          (action == 'CONFIRMAR' &&
                              (accountId == null || paymentTypeId == null))
                      ? null
                      : () async {
                          setLocal(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            final result = await ref
                                .read(accountingRepositoryProvider)
                                .decideTreasuryRefund(
                                  adjustmentId: item.adjustmentId,
                                  operationId: const Uuid().v4(),
                                  action: action,
                                  accountId: accountId,
                                  paymentTypeId: paymentTypeId,
                                  reason: reason.text.trim(),
                                );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext, result);
                            }
                          } catch (caught) {
                            setLocal(() {
                              saving = false;
                              error = _errorText(caught);
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
    reason.dispose();
    if (receipt == null || !mounted) return;
    _refresh();
    await _showReceipt(receipt);
  }

  Future<void> _openReceipt(TreasuryRefundModel item) async {
    if (item.refundId == null) return;
    try {
      final receipt = await ref
          .read(accountingRepositoryProvider)
          .getTreasuryRefundReceipt(item.refundId!);
      if (mounted) {
        await _showReceipt(receipt);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    }
  }

  Future<void> _showReceipt(TreasuryRefundReceiptModel receipt) async {
    final reverse = await showDialog<bool>(
      context: context,
      builder: (context) => PulsoThemeScope(
        child: AlertDialog(
          title: Text(receipt.receiptNumber),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${receipt.currencyCode} ${_money.format(receipt.amount)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text('${receipt.clientName} · ${receipt.clientId}'),
                const Divider(height: 28),
                _Datum('Estado', receipt.status),
                _Datum('Cuenta', receipt.accountName ?? 'Crédito interno'),
                _Datum('Método', receipt.paymentTypeName ?? 'No aplica'),
                _Datum('Registró', receipt.operatorName),
                _Datum('Motivo', receipt.reason),
                if (receipt.reversal != null)
                  _Datum(
                    'Reversión',
                    receipt.reversal?['motivo']?.toString() ?? 'Registrada',
                  ),
              ],
            ),
          ),
          actions: [
            PulsoSecondaryButton(
              label: 'Cerrar',
              onPressed: () => Navigator.pop(context, false),
            ),
            PulsoSecondaryButton(
              label: 'Imprimir',
              onPressed: () =>
                  const TreasuryRefundReceiptService().printReceipt(receipt),
            ),
            if (receipt.status == 'CONFIRMADO' && receipt.reversal == null)
              PulsoPrimaryButton(
                label: 'Revertir',
                onPressed: () => Navigator.pop(context, true),
              ),
          ],
        ),
      ),
    );
    if (reverse == true && mounted) await _reverse(receipt);
  }

  Future<void> _reverse(TreasuryRefundReceiptModel receipt) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revertir reembolso'),
        content: TextField(
          controller: controller,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo del contramovimiento',
          ),
        ),
        actions: [
          PulsoSecondaryButton(
            label: 'Cancelar',
            onPressed: () => Navigator.pop(context),
          ),
          PulsoPrimaryButton(
            label: 'Registrar reversión',
            onPressed: () => Navigator.pop(context, controller.text.trim()),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    try {
      await ref
          .read(accountingRepositoryProvider)
          .reverseTreasuryRefund(
            refundId: receipt.id,
            operationId: const Uuid().v4(),
            reason: reason,
          );
      _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    }
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    color: PulsoTokens.of(context).raised,
    child: Row(
      children: [
        const Expanded(flex: 4, child: PulsoLabel('Socio / plan')),
        if (!compact) const Expanded(flex: 2, child: PulsoLabel('Solicitud')),
        const Expanded(flex: 2, child: PulsoLabel('Importe')),
        const Expanded(flex: 2, child: PulsoLabel('Estado')),
        const SizedBox(width: 96),
      ],
    ),
  );
}

class _RefundRow extends StatelessWidget {
  const _RefundRow({
    required this.item,
    required this.compact,
    required this.onPressed,
  });
  final TreasuryRefundModel item;
  final bool compact;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return SizedBox(
      height: 68,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: _TwoLine(
                item.clientName,
                '${item.planName} · ${item.clientId}',
              ),
            ),
            if (!compact)
              Expanded(
                flex: 2,
                child: _TwoLine(
                  _date.format(item.effectiveDate.toUtc()),
                  item.requestedBy,
                ),
              ),
            Expanded(
              flex: 2,
              child: Text(
                '${item.currencyCode} ${_money.format(item.amount)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                item.isPending && item.lastReceiptStatus == 'ANULADO'
                    ? 'REABIERTO'
                    : _statusLabel(item.status),
                style: TextStyle(
                  color: item.isPending
                      ? tokens.warning
                      : item.status == 'CONFIRMADO'
                      ? tokens.success
                      : tokens.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
            SizedBox(
              width: 96,
              child: TextButton(
                onPressed: onPressed,
                child: Text(item.isPending ? 'Resolver' : 'Comprobante'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TwoLine extends StatelessWidget {
  const _TwoLine(this.primary, this.secondary);
  final String primary;
  final String secondary;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        primary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      Text(
        secondary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: PulsoTokens.of(context).muted, fontSize: 11),
      ),
    ],
  );
}

class _Datum extends StatelessWidget {
  const _Datum(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(width: 100, child: PulsoLabel(label)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

String _statusLabel(String value) => switch (value) {
  'PENDIENTE' => 'PENDIENTE',
  'CONFIRMADO' => 'CONFIRMADO',
  'RECHAZADO_CREDITO' => 'ACREDITADO',
  'ANULADO' => 'ANULADO',
  _ => value,
};
