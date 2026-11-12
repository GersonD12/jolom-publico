const {onCall} = require("firebase-functions/v2/https");
const ngeohash = require("ngeohash");
const {
  assertActiveAuth,
  writeAuditLog,
  findIdempotentResult,
  saveIdempotentResult,
  DEFAULT_TZ,
  DEFAULT_CURRENCY,
  DEFAULT_CITY,
  HttpsError,
  admin,
  db,
} = require("./helpers");
const {
  hasSalonImage,
  hasOpenAvailabilityDay,
} = require("./salon_publish_requirements");
const {
  SALON_INPUT_LIMITS,
  normalizeText,
  isTextWithinLimit,
} = require("./salon_input_limits");

/** Precisión típica para geoqueries Firebase (~5 m). */
const GEOHASH_PRECISION = 9;

/**
 * Normaliza y valida un campo de texto de la ficha.
 * @param {unknown} value
 * @param {string} label
 * @param {number} maxLength
 * @param {boolean} required
 * @return {string}
 */
function parseSalonText(value, label, maxLength, required = false) {
  const normalized = normalizeText(value);
  if (required && !normalized) {
    throw new HttpsError("invalid-argument", `${label} es obligatorio.`);
  }
  if (!isTextWithinLimit(normalized, maxLength)) {
    throw new HttpsError(
        "invalid-argument",
        `${label} admite un máximo de ${maxLength} caracteres.`,
    );
  }
  return normalized;
}

/**
 * Valida y normaliza { latitude, longitude } del cliente.
 * @param {unknown} raw
 * @return {{latitude: number, longitude: number}}
 */
function parseLocationPayload(raw) {
  if (!raw || typeof raw !== "object") {
    throw new HttpsError(
        "invalid-argument",
        "location debe ser { latitude, longitude }.",
    );
  }
  const latitude = Number(raw.latitude);
  const longitude = Number(raw.longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    throw new HttpsError(
        "invalid-argument",
        "latitude y longitude deben ser números.",
    );
  }
  if (latitude < -90 || latitude > 90) {
    throw new HttpsError("invalid-argument", "latitude fuera de rango.");
  }
  if (longitude < -180 || longitude > 180) {
    throw new HttpsError("invalid-argument", "longitude fuera de rango.");
  }
  return {latitude, longitude};
}

/**
 * Crea peluquería + pertenencia owner/barber + perfil profesional.
 */
const createSalon = onCall(async (request) => {
  const uid = await assertActiveAuth(request);
  const data = request.data || {};
  const name = parseSalonText(
      data.name,
      "El nombre",
      SALON_INPUT_LIMITS.salonNameMaxLength,
      true,
  );
  const description = parseSalonText(
      data.description,
      "La descripción",
      SALON_INPUT_LIMITS.salonDescriptionMaxLength,
  );
  const contactPhone = parseSalonText(
      data.contactPhone,
      "El teléfono",
      SALON_INPUT_LIMITS.salonPhoneMaxLength,
  );
  const address = parseSalonText(
      data.address,
      "La dirección",
      SALON_INPUT_LIMITS.salonAddressMaxLength,
  );

  const cached = await findIdempotentResult("createSalon", data.idempotencyKey);
  if (cached) return cached;

  const settingsSnap = await db().collection("appConfig").doc("settings").get();
  if (settingsSnap.data()?.canCreateSalon !== true) {
    throw new HttpsError(
        "permission-denied",
        "La creación de peluquerías no está habilitada.",
    );
  }

  const membershipRef = db().collection("salonMemberships").doc(uid);
  const userRef = db().collection("users").doc(uid);
  const barberRef = db().collection("barberProfiles").doc(uid);
  const salonRef = db().collection("salons").doc();

  const result = await db().runTransaction(async (tx) => {
    const membershipSnap = await tx.get(membershipRef);
    if (membershipSnap.exists) {
      const m = membershipSnap.data();
      if (m.status === "active" || m.status === "pendingExit") {
        throw new HttpsError(
            "failed-precondition",
            "Ya perteneces a una peluquería activa.",
        );
      }
    }

    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "Perfil de usuario no encontrado.");
    }
    const user = userSnap.data();
    if (user.isBanned || user.isDeleted) {
      throw new HttpsError("permission-denied", "Cuenta no habilitada.");
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const salon = {
      ownerId: uid,
      name,
      description: description || null,
      contactPhone: contactPhone || null,
      contactEmail: user.email || null,
      address: address || null,
      city: DEFAULT_CITY,
      location: null,
      geohash: null,
      coverImageUrl: null,
      imageUrls: [],
      businessHours: {},
      currency: DEFAULT_CURRENCY,
      timeZone: DEFAULT_TZ,
      publishStatus: "draft",
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    };

    tx.set(salonRef, salon);
    tx.set(membershipRef, {
      userId: uid,
      salonId: salonRef.id,
      role: "owner",
      status: "active",
      invitationId: null,
      joinedAt: now,
      leftAt: null,
      updatedAt: now,
    });
    tx.set(
        barberRef,
        {
          userId: uid,
          bio: null,
          status: "active",
          createdAt: now,
          updatedAt: now,
        },
        {merge: true},
    );
    tx.update(userRef, {
      "capabilities.barber": true,
      "updatedAt": now,
    });
    tx.set(
        db().collection("availability").doc(uid),
        {
          userId: uid,
          salonId: salonRef.id,
          weeklyHours: {},
          updatedAt: now,
        },
        {merge: true},
    );

    return {salonId: salonRef.id};
  });

  await writeAuditLog({
    actorId: uid,
    action: "createSalon",
    entityType: "salon",
    entityId: result.salonId,
    after: {name},
  });
  await saveIdempotentResult("createSalon", data.idempotencyKey, result);
  return result;
});

/**
 * Actualiza campos de ficha de la peluquería (solo propietario).
 */
const updateSalon = onCall(async (request) => {
  const uid = await assertActiveAuth(request);
  const data = request.data || {};
  const salonId = data.salonId;
  if (!salonId) {
    throw new HttpsError("invalid-argument", "salonId es obligatorio.");
  }

  const cached = await findIdempotentResult("updateSalon", data.idempotencyKey);
  if (cached) return cached;

  const membershipSnap = await db().collection("salonMemberships").doc(uid).get();
  if (
    !membershipSnap.exists ||
    membershipSnap.data().salonId !== salonId ||
    membershipSnap.data().role !== "owner" ||
    membershipSnap.data().status !== "active"
  ) {
    throw new HttpsError(
        "permission-denied",
        "Solo el propietario activo puede editar la peluquería.",
    );
  }

  const ref = db().collection("salons").doc(salonId);
  const snap = await ref.get();
  if (!snap.exists || snap.data().isDeleted) {
    throw new HttpsError("not-found", "Peluquería no encontrada.");
  }

  const patch = {updatedAt: admin.firestore.FieldValue.serverTimestamp()};
  if (data.name !== undefined) {
    patch.name = parseSalonText(
        data.name,
        "El nombre",
        SALON_INPUT_LIMITS.salonNameMaxLength,
        true,
    );
  }
  if (data.description !== undefined) {
    patch.description = parseSalonText(
        data.description,
        "La descripción",
        SALON_INPUT_LIMITS.salonDescriptionMaxLength,
    ) || null;
  }
  if (data.contactPhone !== undefined) {
    patch.contactPhone = parseSalonText(
        data.contactPhone,
        "El teléfono",
        SALON_INPUT_LIMITS.salonPhoneMaxLength,
    ) || null;
  }
  if (data.address !== undefined) {
    patch.address = parseSalonText(
        data.address,
        "La dirección",
        SALON_INPUT_LIMITS.salonAddressMaxLength,
    ) || null;
  }
  if (data.city !== undefined) patch.city = data.city || DEFAULT_CITY;
  if (data.location !== undefined) {
    const {latitude, longitude} = parseLocationPayload(data.location);
    patch.location = new admin.firestore.GeoPoint(latitude, longitude);
    patch.geohash = ngeohash.encode(latitude, longitude, GEOHASH_PRECISION);
  }
  if (data.coverImageUrl !== undefined) {
    patch.coverImageUrl = data.coverImageUrl || null;
  }
  if (data.imageUrls !== undefined) {
    if (!Array.isArray(data.imageUrls)) {
      throw new HttpsError(
          "invalid-argument",
          "imageUrls debe ser un arreglo de strings.",
      );
    }
    if (data.imageUrls.length > 10) {
      throw new HttpsError(
          "invalid-argument",
          "Máximo 10 imágenes del lugar.",
      );
    }
    const normalizedImageUrls = data.imageUrls
        .map((u) => String(u).trim())
        .filter((u) => u.length > 0);
    if (normalizedImageUrls.length === 0) {
      throw new HttpsError(
          "invalid-argument",
          "Debes conservar al menos una foto del negocio.",
      );
    }
    patch.imageUrls = normalizedImageUrls;
  }
  if (data.businessHours && typeof data.businessHours === "object") {
    patch.businessHours = data.businessHours;
  }

  await ref.update(patch);
  const result = {salonId};
  await writeAuditLog({
    actorId: uid,
    action: "updateSalon",
    entityType: "salon",
    entityId: salonId,
    after: patch,
  });
  await saveIdempotentResult("updateSalon", data.idempotencyKey, result);
  return result;
});

/**
 * Publica u oculta la peluquería.
 */
const setSalonPublishStatus = onCall(async (request) => {
  const uid = await assertActiveAuth(request);
  const data = request.data || {};
  const salonId = data.salonId;
  const publishStatus = data.publishStatus;
  const allowed = ["draft", "published", "hidden"];
  if (!salonId || !allowed.includes(publishStatus)) {
    throw new HttpsError(
        "invalid-argument",
        "salonId y publishStatus (draft|published|hidden) son obligatorios.",
    );
  }

  const cached = await findIdempotentResult(
      "setSalonPublishStatus",
      data.idempotencyKey,
  );
  if (cached) return cached;

  const membershipSnap = await db().collection("salonMemberships").doc(uid).get();
  if (
    !membershipSnap.exists ||
    membershipSnap.data().salonId !== salonId ||
    membershipSnap.data().role !== "owner" ||
    membershipSnap.data().status !== "active"
  ) {
    throw new HttpsError(
        "permission-denied",
        "Solo el propietario activo puede publicar.",
    );
  }

  const ref = db().collection("salons").doc(salonId);
  const snap = await ref.get();
  if (!snap.exists || snap.data().isDeleted) {
    throw new HttpsError("not-found", "Peluquería no encontrada.");
  }
  const salon = snap.data();
  if (salon.publishStatus === "suspended" || salon.publishStatus === "deleted") {
    throw new HttpsError(
        "failed-precondition",
        "La peluquería está restringida por moderación.",
    );
  }

  if (publishStatus === "published") {
    if (!hasSalonImage(salon)) {
      throw new HttpsError(
          "failed-precondition",
          "Agrega al menos una foto antes de publicar.",
      );
    }
    if (!salon.location) {
      throw new HttpsError(
          "failed-precondition",
          "Configura la ubicación antes de publicar.",
      );
    }

    const [servicesSnap, availabilitySnap] = await Promise.all([
      db()
          .collection("services")
          .where("salonId", "==", salonId)
          .where("status", "==", "active")
          .limit(1)
          .get(),
      db().collection("availability").doc(salon.ownerId).get(),
    ]);
    if (servicesSnap.empty) {
      throw new HttpsError(
          "failed-precondition",
          "Agrega al menos un servicio activo antes de publicar.",
      );
    }
    const weeklyHours = availabilitySnap.exists ?
      availabilitySnap.data().weeklyHours : null;
    if (!hasOpenAvailabilityDay(weeklyHours)) {
      throw new HttpsError(
          "failed-precondition",
          "Configura al menos un día de atención antes de publicar.",
      );
    }
  }

  await ref.update({
    publishStatus,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const result = {salonId, publishStatus};
  await writeAuditLog({
    actorId: uid,
    action: "setSalonPublishStatus",
    entityType: "salon",
    entityId: salonId,
    before: {publishStatus: salon.publishStatus},
    after: {publishStatus},
  });
  await saveIdempotentResult(
      "setSalonPublishStatus",
      data.idempotencyKey,
      result,
  );
  return result;
});

module.exports = {createSalon, updateSalon, setSalonPublishStatus};
