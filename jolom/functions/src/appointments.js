const {onCall} = require("firebase-functions/v2/https");
const {
  assertActiveAuth,
  writeAuditLog,
  notifyUser,
  findIdempotentResult,
  saveIdempotentResult,
  DEFAULT_TZ,
  HttpsError,
  admin,
  db,
} = require("./helpers");
const {
  AppointmentNotificationOpenMode,
  AppointmentNotificationKind,
  buildAppointmentNotification,
} = require("./appointment_notifications");
const {salonClientBlockRef} = require("./salon_client_blocks");

const ACTIVE_STATUSES = ["pending", "confirmed"];

/** Transiciones permitidas: from -> [to...] */
const TRANSITIONS = {
  pending: [
    "confirmed",
    "rejected",
    "cancelledByClient",
    "cancelledByBusiness",
  ],
  confirmed: [
    "cancelledByClient",
    "cancelledByBusiness",
    "completed",
    "noShow",
  ],
};

/**
 * Copy legible para cambios de estado (bandeja; sin push).
 * @param {string} status
 * @param {boolean} notifyIsClient destinatario es el cliente
 * @return {{title: string, body: string}}
 */
function appointmentStatusCopy(status, notifyIsClient) {
  switch (status) {
    case "confirmed":
      return {
        title: "Cita confirmada",
        body: notifyIsClient ?
          "Tu cita fue confirmada. Te esperamos." :
          "La cita quedó confirmada.",
      };
    case "rejected":
      return {
        title: "Cita no disponible",
        body: notifyIsClient ?
          "El negocio no pudo aceptar esta solicitud." :
          "La solicitud de cita fue rechazada.",
      };
    case "cancelledByClient":
      return {
        title: "Cita cancelada",
        body: notifyIsClient ?
          "Cancelaste tu cita." :
          "El cliente canceló la cita.",
      };
    case "cancelledByBusiness":
      return {
        title: "Cita cancelada",
        body: notifyIsClient ?
          "El negocio canceló tu cita." :
          "Cancelaste la cita del cliente.",
      };
    case "completed":
      return {
        title: "Cita completada",
        body: notifyIsClient ?
          "Tu cita quedó marcada como completada." :
          "Marcaste la cita como completada.",
      };
    case "noShow":
      return {
        title: "Inasistencia registrada",
        body: notifyIsClient ?
          "Se registró que no asististe a la cita." :
          "Registraste inasistencia del cliente.",
      };
    default:
      return {
        title: "Actualización de cita",
        body: "Hubo un cambio en el estado de la cita.",
      };
  }
}

/**
 * @param {string} barberId
 * @param {FirebaseFirestore.Timestamp} startAt
 * @param {FirebaseFirestore.Timestamp} endAt
 * @param {string=} excludeId
 */
async function assertNoOverlap(barberId, startAt, endAt, excludeId) {
  const snap = await db()
      .collection("appointments")
      .where("barberId", "==", barberId)
      .where("status", "in", ACTIVE_STATUSES)
      .where("endAt", ">", startAt)
      .where("startAt", "<", endAt)
      .orderBy("startAt")
      .orderBy("endAt")
      .get();

  const startMs = startAt.toMillis();
  const endMs = endAt.toMillis();
  for (const doc of snap.docs) {
    if (excludeId && doc.id === excludeId) continue;
    const a = doc.data();
    const aStart = a.startAt.toMillis();
    const aEnd = a.endAt.toMillis();
    if (startMs < aEnd && endMs > aStart) {
      throw new HttpsError(
          "failed-precondition",
          "El horario se superpone con otra cita activa.",
      );
    }
  }
}

/**
 * Crea una cita pendiente validando servicio, pertenencia y overlap.
 */
const createAppointment = onCall(async (request) => {
  const uid = await assertActiveAuth(request);
  const data = request.data || {};
  let {salonId, serviceId, barberId} = data;
  if (!salonId || !serviceId || !barberId || !data.startAt) {
    throw new HttpsError(
        "invalid-argument",
        "salonId, serviceId, barberId y startAt son obligatorios.",
    );
  }

  const cached = await findIdempotentResult(
      "createAppointment",
      data.idempotencyKey,
  );
  if (cached) return cached;

  const clientSnap = await db().collection("users").doc(uid).get();
  if (!clientSnap.exists || clientSnap.data().isBanned) {
    throw new HttpsError("permission-denied", "Cuenta no habilitada.");
  }

  const salonSnap = await db().collection("salons").doc(salonId).get();
  if (!salonSnap.exists) {
    throw new HttpsError("not-found", "Peluquería no encontrada.");
  }
  const salon = salonSnap.data();
  if (
    salon.isDeleted ||
    salon.publishStatus !== "published"
  ) {
    throw new HttpsError(
        "failed-precondition",
        "La peluquería no acepta reservas.",
    );
  }

  const localBlockSnap = await salonClientBlockRef(salonId, uid).get();
  if (localBlockSnap.exists) {
    throw new HttpsError(
        "failed-precondition",
        "Esta peluquería no acepta nuevas reservas de tu cuenta.",
    );
  }

  const serviceSnap = await db().collection("services").doc(serviceId).get();
  if (!serviceSnap.exists) {
    throw new HttpsError("not-found", "Servicio no encontrado.");
  }
  const service = serviceSnap.data();
  if (
    service.salonId !== salonId ||
    service.status !== "active" ||
    service.isDeleted
  ) {
    throw new HttpsError("failed-precondition", "Servicio no disponible.");
  }

  const startDate = new Date(data.startAt);
  if (Number.isNaN(startDate.getTime())) {
    throw new HttpsError("invalid-argument", "startAt inválido.");
  }
  const duration = service.durationMinutes || 30;
  const endDate = new Date(startDate.getTime() + duration * 60 * 1000);
  const startAt = admin.firestore.Timestamp.fromDate(startDate);
  const endAt = admin.firestore.Timestamp.fromDate(endDate);
  const bookingDayStart = data.dayStart ? new Date(data.dayStart) : null;
  const bookingDayEnd = data.dayEnd ? new Date(data.dayEnd) : null;
  const hasBookingDay = bookingDayStart &&
    bookingDayEnd &&
    !Number.isNaN(bookingDayStart.getTime()) &&
    !Number.isNaN(bookingDayEnd.getTime()) &&
    bookingDayEnd > bookingDayStart;

  // Asignación automática si el cliente elige cualquiera disponible.
  if (barberId === "any") {
    const membersSnap = await db()
        .collection("salonMemberships")
        .where("salonId", "==", salonId)
        .where("status", "==", "active")
        .get();
    const enabled = service.enabledBarberIds || [];
    let assigned = null;
    const candidateIds = membersSnap.docs
        .map((doc) => doc.id)
        .filter((id) => enabled.length === 0 || enabled.includes(id));
    if (hasBookingDay) {
      const results = await Promise.all(candidateIds.map(async (id) => ({
        barberId: id,
        ...await collectBarberBusy(
            id,
            bookingDayStart.getTime(),
            bookingDayEnd.getTime(),
        ),
      })));
      const match = results.find((result) => isBarberAvailableForRange(
          result,
          bookingDayStart.getTime(),
          startDate.getTime(),
          endDate.getTime(),
      ));
      assigned = match ? match.barberId : null;
    } else {
      for (const candidateId of candidateIds) {
        try {
          await assertNoOverlap(candidateId, startAt, endAt);
          assigned = candidateId;
          break;
        } catch (_) {
          // Compatibilidad con clientes antiguos sin límites del día.
        }
      }
    }
    if (!assigned) {
      throw new HttpsError(
          "failed-precondition",
          "No hay peluqueros disponibles en ese horario.",
      );
    }
    barberId = assigned;
  } else {
    const enabled = service.enabledBarberIds || [];
    if (enabled.length > 0 && !enabled.includes(barberId)) {
      throw new HttpsError(
          "failed-precondition",
          "El peluquero no presta este servicio.",
      );
    }

    const membershipSnap = await db()
        .collection("salonMemberships")
        .doc(barberId)
        .get();
    if (
      !membershipSnap.exists ||
      membershipSnap.data().salonId !== salonId ||
      membershipSnap.data().status !== "active"
    ) {
      throw new HttpsError(
          "failed-precondition",
          "El peluquero no está activo en esta peluquería.",
      );
    }
    if (hasBookingDay) {
      const availability = await collectBarberBusy(
          barberId,
          bookingDayStart.getTime(),
          bookingDayEnd.getTime(),
      );
      if (!isBarberAvailableForRange(
          availability,
          bookingDayStart.getTime(),
          startDate.getTime(),
          endDate.getTime(),
      )) {
        throw new HttpsError(
            "failed-precondition",
            "El horario ya no está disponible.",
        );
      }
    } else {
      await assertNoOverlap(barberId, startAt, endAt);
    }
  }

  const origin = ["app", "qr", "manual"].includes(data.origin) ?
    data.origin :
    "app";

  const clientData = clientSnap.data() || {};
  const clientNameForNotif =
    (typeof clientData.displayName === "string" &&
      clientData.displayName.trim()) ||
    "Cliente";

  const appointmentRef = db().collection("appointments").doc();
  const now = admin.firestore.FieldValue.serverTimestamp();
  const appointment = {
    salonId,
    clientId: uid,
    barberId,
    serviceId,
    serviceName: service.name,
    servicePrice: service.price,
    serviceCurrency: service.currency || salon.currency || "GTQ",
    durationMinutes: duration,
    startAt,
    endAt,
    timeZone: salon.timeZone || DEFAULT_TZ,
    status: "pending",
    origin,
    notes: data.notes || null,
    statusHistory: [
      {
        from: null,
        to: "pending",
        actorId: uid,
        at: admin.firestore.Timestamp.now(),
        source: "createAppointment",
      },
    ],
    idempotencyKey: data.idempotencyKey || null,
    createdAt: now,
    updatedAt: now,
  };

  await appointmentRef.set(appointment);

  const ownerId = salon.ownerId;
  const notifPayload = buildAppointmentNotification({
    appointmentId: appointmentRef.id,
    openMode: AppointmentNotificationOpenMode.WORK,
    kind: AppointmentNotificationKind.REQUEST,
    title: "Nueva solicitud de cita",
    body:
      `${clientNameForNotif} pidió ${service.name}. Confirma o rechaza la reserva.`,
    push: true,
  });
  await notifyUser(barberId, notifPayload);
  if (ownerId && ownerId !== barberId) {
    await notifyUser(ownerId, notifPayload);
  }

  await writeAuditLog({
    actorId: uid,
    action: "createAppointment",
    entityType: "appointment",
    entityId: appointmentRef.id,
    after: {status: "pending", barberId, startAt: startDate.toISOString()},
  });

  const result = {appointmentId: appointmentRef.id};
  await saveIdempotentResult("createAppointment", data.idempotencyKey, result);
  return result;
});

/**
 * Cambia estado de cita según matriz de transiciones y permisos.
 */
const changeAppointmentStatus = onCall(async (request) => {
  const uid = await assertActiveAuth(request);
  const data = request.data || {};
  const {appointmentId, status} = data;
  if (!appointmentId || !status) {
    throw new HttpsError(
        "invalid-argument",
        "appointmentId y status son obligatorios.",
    );
  }

  const cached = await findIdempotentResult(
      "changeAppointmentStatus",
      data.idempotencyKey,
  );
  if (cached) return cached;

  const ref = db().collection("appointments").doc(appointmentId);

  // Membership fuera de la tx (no forma parte de la carrera de status).
  const membershipSnap = await db()
      .collection("salonMemberships")
      .doc(uid)
      .get();
  const membership = membershipSnap.exists ? membershipSnap.data() : null;

  // Lectura + transición + update atómicos: solo una carrera gana.
  const {from, appt, isClient} = await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Cita no encontrada.");
    }
    const current = snap.data();
    const currentFrom = current.status;
    const allowed = TRANSITIONS[currentFrom] || [];
    if (!allowed.includes(status)) {
      throw new HttpsError(
          "failed-precondition",
          `Transición no permitida: ${currentFrom} → ${status}.`,
      );
    }

    const isAssignedBarber = current.barberId === uid;
    const clientIsSelf = current.clientId === uid;
    const isSalonOwner =
      membership &&
      membership.salonId === current.salonId &&
      membership.role === "owner" &&
      membership.status === "active";

    if (status === "cancelledByClient") {
      if (!clientIsSelf) {
        throw new HttpsError(
            "permission-denied",
            "Solo el cliente puede cancelar así.",
        );
      }
    } else if (
      ["confirmed", "rejected", "cancelledByBusiness", "completed", "noShow"]
          .includes(status)
    ) {
      if (!isAssignedBarber && !isSalonOwner) {
        throw new HttpsError(
            "permission-denied",
            "Solo el peluquero asignado o el propietario pueden hacerlo.",
        );
      }
    }

    if (status === "completed" || status === "noShow") {
      if (current.startAt.toMillis() > Date.now()) {
        throw new HttpsError(
            "failed-precondition",
            "Solo después de la hora programada.",
        );
      }
    }

    const history = current.statusHistory || [];
    history.push({
      from: currentFrom,
      to: status,
      actorId: uid,
      at: admin.firestore.Timestamp.now(),
      source: "changeAppointmentStatus",
      reason: data.reason || null,
    });

    tx.update(ref, {
      status,
      statusHistory: history,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {from: currentFrom, appt: current, isClient: clientIsSelf};
  });

  // Notificar / audit fuera de la transaction (solo tras commit exitoso).
  const notifyUid = isClient ? appt.barberId : appt.clientId;
  const notifyIsClient = !isClient;
  const statusCopy = appointmentStatusCopy(status, notifyIsClient);
  // Push al cliente (confirmación/rechazo/cancelación negocio) o al peluquero (cancelación cliente).
  const shouldPush =
    (notifyIsClient &&
      ["confirmed", "rejected", "cancelledByBusiness"].includes(status)) ||
    (!notifyIsClient && status === "cancelledByClient");
  await notifyUser(notifyUid, buildAppointmentNotification({
    appointmentId,
    openMode: notifyIsClient ?
      AppointmentNotificationOpenMode.CLIENT :
      AppointmentNotificationOpenMode.WORK,
    kind: AppointmentNotificationKind.STATUS_CHANGE,
    status,
    title: statusCopy.title,
    body: statusCopy.body,
    push: shouldPush,
  }));

  await writeAuditLog({
    actorId: uid,
    action: "changeAppointmentStatus",
    entityType: "appointment",
    entityId: appointmentId,
    before: {status: from},
    after: {status},
    reason: data.reason || null,
  });

  const result = {appointmentId, status};
  await saveIdempotentResult(
      "changeAppointmentStatus",
      data.idempotencyKey,
      result,
  );
  return result;
});

/**
 * Cita operativa creada desde el modo trabajo (origen manual).
 */
const createManualAppointment = onCall(async (request) => {
  const uid = await assertActiveAuth(request);
  const data = request.data || {};
  const {salonId, serviceId, barberId, clientId} = data;
  if (!salonId || !serviceId || !barberId || !data.startAt) {
    throw new HttpsError(
        "invalid-argument",
        "salonId, serviceId, barberId y startAt son obligatorios.",
    );
  }

  const cached = await findIdempotentResult(
      "createManualAppointment",
      data.idempotencyKey,
  );
  if (cached) return cached;

  const membershipSnap = await db().collection("salonMemberships").doc(uid).get();
  if (!membershipSnap.exists || membershipSnap.data().status !== "active") {
    throw new HttpsError("permission-denied", "Sin pertenencia activa.");
  }
  const membership = membershipSnap.data();
  if (membership.salonId !== salonId) {
    throw new HttpsError("permission-denied", "No perteneces a esta peluquería.");
  }
  const isOwner = membership.role === "owner";
  const isAssignedBarber = uid === barberId;
  if (!isOwner && !isAssignedBarber) {
    throw new HttpsError(
        "permission-denied",
        "Solo el peluquero asignado o el propietario pueden crear citas manuales.",
    );
  }

  // Reutilizar validaciones creando con origin manual.
  request.data = {
    ...data,
    origin: "manual",
    // Si no hay clientId, el creador actúa como placeholder cliente operativo.
    // En MVP usamos el barber/owner como clientId solo si se pasa explícito.
  };
  if (!clientId) {
    throw new HttpsError(
        "invalid-argument",
        "clientId es obligatorio para citas manuales.",
    );
  }

  // Inline create similar a createAppointment pero con clientId externo.
  const salonSnap = await db().collection("salons").doc(salonId).get();
  if (!salonSnap.exists) {
    throw new HttpsError("not-found", "Peluquería no encontrada.");
  }
  const salon = salonSnap.data();
  const localBlockSnap = await salonClientBlockRef(salonId, clientId).get();
  if (localBlockSnap.exists) {
    throw new HttpsError(
        "failed-precondition",
        "Este cliente está bloqueado para nuevas citas en esta peluquería.",
    );
  }
  const serviceSnap = await db().collection("services").doc(serviceId).get();
  if (!serviceSnap.exists) {
    throw new HttpsError("not-found", "Servicio no encontrado.");
  }
  const service = serviceSnap.data();
  if (service.salonId !== salonId || service.status !== "active" || service.isDeleted) {
    throw new HttpsError("failed-precondition", "Servicio no disponible.");
  }

  const barberMembership = await db()
      .collection("salonMemberships")
      .doc(barberId)
      .get();
  if (
    !barberMembership.exists ||
    barberMembership.data().salonId !== salonId ||
    !["active", "pendingExit"].includes(barberMembership.data().status)
  ) {
    throw new HttpsError(
        "failed-precondition",
        "El peluquero no está activo en esta peluquería.",
    );
  }

  const startDate = new Date(data.startAt);
  if (Number.isNaN(startDate.getTime())) {
    throw new HttpsError("invalid-argument", "startAt inválido.");
  }
  const duration = service.durationMinutes || 30;
  const endDate = new Date(startDate.getTime() + duration * 60 * 1000);
  const startAt = admin.firestore.Timestamp.fromDate(startDate);
  const endAt = admin.firestore.Timestamp.fromDate(endDate);
  await assertNoOverlap(barberId, startAt, endAt);

  const appointmentRef = db().collection("appointments").doc();
  const now = admin.firestore.FieldValue.serverTimestamp();
  await appointmentRef.set({
    salonId,
    clientId,
    barberId,
    serviceId,
    serviceName: service.name,
    servicePrice: service.price,
    serviceCurrency: service.currency || salon.currency || "GTQ",
    durationMinutes: duration,
    startAt,
    endAt,
    timeZone: salon.timeZone || DEFAULT_TZ,
    status: "confirmed",
    origin: "manual",
    notes: data.notes || null,
    statusHistory: [
      {
        from: null,
        to: "confirmed",
        actorId: uid,
        at: admin.firestore.Timestamp.now(),
        source: "createManualAppointment",
      },
    ],
    idempotencyKey: data.idempotencyKey || null,
    createdAt: now,
    updatedAt: now,
  });

  await notifyUser(clientId, buildAppointmentNotification({
    appointmentId: appointmentRef.id,
    openMode: AppointmentNotificationOpenMode.CLIENT,
    kind: AppointmentNotificationKind.MANUAL,
    title: "Cita registrada",
    body: `${service.name} quedó confirmada por el negocio.`,
    push: false,
  }));

  await writeAuditLog({
    actorId: uid,
    action: "createManualAppointment",
    entityType: "appointment",
    entityId: appointmentRef.id,
    after: {status: "confirmed", barberId, clientId},
  });

  const result = {appointmentId: appointmentRef.id};
  await saveIdempotentResult(
      "createManualAppointment",
      data.idempotencyKey,
      result,
  );
  return result;
});

/**
 * Une intervalos solapados [{startMs, endMs}] en orden.
 * @param {Array<{startMs: number, endMs: number}>} intervals
 * @return {Array<{startMs: number, endMs: number}>}
 */
function mergeIntervals(intervals) {
  if (!intervals.length) return [];
  const sorted = [...intervals].sort((a, b) => a.startMs - b.startMs);
  const out = [sorted[0]];
  for (let i = 1; i < sorted.length; i++) {
    const cur = sorted[i];
    const last = out[out.length - 1];
    if (cur.startMs <= last.endMs) {
      last.endMs = Math.max(last.endMs, cur.endMs);
    } else {
      out.push({...cur});
    }
  }
  return out;
}

/**
 * Devuelve los tramos libres dentro de una ventana laboral.
 * @param {{startMs: number, endMs: number}} window
 * @param {Array<{startMs: number, endMs: number}>} busyIntervals
 * @return {Array<{startMs: number, endMs: number}>}
 */
function subtractBusyIntervals(window, busyIntervals) {
  const out = [];
  let cursor = window.startMs;
  for (const busy of mergeIntervals(busyIntervals)) {
    const startMs = Math.max(window.startMs, busy.startMs);
    const endMs = Math.min(window.endMs, busy.endMs);
    if (endMs <= window.startMs || startMs >= window.endMs) continue;
    if (startMs > cursor) out.push({startMs: cursor, endMs: startMs});
    cursor = Math.max(cursor, endMs);
  }
  if (cursor < window.endMs) {
    out.push({startMs: cursor, endMs: window.endMs});
  }
  return out;
}

/**
 * Complemento de tramos libres dentro de una ventana global.
 * @param {Array<{startMs: number, endMs: number}>} freeIntervals
 * @param {number} startMs
 * @param {number} endMs
 * @return {Array<{startMs: number, endMs: number}>}
 */
function complementFreeIntervals(freeIntervals, startMs, endMs) {
  return subtractBusyIntervals(
      {startMs, endMs},
      mergeIntervals(freeIntervals),
  );
}

/**
 * Calcula la disponibilidad conjunta para la opción "Cualquiera".
 * @param {Array<{
 *   barberId: string,
 *   intervals: Array<{startMs: number, endMs: number}>,
 *   dayWindow: {startMin: number, endMin: number}|null
 * }>} barberResults
 * @param {number} dayStartMs
 * @param {number} durationMinutes
 * @return {{
 *   minOpen: number|null,
 *   maxClose: number|null,
 *   intervals: Array<{startMs: number, endMs: number}>,
 *   availableStarts: Array<string>
 * }}
 */
function buildAnyBarberAvailability(
    barberResults,
    dayStartMs,
    durationMinutes,
) {
  const working = barberResults.filter((result) => result.dayWindow);
  if (!working.length) {
    return {
      minOpen: null,
      maxClose: null,
      intervals: [],
      availableStarts: [],
    };
  }

  const minOpen = Math.min(...working.map((r) => r.dayWindow.startMin));
  const maxClose = Math.max(...working.map((r) => r.dayWindow.endMin));
  const freeIntervals = [];
  for (const result of working) {
    const window = {
      startMs: dayStartMs + result.dayWindow.startMin * 60 * 1000,
      endMs: dayStartMs + result.dayWindow.endMin * 60 * 1000,
    };
    freeIntervals.push(...subtractBusyIntervals(window, result.intervals));
  }

  const globalStartMs = dayStartMs + minOpen * 60 * 1000;
  const globalEndMs = dayStartMs + maxClose * 60 * 1000;
  const intervals = complementFreeIntervals(
      freeIntervals,
      globalStartMs,
      globalEndMs,
  );
  const durationMs = durationMinutes * 60 * 1000;
  const stepMs = 5 * 60 * 1000;
  const availableStarts = [];

  for (
    let startMs = globalStartMs;
    startMs + durationMs <= globalEndMs;
    startMs += stepMs
  ) {
    const endMs = startMs + durationMs;
    const barber = working.find((result) => {
      const openMs = dayStartMs + result.dayWindow.startMin * 60 * 1000;
      const closeMs = dayStartMs + result.dayWindow.endMin * 60 * 1000;
      if (startMs < openMs || endMs > closeMs) return false;
      return !result.intervals.some((busy) =>
        startMs < busy.endMs && endMs > busy.startMs,
      );
    });
    if (barber) {
      availableStarts.push(new Date(startMs).toISOString());
    }
  }

  return {minOpen, maxClose, intervals, availableStarts};
}

/** Claves weeklyHours alineadas a Date#getUTCDay (0=domingo). */
const WEEKDAY_KEYS = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];

/**
 * Convierte HH:mm a minutos desde medianoche.
 * @param {string} hm
 * @return {number|null}
 */
function hmToMinutes(hm) {
  if (typeof hm !== "string") return null;
  const parts = hm.split(":");
  const h = Number(parts[0]);
  const m = Number(parts[1] || 0);
  if (Number.isNaN(h) || Number.isNaN(m)) return null;
  return h * 60 + m;
}

/**
 * @param {number} mins
 * @return {string}
 */
function minutesToHm(mins) {
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
}

/**
 * Convierte HH:mm a ms absolutos relativos al inicio del día (local del cliente).
 * @param {number} dayStartMs
 * @param {string} hm
 * @return {number|null}
 */
function hmOnDayMs(dayStartMs, hm) {
  const mins = hmToMinutes(hm);
  if (mins == null) return null;
  return dayStartMs + mins * 60 * 1000;
}

/**
 * Intervalos anónimos ocupados de un peluquero en [dayStart, dayEnd).
 * Une citas activas + breaks del weeklyHours + exceptions solapadas.
 * También expone la ventana laboral del día (o null si cerrado / sin doc).
 * @param {string} barberId
 * @param {number} dayStartMs
 * @param {number} dayEndMs
 * @return {Promise<{
 *   intervals: Array<{startMs: number, endMs: number}>,
 *   dayWindow: {start: string, end: string, startMin: number, endMin: number}|null
 * }>}
 */
async function collectBarberBusy(barberId, dayStartMs, dayEndMs) {
  const intervals = [];
  let dayWindow = null;

  const dayStartTimestamp = admin.firestore.Timestamp.fromMillis(dayStartMs);
  const dayEndTimestamp = admin.firestore.Timestamp.fromMillis(dayEndMs);
  const availRef = db().collection("availability").doc(barberId);
  const [snap, availSnap, exceptionsSnap] = await Promise.all([
    db()
        .collection("appointments")
        .where("barberId", "==", barberId)
        .where("status", "in", ACTIVE_STATUSES)
        .where("endAt", ">", dayStartTimestamp)
        .where("startAt", "<", dayEndTimestamp)
        .orderBy("startAt")
        .orderBy("endAt")
        .get(),
    availRef.get(),
    availRef
        .collection("exceptions")
        .where("end", ">", dayStartTimestamp)
        .where("start", "<", dayEndTimestamp)
        .get(),
  ]);

  for (const doc of snap.docs) {
    const a = doc.data();
    const aStart = a.startAt.toMillis();
    const aEnd = a.endAt.toMillis();
    if (aStart < dayEndMs && aEnd > dayStartMs) {
      intervals.push({startMs: aStart, endMs: aEnd});
    }
  }

  if (availSnap.exists) {
    const avail = availSnap.data();
    const dayKey = WEEKDAY_KEYS[new Date(dayStartMs).getUTCDay()];
    const dayHours = avail.weeklyHours && avail.weeklyHours[dayKey];
    if (dayHours && typeof dayHours === "object" && dayHours.start && dayHours.end) {
      const startMin = hmToMinutes(dayHours.start);
      const endMin = hmToMinutes(dayHours.end);
      if (startMin != null && endMin != null && endMin > startMin) {
        dayWindow = {
          start: String(dayHours.start),
          end: String(dayHours.end),
          startMin,
          endMin,
        };
      }
      if (Array.isArray(dayHours.breaks)) {
        for (const br of dayHours.breaks) {
          if (!br || !br.start || !br.end) continue;
          const bStart = hmOnDayMs(dayStartMs, br.start);
          const bEnd = hmOnDayMs(dayStartMs, br.end);
          if (bStart == null || bEnd == null || bEnd <= bStart) continue;
          if (bStart < dayEndMs && bEnd > dayStartMs) {
            intervals.push({startMs: bStart, endMs: bEnd});
          }
        }
      }
    }
  }

  for (const doc of exceptionsSnap.docs) {
    const ex = doc.data();
    if (!ex.start || !ex.end) continue;
    const bStart = ex.start.toMillis ?
      ex.start.toMillis() :
      new Date(ex.start).getTime();
    const bEnd = ex.end.toMillis ?
      ex.end.toMillis() :
      new Date(ex.end).getTime();
    if (Number.isNaN(bStart) || Number.isNaN(bEnd)) continue;
    if (bStart < dayEndMs && bEnd > dayStartMs) {
      intervals.push({startMs: bStart, endMs: bEnd});
    }
  }

  return {intervals: mergeIntervals(intervals), dayWindow};
}

/**
 * Indica si un peluquero cubre por completo un intervalo solicitado.
 * @param {{
 *   intervals: Array<{startMs: number, endMs: number}>,
 *   dayWindow: {startMin: number, endMin: number}|null
 * }} availability
 * @param {number} dayStartMs
 * @param {number} startMs
 * @param {number} endMs
 * @return {boolean}
 */
function isBarberAvailableForRange(
    availability,
    dayStartMs,
    startMs,
    endMs,
) {
  if (!availability.dayWindow) return false;
  const openMs = dayStartMs +
    availability.dayWindow.startMin * 60 * 1000;
  const closeMs = dayStartMs +
    availability.dayWindow.endMin * 60 * 1000;
  if (startMs < openMs || endMs > closeMs) return false;
  return !availability.intervals.some((busy) =>
    startMs < busy.endMs && endMs > busy.startMs,
  );
}

/**
 * Devuelve franjas ocupadas anónimas ({start, end} ISO) y la ventana laboral
 * del día (unión si barberId es "any") para el lienzo de reserva.
 * Sin PII. Accesible sin auth para permitir elegir hora antes del login.
 *
 * Input: salonId, dayStart, dayEnd (ISO), barberId (uid|"any"), serviceId?
 * Output: { intervals, availableStarts?, isClosed, dayOpen?, dayClose? }.
 */
const getDayBusyIntervals = onCall(async (request) => {
  const data = request.data || {};
  const {salonId, barberId, serviceId} = data;
  if (!salonId || !barberId || !data.dayStart || !data.dayEnd) {
    throw new HttpsError(
        "invalid-argument",
        "salonId, barberId, dayStart y dayEnd son obligatorios.",
    );
  }

  const dayStart = new Date(data.dayStart);
  const dayEnd = new Date(data.dayEnd);
  if (Number.isNaN(dayStart.getTime()) || Number.isNaN(dayEnd.getTime())) {
    throw new HttpsError("invalid-argument", "dayStart/dayEnd inválidos.");
  }
  if (dayEnd <= dayStart) {
    throw new HttpsError(
        "invalid-argument",
        "dayEnd debe ser posterior a dayStart.",
    );
  }

  const anyBarber = barberId === "any";
  const salonPromise = db().collection("salons").doc(salonId).get();
  let salonSnap;
  let membershipSnap = null;
  let membersSnap = null;
  let serviceSnap = null;

  if (anyBarber) {
    [salonSnap, membersSnap, serviceSnap] = await Promise.all([
      salonPromise,
      db()
          .collection("salonMemberships")
          .where("salonId", "==", salonId)
          .where("status", "==", "active")
          .get(),
      serviceId ?
        db().collection("services").doc(serviceId).get() :
        Promise.resolve(null),
    ]);
  } else {
    [salonSnap, membershipSnap] = await Promise.all([
      salonPromise,
      db().collection("salonMemberships").doc(barberId).get(),
    ]);
  }

  if (!salonSnap.exists) {
    throw new HttpsError("not-found", "Peluquería no encontrada.");
  }
  const salon = salonSnap.data();
  if (salon.isDeleted || salon.publishStatus !== "published") {
    throw new HttpsError(
        "failed-precondition",
        "La peluquería no acepta reservas.",
    );
  }

  const dayStartMs = dayStart.getTime();
  const dayEndMs = dayEnd.getTime();
  let barberIds = [];
  let durationMinutes = 30;

  if (anyBarber) {
    let enabled = [];
    if (serviceId && (!serviceSnap || !serviceSnap.exists)) {
      throw new HttpsError("not-found", "Servicio no encontrado.");
    }
    if (serviceSnap && serviceSnap.exists) {
      const service = serviceSnap.data();
      if (
        service.salonId !== salonId ||
        service.status !== "active" ||
        service.isDeleted
      ) {
        throw new HttpsError(
            "failed-precondition",
            "Servicio no disponible.",
        );
      }
      enabled = service.enabledBarberIds || [];
      durationMinutes = service.durationMinutes || durationMinutes;
    }
    for (const doc of membersSnap.docs) {
      const uid = doc.id;
      if (enabled.length > 0 && !enabled.includes(uid)) continue;
      barberIds.push(uid);
    }
  } else {
    if (
      !membershipSnap.exists ||
      membershipSnap.data().salonId !== salonId ||
      membershipSnap.data().status !== "active"
    ) {
      throw new HttpsError(
          "failed-precondition",
          "El peluquero no está activo en esta peluquería.",
      );
    }
    barberIds = [barberId];
  }

  const barberResults = await Promise.all(barberIds.map(async (id) => ({
    barberId: id,
    ...await collectBarberBusy(id, dayStartMs, dayEndMs),
  })));

  if (anyBarber) {
    const anyAvailability = buildAnyBarberAvailability(
        barberResults,
        dayStartMs,
        durationMinutes,
    );
    const isClosed = anyAvailability.minOpen == null ||
      anyAvailability.maxClose == null;
    return {
      intervals: anyAvailability.intervals.map((interval) => ({
        start: new Date(interval.startMs).toISOString(),
        end: new Date(interval.endMs).toISOString(),
      })),
      availableStarts: anyAvailability.availableStarts,
      isClosed,
      dayOpen: isClosed ? null : minutesToHm(anyAvailability.minOpen),
      dayClose: isClosed ? null : minutesToHm(anyAvailability.maxClose),
    };
  }

  const result = barberResults[0];
  const isClosed = !result || !result.dayWindow;
  return {
    intervals: (result ? result.intervals : []).map((i) => ({
      start: new Date(i.startMs).toISOString(),
      end: new Date(i.endMs).toISOString(),
    })),
    isClosed,
    dayOpen: isClosed ? null : result.dayWindow.start,
    dayClose: isClosed ? null : result.dayWindow.end,
  };
});

module.exports = {
  createAppointment,
  changeAppointmentStatus,
  createManualAppointment,
  getDayBusyIntervals,
};

Object.defineProperty(module.exports, "__test", {
  enumerable: false,
  value: {
    buildAnyBarberAvailability,
    isBarberAvailableForRange,
    subtractBusyIntervals,
  },
});
