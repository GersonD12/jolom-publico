const {onCall} = require("firebase-functions/v2/https");
const {
  assertActiveAuth,
  writeAuditLog,
  notifyUser,
  findIdempotentResult,
  saveIdempotentResult,
  findUserByEmail,
  INVITE_TTL_MS,
  HttpsError,
  admin,
  db,
} = require("./helpers");

/**
 * Invita a un usuario existente por email; notifica en bandeja in-app.
 */
const inviteBarber = onCall(async (request) => {
  const uid = await assertActiveAuth(request);
  const data = request.data || {};
  const salonId = data.salonId;
  const inviteeEmail = (data.inviteeEmail || "").trim().toLowerCase();
  if (!salonId || !inviteeEmail) {
    throw new HttpsError(
        "invalid-argument",
        "salonId e inviteeEmail son obligatorios.",
    );
  }

  const cached = await findIdempotentResult("inviteBarber", data.idempotencyKey);
  if (cached) return cached;

  const membershipSnap = await db().collection("salonMemberships").doc(uid).get();
  if (!membershipSnap.exists) {
    throw new HttpsError("permission-denied", "Sin pertenencia activa.");
  }
  const membership = membershipSnap.data();
  if (
    membership.salonId !== salonId ||
    membership.role !== "owner" ||
    membership.status !== "active"
  ) {
    throw new HttpsError(
        "permission-denied",
        "Solo el propietario activo puede invitar.",
    );
  }

  const salonSnap = await db().collection("salons").doc(salonId).get();
  if (!salonSnap.exists || salonSnap.data().isDeleted) {
    throw new HttpsError("not-found", "Peluquería no encontrada.");
  }
  const salon = salonSnap.data();

  const invitee = await findUserByEmail(inviteeEmail);
  if (!invitee) {
    throw new HttpsError(
        "not-found",
        "No hay un usuario registrado con ese email.",
    );
  }
  if (invitee.id === uid) {
    throw new HttpsError("invalid-argument", "No puedes invitarte a ti mismo.");
  }
  if (invitee.data.isBanned || invitee.data.isDeleted) {
    throw new HttpsError("failed-precondition", "Usuario no disponible.");
  }

  const existingInvite = await db()
      .collection("salonInvitations")
      .where("salonId", "==", salonId)
      .where("inviteeId", "==", invitee.id)
      .where("status", "==", "pending")
      .limit(1)
      .get();
  if (!existingInvite.empty) {
    const invitationId = existingInvite.docs[0].id;
    const result = {invitationId};
    await saveIdempotentResult("inviteBarber", data.idempotencyKey, result);
    return result;
  }

  const inviteRef = db().collection("salonInvitations").doc();
  const now = admin.firestore.Timestamp.now();
  const expiresAt = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + INVITE_TTL_MS,
  );

  await inviteRef.set({
    salonId,
    inviterId: uid,
    inviteeId: invitee.id,
    inviteeEmail,
    status: "pending",
    expiresAt,
    respondedAt: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await notifyUser(invitee.id, {
    type: "invitation",
    title: "Invitación a peluquería",
    body: `${salon.name} te invita a unirte como peluquero.`,
    data: {
      invitationId: inviteRef.id,
      salonId,
      type: "invitation",
    },
    deepLink: `invitation/${inviteRef.id}`,
    push: false,
  });

  await writeAuditLog({
    actorId: uid,
    action: "inviteBarber",
    entityType: "salonInvitation",
    entityId: inviteRef.id,
    after: {salonId, inviteeId: invitee.id},
  });

  const result = {invitationId: inviteRef.id};
  await saveIdempotentResult("inviteBarber", data.idempotencyKey, result);
  return result;
});

/**
 * Acepta o rechaza una invitación; al aceptar valida pertenencia única.
 */
const respondToInvitation = onCall(async (request) => {
  const uid = await assertActiveAuth(request);
  const data = request.data || {};
  const invitationId = data.invitationId;
  const accept = data.accept === true;
  if (!invitationId) {
    throw new HttpsError("invalid-argument", "invitationId es obligatorio.");
  }

  const cached = await findIdempotentResult(
      "respondToInvitation",
      data.idempotencyKey,
  );
  if (cached) return cached;

  const inviteRef = db().collection("salonInvitations").doc(invitationId);
  const membershipRef = db().collection("salonMemberships").doc(uid);
  const userRef = db().collection("users").doc(uid);
  const barberRef = db().collection("barberProfiles").doc(uid);

  const result = await db().runTransaction(async (tx) => {
    const inviteSnap = await tx.get(inviteRef);
    if (!inviteSnap.exists) {
      throw new HttpsError("not-found", "Invitación no encontrada.");
    }
    const invite = inviteSnap.data();
    if (invite.inviteeId !== uid) {
      throw new HttpsError("permission-denied", "No eres el destinatario.");
    }
    if (invite.status !== "pending") {
      throw new HttpsError(
          "failed-precondition",
          "La invitación ya no está pendiente.",
      );
    }
    const expiresAt = invite.expiresAt.toMillis();
    if (expiresAt < Date.now()) {
      tx.update(inviteRef, {
        status: "expired",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      throw new HttpsError("failed-precondition", "La invitación expiró.");
    }

    const now = admin.firestore.FieldValue.serverTimestamp();

    if (!accept) {
      tx.update(inviteRef, {
        status: "rejected",
        respondedAt: now,
        updatedAt: now,
      });
      return {status: "rejected", salonId: invite.salonId};
    }

    const membershipSnap = await tx.get(membershipRef);
    if (membershipSnap.exists) {
      const m = membershipSnap.data();
      if (m.status === "active" || m.status === "pendingExit") {
        throw new HttpsError(
            "failed-precondition",
            "Ya tienes una pertenencia activa.",
        );
      }
    }

    tx.set(membershipRef, {
      userId: uid,
      salonId: invite.salonId,
      role: "barber",
      status: "active",
      invitationId,
      joinedAt: now,
      leftAt: null,
      updatedAt: now,
    });
    tx.update(inviteRef, {
      status: "accepted",
      respondedAt: now,
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
          salonId: invite.salonId,
          weeklyHours: {},
          updatedAt: now,
        },
        {merge: true},
    );

    return {
      status: "accepted",
      salonId: invite.salonId,
      inviterId: invite.inviterId,
    };
  });

  // Invalidar otras invitaciones pendientes del usuario.
  if (result.status === "accepted") {
    const others = await db()
        .collection("salonInvitations")
        .where("inviteeId", "==", uid)
        .where("status", "==", "pending")
        .get();
    const batch = db().batch();
    others.docs.forEach((doc) => {
      if (doc.id !== invitationId) {
        batch.update(doc.ref, {
          status: "invalidated",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });
    await batch.commit();

    const salonSnap = await db().collection("salons").doc(result.salonId).get();
    const salonLabel =
      (salonSnap.data() && salonSnap.data().name) || "la peluquería";
    await notifyUser(result.inviterId, {
      type: "membership",
      title: "Invitación aceptada",
      body: `Un peluquero aceptó unirse a ${salonLabel}.`,
      data: {
        salonId: result.salonId,
        inviteeId: uid,
        type: "membership",
      },
      push: false,
    });
  } else {
    const inviteSnap = await inviteRef.get();
    const invite = inviteSnap.data();
    const salonSnap = await db().collection("salons").doc(invite.salonId).get();
    const salonLabel =
      (salonSnap.data() && salonSnap.data().name) || "la peluquería";
    await notifyUser(invite.inviterId, {
      type: "membership",
      title: "Invitación rechazada",
      body: `La invitación a ${salonLabel} fue rechazada.`,
      data: {
        salonId: invite.salonId,
        inviteeId: uid,
        type: "membership",
      },
      push: false,
    });
  }

  await writeAuditLog({
    actorId: uid,
    action: "respondToInvitation",
    entityType: "salonInvitation",
    entityId: invitationId,
    after: result,
  });

  const response = {status: result.status, salonId: result.salonId};
  await saveIdempotentResult(
      "respondToInvitation",
      data.idempotencyKey,
      response,
  );
  return response;
});

/**
 * Marca salida pendiente y lista citas futuras a resolver.
 */
const beginMembershipExit = onCall(async (request) => {
  const uid = await assertActiveAuth(request);
  const data = request.data || {};
  const targetUserId = data.targetUserId || uid;

  const cached = await findIdempotentResult(
      "beginMembershipExit",
      data.idempotencyKey,
  );
  if (cached) return cached;

  const targetRef = db().collection("salonMemberships").doc(targetUserId);
  const targetSnap = await targetRef.get();
  if (!targetSnap.exists || targetSnap.data().status !== "active") {
    throw new HttpsError("failed-precondition", "Sin pertenencia activa.");
  }
  const target = targetSnap.data();

  const actorMembershipSnap = await db()
      .collection("salonMemberships")
      .doc(uid)
      .get();
  const actor = actorMembershipSnap.exists ? actorMembershipSnap.data() : null;
  const isSelf = uid === targetUserId;
  const isOwner =
    actor &&
    actor.role === "owner" &&
    actor.salonId === target.salonId &&
    actor.status === "active";

  if (!isSelf && !isOwner) {
    throw new HttpsError("permission-denied", "Sin permiso para iniciar salida.");
  }
  if (target.role === "owner" && isSelf) {
    throw new HttpsError(
        "failed-precondition",
        "El propietario no puede abandonar sin transferir o cerrar el negocio.",
    );
  }

  const futureSnap = await db()
      .collection("appointments")
      .where("barberId", "==", targetUserId)
      .where("status", "in", ["pending", "confirmed"])
      .get();
  const nowMs = Date.now();
  const futureAppointments = futureSnap.docs
      .filter((d) => d.data().startAt.toMillis() > nowMs)
      .map((d) => ({
        appointmentId: d.id,
        startAt: d.data().startAt.toDate().toISOString(),
        status: d.data().status,
      }));

  await targetRef.update({
    status: "pendingExit",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const salonSnap = await db().collection("salons").doc(target.salonId).get();
  const ownerId = salonSnap.exists ? salonSnap.data().ownerId : null;
  if (ownerId && ownerId !== targetUserId) {
    await notifyUser(ownerId, {
      type: "membership",
      title: "Salida de peluquero pendiente",
      body: "Hay citas futuras por resolver antes de cerrar la pertenencia.",
      data: {
        salonId: target.salonId,
        userId: targetUserId,
        type: "membership",
      },
      push: false,
    });
  }
  if (!isSelf) {
    await notifyUser(targetUserId, {
      type: "membership",
      title: "Salida pendiente",
      body: "Debes resolver citas futuras antes de cerrar la relación.",
      data: {salonId: target.salonId, type: "membership"},
      push: false,
    });
  }

  const result = {
    userId: targetUserId,
    salonId: target.salonId,
    status: "pendingExit",
    futureAppointments,
  };
  await writeAuditLog({
    actorId: uid,
    action: "beginMembershipExit",
    entityType: "salonMembership",
    entityId: targetUserId,
    after: result,
  });
  await saveIdempotentResult("beginMembershipExit", data.idempotencyKey, result);
  return result;
});

/**
 * Cierra pertenencia solo si no quedan citas futuras activas.
 */
const completeMembershipExit = onCall(async (request) => {
  const uid = await assertActiveAuth(request);
  const data = request.data || {};
  const targetUserId = data.targetUserId || uid;

  const cached = await findIdempotentResult(
      "completeMembershipExit",
      data.idempotencyKey,
  );
  if (cached) return cached;

  const targetRef = db().collection("salonMemberships").doc(targetUserId);
  const targetSnap = await targetRef.get();
  if (!targetSnap.exists || targetSnap.data().status !== "pendingExit") {
    throw new HttpsError(
        "failed-precondition",
        "La pertenencia no está en salida pendiente.",
    );
  }
  const target = targetSnap.data();

  const actorMembershipSnap = await db()
      .collection("salonMemberships")
      .doc(uid)
      .get();
  const actor = actorMembershipSnap.exists ? actorMembershipSnap.data() : null;
  const isSelf = uid === targetUserId;
  const isOwner =
    actor &&
    actor.role === "owner" &&
    actor.salonId === target.salonId &&
    (actor.status === "active" || actor.status === "pendingExit");
  if (!isSelf && !isOwner) {
    throw new HttpsError("permission-denied", "Sin permiso para completar salida.");
  }

  const futureSnap = await db()
      .collection("appointments")
      .where("barberId", "==", targetUserId)
      .where("status", "in", ["pending", "confirmed"])
      .get();
  const nowMs = Date.now();
  const remaining = futureSnap.docs.filter(
      (d) => d.data().startAt.toMillis() > nowMs,
  );
  if (remaining.length > 0) {
    throw new HttpsError(
        "failed-precondition",
        `Quedan ${remaining.length} citas futuras por reasignar o cancelar.`,
    );
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  await targetRef.update({
    status: "withdrawn",
    leftAt: now,
    updatedAt: now,
  });

  const result = {
    userId: targetUserId,
    salonId: target.salonId,
    status: "withdrawn",
  };
  await writeAuditLog({
    actorId: uid,
    action: "completeMembershipExit",
    entityType: "salonMembership",
    entityId: targetUserId,
    after: result,
  });
  await saveIdempotentResult(
      "completeMembershipExit",
      data.idempotencyKey,
      result,
  );
  return result;
});

module.exports = {
  inviteBarber,
  respondToInvitation,
  beginMembershipExit,
  completeMembershipExit,
};
