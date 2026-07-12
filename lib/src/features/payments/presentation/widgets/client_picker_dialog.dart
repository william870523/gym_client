import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/base64_image.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../clients/data/models/client_model.dart';
import '../../../clients/presentation/state/client_notifier.dart';
import '../../../clients/presentation/widgets/client_form.dart';

class ClientPickerDialog extends ConsumerStatefulWidget {
  const ClientPickerDialog({super.key});

  @override
  ConsumerState<ClientPickerDialog> createState() => _ClientPickerDialogState();
}

class _ClientPickerDialogState extends ConsumerState<ClientPickerDialog> {
  String _query = '';

  Future<void> _assignPlan(ClientModel client) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PulsoThemeScope(child: ClientForm(client: client)),
    );
    if (mounted) {
      await ref.read(clientNotifierProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PulsoThemeScope(
      child: Builder(
        builder: (context) {
          final t = PulsoTokens.of(context);
          final size = MediaQuery.sizeOf(context);
          final dialogHeight = math.min(
            720.0,
            math.max(420.0, size.height * 0.78),
          );
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 40,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 620,
                maxHeight: math.min(dialogHeight, size.height - 80),
              ),
              child: PulsoPanel(
                key: const ValueKey('pulso-client-picker'),
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const PulsoLabel('NUEVO COBRO · PASO 1'),
                                const SizedBox(height: 3),
                                Text(
                                  'SELECCIONAR SOCIO',
                                  style: TextStyle(
                                    fontFamily: PulsoFonts.display,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    color: t.chalk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PulsoIconButton(
                            icon: Icons.close,
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: t.lineStrong),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        key: const ValueKey('payment-client-search'),
                        autofocus: true,
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Nombre o cédula',
                          labelText: 'Buscar socio',
                        ),
                      ),
                    ),
                    Expanded(child: _results(t)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _results(PulsoTokens t) {
    return ref
        .watch(clientNotifierProvider)
        .when(
          loading: () =>
              Center(child: CircularProgressIndicator(color: t.accent)),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No se pudieron cargar los socios',
                style: TextStyle(color: t.danger),
              ),
            ),
          ),
          data: (clients) {
            final filtered =
                clients.where((client) {
                  final name =
                      '${client.nombres ?? ''} ${client.apellidos ?? ''}'
                          .toLowerCase();
                  return _query.isEmpty ||
                      name.contains(_query) ||
                      client.id.toLowerCase().contains(_query);
                }).toList()..sort((left, right) {
                  final leftReady = left.planId?.trim().isNotEmpty == true;
                  final rightReady = right.planId?.trim().isNotEmpty == true;
                  if (leftReady != rightReady) return leftReady ? -1 : 1;
                  final leftName =
                      '${left.nombres ?? ''} ${left.apellidos ?? ''}';
                  final rightName =
                      '${right.nombres ?? ''} ${right.apellidos ?? ''}';
                  return leftName.compareTo(rightName);
                });
            if (filtered.isEmpty) {
              return Center(
                child: Text(
                  'No se encontraron socios',
                  style: TextStyle(fontFamily: PulsoFonts.mono, color: t.muted),
                ),
              );
            }
            final ready = filtered
                .where((client) => client.planId?.trim().isNotEmpty == true)
                .length;
            final withoutPlan = filtered.length - ready;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Text(
                    '$ready ${ready == 1 ? 'listo' : 'listos'} para cobrar · '
                    '$withoutPlan sin plan',
                    key: const ValueKey('payment-client-summary'),
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 10.5,
                      color: t.muted,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: t.line),
                    itemBuilder: (context, index) {
                      final client = filtered[index];
                      final readyToPay =
                          client.planId?.trim().isNotEmpty == true;
                      return _ClientRow(
                        client: client,
                        readyToPay: readyToPay,
                        onTap: readyToPay
                            ? () => Navigator.pop(context, client)
                            : null,
                        onAssignPlan: readyToPay
                            ? null
                            : () => _assignPlan(client),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
  }
}

class _ClientRow extends StatelessWidget {
  const _ClientRow({
    required this.client,
    required this.readyToPay,
    required this.onTap,
    required this.onAssignPlan,
  });
  final ClientModel client;
  final bool readyToPay;
  final VoidCallback? onTap;
  final VoidCallback? onAssignPlan;

  @override
  Widget build(BuildContext context) {
    final t = PulsoTokens.of(context);
    final name = '${client.nombres ?? ''} ${client.apellidos ?? ''}'.trim();
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final photo = client.photoUrl;
    final placeholder = Center(
      child: Text(
        initial,
        style: TextStyle(fontWeight: FontWeight.w800, color: t.chalk),
      ),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              ClipRect(
                child: ColoredBox(
                  color: t.raised2,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: photo?.trim().isNotEmpty == true
                        ? Base64Image(
                            base64String: photo!,
                            width: 44,
                            height: 44,
                            placeholder: placeholder,
                          )
                        : placeholder,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? client.id : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: t.chalk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'CI ${client.id} · ${readyToPay ? 'plan asignado' : 'sin plan'}',
                      style: TextStyle(
                        fontFamily: PulsoFonts.mono,
                        fontSize: 10.5,
                        color: readyToPay ? t.muted : t.warning,
                      ),
                    ),
                  ],
                ),
              ),
              if (readyToPay)
                Icon(Icons.arrow_forward, size: 17, color: t.accent)
              else
                TextButton(
                  key: ValueKey('assign-plan-${client.id}'),
                  onPressed: onAssignPlan,
                  child: const Text('ASIGNAR PLAN'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
