import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/providers/hour_format_provider.dart';
// TODO: reactivar cita manual — import de sesión
// import 'package:jolom/core/providers/session_provider.dart';
import 'package:jolom/core/providers/user_directory_provider.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';
import 'package:jolom/core/utils/app_time_format.dart';
import 'package:jolom/features/appointment/domain/entities/appointment_entity.dart';
import 'package:jolom/features/appointment/presentation/providers/work_calendar_provider.dart';
import 'package:jolom/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:jolom/features/appointment/presentation/utils/notification_permission_prompt.dart';
import 'package:jolom/features/appointment/presentation/widgets/appointment_id_label_widget.dart';
import 'package:jolom/features/appointment/presentation/widgets/appointment_status_actions_sheet.dart';
import 'package:jolom/features/report/application/use_cases/get_salon_client_block_status_use_case.dart';
import 'package:jolom/features/report/application/use_cases/set_salon_client_block_use_case.dart';
import 'package:jolom/features/salon/presentation/widgets/share_salon_cta_widget.dart';
// TODO: reactivar cita manual — import del repositorio de salón
// import 'package:jolom/features/salon/domain/repositories/salon_repository.dart';
import 'package:jolom/shared/widgets/status_badge_widget.dart';
import 'package:jolom/shared/widgets/user_identity.dart';

/// Calendario del peluquero (o global si es propietario).
class WorkCalendarScreen extends ConsumerStatefulWidget {
  const WorkCalendarScreen({super.key});

  @override
  ConsumerState<WorkCalendarScreen> createState() => _WorkCalendarScreenState();
}

class _WorkCalendarScreenState extends ConsumerState<WorkCalendarScreen> {
  static const _dialogBody =
      'Te recomendamos activar las notificaciones para estar enterado de las '
      'citas de tus clientes. Si ya las bloqueaste, actívalas en Ajustes del '
      'sistema.';

  bool _promptShownThisVisit = false;
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
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 300) {
      return;
    }
    // ignore: discarded_futures
    ref.read(workCalendarProvider.notifier).loadMore();
  }

  void _onAppResumed() {
    // ignore: discarded_futures
    _maybePromptNotifications(showDialogIfNeeded: false);
  }

  Future<void> _maybePromptNotifications({
    required bool showDialogIfNeeded,
  }) async {
    final shown = await NotificationPermissionPrompt.ensureNotificationsEnabled(
      context: context,
      isMounted: () => mounted,
      body: _dialogBody,
      showDialogIfNeeded: showDialogIfNeeded,
      alreadyShown: _promptShownThisVisit,
    );
    if (shown) _promptShownThisVisit = true;
  }

  Future<void> _onRefresh() async {
    clearUserDirectory(ref);
    await _reloadAppointments();
  }

  Future<void> _reloadAppointments() async {
    ref.invalidate(workCalendarProvider);
    await ref.read(workCalendarProvider.future);
  }

  Future<void> _manageClientAccess(Appointment appointment) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final blocked = await getIt<GetSalonClientBlockStatusUseCase>()(
        targetUserId: appointment.clientId,
        sourceAppointmentId: appointment.id,
      );
      if (!mounted) return;

      final nextBlocked = !blocked;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(blocked ? 'Cliente bloqueado' : 'Cliente habilitado'),
          content: Text(
            blocked
                ? 'Este cliente no puede reservar en tu peluquería. '
                      '¿Quieres volver a permitirle crear citas?'
                : '¿Quieres impedir que este cliente cree nuevas citas '
                      'únicamente en tu peluquería?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(nextBlocked ? 'Bloquear' : 'Desbloquear'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final changed = await getIt<SetSalonClientBlockUseCase>()(
        targetUserId: appointment.clientId,
        sourceAppointmentId: appointment.id,
        blocked: nextBlocked,
        reason: nextBlocked
            ? 'Bloqueo manual desde una cita'
            : 'Desbloqueo manual desde una cita',
        idempotencyKey:
            'salonClientBlock_${appointment.id}_${appointment.clientId}_${nextBlocked}_${DateTime.now().microsecondsSinceEpoch}',
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            changed
                ? nextBlocked
                      ? 'Cliente bloqueado para esta peluquería.'
                      : 'Cliente desbloqueado para esta peluquería.'
                : nextBlocked
                ? 'El cliente ya estaba bloqueado.'
                : 'El cliente ya estaba desbloqueado.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(userFacingError(e))));
    }
  }

  /// Agrupa por día local preservando el orden del stream.
  List<_CalendarRow> _buildRows(List<Appointment> items) {
    final sections = <DateTime, List<Appointment>>{};
    for (final a in items) {
      final local = a.startAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      (sections[day] ??= []).add(a);
    }
    final rows = <_CalendarRow>[];
    for (final entry in sections.entries) {
      rows.add(_DayHeader(entry.key));
      for (final a in entry.value) {
        rows.add(_AppointmentRow(a));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(membershipProvider).value;
    final isOwner = membership?.isOwner == true;
    final use24h = resolveUse24HourFormat(
      context,
      ref.watch(hourFormatProvider),
    );
    final timeFmt = DateFormat(appTimePattern(use24HourFormat: use24h));
    // Abreviaturas de día/mes en español (lun, mar, ene, feb…).
    // initializeDateFormatting registra los símbolos de forma síncrona.
    // ignore: discarded_futures
    initializeDateFormatting('es');
    final dayFmt = DateFormat('EEE d MMM', 'es');
    final appointmentsAsync = ref.watch(workCalendarProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwner ? 'Calendario' : 'Mi calendario'),
        // TODO: reactivar cita manual
        // actions: [
        //   if (membership != null)
        //     IconButton(
        //       tooltip: 'Cita manual',
        //       onPressed: () => _showManualDialog(context, membership.salonId),
        //       icon: const Icon(Icons.add),
        //     ),
        // ],
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
          data: (calendar) {
            if (calendar.items.isEmpty) {
              return ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: appScrollPadding(
                  context,
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
                  const Center(child: Text('Sin citas.')),
                  const SizedBox(height: AppSpacing.md),
                  const ShareSalonCtaWidget(),
                ],
              );
            }
            final rows = _buildRows(calendar.items);
            final showPaginationFooter =
                calendar.isLoadingMore || calendar.paginationError != null;
            return ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: appScrollPadding(
                context,
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              itemCount: rows.length + (showPaginationFooter ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == rows.length) {
                  if (calendar.isLoadingMore) {
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
                  return Column(
                    children: [
                      Text(
                        userFacingError(
                          calendar.paginationError!,
                          calendar.paginationStackTrace,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.read(workCalendarProvider.notifier).loadMore(),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  );
                }
                final row = rows[i];
                return switch (row) {
                  _DayHeader(:final day) => _buildDayHeader(
                    context,
                    day: day,
                    label: dayFmt.format(day),
                    isFirst: i == 0,
                  ),
                  _AppointmentRow(:final appointment) => _AppointmentTile(
                    appointment: appointment,
                    timeLabel: timeFmt.format(appointment.startAt.toLocal()),
                    onManage: () async {
                      await showAppointmentStatusActions(context, appointment);
                      if (!mounted) return;
                      await _reloadAppointments();
                    },
                    onReport: () => context.push(
                      Uri(
                        path: '/report',
                        queryParameters: {
                          'targetType': 'user',
                          'targetId': appointment.clientId,
                          'targetLabel': 'Cliente',
                          'sourceAppointmentId': appointment.id,
                        },
                      ).toString(),
                    ),
                    onManageClientAccess: () =>
                        _manageClientAccess(appointment),
                    onTap: () async {
                      if (appointment.status == AppointmentStatus.confirmed &&
                          appointment.startAt.isBefore(DateTime.now())) {
                        final confirmed = await confirmAppointmentStatusAction(
                          context,
                          AppointmentStatus.completed,
                        );
                        if (!confirmed || !context.mounted) return;
                        try {
                          await getIt<AppointmentRepository>()
                              .changeAppointmentStatus(
                                appointmentId: appointment.id,
                                status: AppointmentStatus.completed,
                                idempotencyKey:
                                    'changeStatus_${appointment.id}_completed',
                              );
                          if (mounted) await _reloadAppointments();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(userFacingError(e))),
                          );
                        }
                      }
                    },
                  ),
                };
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDayHeader(
    BuildContext context, {
    required DateTime day,
    required String label,
    required bool isFirst,
  }) {
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 0 : AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        isToday ? 'Hoy · $label' : label,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
          color: isToday ? theme.colorScheme.primary : null,
        ),
      ),
    );
  }

  // TODO: reactivar cita manual
  // Future<void> _showManualDialog(BuildContext context, String salonId) async {
  //   final clientCtrl = TextEditingController();
  //   final services = await getIt<SalonRepository>().listServices(salonId);
  //   if (services.isEmpty || !context.mounted) return;
  //   var serviceId = services.first.id;
  //   final session = ref.read(sessionProvider).value;
  //   final start = DateTime.now().add(const Duration(hours: 2));
  //   final slot = DateTime(start.year, start.month, start.day, start.hour);
  //
  //   final ok = await showDialog<bool>(
  //     context: context,
  //     builder: (ctx) => AlertDialog(
  //       title: const Text('Cita manual'),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           TextField(
  //             controller: clientCtrl,
  //             decoration: const InputDecoration(labelText: 'UID del cliente'),
  //           ),
  //           DropdownButtonFormField<String>(
  //             initialValue: serviceId,
  //             items: services
  //                 .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
  //                 .toList(),
  //             onChanged: (v) => serviceId = v ?? serviceId,
  //             decoration: const InputDecoration(labelText: 'Servicio'),
  //           ),
  //         ],
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(ctx, false),
  //           child: const Text('Cancelar'),
  //         ),
  //         FilledButton(
  //           onPressed: () => Navigator.pop(ctx, true),
  //           child: const Text('Crear'),
  //         ),
  //       ],
  //     ),
  //   );
  //   if (ok != true || session == null) return;
  //   try {
  //     await getIt<AppointmentRepository>().createManualAppointment(
  //       salonId: salonId,
  //       serviceId: serviceId,
  //       barberId: session.id,
  //       clientId: clientCtrl.text.trim(),
  //       startAt: slot,
  //     );
  //     if (context.mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Cita manual creada.')),
  //       );
  //     }
  //   } catch (e) {
  //     if (context.mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text(userFacingError(e))),
  //       );
  //     }
  //   }
  // }
}

sealed class _CalendarRow {
  const _CalendarRow();
}

class _DayHeader extends _CalendarRow {
  const _DayHeader(this.day);
  final DateTime day;
}

class _AppointmentRow extends _CalendarRow {
  const _AppointmentRow(this.appointment);
  final Appointment appointment;
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({
    required this.appointment,
    required this.timeLabel,
    required this.onManage,
    required this.onReport,
    required this.onManageClientAccess,
    required this.onTap,
  });

  final Appointment appointment;
  final String timeLabel;
  final VoidCallback onManage;
  final VoidCallback onReport;
  final VoidCallback onManageClientAccess;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: ListTile(
          isThreeLine: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xxs,
          ),
          title: UserName(userId: appointment.clientId),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${appointment.serviceName} · $timeLabel'),
              Row(
                children: [
                  Expanded(
                    child: AppointmentIdLabelWidget(
                      appointmentId: appointment.id,
                    ),
                  ),
                  StatusBadgeWidget(label: appointment.status.labelEs),
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<_AppointmentMenuAction>(
            tooltip: 'Opciones de la cita',
            onSelected: (action) {
              switch (action) {
                case _AppointmentMenuAction.manage:
                  onManage();
                  break;
                case _AppointmentMenuAction.reportClient:
                  onReport();
                  break;
                case _AppointmentMenuAction.manageClientAccess:
                  onManageClientAccess();
                  break;
              }
            },
            itemBuilder: (context) => [
              if (businessStatusActionsFor(appointment).isNotEmpty)
                const PopupMenuItem(
                  value: _AppointmentMenuAction.manage,
                  child: Text('Gestionar cita'),
                ),
              const PopupMenuItem(
                value: _AppointmentMenuAction.manageClientAccess,
                child: Text('Bloquear o desbloquear cliente'),
              ),
              const PopupMenuItem(
                value: _AppointmentMenuAction.reportClient,
                child: Text('Reportar y bloquear cliente'),
              ),
            ],
          ),
          onLongPress: onManage,
          onTap: onTap,
        ),
      ),
    );
  }
}

enum _AppointmentMenuAction { manage, manageClientAccess, reportClient }
