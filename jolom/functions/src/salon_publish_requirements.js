/**
 * Indica si la peluquería tiene al menos una foto utilizable.
 * @param {object} salon
 * @return {boolean}
 */
function hasSalonImage(salon) {
  return Array.isArray(salon && salon.imageUrls) &&
    salon.imageUrls.some((url) =>
      typeof url === "string" && url.trim().length > 0,
    );
}

/**
 * Convierte HH:mm a minutos o devuelve null si el formato no es válido.
 * @param {*} value
 * @return {number|null}
 */
function timeToMinutes(value) {
  if (typeof value !== "string") return null;
  const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(value.trim());
  if (!match) return null;
  return Number(match[1]) * 60 + Number(match[2]);
}

/**
 * Indica si existe al menos un día abierto con un rango horario válido.
 * @param {*} weeklyHours
 * @return {boolean}
 */
function hasOpenAvailabilityDay(weeklyHours) {
  if (!weeklyHours || typeof weeklyHours !== "object") return false;
  return Object.values(weeklyHours).some((day) => {
    if (!day || typeof day !== "object") return false;
    const start = timeToMinutes(day.start);
    const end = timeToMinutes(day.end);
    return start !== null && end !== null && end > start;
  });
}

module.exports = {hasSalonImage, hasOpenAvailabilityDay};
