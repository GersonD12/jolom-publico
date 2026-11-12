import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/providers/session_provider.dart';
import 'package:jolom/features/auth/domain/repositories/auth_repository.dart';

/// Pantalla home de ejemplo tras autenticarse.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jolom'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => getIt<AuthRepository>().signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: session.when(
          data: (user) {
            if (user == null) {
              return const Text('Sin sesión');
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bienvenido',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('UID: ${user.id}'),
                if (user.email != null) Text('Email: ${user.email}'),
                Text(
                  user.isAnonymous ? 'Sesión anónima' : 'Sesión con email',
                ),
              ],
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (error, st) => Text(userFacingError(error, st)),
        ),
      ),
    );
  }
}
