const crypto = require("crypto");
const {onCall} = require("firebase-functions/v2/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {
  assertAuth,
  writeAuditLog,
  notifyUser,
  HttpsError,
  admin,
  db,
  DEFAULT_TZ,
} = require("./helpers");
const {
  AppointmentNotificationOpenMode,
  AppointmentNotificationKind,
  buildAppointmentNotification,
} = require("./appointment_notifications");
const {
  SALON_CLIENT_BLOCKS_COLLECTION,
} = require("./salon_client_blocks");
const {
  SALON_REFERENCE_CLEANUP_POLICY,
  USER_REFERENCE_CLEANUP_POLICY,
} = require("./account_deletion_cleanup_policy");

const JOBS = "accountDeletionJobs";
const QUERY_BATCH_SIZE = 100;
const JOB_LEASE_MS = 8 * 60 * 1000;
const TOMBSTONE_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const ACTIVE_APPOINTMENT_STATUSES = new Set(["pending", "confirmed"]);
const RECENT_LOGIN_MAX_AGE_MS = 30 * 60 * 1000;

/**
 * @param {unknown} value
 * @return {number}
 */
function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  const parsed = new Date(value || 0).getTime();
  return Number.isNaN(parsed) ? 0 : parsed;
}

/**
 * @param {string} kind
 * @param {string} anonymousId
 * @return {string}
 */
function anonymousReference(kind, anonymousId) {
  return `anonymous_${kind}_${anonymousId}`;
}

/**
 * Genera un seudónimo distinto por negocio para impedir correlación entre
 * historiales de peluquerías diferentes.
 * @param {string} kind
 * @param {string} anonymousId
 * @param {string} scope
 * @return {string}
 */
function scopedAnonymousReference(kind, anonymousId, scope) {
  const digest = crypto
      .createHash("sha256")
      .update(`${anonymousId}:${scope}:${kind}`)
      .digest("hex")
      .slice(0, 24);
  return `anonymous_${kind}_${digest}`;
}

/**
 * @param {Array<object>|unknown} raw
 * @param {string} uid
 * @param {string} anonymousActorId
 * @return {Array<object>}
 */
function anonymizeHistory(raw, uid, anonymousActorId) {
  if (!Array.isArray(raw)) return [];
  return raw.map((entry) => {
    if (!entry || typeof entry !== "object") return entry;
    return {
      ...entry,
      actorId: entry.actorId === uid ? anonymousActorId : entry.actorId,
      reason: null,
    };
  });
}

/**
 * Drena una consulta. El callback debe sacar cada documento de la consulta o
 * devolver delete=true para garantizar progreso e idempotencia.
 * @param {() => FirebaseFirestore.Query} queryFactory
 * @param {(doc: FirebaseFirestore.QueryDocumentSnapshot) =>
 *   Promise<{delete?: boolean, patch?: object,
 *     afterCommit?: () => Promise<void>}>} transform
 * @return {Promise<number>}
 */
async function drainQuery(queryFactory, transform) {
  let changed = 0;
  let hasDocuments = true;
  while (hasDocuments) {
    const snap = await queryFactory().limit(QUERY_BATCH_SIZE).get();
    hasDocuments = !snap.empty;
    if (!hasDocuments) break;
    const batch = db().batch();
    const afterCommit = [];
    for (const doc of snap.docs) {
      const action = await transform(doc);
      if (action.delete) {
        batch.delete(doc.ref);
      } else if (action.patch) {
        batch.update(doc.ref, action.patch);
      }
      if (action.afterCommit) afterCommit.push(action.afterCommit);
      changed += 1;
    }
    await batch.commit();
    for (const callback of afterCommit) {
      try {
        await callback();
      } catch (_) {
        // La limpieza ya quedó aplicada; una notificación no debe reabrirla.
      }
    }
  }
  return changed;
}

/**
 * @param {string} prefix
 */
async function deleteStoragePrefix(prefix) {
  try {
    await admin.storage().bucket().deleteFiles({prefix});
  } catch (error) {
    const code = error && error.code;
    if (code !== 404 && code !== "storage/object-not-found") throw error;
  }
}

/**
 * Conserva solo métricas agregadas bajo una identidad aleatoria sin vínculo
 * con el uid o salonId originales.
 * @param {string} sourceId
 * @param {string} targetId
 * @param {string} scopeType
 * @param {string} scopeId
 * @return {Promise<boolean>}
 */
async function anonymizeStats(sourceId, targetId, scopeType, scopeId) {
  const sourceRef = db().collection("stats").doc(sourceId);
  const targetRef = db().collection("stats").doc(targetId);
  const source = await sourceRef.get();
  if (!source.exists) return false;
  const data = source.data();
  const allowed = [
    "requests",
    "confirmed",
    "completed",
    "cancellations",
    "noShow",
    "estimatedRevenue",
    "qrOpens",
    "periods",
  ];
  const aggregate = {};
  for (const key of allowed) {
    if (data[key] !== undefined) aggregate[key] = data[key];
  }
  await targetRef.set({
    ...aggregate,
    scopeType,
    scopeId,
    isAnonymized: true,
    anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await sourceRef.delete();
  return true;
}

/**
 * Elimina notificaciones de terceros que puedan contener texto o payloads
 * vinculados a la identidad que se está eliminando.
 * @param {string} fieldPath
 * @param {string} value
 * @return {Promise<number>}
 */
async function deleteReferencedNotifications(fieldPath, value) {
  if (!value) return 0;
  return drainQuery(
      () => db().collectionGroup("items").where(fieldPath, "==", value),
      async () => ({delete: true}),
  );
}

/**
 * @param {string} uid
 * @param {string} anonymousId
 * @param {object} counters
 */
async function anonymizeClientAppointments(uid, anonymousId, counters) {
  const nowMs = Date.now();
  counters.clientAppointments += await drainQuery(
      () => db().collection("appointments").where("clientId", "==", uid),
      async (doc) => {
        const appointment = doc.data();
        const clientRef = scopedAnonymousReference(
            "client",
            anonymousId,
            String(appointment.salonId || "unknown"),
        );
        const actorRef = scopedAnonymousReference(
            "actor",
            anonymousId,
            String(appointment.salonId || "unknown"),
        );
        const history = anonymizeHistory(
            appointment.statusHistory,
            uid,
            actorRef,
        );
        const future = timestampMillis(appointment.startAt) > nowMs;
        const active = ACTIVE_APPOINTMENT_STATUSES.has(appointment.status);
        const patch = {
          clientId: clientRef,
          clientAnonymized: true,
          notes: admin.firestore.FieldValue.delete(),
          idempotencyKey: admin.firestore.FieldValue.delete(),
          statusHistory: history,
          anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        let afterCommit;
        if (future && active) {
          patch.status = "cancelledByClient";
          patch.statusHistory = [
            ...history,
            {
              from: appointment.status,
              to: "cancelledByClient",
              actorId: "system",
              at: admin.firestore.Timestamp.now(),
              source: "accountDeletion",
            },
          ];
          if (appointment.barberId && appointment.barberId !== uid) {
            afterCommit = () => notifyUser(
                appointment.barberId,
                buildAppointmentNotification({
                  appointmentId: doc.id,
                  openMode: AppointmentNotificationOpenMode.WORK,
                  kind: AppointmentNotificationKind.ACCOUNT_DELETION,
                  status: "cancelledByClient",
                  title: "Cita cancelada",
                  body: "La cita fue cancelada porque el cliente eliminó su cuenta.",
                  push: true,
                }),
            );
          }
        }
        return {patch, afterCommit};
      },
  );
}

/**
 * @param {string} uid
 * @param {string} anonymousId
 * @param {object} counters
 */
async function anonymizeBarberAppointments(uid, anonymousId, counters) {
  const nowMs = Date.now();
  counters.barberAppointments += await drainQuery(
      () => db().collection("appointments").where("barberId", "==", uid),
      async (doc) => {
        const appointment = doc.data();
        const barberRef = scopedAnonymousReference(
            "barber",
            anonymousId,
            String(appointment.salonId || "unknown"),
        );
        const actorRef = scopedAnonymousReference(
            "actor",
            anonymousId,
            String(appointment.salonId || "unknown"),
        );
        const history = anonymizeHistory(
            appointment.statusHistory,
            uid,
            actorRef,
        );
        const future = timestampMillis(appointment.startAt) > nowMs;
        const active = ACTIVE_APPOINTMENT_STATUSES.has(appointment.status);
        const patch = {
          barberId: barberRef,
          barberAnonymized: true,
          notes: admin.firestore.FieldValue.delete(),
          idempotencyKey: admin.firestore.FieldValue.delete(),
          statusHistory: history,
          anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        let afterCommit;
        if (future && active) {
          patch.status = "cancelledByBusiness";
          patch.statusHistory = [
            ...history,
            {
              from: appointment.status,
              to: "cancelledByBusiness",
              actorId: "system",
              at: admin.firestore.Timestamp.now(),
              source: "accountDeletion",
            },
          ];
          if (appointment.clientId && appointment.clientId !== uid) {
            afterCommit = () => notifyUser(
                appointment.clientId,
                buildAppointmentNotification({
                  appointmentId: doc.id,
                  openMode: AppointmentNotificationOpenMode.CLIENT,
                  kind: AppointmentNotificationKind.ACCOUNT_DELETION,
                  status: "cancelledByBusiness",
                  title: "Cita cancelada",
                  body: "La cita fue cancelada porque el profesional eliminó su cuenta.",
                  push: true,
                }),
            );
          }
        }
        return {patch, afterCommit};
      },
  );
}

/**
 * @param {string} uid
 * @return {Promise<number>}
 */
async function removeBarberFromServices(uid) {
  return drainQuery(
      () => db()
          .collection("services")
          .where("enabledBarberIds", "array-contains", uid),
      async () => ({
        patch: {
          enabledBarberIds: admin.firestore.FieldValue.arrayRemove(uid),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      }),
  );
}

/**
 * @param {string} uid
 * @param {string|null} email
 * @param {string} anonymousId
 * @return {Promise<number>}
 */
async function anonymizeInvitations(uid, email, anonymousId) {
  const userRef = anonymousReference("user", anonymousId);
  let count = 0;
  count += await drainQuery(
      () => db().collection("salonInvitations").where("inviterId", "==", uid),
      async () => ({
        patch: {
          inviterId: userRef,
          status: "invalidated",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      }),
  );
  count += await drainQuery(
      () => db().collection("salonInvitations").where("inviteeId", "==", uid),
      async () => ({
        patch: {
          inviteeId: userRef,
          inviteeEmail: null,
          status: "invalidated",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      }),
  );
  if (email) {
    count += await drainQuery(
        () => db()
            .collection("salonInvitations")
            .where("inviteeEmail", "==", email),
        async () => ({
          patch: {
            inviteeEmail: null,
            status: "invalidated",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        }),
    );
  }
  return count;
}

/**
 * @param {string} uid
 * @param {string} anonymousId
 * @param {object} counters
 */
async function anonymizeUserReferences(uid, anonymousId, counters) {
  const userRef = anonymousReference("user", anonymousId);
  const genericReason = "Contenido anonimizado por eliminación de cuenta.";

  counters.salonClientBlocks += await drainQuery(
      () => db()
          .collection(SALON_CLIENT_BLOCKS_COLLECTION)
          .where("userId", "==", uid),
      async () => ({delete: true}),
  );
  counters.salonClientBlocks += await drainQuery(
      () => db()
          .collection(SALON_CLIENT_BLOCKS_COLLECTION)
          .where("blockedBy", "==", uid),
      async (doc) => ({
        patch: {
          blockedBy: scopedAnonymousReference(
              "actor",
              anonymousId,
              doc.data().salonId || doc.id,
          ),
          reason: "Bloqueo conservado con identidad anonimizada.",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      }),
  );

  counters.reports += await drainQuery(
      () => db().collection("reports").where("reporterId", "==", uid),
      async (doc) => {
        await deleteStoragePrefix(`reports/${doc.id}/evidence/`);
        return {
          patch: {
            reporterId: userRef,
            description: genericReason,
            dedupeKey: admin.firestore.FieldValue.delete(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        };
      },
  );
  counters.reports += await drainQuery(
      () => db().collection("reports").where("targetId", "==", uid),
      async (doc) => {
        await deleteStoragePrefix(`reports/${doc.id}/evidence/`);
        return {
          patch: {
            targetId: userRef,
            description: genericReason,
            dedupeKey: admin.firestore.FieldValue.delete(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        };
      },
  );

  counters.moderationCases += await drainQuery(
      () => db().collection("moderationCases").where("actorId", "==", uid),
      async () => ({
        patch: {
          actorId: userRef,
          reason: genericReason,
          notesInternal: null,
          resolution: genericReason,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      }),
  );
  counters.moderationCases += await drainQuery(
      () => db().collection("moderationCases").where("targetId", "==", uid),
      async (doc) => ({
        patch: {
          targetId: userRef,
          reason: genericReason,
          notesInternal: null,
          resolution: genericReason,
          status: doc.data().action === "accountDeletionRequest" ?
            "resolved" : doc.data().status,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      }),
  );

  counters.auditLogs += await drainQuery(
      () => db().collection("auditLogs").where("actorId", "==", uid),
      async () => ({
        patch: {
          actorId: userRef,
          before: null,
          after: null,
          reason: null,
        },
      }),
  );
  counters.auditLogs += await drainQuery(
      () => db().collection("auditLogs").where("entityId", "==", uid),
      async () => ({
        patch: {
          entityId: userRef,
          before: null,
          after: null,
          reason: null,
        },
      }),
  );
  const embeddedUserFields = [
    "before.userId",
    "before.clientId",
    "before.barberId",
    "before.targetUserId",
    "before.targetId",
    "before.inviteeId",
    "before.inviterId",
    "before.ownerId",
    "before.reporterId",
    "before.blockedBy",
    "after.userId",
    "after.clientId",
    "after.barberId",
    "after.targetUserId",
    "after.targetId",
    "after.inviteeId",
    "after.inviterId",
    "after.ownerId",
    "after.reporterId",
    "after.blockedBy",
  ];
  for (const field of embeddedUserFields) {
    counters.auditLogs += await drainQuery(
        () => db().collection("auditLogs").where(field, "==", uid),
        async () => ({
          patch: {before: null, after: null, reason: null},
        }),
    );
  }

  for (const field of [
    "result.userId",
    "result.clientId",
    "result.barberId",
    "result.targetUserId",
    "result.targetId",
  ]) {
    counters.idempotencyKeys += await drainQuery(
        () => db().collection("idempotencyKeys").where(field, "==", uid),
        async () => ({delete: true}),
    );
  }

  for (const path of ["data.userId", "data.clientId", "data.targetId"]) {
    counters.notifications += await deleteReferencedNotifications(path, uid);
  }
}

/**
 * @param {string} salonId
 * @param {string} anonymousId
 * @param {object} counters
 */
async function anonymizeSalonReferences(salonId, anonymousId, counters) {
  const salonRef = anonymousReference("salon", anonymousId);
  const genericReason = "Contenido anonimizado por eliminación de negocio.";
  counters.reports += await drainQuery(
      () => db().collection("reports").where("targetId", "==", salonId),
      async (doc) => {
        await deleteStoragePrefix(`reports/${doc.id}/evidence/`);
        return {
          patch: {
            targetId: salonRef,
            description: genericReason,
            dedupeKey: admin.firestore.FieldValue.delete(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        };
      },
  );
  counters.reports += await drainQuery(
      () => db().collection("reports").where("sourceSalonId", "==", salonId),
      async (doc) => {
        await deleteStoragePrefix(`reports/${doc.id}/evidence/`);
        return {
          patch: {
            sourceSalonId: salonRef,
            sourceAppointmentId: admin.firestore.FieldValue.delete(),
            description: genericReason,
            dedupeKey: admin.firestore.FieldValue.delete(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        };
      },
  );
  counters.moderationCases += await drainQuery(
      () => db().collection("moderationCases").where("targetId", "==", salonId),
      async () => ({
        patch: {
          targetId: salonRef,
          reason: genericReason,
          notesInternal: null,
          resolution: genericReason,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      }),
  );
  counters.auditLogs += await drainQuery(
      () => db().collection("auditLogs").where("entityId", "==", salonId),
      async () => ({
        patch: {
          entityId: salonRef,
          before: null,
          after: null,
          reason: null,
        },
      }),
  );
  for (const field of ["before.salonId", "after.salonId"]) {
    counters.auditLogs += await drainQuery(
        () => db().collection("auditLogs").where(field, "==", salonId),
        async () => ({
          patch: {before: null, after: null, reason: null},
        }),
    );
  }
  counters.idempotencyKeys += await drainQuery(
      () => db()
          .collection("idempotencyKeys")
          .where("result.salonId", "==", salonId),
      async () => ({delete: true}),
  );
  counters.notifications += await deleteReferencedNotifications(
      "data.salonId",
      salonId,
  );
}

/**
 * Elimina un negocio y conserva únicamente su agregado estadístico anónimo.
 * @param {string} salonId
 * @param {string} uid
 * @param {string} anonymousId
 * @param {object} counters
 */
async function cleanupSalonReferences(salonId, uid, anonymousId, counters) {
  const salonRef = db().collection("salons").doc(salonId);
  const salonSnap = await salonRef.get();
  counters.salonClientBlocks += await drainQuery(
      () => db()
          .collection(SALON_CLIENT_BLOCKS_COLLECTION)
          .where("salonId", "==", salonId),
      async () => ({delete: true}),
  );

  counters.salonAppointments += await drainQuery(
      () => db().collection("appointments").where("salonId", "==", salonId),
      async (doc) => {
        const appointment = doc.data();
        const future = timestampMillis(appointment.startAt) > Date.now();
        let afterCommit;
        if (
          future &&
          ACTIVE_APPOINTMENT_STATUSES.has(appointment.status) &&
          appointment.clientId &&
          appointment.clientId !== uid
        ) {
          afterCommit = () => notifyUser(
              appointment.clientId,
              buildAppointmentNotification({
                appointmentId: doc.id,
                openMode: AppointmentNotificationOpenMode.CLIENT,
                kind: AppointmentNotificationKind.ACCOUNT_DELETION,
                status: "cancelledByBusiness",
                title: "Cita cancelada",
                body: "La cita fue cancelada porque el negocio cerró su cuenta.",
                push: true,
              }),
          );
        }
        return {delete: true, afterCommit};
      },
  );

  counters.services += await drainQuery(
      () => db().collection("services").where("salonId", "==", salonId),
      async () => ({delete: true}),
  );
  counters.invitations += await drainQuery(
      () => db()
          .collection("salonInvitations")
          .where("salonId", "==", salonId),
      async () => ({delete: true}),
  );

  const members = await db()
      .collection("salonMemberships")
      .where("salonId", "==", salonId)
      .get();
  for (const member of members.docs) {
    if (member.id !== uid) {
      try {
        await notifyUser(member.id, {
          type: "membership",
          title: "Negocio eliminado",
          body: "El propietario eliminó el negocio. Tu cuenta personal sigue activa.",
          data: {type: "membership"},
          push: true,
        });
      } catch (_) {
        // La notificación no debe bloquear la eliminación del negocio.
      }
    }
    await db().recursiveDelete(
        db().collection("availability").doc(member.id),
    );
    await member.ref.delete();
    counters.memberships += 1;
  }

  await anonymizeSalonReferences(salonId, anonymousId, counters);
  if (await anonymizeStats(
      `salon_${salonId}`,
      `anonymized_salon_${anonymousId}`,
      "anonymizedSalon",
      anonymousReference("salon", anonymousId),
  )) {
    counters.stats += 1;
  }
  await deleteStoragePrefix(`negocios/${salonId}/`);
  await salonRef.delete();
  if (salonSnap.exists) counters.salons += 1;
}

/**
 * Orquesta todas las referencias externas del usuario antes del tombstone y
 * Firebase Auth. Toda relación nueva debe declararse en la política importada.
 * @param {string} uid
 * @param {string} anonymousId
 * @param {object} user
 * @param {object} counters
 */
async function cleanupUserReferences(uid, anonymousId, user, counters) {
  await anonymizeClientAppointments(uid, anonymousId, counters);
  await anonymizeBarberAppointments(uid, anonymousId, counters);
  counters.services += await removeBarberFromServices(uid);
  counters.invitations += await anonymizeInvitations(
      uid,
      typeof user.email === "string" ? user.email : null,
      anonymousId,
  );
  await anonymizeUserReferences(uid, anonymousId, counters);

  await db().recursiveDelete(db().collection("availability").doc(uid));
  await db().collection("barberProfiles").doc(uid).delete().catch(() => {});
  await db().collection("salonMemberships").doc(uid).delete().catch(() => {});
  await db().recursiveDelete(db().collection("notifications").doc(uid));
  await deleteStoragePrefix(`users/${uid}/`);
  if (await anonymizeStats(
      `barber_${uid}`,
      `anonymized_barber_${anonymousId}`,
      "anonymizedBarber",
      anonymousReference("barber", anonymousId),
  )) {
    counters.stats += 1;
  }
}

/**
 * @return {object}
 */
function emptyCounters() {
  return {
    salons: 0,
    salonClientBlocks: 0,
    services: 0,
    memberships: 0,
    invitations: 0,
    salonAppointments: 0,
    clientAppointments: 0,
    barberAppointments: 0,
    reports: 0,
    moderationCases: 0,
    auditLogs: 0,
    notifications: 0,
    idempotencyKeys: 0,
    stats: 0,
  };
}

/**
 * Encola una eliminación desde autoservicio o moderación administrativa.
 * @param {{uid: string, actorId: string, actorType: string}} input
 * @return {Promise<object>}
 */
async function enqueueAccountDeletion(input) {
  const {uid, actorId, actorType} = input;
  const userRef = db().collection("users").doc(uid);
  const jobRef = db().collection(JOBS).doc(uid);
  const membershipRef = db().collection("salonMemberships").doc(uid);
  const ownedSalons = await db()
      .collection("salons")
      .where("ownerId", "==", uid)
      .get();
  const salonIds = ownedSalons.docs.map((doc) => doc.id);
  const anonymousId = crypto.randomUUID();

  const result = await db().runTransaction(async (tx) => {
    const [userSnap, jobSnap, membershipSnap] = await Promise.all([
      tx.get(userRef),
      tx.get(jobRef),
      tx.get(membershipRef),
    ]);
    if (jobSnap.exists) {
      const job = jobSnap.data();
      return {
        jobId: jobRef.id,
        status: job.status,
        role: job.role,
        anonymousId: job.anonymousId,
      };
    }
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "Perfil de usuario no encontrado.");
    }
    const membership = membershipSnap.exists ? membershipSnap.data() : null;
    const role = salonIds.length > 0 ?
      "owner" :
      membership && membership.role === "barber" ? "barber" : "client";
    const now = admin.firestore.FieldValue.serverTimestamp();
    tx.set(jobRef, {
      userId: uid,
      anonymousId,
      actorId,
      actorType,
      role,
      salonIds,
      status: "queued",
      attempts: 0,
      requestedAt: now,
      updatedAt: now,
    });
    tx.update(userRef, {
      accountStatus: "deletionPending",
      deletionRequestedAt: now,
      deletionJobId: jobRef.id,
      fcmTokens: [],
      updatedAt: now,
    });
    if (membership && role === "barber") {
      tx.update(membershipRef, {
        status: "withdrawn",
        leftAt: now,
        updatedAt: now,
      });
    }
    for (const salon of ownedSalons.docs) {
      tx.update(salon.ref, {
        publishStatus: "deleted",
        isDeleted: true,
        updatedAt: now,
      });
    }
    return {jobId: jobRef.id, status: "queued", role, anonymousId};
  });

  if (result.role === "barber" || result.role === "owner") {
    try {
      await db().collection("barberProfiles").doc(uid).set({
        status: "suspended",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    } catch (_) {
      // El worker volverá a eliminar el perfil; no reabrir la cuenta.
    }
  }

  try {
    const authUser = await admin.auth().getUser(uid);
    await admin.auth().setCustomUserClaims(uid, {
      ...(authUser.customClaims || {}),
      accountStatus: "deletionPending",
    });
    await admin.auth().revokeRefreshTokens(uid);
  } catch (_) {
    // Firestore ya bloquea la cuenta y el worker eliminará Auth al terminar.
  }

  try {
    await writeAuditLog({
      actorId: actorType === "self" ?
        anonymousReference("actor", result.anonymousId) : actorId,
      action: "enqueueAccountDeletion",
      entityType: "anonymousUser",
      entityId: anonymousReference("user", result.anonymousId),
      after: {status: result.status, role: result.role || null},
    });
  } catch (_) {
    // El trabajo ya está en cola; la auditoría no debe revertir el bloqueo.
  }
  return result;
}

/**
 * @param {string} jobId
 * @return {Promise<object|null>}
 */
async function claimJob(jobId) {
  const ref = db().collection(JOBS).doc(jobId);
  return db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return null;
    const job = snap.data();
    if (job.status === "completed") return null;
    if (
      job.status === "processing" &&
      timestampMillis(job.leaseExpiresAt) > Date.now()
    ) {
      return null;
    }
    if (!["queued", "failed", "processing"].includes(job.status)) return null;
    const now = admin.firestore.Timestamp.now();
    tx.update(ref, {
      status: "processing",
      attempts: Number(job.attempts || 0) + 1,
      startedAt: job.startedAt || now,
      leaseExpiresAt: admin.firestore.Timestamp.fromMillis(
          Date.now() + JOB_LEASE_MS,
      ),
      lastError: null,
      updatedAt: now,
    });
    return {...job, attempts: Number(job.attempts || 0) + 1};
  });
}

/**
 * @param {string} jobId
 * @return {Promise<boolean>}
 */
async function processDeletionJob(jobId) {
  if (jobId.startsWith("completed_")) return false;
  const job = await claimJob(jobId);
  if (!job) return false;
  const ref = db().collection(JOBS).doc(jobId);
  const uid = job.userId || jobId;
  const anonymousId = job.anonymousId;
  const counters = emptyCounters();
  try {
    const userRef = db().collection("users").doc(uid);
    const userSnap = await userRef.get();
    const user = userSnap.exists ? userSnap.data() : {};
    if (userSnap.exists) {
      await userRef.update({
        accountStatus: "deleting",
        fcmTokens: [],
        deletionStartedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    const salonIds = new Set(Array.isArray(job.salonIds) ? job.salonIds : []);
    const ownedSalons = await db()
        .collection("salons")
        .where("ownerId", "==", uid)
        .get();
    ownedSalons.docs.forEach((doc) => salonIds.add(doc.id));
    for (const salonId of salonIds) {
      await cleanupSalonReferences(salonId, uid, anonymousId, counters);
    }

    await cleanupUserReferences(uid, anonymousId, user, counters);

    const purgeAfter = admin.firestore.Timestamp.fromMillis(
        Date.now() + TOMBSTONE_TTL_MS,
    );
    await userRef.set({
      email: null,
      displayName: null,
      photoUrl: null,
      phone: null,
      capabilities: {client: false, barber: false},
      fcmTokens: [],
      accountStatus: "deleted",
      isBanned: false,
      isDeleted: true,
      moderationStatus: "none",
      deletionCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
      purgeAfter,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    try {
      await admin.auth().deleteUser(uid);
    } catch (error) {
      if (error.code !== "auth/user-not-found") throw error;
    }

    const archiveRef = db()
        .collection(JOBS)
        .doc(`completed_${anonymousId}`);
    const batch = db().batch();
    batch.set(archiveRef, {
      anonymousId,
      actorType: job.actorType || "self",
      role: job.role || "client",
      status: "completed",
      attempts: job.attempts || 1,
      counters,
      requestedAt: job.requestedAt || null,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      purgeAfter,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    batch.delete(ref);
    await batch.commit();
    try {
      await writeAuditLog({
        actorId: "system",
        action: "completeAccountDeletion",
        entityType: "anonymousUser",
        entityId: anonymousReference("user", anonymousId),
        after: {role: job.role || "client", counters},
      });
    } catch (_) {
      // El trabajo ya terminó; una auditoría tardía no debe recrear la cola.
    }
    return true;
  } catch (error) {
    await ref.set({
      status: "failed",
      lastError: String(error.code || "unknown"),
      leaseExpiresAt: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    throw error;
  }
}

/** Solicitud autoservicio. No requiere aprobación administrativa. */
const requestAccountDeletion = onCall(async (request) => {
  const uid = assertAuth(request);
  const authTimeSeconds = Number(request.auth.token.auth_time || 0);
  const authAge = Date.now() - authTimeSeconds * 1000;
  if (!authTimeSeconds || authAge > RECENT_LOGIN_MAX_AGE_MS) {
    throw new HttpsError(
        "failed-precondition",
        "Por seguridad, vuelve a iniciar sesión antes de eliminar tu cuenta.",
    );
  }
  return enqueueAccountDeletion({
    uid,
    actorId: uid,
    actorType: "self",
  });
});

/** Procesa inmediatamente trabajos recién creados. */
const onAccountDeletionJobCreated = onDocumentCreated(
    {
      document: `${JOBS}/{jobId}`,
      retry: true,
    },
    async (event) => {
      await processDeletionJob(event.params.jobId);
    },
);

/** Recupera trabajos fallidos o leases interrumpidos. */
const recoverAccountDeletions = onSchedule(
    {
      schedule: "every 10 minutes",
      timeZone: DEFAULT_TZ,
    },
    async () => {
      const ids = new Set();
      for (const status of ["queued", "failed", "processing"]) {
        const snap = await db()
            .collection(JOBS)
            .where("status", "==", status)
            .limit(20)
            .get();
        snap.docs.forEach((doc) => ids.add(doc.id));
      }
      for (const id of ids) {
        try {
          await processDeletionJob(id);
        } catch (_) {
          // El trabajo conserva failed y se reintentará en la siguiente corrida.
        }
      }
    },
);

/** Elimina tombstones operativos después del plazo de seguridad. */
const purgeAccountDeletionTombstones = onSchedule(
    {
      schedule: "every 24 hours",
      timeZone: DEFAULT_TZ,
    },
    async () => {
      const now = admin.firestore.Timestamp.now();
      for (const collection of ["users", JOBS]) {
        const snap = await db()
            .collection(collection)
            .where("purgeAfter", "<=", now)
            .limit(200)
            .get();
        if (snap.empty) continue;
        const batch = db().batch();
        snap.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
      }
    },
);

module.exports = {
  SALON_REFERENCE_CLEANUP_POLICY,
  USER_REFERENCE_CLEANUP_POLICY,
  cleanupSalonReferences,
  cleanupUserReferences,
  requestAccountDeletion,
  onAccountDeletionJobCreated,
  recoverAccountDeletions,
  purgeAccountDeletionTombstones,
  enqueueAccountDeletion,
  processDeletionJob,
};
