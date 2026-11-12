import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/features/app_update/application/application.dart';
import 'package:jolom/features/app_update/domain/domain.dart';
import 'package:package_info_plus/package_info_plus.dart';

final appUpdateStatusProvider = StreamProvider<AppUpdateStatus>((ref) async* {
  ref.keepAlive();

  final platform = switch (defaultTargetPlatform) {
    TargetPlatform.iOS => AppUpdatePlatform.ios,
    TargetPlatform.android => AppUpdatePlatform.android,
    _ => null,
  };

  final packageInfo = await PackageInfo.fromPlatform();
  final installed = InstalledAppVersion(version: packageInfo.version);

  if (platform == null) {
    yield AppUpdateStatus(
      policy: const AppUpdatePolicy.disabled(),
      installed: installed,
      updateRequired: false,
    );
    return;
  }

  final policies = getIt<WatchAppUpdatePolicyUseCase>().execute(platform);
  await for (final policy in policies) {
    yield AppUpdateStatus(
      policy: policy,
      installed: installed,
      updateRequired: policy.requiresUpdate(installed),
    );
  }
});
