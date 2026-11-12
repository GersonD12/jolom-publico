const test = require("node:test");
const assert = require("node:assert/strict");

const {
  CLEANUP_ACTIONS,
  SALON_REFERENCE_CLEANUP_POLICY,
  USER_REFERENCE_CLEANUP_POLICY,
} = require("../src/account_deletion_cleanup_policy");

function assertValidPolicy(policy) {
  const validActions = new Set(Object.values(CLEANUP_ACTIONS));
  const resources = policy.map((entry) => entry.resource);
  assert.equal(new Set(resources).size, resources.length, "recursos duplicados");
  for (const entry of policy) {
    assert.ok(entry.resource.length > 0);
    assert.ok(validActions.has(entry.action), `acción inválida: ${entry.action}`);
    assert.ok(Object.isFrozen(entry), `entrada mutable: ${entry.resource}`);
  }
  assert.ok(Object.isFrozen(policy));
}

test("el inventario de usuario cubre todas las relaciones críticas", () => {
  assertValidPolicy(USER_REFERENCE_CLEANUP_POLICY);
  const resources = new Set(
      USER_REFERENCE_CLEANUP_POLICY.map((entry) => entry.resource),
  );
  for (const required of [
    "appointments.clientId",
    "appointments.barberId",
    "salons.ownerId",
    "salonClientBlocks.userId",
    "salonClientBlocks.blockedBy",
    "reports.reporterId",
    "reports.targetId",
    "moderationCases.targetId",
    "salonMemberships/{uid}",
    "salonInvitations.inviteeId",
    "notifications/{uid}",
  ]) {
    assert.ok(resources.has(required), `falta política de usuario para ${required}`);
  }
});

test("el inventario de salón cubre todas las relaciones críticas", () => {
  assertValidPolicy(SALON_REFERENCE_CLEANUP_POLICY);
  const resources = new Set(
      SALON_REFERENCE_CLEANUP_POLICY.map((entry) => entry.resource),
  );
  for (const required of [
    "salonClientBlocks.salonId",
    "appointments.salonId",
    "services.salonId",
    "salonInvitations.salonId",
    "salonMemberships.salonId",
    "reports.targetId",
    "reports.sourceSalonId",
    "moderationCases.targetId",
    "salons/{salonId}",
  ]) {
    assert.ok(resources.has(required), `falta política de salón para ${required}`);
  }
});
