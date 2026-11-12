#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Uso: $0 <dev|prod>" >&2
  exit 64
fi

environment="$1"
case "$environment" in
  dev|prod) ;;
  *)
    echo "Entorno inválido: $environment (usa dev o prod)." >&2
    exit 64
    ;;
esac

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

read -rsp "Clave Google Maps Android ($environment): " android_key
echo
read -rsp "Clave Google Maps iOS ($environment): " ios_key
echo

if [[ "$android_key" != AIza* || "$ios_key" != AIza* ]]; then
  echo "Las claves no tienen el formato esperado de una API key de Google." >&2
  exit 1
fi

printf 'GOOGLE_MAPS_API_KEY=%s\n' "$android_key" \
  > "$project_root/android/maps-$environment.properties"
printf 'GOOGLE_MAPS_API_KEY = %s\n' "$ios_key" \
  > "$project_root/ios/Flutter/Maps-$environment.xcconfig"

"$project_root/scripts/check-environment.sh" "$environment" android
"$project_root/scripts/check-environment.sh" "$environment" ios
echo "Google Maps $environment quedó instalado para Android e iOS."
