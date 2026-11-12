const functions = require("firebase-functions/v1");
const {onCall} = require("firebase-functions/v2/https");
const {admin, db} = require("./init");
const {assertActiveAuth, HttpsError} = require("./helpers");

/** Máximo de uids por llamada (listas de agenda / solicitudes). */
const MAX_DIRECTORY_UIDS = 50;

/**
 * Crea el documento base `users/{uid}` al registrarse en Auth.
 * Si Auth no trae displayName, asigna un placeholder genérico `userXXXX`.
 */
const onUserCreated = functions.auth.user().onCreate(async (user) => {
  const uid = user.uid;
  const ref = db().collection("users").doc(uid);
  const email = user.email ? user.email.toLowerCase() : null;
  const trimmed = (user.displayName || "").trim();
  const displayName = trimmed ||
    `user${String(Math.floor(1000 + Math.random() * 9000))}`;

  // Firestore primero: si Auth falla, el perfil igual tiene nombre.
  await ref.set({
    email,
    displayName,
    photoUrl: user.photoURL || null,
    phone: user.phoneNumber || null,
    capabilities: {client: true, barber: false},
    isBanned: false,
    isDeleted: false,
    accountStatus: "active",
    moderationStatus: "none",
    locale: "es_GT",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  if (!trimmed) {
    try {
      await admin.auth().updateUser(uid, {displayName});
    } catch (err) {
      functions.logger.warn("No se pudo sincronizar displayName en Auth", {
        uid,
        err: String(err),
      });
    }
  }

  await db().collection("notifications").doc(uid).set({
    unreadCount: 0,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return null;
});

/**
 * Resuelve identidad pública de otros usuarios (nombre/foto/flags).
 * Usa Admin SDK para no abrir `users/{uid}` completo al cliente.
 *
 * Input: { uids: string[] } (máx. 50)
 * Output: { entries: { [uid]: { status, displayName?, photoUrl? } } }
 *   status: "visible" | "hidden" | "missing"
 */
const getUserDirectoryEntries = onCall(async (request) => {
  await assertActiveAuth(request);
  const raw = (request.data && request.data.uids) || [];
  if (!Array.isArray(raw)) {
    throw new HttpsError("invalid-argument", "uids debe ser un arreglo.");
  }
  if (raw.length === 0) {
    return {entries: {}};
  }
  if (raw.length > MAX_DIRECTORY_UIDS) {
    throw new HttpsError(
        "invalid-argument",
        `Máximo ${MAX_DIRECTORY_UIDS} uids por llamada.`,
    );
  }

  const uids = [];
  const seen = new Set();
  for (const item of raw) {
    if (typeof item !== "string") continue;
    const uid = item.trim();
    if (!uid || seen.has(uid)) continue;
    seen.add(uid);
    uids.push(uid);
  }

  const refs = uids.map((uid) => db().collection("users").doc(uid));
  const snaps = refs.length > 0 ? await db().getAll(...refs) : [];
  const entries = {};

  for (let i = 0; i < uids.length; i++) {
    const uid = uids[i];
    const snap = snaps[i];
    if (!snap.exists) {
      entries[uid] = {status: "missing"};
      continue;
    }
    const data = snap.data() || {};
    if (data.isBanned === true || data.isDeleted === true) {
      entries[uid] = {status: "hidden"};
      continue;
    }
    const name =
      typeof data.displayName === "string" ? data.displayName.trim() : "";
    const photo =
      typeof data.photoUrl === "string" ? data.photoUrl.trim() : "";
    entries[uid] = {
      status: "visible",
      displayName: name || null,
      photoUrl: photo || null,
    };
  }

  return {entries};
});

module.exports = {onUserCreated, getUserDirectoryEntries};
