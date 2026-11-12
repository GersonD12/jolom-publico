import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/providers/hour_format_provider.dart';
import 'package:jolom/core/providers/session_provider.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/core/utils/app_time_format.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';
import 'package:jolom/features/appointment/application/use_cases/change_appointment_status_use_case.dart';
import 'package:jolom/features/appointment/domain/entities/appointment_entity.dart';
import 'package:jolom/features/appointment/presentation/providers/client_appointments_provider.dart';
import 'package:jolom/features/appointment/presentation/utils/notification_permission_prompt.dart';
import 'package:jolom/features/appointment/presentation/widgets/appointment_id_label_widget.dart';
import 'package:jolom/features/appointment/presentation/widgets/appointment_status_actions_sheet.dart';
import 'package:jolom/shared/widgets/notifications_icon_button_widget.dart';
import 'package:jolom/shared/widgets/soft_card_widget.dart';
import 'package:jolom/shared/widgets/status_badge_widget.dart';

bool _isLocalToday(DateTime dateTime) {
  final local = dateTime.toLocal();
  final now = DateTime.now();
  return local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
}

enum _AppointmentsView { today, upcoming, history }

/// Mis citas (cliente).
class MyAppointmentsScreen extends ConsumerStatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  ConsumerState<MyAppointmentsScreen> createState() =>
      _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends ConsumerState<MyAppointmentsScreen> {
  static const _dialogBody =
      'Así te enteras al instante cuando confirmen, rechacen o cancelen '
      'tus citas. Si ya las bloqueaste, actívalas en Ajustes del sistema.';

  bool _promptShownThisVisit = false;
  final Map<String, GlobalKey> _upcomingAppointmentKeys = {};
  String? _autoScrolledAppointmentId;
  String? _focusedHighlightedAppointmentId;
  bool _autoScrollScheduled = false;
  _AppointmentsView _view = _AppointmentsView.today;
  AppLifecycleListener? _lifecycleListener;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _lifecycleListener = AppLifecycleListener(onResume: _onAppResumed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: discarded_futures
      _maybePromptNotifications(showDialogIfNeeded: true);
      // Revalida sin ocultar las citas conservadas durante la sesión.
      // ignore: discarded_futures
      ref.read(clientAppointmentHistoryProvider.notifier).refreshFirstPage();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _lifecycleListener?.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_view != _AppointmentsView.history ||
        !_scrollController.hasClients ||
        _scrollController.position.extentAfter > 280) {
      return;
    }
    // ignore: discarded_futures
    ref.read(clientAppointmentHistoryProvider.notifier).loadMore();
  }

  void _onAppResumed() {
    // ignore: discarded_futures
    _maybePromptNotifications(showDialogIfNeeded: false);
  }

  GlobalKey _keyForUpcomingAppointment(String appointmentId) {
    return _upcomingAppointmentKeys.putIfAbsent(appointmentId, GlobalKey.new);
  }

  void _scheduleScrollToHighlighted(String appointmentId) {
    if (_autoScrolledAppointmentId == appointmentId || _autoScrollScheduled) {
      return;
    }
    _autoScrollScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _autoScrollScheduled = false;
      if (!mounted ||
          ref.read(highlightedClientAppointmentIdProvider) != appointmentId) {
        return;
      }

      final targetContext =
          _upcomingAppointmentKeys[appointmentId]?.currentContext;
      if (targetContext == null) return;

      _autoScrolledAppointmentId = appointmentId;
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0.15,
        duration: AppMotion.durationOf(
          context,
          const Duration(milliseconds: 380),
        ),
        curve: AppMotion.curveOf(context, AppMotion.decelerate),
      );
      if (!mounted ||
          ref.read(highlightedClientAppointmentIdProvider) != appointmentId) {
        return;
      }
      setState(() => _focusedHighlightedAppointmentId = appointmentId);
    });
  }

  Future<void> _maybePromptNotifications({
    required bool showDialogIfNeeded,
  }) async {
    if (!mounted) return;
    final session = ref.read(sessionProvider).value;
    if (session == null) return;

    final shown = await NotificationPermissionPrompt.ensureNotificationsEnabled(
      context: context,
      isMounted: () => mounted,
      body: _dialogBody,
      showDialogIfNeeded: showDialogIfNeeded,
      alreadyShown: _promptShownThisVisit,
    );
    if (shown) _promptShownThisVisit = true;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).value;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mis citas'),
          actions: const [NotificationsIconButtonWidget()],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Únete para ver y reservar citas',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Inicia sesión o crea una cuenta para gestionar tus citas en Jolom.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/login?from=/appointments'),
                  child: const Text('Iniciar sesión'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final upcomingAsync = ref.watch(clientUpcomingAppointmentsProvider);
    final cachedUpcoming = ref.watch(clientUpcomingAppointmentsCacheProvider);
    final visibleUpcoming = upcomingAsync.value ?? cachedUpcoming;
    final historyAsync = ref.watch(clientAppointmentHistoryProvider);
    final highlightedAppointmentId = ref.watch(
      highlightedClientAppointmentIdProvider,
    );
    final use24h = resolveUse24HourFormat(
      context,
      ref.watch(hourFormatProvider),
    );
    // Día + fecha corta en español; hora según preferencia 12h/24h.
    // ignore: discarded_futures
    initializeDateFormatting('es');
    final dateFmt = DateFormat('EEE, d MMM', 'es');
    final timeFmt = DateFormat(appTimePattern(use24HourFormat: use24h));
    final sortedUpcoming = visibleUpcoming == null
        ? null
        : ([...visibleUpcoming]..sort((first, second) {
            final dateComparison = first.startAt.compareTo(second.startAt);
            return dateComparison != 0
                ? dateComparison
                : first.id.compareTo(second.id);
          }));
    final todayAppointments = sortedUpcoming
        ?.where((appointment) => _isLocalToday(appointment.startAt))
        .toList();
    final futureAppointments = sortedUpcoming
        ?.where((appointment) => !_isLocalToday(appointment.startAt))
        .toList();
    if (highlightedAppointmentId != null &&
        sortedUpcoming?.any(
              (appointment) => appointment.id == highlightedAppointmentId,
            ) ==
            true) {
      _scheduleScrollToHighlighted(highlightedAppointmentId);
    }

    Widget buildUpcomingTile(Appointment appointment) {
      return _AppointmentTile(
        key: _keyForUpcomingAppointment(appointment.id),
        appointment: appointment,
        dateFmt: dateFmt,
        timeFmt: timeFmt,
        highlighted:
            highlightedAppointmentId == appointment.id &&
            _focusedHighlightedAppointmentId == appointment.id,
        onHighlightFinished: () {
          if (ref.read(highlightedClientAppointmentIdProvider) ==
              appointment.id) {
            ref.read(highlightedClientAppointmentIdProvider.notifier).clear();
          }
        },
        onTap: appointment.salonId.isEmpty
            ? null
            : () => context.push('/salon/${appointment.salonId}'),
        onCancel: () async {
          await getIt<ChangeAppointmentStatusUseCase>()(
            appointmentId: appointment.id,
            status: AppointmentStatus.cancelledByClient,
            idempotencyKey: 'changeStatus_${appointment.id}_cancelledByClient',
          );
          // La lista visible se conserva mientras se actualiza.
          // ignore: discarded_futures
          ref
              .read(clientAppointmentHistoryProvider.notifier)
              .refreshFirstPage(force: true);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis citas'),
        actions: const [NotificationsIconButtonWidget()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: SegmentedButton<_AppointmentsView>(
              segments: [
                const ButtonSegment(
                  value: _AppointmentsView.today,
                  label: Text('Hoy'),
                ),
                ButtonSegment(
                  value: _AppointmentsView.upcoming,
                  label: Badge.count(
                    count: futureAppointments?.length ?? 0,
                    isLabelVisible: (futureAppointments?.isNotEmpty ?? false),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Text('Próximas'),
                    ),
                  ),
                ),
                const ButtonSegment(
                  value: _AppointmentsView.history,
                  label: Text('Historial'),
                ),
              ],
              selected: {_view},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() => _view = selection.first);
              },
            ),
          ),
        ),
      ),
      body: switch (_view) {
        _AppointmentsView.today =>
          visibleUpcoming == null
              ? ListView(
                  padding: appScrollPadding(
                    context,
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  children: [
                    upcomingAsync.when(
                      loading: () => const _SectionLoadingWidget(),
                      error: (error, stackTrace) =>
                          Text(userFacingError(error, stackTrace)),
                      data: (_) => const SizedBox.shrink(),
                    ),
                  ],
                )
              : todayAppointments!.isEmpty
              ? const _EmptyAppointmentsWidget(
                  message: 'No tienes citas para hoy.',
                )
              : ListView(
                  padding: appScrollPadding(
                    context,
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  children: todayAppointments.map(buildUpcomingTile).toList(),
                ),
        _AppointmentsView.upcoming =>
          visibleUpcoming == null
              ? ListView(
                  padding: appScrollPadding(
                    context,
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  children: [
                    upcomingAsync.when(
                      loading: () => const _SectionLoadingWidget(),
                      error: (error, stackTrace) =>
                          Text(userFacingError(error, stackTrace)),
                      data: (_) => const SizedBox.shrink(),
                    ),
                  ],
                )
              : futureAppointments!.isEmpty
              ? const _EmptyAppointmentsWidget(
                  message: 'No tienes citas próximas.',
                )
              : ListView(
                  padding: appScrollPadding(
                    context,
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  children: [
                    ...futureAppointments.map(buildUpcomingTile),
                    if (upcomingAsync.hasError)
                      Text(
                        'No se pudieron actualizar las citas. '
                        'Se muestran los últimos datos disponibles.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
        _AppointmentsView.history => historyAsync.when(
          loading: () => const _SectionLoadingWidget(),
          error: (error, stackTrace) => ListView(
            padding: appScrollPadding(
              context,
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(userFacingError(error, stackTrace)),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(clientAppointmentHistoryProvider),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ],
          ),
          data: (history) => history.items.isEmpty
              ? const _EmptyAppointmentsWidget(
                  message: 'Aún no tienes citas en tu historial.',
                )
              : ListView(
                  controller: _scrollController,
                  padding: appScrollPadding(
                    context,
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...history.items.map(
                          (appointment) => _AppointmentTile(
                            key: ValueKey(appointment.id),
                            appointment: appointment,
                            dateFmt: dateFmt,
                            timeFmt: timeFmt,
                            onTap: appointment.salonId.isEmpty
                                ? null
                                : () => context.push(
                                    '/salon/${appointment.salonId}',
                                  ),
                          ),
                        ),
                        if (history.isLoadingMore)
                          const _SectionLoadingWidget()
                        else if (history.paginationError != null) ...[
                          Text(
                            userFacingError(
                              history.paginationError!,
                              history.paginationStackTrace,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: () => ref
                                .read(clientAppointmentHistoryProvider.notifier)
                                .loadMore(),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
        ),
      },
    );
  }
}

class _EmptyAppointmentsWidget extends StatelessWidget {
  const _EmptyAppointmentsWidget({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: Semantics(
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
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLoadingWidget extends StatelessWidget {
  const _SectionLoadingWidget();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _AppointmentTile extends StatefulWidget {
  const _AppointmentTile({
    required this.appointment,
    required this.dateFmt,
    required this.timeFmt,
    this.highlighted = false,
    this.onHighlightFinished,
    this.onTap,
    this.onCancel,
    super.key,
  });

  final Appointment appointment;
  final DateFormat dateFmt;
  final DateFormat timeFmt;
  final bool highlighted;
  final VoidCallback? onHighlightFinished;
  final VoidCallback? onTap;
  final Future<void> Function()? onCancel;

  @override
  State<_AppointmentTile> createState() => _AppointmentTileState();
}

class _AppointmentTileState extends State<_AppointmentTile>
    with SingleTickerProviderStateMixin {
  static const _highlightDuration = Duration(milliseconds: 2500);

  late final AnimationController _highlightController;
  bool _highlightStarted = false;
  int _highlightGeneration = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.highlighted && !_highlightStarted) {
      _highlightStarted = true;
      // ignore: discarded_futures
      _playHighlight();
    }
  }

  @override
  void didUpdateWidget(covariant _AppointmentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlighted && !oldWidget.highlighted) {
      _highlightStarted = true;
      // ignore: discarded_futures
      _playHighlight();
    } else if (!widget.highlighted && oldWidget.highlighted) {
      _stopHighlight();
    }
  }

  Future<void> _playHighlight() async {
    final generation = ++_highlightGeneration;
    if (AppMotion.reduceMotion(context)) {
      _highlightController.value = 1;
    } else {
      _highlightController.repeat(reverse: true);
    }

    await Future<void>.delayed(_highlightDuration);
    if (!mounted || generation != _highlightGeneration) return;
    _highlightController
      ..stop()
      ..value = 0;
    widget.onHighlightFinished?.call();
  }

  void _stopHighlight() {
    _highlightGeneration++;
    _highlightStarted = false;
    _highlightController
      ..stop()
      ..value = 0;
  }

  @override
  void dispose() {
    _highlightGeneration++;
    _highlightController.dispose();
    super.dispose();
  }

  /// Capitaliza la primera letra (ej. `lun, 3 ago` → `Lun, 3 ago`).
  String _capitalizeFirst(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  String _formatDateTime(DateTime local) {
    final date = _capitalizeFirst(widget.dateFmt.format(local));
    final time = widget.timeFmt.format(local);
    return '$date · $time';
  }

  Future<void> _runCancel() async {
    if (_busy || widget.onCancel == null) return;
    final confirmed = await confirmAppointmentStatusAction(
      context,
      AppointmentStatus.cancelledByClient,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.onCancel!();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final appointment = widget.appointment;
    final localStart = appointment.startAt.toLocal();
    final isToday =
        _isLocalToday(appointment.startAt) &&
        (appointment.status == AppointmentStatus.pending ||
            appointment.status == AppointmentStatus.confirmed);

    final cardBody = InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    appointment.serviceName,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.onTap != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Tooltip(
                    message: 'Ver peluquería',
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _formatDateTime(localStart),
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cita ${AppointmentIdLabelWidget.format(appointment.id)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                StatusBadgeWidget(
                  label: appointment.status.labelEs,
                  tone: StatusBadgeTone.neutral,
                ),
              ],
            ),
            if (widget.onCancel != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: _busy ? null : _runCancel,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Cancelar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AnimatedBuilder(
        animation: _highlightController,
        child: cardBody,
        builder: (context, child) {
          final progress = Curves.easeInOut.transform(
            _highlightController.value,
          );
          return Card(
            color: widget.highlighted
                ? Color.lerp(
                    scheme.surfaceContainerLow,
                    scheme.primaryContainer,
                    progress,
                  )
                : null,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.card,
              side: isToday
                  ? BorderSide(color: scheme.primary, width: 1.5)
                  : BorderSide.none,
            ),
            child: child,
          );
        },
      ),
    );
  }
}
