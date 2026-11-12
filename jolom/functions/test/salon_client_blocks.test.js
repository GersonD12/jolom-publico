const test = require("node:test");
const assert = require("node:assert/strict");

const {
  buildSalonClientBlockId,
  salonClientBlockPath,
} = require("../src/salon_client_blocks");

test("genera una ruta raíz estable con un SHA-256 determinista", () => {
  const relationId = buildSalonClientBlockId("salon-1", "user-2");
  assert.match(relationId, /^[a-f0-9]{64}$/);
  assert.equal(
      relationId,
      "1ffeedf09f2b9c96a30ab607e04a80bcda89c303890636cb08c1d7b341469cb7",
  );
  assert.equal(
      salonClientBlockPath("salon-1", "user-2"),
      `salonClientBlocks/${relationId}`,
  );
  assert.equal(relationId, buildSalonClientBlockId("salon-1", "user-2"));
});

test("el mismo cliente puede estar bloqueado en una peluquería y no en otra", () => {
  assert.notEqual(
      salonClientBlockPath("salon-a", "user-1"),
      salonClientBlockPath("salon-b", "user-1"),
  );
});

test("la tupla canónica evita depender de separadores entre IDs", () => {
  assert.notEqual(
      buildSalonClientBlockId("salon-a-user", "1"),
      buildSalonClientBlockId("salon-a", "user-1"),
  );
});
