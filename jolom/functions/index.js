/**
 * Punto de entrada de Cloud Functions.
 *
 * Patrón: cada dominio vive en un archivo dentro de src/ y se reexporta aquí.
 */
require("./src/init");

Object.assign(exports, require("./src/users"));
Object.assign(exports, require("./src/salons"));
Object.assign(exports, require("./src/services"));
Object.assign(exports, require("./src/availability"));
Object.assign(exports, require("./src/memberships"));
Object.assign(exports, require("./src/appointments"));
Object.assign(exports, require("./src/reports"));
const salonClientBlocks = require("./src/salon_client_blocks");
exports.getSalonClientBlockStatus =
  salonClientBlocks.getSalonClientBlockStatus;
exports.setSalonClientBlock = salonClientBlocks.setSalonClientBlock;
Object.assign(exports, require("./src/moderation"));
const accountDeletions = require("./src/account_deletions");
exports.requestAccountDeletion = accountDeletions.requestAccountDeletion;
exports.onAccountDeletionJobCreated =
  accountDeletions.onAccountDeletionJobCreated;
exports.recoverAccountDeletions = accountDeletions.recoverAccountDeletions;
exports.purgeAccountDeletionTombstones =
  accountDeletions.purgeAccountDeletionTombstones;
Object.assign(exports, require("./src/scheduled"));
