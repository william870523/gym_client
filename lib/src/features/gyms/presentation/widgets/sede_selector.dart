import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../auth/presentation/state/sede_session_provider.dart';
import '../../../auth/presentation/state/auth_notifier.dart';
import '../gyms_provider.dart';

/// Selector de la sede activa (docs/MULTI_SEDE.md §3.4, etapa M2).
///
/// **No aparece si solo hay una sede**: para el 99 % de las cuentas —y para
/// todas las instalaciones de escritorio, que atienden una sola sede— sería un
/// mando inútil ocupando la cabecera.
///
/// Cambiar de sede tira **todo** el estado cacheado. No hace falta invalidar
/// nada a mano aquí: `apiClientProvider` observa la sede activa, cada
/// repositorio observa el cliente y cada vista observa su repositorio, así que
/// mover la sede reconstruye la cadena entera. Lo vigila
/// `test/core/network/api_client_dependency_test.dart`, porque un proveedor que
/// se saltara la cadena seguiría enseñando los socios de la sede anterior sin
/// dar ningún error.
class SedeSelector extends ConsumerWidget {
  const SedeSelector({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    final sedes = ref.watch(gymsListProvider).value ?? const [];
    final activa = ref.watch(sedeSessionProvider)?.gymId;

    // Una sola sede —o ninguna todavía— no necesita selector.
    if (sedes.length < 2) return const SizedBox.shrink();

    final actual = sedes.where((gym) => gym.id == activa).firstOrNull;

    return Tooltip(
      message: 'Sede activa. Al cambiarla se recarga todo con sus datos.',
      child: Material(
        color: tokens.raised,
        child: PopupMenuButton<String>(
          tooltip: '',
          color: tokens.surface,
          surfaceTintColor: Colors.transparent,
          position: PopupMenuPosition.under,
          onSelected: (gymId) async {
            try {
              await ref.read(authProvider.notifier).changeSede(gymId);
            } catch (_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('No se pudo cambiar de sede. El contexto anterior se conserva.'),
              ));
            }
          },
          itemBuilder: (context) => [
            for (final gym in sedes)
              PopupMenuItem<String>(
                value: gym.id,
                child: Row(
                  children: [
                    Icon(
                      gym.id == activa
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 15,
                      color: gym.id == activa ? tokens.accent : tokens.muted,
                    ),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        gym.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.chalk,
                          fontWeight: gym.id == activa
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          child: Container(
            constraints: BoxConstraints(minHeight: 34, maxWidth: compact ? 150 : 240),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 9 : 11,
              vertical: 7,
            ),
            decoration: BoxDecoration(border: Border.all(color: tokens.line)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront_outlined, size: 14, color: tokens.accent),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    actual?.name ?? 'Elegir sede',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tokens.chalk,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.expand_more, size: 15, color: tokens.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
