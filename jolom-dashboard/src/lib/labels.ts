export const REPORT_STATUS_LABELS: Record<string, string> = {
  received: "Recibido",
  inReview: "En revisión",
  closedWithAction: "Cerrado con acción",
  closedWithoutAction: "Cerrado sin acción",
};

export const MODERATION_STATUS_LABELS: Record<string, string> = {
  none: "Ninguno",
  warned: "Advertido",
  banned: "Bloqueado",
};

export function effectiveUserModerationStatus(
  status?: string,
  isBanned = false,
): "none" | "warned" | "banned" {
  if (isBanned || status === "banned") return "banned";
  if (status === "warned") return "warned";
  return "none";
}

export const PUBLISH_STATUS_LABELS: Record<string, string> = {
  draft: "Borrador",
  published: "Publicada",
  hidden: "Oculta",
  suspended: "Suspendida",
  deleted: "Eliminada",
};

export const CASE_STATUS_LABELS: Record<string, string> = {
  open: "Abierto",
  resolved: "Resuelto",
};

export function reportStatusVariant(
  status?: string,
): "default" | "amber" | "celadon" | "destructive" | "bondi" {
  switch (status) {
    case "received":
      return "amber";
    case "inReview":
      return "bondi";
    case "closedWithAction":
      return "destructive";
    case "closedWithoutAction":
      return "celadon";
    default:
      return "default";
  }
}

export function moderationVariant(
  status?: string,
): "default" | "amber" | "celadon" | "destructive" | "bondi" {
  switch (status) {
    case "warned":
      return "amber";
    case "banned":
      return "destructive";
    case "none":
      return "celadon";
    default:
      return "default";
  }
}
