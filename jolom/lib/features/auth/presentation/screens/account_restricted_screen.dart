import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/providers/session_provider.dart';
import 'package:jolom/features/auth/domain/repositories/auth_repository.dart';

/// Única pantalla accesible durante un bloqueo global de cuenta.
class AccountRestrictedScreen extends ConsumerStatefulWidget {
  const AccountRestrictedScreen({super.key});

  @override
  ConsumerState<AccountRestrictedScreen> createState() =>
      _AccountRestrictedScreenState();
}

class _AccountRestrictedScreenState
    extends ConsumerState<AccountRestrictedScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    ref.read(pendingBookingProvider.notifier).set(null);
    ref.read(highlightedAppointmentIdProvider.notifier).clear();
    ref.read(highlightedClientAppointmentIdProvider.notifier).clear();
    ref.read(appModeProvider.notifier).setMode(AppMode.client);
    await getIt<AuthRepository>().signOut();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(accountProfileProvider).value;
    final reason = profile?.moderationReason?.trim();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.block_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Cuenta bloqueada',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tu cuenta fue bloqueada y no puede utilizar las '
                    'funciones de Jolom.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (reason != null && reason.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Motivo: $reason',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _signingOut ? null : _signOut,
                    child: _signingOut
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
