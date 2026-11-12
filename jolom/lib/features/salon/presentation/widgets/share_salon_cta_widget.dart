import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/shared/widgets/app_modal_bottom_sheet.dart';

import 'salon_share_sheet.dart';

/// Invitación reutilizable para compartir la peluquería desde estados vacíos.
class ShareSalonCtaWidget extends ConsumerWidget {
  const ShareSalonCtaWidget({super.key});

  void _openShareSheet(BuildContext context, String salonId) {
    showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SalonShareSheet(salonId: salonId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(membershipProvider).value;
    if (membership == null || !membership.isActive) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Padding(
      key: const ValueKey('share-salon-empty-state'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Invita a tus amigos y clientes',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Haz que te encuentren en Jolom compartiendo tu negocio.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: () => _openShareSheet(context, membership.salonId),
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Compartir mi negocio'),
          ),
        ],
      ),
    );
  }
}
