import 'package:flutter/material.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/features/salon/domain/entities/salon_membership_entity.dart';
import 'package:jolom/shared/widgets/pill_button_widget.dart';

import 'booking_service_summary_widget.dart';

/// Selección de peluquero previa al horario de reserva.
class BookingBarberSheet extends StatefulWidget {
  const BookingBarberSheet({
    required this.members,
    required this.serviceName,
    required this.durationMinutes,
    required this.priceLabel,
    this.initialBarberId = 'any',
    super.key,
  });

  final List<SalonMembership> members;
  final String serviceName;
  final int durationMinutes;
  final String priceLabel;
  final String initialBarberId;

  @override
  State<BookingBarberSheet> createState() => _BookingBarberSheetState();
}

class _BookingBarberSheetState extends State<BookingBarberSheet> {
  late String _selectedBarberId;

  @override
  void initState() {
    super.initState();
    _selectedBarberId = widget.initialBarberId;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: bottomInset + safeBottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Peluquero', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          BookingServiceSummaryWidget(
            name: widget.serviceName,
            durationMinutes: widget.durationMinutes,
            priceLabel: widget.priceLabel,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Elige quién te atenderá o deja cualquiera.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Cualquiera'),
                selected: _selectedBarberId == 'any',
                onSelected: (_) {
                  setState(() => _selectedBarberId = 'any');
                },
              ),
              ...widget.members.map(
                (m) => ChoiceChip(
                  label: Text(m.isOwner ? 'Propietario' : 'Peluquero'),
                  selected: _selectedBarberId == m.userId,
                  onSelected: (_) {
                    setState(() => _selectedBarberId = m.userId);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          PillButtonWidget(
            label: 'Continuar',
            onPressed: () => Navigator.pop(context, _selectedBarberId),
          ),
        ],
      ),
    );
  }
}
