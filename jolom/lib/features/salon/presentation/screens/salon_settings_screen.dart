import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';
import 'package:jolom/shared/widgets/soft_card_widget.dart';

/// Opciones adicionales de administración de la peluquería.
class SalonSettingsScreen extends StatelessWidget {
  const SalonSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración del negocio')),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: appScrollPadding(
          context,
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
          bottom: appBottomActionClearance,
        ),
        children: [
          SoftCardWidget(
            key: const ValueKey('salon-stats-option'),
            onTap: () => context.push('/work/stats'),
            child: Row(
              children: [
                Icon(
                  Icons.bar_chart_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estadísticas', style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Consulta el rendimiento y la actividad de tu negocio.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
