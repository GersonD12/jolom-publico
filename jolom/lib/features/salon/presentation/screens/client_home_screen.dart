import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/providers/session_provider.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';
import 'package:jolom/shared/widgets/ambient_background_widget.dart';
import 'package:jolom/shared/widgets/circular_icon_button_widget.dart';
import 'package:jolom/shared/widgets/pill_button_widget.dart';
import 'package:jolom/shared/widgets/soft_card_widget.dart';

/// Inicio modo cliente.
class ClientHomeScreen extends ConsumerWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authSession = ref.watch(sessionProvider).value;
    final session = ref.watch(hydratedSessionProvider).value ?? authSession;
    final membership = ref.watch(membershipProvider).value;
    final theme = Theme.of(context);
    final name = session?.preferredDisplayName;

    return AmbientBackgroundWidget(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: appScrollPadding(context, horizontal: 24, vertical: 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Jolom', style: theme.textTheme.headlineLarge),
                ),
                CircularIconButtonWidget(
                  tooltip: 'Notificaciones',
                  icon: Icons.notifications_outlined,
                  onPressed: () => context.push('/notifications'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              session == null
                  ? 'Explora peluquerías sin cuenta. Inicia sesión al reservar.'
                  : name != null
                  ? 'Hola, $name'
                  : 'Hola',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label: 'Buscar peluquerías',
              excludeSemantics: true,
              child: SoftCardWidget(
                onTap: () => context.go('/explore'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Descubrir', style: theme.textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Encuentra peluquerías cerca de ti.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      constraints: const BoxConstraints(
                        minHeight: AppSpacing.minTapTarget,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.72),
                        borderRadius: AppRadius.pill,
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.18,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Buscar peluquerías',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (membership != null && membership.isActive) ...[
              const SizedBox(height: 16),
              SoftCardWidget(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Modo trabajo', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      membership.isOwner
                          ? 'Gestiona tu peluquería y equipo.'
                          : 'Administra tu agenda y citas.',
                    ),
                    const SizedBox(height: 16),
                    PillButtonWidget(
                      label: 'Abrir modo trabajo',
                      onPressed: () {
                        ref
                            .read(appModeProvider.notifier)
                            .setMode(AppMode.work);
                        context.go('/work');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
