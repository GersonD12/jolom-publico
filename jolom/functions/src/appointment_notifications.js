const APPOINTMENT_NOTIFICATION_TYPE = "appointment";

const AppointmentNotificationOpenMode = Object.freeze({
  CLIENT: "client",
  WORK: "work",
});

const AppointmentNotificationKind = Object.freeze({
  REQUEST: "request",
  STATUS_CHANGE: "statusChange",
  REMINDER: "reminder",
  MANUAL: "manual",
  ACCOUNT_DELETION: "accountDeletion",
});

const APPOINTMENT_STATUSES = new Set([
  "pending",
  "confirmed",
  "rejected",
  "cancelledByClient",
  "cancelledByBusiness",
  "completed",
  "noShow",
]);

/**
 * Construye el único formato admitido para notificaciones de citas.
 * @param {{
 *   appointmentId: string,
 *   openMode: string,
 *   kind: string,
 *   status?: string,
 *   title: string,
 *   body: string,
 *   push?: boolean,
 * }} values
 * @return {object}
 */
function buildAppointmentNotification(values) {
  const appointmentId = String(values.appointmentId || "");
  const openMode = values.openMode;
  const kind = values.kind;
  const validOpenModes = Object.values(AppointmentNotificationOpenMode);
  const validKinds = Object.values(AppointmentNotificationKind);

  if (!appointmentId) throw new Error("appointmentId es obligatorio.");
  if (!validOpenModes.includes(openMode)) {
    throw new Error(`openMode de cita inválido: ${openMode}`);
  }
  if (!validKinds.includes(kind)) {
    throw new Error(`kind de cita inválido: ${kind}`);
  }
  if (values.status != null && !APPOINTMENT_STATUSES.has(values.status)) {
    throw new Error(`status de cita inválido: ${values.status}`);
  }

  const data = {
    type: APPOINTMENT_NOTIFICATION_TYPE,
    appointmentId,
    openMode: String(openMode),
    kind: String(kind),
  };
  if (values.status != null) data.status = String(values.status);

  return {
    type: APPOINTMENT_NOTIFICATION_TYPE,
    title: values.title,
    body: values.body,
    data,
    deepLink: `appointment/${appointmentId}`,
    push: values.push === true,
  };
}

module.exports = {
  APPOINTMENT_NOTIFICATION_TYPE,
  AppointmentNotificationOpenMode,
  AppointmentNotificationKind,
  buildAppointmentNotification,
};
