const test = require("node:test");
const assert = require("node:assert/strict");
const {
  SALON_INPUT_LIMITS,
  isTextWithinLimit,
  isValidServiceDuration,
  isValidServicePrice,
} = require("../src/salon_input_limits");

test("los textos respetan el máximo configurado", () => {
  assert.equal(
      isTextWithinLimit(
          "a".repeat(SALON_INPUT_LIMITS.salonNameMaxLength),
          SALON_INPUT_LIMITS.salonNameMaxLength,
      ),
      true,
  );
  assert.equal(
      isTextWithinLimit(
          "a".repeat(SALON_INPUT_LIMITS.salonNameMaxLength + 1),
          SALON_INPUT_LIMITS.salonNameMaxLength,
      ),
      false,
  );
});

test("la duración debe ser un entero entre 5 y 480", () => {
  assert.equal(isValidServiceDuration(5), true);
  assert.equal(isValidServiceDuration(480), true);
  assert.equal(isValidServiceDuration(4), false);
  assert.equal(isValidServiceDuration(480.5), false);
  assert.equal(isValidServiceDuration(481), false);
});

test("el precio limita rango, finitud y decimales", () => {
  assert.equal(isValidServicePrice(0), true);
  assert.equal(isValidServicePrice(49.99), true);
  assert.equal(isValidServicePrice(100000), true);
  assert.equal(isValidServicePrice(-0.01), false);
  assert.equal(isValidServicePrice(49.999), false);
  assert.equal(isValidServicePrice(100000.01), false);
  assert.equal(isValidServicePrice(Infinity), false);
  assert.equal(isValidServicePrice(null), false);
  assert.equal(isValidServicePrice(""), false);
});
