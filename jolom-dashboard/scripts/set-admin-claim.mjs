/**
 * Asigna el custom claim { role: "admin" } sin eliminar claims existentes.
 *
 * Uso:
 *   pnpm set-admin:dev -- <uid>
 *   pnpm set-admin:prod -- <uid>
 *   pnpm set-admin -- <dev|prod> <uid>
 */
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { cert, getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

const ENVIRONMENTS = {
  dev: {
    projectEnv: "FIREBASE_PROJECT_ID_DEV",
    credentialEnv: "FIREBASE_SERVICE_ACCOUNT_DEV",
    defaultCredential: "service-account.dev.json",
  },
  prod: {
    projectEnv: "FIREBASE_PROJECT_ID_PROD",
    credentialEnv: "FIREBASE_SERVICE_ACCOUNT_PROD",
    defaultCredential: "service-account.prod.json",
  },
};

function fail(message) {
  console.error(`Error: ${message}\n`);
  console.error("Uso: pnpm set-admin -- <dev|prod> <uid>");
  console.error("     pnpm set-admin:dev -- <uid>");
  console.error("     pnpm set-admin:prod -- <uid>");
  process.exit(1);
}

function parseArguments() {
  const args = process.argv.slice(2);
  if (args[0] === "--") args.shift();
  const fixedEnvironment = process.env.ADMIN_TARGET_ENV;
  const environment = fixedEnvironment || args.shift();
  const uid = args.shift();

  if (!Object.hasOwn(ENVIRONMENTS, environment)) {
    fail('el entorno debe ser "dev" o "prod".');
  }
  if (!uid || args.length > 0) {
    fail("debes indicar exactamente un UID de Firebase Auth.");
  }

  return { environment, uid };
}

function loadCredential(environment, projectId) {
  const config = ENVIRONMENTS[environment];
  const configuredPath = process.env[config.credentialEnv];
  const credentialPath = resolve(
    process.cwd(),
    configuredPath || config.defaultCredential,
  );

  if (!existsSync(credentialPath)) {
    fail(
      `no se encontró la credencial para ${environment}. Agrega ${config.defaultCredential} ` +
        `en la raíz del proyecto o define ${config.credentialEnv} con su ruta.`,
    );
  }

  let serviceAccount;
  try {
    serviceAccount = JSON.parse(readFileSync(credentialPath, "utf8"));
  } catch {
    fail(`la credencial ${credentialPath} no contiene JSON válido.`);
  }

  if (serviceAccount.project_id !== projectId) {
    fail(
      `la credencial pertenece a "${serviceAccount.project_id || "desconocido"}", ` +
        `pero el entorno ${environment} requiere "${projectId}".`,
    );
  }

  return cert(serviceAccount);
}

async function main() {
  const { environment, uid } = parseArguments();
  const { projectEnv } = ENVIRONMENTS[environment];
  const projectId = process.env[projectEnv]?.trim();
  if (!projectId) {
    fail(`define ${projectEnv} con el ID de tu proyecto Firebase.`);
  }

  if (getApps().length === 0) {
    initializeApp({ credential: loadCredential(environment, projectId) });
  }

  const auth = getAuth();
  const user = await auth.getUser(uid);
  const currentClaims = user.customClaims || {};

  console.log(`Proyecto: ${projectId} (${environment})`);
  console.log(`Usuario: ${user.email || "(sin email)"} (${uid})`);

  if (currentClaims.role === "admin") {
    console.log("El usuario ya tiene role=admin; no se realizaron cambios.");
    return;
  }

  await auth.setCustomUserClaims(uid, { ...currentClaims, role: "admin" });
  console.log("Listo: se asignó role=admin y se conservaron los demás claims.");
  console.log("El usuario debe cerrar sesión y volver a entrar para renovar su token.");
}

main().catch((error) => {
  if (error?.code === "auth/user-not-found") {
    fail("no existe un usuario con ese UID en el proyecto seleccionado.");
  }
  console.error("No se pudo asignar el rol admin:", error);
  process.exit(1);
});
