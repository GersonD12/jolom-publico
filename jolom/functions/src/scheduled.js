const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {admin, db, notifyUser, DEFAULT_TZ} = require("./helpers");
const {
  AppointmentNotificationOpenMode,
  AppointmentNotificationKind,
  buildAppointmentNotification,
} = require("./appointment_notifications");

/**
 * Recordatorios ~30 min antes de citas confirmadas.
 * Ventana ±10 min (intervalo del cron) para no saltar citas entre corridas.
 */
const sendAppointmentReminders = onSchedule(
    {
      schedule: "every 10 minutes",
      timeZone: DEFAULT_TZ,
    },
    async () => {
      const now = Date.now();
      const windowStart = admin.firestore.Timestamp.fromMillis(
          now + 20 * 60 * 1000,
      );
      const windowEnd = admin.firestore.Timestamp.fromMillis(
          now + 40 * 60 * 1000,
      );

      const snap = await db()
          .collection("appointments")
          .where("status", "==", "confirmed")
          .where("startAt", ">=", windowStart)
          .where("startAt", "<=", windowEnd)
          .get();

      for (const doc of snap.docs) {
        const a = doc.data();
        if (a.reminderSentAt) continue;
        await notifyUser(a.clientId, buildAppointmentNotification({
          appointmentId: doc.id,
          openMode: AppointmentNotificationOpenMode.CLIENT,
          kind: AppointmentNotificationKind.REMINDER,
          title: "Tu cita se acerca",
          body: `${a.serviceName} es en aproximadamente 30 minutos.`,
          push: true,
        }));
        await doc.ref.update({
          reminderSentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    },
);

/**
 * Vence invitaciones pendientes expiradas.
 */
const expireInvitations = onSchedule(
    {
      schedule: "every 6 hours",
      timeZone: DEFAULT_TZ,
    },
    async () => {
      const now = admin.firestore.Timestamp.now();
      const snap = await db()
          .collection("salonInvitations")
          .where("status", "==", "pending")
          .where("expiresAt", "<=", now)
          .limit(200)
          .get();
      const batch = db().batch();
      snap.docs.forEach((doc) => {
        batch.update(doc.ref, {
          status: "expired",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      if (!snap.empty) await batch.commit();
    },
);

/**
 * Agrega estadísticas incrementales al completar/cambiar citas.
 */
const onAppointmentStatusForStats = onDocumentUpdated(
    "appointments/{appointmentId}",
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();
      if (!before || !after || before.status === after.status) return;

      const increments = {};
      if (after.status === "pending") increments.requests = 1;
      if (after.status === "confirmed") increments.confirmed = 1;
      if (after.status === "completed") {
        increments.completed = 1;
        increments.estimatedRevenue = after.servicePrice || 0;
      }
      if (after.status === "noShow") increments.noShow = 1;
      if (
        after.status === "cancelledByClient" ||
      after.status === "cancelledByBusiness" ||
      after.status === "rejected"
      ) {
        increments.cancellations = 1;
      }
      if (Object.keys(increments).length === 0) return;

      const statsBarberId = after.barberAnonymized ?
        before.barberId : after.barberId;
      const statsSalonId = after.salonAnonymized ?
        before.salonId : after.salonId;
      const barberRef = db().collection("stats").doc(`barber_${statsBarberId}`);
      const salonRef = db().collection("stats").doc(`salon_${statsSalonId}`);
      const now = admin.firestore.FieldValue.serverTimestamp();

      const apply = (base) => {
        const patch = {updatedAt: now, scopeId: base.scopeId, scopeType: base.scopeType};
        for (const [k, v] of Object.entries(increments)) {
          patch[k] = admin.firestore.FieldValue.increment(v);
        }
        return patch;
      };

      await barberRef.set(
          apply({scopeId: statsBarberId, scopeType: "barber"}),
          {merge: true},
      );
      await salonRef.set(
          apply({scopeId: statsSalonId, scopeType: "salon"}),
          {merge: true},
      );
    },
);

module.exports = {
  sendAppointmentReminders,
  expireInvitations,
  onAppointmentStatusForStats,
};
