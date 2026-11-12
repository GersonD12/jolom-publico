import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/features/appointment/domain/entities/availability_entity.dart';

void main() {
  group('hasAnyOpenAvailabilityDay', () {
    test(
      'devuelve false cuando no hay horario o todos los días están cerrados',
      () {
        expect(hasAnyOpenAvailabilityDay(null), isFalse);
        expect(hasAnyOpenAvailabilityDay(const {}), isFalse);
        expect(
          hasAnyOpenAvailabilityDay(const {
            'mon': null,
            'tue': null,
            'wed': null,
            'thu': null,
            'fri': null,
            'sat': null,
            'sun': null,
          }),
          isFalse,
        );
      },
    );

    test('devuelve true cuando existe al menos un día abierto válido', () {
      expect(
        hasAnyOpenAvailabilityDay(const {
          'mon': null,
          'tue': {'start': '09:00', 'end': '18:00'},
        }),
        isTrue,
      );
    });

    test('ignora días incompletos como si estuvieran cerrados', () {
      expect(
        hasAnyOpenAvailabilityDay(const {
          'mon': {'start': '09:00'},
          'tue': {'start': '', 'end': '18:00'},
        }),
        isFalse,
      );
    });
  });
}
