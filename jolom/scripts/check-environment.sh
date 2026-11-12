#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Uso: $0 <dev|prod> <android|ios> [--signing]" >&2
  exit 64
fi

environment="$1"
platform="$2"
signing_check="${3:-}"
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$environment" in
  dev)
    expected_id="com.example.jolom"
    ;;
  prod)
    expected_id="com.example.jolom.prod"
    ;;
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

check_android() {
  local config="$project_root/android/app/src/$environment/google-services.json"
  local maps_config="$project_root/android/maps-$environment.properties"
  if [[ ! -f "$config" ]]; then
    echo "Falta $config. Ejecuta make firebase-$environment con los archivos descargados de Firebase." >&2
    exit 1
  fi

  node - "$config" "$expected_id" "$expected_project_id" <<'NODE'
const fs = require('fs');
const [configPath, expectedId, expectedProjectId] = process.argv.slice(2);
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
if (config?.project_info?.project_id !== expectedProjectId) {
  console.error(
    `El archivo ${configPath} pertenece a '${config?.project_info?.project_id ?? ''}'; se esperaba '${expectedProjectId}'.`,
  );
  process.exit(1);
}
const clients = Array.isArray(config.client) ? config.client : [];
const matches = clients.some((client) =>
  client?.client_info?.android_client_info?.package_name === expectedId,
);
if (!matches) {
  console.error(`El archivo ${configPath} no contiene el package ${expectedId}.`);
  process.exit(1);
}
NODE

  if [[ ! -f "$maps_config" ]] || ! grep -Eq '^GOOGLE_MAPS_API_KEY=AIza.+' "$maps_config"; then
    echo "Falta una clave válida en $maps_config. Ejecuta make maps-$environment." >&2
    exit 1
  fi

  if [[ "$signing_check" == "--signing" ]]; then
    local properties="$project_root/android/key.properties"
    if [[ ! -f "$properties" ]]; then
      echo "Falta $properties. Copia android/key.properties.example y agrega la firma de Google Play." >&2
      exit 1
    fi

    local key
    for key in storeFile storePassword keyAlias keyPassword; do
      if ! grep -Eq "^${key}=.+" "$properties"; then
        echo "Falta $key en $properties." >&2
        exit 1
      fi
    done

    local store_file
    store_file="$(sed -n 's/^storeFile=//p' "$properties" | tail -1)"
    if [[ "$store_file" != /* ]]; then
      store_file="$project_root/android/$store_file"
    fi
    if [[ ! -f "$store_file" ]]; then
      echo "No existe el keystore configurado: $store_file" >&2
      exit 1
    fi
  fi
}

check_ios() {
  local config="$project_root/ios/config/$environment/GoogleService-Info.plist"
  local firebase_xcconfig="$project_root/ios/Flutter/Firebase-$environment.xcconfig"
  local maps_xcconfig="$project_root/ios/Flutter/Maps-$environment.xcconfig"
  if [[ ! -f "$config" ]]; then
    echo "Falta $config. Ejecuta make firebase-$environment con los archivos descargados de Firebase." >&2
    exit 1
  fi

  local configured_id configured_project_id reversed_id xcconfig_reversed
  configured_id="$(/usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' "$config" 2>/dev/null || true)"
  configured_project_id="$(/usr/libexec/PlistBuddy -c 'Print :PROJECT_ID' "$config" 2>/dev/null || true)"
  reversed_id="$(/usr/libexec/PlistBuddy -c 'Print :REVERSED_CLIENT_ID' "$config" 2>/dev/null || true)"
  if [[ "$configured_id" != "$expected_id" ]]; then
    echo "El archivo $config usa '$configured_id'; se esperaba '$expected_id'." >&2
    exit 1
  fi
  if [[ "$configured_project_id" != "$expected_project_id" ]]; then
    echo "El archivo $config pertenece a '$configured_project_id'; se esperaba '$expected_project_id'." >&2
    exit 1
  fi
  if [[ -z "$reversed_id" ]]; then
    echo "Falta REVERSED_CLIENT_ID en $config." >&2
    echo "Habilita Google Sign-In para la app iOS '$expected_id' en Firebase '$expected_project_id' y ejecuta: make flutterfire-$environment" >&2
    exit 1
  fi
  if [[ ! -f "$firebase_xcconfig" ]]; then
    echo "Falta $firebase_xcconfig. Ejecuta make firebase-$environment para generarlo." >&2
    exit 1
  fi
  xcconfig_reversed="$(sed -n 's/^GOOGLE_REVERSED_CLIENT_ID[[:space:]]*=[[:space:]]*//p' "$firebase_xcconfig" | tail -1)"
  if [[ "$xcconfig_reversed" != "$reversed_id" ]]; then
    echo "El URL scheme de $firebase_xcconfig no coincide con el plist de Firebase." >&2
    exit 1
  fi
  if [[ ! -f "$maps_xcconfig" ]] || ! grep -Eq '^GOOGLE_MAPS_API_KEY[[:space:]]*=[[:space:]]*AIza.+' "$maps_xcconfig"; then
    echo "Falta una clave válida en $maps_xcconfig. Ejecuta make maps-$environment." >&2
    exit 1
  fi
}

case "$platform" in
  android) check_android ;;
  ios) check_ios ;;
  *)
    echo "Plataforma inválida: $platform (usa android o ios)." >&2
    exit 64
    ;;
esac

echo "Configuración $environment/$platform válida."
