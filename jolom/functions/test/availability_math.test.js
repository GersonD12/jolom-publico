const test = require("node:test");
const assert = require("node:assert/strict");

const {__test} = require("../src/appointments");

const HOUR = 60 * 60 * 1000;
const MINUTE = 60 * 1000;

test("Cualquiera asigna un peluquero libre para toda la duración", () => {
  const dayStartMs = Date.UTC(2026, 7, 5);
  const result = __test.buildAnyBarberAvailability([
    {
      barberId: "barber-a",
      dayWindow: {startMin: 9 * 60, endMin: 10 * 60},
      intervals: [{
        startMs: dayStartMs + 9 * HOUR + 15 * MINUTE,
        endMs: dayStartMs + 10 * HOUR,
      }],
    },
    {
      barberId: "barber-b",
      dayWindow: {startMin: 9 * 60, endMin: 10 * 60},
      intervals: [{
        startMs: dayStartMs + 9 * HOUR,
        endMs: dayStartMs + 9 * HOUR + 15 * MINUTE,
      }],
    },
  ], dayStartMs, 30);

  const starts = new Set(result.availableStarts.map((item) =>
    new Date(item).getTime(),
  ));

  assert.equal(starts.has(dayStartMs + 9 * HOUR), false);
  assert.equal(starts.has(dayStartMs + 9 * HOUR + 15 * MINUTE), true);
  assert.equal(starts.has(dayStartMs + 9 * HOUR + 30 * MINUTE), true);
});

test("resta ocupaciones y conserva los tramos libres del día", () => {
  const result = __test.subtractBusyIntervals(
      {startMs: 0, endMs: 100},
      [
        {startMs: 20, endMs: 40},
        {startMs: 35, endMs: 60},
        {startMs: 80, endMs: 120},
      ],
  );

  assert.deepEqual(result, [
    {startMs: 0, endMs: 20},
    {startMs: 60, endMs: 80},
  ]);
});

test("valida nuevamente horario laboral y bloqueos al reservar", () => {
  const dayStartMs = Date.UTC(2026, 7, 5);
  const availability = {
    dayWindow: {startMin: 9 * 60, endMin: 10 * 60},
    intervals: [{
      startMs: dayStartMs + 9 * HOUR + 30 * MINUTE,
      endMs: dayStartMs + 9 * HOUR + 45 * MINUTE,
    }],
  };

  assert.equal(__test.isBarberAvailableForRange(
      availability,
      dayStartMs,
      dayStartMs + 9 * HOUR,
      dayStartMs + 9 * HOUR + 30 * MINUTE,
  ), true);
  assert.equal(__test.isBarberAvailableForRange(
      availability,
      dayStartMs,
      dayStartMs + 9 * HOUR + 15 * MINUTE,
      dayStartMs + 9 * HOUR + 45 * MINUTE,
  ), false);
  assert.equal(__test.isBarberAvailableForRange(
      availability,
      dayStartMs,
      dayStartMs + 8 * HOUR + 45 * MINUTE,
      dayStartMs + 9 * HOUR + 15 * MINUTE,
  ), false);
});
