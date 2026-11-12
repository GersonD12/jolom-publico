import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/app/view/splash_screen.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/navigation/unsaved_changes_route_guard.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/providers/session_provider.dart';
import 'package:jolom/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:jolom/features/appointment/presentation/screens/availability_screen.dart';
import 'package:jolom/features/appointment/presentation/screens/my_appointments_screen.dart';
import 'package:jolom/features/appointment/presentation/screens/stats_screen.dart';
import 'package:jolom/features/appointment/presentation/screens/work_calendar_screen.dart';
import 'package:jolom/features/appointment/presentation/screens/work_home_screen.dart';
import 'package:jolom/features/auth/presentation/screens/login_screen.dart';
import 'package:jolom/features/auth/presentation/screens/account_deletion_pending_screen.dart';
import 'package:jolom/features/auth/presentation/screens/account_restricted_screen.dart';
import 'package:jolom/features/auth/presentation/screens/appearance_screen.dart';
import 'package:jolom/features/auth/presentation/screens/business_screen.dart';
import 'package:jolom/features/auth/presentation/screens/email_link_completion_screen.dart';
import 'package:jolom/features/auth/presentation/screens/profile_screen.dart';
import 'package:jolom/features/notification/presentation/screens/notifications_screen.dart';
import 'package:jolom/features/report/presentation/screens/report_screen.dart';
import 'package:jolom/features/salon/domain/repositories/salon_repository.dart';
import 'package:jolom/features/salon/presentation/screens/client_home_screen.dart';
import 'package:jolom/features/salon/presentation/screens/complete_salon_setup_screen.dart';
import 'package:jolom/features/salon/presentation/screens/configure_initial_schedule_screen.dart';
import 'package:jolom/features/salon/presentation/screens/create_first_service_screen.dart';
import 'package:jolom/features/salon/presentation/screens/explore_screen.dart';
import 'package:jolom/features/salon/presentation/screens/invitations_screen.dart';
import 'package:jolom/features/salon/presentation/screens/salon_detail_screen.dart';
import 'package:jolom/features/salon/presentation/screens/salon_qr_screen.dart';
import 'package:jolom/features/salon/presentation/screens/salon_settings_screen.dart';
import 'package:jolom/features/salon/presentation/screens/team_screen.dart';
import 'package:jolom/features/salon/presentation/screens/edit_salon_profile_screen.dart';
import 'package:jolom/features/salon/presentation/screens/work_salon_screen.dart';
import 'package:jolom/features/shell/presentation/screens/shell_screens.dart';
import 'package:jolom/services/fcm_service.dart';
import 'package:jolom/services/user_profile_sync.dart';

/// Rutas de la aplicación.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const emailLink = '/__/auth/links';
  static const home = '/home';
  static const explore = '/explore';
  static const appointments = '/appointments';
  static const profile = '/profile';
  static const appearance = '/profile/appearance';
  static const business = '/profile/business';
  static const completeSalonSetup = '/onboarding/salon/setup';
  static const createFirstService = '/onboarding/salon/service';
  static const configureInitialSchedule = '/onboarding/salon/schedule';
  static const accountDeletion = '/account-deletion';
  static const accountRestriction = '/account-restricted';
}

/// Página sin transición para cambios de tab en el shell.
NoTransitionPage<void> shellPage({
  required LocalKey key,
  required Widget child,
}) {
  return NoTransitionPage<void>(key: key, child: child);
}

/// Notifier que dispara refresh de GoRouter cuando cambia la sesión.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(sessionProvider, (prev, next) {
      _scheduleRefresh();
      if (next.asData?.value == null) _bootstrappedUid = null;
    });
    ref.listen(accountProfileProvider, (prev, next) {
      _scheduleRefresh();
      final profile = next.asData?.value;
      final user = ref.read(sessionProvider).asData?.value;
      if (user != null &&
          profile != null &&
          !profile.accountStatus.blocksAccess &&
          !profile.isDeleted &&
          !profile.isModerationBlocked &&
          _bootstrappedUid != user.id) {
        _bootstrappedUid = user.id;
        // Diferir side-effects: evitar mutar Auth/providers a mitad del build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          UserProfileSync.syncAfterLogin();
          FcmService.registerTokenAfterLogin();
          _completePendingBooking(ref);
        });
      }
    });
  }

  String? _bootstrappedUid;
  bool _refreshScheduled = false;

  /// Evita redirect de GoRouter durante un build en curso (Riverpod listen).
  void _scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      notifyListeners();
    });
  }

  Future<void> _completePendingBooking(Ref ref) async {
    final pending = ref.read(pendingBookingProvider);
    if (pending == null) return;
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
    } catch (_) {
      // El usuario puede reintentar desde la ficha.
    }
  }
}

bool _isPublicPath(String location) {
  return location == AppRoutes.login ||
      location == AppRoutes.emailLink ||
      location == AppRoutes.splash ||
      location == AppRoutes.explore ||
      location == AppRoutes.home ||
      location.startsWith('/appointments') ||
      location.startsWith('/profile') ||
      location.startsWith('/salon/') ||
      location.startsWith('/s/');
}

bool _requiresAuth(String location) {
  return location.startsWith('/notifications') ||
      location.startsWith('/invitations') ||
      location.startsWith('/report') ||
      location == AppRoutes.appearance ||
      location == AppRoutes.business ||
      location == AppRoutes.accountDeletion ||
      location == AppRoutes.accountRestriction ||
      location.startsWith('/onboarding') ||
      location.startsWith('/work');
}

/// GoRouter con redirect según estado de autenticación.
final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  final availabilityExitGuard = UnsavedChangesRouteGuard();
  String? pendingInitialLocation;

  String? takePendingInitialLocation() {
    final location = pendingInitialLocation;
    pendingInitialLocation = null;
    return location;
  }

  final editSalonExitGuard = UnsavedChangesRouteGuard();
  final completeSalonSetupExitGuard = UnsavedChangesRouteGuard();
  final firstServiceExitGuard = UnsavedChangesRouteGuard();
  final initialScheduleExitGuard = UnsavedChangesRouteGuard();

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final accessStatus = ref.read(appAccessStatusProvider);
      final location = state.matchedLocation;

      if (accessStatus == AppAccessStatus.loading) {
        // Quedarse en /login evita login→splash→destino tras auth (carrera
        // con context.go mientras hidrata el perfil).
        if (location == AppRoutes.splash ||
            location == AppRoutes.login ||
            location == AppRoutes.emailLink) {
          return null;
        }
        // Android entrega el App Link antes de que Auth/Firestore terminen de
        // hidratarse. Conservarlo evita perder `/s/:salonId` al mostrar splash.
        pendingInitialLocation ??= state.uri.toString();
        return AppRoutes.splash;
      }

      if (accessStatus == AppAccessStatus.sessionError) {
        return location == AppRoutes.login ? null : AppRoutes.login;
      }

      if (accessStatus == AppAccessStatus.unauthenticated) {
        if (_requiresAuth(location)) {
          final from = Uri.encodeComponent(state.uri.toString());
          return '${AppRoutes.login}?from=$from';
        }
        if (location == AppRoutes.splash) {
          final pending = takePendingInitialLocation();
          if (pending != null) return pending;
          return AppRoutes.home;
        }
        if (_isPublicPath(location)) return null;
        return AppRoutes.home;
      }

      if (accessStatus == AppAccessStatus.blocked) {
        return location == AppRoutes.accountDeletion
            ? null
            : AppRoutes.accountDeletion;
      }
      if (accessStatus == AppAccessStatus.restricted) {
        return location == AppRoutes.accountRestriction
            ? null
            : AppRoutes.accountRestriction;
      }
      if (location == AppRoutes.accountDeletion) return AppRoutes.home;
      if (location == AppRoutes.accountRestriction) return AppRoutes.home;

      if (location == AppRoutes.splash) {
        final pending = takePendingInitialLocation();
        if (pending != null) return pending;
        return AppRoutes.home;
      }

      if (location == AppRoutes.login) {
        final pending = ref.read(pendingBookingProvider);
        if (pending != null) {
          return AppRoutes.appointments;
        }
        final from = state.uri.queryParameters['from'];
        if (from != null && from.isNotEmpty) {
          final decoded = Uri.decodeComponent(from);
          if (decoded.startsWith('/') &&
              decoded != AppRoutes.login &&
              !decoded.startsWith('${AppRoutes.login}?') &&
              decoded != AppRoutes.splash) {
            return decoded;
          }
        }
        // Nunca quedarse en /login autenticado (push encima del shell no
        // siempre se limpia solo con redirect a la misma ruta del shell).
        return AppRoutes.home;
      }

      if (location == AppRoutes.emailLink) return AppRoutes.home;

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.emailLink,
        builder: (context, state) =>
            EmailLinkCompletionScreen(emailLink: state.uri.toString()),
      ),
      GoRoute(
        path: AppRoutes.accountDeletion,
        builder: (context, state) => const AccountDeletionPendingScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountRestriction,
        builder: (context, state) => const AccountRestrictedScreen(),
      ),
      GoRoute(
        path: AppRoutes.appearance,
        builder: (context, state) => const AppearanceScreen(),
      ),
      GoRoute(
        path: AppRoutes.business,
        builder: (context, state) => const BusinessScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => ClientShellScreen(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) =>
                shellPage(key: state.pageKey, child: const ClientHomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.explore,
            pageBuilder: (context, state) =>
                shellPage(key: state.pageKey, child: const ExploreScreen()),
          ),
          GoRoute(
            path: AppRoutes.appointments,
            pageBuilder: (context, state) => shellPage(
              key: state.pageKey,
              child: const MyAppointmentsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) =>
                shellPage(key: state.pageKey, child: const ProfileScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/salon/:salonId',
        builder: (context, state) =>
            SalonDetailScreen(salonId: state.pathParameters['salonId']!),
      ),
      GoRoute(
        path: '/s/:salonId',
        builder: (context, state) {
          final salonId = state.pathParameters['salonId']!;
          // Atribución QR al abrir deep link.
          getIt<SalonRepository>().recordQrOpen(salonId);
          return SalonDetailScreen(salonId: salonId);
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/invitations',
        builder: (context, state) => const InvitationsScreen(),
      ),
      GoRoute(
        path: '/report',
        builder: (context, state) {
          final targetType = state.uri.queryParameters['targetType'] ?? '';
          final targetId = state.uri.queryParameters['targetId'] ?? '';
          if (!{'salon', 'user'}.contains(targetType) || targetId.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('No se pudo identificar qué reportar.')),
            );
          }
          return ReportScreen(
            targetType: targetType,
            targetId: targetId,
            targetLabel: state.uri.queryParameters['targetLabel'],
            sourceAppointmentId:
                state.uri.queryParameters['sourceAppointmentId'],
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) => WorkShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/work',
            pageBuilder: (context, state) =>
                shellPage(key: state.pageKey, child: const WorkHomeScreen()),
          ),
          GoRoute(
            path: '/work/calendar',
            pageBuilder: (context, state) => shellPage(
              key: state.pageKey,
              child: const WorkCalendarScreen(),
            ),
          ),
          GoRoute(
            path: '/work/availability',
            onExit: (context, state) {
              final container = ProviderScope.containerOf(context);
              final notifier = container.read(
                availabilityUnsavedChangesProvider.notifier,
              );
              return availabilityExitGuard.canExit(
                context: context,
                canRemainInRoute:
                    container.read(appAccessStatusProvider) ==
                    AppAccessStatus.active,
                hasUnsavedChanges: container.read(
                  availabilityUnsavedChangesProvider,
                ),
                clearUnsavedChanges: notifier.clear,
              );
            },
            pageBuilder: (context, state) => shellPage(
              key: state.pageKey,
              child: const AvailabilityScreen(),
            ),
          ),
          GoRoute(
            path: '/work/salon',
            pageBuilder: (context, state) =>
                shellPage(key: state.pageKey, child: const WorkSalonScreen()),
          ),
          GoRoute(
            path: '/work/team',
            pageBuilder: (context, state) =>
                shellPage(key: state.pageKey, child: const TeamScreen()),
          ),
          GoRoute(
            path: '/work/qr',
            pageBuilder: (context, state) =>
                shellPage(key: state.pageKey, child: const SalonQrScreen()),
          ),
          GoRoute(
            path: '/work/salon/settings',
            pageBuilder: (context, state) => shellPage(
              key: state.pageKey,
              child: const SalonSettingsScreen(),
            ),
          ),
          GoRoute(
            path: '/work/stats',
            pageBuilder: (context, state) =>
                shellPage(key: state.pageKey, child: const StatsScreen()),
          ),
        ],
      ),
      // Flujo interno de pantalla completa: queda fuera del shell para que la
      // navegación inferior no cubra el formulario ni su acción Guardar.
      GoRoute(
        path: '/work/salon/edit',
        onExit: (context, state) {
          final container = ProviderScope.containerOf(context);
          final notifier = container.read(
            editSalonUnsavedChangesProvider.notifier,
          );
          return editSalonExitGuard.canExit(
            context: context,
            canRemainInRoute:
                container.read(appAccessStatusProvider) ==
                AppAccessStatus.active,
            hasUnsavedChanges: container.read(editSalonUnsavedChangesProvider),
            clearUnsavedChanges: notifier.clear,
          );
        },
        builder: (context, state) => const EditSalonProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.completeSalonSetup,
        onExit: (context, state) {
          final container = ProviderScope.containerOf(context);
          final notifier = container.read(
            completeSalonSetupUnsavedChangesProvider.notifier,
          );
          return completeSalonSetupExitGuard.canExit(
            context: context,
            canRemainInRoute:
                container.read(appAccessStatusProvider) ==
                AppAccessStatus.active,
            hasUnsavedChanges: container.read(
              completeSalonSetupUnsavedChangesProvider,
            ),
            clearUnsavedChanges: notifier.clear,
          );
        },
        builder: (context, state) => CompleteSalonSetupScreen(
          salonId: state.uri.queryParameters['salonId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.createFirstService,
        onExit: (context, state) {
          final container = ProviderScope.containerOf(context);
          final notifier = container.read(
            firstServiceUnsavedChangesProvider.notifier,
          );
          return firstServiceExitGuard.canExit(
            context: context,
            canRemainInRoute:
                container.read(appAccessStatusProvider) ==
                AppAccessStatus.active,
            hasUnsavedChanges: container.read(
              firstServiceUnsavedChangesProvider,
            ),
            clearUnsavedChanges: notifier.clear,
          );
        },
        builder: (context, state) => CreateFirstServiceScreen(
          salonId: state.uri.queryParameters['salonId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.configureInitialSchedule,
        onExit: (context, state) {
          final container = ProviderScope.containerOf(context);
          final notifier = container.read(
            initialScheduleUnsavedChangesProvider.notifier,
          );
          return initialScheduleExitGuard.canExit(
            context: context,
            canRemainInRoute:
                container.read(appAccessStatusProvider) ==
                AppAccessStatus.active,
            hasUnsavedChanges: container.read(
              initialScheduleUnsavedChangesProvider,
            ),
            clearUnsavedChanges: notifier.clear,
          );
        },
        builder: (context, state) => ConfigureInitialScheduleScreen(
          salonId: state.uri.queryParameters['salonId'] ?? '',
        ),
      ),
    ],
  );
});
