import '../entities/app_update_policy_entity.dart';

abstract class AppUpdateRepository {
  Stream<AppUpdatePolicy> watchPolicy(AppUpdatePlatform platform);
}
