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
  assertSalonCanManageClient,
  salonClientBlockRef,
} = require("./salon_client_blocks");
const {buildReportDedupeKey} = require("./report_dedupe");

const TARGET_TYPES = ["user", "salon"];
const CATEGORIES_BY_TARGET = {
  salon: ["servicio", "informacion", "conducta", "fraude", "otro"],
  user: ["conducta", "inasistencia", "fraude", "spam", "otro"],
};
const CATEGORY_LABELS = {
  servicio: "Mala experiencia de servicio",
  informacion: "Información engañosa o incorrecta",
  conducta: "Conducta inapropiada",
  inasistencia: "Inasistencia reiterada",
  fraude: "Posible fraude",
  spam: "Spam o abuso",
  otro: "Otro motivo",
};

async function assertReportTargetAllowed(uid, targetType, targetId, data) {
  if (targetType === "salon") {
    const [salonSnap, membershipSnap] = await Promise.all([
      db().collection("salons").doc(targetId).get(),
      db().collection("salonMemberships").doc(uid).get(),
    ]);
    if (!salonSnap.exists || salonSnap.data().isDeleted) {
      throw new HttpsError("not-found", "Peluquería no encontrada.");
    }
    const salon = salonSnap.data();
    const membership = membershipSnap.exists ? membershipSnap.data() : null;
    const belongsToSalon = membership &&
      membership.status === "active" && membership.salonId === targetId;
    if (salon.ownerId === uid || belongsToSalon) {
      throw new HttpsError(
          "failed-precondition",
          "No puedes reportar tu propia peluquería.",
      );
    }
    return {};
  }

  const appointmentId = (data.sourceAppointmentId || "").trim();
  if (!appointmentId) {
    throw new HttpsError(
        "failed-precondition",
        "El reporte de un cliente debe originarse desde una cita.",
    );
  }
  return assertSalonCanManageClient(uid, targetId, appointmentId);
}

/**
 * Crea un reporte con deduplicación básica (24h).
 */
const submitReport = onCall(async (request) => {
  const uid = await assertActiveAuth(request);
  const data = request.data || {};
  const targetType = data.targetType;
  const targetId = (data.targetId || "").trim();
  const category = (data.category || "").trim();
  const description = (data.description || "").trim();

  if (!TARGET_TYPES.includes(targetType)) {
    throw new HttpsError("invalid-argument", "targetType inválido.");
  }
  if (!targetId || !category) {
    throw new HttpsError(
        "invalid-argument",
        "targetId y category son obligatorios.",
    );
  }
  if (description.length > 2000) {
    throw new HttpsError(
        "invalid-argument",
        "La descripción es demasiado larga.",
    );
  }
  if (!CATEGORIES_BY_TARGET[targetType].includes(category)) {
    throw new HttpsError("invalid-argument", "Motivo de reporte inválido.");
  }

  const targetContext = await assertReportTargetAllowed(
      uid,
      targetType,
      targetId,
      data,
  );

  const cached = await findIdempotentResult("submitReport", data.idempotencyKey);
  if (cached) return cached;

  const dayBucket = new Date().toISOString().slice(0, 10);
  const dedupeKey = buildReportDedupeKey({
    reporterId: uid,
    targetType,
    targetId,
    category,
    dayBucket,
  });

  const existing = await db()
      .collection("reports")
      .where("dedupeKey", "==", dedupeKey)
      .limit(1)
      .get();
  if (!existing.empty) {
    const existingReportId = existing.docs[0].id;
    if (targetType === "user") {
      const blockRef = salonClientBlockRef(
          targetContext.sourceSalonId,
          targetId,
      );
      const blockSnap = await blockRef.get();
      if (!blockSnap.exists) {
        await blockRef.set({
          salonId: targetContext.sourceSalonId,
          userId: targetId,
          sourceAppointmentId: targetContext.sourceAppointmentId,
          reportId: existingReportId,
          category,
          reason: description || CATEGORY_LABELS[category],
          blockedBy: uid,
          blockedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
    const result = {reportId: existingReportId, deduped: true};
    await saveIdempotentResult("submitReport", data.idempotencyKey, result);
    return result;
  }

  const ref = db().collection("reports").doc();
  const batch = db().batch();
  const now = admin.firestore.FieldValue.serverTimestamp();
  batch.set(ref, {
    reporterId: uid,
    targetType,
    targetId,
    category,
    description: description || CATEGORY_LABELS[category],
    ...targetContext,
    status: "received",
    dedupeKey,
    createdAt: now,
    updatedAt: now,
  });

  addAuditLogToBatch(batch, {
    actorId: uid,
    action: "submitReport",
    entityType: "report",
    entityId: ref.id,
    after: {targetType, targetId, category, ...targetContext},
  });

  if (targetType === "user") {
    const blockRef = salonClientBlockRef(
        targetContext.sourceSalonId,
        targetId,
    );
    const blockSnap = await blockRef.get();
    batch.set(blockRef, {
      salonId: targetContext.sourceSalonId,
      userId: targetId,
      sourceAppointmentId: targetContext.sourceAppointmentId,
      reportId: ref.id,
      category,
      reason: description || CATEGORY_LABELS[category],
      blockedBy: uid,
      blockedAt: blockSnap.exists && blockSnap.data().blockedAt ?
        blockSnap.data().blockedAt : now,
      updatedAt: now,
    });
    if (!blockSnap.exists) {
      addInAppNotificationToBatch(batch, targetId, {
        type: "moderation",
        title: "Reservas bloqueadas",
        body: "Esta peluquería bloqueó nuevas reservas de tu cuenta.",
        data: {
          action: "salonClientBlock",
          salonId: targetContext.sourceSalonId,
          type: "moderation",
        },
      });
    }
  }

  await batch.commit();

  const result = {reportId: ref.id, deduped: false};
  await saveIdempotentResult("submitReport", data.idempotencyKey, result);
  return result;
});

module.exports = {submitReport};
