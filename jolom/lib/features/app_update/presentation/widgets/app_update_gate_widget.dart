import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_update_provider.dart';
import '../screens/app_update_screen.dart';

/// Bloquea toda interacción con la app cuando la versión instalada expiró.
class AppUpdateGate extends ConsumerWidget {
  const AppUpdateGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(appUpdateStatusProvider);
    return status.when(
      data: (value) =>
          value.updateRequired ? AppUpdateScreen(status: value) : child,
      // No mostramos la app hasta completar la primera validación.
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      // Fail-open ante una caída de configuración para no inutilizar todas las
      // instalaciones; el stream se recuperará y volverá a evaluar la versión.
      error: (_, _) => child,
    );
  }
}
