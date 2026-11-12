import 'package:cloud_functions/cloud_functions.dart';
import 'package:jolom/services/user_directory/domain/user_directory_result.dart';

/// Directorio central de identidad de otros usuarios (lectura vía callable + caché).
class UserDirectoryService {
  UserDirectoryService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;
  final Map<String, _CacheEntry> _cache = {};

  static const Duration ttl = Duration(minutes: 15);

  /// Lectura única con caché en memoria.
  Future<UserDirectoryResult> get(String uid) async {
    if (uid.isEmpty) return MissingUser(uid: uid);

    final cached = _cache[uid];
    if (cached != null && !cached.isExpired) {
      return cached.result;
    }

    try {
      final results = await _fetch([uid]);
      final result = results[uid] ?? MissingUser(uid: uid);
      _cache[uid] = _CacheEntry(result);
      return result;
    } catch (_) {
      if (cached != null) return cached.result;
      rethrow;
    }
  }

  /// Precarga varios uids en una sola llamada (omite los que aún tienen caché válida).
  Future<Map<String, UserDirectoryResult>> getMany(List<String> uids) async {
    final out = <String, UserDirectoryResult>{};
    final missing = <String>[];

    for (final uid in uids) {
      if (uid.isEmpty) {
        out[uid] = MissingUser(uid: uid);
        continue;
      }
      final cached = _cache[uid];
      if (cached != null && !cached.isExpired) {
        out[uid] = cached.result;
      } else {
        missing.add(uid);
      }
    }

    if (missing.isEmpty) return out;

    final fetched = await _fetch(missing);
    for (final uid in missing) {
      final result = fetched[uid] ?? MissingUser(uid: uid);
      _cache[uid] = _CacheEntry(result);
      out[uid] = result;
    }
    return out;
  }

  void invalidate(String uid) => _cache.remove(uid);

  void clear() => _cache.clear();

  Future<Map<String, UserDirectoryResult>> _fetch(List<String> uids) async {
    final callable = _functions.httpsCallable('getUserDirectoryEntries');
    final result = await callable.call(<String, dynamic>{
      'uids': uids,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final rawEntries = data['entries'];
    final entriesMap = rawEntries is Map
        ? Map<String, dynamic>.from(rawEntries)
        : <String, dynamic>{};

    final mapped = <String, UserDirectoryResult>{};
    for (final uid in uids) {
      final entry = entriesMap[uid];
      mapped[uid] = _mapEntry(uid, entry);
    }
    return mapped;
  }

  UserDirectoryResult _mapEntry(String uid, Object? entry) {
    if (entry is! Map) return MissingUser(uid: uid);
    final map = Map<String, dynamic>.from(entry);
    final status = map['status'] as String? ?? 'missing';
    switch (status) {
      case 'hidden':
        return HiddenUser(uid: uid);
      case 'visible':
        final name = map['displayName'] as String?;
        final photo = map['photoUrl'] as String?;
        return VisibleUser(
          uid: uid,
          displayName: name?.trim().isNotEmpty == true ? name!.trim() : null,
          photoUrl: photo?.trim().isNotEmpty == true ? photo!.trim() : null,
        );
      case 'missing':
      default:
        return MissingUser(uid: uid);
    }
  }
}

class _CacheEntry {
  _CacheEntry(this.result) : storedAt = DateTime.now();

  final UserDirectoryResult result;
  final DateTime storedAt;

  bool get isExpired =>
      DateTime.now().difference(storedAt) > UserDirectoryService.ttl;
}
