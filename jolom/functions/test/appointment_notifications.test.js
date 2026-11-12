const test = require("node:test");
const assert = require("node:assert/strict");

const {
  AppointmentNotificationOpenMode,
  AppointmentNotificationKind,
  buildAppointmentNotification,
} = require("../src/appointment_notifications");

const cases = [
  ["solicitud a peluquero", "work", "request", undefined],
  ["solicitud a propietario", "work", "request", undefined],
  ["confirmación a cliente", "client", "statusChange", "confirmed"],
  ["rechazo a cliente", "client", "statusChange", "rejected"],
  [
    "cancelación del negocio a cliente",
    "client",
    "statusChange",
    "cancelledByBusiness",
  ],
  [
    "cancelación del cliente a peluquero",
    "work",
    "statusChange",
    "cancelledByClient",
  ],
  ["recordatorio a cliente", "client", "reminder", undefined],
  ["cita manual a cliente", "client", "manual", undefined],
  [
    "eliminación del cliente a peluquero",
    "work",
    "accountDeletion",
    "cancelledByClient",
  ],
  [
    "eliminación profesional o negocio a cliente",
    "client",
    "accountDeletion",
    "cancelledByBusiness",
  ],
];

for (const [name, openMode, kind, status] of cases) {
  test(`genera payload estándar: ${name}`, () => {
    const payload = buildAppointmentNotification({
      appointmentId: "appointment-1",
      openMode,
      kind,
      status,
      title: "Título",
      body: "Contenido",
      push: true,
    });

    assert.deepEqual(payload.data, {
      type: "appointment",
      appointmentId: "appointment-1",
      openMode,
      kind,
      ...(status ? {status} : {}),
    });
    assert.ok(Object.values(payload.data).every(
        (value) => typeof value === "string",
    ));
  });
}

test("rechaza appointmentId ausente", () => {
  assert.throws(() => buildAppointmentNotification({
    appointmentId: "",
    openMode: AppointmentNotificationOpenMode.CLIENT,
    kind: AppointmentNotificationKind.REMINDER,
    title: "Título",
    body: "Contenido",
  }), /appointmentId/);
});

test("rechaza openMode desconocido", () => {
  assert.throws(() => buildAppointmentNotification({
    appointmentId: "appointment-1",
    openMode: "unknown",
    kind: AppointmentNotificationKind.REMINDER,
    title: "Título",
    body: "Contenido",
  }), /openMode/);
});
