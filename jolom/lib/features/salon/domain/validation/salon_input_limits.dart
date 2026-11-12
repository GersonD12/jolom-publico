/// Límites de entrada compartidos por la ficha de peluquería y sus servicios.
abstract final class SalonInputLimits {
  static const int salonNameMaxLength = 80;
  static const int salonDescriptionMaxLength = 500;
  static const int salonPhoneMaxLength = 20;
  static const int salonAddressMaxLength = 200;

  static const int serviceNameMaxLength = 80;
  static const int serviceDurationMinMinutes = 5;
  static const int serviceDurationMaxMinutes = 480;
  static const double servicePriceMin = 0;
  static const double servicePriceMax = 100000;
  static const int servicePriceMaxDecimalPlaces = 2;

  static bool isTextWithinLimit(String value, int maxLength) =>
      value.runes.length <= maxLength;

  static bool isValidServiceDuration(int? durationMinutes) =>
      durationMinutes != null &&
      durationMinutes >= serviceDurationMinMinutes &&
      durationMinutes <= serviceDurationMaxMinutes;

  static bool isValidServicePrice(double? price) {
    if (price == null ||
        !price.isFinite ||
        price < servicePriceMin ||
        price > servicePriceMax) {
      return false;
    }

    final multiplier = switch (servicePriceMaxDecimalPlaces) {
      0 => 1,
      1 => 10,
      2 => 100,
      _ => throw UnsupportedError('Cantidad de decimales no soportada.'),
    };
    final scaledPrice = price * multiplier;
    return (scaledPrice - scaledPrice.round()).abs() < 0.000000001;
  }
}
