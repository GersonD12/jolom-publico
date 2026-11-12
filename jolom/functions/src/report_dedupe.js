const {createHash} = require("node:crypto");

/**
 * Huella estable para deduplicar sin concatenar valores ambiguos ni exponerlos
 * en una clave auxiliar.
 */
function buildReportDedupeKey({
  reporterId,
  targetType,
  targetId,
  category,
  dayBucket,
}) {
  const canonical = JSON.stringify([
    reporterId,
    targetType,
    targetId,
    category,
    dayBucket,
  ]);
  return createHash("sha256").update(canonical).digest("hex");
}

module.exports = {buildReportDedupeKey};
