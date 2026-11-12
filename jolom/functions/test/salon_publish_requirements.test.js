const test = require("node:test");
const assert = require("node:assert/strict");
const {
  hasSalonImage,
  hasOpenAvailabilityDay,
} = require("../src/salon_publish_requirements");

test("hasSalonImage exige al menos una URL no vacía", () => {
  assert.equal(hasSalonImage({imageUrls: []}), false);
  assert.equal(hasSalonImage({imageUrls: ["  "]}), false);
  assert.equal(hasSalonImage({imageUrls: ["https://img.test/place.webp"]}), true);
});

test("hasOpenAvailabilityDay exige un rango HH:mm válido", () => {
  assert.equal(hasOpenAvailabilityDay(null), false);
  assert.equal(hasOpenAvailabilityDay({mon: null}), false);
  assert.equal(
      hasOpenAvailabilityDay({mon: {start: "18:00", end: "09:00"}}),
      false,
  );
  assert.equal(
      hasOpenAvailabilityDay({mon: {start: "09:00", end: "18:00"}}),
      true,
  );
});
