import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/repositories/client_repository.dart';

/// R5.4 — bandeja de avisos informativos para administración (cambios de
/// entrenador y hechos que antes viajaban por WhatsApp). Solo lectura: la
/// futura app móvil del administrador consumirá la misma cola.
class AdminNoticesDialog extends ConsumerStatefulWidget {
  const AdminNoticesDialog({super.key});

  @override
  ConsumerState<AdminNoticesDialog> createState() => _AdminNoticesDialogState();
}

class _AdminNoticesDialogState extends ConsumerState<AdminNoticesDialog> {
  late Future<List<Map<String, dynamic>>> _notices;

  @override
  void initState() {
    super.initState();
    _notices = ref.read(clientRepositoryProvider).getAdminNotices();
  }

  Future<void> _markAllRead() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final marked = await ref
          .read(clientRepositoryProvider)
          .markAdminNoticesRead();
      if (!mounted) return;
      setState(() {
        _notices = ref.read(clientRepositoryProvider).getAdminNotices();
      });
      messenger.showSnackBar(
        SnackBar(content: Text('$marked aviso(s) marcados como leídos.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudieron marcar los avisos: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PulsoThemeScope(
      child: Builder(
        builder: (context) {
          final tokens = PulsoTokens.of(context);
          final screen = MediaQuery.sizeOf(context);
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 640,
                maxHeight: screen.height - 48,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(height: 4, color: tokens.accent),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 16, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const PulsoLabel('PULSO · ADMINISTRACIÓN'),
                              const SizedBox(height: 8),
                              Text(
                                'AVISOS',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Cambios ejecutados por recepción que no '
                                'requieren aprobación, para seguimiento.',
                                style: TextStyle(
                                  color: tokens.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PulsoIconButton(
                          key: const ValueKey('admin-notices-mark-read'),
                          icon: Icons.done_all_outlined,
                          tooltip: 'Marcar todo como leído',
                          onPressed: _markAllRead,
                        ),
                        PulsoIconButton(
                          icon: Icons.close,
                          tooltip: 'Cerrar',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: tokens.line),
                  Flexible(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _notices,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const PulsoStateView(
                            kind: PulsoStateKind.loading,
                            message: 'Cargando avisos…',
                          );
                        }
                        if (snapshot.hasError) {
                          return PulsoStateView(
                            kind: PulsoStateKind.error,
                            message:
                                'No se pudieron cargar los avisos.\n${snapshot.error}',
                            onRetry: () => setState(() {
                              _notices = ref
                                  .read(clientRepositoryProvider)
                                  .getAdminNotices();
                            }),
                          );
                        }
                        final notices = snapshot.data ?? const [];
                        if (notices.isEmpty) {
                          return const PulsoStateView(
                            kind: PulsoStateKind.empty,
                            message:
                                'Sin avisos: ningún cambio informativo registrado.',
                          );
                        }
                        return ListView.separated(
                          key: const Key('admin-notices-list'),
                          padding: const EdgeInsets.all(12),
                          itemCount: notices.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, index) =>
                              _NoticeRow(notice: notices[index]),
                        );
                      },
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

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.notice});

  final Map<String, dynamic> notice;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final unread = notice['leido'] != true && notice['leido'] != 1;
    final createdAt = DateTime.tryParse('${notice['created_at']}');
    final tipo = '${notice['tipo'] ?? 'AVISO'}'.replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border(
          left: BorderSide(
            color: unread ? tokens.accent : tokens.line,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tipo,
                style: TextStyle(
                  color: unread ? tokens.accent : tokens.muted,
                  fontFamily: PulsoFonts.mono,
                  fontSize: 9,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (createdAt != null)
                Text(
                  '${createdAt.toLocal()}'.substring(0, 16),
                  style: TextStyle(
                    color: tokens.muted2,
                    fontFamily: PulsoFonts.mono,
                    fontSize: 9,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${notice['mensaje'] ?? ''}',
            style: TextStyle(color: tokens.chalk, fontSize: 12.5),
          ),
          if ('${notice['actor_nombre'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              'Ejecutado por ${notice['actor_nombre']}',
              style: TextStyle(color: tokens.chalkDim, fontSize: 10.5),
            ),
          ],
        ],
      ),
    );
  }
}
