import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Mensaje legible para el usuario final.
///
/// En debug imprime el detalle técnico en consola; la UI nunca debe mostrar
/// el string crudo de Firebase/excepciones.
String userFacingError(Object error, [StackTrace? stackTrace]) {
  if (kDebugMode) {
    debugPrint('Error técnico: $error');
    if (stackTrace != null) {
      debugPrint('$stackTrace');
    }
  }

  if (error is FirebaseException) {
    final mapped = _mapCode(error.code);
    if (mapped != null) return mapped;

    // Callables suelen traer copy en español en `message` (ej. failed-precondition).
    final message = error.message?.trim();
    if (message != null &&
        message.isNotEmpty &&
        !_looksTechnical(message) &&
        !_isAuthChannelError(message)) {
      return message;
    }
  }

  // Auth a veces llega como string con el código embebido.
  final raw = error.toString();
  if (_isAuthChannelError(raw)) {
    return 'No pudimos conectar con el servicio de acceso. '
        'Intenta de nuevo en unos minutos.';
  }
  for (final entry in _substringMappings.entries) {
    if (raw.contains(entry.key)) return entry.value;
  }

  return 'No se pudo completar la acción. Intenta de nuevo.';
}

/// Detecta errores internos del canal nativo de Firebase Auth (Pigeon).
///
/// Estos identificadores son útiles para diagnóstico, pero nunca deben llegar
/// a la interfaz porque no le indican al usuario cómo continuar.
bool _isAuthChannelError(String raw) {
  final lower = raw.toLowerCase();
  return lower.contains('firebase_auth_platform_interface') ||
      lower.contains('firebaseauthhostapi') ||
      (lower.contains('channel-error') && lower.contains('firebase_auth')) ||
      (lower.contains('unable to establish connection on channel') &&
          lower.contains('firebase'));
}

/// Evita mostrar dumps técnicos si el message no es copy de producto.
bool _looksTechnical(String message) {
  final lower = message.toLowerCase();
  return lower.contains('exception') ||
      lower.contains('stack') ||
      lower.contains('null check') ||
      lower.contains('flutter.pigeon') ||
      lower.contains('platform_interface') ||
      lower.contains('hostapi') ||
      lower.startsWith('[') ||
      lower.contains('http://') ||
      lower.contains('https://');
}

String? _mapCode(String code) {
  switch (code) {
    case 'permission-denied':
      return 'No tienes permiso para ver esta información.';
    case 'unavailable':
    case 'deadline-exceeded':
      return 'El servicio no está disponible. Intenta de nuevo.';
    case 'not-found':
      return 'No se encontró la información solicitada.';
    case 'network-request-failed':
      return 'Sin conexión. Revisa tu red e intenta de nuevo.';
    case 'too-many-requests':
      return 'Demasiados intentos. Espera un momento.';
    case 'invalid-email':
      return 'El email no es válido.';
    case 'expired-action-code':
      return 'Este vínculo venció. Solicita uno nuevo.';
    case 'invalid-action-code':
      return 'Este vínculo no es válido o ya fue utilizado.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'INVALID_LOGIN_CREDENTIALS':
      return 'Email o contraseña incorrectos.';
    case 'email-already-in-use':
      return 'Ya existe una cuenta con ese email.';
    case 'weak-password':
      return 'La contraseña debe tener al menos 6 caracteres.';
    case 'user-disabled':
      return 'Esta cuenta está deshabilitada.';
    case 'requires-recent-login':
      return 'Por seguridad, vuelve a iniciar sesión e intenta de nuevo.';
    case 'cancelled':
    case 'aborted':
      return 'La acción se canceló.';
    default:
      return null;
  }
}

const _substringMappings = <String, String>{
  'invalid-email': 'El email no es válido.',
  'expired-action-code': 'Este vínculo venció. Solicita uno nuevo.',
  'invalid-action-code': 'Este vínculo no es válido o ya fue utilizado.',
  'user-not-found': 'Email o contraseña incorrectos.',
  'INVALID_LOGIN_CREDENTIALS': 'Email o contraseña incorrectos.',
  'invalid-credential': 'Email o contraseña incorrectos.',
  'wrong-password': 'Email o contraseña incorrectos.',
  'email-already-in-use': 'Ya existe una cuenta con ese email.',
  'weak-password': 'La contraseña debe tener al menos 6 caracteres.',
  'network-request-failed': 'Sin conexión. Revisa tu red e intenta de nuevo.',
  'too-many-requests': 'Demasiados intentos. Espera un momento.',
  'permission-denied': 'No tienes permiso para ver esta información.',
  'PERMISSION_DENIED': 'No tienes permiso para ver esta información.',
};
