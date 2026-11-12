#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 <dev|prod> [google-services.json] [GoogleService-Info.plist]" >&2
  exit 64
fi

environment="$1"
android_source="${2:-}"
ios_source="${3:-}"
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$environment" in
  dev) expected_id="com.example.jolom" ;;
  prod) expected_id="com.example.jolom.prod" ;;
  *)
    echo "Entorno inválido: $environment (usa dev o prod)." >&2
    exit 64
    ;;
esac

expected_project_id="$(node -e "const fs=require('fs'); const c=JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); console.log(c.projects?.[process.argv[2]] ?? '')" "$project_root/.firebaserc" "$environment")"
if [[ -z "$expected_project_id" || "$expected_project_id" == TU_* ]]; then
  echo "Configura el project ID real de '$environment' en .firebaserc." >&2
  exit 1
fi

android_destination="$project_root/android/app/src/$environment/google-services.json"
ios_destination="$project_root/ios/config/$environment/GoogleService-Info.plist"
firebase_xcconfig="$project_root/ios/Flutter/Firebase-$environment.xcconfig"

if [[ -n "$android_source" ]]; then
  if [[ ! -f "$android_source" ]]; then
    echo "No existe el archivo Android: $android_source" >&2
    exit 1
  fi
  source_package="$(node - "$android_source" "$expected_id" <<'NODE'
const fs = require('fs');
const config = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const expectedId = process.argv[3];
const clients = Array.isArray(config.client) ? config.client : [];
const packages = clients
  .map((client) => client?.client_info?.android_client_info?.package_name)
  .filter(Boolean);
console.log(packages.includes(expectedId) ? expectedId : packages.join(', '));
NODE
)"
  if [[ "$source_package" != "$expected_id" ]]; then
    echo "El archivo Android usa '$source_package'; se esperaba '$expected_id'." >&2
    exit 1
  fi
  source_project_id="$(node -e "const fs=require('fs'); const c=JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); console.log(c.project_info?.project_id ?? '')" "$android_source")"
  if [[ "$source_project_id" != "$expected_project_id" ]]; then
    echo "El archivo Android pertenece a '$source_project_id'; se esperaba '$expected_project_id'." >&2
    exit 1
  fi
  cp "$android_source" "$android_destination"
fi

if [[ -n "$ios_source" ]]; then
  if [[ ! -f "$ios_source" ]]; then
    echo "No existe el archivo iOS: $ios_source" >&2
    exit 1
  fi
  source_bundle="$(/usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' "$ios_source" 2>/dev/null || true)"
  if [[ "$source_bundle" != "$expected_id" ]]; then
    echo "El archivo iOS usa '$source_bundle'; se esperaba '$expected_id'." >&2
    exit 1
  fi
  source_project_id="$(/usr/libexec/PlistBuddy -c 'Print :PROJECT_ID' "$ios_source" 2>/dev/null || true)"
  if [[ "$source_project_id" != "$expected_project_id" ]]; then
    echo "El archivo iOS pertenece a '$source_project_id'; se esperaba '$expected_project_id'." >&2
    exit 1
  fi
  cp "$ios_source" "$ios_destination"
fi

if [[ ! -f "$ios_destination" ]]; then
  echo "Falta $ios_destination." >&2
  exit 1
fi

reversed_client_id="$(/usr/libexec/PlistBuddy -c 'Print :REVERSED_CLIENT_ID' "$ios_destination" 2>/dev/null || true)"
if [[ -z "$reversed_client_id" ]]; then
  echo "Falta REVERSED_CLIENT_ID en $ios_destination." >&2
  echo "Google Sign-In aún no está configurado para la app iOS '$expected_id' del proyecto '$expected_project_id'." >&2
  echo "Habilita Google en Firebase Console > Authentication > Sign-in method y vuelve a ejecutar: make flutterfire-$environment" >&2
  exit 1
fi
printf 'GOOGLE_REVERSED_CLIENT_ID = %s\nFIREBASE_AUTH_HOST = %s.firebaseapp.com\n' \
  "$reversed_client_id" "$expected_project_id" > "$firebase_xcconfig"

echo "Configuración Firebase de iOS ($environment) instalada."
if [[ -f "$android_destination" ]]; then
  echo "Archivo Firebase de Android ($environment) disponible."
fi
