import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../auth/presentation/state/auth_notifier.dart';
import '../../data/models/client_record_model.dart';
import '../../data/repositories/client_repository.dart';
import '../state/client_notifier.dart';
import '../state/client_record_provider.dart';

class MembershipRequestsDialog extends ConsumerStatefulWidget {
  const MembershipRequestsDialog({super.key});

  @override
  ConsumerState<MembershipRequestsDialog> createState() =>
      _MembershipRequestsDialogState();
}

class _MembershipRequestsDialogState
    extends ConsumerState<MembershipRequestsDialog> {
  String? _state = 'PENDIENTE';
  String? _busyId;

  bool get _isAdmin {
    final role = ref.read(authProvider).value?.role.toLowerCase();
    return role == 'admin' || role == 'administrador';
  }

  Future<void> _approve(ClientMembershipRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ApproveRequestDialog(request: request),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      request,
      () => ref
          .read(clientRepositoryProvider)
          .approveMembershipRequest(request.id),
      'Solicitud aprobada y vigencia recalculada.',
    );
  }

  Future<void> _reject(ClientMembershipRequest request) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectRequestDialog(),
    );
    if (reason == null || !mounted) return;
    await _run(
      request,
      () => ref
          .read(clientRepositoryProvider)
          .rejectMembershipRequest(requestId: request.id, reason: reason),
      'Solicitud rechazada; la vigencia no cambió.',
    );
  }

  Future<void> _run(
    ClientMembershipRequest request,
    Future<void> Function() operation,
    String message,
  ) async {
    setState(() => _busyId = request.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await operation();
      ref.invalidate(membershipRequestsProvider('PENDIENTE'));
      ref.invalidate(membershipRequestsProvider(null));
      ref.invalidate(clientRecordProvider(request.clientId));
      await ref.read(clientNotifierProvider.notifier).refresh();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo decidir la solicitud: $error')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(membershipRequestsProvider(_state));
    final user = ref.watch(authProvider).value;
    return PulsoThemeScope(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tokens = PulsoTokens.of(context);
          final width = (constraints.maxWidth - 32).clamp(320.0, 980.0);
          final height = (constraints.maxHeight - 32).clamp(480.0, 760.0);
          return Center(
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                key: const ValueKey('membership-requests-dialog'),
                width: width,
                height: height,
                child: PulsoPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(22, 16, 12, 14),
                        color: tokens.raised,
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 42,
                              color: tokens.accent,
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  PulsoLabel(
                                    _isAdmin
                                        ? 'MEMBRESÍAS · CONTROL ADMINISTRATIVO'
                                        : 'MEMBRESÍAS · SEGUIMIENTO',
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _isAdmin
                                        ? 'SOLICITUDES DE VIGENCIA'
                                        : 'MIS SOLICITUDES',
                                    style: TextStyle(
                                      fontFamily: PulsoFonts.display,
                                      fontSize: 24,
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
                                membershipRequestsProvider(_state),
                              ),
                            ),
                            PulsoIconButton(
                              tooltip: 'Cerrar',
                              icon: Icons.close,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: tokens.line),
                          ),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _QueueFilter(
                              label: 'Pendientes',
                              selected: _state == 'PENDIENTE',
                              onTap: () => setState(() => _state = 'PENDIENTE'),
                            ),
                            _QueueFilter(
                              label: 'Historial',
                              selected: _state == null,
                              onTap: () => setState(() => _state = null),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: requests.when(
                          loading: () => const PulsoStateView(
                            kind: PulsoStateKind.loading,
                            message: 'Consultando solicitudes…',
                          ),
                          error: (error, _) => PulsoStateView(
                            kind: PulsoStateKind.error,
                            message:
                                'No se pudieron cargar las solicitudes.\n$error',
                            onRetry: () => ref.invalidate(
                              membershipRequestsProvider(_state),
                            ),
                          ),
                          data: (items) => items.isEmpty
                              ? PulsoStateView(
                                  kind: PulsoStateKind.empty,
                                  message: _state == 'PENDIENTE'
                                      ? 'No hay solicitudes pendientes.'
                                      : 'Todavía no existe historial de solicitudes.',
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    22,
                                    12,
                                    22,
                                    22,
                                  ),
                                  itemCount: items.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (_, index) => _RequestLine(
                                    request: items[index],
                                    isAdmin: _isAdmin,
                                    isOwn:
                                        user?.id ==
                                        items[index].requesterUserId,
                                    busy: _busyId == items[index].id,
                                    onApprove: () => _approve(items[index]),
                                    onReject: () => _reject(items[index]),
                                  ),
                                ),
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
}

class _QueueFilter extends StatelessWidget {
  const _QueueFilter({
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? tokens.accentSoft : Colors.transparent,
          border: Border.all(
            color: selected ? tokens.accent : tokens.lineStrong,
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            color: selected ? tokens.accent : tokens.muted,
          ),
        ),
      ),
    );
  }
}

class _RequestLine extends StatelessWidget {
  const _RequestLine({
    required this.request,
    required this.isAdmin,
    required this.isOwn,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final ClientMembershipRequest request;
  final bool isAdmin;
  final bool isOwn;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = switch (request.status) {
      'PENDIENTE' => tokens.warning,
      'APROBADA' => tokens.success,
      'RECHAZADA' => tokens.danger,
      _ => tokens.muted,
    };
    final estimatedEnd = request.estimatedEndDate == null
        ? '—'
        : DateFormat('dd/MM/yyyy').format(request.estimatedEndDate!);
    return Container(
      key: ValueKey('membership-request-${request.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.floor2,
        border: Border(
          left: BorderSide(color: color, width: 4),
          top: BorderSide(color: tokens.line),
          right: BorderSide(color: tokens.line),
          bottom: BorderSide(color: tokens.line),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final information = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (request.clientName ?? 'CI ${request.clientId}')
                          .toUpperCase(),
                      style: TextStyle(
                        color: tokens.chalk,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    request.status,
                    style: TextStyle(
                      color: color,
                      fontFamily: PulsoFonts.mono,
                      fontWeight: FontWeight.w800,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${request.kind} · ${request.planName ?? 'membresía'} · '
                '${request.estimatedRemainingDays} días · fin estimado $estimatedEnd',
                style: TextStyle(
                  color: tokens.chalkDim,
                  fontFamily: PulsoFonts.mono,
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(request.reason, style: TextStyle(color: tokens.chalkDim)),
              const SizedBox(height: 5),
              Text(
                'Solicitó ${request.requesterName} · '
                '${DateFormat('dd/MM/yyyy HH:mm').format(toGymWallClock(request.requestedAt, appClock.gymTimezone))}',
                style: TextStyle(color: tokens.muted, fontSize: 10.5),
              ),
              if (request.deciderName != null) ...[
                const SizedBox(height: 3),
                Text(
                  'Decidió ${request.deciderName}'
                  '${request.decisionReason == null ? '' : ' · ${request.decisionReason}'}',
                  style: TextStyle(color: tokens.muted2, fontSize: 10.5),
                ),
              ],
              if (isOwn && request.isPending && isAdmin) ...[
                const SizedBox(height: 6),
                Text(
                  'Requiere otra cuenta administrativa para decidir.',
                  style: TextStyle(color: tokens.warning, fontSize: 10.5),
                ),
              ],
            ],
          );
          final actions = request.isPending && isAdmin
              ? Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  alignment: WrapAlignment.end,
                  children: [
                    PulsoSecondaryButton(
                      label: 'Rechazar',
                      icon: Icons.close,
                      onPressed: busy || isOwn ? null : onReject,
                    ),
                    PulsoPrimaryButton(
                      label: busy ? 'Procesando' : 'Aprobar',
                      icon: Icons.check,
                      onPressed: busy || isOwn ? null : onApprove,
                    ),
                  ],
                )
              : const SizedBox.shrink();
          if (constraints.maxWidth < 700) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                information,
                if (request.isPending && isAdmin) ...[
                  const SizedBox(height: 12),
                  actions,
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: information),
              if (request.isPending && isAdmin) ...[
                const SizedBox(width: 18),
                actions,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ApproveRequestDialog extends StatelessWidget {
  const _ApproveRequestDialog({required this.request});

  final ClientMembershipRequest request;

  @override
  Widget build(BuildContext context) {
    final action = request.isPause ? 'pausa' : 'reanudación';
    return AlertDialog(
      title: Text('Aprobar $action'),
      content: Text(
        'La operación se aplicará usando el día comercial actual del gimnasio. '
        'No será retroactiva a la fecha en que recepción la solicitó.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Aprobar'),
        ),
      ],
    );
  }
}

class _RejectRequestDialog extends StatefulWidget {
  const _RejectRequestDialog();

  @override
  State<_RejectRequestDialog> createState() => _RejectRequestDialogState();
}

class _RejectRequestDialogState extends State<_RejectRequestDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rechazar solicitud'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        maxLength: 240,
        decoration: const InputDecoration(
          labelText: 'Motivo administrativo',
          hintText: 'Explique por qué no se autoriza…',
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _controller.text.trim().length < 5
              ? null
              : () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Rechazar'),
        ),
      ],
    );
  }
}
