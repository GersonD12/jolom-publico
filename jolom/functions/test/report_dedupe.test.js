const test = require("node:test");
const assert = require("node:assert/strict");

const {buildReportDedupeKey} = require("../src/report_dedupe");

test("genera una huella estable y de tamaño fijo", () => {
  const input = {
    reporterId: "reporter-1",
    targetType: "user",
    targetId: "user-2",
    category: "conducta",
    dayBucket: "2026-08-11",
  };
  const key = buildReportDedupeKey(input);

  assert.equal(key, buildReportDedupeKey(input));
  assert.match(key, /^[a-f0-9]{64}$/);
});

test("distingue valores que una concatenación con separador confundiría", () => {
  const base = {
    targetType: "user",
    category: "conducta",
    dayBucket: "2026-08-11",
  };
  const first = buildReportDedupeKey({
    ...base,
    reporterId: "actor_a",
    targetId: "b",
  });
  const second = buildReportDedupeKey({
    ...base,
    reporterId: "actor",
    targetId: "a_b",
  });

  assert.notEqual(first, second);
});
