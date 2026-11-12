import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/providers/hour_format_provider.dart';
import 'package:jolom/core/providers/user_directory_provider.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';
import 'package:jolom/core/utils/app_time_format.dart';
import 'package:jolom/features/appointment/domain/entities/appointment_entity.dart';
import 'package:jolom/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:jolom/features/appointment/presentation/widgets/appointment_id_label_widget.dart';
import 'package:jolom/features/appointment/presentation/widgets/appointment_status_actions_sheet.dart';
import 'package:jolom/features/salon/domain/repositories/salon_repository.dart';
import 'package:jolom/features/salon/presentation/widgets/share_salon_cta_widget.dart';
import 'package:jolom/shared/widgets/status_badge_widget.dart';
import 'package:jolom/shared/widgets/user_identity.dart';

/// Inicio modo trabajo: pendientes y agenda del día.
class WorkHomeScreen extends ConsumerStatefulWidget {
  const WorkHomeScreen({super.key});

  @override
  ConsumerState<WorkHomeScreen> createState() => _WorkHomeScreenState();
}

class _WorkHomeScreenState extends ConsumerState<WorkHomeScreen> {
  /// Citas recién aceptadas aún visibles durante la animación de salida.
  final Map<String, Appointment> _celebrating = {};

  Future<void> _onRefresh() async {
    clearUserDirectory(ref);
    ref.invalidate(barberAppointmentsProvider);
    ref.invalidate(membershipProvider);
    await Future.wait([
      ref.read(barberAppointmentsProvider.future),
      ref.read(membershipProvider.future),
    ]);
  }

  void _onConfirmSuccess(Appointment appointment) {
    setState(() => _celebrating[appointment.id] = appointment);
  }

  void _onExitComplete(String appointmentId) {
    if (!_celebrating.containsKey(appointmentId)) return;
    setState(() => _celebrating.remove(appointmentId));
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(barberAppointmentsProvider);
    final membership = ref.watch(membershipProvider).value;
    final highlightedId = ref.watch(highlightedAppointmentIdProvider);
    final use24h = resolveUse24HourFormat(
      context,
      ref.watch(hourFormatProvider),
    );
    // Día de la semana + fecha en español (vie 24/07 14:30).
    // ignore: discarded_futures
    initializeDateFormatting('es');
    final fmt = DateFormat(
      'EEE dd/MM ${appTimePattern(use24HourFormat: use24h)}',
      'es',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo trabajo'),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(appModeProvider.notifier).setMode(AppMode.client);
              context.go('/home');
            },
            child: const Text('Cliente'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: appointmentsAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 120),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (e, st) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: appScrollPadding(context, horizontal: 16, vertical: 16),
            children: [
              SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
              Center(child: Text(userFacingError(e, st))),
            ],
          ),
          data: (items) {
            final pending = items
                .where((a) => a.status == AppointmentStatus.pending)
                .toList();
            final pendingIds = pending.map((a) => a.id).toSet();
            // Retener cards aceptadas mientras dura la animación.
            final displayPending = [
              ...pending,
              ..._celebrating.values.where((a) => !pendingIds.contains(a.id)),
            ];
            final now = DateTime.now();
            final today = items.where((a) {
              if (_celebrating.containsKey(a.id)) return false;
              final s = a.startAt.toLocal();
              return s.year == now.year &&
                  s.month == now.month &&
                  s.day == now.day &&
                  a.status == AppointmentStatus.confirmed;
            }).toList();

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: appScrollPadding(
                context,
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              children: [
                if (membership?.status.name == 'pendingExit') ...[
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: ListTile(
                      title: const Text('Salida pendiente'),
                      subtitle: const Text(
                        'Resuelve citas futuras y completa la salida.',
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          try {
                            await getIt<SalonRepository>()
                                .completeMembershipExit();
                            ref.invalidate(membershipProvider);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(userFacingError(e))),
                              );
                            }
                          }
                        },
                        child: const Text('Completar'),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Text(
                  'Solicitudes pendientes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (displayPending.isEmpty)
                  const Text('Sin pendientes.')
                else
                  ...displayPending.map(
                    (a) => _PendingRequestCard(
                      key: ValueKey(a.id),
                      appointment: a,
                      timeLabel: fmt.format(a.startAt.toLocal()),
                      highlighted: highlightedId == a.id,
                      onHighlightFinished: () {
                        if (ref.read(highlightedAppointmentIdProvider) ==
                            a.id) {
                          ref
                              .read(highlightedAppointmentIdProvider.notifier)
                              .clear();
                        }
                      },
                      onRetain: () => _onConfirmSuccess(a),
                      onExitComplete: () => _onExitComplete(a.id),
                      onConfirm: () => getIt<AppointmentRepository>()
                          .changeAppointmentStatus(
                            appointmentId: a.id,
                            status: AppointmentStatus.confirmed,
                            idempotencyKey: 'changeStatus_${a.id}_confirmed',
                          ),
                      onReject: () => getIt<AppointmentRepository>()
                          .changeAppointmentStatus(
                            appointmentId: a.id,
                            status: AppointmentStatus.rejected,
                            idempotencyKey: 'changeStatus_${a.id}_rejected',
                          ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sectionGap),
                Text('Hoy', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                if (today.isEmpty) ...[
                  const Text('Sin citas hoy.'),
                  const SizedBox(height: AppSpacing.md),
                  const ShareSalonCtaWidget(),
                ] else
                  ...today.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Card(
                        child: ListTile(
                          isThreeLine: true,
                          title: UserName(userId: a.clientId),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${a.serviceName} · ${fmt.format(a.startAt.toLocal())}',
                              ),
                              AppointmentIdLabelWidget(appointmentId: a.id),
                            ],
                          ),
                          trailing: StatusBadgeWidget(label: a.status.labelEs),
                          // Long-press: menú de acciones sobre citas confirmadas.
                          onLongPress: () =>
                              showAppointmentStatusActions(context, a),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Tarjeta de solicitud pendiente con parpadeo sutil al llegar desde push.
class _PendingRequestCard extends StatefulWidget {
  const _PendingRequestCard({
    required this.appointment,
    required this.timeLabel,
    required this.highlighted,
    required this.onHighlightFinished,
    required this.onRetain,
    required this.onExitComplete,
    required this.onConfirm,
    required this.onReject,
    super.key,
  });

  final Appointment appointment;
  final String timeLabel;
  final bool highlighted;
  final VoidCallback onHighlightFinished;

  /// Mantener la card en la lista mientras corre API + animación.
  final VoidCallback onRetain;
  final VoidCallback onExitComplete;
  final Future<void> Function() onConfirm;
  final Future<void> Function() onReject;

  @override
  State<_PendingRequestCard> createState() => _PendingRequestCardState();
}

class _PendingRequestCardState extends State<_PendingRequestCard>
    with TickerProviderStateMixin {
  static const _successHold = Duration(milliseconds: 550);

  late final AnimationController _pulse;
  late final Animation<double> _pulseOpacity;
  late final AnimationController _success;
  late final Animation<double> _successScale;
  late final Animation<double> _successOpacity;
  late final AnimationController _exit;
  late final Animation<double> _exitOpacity;
  late final Animation<double> _exitSlide;
  late final Animation<double> _exitScale;

  bool _busy = false;
  bool _accepted = false;
  bool _exitStarted = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseOpacity = Tween<double>(
      begin: 0.55,
      end: 1,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    // Pop del check más largo y con overshoot visible.
    _success = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _successScale = Tween<double>(
      begin: 0.2,
      end: 1,
    ).animate(CurvedAnimation(parent: _success, curve: Curves.elasticOut));
    _successOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _success,
        curve: const Interval(0, 0.35, curve: Curves.easeOut),
      ),
    );

    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _exitOpacity = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(parent: _exit, curve: AppMotion.standard));
    _exitSlide = Tween<double>(
      begin: 0,
      end: -48,
    ).animate(CurvedAnimation(parent: _exit, curve: AppMotion.standard));
    _exitScale = Tween<double>(
      begin: 1,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _exit, curve: AppMotion.standard));

    if (widget.highlighted) {
      _startPulse();
    }
  }

  @override
  void didUpdateWidget(covariant _PendingRequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlighted && !oldWidget.highlighted) {
      _startPulse();
    }
  }

  Future<void> _startPulse() async {
    _pulse.repeat(reverse: true);
    await Future<void>.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    _pulse.stop();
    _pulse.value = 1;
    widget.onHighlightFinished();
  }

  Future<void> _runReject() async {
    if (_busy || _accepted) return;
    final confirmed = await confirmAppointmentStatusAction(
      context,
      AppointmentStatus.rejected,
    );
    if (!mounted || !confirmed || _busy || _accepted) return;
    setState(() => _busy = true);
    try {
      await widget.onReject();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _playAcceptAnimation() async {
    if (_exitStarted) return;
    _exitStarted = true;
    if (AppMotion.reduceMotion(context)) {
      widget.onExitComplete();
      return;
    }
    await _success.forward(from: 0);
    if (!mounted) return;
    await Future<void>.delayed(_successHold);
    if (!mounted) return;
    await _exit.forward(from: 0);
    if (!mounted) return;
    widget.onExitComplete();
  }

  Future<void> _runConfirm() async {
    if (_busy || _accepted) return;
    final confirmed = await confirmAppointmentStatusAction(
      context,
      AppointmentStatus.confirmed,
    );
    if (!mounted || !confirmed || _busy || _accepted) return;
    // Retener YA: el stream de Firestore puede quitar la card antes
    // de que termine la API y destruiría el State sin animar.
    widget.onRetain();
    setState(() => _busy = true);
    try {
      await widget.onConfirm();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _busy = false;
        _accepted = true;
      });
      await _playAcceptAnimation();
    } catch (e) {
      widget.onExitComplete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
      setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _success.dispose();
    _exit.dispose();
    super.dispose();
  }

  Widget _buildTrailing(ColorScheme scheme) {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.xs),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: const Icon(Icons.check), onPressed: _runConfirm),
        IconButton(icon: const Icon(Icons.close), onPressed: _runReject),
      ],
    );
  }

  Widget _buildSuccessOverlay(ColorScheme scheme, TextTheme textTheme) {
    return FadeTransition(
      opacity: _successOpacity,
      child: ScaleTransition(
        scale: _successScale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: scheme.primary, size: 52),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Aceptada',
              style: textTheme.titleMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    // Solo tras OK de la API: `onRetain` solo evita que el stream desmonte la card.
    final showSuccess = _accepted;

    final cardBody = showSuccess
        ? SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.lg,
              ),
              child: Center(child: _buildSuccessOverlay(scheme, textTheme)),
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserName(
                        userId: widget.appointment.clientId,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        widget.appointment.serviceName,
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        widget.timeLabel,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      AppointmentIdLabelWidget(
                        appointmentId: widget.appointment.id,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _buildTrailing(scheme),
              ],
            ),
          );

    final card = Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: showSuccess
            ? Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.16),
                scheme.surface,
              )
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: widget.highlighted && !showSuccess
              ? BorderSide(color: scheme.primary, width: 1.5)
              : showSuccess
              ? BorderSide(color: scheme.primary, width: 1.5)
              : BorderSide.none,
        ),
        child: cardBody,
      ),
    );

    Widget result = card;
    if (widget.highlighted && !showSuccess && _pulse.isAnimating) {
      result = FadeTransition(opacity: _pulseOpacity, child: result);
    }

    if (showSuccess) {
      result = AnimatedBuilder(
        animation: Listenable.merge([_success, _exit]),
        builder: (context, child) {
          return Opacity(
            opacity: _exitOpacity.value,
            child: Transform.translate(
              offset: Offset(0, _exitSlide.value),
              child: Transform.scale(scale: _exitScale.value, child: child),
            ),
          );
        },
        child: result,
      );
    }

    return result;
  }
}
