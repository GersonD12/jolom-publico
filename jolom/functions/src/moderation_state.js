const USER_ACTIONS_BY_STATE = Object.freeze({
  none: ["warn", "ban", "softDelete"],
  warned: ["ban", "restore", "softDelete"],
  banned: ["unban", "softDelete"],
  deletion: [],
});

const SALON_ACTIONS_BY_STATE = Object.freeze({
  published: ["warn", "unpublish", "suspend", "softDelete"],
  draft: ["warn", "suspend", "softDelete"],
  hidden: ["warn", "restore", "suspend", "softDelete"],
  suspended: ["restore", "softDelete"],
  deleted: ["restore"],
});

function getUserModerationState(user) {
  if (!user || user.accountStatus && user.accountStatus !== "active" || user.isDeleted) {
    return "deletion";
  }
  if (user.isBanned || user.moderationStatus === "banned") return "banned";
  if (user.moderationStatus === "warned") return "warned";
  return "none";
}

function allowedUserActions(user) {
  return USER_ACTIONS_BY_STATE[getUserModerationState(user)] || [];
}

function allowedSalonActions(salon) {
  if (!salon) return [];
  const state = salon.isDeleted ? "deleted" : salon.publishStatus;
  return SALON_ACTIONS_BY_STATE[state] || [];
}

module.exports = {
  allowedSalonActions,
  allowedUserActions,
  getUserModerationState,
};
