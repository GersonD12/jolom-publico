import 'package:flutter/material.dart';
import 'package:jolom/core/theme/theme.dart';

/// Mensaje flotante para estados vacíos o errores del mapa.
class SalonMapMessageWidget extends StatelessWidget {
  const SalonMapMessageWidget({
    required this.icon,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 4,
    color: Theme.of(context).colorScheme.surface,
    borderRadius: AppRadius.cardCompact,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
