const CLEANUP_ACTIONS = Object.freeze({
  ANONYMIZE: "anonymize",
  DELETE: "delete",
  INVALIDATE: "invalidate",
  RETAIN_AGGREGATE: "retainAggregate",
  UNLINK: "unlink",
});

/**
 * Inventario obligatorio de referencias a una identidad de usuario.
 * La política documenta el contrato; cleanupUserReferences ejecuta la lógica.
 */
const USER_REFERENCE_CLEANUP_POLICY = Object.freeze([
  {resource: "appointments.clientId", action: CLEANUP_ACTIONS.ANONYMIZE},
  {resource: "appointments.barberId", action: CLEANUP_ACTIONS.ANONYMIZE},
  {resource: "salons.ownerId", action: CLEANUP_ACTIONS.DELETE},
  {resource: "services.enabledBarberIds", action: CLEANUP_ACTIONS.UNLINK},
  {resource: "salonInvitations.inviterId", action: CLEANUP_ACTIONS.INVALIDATE},
  {resource: "salonInvitations.inviteeId", action: CLEANUP_ACTIONS.INVALIDATE},
  {resource: "salonInvitations.inviteeEmail", action: CLEANUP_ACTIONS.INVALIDATE},
  {resource: "salonClientBlocks.userId", action: CLEANUP_ACTIONS.DELETE},
  {resource: "salonClientBlocks.blockedBy", action: CLEANUP_ACTIONS.ANONYMIZE},
  {resource: "reports.reporterId", action: CLEANUP_ACTIONS.ANONYMIZE},
  {resource: "reports.targetId", action: CLEANUP_ACTIONS.ANONYMIZE},
  {resource: "moderationCases.actorId", action: CLEANUP_ACTIONS.ANONYMIZE},
  {resource: "moderationCases.targetId", action: CLEANUP_ACTIONS.ANONYMIZE},
  {resource: "auditLogs.actorId|entityId|before|after", action: CLEANUP_ACTIONS.ANONYMIZE},
  {resource: "idempotencyKeys.result", action: CLEANUP_ACTIONS.DELETE},
  {resource: "notifications.items.data", action: CLEANUP_ACTIONS.DELETE},
  {resource: "availability/{uid}", action: CLEANUP_ACTIONS.DELETE},
  {resource: "barberProfiles/{uid}", action: CLEANUP_ACTIONS.DELETE},
  {resource: "salonMemberships/{uid}", action: CLEANUP_ACTIONS.DELETE},
  {resource: "notifications/{uid}", action: CLEANUP_ACTIONS.DELETE},
  {resource: "storage/users/{uid}", action: CLEANUP_ACTIONS.DELETE},
  {resource: "stats/barber_{uid}", action: CLEANUP_ACTIONS.RETAIN_AGGREGATE},
].map(Object.freeze));

/**
 * Inventario obligatorio de referencias a una peluquería.
 * La política documenta el contrato; cleanupSalonReferences ejecuta la lógica.
 */
const SALON_REFERENCE_CLEANUP_POLICY = Object.freeze([
  {resource: "salonClientBlocks.salonId", action: CLEANUP_ACTIONS.DELETE},
  {resource: "appointments.salonId", action: CLEANUP_ACTIONS.DELETE},
  {resource: "services.salonId", action: CLEANUP_ACTIONS.DELETE},
  {resource: "salonInvitations.salonId", action: CLEANUP_ACTIONS.DELETE},
  {resource: "salonMemberships.salonId", action: CLEANUP_ACTIONS.DELETE},
  {resource: "availability/{memberId}", action: CLEANUP_ACTIONS.DELETE},
  {resource: "reports.targetId", action: CLEANUP_ACTIONS.ANONYMIZE},
  {resource: "reports.sourceSalonId", action: CLEANUP_ACTIONS.ANONYMIZE},
  {resource: "moderationCases.targetId", action: CLEANUP_ACTIONS.ANONYMIZE},
  {resource: "auditLogs.entityId|before.salonId|after.salonId", action: CLEANUP_ACTIONS.ANONYMIZE},
  {resource: "idempotencyKeys.result.salonId", action: CLEANUP_ACTIONS.DELETE},
  {resource: "notifications.items.data.salonId", action: CLEANUP_ACTIONS.DELETE},
  {resource: "stats/salon_{salonId}", action: CLEANUP_ACTIONS.RETAIN_AGGREGATE},
  {resource: "storage/negocios/{salonId}", action: CLEANUP_ACTIONS.DELETE},
  {resource: "salons/{salonId}", action: CLEANUP_ACTIONS.DELETE},
].map(Object.freeze));

module.exports = {
  CLEANUP_ACTIONS,
  SALON_REFERENCE_CLEANUP_POLICY,
  USER_REFERENCE_CLEANUP_POLICY,
};
