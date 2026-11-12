/** Maps Firebase client errors to Spanish copy for the admin UI. */
export function formatFirebaseError(
  error: unknown,
  fallback = "Ocurrió un error inesperado",
): string {
  if (!(error instanceof Error)) {
    return fallback;
  }

  const code =
    "code" in error && typeof error.code === "string" ? error.code : undefined;
  const message = error.message;

  if (
    code === "permission-denied" ||
    code === "storage/unauthorized" ||
    message.includes("Missing or insufficient permissions")
  ) {
    return "Sin permisos de Firestore. Verifica el claim role=admin y las reglas de seguridad.";
  }

  return message || fallback;
}
