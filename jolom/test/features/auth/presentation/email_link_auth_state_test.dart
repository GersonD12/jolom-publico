import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/features/auth/presentation/email_link_auth_state.dart';

void main() {
  group('isValidEmailAddress', () {
    test('acepta un correo con formato válido', () {
      expect(isValidEmailAddress('usuario@ejemplo.com'), isTrue);
      expect(isValidEmailAddress(' nombre.apellido@jolom.example '), isTrue);
    });

    test('rechaza correos incompletos o con espacios', () {
      expect(isValidEmailAddress(''), isFalse);
      expect(isValidEmailAddress('usuario@'), isFalse);
      expect(isValidEmailAddress('usuario@localhost'), isFalse);
      expect(isValidEmailAddress('usuario @ejemplo.com'), isFalse);
      expect(isValidEmailAddress('usuario@@ejemplo.com'), isFalse);
    });
  });
}
