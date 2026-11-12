import 'package:flutter/services.dart';
import 'package:jolom/features/salon/domain/validation/salon_input_limits.dart';

final List<TextInputFormatter> servicePriceInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
  LengthLimitingTextInputFormatter(9),
];

String? validateServiceName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Ingresa un nombre';
  if (!SalonInputLimits.isTextWithinLimit(
    name,
    SalonInputLimits.serviceNameMaxLength,
  )) {
    return 'Máximo ${SalonInputLimits.serviceNameMaxLength} caracteres';
  }
  return null;
}

String? validateServiceDuration(String? value) {
  final duration = int.tryParse(value?.trim() ?? '');
  if (!SalonInputLimits.isValidServiceDuration(duration)) {
    return 'Entre ${SalonInputLimits.serviceDurationMinMinutes} y '
        '${SalonInputLimits.serviceDurationMaxMinutes} min';
  }
  return null;
}

String? validateServicePrice(String? value) {
  final price = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
  if (!SalonInputLimits.isValidServicePrice(price)) {
    return 'Entre 0 y 100,000; máximo 2 decimales';
  }
  return null;
}
