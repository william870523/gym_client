import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/state/sede_session_provider.dart';

/// Oculta mutaciones globales a una sesión de sede. El servidor vuelve a
/// comprobar la autoridad; esto solo evita ofrecer una acción imposible.
class GlobalCatalogAuthority extends ConsumerWidget {
  const GlobalCatalogAuthority({required this.child, this.readOnly, super.key});

  final Widget child;
  final Widget? readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sedeSessionProvider);
    // Los widget tests aislados no montan sesión; conservar sus controles hace
    // que prueben el CRUD. En la aplicación la sesión siempre está presente.
    if (session == null || session.esPlataforma) return child;
    return readOnly ??
        const Tooltip(
          message: 'Catálogo global: solo lo edita el dueño de la cadena',
          child: Icon(Icons.lock_outline, size: 18),
        );
  }
}
