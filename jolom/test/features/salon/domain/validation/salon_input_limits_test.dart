import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/features/salon/domain/validation/salon_input_limits.dart';

void main() {
  group('SalonInputLimits', () {
    test('acepta textos hasta el límite y rechaza el excedente', () {
      final textAtLimit = List.filled(
        SalonInputLimits.salonNameMaxLength,
        'a',
      ).join();
      final textOverLimit = '${textAtLimit}a';
      expect(
        SalonInputLimits.isTextWithinLimit(
          textAtLimit,
          SalonInputLimits.salonNameMaxLength,
        ),
        isTrue,
      );
      expect(
        SalonInputLimits.isTextWithinLimit(
          textOverLimit,
          SalonInputLimits.salonNameMaxLength,
        ),
        isFalse,
      );
    });

    test('acepta duraciones entre 5 y 480 minutos', () {
      expect(SalonInputLimits.isValidServiceDuration(5), isTrue);
      expect(SalonInputLimits.isValidServiceDuration(480), isTrue);
      expect(SalonInputLimits.isValidServiceDuration(4), isFalse);
      expect(SalonInputLimits.isValidServiceDuration(481), isFalse);
      expect(SalonInputLimits.isValidServiceDuration(null), isFalse);
    });

    test('limita precio, finitud y cantidad de decimales', () {
      expect(SalonInputLimits.isValidServicePrice(0), isTrue);
      expect(SalonInputLimits.isValidServicePrice(100000), isTrue);
      expect(SalonInputLimits.isValidServicePrice(49.99), isTrue);
      expect(SalonInputLimits.isValidServicePrice(-0.01), isFalse);
      expect(SalonInputLimits.isValidServicePrice(100000.01), isFalse);
      expect(SalonInputLimits.isValidServicePrice(49.999), isFalse);
      expect(SalonInputLimits.isValidServicePrice(double.infinity), isFalse);
      expect(SalonInputLimits.isValidServicePrice(null), isFalse);
    });
  });
}
