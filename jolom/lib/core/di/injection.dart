import 'package:get_it/get_it.dart';
import 'package:jolom/features/appointment/application/use_cases/change_appointment_status_use_case.dart';
import 'package:jolom/features/appointment/application/use_cases/create_appointment_use_case.dart';
import 'package:jolom/features/appointment/application/use_cases/get_client_appointment_history_page_use_case.dart';
import 'package:jolom/features/appointment/application/use_cases/get_barber_appointments_page_use_case.dart';
import 'package:jolom/features/appointment/application/use_cases/watch_upcoming_client_appointments_use_case.dart';
import 'package:jolom/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:jolom/features/appointment/infrastructure/appointment_repository_impl.dart';
import 'package:jolom/features/app_update/application/application.dart';
import 'package:jolom/features/app_update/domain/domain.dart';
import 'package:jolom/features/app_update/infrastructure/infrastructure.dart';
import 'package:jolom/features/auth/domain/repositories/auth_repository.dart';
import 'package:jolom/features/auth/infrastructure/auth_repository_impl.dart';
import 'package:jolom/features/notification/domain/repositories/notification_repository.dart';
import 'package:jolom/features/notification/infrastructure/notification_repository_impl.dart';
import 'package:jolom/features/report/application/use_cases/submit_report_use_case.dart';
import 'package:jolom/features/report/application/use_cases/get_salon_client_block_status_use_case.dart';
import 'package:jolom/features/report/application/use_cases/set_salon_client_block_use_case.dart';
import 'package:jolom/features/report/domain/repositories/report_repository.dart';
import 'package:jolom/features/report/infrastructure/report_repository_impl.dart';
import 'package:jolom/features/salon/application/use_cases/create_salon_use_case.dart';
import 'package:jolom/features/salon/application/use_cases/find_nearby_salons_use_case.dart';
import 'package:jolom/features/salon/application/use_cases/invite_barber_use_case.dart';
import 'package:jolom/features/salon/application/use_cases/respond_to_invitation_use_case.dart';
import 'package:jolom/features/salon/domain/repositories/salon_repository.dart';
import 'package:jolom/features/salon/infrastructure/place_image_storage_service.dart';
import 'package:jolom/features/salon/infrastructure/salon_repository_impl.dart';
import 'package:jolom/services/image_compression/image_compression.dart';
import 'package:jolom/services/user_directory/user_directory.dart';

/// Instancia global de GetIt.
final getIt = GetIt.instance;

/// Registra dependencias compartidas (repositorios, servicios).
Future<void> setupDI() async {
  if (!getIt.isRegistered<AuthRepository>()) {
    getIt.registerLazySingleton<AuthRepository>(AuthRepositoryImpl.new);
  }

  if (!getIt.isRegistered<UserDirectoryService>()) {
    getIt.registerLazySingleton<UserDirectoryService>(UserDirectoryService.new);
  }

  if (!getIt.isRegistered<ImageCompressionService>()) {
    getIt.registerLazySingleton<ImageCompressionService>(
      ImageCompressionService.new,
    );
  }
  if (!getIt.isRegistered<PlaceImageStorageService>()) {
    getIt.registerLazySingleton<PlaceImageStorageService>(
      () => PlaceImageStorageService(
        compression: getIt<ImageCompressionService>(),
      ),
    );
  }

  if (!getIt.isRegistered<SalonRepository>()) {
    getIt.registerLazySingleton<SalonRepository>(SalonRepositoryImpl.new);
  }
  if (!getIt.isRegistered<AppointmentRepository>()) {
    getIt.registerLazySingleton<AppointmentRepository>(
      AppointmentRepositoryImpl.new,
    );
  }
  if (!getIt.isRegistered<AppUpdateRepository>()) {
    getIt.registerLazySingleton<AppUpdateRepository>(
      AppUpdateRepositoryImpl.new,
    );
  }
  if (!getIt.isRegistered<NotificationRepository>()) {
    getIt.registerLazySingleton<NotificationRepository>(
      NotificationRepositoryImpl.new,
    );
  }
  if (!getIt.isRegistered<ReportRepository>()) {
    getIt.registerLazySingleton<ReportRepository>(ReportRepositoryImpl.new);
  }

  if (!getIt.isRegistered<CreateSalonUseCase>()) {
    getIt.registerLazySingleton(
      () => CreateSalonUseCase(getIt<SalonRepository>()),
    );
  }
  if (!getIt.isRegistered<FindNearbySalonsUseCase>()) {
    getIt.registerLazySingleton(
      () => FindNearbySalonsUseCase(getIt<SalonRepository>()),
    );
  }
  if (!getIt.isRegistered<WatchAppUpdatePolicyUseCase>()) {
    getIt.registerLazySingleton(
      () => WatchAppUpdatePolicyUseCase(getIt<AppUpdateRepository>()),
    );
  }
  if (!getIt.isRegistered<InviteBarberUseCase>()) {
    getIt.registerLazySingleton(
      () => InviteBarberUseCase(getIt<SalonRepository>()),
    );
  }
  if (!getIt.isRegistered<RespondToInvitationUseCase>()) {
    getIt.registerLazySingleton(
      () => RespondToInvitationUseCase(getIt<SalonRepository>()),
    );
  }
  if (!getIt.isRegistered<CreateAppointmentUseCase>()) {
    getIt.registerLazySingleton(
      () => CreateAppointmentUseCase(getIt<AppointmentRepository>()),
    );
  }
  if (!getIt.isRegistered<ChangeAppointmentStatusUseCase>()) {
    getIt.registerLazySingleton(
      () => ChangeAppointmentStatusUseCase(getIt<AppointmentRepository>()),
    );
  }
  if (!getIt.isRegistered<GetClientAppointmentHistoryPageUseCase>()) {
    getIt.registerLazySingleton(
      () => GetClientAppointmentHistoryPageUseCase(
        getIt<AppointmentRepository>(),
      ),
    );
  }
  if (!getIt.isRegistered<GetBarberAppointmentsPageUseCase>()) {
    getIt.registerLazySingleton(
      () => GetBarberAppointmentsPageUseCase(getIt<AppointmentRepository>()),
    );
  }
  if (!getIt.isRegistered<WatchUpcomingClientAppointmentsUseCase>()) {
    getIt.registerLazySingleton(
      () => WatchUpcomingClientAppointmentsUseCase(
        getIt<AppointmentRepository>(),
      ),
    );
  }
  if (!getIt.isRegistered<SubmitReportUseCase>()) {
    getIt.registerLazySingleton(
      () => SubmitReportUseCase(getIt<ReportRepository>()),
    );
  }
  if (!getIt.isRegistered<GetSalonClientBlockStatusUseCase>()) {
    getIt.registerLazySingleton(
      () => GetSalonClientBlockStatusUseCase(getIt<ReportRepository>()),
    );
  }
  if (!getIt.isRegistered<SetSalonClientBlockUseCase>()) {
    getIt.registerLazySingleton(
      () => SetSalonClientBlockUseCase(getIt<ReportRepository>()),
    );
  }
}
