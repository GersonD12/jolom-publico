import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jolom/features/app_update/domain/domain.dart';

class AppUpdateRepositoryImpl implements AppUpdateRepository {
  AppUpdateRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<AppUpdatePolicy> watchPolicy(AppUpdatePlatform platform) {
    return _firestore
        .collection('appConfig')
        .doc('settings')
        .snapshots()
        .map((snapshot) => _policyFrom(snapshot.data(), platform));
  }

  AppUpdatePolicy _policyFrom(
    Map<String, dynamic>? data,
    AppUpdatePlatform platform,
  ) {
    final appUpdate = data?['appUpdate'];
    if (appUpdate is! Map) return const AppUpdatePolicy.disabled();

    final platformKey = platform == AppUpdatePlatform.ios ? 'ios' : 'android';
    final rawPolicy = appUpdate[platformKey];
    if (rawPolicy is! Map) return const AppUpdatePolicy.disabled();

    final rawVersion = rawPolicy['requiredVersion'];
    final rawStoreUrl = rawPolicy['storeUrl'];
    final rawReleaseNotes = rawPolicy['releaseNotes'];
    return AppUpdatePolicy(
      enabled: rawPolicy['enabled'] == true,
      requiredVersion: rawVersion is String ? rawVersion.trim() : '',
      storeUrl: rawStoreUrl is String ? rawStoreUrl.trim() : '',
      releaseNotes: rawReleaseNotes is String ? rawReleaseNotes.trim() : '',
    );
  }
}
