import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/core/errors/user_facing_error.dart';

void main() {
  group('userFacingError', () {
    test('traduce los códigos conocidos de Firebase Auth', () {
      final error = FirebaseException(
        plugin: 'firebase_auth',
        code: 'email-already-in-use',
      );

      expect(userFacingError(error), 'Ya existe una cuenta con ese email.');
    });

    test('oculta el nombre técnico del canal de registro', () {
      const error =
          '"dev.flutter.pigeon.firebase_auth_platform_interface.'
          'FirebaseAuthHostApi.createUserWithEmailAndPassword".';

      final message = userFacingError(error);

      expect(
        message,
        'No pudimos conectar con el servicio de acceso. '
        'Intenta de nuevo en unos minutos.',
      );
      expect(message, isNot(contains('firebase')));
      expect(message, isNot(contains('pigeon')));
    });

    test('oculta el canal técnico cuando Firebase lo envuelve', () {
      final error = FirebaseException(
        plugin: 'firebase_auth',
        code: 'unknown',
        message:
            'dev.flutter.pigeon.firebase_auth_platform_interface.'
            'FirebaseAuthHostApi.createUserWithEmailAndPassword',
      );

      final message = userFacingError(error);

      expect(
        message,
        'No pudimos conectar con el servicio de acceso. '
        'Intenta de nuevo en unos minutos.',
      );
      expect(message, isNot(contains('FirebaseAuthHostApi')));
    });

    test('oculta errores de conexión del canal nativo', () {
      const error =
          'PlatformException(channel-error, Unable to establish connection '
          'on channel: firebase_auth, null, null)';

      expect(
        userFacingError(error),
        'No pudimos conectar con el servicio de acceso. '
        'Intenta de nuevo en unos minutos.',
      );
    });

    test('usa un mensaje seguro para errores desconocidos', () {
      expect(
        userFacingError(StateError('detalle interno sensible')),
        'No se pudo completar la acción. Intenta de nuevo.',
      );
    });

    test('explica cuando el vínculo venció', () {
      final error = FirebaseException(
        plugin: 'firebase_auth',
        code: 'expired-action-code',
      );

      expect(
        userFacingError(error),
        'Este vínculo venció. Solicita uno nuevo.',
      );
    });

    test('conserva el mensaje funcional de una reserva bloqueada', () {
      final error = FirebaseException(
        plugin: 'cloud_functions',
        code: 'failed-precondition',
        message: 'Esta peluquería no acepta nuevas reservas de tu cuenta.',
      );

      expect(
        userFacingError(error),
        'Esta peluquería no acepta nuevas reservas de tu cuenta.',
      );
    });
  });
}
