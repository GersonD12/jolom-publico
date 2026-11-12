import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jolom/features/notification/domain/entities/appointment_notification_payload.dart';

/// Canal Android compartido con el default FCM del Manifest.
const String kFcmAndroidChannelId = 'jolom_appointments';

/// Handler en isolate de background (requerido por firebase_messaging).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // El payload ya incluye `notification`; el tray del sistema lo muestra.
}

/// Callback al abrir una notificación de cita con destino explícito.
typedef AppointmentNotificationOpenCallback =
    void Function(
      String appointmentId,
      AppointmentNotificationOpenMode openMode,
    );

/// Registro de token FCM y presentación de pushes en primer plano.
class FcmService {
  FcmService._();

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static AppointmentNotificationOpenCallback? _onAppointmentOpen;

  /// Inicializa handlers y canal. Llamar tras [Firebase.initializeApp].
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        kFcmAndroidChannelId,
        'Citas',
        description: 'Notificaciones de citas y reservas',
        importance: Importance.high,
      ),
    );

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_onRemoteMessageOpened);
  }

  /// Enlaza navegación al tocar push (llamar con [ProviderScope] ya montado).
  static Future<void> attachAppointmentOpenHandler(
    AppointmentNotificationOpenCallback handler,
  ) async {
    _onAppointmentOpen = handler;
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _onRemoteMessageOpened(initial);
    }
  }

  static void _onLocalNotificationTap(NotificationResponse response) {
    final payload =
        AppointmentNotificationPayload.tryParseLocalNotificationPayload(
          response.payload,
        );
    _openAppointment(
      payload,
      source: 'notificación local',
      diagnosticPayload: response.payload,
    );
  }

  static void _onRemoteMessageOpened(RemoteMessage message) {
    final payload = AppointmentNotificationPayload.tryParse(message.data);
    _openAppointment(
      payload,
      source: 'notificación remota',
      diagnosticPayload: message.data,
    );
  }

  static void _openAppointment(
    AppointmentNotificationPayload? payload, {
    required String source,
    required Object? diagnosticPayload,
  }) {
    if (payload == null) {
      if (kDebugMode) {
        debugPrint(
          'FCM: $source ignorada; payload de cita incompleto o inválido: '
          '$diagnosticPayload',
        );
      }
      return;
    }
    _onAppointmentOpen?.call(payload.appointmentId, payload.openMode);
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title =
        notification?.title ?? message.data['title'] as String? ?? 'Jolom';
    final body = notification?.body ?? message.data['body'] as String? ?? '';
    if (title.isEmpty && body.isEmpty) return;

    final appointmentPayload = AppointmentNotificationPayload.tryParse(
      message.data,
    );

    await _local.show(
      notification?.hashCode ?? message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          kFcmAndroidChannelId,
          'Citas',
          channelDescription: 'Notificaciones de citas y reservas',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: appointmentPayload?.toLocalNotificationPayload(),
    );
  }

  /// True si el OS autoriza notificaciones (authorized o provisional).
  static Future<bool> areNotificationsEnabled() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Abre Ajustes de la app para que el usuario active notificaciones.
  static Future<void> openSystemNotificationSettings() async {
    await Geolocator.openAppSettings();
  }

  /// Registro de token FCM después del login (regla del proyecto).
  static Future<void> registerTokenAfterLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      final androidPlugin = _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();

      final token = await messaging.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      messaging.onTokenRefresh.listen((newToken) async {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'fcmTokens': FieldValue.arrayUnion([newToken]),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {
          // Una cuenta bloqueada o eliminada no puede registrar tokens nuevos.
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM register skipped: $e');
      }
    }
  }

  /// Quita el token FCM de Firestore e invalida el del dispositivo.
  /// Llamar **antes** de [FirebaseAuth.signOut].
  static Future<void> unregisterTokenOnLogout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmTokens': FieldValue.arrayRemove([token]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await messaging.deleteToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM unregister skipped: $e');
      }
    }
  }
}
