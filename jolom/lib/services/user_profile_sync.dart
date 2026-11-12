import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Persiste identidad de sesión en `users/{uid}` (fuente para notificaciones).
class UserProfileSync {
  UserProfileSync._();

  /// Tras login: escribe displayName/photoUrl en Firestore si Auth los trae.
  static Future<void> syncAfterLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    final name = user.displayName?.trim();
    final photo = user.photoURL?.trim();
    final email = user.email?.trim().toLowerCase();

    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (name != null && name.isNotEmpty) {
      data['displayName'] = name;
    }
    if (photo != null && photo.isNotEmpty) {
      data['photoUrl'] = photo;
    }
    if (email != null && email.isNotEmpty) {
      data['email'] = email;
    }

    // Solo updatedAt no aporta; evita writes vacíos.
    if (data.length <= 1) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserProfileSync skipped: $e');
      }
    }
  }
}
