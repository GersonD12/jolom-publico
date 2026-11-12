const test = require("node:test");
const assert = require("node:assert/strict");

const {
  allowedSalonActions,
  allowedUserActions,
  getUserModerationState,
} = require("../src/moderation_state");

const NOW = Date.UTC(2026, 7, 11, 12);

test("una cuenta normal solo admite sanciones iniciales", () => {
  const actions = allowedUserActions({
    accountStatus: "active",
    moderationStatus: "none",
    isBanned: false,
    isDeleted: false,
  }, NOW);
  assert.deepEqual(actions, ["warn", "ban", "softDelete"]);
});

test("una cuenta advertida no puede recibir otra advertencia", () => {
  const actions = allowedUserActions({
    accountStatus: "active",
    moderationStatus: "warned",
    isBanned: false,
    isDeleted: false,
  }, NOW);
  assert.equal(actions.includes("warn"), false);
  assert.equal(actions.includes("restore"), true);
});

test("el estado legado suspended ya no bloquea la cuenta", () => {
  const user = {
    accountStatus: "active",
    moderationStatus: "suspended",
    isBanned: false,
    isDeleted: false,
  };
  assert.equal(getUserModerationState(user, NOW), "none");
  assert.deepEqual(allowedUserActions(user, NOW), [
    "warn",
    "ban",
    "softDelete",
  ]);
});

test("una cuenta bloqueada no admite otra advertencia", () => {
  const actions = allowedUserActions({
    accountStatus: "active",
    moderationStatus: "banned",
    isBanned: true,
    isDeleted: false,
  }, NOW);
  assert.deepEqual(actions, ["unban", "softDelete"]);
});

test("una cuenta en eliminación no admite moderación", () => {
  const actions = allowedUserActions({
    accountStatus: "deletionPending",
    moderationStatus: "none",
    isBanned: false,
    isDeleted: false,
  }, NOW);
  assert.deepEqual(actions, []);
});

test("advertir salón publicado es válido y banearlo no", () => {
  const actions = allowedSalonActions({
    publishStatus: "published",
    isDeleted: false,
  });
  assert.equal(actions.includes("warn"), true);
  assert.equal(actions.includes("ban"), false);
});

test("un salón suspendido solo se restaura o elimina", () => {
  const actions = allowedSalonActions({
    publishStatus: "suspended",
    isDeleted: false,
  });
  assert.deepEqual(actions, ["restore", "softDelete"]);
});
