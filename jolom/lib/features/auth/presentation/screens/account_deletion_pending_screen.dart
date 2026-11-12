import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/domain/entities/user_entity.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/providers/session_provider.dart';
import 'package:jolom/features/auth/domain/repositories/auth_repository.dart';

/// Única pantalla accesible mientras el backend elimina la cuenta.
class AccountDeletionPendingScreen extends ConsumerStatefulWidget {
  const AccountDeletionPendingScreen({super.key});

  @override
  ConsumerState<AccountDeletionPendingScreen> createState() =>
      _AccountDeletionPendingScreenState();
}

class _AccountDeletionPendingScreenState
    extends ConsumerState<AccountDeletionPendingScreen> {
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
    final completed = profile?.accountStatus == AccountStatus.deleted;

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
                    completed ? Icons.person_off_outlined : Icons.hourglass_top,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    completed ? 'Cuenta eliminada' : 'Eliminación en proceso',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    completed
                        ? 'Tus datos personales fueron eliminados o anonimizados. '
                              'Puedes cerrar esta sesión.'
                        : 'Tu cuenta está bloqueada mientras eliminamos y '
                              'anonimizamos los datos relacionados. No puedes '
                              'utilizarla durante este proceso.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
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
