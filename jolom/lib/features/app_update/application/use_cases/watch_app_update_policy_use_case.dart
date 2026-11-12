import '../../domain/domain.dart';

class WatchAppUpdatePolicyUseCase {
  const WatchAppUpdatePolicyUseCase(this._repository);

  final AppUpdateRepository _repository;

  Stream<AppUpdatePolicy> execute(AppUpdatePlatform platform) {
    return _repository.watchPolicy(platform);
  }
}
