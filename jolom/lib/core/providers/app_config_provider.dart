import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream del flag global `appConfig/settings.canCreateSalon`.
///
/// Si el documento no existe o el campo falta, se trata como `false`.
final canCreateSalonProvider = StreamProvider<bool>((ref) {
  ref.keepAlive();
  return FirebaseFirestore.instance
      .collection('appConfig')
      .doc('settings')
      .snapshots()
      .map((snap) {
        if (!snap.exists) return false;
        final data = snap.data();
        return data?['canCreateSalon'] == true;
      });
});
