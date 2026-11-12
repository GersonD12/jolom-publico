import 'package:flutter/material.dart';

/// Resumen del servicio elegido, con el precio destacado.
class BookingServiceSummaryWidget extends StatelessWidget {
  const BookingServiceSummaryWidget({
    required this.name,
    required this.durationMinutes,
    required this.priceLabel,
    super.key,
  });

  final String name;
  final int durationMinutes;
  final String priceLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = Theme.of(context).textTheme.bodyMedium;
    final muted = body?.copyWith(color: scheme.onSurfaceVariant);

    return Text.rich(
      TextSpan(
        style: muted,
        children: [
          TextSpan(text: '$name · $durationMinutes min · '),
          TextSpan(
            text: priceLabel,
            style: body?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
