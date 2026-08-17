import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../auth/presentation/state/auth_notifier.dart';
import '../../../payments/presentation/widgets/process_payment_dialog.dart';
import '../../../products/data/models/membresia_cuota_models.dart';
import '../../../products/data/repositories/payment_plan_repository.dart';
import '../../../products/presentation/widgets/membresia_cuotas_panel.dart';
import '../../../trainers/presentation/providers/trainer_notifier.dart';
import '../../data/models/client_model.dart';
import '../../data/models/client_record_model.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/services/client_statement_export_service.dart';
import '../../domain/membership_vigencia.dart';
import '../state/client_record_export_provider.dart';
import '../state/client_notifier.dart';
import '../state/client_record_provider.dart';
import 'membership_requests_dialog.dart';
import 'multisede_access_panel.dart';
import 'voluntary_cancellation_preview_dialog.dart';

class ClientRecordDialog extends ConsumerWidget {
  const ClientRecordDialog({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(clientRecordProvider(clientId));
    return PulsoThemeScope(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < 1180
              ? constraints.maxWidth - 32
              : 1140.0;
          final height = constraints.maxHeight < 840
              ? constraints.maxHeight - 32
              : 800.0;
          return Center(
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                key: const ValueKey('client-record-dialog'),
                width: width.clamp(320, 1140),
                height: height.clamp(480, 800),
                child: PulsoPanel(
                  padding: EdgeInsets.zero,
                  child: record.when(
                    loading: () => const PulsoStateView(
                      kind: PulsoStateKind.loading,
                      message: 'Reconstruyendo expediente…',
                    ),
                    error: (error, _) => PulsoStateView(
                      kind: PulsoStateKind.error,
                      message: 'No se pudo cargar el expediente.\n$error',
                      onRetry: () =>
                          ref.invalidate(clientRecordProvider(clientId)),
                    ),
                    data: (data) => _RecordBody(
                      record: data,
                      onRefresh: () =>
                          ref.invalidate(clientRecordProvider(clientId)),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecordBody extends ConsumerWidget {
  const _RecordBody({required this.record, required this.onRefresh});

  final ClientRecordModel record;
  final VoidCallback onRefresh;

  int get _linkedPaymentCount => record.memberships.fold(
    0,
    (count, membership) => count + membership.payments.length,
  );

  ClientStatementSnapshot _statementSnapshot(
    ClientRecordFilter filter,
    List<ClientMembershipRecord> memberships,
  ) => ClientStatementSnapshot.fromRecord(
    record: record,
    memberships: memberships,
    timezone: appClock.gymTimezone,
    generatedAtUtc: appClock.nowUtc(),
    scope: _filterSummary(record, filter),
  );

  Future<void> _copySummary(BuildContext context) async {
    final lines = <String>[
      'EXPEDIENTE · ${record.client.fullName}',
      'CI ${record.client.id}',
      'Membresías: ${record.memberships.length}',
      'Pagos: ${_linkedPaymentCount + record.unlinkedPayments.length}',
      for (final total in record.totalsByCurrency)
        '${total.code ?? total.currencyId}: ${total.amount.toStringAsFixed(2)} '
            '(${total.paymentCount} pago${total.paymentCount == 1 ? '' : 's'})',
      '',
      for (final membership in record.memberships)
        '${membership.planName} · ${_date(membership.startDate)} → '
            '${_date(membership.endDate)} · ${membership.status} · '
            '${membership.paidAmount.toStringAsFixed(2)} '
            '${membership.currencyCode ?? membership.currencyId}',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resumen del expediente copiado.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    final filter = ref.watch(clientRecordFilterProvider);
    final visibleMemberships = _filterMemberships(record.memberships, filter);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 86),
          padding: const EdgeInsets.fromLTRB(24, 14, 12, 14),
          decoration: BoxDecoration(
            color: tokens.raised,
            border: Border(bottom: BorderSide(color: tokens.lineStrong)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final title = Row(
                children: [
                  Container(width: 8, height: 42, color: tokens.accent),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PulsoLabel('PULSO · EXPEDIENTE DEL SOCIO'),
                        const SizedBox(height: 3),
                        Text(
                          record.client.fullName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: PulsoFonts.display,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: tokens.chalk,
                          ),
                        ),
                        Text(
                          // H1: la categoría del socio (NUEVO/VIEJO) va en la
                          // cabecera, junto al CI, para que se vea al abrir el
                          // expediente sin entrar a Editar Cliente.
                          [
                            'CI ${record.client.id}',
                            if (record.client.categoria != null &&
                                record.client.categoria!.isNotEmpty)
                              record.client.categoria,
                            'historial contractual y financiero',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: PulsoFonts.mono,
                            fontSize: 10.5,
                            color: tokens.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final actions = Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 6,
                children: [
                  PulsoSecondaryButton(
                    label: 'Exportar',
                    icon: Icons.file_download_outlined,
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => _StatementExportDialog(
                        snapshot: _statementSnapshot(
                          filter,
                          visibleMemberships,
                        ),
                      ),
                    ),
                  ),
                  PulsoSecondaryButton(
                    label: 'Emisiones',
                    icon: Icons.verified_outlined,
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          _StatementDocumentsDialog(clientId: record.client.id),
                    ),
                  ),
                  PulsoSecondaryButton(
                    label: 'Copiar resumen',
                    icon: Icons.content_copy_outlined,
                    onPressed: () => _copySummary(context),
                  ),
                  PulsoIconButton(
                    tooltip: 'Actualizar expediente',
                    icon: Icons.refresh,
                    onPressed: onRefresh,
                  ),
                  PulsoIconButton(
                    tooltip: 'Cerrar',
                    icon: Icons.close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              );
              if (constraints.maxWidth < 720) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 12),
                  actions,
                ],
              );
            },
          ),
        ),
        // La barra de filtros queda FIJA cuando hay ancho para ello: es el
        // mando del expediente y, dentro del scroll, con un historial largo
        // había que subir hasta arriba solo para cambiar un filtro. En
        // compacto no se fija: el alto disponible no da y desbordaría.
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 760) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _RecordExplorerBar(
                record: record,
                filter: filter,
                visibleCount: visibleMemberships.length,
              ),
            );
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Summary(record: record),
                const SizedBox(height: 16),
                // M4a — el acceso multi-sede va junto a la identidad y antes
                // del historial: es una condición del socio, no un movimiento.
                MultisedeAccessPanel(ci: record.client.id),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 760) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _RecordExplorerBar(
                        record: record,
                        filter: filter,
                        visibleCount: visibleMemberships.length,
                      ),
                    );
                  },
                ),
                const PulsoLabel('HISTORIAL DE MEMBRESÍAS'),
                const SizedBox(height: 8),
                if (visibleMemberships.isEmpty)
                  PulsoPanel(
                    child: PulsoStateView(
                      kind: PulsoStateKind.empty,
                      message: record.memberships.isEmpty
                          ? 'No hay membresías históricas registradas.'
                          : 'Ninguna membresía coincide con estos filtros.',
                      onRetry: filter.isActive
                          ? () => ref
                                .read(clientRecordFilterProvider.notifier)
                                .reset()
                          : null,
                    ),
                  )
                else
                  for (final membership in visibleMemberships) ...[
                    _MembershipBlock(
                      membership: membership,
                      client: record.client,
                    ),
                    const SizedBox(height: 10),
                  ],
                if (record.unlinkedPayments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  PulsoLabel(
                    'PAGOS HISTÓRICOS SIN MEMBRESÍA',
                    color: tokens.warning,
                  ),
                  const SizedBox(height: 8),
                  PulsoPanel(
                    child: Column(
                      children: [
                        Text(
                          'Estos cobros pertenecen al cliente, pero fueron creados antes del vínculo explícito con membresías.',
                          style: TextStyle(color: tokens.muted, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        for (final payment in record.unlinkedPayments)
                          _PaymentLine(
                            payment: payment,
                            client: record.client,
                            planName: 'Pago histórico sin membresía',
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _filterSummary(ClientRecordModel record, ClientRecordFilter filter) {
  final planName = filter.planId == null
      ? 'Todos los planes'
      : record.memberships
                .where((item) => item.planId == filter.planId)
                .map((item) => item.planName)
                .firstOrNull ??
            filter.planId!;
  final status = filter.status?.replaceAll('_', ' ') ?? 'Todos los estados';
  return '${filter.period.label} / $planName / $status';
}

class _StatementExportDialog extends ConsumerWidget {
  const _StatementExportDialog({required this.snapshot});

  final ClientStatementSnapshot snapshot;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    ClientRecordExportOperation operation,
  ) async {
    try {
      final notifier = ref.read(clientRecordExportProvider.notifier);
      final success = switch (operation) {
        ClientRecordExportOperation.pdf =>
          await notifier.savePdf(snapshot) != null,
        ClientRecordExportOperation.csv =>
          await notifier.saveCsv(snapshot) != null,
        ClientRecordExportOperation.print => await notifier.printPdf(snapshot),
        ClientRecordExportOperation.idle => false,
      };
      if (!context.mounted || !success) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (operation) {
            ClientRecordExportOperation.pdf => 'Estado de cuenta PDF guardado.',
            ClientRecordExportOperation.csv => 'Movimientos CSV guardados.',
            ClientRecordExportOperation.print =>
              'Documento enviado al sistema de impresión.',
            ClientRecordExportOperation.idle => 'Exportación terminada.',
          }),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo exportar: $error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    final operation = ref.watch(clientRecordExportProvider);
    final busy = operation != ClientRecordExportOperation.idle;
    return PulsoThemeScope(
      child: Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: PulsoPanel(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(width: 6, height: 38, color: tokens.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const PulsoLabel('ESTADO DE CUENTA'),
                          Text(
                            'EXPORTAR / IMPRIMIR',
                            style: TextStyle(
                              fontFamily: PulsoFonts.display,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: tokens.chalk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PulsoIconButton(
                      tooltip: 'Cerrar',
                      icon: Icons.close,
                      onPressed: busy
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PulsoPanel(
                  padding: const EdgeInsets.all(12),
                  color: tokens.floor2,
                  child: Text(
                    '${snapshot.clientName} · ${snapshot.memberships.length} '
                    'membresía(s) · ${snapshot.payments.length} pago(s)\n'
                    '${snapshot.scope}',
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      color: tokens.muted,
                      fontSize: 10.5,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                PulsoPrimaryButton(
                  label: 'Guardar PDF',
                  icon: Icons.picture_as_pdf_outlined,
                  busy: operation == ClientRecordExportOperation.pdf,
                  onPressed: busy
                      ? null
                      : () =>
                            _run(context, ref, ClientRecordExportOperation.pdf),
                ),
                const SizedBox(height: 8),
                PulsoSecondaryButton(
                  label: operation == ClientRecordExportOperation.print
                      ? 'Preparando impresión…'
                      : 'Imprimir',
                  icon: Icons.print_outlined,
                  onPressed: busy
                      ? null
                      : () => _run(
                          context,
                          ref,
                          ClientRecordExportOperation.print,
                        ),
                ),
                const SizedBox(height: 8),
                PulsoSecondaryButton(
                  label: operation == ClientRecordExportOperation.csv
                      ? 'Preparando CSV…'
                      : 'Guardar CSV',
                  icon: Icons.table_view_outlined,
                  onPressed: busy
                      ? null
                      : () =>
                            _run(context, ref, ClientRecordExportOperation.csv),
                ),
                const SizedBox(height: 12),
                Text(
                  'El PDF separa totales por moneda. El CSV crea una fila por forma de pago para conservar cobros mixtos y tasas históricas.',
                  style: TextStyle(color: tokens.muted2, fontSize: 10.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatementDocumentsDialog extends ConsumerWidget {
  const _StatementDocumentsDialog({required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    final documents = ref.watch(clientRecordDocumentsProvider(clientId));
    return PulsoThemeScope(
      child: Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 600),
          child: PulsoPanel(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(width: 6, height: 38, color: tokens.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const PulsoLabel('EXPEDIENTE DEL SOCIO'),
                          Text(
                            'EMISIONES REGISTRADAS',
                            style: TextStyle(
                              fontFamily: PulsoFonts.display,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: tokens.chalk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PulsoIconButton(
                      tooltip: 'Actualizar',
                      icon: Icons.refresh,
                      onPressed: () => ref.invalidate(
                        clientRecordDocumentsProvider(clientId),
                      ),
                    ),
                    PulsoIconButton(
                      tooltip: 'Cerrar',
                      icon: Icons.close,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Cada fila conserva el archivo exacto, la identidad histórica del operador, la hora confiable y su SHA-256.',
                  style: TextStyle(color: tokens.muted, fontSize: 11),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: documents.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(
                      child: Text(
                        'No se pudieron cargar las emisiones: $error',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: tokens.danger),
                      ),
                    ),
                    data: (items) {
                      if (items.isEmpty) {
                        return Center(
                          child: Text(
                            'Todavía no hay documentos emitidos.',
                            style: TextStyle(color: tokens.muted),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: tokens.line),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final localTime = toGymWallClock(
                            item.issuedAtUtc,
                            appClock.gymTimezone,
                          );
                          final shortHash = item.sha256.length > 16
                              ? '${item.sha256.substring(0, 16)}…'
                              : item.sha256;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 46,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: tokens.lineStrong,
                                    ),
                                  ),
                                  child: Text(
                                    item.format,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: PulsoFonts.mono,
                                      fontWeight: FontWeight.w800,
                                      color: tokens.accent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.fileName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: tokens.chalk,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${DateFormat('dd/MM/yyyy HH:mm').format(localTime)} · '
                                        '${item.issuedByName} (${item.issuedByRole}) · '
                                        '${item.destination.toLowerCase()}',
                                        style: TextStyle(
                                          fontFamily: PulsoFonts.mono,
                                          fontSize: 10,
                                          color: tokens.muted,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'SHA-256 $shortHash · ${item.sizeBytes} bytes',
                                        style: TextStyle(
                                          fontFamily: PulsoFonts.mono,
                                          fontSize: 10,
                                          color: tokens.muted2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PulsoIconButton(
                                  tooltip: 'Copiar SHA-256',
                                  icon: Icons.copy_all_outlined,
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: item.sha256),
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('SHA-256 copiado.'),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<ClientMembershipRecord> _filterMemberships(
  List<ClientMembershipRecord> memberships,
  ClientRecordFilter filter,
) {
  final gymNow = toGymWallClock(appClock.nowUtc(), appClock.gymTimezone);
  final cutoff = switch (filter.period) {
    ClientRecordPeriod.all => null,
    ClientRecordPeriod.threeMonths => DateTime.utc(
      gymNow.year,
      gymNow.month - 3,
      gymNow.day,
    ),
    ClientRecordPeriod.sixMonths => DateTime.utc(
      gymNow.year,
      gymNow.month - 6,
      gymNow.day,
    ),
    ClientRecordPeriod.twelveMonths => DateTime.utc(
      gymNow.year - 1,
      gymNow.month,
      gymNow.day,
    ),
  };
  return memberships.where((membership) {
    if (filter.planId != null && membership.planId != filter.planId) {
      return false;
    }
    if (filter.status != null && membership.status != filter.status) {
      return false;
    }
    if (cutoff != null && membership.endDate.isBefore(cutoff)) return false;
    return true;
  }).toList();
}

class _RecordExplorerBar extends ConsumerWidget {
  const _RecordExplorerBar({
    required this.record,
    required this.filter,
    required this.visibleCount,
  });

  final ClientRecordModel record;
  final ClientRecordFilter filter;
  final int visibleCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    final notifier = ref.read(clientRecordFilterProvider.notifier);
    final plans = <String, String>{
      for (final membership in record.memberships)
        membership.planId: membership.planName,
    };
    final statuses = record.memberships.map((item) => item.status).toSet()
      ..remove('');
    final sortedStatuses = statuses.toList()..sort();

    return PulsoPanel(
      padding: const EdgeInsets.all(14),
      color: tokens.floor2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fieldWidth = constraints.maxWidth < 620
              ? constraints.maxWidth
              : (constraints.maxWidth - 16) / 3;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(width: 5, height: 28, color: tokens.accent),
                  const SizedBox(width: 10),
                  const Expanded(child: PulsoLabel('EXPLORAR HISTORIAL')),
                  Text(
                    '$visibleCount / ${record.memberships.length}',
                    key: const ValueKey('record-filter-count'),
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: filter.isActive ? tokens.accent : tokens.muted,
                    ),
                  ),
                  if (filter.isActive) ...[
                    const SizedBox(width: 8),
                    PulsoIconButton(
                      tooltip: 'Limpiar filtros',
                      icon: Icons.filter_alt_off_outlined,
                      onPressed: notifier.reset,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<ClientRecordPeriod>(
                      key: ValueKey('record-period-${filter.period.name}'),
                      isExpanded: true,
                      initialValue: filter.period,
                      decoration: _filterDecoration('PERÍODO', tokens),
                      items: [
                        for (final period in ClientRecordPeriod.values)
                          DropdownMenuItem(
                            value: period,
                            child: Text(period.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) notifier.setPeriod(value);
                      },
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey('record-plan-${filter.planId ?? 'all'}'),
                      isExpanded: true,
                      initialValue: filter.planId,
                      decoration: _filterDecoration('PLAN', tokens),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todos los planes'),
                        ),
                        for (final entry in plans.entries)
                          DropdownMenuItem<String?>(
                            value: entry.key,
                            child: Text(
                              entry.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: notifier.setPlan,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey('record-status-${filter.status ?? 'all'}'),
                      isExpanded: true,
                      initialValue: filter.status,
                      decoration: _filterDecoration('ESTADO', tokens),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todos los estados'),
                        ),
                        for (final status in sortedStatuses)
                          DropdownMenuItem<String?>(
                            value: status,
                            child: Text(status.replaceAll('_', ' ')),
                          ),
                      ],
                      onChanged: notifier.setStatus,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

InputDecoration _filterDecoration(String label, PulsoTokens tokens) =>
    InputDecoration(
      labelText: label,
      filled: true,
      fillColor: tokens.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: tokens.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: tokens.line),
      ),
    );

class _Summary extends StatelessWidget {
  const _Summary({required this.record});

  final ClientRecordModel record;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final paymentCount =
        record.memberships.fold<int>(
          0,
          (count, item) => count + item.payments.length,
        ) +
        record.unlinkedPayments.length;
    // H2: «Activas» mide vigencia, no estado del contrato. Una membresía que
    // venció pero no se anuló seguía `status == ACTIVA` y sumaba, contradiciendo
    // el sello «VENCIDA HACE POCO» que la propia fila pinta. Se reutiliza la
    // misma fuente de verdad que el sello (resolveMembershipVigencia + coversToday).
    final today = todayInZone(appClock.gymTimezone);
    final active = record.memberships
        .where(
          (item) => coversToday(
            resolveMembershipVigencia(
              status: item.status,
              endDate: item.endDate,
              today: today,
            ),
          ),
        )
        .length;
    final voided =
        record.memberships.fold<int>(
          0,
          (count, item) =>
              count + item.payments.where((payment) => payment.isVoided).length,
        ) +
        record.unlinkedPayments.where((payment) => payment.isVoided).length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = [
          _RecordMetric(
            value: '${record.memberships.length}',
            label: 'Membresías',
            note: 'contratos históricos',
          ),
          _RecordMetric(
            value: '$active',
            label: 'Activas',
            note: 'vigencia actual',
            success: active > 0,
          ),
          _RecordMetric(
            value: '$paymentCount',
            label: 'Pagos',
            note: 'cobros conservados',
          ),
          if (voided > 0)
            _RecordMetric(
              value: '$voided',
              label: 'Anulados',
              note: 'excluidos de ingresos',
            ),
          for (final total in record.totalsByCurrency)
            _RecordMetric(
              value: '${total.symbol ?? ''}${total.amount.toStringAsFixed(2)}',
              label: total.code ?? total.currencyId,
              note:
                  '${total.paymentCount} pago${total.paymentCount == 1 ? '' : 's'}',
              emphasis: true,
            ),
        ];
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: constraints.maxWidth < 620
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 24) / 4,
                child: metric,
              ),
            if (record.totalsByCurrency.isEmpty)
              Text(
                'Sin importes cobrados.',
                style: TextStyle(color: tokens.muted),
              ),
          ],
        );
      },
    );
  }
}

class _RecordMetric extends StatelessWidget {
  const _RecordMetric({
    required this.value,
    required this.label,
    required this.note,
    this.emphasis = false,
    this.success = false,
  });

  final String value;
  final String label;
  final String note;
  final bool emphasis;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PulsoFonts.display,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: success
                  ? tokens.success
                  : emphasis
                  ? tokens.accent
                  : tokens.chalk,
            ),
          ),
          Text(label, style: TextStyle(color: tokens.chalkDim, fontSize: 12)),
          Text(
            note,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              color: tokens.muted2,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipBlock extends ConsumerStatefulWidget {
  const _MembershipBlock({required this.membership, required this.client});

  final ClientMembershipRecord membership;
  final ClientRecordIdentity client;

  @override
  ConsumerState<_MembershipBlock> createState() => _MembershipBlockState();
}

class _MembershipBlockState extends ConsumerState<_MembershipBlock> {
  bool _busy = false;

  /// R5.2 — calendario de cuotas de la membresía (si contrató por cuotas).
  List<MembresiaCuotaModel> _cuotas = const [];

  ClientMembershipRecord get membership => widget.membership;
  ClientRecordIdentity get client => widget.client;

  @override
  void initState() {
    super.initState();
    _loadCuotas();
  }

  Future<void> _loadCuotas() async {
    try {
      final cuotas = await ref
          .read(paymentPlanRepositoryProvider)
          .getMembresiaCuotas(membership.id);
      if (mounted && cuotas.isNotEmpty) {
        setState(() => _cuotas = cuotas);
      }
    } catch (_) {
      // Sin cuotas legibles el bloque simplemente no se muestra.
    }
  }

  Future<void> _payCuota(MembresiaCuotaModel cuota) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ProcessPaymentDialog(
        client: ClientModel(
          id: client.id,
          nombres: '${client.firstName} ${client.lastName}'.trim(),
          membershipId: membership.id,
        ),
        planId: membership.planId,
        cuotaNumero: cuota.numeroCuota,
        cuotaImporte: cuota.importe,
      ),
    );
    if (saved == true && mounted) {
      await _loadCuotas();
      await ref.read(clientNotifierProvider.notifier).refresh();
      ref.invalidate(clientRecordProvider(client.id));
    }
  }

  Future<void> _pause() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _PauseMembershipDialog(membership: membership),
    );
    if (reason == null || !mounted) return;
    await _run(
      () => ref
          .read(clientRepositoryProvider)
          .pauseMembership(
            clientId: client.id,
            membershipId: membership.id,
            reason: reason,
          ),
      'Membresía pausada; sus días restantes quedaron protegidos.',
    );
  }

  Future<void> _resume() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ResumeMembershipDialog(membership: membership),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => ref
          .read(clientRepositoryProvider)
          .resumeMembership(clientId: client.id, membershipId: membership.id),
      'Membresía reanudada y nueva fecha final calculada.',
    );
  }

  Future<void> _request(String kind) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) =>
          _MembershipRequestDialog(membership: membership, kind: kind),
    );
    if (reason == null || !mounted) return;
    await _run(
      () => ref
          .read(clientRepositoryProvider)
          .requestMembershipAction(
            clientId: client.id,
            membershipId: membership.id,
            kind: kind,
            reason: reason,
          ),
      'Solicitud enviada a administración; la vigencia aún no cambió.',
    );
    ref.invalidate(membershipRequestsProvider('PENDIENTE'));
    ref.invalidate(membershipRequestsProvider(null));
  }

  Future<void> _reviewRequests() => showDialog<void>(
    context: context,
    builder: (_) => const MembershipRequestsDialog(),
  );

  Future<void> _previewVoluntaryCancellation() async {
    final role = ref.read(authProvider).value?.role.toLowerCase();
    final executed = await showDialog<bool>(
      context: context,
      builder: (_) => VoluntaryCancellationPreviewDialog(
        clientId: client.id,
        membershipId: membership.id,
        canExecute: role == 'admin' || role == 'administrador',
      ),
    );
    if (executed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      await ref.read(clientNotifierProvider.notifier).refresh();
      ref.invalidate(clientRecordProvider(client.id));
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Membresía cancelada y resolución financiera registrada.',
          ),
        ),
      );
    }
  }

  /// R5.4 — cambio de entrenador a petición del cliente: recepción lo ejecuta
  /// sin aprobación previa y administración recibe un aviso automático.
  Future<void> _changeTrainer() async {
    final choice = await showDialog<_TrainerChangeChoice>(
      context: context,
      builder: (_) => _ChangeTrainerDialog(membership: membership),
    );
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(clientRepositoryProvider)
          .changeMembershipTrainer(
            membershipId: membership.id,
            newTrainerId: choice.trainerId,
            reason: choice.reason,
          );
      await ref.read(clientNotifierProvider.notifier).refresh();
      ref.invalidate(clientRecordProvider(client.id));
      final destino = result['entrenador_nuevo'] ?? 'sin entrenador';
      final transferidas = result['cuotas_transferidas'] ?? 0;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Entrenador cambiado a $destino. '
            '$transferidas tramo(s) de comisión transferidos; '
            'administración fue avisada.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo cambiar el entrenador: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() operation, String message) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await operation();
      await ref.read(clientNotifierProvider.notifier).refresh();
      ref.invalidate(clientRecordProvider(client.id));
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo completar la operación: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final role = ref.watch(authProvider).value?.role.toLowerCase();
    final canManage = role == 'admin' || role == 'administrador';
    final canRequest =
        canManage ||
        role == 'recepcion' ||
        role == 'recepción' ||
        role == 'reception' ||
        role == 'recepcionista' ||
        role == 'operador';
    final activePause = membership.pauses
        .where((item) => item.isActive)
        .firstOrNull;
    final pendingRequest = membership.requests
        .where((item) => item.isPending)
        .firstOrNull;
    // El expediente enseñaba el `estado` guardado, y ese estado nunca dice
    // VENCIDA: una membresía con la cobertura terminada seguía apareciendo como
    // ACTIVA en verde. Lo que se enseña ahora es la vigencia derivada de la
    // cobertura (docs/DEMO_MEMBERSHIP_VIGENCIA.md).
    final vigencia = resolveMembershipVigencia(
      status: membership.status,
      endDate: membership.endDate,
      today: todayInZone(appClock.gymTimezone),
    );
    final statusColor = switch (vigencia) {
      MembershipVigencia.current => tokens.success,
      MembershipVigencia.pendingPayment ||
      MembershipVigencia.paused ||
      MembershipVigencia.recentlyExpired => tokens.warning,
      MembershipVigencia.expired ||
      MembershipVigencia.cancelled => tokens.danger,
      MembershipVigencia.none => tokens.muted,
    };
    final currency = membership.currencyCode ?? membership.currencyId;
    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.raised,
              border: Border(left: BorderSide(color: statusColor, width: 5)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      membership.planName,
                      style: TextStyle(
                        color: tokens.chalk,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${_date(membership.startDate)} → ${_date(membership.endDate)} · ${membership.durationDays} días',
                      style: TextStyle(
                        fontFamily: PulsoFonts.mono,
                        color: tokens.muted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                );
                final facts = Wrap(
                  spacing: 18,
                  runSpacing: 6,
                  children: [
                    _Fact(
                      label: 'CONTRATADO',
                      value:
                          '${membership.currencySymbol ?? ''}${membership.price.toStringAsFixed(2)} $currency',
                    ),
                    _Fact(
                      label: 'APLICADO',
                      value:
                          '${membership.paidAmount.toStringAsFixed(2)} $currency',
                    ),
                    _Fact(label: 'ORIGEN', value: membership.origin),
                    _StatusFact(
                      label: membershipVigenciaLabel(vigencia).toUpperCase(),
                      color: statusColor,
                    ),
                  ],
                );
                if (constraints.maxWidth < 700) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 10), facts],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 16),
                    facts,
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canRequest &&
                    (membership.status == 'ACTIVA' ||
                        membership.status == 'PAUSADA')) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: PulsoSecondaryButton(
                      key: ValueKey('membership-action-${membership.id}'),
                      label: _busy
                          ? 'Procesando'
                          : pendingRequest != null
                          ? canManage
                                ? 'Revisar solicitud'
                                : 'Solicitud pendiente'
                          : membership.status == 'ACTIVA'
                          ? canManage
                                ? 'Pausar membresía'
                                : 'Solicitar pausa'
                          : canManage
                          ? 'Reanudar membresía'
                          : 'Solicitar reanudación',
                      icon: membership.status == 'ACTIVA'
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      onPressed: _busy
                          ? null
                          : pendingRequest != null
                          ? canManage
                                ? _reviewRequests
                                : null
                          : membership.status == 'ACTIVA'
                          ? canManage
                                ? _pause
                                : () => _request('PAUSAR')
                          : activePause == null
                          ? null
                          : canManage
                          ? _resume
                          : () => _request('REANUDAR'),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Align(
                    alignment: Alignment.centerRight,
                    child: PulsoSecondaryButton(
                      key: ValueKey(
                        'membership-preview-cancellation-${membership.id}',
                      ),
                      label: canManage
                          ? 'Cancelar membresía'
                          : 'Valorar cancelación',
                      icon: Icons.calculate_outlined,
                      onPressed: _busy ? null : _previewVoluntaryCancellation,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Align(
                    alignment: Alignment.centerRight,
                    child: PulsoSecondaryButton(
                      key: ValueKey(
                        'membership-change-trainer-${membership.id}',
                      ),
                      label: 'Cambiar entrenador',
                      icon: Icons.swap_horiz_outlined,
                      onPressed: _busy ? null : _changeTrainer,
                    ),
                  ),
                  if (pendingRequest != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(
                        '${pendingRequest.kind} solicitado por '
                        '${pendingRequest.requesterName}. La vigencia se '
                        'mantiene igual hasta la decisión administrativa.',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: tokens.warning, fontSize: 10.5),
                      ),
                    ),
                  if (membership.status == 'PAUSADA' && activePause == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(
                        'Esta pausa es anterior al historial de intervalos y requiere revisión administrativa.',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: tokens.warning, fontSize: 10.5),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
                if (membership.reconstructed)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(9),
                    color: tokens.warningSoft,
                    child: Text(
                      'Registro reconstruido · confianza ${membership.reconstructionConfidence ?? 'no especificada'}',
                      style: TextStyle(color: tokens.warning, fontSize: 11),
                    ),
                  ),
                if (membership.pauses.isNotEmpty) ...[
                  const PulsoLabel('PAUSAS DE MEMBRESÍA'),
                  const SizedBox(height: 6),
                  for (final pause in membership.pauses)
                    _MembershipPauseLine(pause: pause),
                  const SizedBox(height: 12),
                ],
                if (membership.requests.isNotEmpty) ...[
                  const PulsoLabel('SOLICITUDES DE VIGENCIA'),
                  const SizedBox(height: 6),
                  for (final request in membership.requests)
                    _MembershipRequestLine(request: request),
                  const SizedBox(height: 12),
                ],
                if (membership.trainers.isNotEmpty) ...[
                  const PulsoLabel('ENTRENADOR ASIGNADO'),
                  const SizedBox(height: 5),
                  for (final trainer in membership.trainers)
                    Column(
                      key: ValueKey('membership-trainer-${trainer.id}'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${trainer.trainerName ?? trainer.trainerId} · ${_date(trainer.startDate)}${trainer.endDate == null ? ' → actual' : ' → ${_date(trainer.endDate!)}'} · ${trainer.status}',
                          style: TextStyle(
                            color: tokens.chalkDim,
                            fontSize: 11.5,
                          ),
                        ),
                        // R5.4 — el motivo de cierre es lo que distingue un
                        // cambio pedido por el socio de una reasignación por
                        // baja del entrenador. Sin enseñarlo, el expediente no
                        // dice por qué dejó de atenderle.
                        if (trainer.closeReason?.trim().isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(left: 10, bottom: 3),
                            child: Text(
                              '↳ ${trainer.closeReason!.trim()}',
                              style: TextStyle(
                                color: tokens.muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 12),
                ],
                if (_cuotas.isNotEmpty) ...[
                  const PulsoLabel('CUOTAS DEL PLAN'),
                  const SizedBox(height: 6),
                  MembresiaCuotasPanel(
                    cuotas: _cuotas,
                    symbol: '',
                    onPayCuota: _busy ? null : _payCuota,
                  ),
                  const SizedBox(height: 12),
                ],
                const PulsoLabel('PAGOS APLICADOS'),
                const SizedBox(height: 5),
                if (membership.payments.isEmpty)
                  Text(
                    'Sin pagos aplicados a esta membresía.',
                    style: TextStyle(color: tokens.muted, fontSize: 11.5),
                  )
                else
                  _ListaAcotada(
                    key: ValueKey('membership-payments-${membership.id}'),
                    filas: membership.payments.length,
                    children: [
                      for (final payment in membership.payments)
                        _PaymentLine(
                          payment: payment,
                          client: client,
                          planName: membership.planName,
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

/// Lista que crece hasta cierto punto y a partir de ahí se desplaza por dentro.
///
/// Regla PULSO: **la tabla scrollea, no la vista**. Un socio con muchos cobros
/// alargaba el expediente hasta empujar los filtros fuera de la pantalla.
class _ListaAcotada extends StatefulWidget {
  const _ListaAcotada({super.key, required this.filas, required this.children});

  final int filas;
  final List<Widget> children;

  /// A partir de aquí la lista deja de crecer y se desplaza por dentro.
  static const int filasSinScroll = 5;
  static const double altoFila = 46;

  @override
  State<_ListaAcotada> createState() => _ListaAcotadaState();
}

class _ListaAcotadaState extends State<_ListaAcotada> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: widget.children,
    );
    if (widget.filas <= _ListaAcotada.filasSinScroll) return contenido;
    return SizedBox(
      height: _ListaAcotada.filasSinScroll * _ListaAcotada.altoFila,
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _controller,
          primary: false,
          child: contenido,
        ),
      ),
    );
  }
}

class _TrainerChangeChoice {
  const _TrainerChangeChoice({required this.trainerId, this.reason});

  /// Nulo = el cliente continúa sin entrenador.
  final String? trainerId;
  final String? reason;
}

/// R5.4 — selector del nuevo entrenador (u opción «sin entrenador») con
/// motivo opcional. El aviso a administración lo emite el servidor.
class _ChangeTrainerDialog extends ConsumerStatefulWidget {
  const _ChangeTrainerDialog({required this.membership});

  final ClientMembershipRecord membership;

  @override
  ConsumerState<_ChangeTrainerDialog> createState() =>
      _ChangeTrainerDialogState();
}

class _ChangeTrainerDialogState extends ConsumerState<_ChangeTrainerDialog> {
  final _reasonController = TextEditingController();
  final _scroll = ScrollController();
  String? _trainerId;
  bool _sinEntrenador = false;

  /// Efecto financiero que devuelve el servidor. Aquí no se calcula dinero:
  /// solo se presenta lo que el endpoint de previsualización responde.
  Map<String, dynamic>? _efecto;
  String? _efectoError;
  bool _calculando = false;
  int _peticion = 0;

  @override
  void dispose() {
    _reasonController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Pide al servidor el reparto que produciría la elección actual.
  ///
  /// Se numera cada petición porque el operador puede cambiar de entrenador
  /// dos veces seguidas: sin el contador, una respuesta lenta de la primera
  /// elección podía pisar a la segunda y enseñar cifras de otro entrenador.
  Future<void> _calcularEfecto() async {
    if (!_sinEntrenador && _trainerId == null) {
      setState(() {
        _efecto = null;
        _efectoError = null;
      });
      return;
    }
    final marca = ++_peticion;
    setState(() {
      _calculando = true;
      _efectoError = null;
    });
    try {
      final resultado = await ref
          .read(clientRepositoryProvider)
          .previewMembershipTrainerChange(
            membershipId: widget.membership.id,
            newTrainerId: _sinEntrenador ? null : _trainerId,
          );
      if (!mounted || marca != _peticion) return;
      setState(() {
        _efecto = resultado;
        _calculando = false;
      });
    } catch (error) {
      if (!mounted || marca != _peticion) return;
      setState(() {
        _efecto = null;
        _efectoError = error.toString().replaceFirst('Exception: ', '');
        _calculando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final trainersAsync = ref.watch(trainerProvider);
    final actual = widget.membership.trainers
        .where((item) => item.endDate == null)
        .firstOrNull;
    final currentTrainerId = actual?.trainerId;
    // Ancho adaptable: el fijo de 420 se desbordaba en compacto (360 px).
    final ancho = math.min(420.0, MediaQuery.sizeOf(context).width - 64);
    return AlertDialog(
      title: const Text('CAMBIAR ENTRENADOR'),
      content: ConstrainedBox(
        // Alto acotado y **barra de scroll siempre visible**: sin ella, el
        // contenido que queda debajo —el motivo, entre otros— no se anuncia, y
        // el operador da por hecho que el diálogo no lo pide. Pasó en el
        // recorrido del 02-08-2026.
        constraints: BoxConstraints(
          maxWidth: ancho > 0 ? ancho : double.infinity,
          maxHeight: math.max(260.0, MediaQuery.sizeOf(context).height - 260),
        ),
        child: Scrollbar(
          key: const ValueKey('change-trainer-scroll'),
          controller: _scroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Recepción ejecuta el cambio sin aprobación previa; '
                  'administración recibe un aviso automático. Lo ya ganado queda '
                  'con el entrenador saliente.',
                  style: TextStyle(color: tokens.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                // Entrenador actual: sin esto el operador elige a ciegas.
                Container(
                  key: const ValueKey('change-trainer-current'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.raised,
                    border: Border.all(color: tokens.line),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 16, color: tokens.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Entrenador actual: '
                          '${actual?.trainerName ?? 'sin entrenador'}',
                          style: TextStyle(color: tokens.chalk, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                trainersAsync.when(
                  loading: () => const LinearProgressIndicator(minHeight: 2),
                  error: (error, _) => Text(
                    'No se pudo cargar el catálogo de entrenadores: $error',
                    style: TextStyle(color: tokens.danger, fontSize: 12),
                  ),
                  data: (trainers) => DropdownButtonFormField<String>(
                    key: const ValueKey('change-trainer-target'),
                    initialValue: _trainerId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Nuevo entrenador',
                      isDense: true,
                    ),
                    items: [
                      for (final trainer in trainers)
                        if (trainer.activo && trainer.id != currentTrainerId)
                          DropdownMenuItem(
                            value: trainer.id,
                            child: Text(
                              '${trainer.nombres ?? ''} ${trainer.apellidos ?? ''}'
                                  .trim(),
                            ),
                          ),
                    ],
                    onChanged: _sinEntrenador
                        ? null
                        : (value) {
                            setState(() => _trainerId = value);
                            _calcularEfecto();
                          },
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  key: const ValueKey('change-trainer-none'),
                  value: _sinEntrenador,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('El cliente continúa sin entrenador'),
                  subtitle: Text(
                    'Los tramos futuros de comisión se anulan.',
                    style: TextStyle(color: tokens.muted, fontSize: 11),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _sinEntrenador = value ?? false;
                      if (_sinEntrenador) _trainerId = null;
                    });
                    _calcularEfecto();
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('change-trainer-reason'),
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Motivo (opcional, llega a administración)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                _EfectoDelCambio(
                  efecto: _efecto,
                  error: _efectoError,
                  calculando: _calculando,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('change-trainer-confirm'),
          onPressed: _sinEntrenador || _trainerId != null
              ? () => Navigator.of(context).pop(
                  _TrainerChangeChoice(
                    trainerId: _sinEntrenador ? null : _trainerId,
                    reason: _reasonController.text,
                  ),
                )
              : null,
          child: const Text('Confirmar cambio'),
        ),
      ],
    );
  }
}

/// R5.4 — efecto financiero del cambio, tal como lo devuelve el servidor.
///
/// **No hace aritmética de dinero.** Recibe las cifras ya calculadas por
/// `/cambiar-entrenador/previsualizacion` y las presenta; la regla del proyecto
/// es que el servidor calcula y Flutter enseña. Si alguien añade aquí una suma,
/// habrá creado una segunda fórmula del reparto.
class _EfectoDelCambio extends StatelessWidget {
  const _EfectoDelCambio({
    required this.efecto,
    required this.error,
    required this.calculando,
  });

  final Map<String, dynamic>? efecto;
  final String? error;
  final bool calculando;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);

    if (calculando) {
      return const Padding(
        key: ValueKey('change-trainer-preview-loading'),
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (error != null) {
      return Container(
        key: const ValueKey('change-trainer-preview-error'),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: tokens.danger.withValues(alpha: 0.08),
          border: Border.all(color: tokens.danger.withValues(alpha: 0.45)),
        ),
        child: Text(
          error!,
          style: TextStyle(color: tokens.chalk, fontSize: 12, height: 1.35),
        ),
      );
    }
    final datos = efecto;
    if (datos == null) {
      return Text(
        'Elige el destino para ver el reparto de la comisión.',
        key: const ValueKey('change-trainer-preview-empty'),
        style: TextStyle(color: tokens.muted, fontSize: 11),
      );
    }

    final sinEntrenador = datos['sin_entrenador'] == true;
    final credito = datos['credito_liberado']?.toString() ?? '0.00';
    return Container(
      key: const ValueKey('change-trainer-preview'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border.all(color: tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PulsoLabel('EFECTO DEL CAMBIO'),
          const SizedBox(height: 6),
          _linea(
            tokens,
            'Tramo ya ganado (queda con el saliente)',
            datos['tramo_ganado']?.toString() ?? '0.00',
          ),
          _linea(
            tokens,
            sinEntrenador
                ? 'Tramo futuro (se anula)'
                : 'Tramo futuro (pasa al entrante)',
            datos['tramo_futuro']?.toString() ?? '0.00',
          ),
          if (sinEntrenador && credito != '0.00')
            _linea(tokens, 'Crédito liberado al socio', credito),
          const SizedBox(height: 6),
          Text(
            'Efectivo desde ${datos['fecha_efectiva'] ?? '—'} · '
            '${datos['cuotas_transferibles'] ?? 0} cuota(s) a transferir · '
            '${datos['cuotas_anulables'] ?? 0} a anular.',
            style: TextStyle(color: tokens.muted, fontSize: 11, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _linea(PulsoTokens tokens, String etiqueta, String importe) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            etiqueta,
            style: TextStyle(color: tokens.muted, fontSize: 11),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          importe,
          style: TextStyle(
            color: tokens.chalk,
            fontFamily: PulsoFonts.mono,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class _MembershipPauseLine extends StatelessWidget {
  const _MembershipPauseLine({required this.pause});

  final ClientMembershipPause pause;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = pause.isActive ? tokens.warning : tokens.success;
    final period = pause.resumeDate == null
        ? 'desde ${_date(pause.pauseDate)}'
        : '${_date(pause.pauseDate)} → ${_date(pause.resumeDate!)}';
    final endNote = pause.recalculatedEndDate == null
        ? 'vencimiento congelado: ${_date(pause.previousEndDate)}'
        : 'nuevo vencimiento: ${_date(pause.recalculatedEndDate!)}';
    return Container(
      key: ValueKey('membership-pause-${pause.id}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: tokens.isDark ? 0.10 : 0.07),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${pause.isActive ? 'EN PAUSA' : pause.status} · $period · '
            '${pause.remainingDays} días conservados',
            style: TextStyle(
              color: color,
              fontFamily: PulsoFonts.mono,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${pause.reason} · $endNote',
            style: TextStyle(color: tokens.chalkDim, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MembershipRequestLine extends StatelessWidget {
  const _MembershipRequestLine({required this.request});

  final ClientMembershipRequest request;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = switch (request.status) {
      'PENDIENTE' => tokens.warning,
      'APROBADA' => tokens.success,
      'RECHAZADA' => tokens.danger,
      _ => tokens.muted,
    };
    final requestedAt = toGymWallClock(
      request.requestedAt,
      appClock.gymTimezone,
    );
    return Container(
      key: ValueKey('membership-request-history-${request.id}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: tokens.isDark ? 0.10 : 0.07),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${request.kind} · ${request.status} · '
            '${request.estimatedRemainingDays} días estimados',
            style: TextStyle(
              color: color,
              fontFamily: PulsoFonts.mono,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${request.reason} · ${request.requesterName} · '
            '${DateFormat('dd/MM/yyyy HH:mm').format(requestedAt)}',
            style: TextStyle(color: tokens.chalkDim, fontSize: 11),
          ),
          if (request.deciderName != null)
            Text(
              'Decidió ${request.deciderName}'
              '${request.decisionReason == null ? '' : ' · ${request.decisionReason}'}',
              style: TextStyle(color: tokens.muted, fontSize: 10.5),
            ),
        ],
      ),
    );
  }
}

class _MembershipRequestDialog extends StatefulWidget {
  const _MembershipRequestDialog({
    required this.membership,
    required this.kind,
  });

  final ClientMembershipRecord membership;
  final String kind;

  @override
  State<_MembershipRequestDialog> createState() =>
      _MembershipRequestDialogState();
}

class _MembershipRequestDialogState extends State<_MembershipRequestDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPause = widget.kind == 'PAUSAR';
    final activePause = widget.membership.pauses
        .where((item) => item.isActive)
        .firstOrNull;
    return PulsoThemeScope(
      child: Builder(
        builder: (context) {
          final tokens = PulsoTokens.of(context);
          return Dialog(
            insetPadding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: PulsoPanel(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PulsoLabel('MEMBRESÍA · SOLICITUD A ADMINISTRACIÓN'),
                    const SizedBox(height: 5),
                    Text(
                      isPause ? 'SOLICITAR PAUSA' : 'SOLICITAR REANUDACIÓN',
                      style: TextStyle(
                        fontFamily: PulsoFonts.display,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: tokens.chalk,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isPause
                          ? 'Administración verá una estimación de los días '
                                'restantes. La membresía seguirá activa hasta '
                                'que otra cuenta apruebe la solicitud.'
                          : '${activePause?.remainingDays ?? 0} días están '
                                'congelados. Seguirán así hasta que otra cuenta '
                                'administrativa apruebe la reanudación.',
                      style: TextStyle(color: tokens.chalkDim, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('membership-request-reason'),
                      controller: _reason,
                      autofocus: true,
                      maxLines: 3,
                      maxLength: 240,
                      decoration: InputDecoration(
                        labelText: isPause
                            ? 'Motivo de la pausa'
                            : 'Motivo de la reanudación',
                        hintText: isPause
                            ? 'Viaje, indicación médica, ausencia temporal…'
                            : 'Regresó antes, alta médica, fin de ausencia…',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        PulsoSecondaryButton(
                          label: 'Cancelar',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        PulsoPrimaryButton(
                          label: 'Enviar solicitud',
                          icon: Icons.send_outlined,
                          onPressed: _reason.text.trim().length < 5
                              ? null
                              : () => Navigator.of(
                                  context,
                                ).pop(_reason.text.trim()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PauseMembershipDialog extends StatefulWidget {
  const _PauseMembershipDialog({required this.membership});

  final ClientMembershipRecord membership;

  @override
  State<_PauseMembershipDialog> createState() => _PauseMembershipDialogState();
}

class _PauseMembershipDialogState extends State<_PauseMembershipDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _confirm() {
    final reason = _reason.text.trim();
    if (reason.length < 5) {
      setState(() => _error = 'Describe el motivo con al menos 5 caracteres.');
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return PulsoThemeScope(
      child: Builder(
        builder: (context) {
          final tokens = PulsoTokens.of(context);
          return Dialog(
            insetPadding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: PulsoPanel(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PulsoLabel('MEMBRESÍA · OPERACIÓN PROTEGIDA'),
                    const SizedBox(height: 5),
                    Text(
                      'PAUSAR SERVICIO',
                      style: TextStyle(
                        fontFamily: PulsoFonts.display,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: tokens.chalk,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${widget.membership.planName}\n'
                      '${_date(widget.membership.startDate)} → '
                      '${_date(widget.membership.endDate)}',
                      style: TextStyle(color: tokens.chalkDim, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      key: const ValueKey('membership-pause-reason'),
                      controller: _reason,
                      minLines: 3,
                      maxLines: 5,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Motivo administrativo',
                        hintText: 'Viaje, indicación médica u otra causa…',
                        errorText: _error,
                      ),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'La fecha efectiva será el día comercial actual del gimnasio. '
                      'Los días sin consumir quedarán congelados.',
                      style: TextStyle(
                        color: tokens.muted,
                        fontFamily: PulsoFonts.mono,
                        fontSize: 9.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        PulsoSecondaryButton(
                          label: 'Cancelar',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        PulsoPrimaryButton(
                          label: 'Confirmar pausa',
                          icon: Icons.pause_circle_outline,
                          onPressed: _confirm,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ResumeMembershipDialog extends StatelessWidget {
  const _ResumeMembershipDialog({required this.membership});

  final ClientMembershipRecord membership;

  @override
  Widget build(BuildContext context) {
    final pause = membership.pauses.where((item) => item.isActive).firstOrNull;
    return PulsoThemeScope(
      child: Builder(
        builder: (context) {
          final tokens = PulsoTokens.of(context);
          return Dialog(
            insetPadding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: PulsoPanel(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PulsoLabel('MEMBRESÍA · OPERACIÓN PROTEGIDA'),
                    const SizedBox(height: 5),
                    Text(
                      'REANUDAR SERVICIO',
                      style: TextStyle(
                        fontFamily: PulsoFonts.display,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: tokens.chalk,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      pause == null
                          ? 'No existe un intervalo activo para reanudar.'
                          : '${pause.remainingDays} días de servicio volverán a '
                                'contar desde el día comercial actual. La nueva '
                                'fecha final la calculará el servidor.',
                      style: TextStyle(color: tokens.chalkDim, fontSize: 12),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        PulsoSecondaryButton(
                          label: 'Cancelar',
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                        PulsoPrimaryButton(
                          label: 'Reanudar',
                          icon: Icons.play_circle_outline,
                          onPressed: pause == null
                              ? null
                              : () => Navigator.of(context).pop(true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PaymentLine extends StatelessWidget {
  const _PaymentLine({
    required this.payment,
    required this.client,
    required this.planName,
  });

  final ClientRecordPayment payment;
  final ClientRecordIdentity client;
  final String planName;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final instant = toGymWallClock(payment.date, appClock.gymTimezone);
    final color = payment.isVoided ? tokens.danger : tokens.chalk;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('record-payment-${payment.id}'),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => _ClientPaymentReceiptDialog(
              payment: payment,
              client: client,
              planName: planName,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  payment.isVoided
                      ? Icons.block_outlined
                      : Icons.receipt_long_outlined,
                  size: 17,
                  color: payment.isVoided ? tokens.danger : tokens.accent,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('dd/MM/yyyy · HH:mm').format(instant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.chalkDim,
                          fontSize: 11.5,
                        ),
                      ),
                      Text(
                        payment.isVoided
                            ? 'ANULADO · VER RECIBO'
                            : 'VER RECIBO',
                        style: TextStyle(
                          color: payment.isVoided
                              ? tokens.danger
                              : tokens.muted2,
                          fontFamily: PulsoFonts.mono,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${payment.currencySymbol ?? ''}${(payment.appliedAmount ?? payment.total).toStringAsFixed(2)} ${payment.currencyCode ?? payment.currencyId}',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontWeight: FontWeight.w700,
                    color: color,
                    decoration: payment.isVoided
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(width: 5),
                Icon(Icons.chevron_right, size: 17, color: tokens.muted2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientPaymentReceiptDialog extends StatelessWidget {
  const _ClientPaymentReceiptDialog({
    required this.payment,
    required this.client,
    required this.planName,
  });

  final ClientRecordPayment payment;
  final ClientRecordIdentity client;
  final String planName;

  String _currencyCode(String? id) {
    if (id == payment.currencyId) {
      return payment.currencyCode ?? payment.currencyId;
    }
    for (final detail in payment.details) {
      if (detail.currencyId == id) {
        return detail.currencyCode ?? detail.currencyId;
      }
    }
    return id ?? '—';
  }

  String _rateText(ClientRecordPaymentDetail detail) {
    if (detail.exchangeRate == null) return 'misma moneda · tasa 1:1';
    return '1 ${_currencyCode(detail.exchangeRateBaseCurrencyId)} = '
        '${detail.exchangeRate!.toStringAsFixed(4)} '
        '${_currencyCode(detail.exchangeRateTargetCurrencyId)}';
  }

  String _detailAmount(ClientRecordPaymentDetail detail) {
    final cents = double.parse(detail.amount.toStringAsFixed(2));
    final decimals = (detail.amount - cents).abs() > 0.00001 ? 4 : 2;
    return '${detail.currencySymbol ?? ''}${detail.amount.toStringAsFixed(decimals)} '
        '${detail.currencyCode ?? detail.currencyId}';
  }

  Future<void> _copyReceipt(BuildContext context) async {
    final when = toGymWallClock(payment.date, appClock.gymTimezone);
    final lines = [
      'RECIBO · ${payment.id}',
      client.fullName,
      'CI ${client.id}',
      // H3: concepto con código + sufijo.
      '${payment.planCode ?? planName}${payment.installmentSuffix ?? ''}',
      DateFormat('dd/MM/yyyy HH:mm').format(when),
      // H5: cobrador.
      if (payment.collectorName != null)
        'Cobrado por: ${payment.collectorName}'
            '${payment.collectorRole == null ? '' : ' · ${payment.collectorRole}'}',
      // H1: descuento congelado.
      if (payment.listPrice != null)
        'Lista − descuento: ${payment.listPrice!.toStringAsFixed(2)} − '
            '${(payment.discountAmount ?? 0).toStringAsFixed(2)}'
            '${payment.discountPct == null ? '' : ' (${payment.discountPct}%)'}',
      'Estado: ${payment.isVoided ? 'ANULADO' : 'PAGADO'}',
      'Total: ${payment.total.toStringAsFixed(2)} '
          '${payment.currencyCode ?? payment.currencyId}',
      for (final detail in payment.details)
        '${detail.paymentTypeName ?? 'Sin clasificar'} · '
            '${_detailAmount(detail)} · '
            '${detail.accountName ?? 'sin cuenta'} · ${_rateText(detail)}',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Recibo copiado.')));
  }

  @override
  Widget build(BuildContext context) {
    return PulsoThemeScope(
      child: Builder(
        builder: (context) {
          final tokens = PulsoTokens.of(context);
          final when = toGymWallClock(payment.date, appClock.gymTimezone);
          final statusColor = payment.isVoided ? tokens.danger : tokens.success;
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640, maxHeight: 740),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(height: 5, color: statusColor),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const PulsoLabel('EXPEDIENTE · RECIBO'),
                                    const SizedBox(height: 4),
                                    Text(
                                      payment.isVoided
                                          ? 'PAGO ANULADO'
                                          : 'PAGO CONFIRMADO',
                                      key: const ValueKey(
                                        'record-receipt-status',
                                      ),
                                      style: TextStyle(
                                        fontFamily: PulsoFonts.display,
                                        fontSize: 25,
                                        fontWeight: FontWeight.w900,
                                        color: statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PulsoIconButton(
                                tooltip: 'Cerrar recibo',
                                icon: Icons.close,
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            '${payment.currencySymbol ?? ''}${payment.total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontFamily: PulsoFonts.display,
                              fontSize: 48,
                              height: 0.95,
                              fontWeight: FontWeight.w900,
                              color: payment.isVoided
                                  ? tokens.muted
                                  : tokens.accent,
                              decoration: payment.isVoided
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          Text(
                            payment.currencyCode ?? payment.currencyId,
                            style: TextStyle(
                              fontFamily: PulsoFonts.mono,
                              color: tokens.muted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _ReceiptFact(label: 'SOCIO', value: client.fullName),
                          _ReceiptFact(label: 'CI', value: client.id),
                          // H3: el concepto lleva código de plan + sufijo de
                          // cuota, igual que en el panel de pagos. Antes solo
                          // mostraba el nombre del plan.
                          _ReceiptFact(
                            label: 'CONCEPTO',
                            value:
                                '${payment.planCode ?? planName}'
                                '${payment.installmentSuffix ?? ''}',
                          ),
                          _ReceiptFact(
                            label: 'FECHA DEL GIMNASIO',
                            value: DateFormat(
                              'dd/MM/yyyy · HH:mm',
                            ).format(when),
                          ),
                          // H5: quién cobró (R5.6). Los cobros anteriores al
                          // corte no tienen cobrador: se enseña «histórico».
                          _ReceiptFact(
                            label: 'COBRADO POR',
                            value: payment.collectorName == null
                                ? 'Sin atribuir · histórico'
                                : '${payment.collectorName}'
                                      '${payment.collectorRole == null ? '' : ' · ${payment.collectorRole}'}',
                          ),
                          // H1: desglose del descuento congelado al cobrar. Se
                          // muestra la instantánea, nunca la política de hoy.
                          if (payment.listPrice != null)
                            _ReceiptFact(
                              label: 'LISTA − DESCUENTO',
                              value:
                                  '${payment.currencySymbol ?? ''}${payment.listPrice!.toStringAsFixed(2)}'
                                  ' − ${payment.currencySymbol ?? ''}${(payment.discountAmount ?? 0).toStringAsFixed(2)}'
                                  '${payment.discountPct == null ? '' : ' (${payment.discountPct}%)'}',
                            ),
                          const SizedBox(height: 18),
                          const PulsoLabel('DESGLOSE DEL COBRO'),
                          const SizedBox(height: 6),
                          if (payment.details.isEmpty)
                            PulsoPanel(
                              padding: const EdgeInsets.all(14),
                              color: tokens.floor2,
                              child: Text(
                                payment.isVoided
                                    ? 'El detalle económico fue anulado junto con el cobro.'
                                    : 'Este pago histórico no conserva formas de pago detalladas.',
                                style: TextStyle(
                                  color: tokens.muted,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          else
                            for (final detail in payment.details)
                              _RecordReceiptDetail(
                                detail: detail,
                                amount: _detailAmount(detail),
                                rate: _rateText(detail),
                              ),
                          const SizedBox(height: 18),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              PulsoSecondaryButton(
                                label: 'Copiar recibo',
                                icon: Icons.content_copy_outlined,
                                onPressed: () => _copyReceipt(context),
                              ),
                              PulsoPrimaryButton(
                                label: 'Cerrar',
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            payment.id,
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
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReceiptFact extends StatelessWidget {
  const _ReceiptFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final labelWidget = PulsoLabel(
      label,
      key: ValueKey('receipt-fact-label-$label'),
    );
    final valueWidget = Text(
      value,
      key: ValueKey('receipt-fact-value-$label'),
      textAlign: TextAlign.right,
      style: TextStyle(
        color: tokens.chalkDim,
        fontFamily: PulsoFonts.mono,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: MediaQuery.sizeOf(context).width < 500
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: 5),
                Align(alignment: Alignment.centerLeft, child: valueWidget),
              ],
            )
          : Row(
              children: [
                Expanded(child: labelWidget),
                Flexible(flex: 2, child: valueWidget),
              ],
            ),
    );
  }
}

class _RecordReceiptDetail extends StatelessWidget {
  const _RecordReceiptDetail({
    required this.detail,
    required this.amount,
    required this.rate,
  });

  final ClientRecordPaymentDetail detail;
  final String amount;
  final String rate;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.lineStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  detail.paymentTypeName ?? 'Sin clasificar',
                  style: TextStyle(
                    color: tokens.chalk,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                amount,
                style: TextStyle(
                  color: tokens.chalk,
                  fontFamily: PulsoFonts.mono,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${detail.accountName ?? 'sin cuenta'} · $rate',
            style: TextStyle(
              color: tokens.muted,
              fontFamily: PulsoFonts.mono,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PulsoLabel(label),
        Text(
          value,
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            color: tokens.chalkDim,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _StatusFact extends StatelessWidget {
  const _StatusFact({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(border: Border.all(color: color)),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: PulsoFonts.mono,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

String _date(DateTime value) => DateFormat('dd/MM/yyyy').format(value);
