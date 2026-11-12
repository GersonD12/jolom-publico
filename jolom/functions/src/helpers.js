const {HttpsError} = require("firebase-functions/v2/https");
const {admin, db} = require("./init");

const DEFAULT_TZ = "America/Guatemala";
const DEFAULT_CURRENCY = "GTQ";
const DEFAULT_CITY = "Guatemala";
const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000;

/**
 * Exige usuario autenticado en un callable.
 * @param {import("firebase-functions/v2/https").CallableRequest} request
 * @return {string} uid
 */
function assertAuth(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  return request.auth.uid;
}

/**
 * Exige una cuenta autenticada y habilitada para operar.
 *
 * Se consulta Firestore en cada callable sensible para que una solicitud de
 * eliminación bloquee también tokens emitidos antes de revocar la sesión.
 * @param {import("firebase-functions/v2/https").CallableRequest} request
 * @return {Promise<string>} uid
 */
async function assertActiveAuth(request) {
  const uid = assertAuth(request);
  const snap = await db().collection("users").doc(uid).get();
  const user = snap.exists ? snap.data() : null;
  const accountStatus = user && user.accountStatus;
  const isActiveStatus = !accountStatus || accountStatus === "active";
  if (
    !user ||
    !isActiveStatus ||
    user.isBanned === true ||
    user.isDeleted === true ||
    user.moderationStatus === "banned"
  ) {
    throw new HttpsError(
        "failed-precondition",
        "La cuenta no está habilitada para realizar esta acción.",
    );
  }
  return uid;
}

/** Agrega una entrada de auditoría a un WriteBatch. */
function addAuditLogToBatch(batch, entry) {
  const ref = db().collection("auditLogs").doc();
  batch.set(ref, {
    actorId: entry.actorId || null,
    action: entry.action,
    entityType: entry.entityType,
    entityId: entry.entityId,
    before: entry.before || null,
    after: entry.after || null,
    reason: entry.reason || null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return ref.id;
}

/**
 * @param {FirebaseFirestore.Transaction|FirebaseFirestore.WriteBatch|null} tx
 * @param {object} entry
 */
async function writeAuditLog(entry) {
  const ref = db().collection("auditLogs").doc();
  await ref.set({
    actorId: entry.actorId || null,
    action: entry.action,
    entityType: entry.entityType,
    entityId: entry.entityId,
    before: entry.before || null,
    after: entry.after || null,
    reason: entry.reason || null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Crea un ítem en la bandeja in-app y actualiza unreadCount.
 * @param {string} userId
 * @param {object} payload
 * @param {FirebaseFirestore.Transaction=} transaction
 */
async function createInAppNotification(userId, payload, transaction) {
  const userNotifRef = db().collection("notifications").doc(userId);
  const itemRef = userNotifRef.collection("items").doc();
  const item = {
    type: payload.type,
    title: payload.title,
    body: payload.body,
    data: payload.data || {},
    deepLink: payload.deepLink || null,
    readAt: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (transaction) {
    const snap = await transaction.get(userNotifRef);
    const unread = snap.exists ? (snap.data().unreadCount || 0) : 0;
    transaction.set(itemRef, item);
    transaction.set(
        userNotifRef,
        {
          unreadCount: unread + 1,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
    );
    return itemRef.id;
  }

  await db().runTransaction(async (tx) => {
    const snap = await tx.get(userNotifRef);
    const unread = snap.exists ? (snap.data().unreadCount || 0) : 0;
    tx.set(itemRef, item);
    tx.set(
        userNotifRef,
        {
          unreadCount: unread + 1,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
    );
  });
  return itemRef.id;
}

/** Agrega una notificación in-app y su contador a un WriteBatch. */
function addInAppNotificationToBatch(batch, userId, payload) {
  if (!userId || !payload || !payload.type || !payload.title || !payload.body) {
    return null;
  }
  const userNotifRef = db().collection("notifications").doc(userId);
  const itemRef = userNotifRef.collection("items").doc();
  const data = Object.assign({}, payload.data || {}, {type: payload.type});
  batch.set(itemRef, {
    type: payload.type,
    title: payload.title,
    body: payload.body,
    data,
    deepLink: payload.deepLink || null,
    readAt: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  batch.set(userNotifRef, {
    unreadCount: admin.firestore.FieldValue.increment(1),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  return itemRef.id;
}

/**
 * Envía push FCM a todos los tokens registrados del usuario.
 * Primitiva interna: preferir [notifyUser]. No lanza.
 * @param {string} userId
 * @param {{title: string, body: string, data?: object}} payload
 */
async function sendFcmToUser(userId, payload) {
  if (!userId) return;
  try {
    const userSnap = await db().collection("users").doc(userId).get();
    const tokens = (userSnap.data() && userSnap.data().fcmTokens) || [];
    if (!Array.isArray(tokens) || tokens.length === 0) return;

    const data = {};
    const raw = payload.data || {};
    for (const key of Object.keys(raw)) {
      const value = raw[key];
      if (value === undefined || value === null) continue;
      data[key] = String(value);
    }

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data,
    });

    // Limpia tokens inválidos reportados por FCM.
    const invalid = [];
    response.responses.forEach((res, i) => {
      if (!res.success) {
        const code = res.error && res.error.code;
        if (
          code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered"
        ) {
          invalid.push(tokens[i]);
        }
      }
    });
    if (invalid.length > 0) {
      await db()
          .collection("users")
          .doc(userId)
          .update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalid),
          });
    }
  } catch (_) {
    // No bloquear por fallos FCM.
  }
}

/**
 * Bandeja in-app + push FCM opcional (mismo title/body).
 * Único punto de emisión desde callables/schedulers.
 * @param {string} userId
 * @param {{
 *   type: string,
 *   title: string,
 *   body: string,
 *   data?: object,
 *   deepLink?: string|null,
 *   push?: boolean,
 * }} payload
 * @param {FirebaseFirestore.Transaction=} transaction
 * @return {Promise<string|undefined>} id del ítem in-app
 */
async function notifyUser(userId, payload, transaction) {
  if (!userId || !payload) return;
  const type = payload.type;
  const title = payload.title;
  const body = payload.body;
  if (!type || !title || !body) {
    return;
  }

  const data = Object.assign({}, payload.data || {}, {type});
  const itemPayload = {
    type,
    title,
    body,
    data,
    deepLink: payload.deepLink || null,
  };

  const itemId = await createInAppNotification(
      userId,
      itemPayload,
      transaction,
  );

  if (payload.push === true) {
    // Push fuera de la transacción de bandeja (messaging es I/O externo).
    await sendFcmToUser(userId, {
      title,
      body,
      data,
    });
  }

  return itemId;
}

/**
 * Busca operaciones ya procesadas por clave de idempotencia.
 * @param {string} scope
 * @param {string|undefined|null} key
 * @return {Promise<object|null>}
 */
async function findIdempotentResult(scope, key) {
  if (!key) return null;
  const snap = await db()
      .collection("idempotencyKeys")
      .doc(`${scope}_${key}`)
      .get();
  if (!snap.exists) return null;
  return snap.data().result || null;
}

/**
 * @param {string} scope
 * @param {string|undefined|null} key
 * @param {object} result
 */
async function saveIdempotentResult(scope, key, result) {
  if (!key) return;
  await db()
      .collection("idempotencyKeys")
      .doc(`${scope}_${key}`)
      .set({
        scope,
        key,
        result,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
}

/**
 * Lookup de usuario por email (campo users.email en minúsculas).
 * @param {string} email
 * @return {Promise<{id: string, data: object}|null>}
 */
async function findUserByEmail(email) {
  const normalized = email.trim().toLowerCase();
  const snap = await db()
      .collection("users")
      .where("email", "==", normalized)
      .limit(1)
      .get();
  if (snap.empty) return null;
  const doc = snap.docs[0];
  return {id: doc.id, data: doc.data()};
}

module.exports = {
  assertAuth,
  assertActiveAuth,
  addAuditLogToBatch,
  addInAppNotificationToBatch,
  writeAuditLog,
  createInAppNotification,
  sendFcmToUser,
  notifyUser,
  findIdempotentResult,
  saveIdempotentResult,
  findUserByEmail,
  DEFAULT_TZ,
  DEFAULT_CURRENCY,
  DEFAULT_CITY,
  INVITE_TTL_MS,
  HttpsError,
  admin,
  db,
};
