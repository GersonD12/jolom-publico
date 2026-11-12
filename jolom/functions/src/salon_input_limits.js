const SALON_INPUT_LIMITS = Object.freeze({
  salonNameMaxLength: 80,
  salonDescriptionMaxLength: 500,
  salonPhoneMaxLength: 20,
  salonAddressMaxLength: 200,
  serviceNameMaxLength: 80,
  serviceDurationMinMinutes: 5,
  serviceDurationMaxMinutes: 480,
  servicePriceMin: 0,
  servicePriceMax: 100000,
  servicePriceMaxDecimalPlaces: 2,
});

/**
 * Normaliza un valor de texto recibido por una callable.
 * @param {unknown} value
 * @return {string}
 */
function normalizeText(value) {
  return String(value ?? "").trim();
}

/**
 * Cuenta puntos de código Unicode para no penalizar caracteres fuera del BMP.
 * @param {string} value
 * @return {number}
 */
function textLength(value) {
  return Array.from(value).length;
}

/**
 * @param {unknown} value
 * @param {number} maxLength
 * @return {boolean}
 */
function isTextWithinLimit(value, maxLength) {
  return textLength(normalizeText(value)) <= maxLength;
}

/**
 * @param {unknown} value
 * @return {boolean}
 */
function isValidServiceDuration(value) {
  const duration = Number(value);
  return Number.isInteger(duration) &&
    duration >= SALON_INPUT_LIMITS.serviceDurationMinMinutes &&
    duration <= SALON_INPUT_LIMITS.serviceDurationMaxMinutes;
}

/**
 * @param {unknown} value
 * @return {boolean}
 */
function isValidServicePrice(value) {
  if (
    value === null ||
    value === undefined ||
    typeof value === "boolean" ||
    (typeof value === "string" && value.trim() === "")
  ) {
    return false;
  }
  const price = Number(value);
  if (
    !Number.isFinite(price) ||
    price < SALON_INPUT_LIMITS.servicePriceMin ||
    price > SALON_INPUT_LIMITS.servicePriceMax
  ) {
    return false;
  }

  const multiplier = 10 ** SALON_INPUT_LIMITS.servicePriceMaxDecimalPlaces;
  return Math.abs(price * multiplier - Math.round(price * multiplier)) < 1e-9;
}

module.exports = {
  SALON_INPUT_LIMITS,
  normalizeText,
  isTextWithinLimit,
  isValidServiceDuration,
  isValidServicePrice,
};
