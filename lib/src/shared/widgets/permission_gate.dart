import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/state/auth_notifier.dart';

class PermissionGate extends ConsumerWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;

  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return authState.when(
      data: (user) {
        if (user == null) return fallback ?? const SizedBox.shrink();

        // Check for specific permission or Super Admin wildcard '*'
        final hasPermission =
            user.permissions.contains(permission) ||
            user.permissions.contains('*');

        if (hasPermission) {
          return child;
        }

        return fallback ?? const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(), // Or fallback
      error: (_, _) => fallback ?? const SizedBox.shrink(),
    );
  }
}
