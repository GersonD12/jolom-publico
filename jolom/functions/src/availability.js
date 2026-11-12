const {onCall} = require("firebase-functions/v2/https");
const {
  assertActiveAuth,
  writeAuditLog,
  findIdempotentResult,
  saveIdempotentResult,
  HttpsError,
  admin,
  db,
} = require("./helpers");

const DAY_KEYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];
const EXCEPTION_TYPES = new Set(["block", "timeOff"]);

/**
 * Normaliza un día de weeklyHours: null | { start, end, breaks? }.
 * @param {*} raw
 * @return {null|{start: string, end: string, breaks: Array}}
 */
function normalizeDayHours(raw) {
  if (raw == null) return null;
  if (typeof raw !== "object") {
    throw new HttpsError("invalid-argument", "weeklyHours inválido.");
  }
  if (!raw.start || !raw.end) {
    throw new HttpsError(
        "invalid-argument",
        "Cada día abierto requiere start y end (HH:mm).",
    );
  }
  const breaks = [];
  if (Array.isArray(raw.breaks)) {
    for (const b of raw.breaks) {
      if (!b || typeof b !== "object" || !b.start || !b.end) continue;
      breaks.push({
        start: String(b.start),
        end: String(b.end),
        reason: b.reason ? String(b.reason) : null,
      });
    }
  }
  return {
    start: String(raw.start),
    end: String(raw.end),
    breaks,
  };
}

/**
 * Normaliza el mapa weeklyHours completo.
 * @param {object} weeklyHours
 * @return {object}
 */
function normalizeWeeklyHours(weeklyHours) {
  const out = {};
  for (const key of DAY_KEYS) {
    if (!(key in weeklyHours)) {
      out[key] = null;
      continue;
    }
    out[key] = normalizeDayHours(weeklyHours[key]);
  }
  return out;
}

/**
 * Comprueba si el caller puede editar la agenda del barberId.
 * @param {string} uid
 * @param {string} barberId
 * @param {FirebaseFirestore.DocumentData} avail
 */
async function assertCanEditAvailability(uid, barberId, avail) {
  const membershipSnap = await db().collection("salonMemberships").doc(uid).get();
  if (!membershipSnap.exists) {
    throw new HttpsError("permission-denied", "Sin pertenencia.");
  }
  const membership = membershipSnap.data();
  const isSelf = uid === barberId && membership.status === "active";
  const isOwner =
    membership.role === "owner" &&
    membership.salonId === avail.salonId &&
    membership.status === "active";
  if (!isSelf && !isOwner) {
    throw new HttpsError(
        "permission-denied",
        "Solo el peluquero o el propietario pueden editar la agenda.",
    );
  }
}

/**
 * Actualiza horario semanal (con breaks) del peluquero.
 * El propio peluquero o el propietario de su peluquería pueden escribir.
 */
const setAvailability = onCall(async (request) => {
  const uid = await assertActiveAuth(request);
  const data = request.data || {};
  const barberId = data.barberId || uid;

  const cached = await findIdempotentResult(
      "setAvailability",
      data.idempotencyKey,
  );
  if (cached) return cached;

  const availRef = db().collection("availability").doc(barberId);
  const availSnap = await availRef.get();
  if (!availSnap.exists) {
    throw new HttpsError("not-found", "Disponibilidad no encontrada.");
  }
  const avail = availSnap.data();
  const salonId = avail.salonId;

  await assertCanEditAvailability(uid, barberId, avail);

  const patch = {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    // Deja de usarse el array legacy (ADR-0002).
    blocks: admin.firestore.FieldValue.delete(),
  };
  if (data.weeklyHours && typeof data.weeklyHours === "object") {
    patch.weeklyHours = normalizeWeeklyHours(data.weeklyHours);
  }

  await availRef.update(patch);

  const result = {barberId, salonId};
  await writeAuditLog({
    actorId: uid,
    action: "setAvailability",
    entityType: "availability",
    entityId: barberId,
    after: {
      weeklyHours: data.weeklyHours || null,
    },
  });
  await saveIdempotentResult("setAvailability", data.idempotencyKey, result);
  return result;
});

/**
 * Crea una excepción (bloqueo puntual o ausencia) en la subcolección.
 */
const createAvailabilityBlock = onCall(async (request) => {
  const uid = await assertActiveAuth(request);
  const data = request.data || {};
  const barberId = data.barberId || uid;
  if (!data.start || !data.end) {
    throw new HttpsError("invalid-argument", "start y end son obligatorios.");
  }

  const type = data.type || "block";
  if (!EXCEPTION_TYPES.has(type)) {
    throw new HttpsError(
        "invalid-argument",
        "type debe ser block o timeOff.",
    );
  }

  const start = new Date(data.start);
  const end = new Date(data.end);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || end <= start) {
    throw new HttpsError("invalid-argument", "Rango de bloqueo inválido.");
  }

  const cached = await findIdempotentResult(
      "createAvailabilityBlock",
      data.idempotencyKey,
  );
  if (cached) return cached;

  const availRef = db().collection("availability").doc(barberId);
  const availSnap = await availRef.get();
  if (!availSnap.exists) {
    throw new HttpsError("not-found", "Disponibilidad no encontrada.");
  }
  const avail = availSnap.data();
  await assertCanEditAvailability(uid, barberId, avail);

  const exceptionRef = availRef.collection("exceptions").doc();
  const exception = {
    type,
    start: admin.firestore.Timestamp.fromDate(start),
    end: admin.firestore.Timestamp.fromDate(end),
    reason: data.reason || null,
    createdBy: uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await exceptionRef.set(exception);
  await availRef.update({
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const result = {barberId, exceptionId: exceptionRef.id, ok: true};
  await writeAuditLog({
    actorId: uid,
    action: "createAvailabilityBlock",
    entityType: "availability",
    entityId: barberId,
    after: {
      exceptionId: exceptionRef.id,
      type,
      start: start.toISOString(),
      end: end.toISOString(),
    },
  });
  await saveIdempotentResult(
      "createAvailabilityBlock",
      data.idempotencyKey,
      result,
  );
  return result;
});

/**
 * Elimina una excepción de disponibilidad.
 */
const deleteAvailabilityException = onCall(async (request) => {
  const uid = await assertActiveAuth(request);
  const data = request.data || {};
  const barberId = data.barberId || uid;
  const exceptionId = data.exceptionId;
  if (!exceptionId) {
    throw new HttpsError("invalid-argument", "exceptionId es obligatorio.");
  }

  const cached = await findIdempotentResult(
      "deleteAvailabilityException",
      data.idempotencyKey,
  );
  if (cached) return cached;

  const availRef = db().collection("availability").doc(barberId);
  const availSnap = await availRef.get();
  if (!availSnap.exists) {
    throw new HttpsError("not-found", "Disponibilidad no encontrada.");
  }
  await assertCanEditAvailability(uid, barberId, availSnap.data());

  const exceptionRef = availRef.collection("exceptions").doc(exceptionId);
  const exceptionSnap = await exceptionRef.get();
  if (!exceptionSnap.exists) {
    throw new HttpsError("not-found", "Excepción no encontrada.");
  }

  await exceptionRef.delete();
  await availRef.update({
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const result = {barberId, exceptionId, ok: true};
  await writeAuditLog({
    actorId: uid,
    action: "deleteAvailabilityException",
    entityType: "availability",
    entityId: barberId,
    after: {exceptionId},
  });
  await saveIdempotentResult(
      "deleteAvailabilityException",
      data.idempotencyKey,
      result,
  );
  return result;
});

module.exports = {
  setAvailability,
  createAvailabilityBlock,
  deleteAvailabilityException,
};
