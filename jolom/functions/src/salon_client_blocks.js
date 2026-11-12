const crypto = require("crypto");
const {onCall} = require("firebase-functions/v2/https");
const {
  assertActiveAuth,
  addAuditLogToBatch,
  addInAppNotificationToBatch,
  findIdempotentResult,
  saveIdempotentResult,
  HttpsError,
  admin,
  db,
} = require("./helpers");

const SALON_CLIENT_BLOCKS_COLLECTION = "salonClientBlocks";
const SALON_CLIENT_BLOCK_ID_NAMESPACE = "salon-client-block-v1";

/**
 * Genera la identidad estable de una relación salón-cliente sin concatenar IDs.
 * @param {string} salonId
 * @param {string} userId
 * @return {string}
 */
function buildSalonClientBlockId(salonId, userId) {
  if (
    typeof salonId !== "string" || !salonId ||
    typeof userId !== "string" || !userId
  ) {
    throw new TypeError("salonId y userId son obligatorios.");
  }
  const canonicalTuple = JSON.stringify([
    SALON_CLIENT_BLOCK_ID_NAMESPACE,
    salonId,
    userId,
  ]);
  return crypto.createHash("sha256").update(canonicalTuple).digest("hex");
}

/** Ruta raíz estable para una única relación salón-cliente. */
function salonClientBlockPath(salonId, userId) {
  return `${SALON_CLIENT_BLOCKS_COLLECTION}/${
    buildSalonClientBlockId(salonId, userId)}`;
}

function salonClientBlockRef(salonId, userId) {
  return db().doc(salonClientBlockPath(salonId, userId));
}

/**
 * Verifica que el cliente y la cita coincidan, y que el actor pueda gestionar
 * clientes de esa peluquería.
 */
async function assertSalonCanManageClient(uid, targetUserId, appointmentId) {
  if (!targetUserId || !appointmentId) {
    throw new HttpsError(
        "invalid-argument",
        "targetUserId y sourceAppointmentId son obligatorios.",
    );
  }
  if (targetUserId === uid) {
    throw new HttpsError(
        "failed-precondition",
        "No puedes bloquearte o reportarte a ti mismo.",
    );
  }

  const [targetSnap, appointmentSnap, membershipSnap] = await Promise.all([
    db().collection("users").doc(targetUserId).get(),
    db().collection("appointments").doc(appointmentId).get(),
    db().collection("salonMemberships").doc(uid).get(),
  ]);
  if (!targetSnap.exists || targetSnap.data().isDeleted) {
    throw new HttpsError("not-found", "Cliente no encontrado.");
  }
  if (!appointmentSnap.exists) {
    throw new HttpsError("not-found", "Cita no encontrada.");
  }

  const appointment = appointmentSnap.data();
  if (appointment.clientId !== targetUserId) {
    throw new HttpsError("invalid-argument", "La cita no corresponde al cliente.");
  }
  const membership = membershipSnap.exists ? membershipSnap.data() : null;
  const isActiveMember = membership && membership.status === "active" &&
    membership.salonId === appointment.salonId;
  const isAssignedBarber = isActiveMember && appointment.barberId === uid;
  const isSalonOwner = isActiveMember && membership.role === "owner";
  if (!isAssignedBarber && !isSalonOwner) {
    throw new HttpsError(
        "permission-denied",
        "Solo el peluquero asignado o el propietario pueden gestionar al cliente.",
    );
  }

  return {
    sourceAppointmentId: appointmentId,
    sourceSalonId: appointment.salonId,
  };
}

/** Consulta el estado local después de validar la cita y la pertenencia. */
const getSalonClientBlockStatus = onCall(async (request) => {
  const uid = await assertActiveAuth(request);
  const data = request.data || {};
  const targetUserId = (data.targetUserId || "").trim();
  const appointmentId = (data.sourceAppointmentId || "").trim();
  const context = await assertSalonCanManageClient(
      uid,
      targetUserId,
      appointmentId,
  );
  const blockSnap = await salonClientBlockRef(
      context.sourceSalonId,
      targetUserId,
  ).get();
  return {
    blocked: blockSnap.exists,
    salonId: context.sourceSalonId,
    userId: targetUserId,
  };
});

/** Bloquea o desbloquea al cliente únicamente para la peluquería de la cita. */
const setSalonClientBlock = onCall(async (request) => {
  const uid = await assertActiveAuth(request);
  const data = request.data || {};
  const targetUserId = (data.targetUserId || "").trim();
  const appointmentId = (data.sourceAppointmentId || "").trim();
  const blocked = data.blocked;
  const reason = (data.reason || "").trim();

  if (typeof blocked !== "boolean") {
    throw new HttpsError("invalid-argument", "blocked debe ser booleano.");
  }
  if (reason.length > 500) {
    throw new HttpsError("invalid-argument", "El motivo es demasiado largo.");
  }

  const context = await assertSalonCanManageClient(
      uid,
      targetUserId,
      appointmentId,
  );
  const cached = await findIdempotentResult(
      "setSalonClientBlock",
      data.idempotencyKey,
  );
  if (cached) return cached;

  const blockRef = salonClientBlockRef(context.sourceSalonId, targetUserId);
  const blockSnap = await blockRef.get();
  const changed = blocked ? !blockSnap.exists : blockSnap.exists;
  const result = {
    blocked,
    changed,
    salonId: context.sourceSalonId,
    userId: targetUserId,
  };
  if (!changed) {
    await saveIdempotentResult(
        "setSalonClientBlock",
        data.idempotencyKey,
        result,
    );
    return result;
  }

  const batch = db().batch();
  const now = admin.firestore.FieldValue.serverTimestamp();
  if (blocked) {
    batch.set(blockRef, {
      salonId: context.sourceSalonId,
      userId: targetUserId,
      sourceAppointmentId: appointmentId,
      reason: reason || "Bloqueo manual desde una cita",
      blockedBy: uid,
      blockedAt: now,
      updatedAt: now,
    });
  } else {
    batch.delete(blockRef);
  }

  addAuditLogToBatch(batch, {
    actorId: uid,
    action: blocked ? "blockSalonClient" : "unblockSalonClient",
    entityType: "salonClientBlock",
    entityId: blockRef.path,
    before: {blocked: blockSnap.exists},
    after: {blocked, ...context, targetUserId},
    reason: reason || null,
  });
  addInAppNotificationToBatch(batch, targetUserId, {
    type: "moderation",
    title: blocked ? "Reservas bloqueadas" : "Reservas habilitadas",
    body: blocked ?
      "Esta peluquería bloqueó nuevas reservas de tu cuenta." :
      "Esta peluquería volvió a habilitar tus reservas.",
    data: {
      action: blocked ? "salonClientBlock" : "salonClientUnblock",
      salonId: context.sourceSalonId,
      type: "moderation",
    },
  });
  await batch.commit();

  await saveIdempotentResult(
      "setSalonClientBlock",
      data.idempotencyKey,
      result,
  );
  return result;
});

module.exports = {
  SALON_CLIENT_BLOCKS_COLLECTION,
  assertSalonCanManageClient,
  buildSalonClientBlockId,
  getSalonClientBlockStatus,
  salonClientBlockPath,
  salonClientBlockRef,
  setSalonClientBlock,
};
