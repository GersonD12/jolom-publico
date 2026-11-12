import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:jolom/core/domain/entities/user_entity.dart';
import 'package:jolom/features/auth/domain/repositories/auth_repository.dart';
import 'package:jolom/services/fcm_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Implementación de [AuthRepository] sobre Firebase Auth.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _db;
  bool _googleInitialized = false;

  UserEntity _mapUser(User user) {
    return UserEntity(
      id: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      isAnonymous: user.isAnonymous,
    );
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await _googleSignIn.initialize();
    _googleInitialized = true;
  }

  String _randomNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  Stream<UserEntity?> authStateChanges() {
    return _auth.authStateChanges().map((user) {
      if (user == null) return null;
      return _mapUser(user);
    });
  }

  @override
  UserEntity? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _mapUser(user);
  }

  @override
  Future<void> sendEmailSignInLink(String email) async {
    final projectId = Firebase.app().options.projectId;
    const applicationId = String.fromEnvironment(
      'APP_ID',
      defaultValue: 'com.example.jolom',
    );

    await _auth.setLanguageCode('es');
    await _auth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: ActionCodeSettings(
        url: 'https://$projectId.firebaseapp.com/auth/email-complete',
        handleCodeInApp: true,
        androidPackageName: applicationId,
        androidInstallApp: true,
        iOSBundleId: applicationId,
      ),
    );
  }

  @override
  bool isEmailSignInLink(String emailLink) {
    return _auth.isSignInWithEmailLink(_absoluteEmailLink(emailLink));
  }

  @override
  Future<UserEntity> signInWithEmailLink({
    required String email,
    required String emailLink,
  }) async {
    final credential = await _auth.signInWithEmailLink(
      email: email,
      emailLink: _absoluteEmailLink(emailLink),
    );
    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase Auth no devolvió usuario tras vínculo');
    }
    return _mapUser(user);
  }

  @override
  Future<UserEntity> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase Auth no devolvió usuario tras contraseña');
    }
    return _mapUser(user);
  }

  String _absoluteEmailLink(String emailLink) {
    final uri = Uri.parse(emailLink);
    if (uri.hasScheme) return emailLink;
    final projectId = Firebase.app().options.projectId;
    return Uri(
      scheme: 'https',
      host: '$projectId.firebaseapp.com',
      path: uri.path,
      query: uri.hasQuery ? uri.query : null,
      fragment: uri.hasFragment ? uri.fragment : null,
    ).toString();
  }

  @override
  Future<UserEntity> signInWithGoogle() async {
    await _ensureGoogleInitialized();
    final account = await _googleSignIn.authenticate();
    final googleAuth = account.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw StateError('Google Sign-In no devolvió idToken');
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCred = await _auth.signInWithCredential(credential);
    final user = userCred.user;
    if (user == null) {
      throw StateError('Firebase Auth no devolvió usuario tras Google Sign-In');
    }
    return _mapUser(user);
  }

  @override
  Future<UserEntity> signInWithApple() async {
    final rawNonce = _randomNonce();
    final nonce = _sha256ofString(rawNonce);
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
      accessToken: appleCredential.authorizationCode,
    );
    final userCred = await _auth.signInWithCredential(oauthCredential);
    final user = userCred.user;
    if (user == null) {
      throw StateError('Firebase Auth no devolvió usuario tras Apple Sign-In');
    }

    // Apple solo envía el nombre en el primer login.
    final given = appleCredential.givenName;
    final family = appleCredential.familyName;
    if ((user.displayName == null || user.displayName!.isEmpty) &&
        (given != null || family != null)) {
      final displayName = [given, family].whereType<String>().join(' ').trim();
      if (displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
        await user.reload();
        return _mapUser(_auth.currentUser!);
      }
    }
    return _mapUser(user);
  }

  @override
  Future<void> signOut() async {
    // Quitar token FCM mientras aún hay sesión (escritura a users/{uid}).
    await FcmService.unregisterTokenOnLogout();
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignorar si Google no estaba inicializado o no había sesión.
    }
    await _auth.signOut();
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('No hay sesión para actualizar el nombre');
    }
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('El nombre no puede estar vacío');
    }

    await user.updateDisplayName(trimmed);
    await user.reload();
    await _db.collection('users').doc(user.uid).set({
      'displayName': trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<UserEntity?> fetchUserProfile(String uid) async {
    if (uid.isEmpty) return null;
    final snap = await _db.collection('users').doc(uid).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return UserEntity.fromFirestoreMap(
      uid,
      data,
      isAnonymous: _auth.currentUser?.isAnonymous ?? false,
    );
  }

  @override
  Stream<UserEntity?> watchUserProfile(String uid) {
    if (uid.isEmpty) return Stream.value(null);
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      final provisioned =
          data.containsKey('isBanned') &&
          data.containsKey('isDeleted') &&
          data.containsKey('accountStatus');
      if (!provisioned) return null;
      return UserEntity.fromFirestoreMap(
        uid,
        data,
        isAnonymous: _auth.currentUser?.isAnonymous ?? false,
      );
    });
  }
}
