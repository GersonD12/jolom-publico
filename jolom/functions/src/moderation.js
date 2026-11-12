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
const {
  allowedSalonActions,
  allowedUserActions,
  getUserModerationState,
} = require("./moderation_state");
const {enqueueAccountDeletion} = require("./account_deletions");

/** Exige custom claim admin. */
async function assertAdmin(request) {
  const uid = await assertActiveAuth(request);
  const role = request.auth.token && request.auth.token.role;
  if (role !== "admin") {
    throw new HttpsError("permission-denied", "Se requiere rol administrador.");
  }
  return uid;
}

function userNotification(action, reason) {
  switch (action) {
    case "warn":
      return {
        type: "moderation",
        title: "Advertencia de moderación",
        body: `Recibiste una advertencia. Motivo: ${reason}`,
        data: {action, type: "moderation"},
      };
    case "ban":
      return {
        type: "moderation",
        title: "Cuenta bloqueada",
        body: `Tu cuenta fue bloqueada. Motivo: ${reason}`,
        data: {action, type: "moderation"},
      };
    case "unban":
    case "restore":
      return {
        type: "moderation",
        title: "Cuenta habilitada",
        body: "La restricción de tu cuenta fue retirada.",
        data: {action, type: "moderation"},
      };
    default:
      return null;
  }
}

function salonNotification(action, salonName, reason) {
  const copy = {
    warn: [
      "Advertencia sobre tu peluquería",
      `${salonName} recibió una advertencia. Motivo: ${reason}`,
    ],
    suspend: [
      "Peluquería suspendida",
      `${salonName} fue suspendida. Motivo: ${reason}`,
    ],
    unpublish: [
      "Peluquería despublicada",
      `${salonName} dejó de estar visible. Motivo: ${reason}`,
    ],
    softDelete: [
      "Peluquería eliminada",
      `${salonName} fue eliminada. Motivo: ${reason}`,
    ],
    restore: [
      "Peluquería restaurada",
      `${salonName} volvió a estar disponible.`,
    ],
  }[action];
  if (!copy) return null;
  return {
    type: "moderation",
    title: copy[0],
    body: copy[1],
    data: {action, type: "moderation"},
  };
}

async function assertOpenMatchingReport(reportId, targetType, targetId) {
  if (!reportId) return null;
  const snap = await db().collection("reports").doc(reportId).get();
  if (!snap.exists) throw new HttpsError("not-found", "Reporte no encontrado.");
  const report = snap.data();
  if (report.targetType !== targetType || report.targetId !== targetId) {
    throw new HttpsError(
        "invalid-argument",
        "El reporte no corresponde al objetivo de moderación.",
    );
  }
  if (!["received", "inReview"].includes(report.status)) {
    throw new HttpsError(
        "failed-precondition",
        "El reporte ya fue cerrado.",
    );
  }
  return snap;
}

/** Aplica una transición válida de moderación y registra todo en un batch. */
const applyModerationAction = onCall(async (request) => {
  const adminUid = await assertAdmin(request);
  const data = request.data || {};
  const targetType = data.targetType;
  const targetId = (data.targetId || "").trim();
  const action = data.action;
  const reason = (data.reason || "").trim();
  const scope = (data.scope || "").trim() || null;
  const reportId = (data.reportId || "").trim() || null;

  if (!["user", "barber", "salon"].includes(targetType) ||
      !targetId || !action || !reason) {
    throw new HttpsError(
        "invalid-argument",
        "targetType, targetId, action y reason son obligatorios.",
    );
  }

  const cached = await findIdempotentResult(
      "applyModerationAction",
      data.idempotencyKey,
  );
  if (cached) return cached;

  const reportSnap = await assertOpenMatchingReport(
      reportId,
      targetType,
      targetId,
  );
  const now = admin.firestore.FieldValue.serverTimestamp();
  const batch = db().batch();
  const caseRef = db().collection("moderationCases").doc();
  let before;
  let after;
  let notificationTargetId = null;
  let notification = null;
  let enqueueDeletion = false;

  if (targetType === "user" || targetType === "barber") {
    const userRef = db().collection("users").doc(targetId);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "Usuario no encontrado.");
    }
    const user = userSnap.data();
    const allowed = allowedUserActions(user);
    if (!allowed.includes(action)) {
      const state = getUserModerationState(user);
      throw new HttpsError(
          "failed-precondition",
          `La acción ${action} no es válida para una cuenta en estado ${state}.`,
      );
    }

    before = {
      moderationStatus: user.moderationStatus || "none",
      moderationReason: user.moderationReason || null,
      isBanned: user.isBanned === true,
      accountStatus: user.accountStatus || "active",
    };
    const patch = {updatedAt: now};
    if (action === "warn") {
      patch.moderationStatus = "warned";
      patch.moderationReason = reason;
    } else if (action === "ban") {
      patch.moderationStatus = "banned";
      patch.moderationReason = reason;
      patch.isBanned = true;
    } else if (action === "unban" || action === "restore") {
      patch.moderationStatus = "none";
      patch.moderationReason = null;
      if (action === "unban") patch.isBanned = false;
    } else if (action === "softDelete") {
      enqueueDeletion = true;
    }
    batch.update(userRef, patch);
    after = patch;

    const shouldSyncBarber = targetType === "barber" ||
      user.capabilities && user.capabilities.barber === true;
    if (shouldSyncBarber) {
      const barberRef = db().collection("barberProfiles").doc(targetId);
      const barberSnap = await barberRef.get();
      if (barberSnap.exists &&
          ["ban", "softDelete"].includes(action)) {
        batch.update(barberRef, {status: "suspended", updatedAt: now});
      } else if (barberSnap.exists &&
          ["unban", "restore"].includes(action)) {
        batch.update(barberRef, {status: "active", updatedAt: now});
      }
    }
    notificationTargetId = targetId;
    notification = userNotification(action, reason);
  } else {
    const salonRef = db().collection("salons").doc(targetId);
    const salonSnap = await salonRef.get();
    if (!salonSnap.exists) {
      throw new HttpsError("not-found", "Peluquería no encontrada.");
    }
    const salon = salonSnap.data();
    const allowed = allowedSalonActions(salon);
    if (!allowed.includes(action)) {
      throw new HttpsError(
          "failed-precondition",
          `La acción ${action} no es válida para una peluquería ${salon.publishStatus}.`,
      );
    }
    before = {
      publishStatus: salon.publishStatus,
      isDeleted: salon.isDeleted === true,
    };
    const patch = {updatedAt: now};
    if (action === "unpublish") patch.publishStatus = "hidden";
    if (action === "suspend") patch.publishStatus = "suspended";
    if (action === "softDelete") {
      patch.publishStatus = "deleted";
      patch.isDeleted = true;
    }
    if (action === "restore") {
      patch.publishStatus = salon.publishStatus === "suspended" ?
        "published" : "draft";
      patch.isDeleted = false;
    }
    batch.update(salonRef, patch);
    after = patch;
    notificationTargetId = salon.ownerId || null;
    notification = salonNotification(action, salon.name || "Tu peluquería", reason);
  }

  batch.set(caseRef, {
    reportIds: reportId ? [reportId] : [],
    targetType,
    targetId,
    action,
    reason,
    scope,
    status: "resolved",
    actorId: adminUid,
    createdAt: now,
    updatedAt: now,
  });
  if (reportSnap) {
    batch.update(reportSnap.ref, {status: "closedWithAction", updatedAt: now});
  }
  addAuditLogToBatch(batch, {
    actorId: adminUid,
    action: "applyModerationAction",
    entityType: targetType,
    entityId: targetId,
    before,
    after,
    reason,
  });
  if (notificationTargetId && notification) {
    addInAppNotificationToBatch(
        batch,
        notificationTargetId,
        notification,
    );
  }
  await batch.commit();

  if (enqueueDeletion) {
    await enqueueAccountDeletion({
      uid: targetId,
      actorId: adminUid,
      actorType: "admin",
    });
  }

  const result = {caseId: caseRef.id, action, targetType, targetId};
  await saveIdempotentResult(
      "applyModerationAction",
      data.idempotencyKey,
      result,
  );
  return result;
});

/** Registra atribución de visita por QR (público autenticado o anónimo). */
const recordQrOpen = onCall(async (request) => {
  const data = request.data || {};
  const salonId = data.salonId;
  if (!salonId) {
    throw new HttpsError("invalid-argument", "salonId es obligatorio.");
  }
  const salonSnap = await db().collection("salons").doc(salonId).get();
  if (!salonSnap.exists || salonSnap.data().isDeleted) {
    throw new HttpsError("not-found", "Peluquería no encontrada.");
  }
  const statsRef = db().collection("stats").doc(`salon_${salonId}`);
  await statsRef.set({
    scopeType: "salon",
    scopeId: salonId,
    qrOpens: admin.firestore.FieldValue.increment(1),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  return {ok: true, salonId};
});

module.exports = {applyModerationAction, recordQrOpen};
