const {onCall} = require("firebase-functions/v2/https");
const {
  assertActiveAuth,
  writeAuditLog,
  findIdempotentResult,
  saveIdempotentResult,
  DEFAULT_CURRENCY,
  HttpsError,
  admin,
  db,
} = require("./helpers");
const {
  SALON_INPUT_LIMITS,
  normalizeText,
  isTextWithinLimit,
  isValidServiceDuration,
  isValidServicePrice,
} = require("./salon_input_limits");

const SERVICE_DURATION_ERROR =
  `La duración debe estar entre ` +
  `${SALON_INPUT_LIMITS.serviceDurationMinMinutes} y ` +
  `${SALON_INPUT_LIMITS.serviceDurationMaxMinutes} minutos.`;
const SERVICE_PRICE_ERROR =
  `El precio debe estar entre ${SALON_INPUT_LIMITS.servicePriceMin} y ` +
  `${SALON_INPUT_LIMITS.servicePriceMax}, con un máximo de ` +
  `${SALON_INPUT_LIMITS.servicePriceMaxDecimalPlaces} decimales.`;

/**
 * Normaliza y valida el nombre del servicio.
 * @param {unknown} value
 * @return {string}
 */
function parseServiceName(value) {
  const name = normalizeText(value);
  if (!name) {
    throw new HttpsError("invalid-argument", "El nombre es obligatorio.");
  }
  if (!isTextWithinLimit(name, SALON_INPUT_LIMITS.serviceNameMaxLength)) {
    throw new HttpsError(
        "invalid-argument",
        `El nombre admite un máximo de ${SALON_INPUT_LIMITS.serviceNameMaxLength} caracteres.`,
    );
  }
  return name;
}

/**
 * Valida duración y precio, y devuelve sus valores numéricos.
 * @param {unknown} durationValue
 * @param {unknown} priceValue
 * @return {{durationMinutes: number, price: number}}
 */
function parseServiceNumbers(durationValue, priceValue) {
  if (!isValidServiceDuration(durationValue)) {
    throw new HttpsError(
        "invalid-argument",
        SERVICE_DURATION_ERROR,
    );
  }
  if (!isValidServicePrice(priceValue)) {
    throw new HttpsError(
        "invalid-argument",
        SERVICE_PRICE_ERROR,
    );
  }
  return {
    durationMinutes: Number(durationValue),
    price: Number(priceValue),
  };
}

/**
 * Comprueba que el actor es propietario activo del salon.
 * @param {string} uid
 * @param {string} salonId
 */
async function assertOwnerOfSalon(uid, salonId) {
  const membershipSnap = await db().collection("salonMemberships").doc(uid).get();
  if (!membershipSnap.exists) {
    throw new HttpsError("permission-denied", "Sin pertenencia activa.");
  }
  const m = membershipSnap.data();
  if (
    m.salonId !== salonId ||
    m.role !== "owner" ||
    m.status !== "active"
  ) {
    throw new HttpsError(
        "permission-denied",
        "Solo el propietario activo puede gestionar servicios.",
    );
  }
}

/**
 * Crea un servicio reservable.
 */
const createService = onCall(async (request) => {
  const uid = await assertActiveAuth(request);
  const data = request.data || {};
  const salonId = data.salonId;
  if (!salonId) {
    throw new HttpsError("invalid-argument", "salonId es obligatorio.");
  }
  const name = parseServiceName(data.name);
  const {durationMinutes, price} = parseServiceNumbers(
      data.durationMinutes,
      data.price,
  );

  const cached = await findIdempotentResult("createService", data.idempotencyKey);
  if (cached) return cached;

  await assertOwnerOfSalon(uid, salonId);
  const salonSnap = await db().collection("salons").doc(salonId).get();
  if (!salonSnap.exists || salonSnap.data().isDeleted) {
    throw new HttpsError("not-found", "Peluquería no encontrada.");
  }

  const enabledBarberIds = Array.isArray(data.enabledBarberIds) ?
    data.enabledBarberIds.filter((id) => typeof id === "string") :
    [uid];

  const now = admin.firestore.FieldValue.serverTimestamp();
  const ref = db().collection("services").doc();
  await ref.set({
    salonId,
    name,
    description: data.description || null,
    durationMinutes,
    price,
    currency: salonSnap.data().currency || DEFAULT_CURRENCY,
    enabledBarberIds,
    status: "active",
    isDeleted: false,
    createdAt: now,
    updatedAt: now,
  });

  const result = {serviceId: ref.id};
  await writeAuditLog({
    actorId: uid,
    action: "createService",
    entityType: "service",
    entityId: ref.id,
    after: {name, price, durationMinutes},
  });
  await saveIdempotentResult("createService", data.idempotencyKey, result);
  return result;
});

/**
 * Actualiza o desactiva un servicio.
 */
const updateService = onCall(async (request) => {
  const uid = await assertActiveAuth(request);
  const data = request.data || {};
  const serviceId = data.serviceId;
  if (!serviceId) {
    throw new HttpsError("invalid-argument", "serviceId es obligatorio.");
  }

  const cached = await findIdempotentResult("updateService", data.idempotencyKey);
  if (cached) return cached;

  const ref = db().collection("services").doc(serviceId);
  const snap = await ref.get();
  if (!snap.exists || snap.data().isDeleted) {
    throw new HttpsError("not-found", "Servicio no encontrado.");
  }
  const service = snap.data();
  await assertOwnerOfSalon(uid, service.salonId);

  const patch = {updatedAt: admin.firestore.FieldValue.serverTimestamp()};
  if (data.name !== undefined) patch.name = parseServiceName(data.name);
  if (data.description !== undefined) patch.description = data.description || null;
  if (data.durationMinutes !== undefined) {
    if (!isValidServiceDuration(data.durationMinutes)) {
      throw new HttpsError(
          "invalid-argument",
          SERVICE_DURATION_ERROR,
      );
    }
    patch.durationMinutes = Number(data.durationMinutes);
  }
  if (data.price !== undefined) {
    if (!isValidServicePrice(data.price)) {
      throw new HttpsError(
          "invalid-argument",
          SERVICE_PRICE_ERROR,
      );
    }
    patch.price = Number(data.price);
  }
  if (Array.isArray(data.enabledBarberIds)) {
    patch.enabledBarberIds = data.enabledBarberIds;
  }
  if (data.status === "active" || data.status === "inactive") {
    patch.status = data.status;
  }
  if (data.isDeleted === true) {
    patch.isDeleted = true;
    patch.status = "inactive";
  }

  await ref.update(patch);
  const result = {serviceId};
  await writeAuditLog({
    actorId: uid,
    action: "updateService",
    entityType: "service",
    entityId: serviceId,
    after: patch,
  });
  await saveIdempotentResult("updateService", data.idempotencyKey, result);
  return result;
});

module.exports = {createService, updateService};
