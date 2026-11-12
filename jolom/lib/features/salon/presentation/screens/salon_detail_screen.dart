import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/providers/session_provider.dart';
import 'package:jolom/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:jolom/features/salon/domain/entities/salon_entity.dart';
import 'package:jolom/features/salon/domain/entities/salon_membership_entity.dart';
import 'package:jolom/features/salon/domain/entities/service_entity.dart';
import 'package:jolom/features/salon/domain/repositories/salon_repository.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/shared/widgets/app_modal_bottom_sheet.dart';
import 'package:jolom/shared/widgets/circular_icon_button_widget.dart';
import 'package:jolom/shared/widgets/fade_slide_in_widget.dart';
import 'package:jolom/shared/widgets/pressable_scale_widget.dart';
import 'package:jolom/shared/widgets/service_card_widget.dart';
import 'package:jolom/shared/widgets/status_badge_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/booking_barber_sheet.dart';
import '../widgets/booking_schedule_sheet.dart';
import '../widgets/place_gallery_preview_widget.dart';
import '../widgets/salon_hours_section_widget.dart';
import '../widgets/salon_share_sheet.dart';
import '../controllers/salon_detail_refresh_controller.dart';

final salonDetailProvider = FutureProvider.family<Salon?, String>((
  ref,
  salonId,
) {
  return getIt<SalonRepository>().getSalon(salonId);
});

final salonServicesProvider = FutureProvider.family<List<Service>, String>((
  ref,
  salonId,
) {
  return getIt<SalonRepository>().listServices(salonId);
});

final salonMembersProvider =
    FutureProvider.family<List<SalonMembership>, String>((ref, salonId) {
      return getIt<SalonRepository>().listSalonMembers(salonId);
    });

/// `weeklyHours` del propietario del salón (horario de atención público).
final salonOwnerWeeklyHoursProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, salonId) async {
      final salon = await ref.watch(salonDetailProvider(salonId).future);
      final ownerId = salon?.ownerId;
      if (ownerId == null || ownerId.isEmpty) return null;
      return getIt<AppointmentRepository>().getAvailabilityWeeklyHours(ownerId);
    });

/// Ficha pública de peluquería + inicio de reserva.
class SalonDetailScreen extends ConsumerStatefulWidget {
  const SalonDetailScreen({required this.salonId, super.key});

  final String salonId;

  @override
  ConsumerState<SalonDetailScreen> createState() => _SalonDetailScreenState();
}

class _SalonDetailScreenState extends ConsumerState<SalonDetailScreen> {
  String? _selectedServiceId;
  bool _bookingFlowInProgress = false;
  final _refreshController = SalonDetailRefreshController();

  Future<void> _refreshSalonDetails() async {
    final salonId = widget.salonId;
    final detailProvider = salonDetailProvider(salonId);
    final servicesProvider = salonServicesProvider(salonId);
    final hoursProvider = salonOwnerWeeklyHoursProvider(salonId);

    if (ref.read(detailProvider).isLoading ||
        ref.read(servicesProvider).isLoading ||
        ref.read(hoursProvider).isLoading) {
      return;
    }

    await _refreshController.run(() async {
      ref.invalidate(detailProvider);
      ref.invalidate(servicesProvider);
      ref.invalidate(hoursProvider);
      ref.invalidate(salonMembersProvider(salonId));

      try {
        await Future.wait<Object?>([
          ref.read(detailProvider.future),
          ref.read(servicesProvider.future),
          ref.read(hoursProvider.future),
        ]);
      } catch (error, stackTrace) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(error, stackTrace))),
        );
      }
    });
  }

  Widget _refreshablePlaceholder(Widget child) => RefreshIndicator(
    onRefresh: _refreshSalonDetails,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [SliverFillRemaining(hasScrollBody: false, child: child)],
    ),
  );

  Future<void> _prefetchTodaySchedule(Service service, String barberId) async {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    try {
      await getIt<AppointmentRepository>().getDayBusyIntervals(
        salonId: widget.salonId,
        barberId: barberId,
        dayStart: dayStart,
        dayEnd: dayStart.add(const Duration(days: 1)),
        serviceId: service.id,
      );
    } catch (_) {
      // El sheet conserva su manejo de error y opción de reintento.
    }
  }

  Future<void> _startBookingFlow(Service service) async {
    if (_bookingFlowInProgress) return;
    _bookingFlowInProgress = true;
    setState(() => _selectedServiceId = service.id);

    try {
      final priceLabel =
          '${service.price.toStringAsFixed(0)} ${service.currency}';

      List<SalonMembership> members;
      try {
        members = await ref.read(salonMembersProvider(widget.salonId).future);
      } catch (_) {
        members = const [];
      }
      if (!mounted) return;

      // Un solo peluquero: se asigna directo. Varios: sheet de elección.
      var barberId = 'any';
      if (members.length == 1) {
        barberId = members.first.userId;
      } else if (members.length > 1) {
        final selected = await showAppModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (ctx) => BookingBarberSheet(
            members: members,
            serviceName: service.name,
            durationMinutes: service.durationMinutes,
            priceLabel: priceLabel,
          ),
        );
        if (!mounted || selected == null) return;
        barberId = selected;
      }

      // Inicia la consulta durante la animación de apertura del sheet.
      // ignore: discarded_futures
      _prefetchTodaySchedule(service, barberId);
      final initialWeeklyHours = ref
          .read(salonOwnerWeeklyHoursProvider(widget.salonId))
          .value;
      await showAppModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => BookingScheduleSheet(
          salonId: widget.salonId,
          serviceId: service.id,
          barberId: barberId,
          durationMinutes: service.durationMinutes,
          serviceName: service.name,
          priceLabel: priceLabel,
          initialWeeklyHours: initialWeeklyHours,
          onConfirm: _confirmBooking,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _bookingFlowInProgress = false);
      } else {
        _bookingFlowInProgress = false;
      }
    }
  }

  Future<void> _confirmBooking(PendingBooking pending) async {
    final session = ref.read(sessionProvider).value;
    if (session == null) {
      ref.read(pendingBookingProvider.notifier).set(pending);
      // Tras login se completa la reserva y el router va a /appointments.
      if (mounted) {
        Navigator.of(context).pop();
        context.go('/login?from=/appointments');
      }
      return;
    }

    await _submitBooking(pending);
  }

  Future<void> _submitBooking(PendingBooking pending) async {
    // Capturar antes del await: tras navegar/desactivar el árbol,
    // ScaffoldMessenger.of(context) lanza (ancestor lookup unsafe).
    final messenger = ScaffoldMessenger.of(context);
    try {
      final appointment = await getIt<AppointmentRepository>()
          .createAppointment(
            salonId: pending.salonId,
            serviceId: pending.serviceId,
            barberId: pending.barberId,
            startAt: pending.startAt,
            origin: pending.origin,
          );
      ref
          .read(highlightedClientAppointmentIdProvider.notifier)
          .highlight(appointment.id);
      ref.read(pendingBookingProvider.notifier).set(null);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Solicitud enviada. Queda pendiente.')),
      );
      context.go('/appointments');
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo reservar: ${userFacingError(e)}')),
      );
    }
  }

  /// Abre Google Maps (u otra app de mapas) con la ubicación del salón.
  Future<void> _openSalonInMaps(Salon salon) async {
    final lat = salon.latitude;
    final lng = salon.longitude;
    if (lat == null || lng == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el mapa.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final salonAsync = ref.watch(salonDetailProvider(widget.salonId));
    final servicesAsync = ref.watch(salonServicesProvider(widget.salonId));
    final hoursAsync = ref.watch(salonOwnerWeeklyHoursProvider(widget.salonId));

    return Scaffold(
      body: salonAsync.when(
        loading: () => Stack(
          children: [
            _refreshablePlaceholder(
              const Center(child: CircularProgressIndicator()),
            ),
            _DetailOverlayActions(salonId: widget.salonId),
          ],
        ),
        error: (e, st) => Stack(
          children: [
            _refreshablePlaceholder(
              Center(child: Text(userFacingError(e, st))),
            ),
            _DetailOverlayActions(salonId: widget.salonId),
          ],
        ),
        data: (salon) {
          if (salon == null) {
            return Stack(
              children: [
                _refreshablePlaceholder(
                  const Center(child: Text('No encontrada')),
                ),
                _DetailOverlayActions(salonId: widget.salonId),
              ],
            );
          }
          final hasPlacePhotos =
              salon.imageUrls.isNotEmpty ||
              (salon.coverImageUrl != null && salon.coverImageUrl!.isNotEmpty);
          final heroHeight = MediaQuery.sizeOf(context).width * 0.85;
          final contentBottomPadding =
              MediaQuery.viewPaddingOf(context).bottom + AppSpacing.xxl;

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: _refreshSalonDetails,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    if (hasPlacePhotos)
                      PlaceGalleryPreviewWidget(
                        imageUrls: salon.imageUrls,
                        coverImageUrl: salon.coverImageUrl,
                        height: heroHeight,
                        borderRadius: BorderRadius.zero,
                      )
                    else
                      SizedBox(
                        height: heroHeight * 0.45,
                        width: double.infinity,
                        child: ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: Icon(Icons.storefront, size: 48),
                          ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        contentBottomPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            salon.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          if (salon.description != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(salon.description!),
                          ],
                          if (salon.address != null &&
                              salon.address!.trim().isNotEmpty)
                            Text(salon.address!.trim()),
                          if (salon.hasLocation) ...[
                            const SizedBox(height: AppSpacing.sm),
                            // Wrap listo para más chips (Instagram, etc.).
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              children: [
                                PressableScaleWidget(
                                  onTap: () => _openSalonInMaps(salon),
                                  child: const StatusBadgeWidget(
                                    label: 'Mapa',
                                    icon: Icons.location_on,
                                    size: StatusBadgeSize.compact,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Servicios',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          servicesAsync.when(
                            data: (services) {
                              if (services.isEmpty) {
                                return const Text('Sin servicios publicados.');
                              }
                              return Column(
                                children: [
                                  for (var i = 0; i < services.length; i++)
                                    FadeSlideInWidget(
                                      delay: Duration(milliseconds: 290 * i),
                                      duration: AppMotion.slow,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: AppSpacing.xs,
                                        ),
                                        child: ServiceCardWidget(
                                          title: services[i].name,
                                          priceLabel:
                                              '${services[i].price.toStringAsFixed(0)} ${services[i].currency}',
                                          durationLabel:
                                              '${services[i].durationMinutes} min',
                                          selected:
                                              _selectedServiceId ==
                                              services[i].id,
                                          enabled: !_bookingFlowInProgress,
                                          onTap: () =>
                                              _startBookingFlow(services[i]),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                            loading: () => const LinearProgressIndicator(),
                            error: (e, st) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(userFacingError(e, st)),
                                TextButton(
                                  onPressed: () => ref.invalidate(
                                    salonServicesProvider(widget.salonId),
                                  ),
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          hoursAsync.when(
                            data: (weeklyHours) {
                              if (weeklyHours == null || weeklyHours.isEmpty) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Horario de atención',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      'Horario no disponible',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                );
                              }
                              return SalonHoursSectionWidget(
                                weeklyHours: weeklyHours,
                              );
                            },
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Horario de atención',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Horario no disponible',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _DetailOverlayActions(
                salonId: widget.salonId,
                salonName: salon.name,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Botones circulares flotantes: atrás, compartir y reportar.
class _DetailOverlayActions extends StatelessWidget {
  const _DetailOverlayActions({required this.salonId, this.salonName});

  final String salonId;
  final String? salonName;

  void _openShareSheet(BuildContext context) {
    showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SalonShareSheet(salonId: salonId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            CircularIconButtonWidget(
              tooltip: 'Atrás',
              icon: Icons.arrow_back_rounded,
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/explore');
                }
              },
            ),
            const Spacer(),
            CircularIconButtonWidget(
              tooltip: 'Compartir',
              icon: Icons.share_outlined,
              onPressed: () => _openShareSheet(context),
            ),
            if (salonName != null) ...[
              const SizedBox(width: AppSpacing.sm),
              CircularIconButtonWidget(
                tooltip: 'Reportar',
                icon: Icons.flag_outlined,
                onPressed: () => context.push(
                  Uri(
                    path: '/report',
                    queryParameters: {
                      'targetType': 'salon',
                      'targetId': salonId,
                      'targetLabel': salonName,
                    },
                  ).toString(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
